import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

/// Adds stable identities and type-specific payload storage to reader notes.
class ReaderAnnotationSchemaMigration {
  const ReaderAnnotationSchemaMigration._();

  static const int migrationVersion = 20;
  static const String annotationIdIndex = 'idx_book_notes_annotation_id_unique';
  static const String annotationIdInsertGuard =
      'trg_book_notes_annotation_id_insert_guard';
  static const String annotationIdUpdateGuard =
      'trg_book_notes_annotation_id_update_guard';

  static Future<void> migrate(DatabaseExecutor db) async {
    final columns = (await db.rawQuery(
      'PRAGMA table_info(book_notes)',
    )).map((row) => row['name'] as String).toSet();

    if (!columns.contains('annotation_id')) {
      await db.execute('ALTER TABLE book_notes ADD COLUMN annotation_id TEXT');
    }
    if (!columns.contains('payload_json')) {
      await db.execute('ALTER TABLE book_notes ADD COLUMN payload_json TEXT');
    }

    final rows = await db.query(
      'book_notes',
      columns: const ['id', 'annotation_id'],
      orderBy: 'id ASC',
    );
    final usedIds = <String>{};
    const uuid = Uuid();

    for (final row in rows) {
      final currentId = row['annotation_id'] as String?;
      if (currentId != null && currentId.isNotEmpty && usedIds.add(currentId)) {
        continue;
      }

      String generatedId;
      do {
        generatedId = uuid.v4();
      } while (!usedIds.add(generatedId));

      await db.update(
        'book_notes',
        {'annotation_id': generatedId},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS $annotationIdIndex
      ON book_notes(annotation_id)
    ''');
    // SQLite cannot add a NOT NULL constraint with ALTER TABLE. These guards
    // keep upgraded databases behaviorally consistent with fresh v20 schemas.
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS $annotationIdInsertGuard
      BEFORE INSERT ON book_notes
      WHEN NEW.annotation_id IS NULL OR trim(NEW.annotation_id) = ''
      BEGIN
        SELECT RAISE(ABORT, 'book_notes.annotation_id is required');
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS $annotationIdUpdateGuard
      BEFORE UPDATE OF annotation_id ON book_notes
      WHEN NEW.annotation_id IS NULL OR trim(NEW.annotation_id) = ''
      BEGIN
        SELECT RAISE(ABORT, 'book_notes.annotation_id is required');
      END
    ''');
  }
}

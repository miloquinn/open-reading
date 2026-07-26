import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/data/migration/reader_annotation_schema_migration.dart';

void main() {
  late Database database;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE book_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        cfi TEXT NOT NULL,
        chapter TEXT NOT NULL,
        type TEXT NOT NULL,
        color TEXT NOT NULL,
        update_time TEXT NOT NULL
      )
    ''');
    await database.insert('book_notes', {
      'book_id': 1,
      'content': 'first',
      'cfi': 'same-cfi',
      'chapter': 'chapter',
      'type': 'highlight',
      'color': '66CCFF',
      'update_time': DateTime.utc(2026).toIso8601String(),
    });
    await database.insert('book_notes', {
      'book_id': 1,
      'content': '',
      'cfi': 'same-cfi',
      'chapter': 'chapter',
      'type': 'ink',
      'color': 'FF0000',
      'update_time': DateTime.utc(2026).toIso8601String(),
    });
  });

  tearDown(() => database.close());

  test('v20 migration backfills unique UUIDs and is idempotent', () async {
    await ReaderAnnotationSchemaMigration.migrate(database);
    final firstPass = await database.query('book_notes', orderBy: 'id');

    await ReaderAnnotationSchemaMigration.migrate(database);
    final secondPass = await database.query('book_notes', orderBy: 'id');

    final columns = await database.rawQuery('PRAGMA table_info(book_notes)');
    expect(
      columns.map((row) => row['name']),
      containsAll(['annotation_id', 'payload_json']),
    );

    final ids = firstPass.map((row) => row['annotation_id'] as String).toList();
    expect(ids, hasLength(2));
    expect(ids.toSet(), hasLength(2));
    expect(ids, everyElement(matches(_uuidPattern)));
    expect(secondPass.map((row) => row['annotation_id']).toList(), ids);

    final indexes = await database.rawQuery('PRAGMA index_list(book_notes)');
    final annotationIndex = indexes.singleWhere(
      (row) => row['name'] == ReaderAnnotationSchemaMigration.annotationIdIndex,
    );
    expect(annotationIndex['unique'], 1);

    await expectLater(
      database.insert('book_notes', {
        'annotation_id': ids.first,
        'book_id': 1,
        'content': 'duplicate',
        'cfi': 'another-cfi',
        'chapter': 'chapter',
        'type': 'note',
        'color': '66CCFF',
        'update_time': DateTime.utc(2026).toIso8601String(),
      }),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      database.insert('book_notes', {
        'book_id': 1,
        'content': 'missing identity',
        'cfi': 'missing-id-cfi',
        'chapter': 'chapter',
        'type': 'note',
        'color': '66CCFF',
        'update_time': DateTime.utc(2026).toIso8601String(),
      }),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      database.update(
        'book_notes',
        {'annotation_id': ''},
        where: 'id = ?',
        whereArgs: [firstPass.first['id']],
      ),
      throwsA(isA<DatabaseException>()),
    );
  });
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

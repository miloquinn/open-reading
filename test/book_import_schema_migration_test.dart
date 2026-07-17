import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/data/migration/book_import_schema_migration.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('v17 迁移添加来源字段和唯一来源索引', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute(
      'CREATE TABLE books(id INTEGER PRIMARY KEY, content_hash TEXT)',
    );

    await BookImportSchemaMigration.migrate(db);
    await BookImportSchemaMigration.migrate(db);

    final columns = await db.rawQuery('PRAGMA table_info(books)');
    expect(
      columns.map((row) => row['name']),
      containsAll(<String>[
        'source_kind',
        'source_locator',
        'source_modified_time',
      ]),
    );

    final indexes = await db.rawQuery('PRAGMA index_list(books)');
    expect(
      indexes.map((row) => row['name']),
      contains('idx_books_source_locator'),
    );
  });
}

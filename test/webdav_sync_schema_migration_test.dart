import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/data/migration/webdav_sync_schema_migration.dart';

void main() {
  late Database database;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });

  tearDown(() => database.close());

  test('migration creates records, cursor, and local state tables idempotently',
      () async {
    await WebDavSyncSchemaMigration.migrate(database);
    await WebDavSyncSchemaMigration.migrate(database);

    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']).toSet();
    expect(
        names,
        containsAll([
          'sync_records',
          'sync_device_cursors',
          'sync_local_state',
          'sync_book_files',
        ]));

    final indexes = await database.rawQuery('PRAGMA index_list(sync_records)');
    final indexNames = indexes.map((row) => row['name']).toSet();
    expect(indexNames, contains('idx_sync_records_dirty'));
    expect(indexNames, contains('idx_sync_records_entity'));

    final bookFileIndexes =
        await database.rawQuery('PRAGMA index_list(sync_book_files)');
    final bookFileIndexNames =
        bookFileIndexes.map((row) => row['name']).toSet();
    expect(bookFileIndexNames, contains('idx_sync_book_files_local_book'));
  });
}

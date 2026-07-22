import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Installs the protocol mirror used by metadata sync.
///
/// These tables intentionally contain no credentials and no device-local file
/// paths. Business tables remain the source of truth for the reader UI.
class WebDavSyncSchemaMigration {
  const WebDavSyncSchemaMigration._();

  static Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_records(
        dataset TEXT NOT NULL,
        record_id TEXT NOT NULL,
        entity_key TEXT NOT NULL,
        payload_json TEXT,
        hlc TEXT NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        dirty INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY(dataset, record_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_records_dirty
      ON sync_records(dirty, dataset)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_records_entity
      ON sync_records(dataset, entity_key)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_device_cursors(
        remote_device_id TEXT PRIMARY KEY,
        applied_sequence INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_local_state(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_book_files(
        book_uid TEXT PRIMARY KEY,
        local_book_id INTEGER,
        blob_sha256 TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        remote_path TEXT NOT NULL,
        cover_blob_sha256 TEXT,
        cover_file_name TEXT,
        cover_file_size INTEGER,
        cover_remote_path TEXT,
        sync_enabled INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');
    final bookFileColumns = (await db.rawQuery(
      'PRAGMA table_info(sync_book_files)',
    ))
        .map((column) => column['name'] as String)
        .toSet();
    const coverColumns = <String, String>{
      'cover_blob_sha256': 'TEXT',
      'cover_file_name': 'TEXT',
      'cover_file_size': 'INTEGER',
      'cover_remote_path': 'TEXT',
    };
    for (final entry in coverColumns.entries) {
      if (!bookFileColumns.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE sync_book_files ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_book_files_local_book
      ON sync_book_files(local_book_id)
    ''');
  }
}

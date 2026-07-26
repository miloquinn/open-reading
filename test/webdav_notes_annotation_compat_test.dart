import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/data/migration/webdav_sync_schema_migration.dart';
import 'package:xxread/services/sync/adapters/metadata_sync_adapters.dart';
import 'package:xxread/services/sync/sync_change_store.dart';
import 'package:xxread/services/sync/sync_clock.dart';
import 'package:xxread/services/sync/sync_protocol.dart';

void main() {
  late Database database;
  late SyncChangeStore store;
  late NotesSyncAdapter adapter;

  const bookUid = 'source:source-1:book-1';

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        filePath TEXT NOT NULL,
        format TEXT NOT NULL,
        importDate INTEGER NOT NULL,
        content_hash TEXT,
        source_id TEXT,
        source_book_id TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE book_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        annotation_id TEXT NOT NULL,
        book_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        cfi TEXT NOT NULL,
        chapter TEXT NOT NULL,
        type TEXT NOT NULL,
        color TEXT NOT NULL,
        reader_note TEXT,
        page_number INTEGER,
        start_offset INTEGER,
        end_offset INTEGER,
        canonical_locator TEXT,
        payload_json TEXT,
        create_time TEXT,
        update_time TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE UNIQUE INDEX idx_book_notes_annotation_id_unique
      ON book_notes(annotation_id)
    ''');
    await database.insert('books', {
      'title': 'Remote Book',
      'author': 'Author',
      'filePath': '',
      'format': 'source',
      'importDate': 1,
      'source_id': 'source-1',
      'source_book_id': 'book-1',
    });
    await WebDavSyncSchemaMigration.migrate(database);
    store = SyncChangeStore(database: () async => database);
    adapter = NotesSyncAdapter(store, () async => database);
  });

  tearDown(() => database.close());

  test(
    'remote ink records preserve stable identity and drawing payload',
    () async {
      const annotationId = '27d34c7c-90e3-4c79-a1c6-95923628bb36';
      const operation = SyncOperation(
        dataset: 'notes',
        recordId: '64b1e3cb-3ed7-5ce2-a93d-c8f778aaeb2b',
        entityKey: bookUid,
        hlc: '1000-0000-remote',
        deleted: false,
        payload: {
          'annotation_id': annotationId,
          'content': 'quoted text',
          'cfi': 'or-annotation:ink:chapter-1:4:4',
          'chapter': 'Chapter 1',
          'type': 'ink',
          'color': '2563EB',
          'reader_note': null,
          'page_number': 1,
          'start_offset': 4,
          'end_offset': 4,
          'canonical_locator': {'chapterId': 'chapter-1'},
          'payload_json': {
            'version': 1,
            'coordinateSpace': 'normalized-page',
            'strokes': [
              {
                'color': '2563EB',
                'width': 2.7,
                'points': [
                  [0.1, 0.2],
                  [0.3, 0.4],
                ],
              },
            ],
          },
          'create_time': '2026-07-26T00:00:00.000Z',
          'update_time': '2026-07-26T00:00:00.000Z',
        },
      );

      await database.transaction((txn) => adapter.apply(txn, operation));

      final row = (await database.query('book_notes')).single;
      expect(row['annotation_id'], annotationId);
      expect(
        jsonDecode(row['payload_json']! as String),
        operation.payload!['payload_json'],
      );

      await adapter.scan(
        HybridLogicalClock(deviceId: 'local', nowMillis: () => 2000),
      );
      final record = (await store.recordsForDataset('notes')).single;
      expect(record.payload!['annotation_id'], annotationId);
      expect(
        record.payload!['payload_json'],
        operation.payload!['payload_json'],
      );
    },
  );

  test(
    'legacy remote notes use the stable record id as an annotation id',
    () async {
      const recordId = '749bd077-72b0-5279-aa6f-018083bb4964';
      const operation = SyncOperation(
        dataset: 'notes',
        recordId: recordId,
        entityKey: bookUid,
        hlc: '1000-0000-remote',
        deleted: false,
        payload: {
          'content': 'legacy highlight',
          'cfi': 'legacy-cfi',
          'chapter': 'Chapter 1',
          'type': 'highlight',
          'color': 'FFD54F',
          'create_time': '2026-07-25T00:00:00.000Z',
          'update_time': '2026-07-25T00:00:00.000Z',
        },
      );

      await database.transaction((txn) => adapter.apply(txn, operation));
      await database.transaction((txn) => adapter.apply(txn, operation));

      final rows = await database.query('book_notes');
      expect(rows, hasLength(1));
      expect(rows.single['annotation_id'], recordId);
    },
  );
}

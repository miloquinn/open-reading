import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/services/book_source_reading_progress.dart';
import 'package:xxread/book_sources/services/book_source_registry.dart';
import 'package:xxread/data/migration/webdav_sync_schema_migration.dart';
import 'package:xxread/services/sync/adapters/metadata_sync_adapters.dart';
import 'package:xxread/services/sync/sync_change_store.dart';
import 'package:xxread/services/sync/sync_clock.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/services/sync/sync_protocol.dart';

void main() {
  late Database database;
  late SyncChangeStore store;
  late BookSourceRegistry registry;
  late BookSourceReadingProgressStore progressStore;
  late MetadataSyncAdapters adapters;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        filePath TEXT NOT NULL,
        format TEXT NOT NULL,
        currentPage INTEGER DEFAULT 0,
        totalPages INTEGER DEFAULT 1,
        importDate INTEGER NOT NULL,
        content_hash TEXT,
        last_canonical_locator TEXT,
        storage_type TEXT NOT NULL DEFAULT 'local',
        source_id TEXT,
        source_book_id TEXT,
        source_json TEXT,
        source_book_json TEXT
      )
    ''');
    await database.execute('''
      CREATE UNIQUE INDEX idx_books_source_identity
      ON books(source_id, source_book_id)
      WHERE source_id IS NOT NULL AND source_book_id IS NOT NULL
    ''');
    await WebDavSyncSchemaMigration.migrate(database);
    store = SyncChangeStore(database: () async => database);
    registry = BookSourceRegistry();
    progressStore = const BookSourceReadingProgressStore();
    adapters = MetadataSyncAdapters(
      store: store,
      database: () async => database,
      bookSourceRegistry: registry,
      sourceProgressStore: progressStore,
    );
  });

  tearDown(() => database.close());

  test(
    'book sources scan into records and local removal becomes a tombstone',
    () async {
      final source = _source();
      await registry.upsert(source);
      final clock = HybridLogicalClock(
        deviceId: 'local',
        nowMillis: () => 1000,
      );

      await adapters.scan(
        const WebDavSyncScope(
          books: false,
          progress: false,
          bookmarks: false,
          readingSessions: false,
        ),
        clock,
      );

      var record = (await store.recordsForDataset('book_sources')).single;
      expect(record.entityKey, source.id);
      expect(record.payload, source.toJson());
      expect(record.deleted, isFalse);

      await store.markUploaded([record]);
      await registry.remove(source.id);
      await adapters.scan(
        const WebDavSyncScope(
          books: false,
          progress: false,
          bookmarks: false,
          readingSessions: false,
        ),
        clock,
      );

      record = (await store.recordsForDataset('book_sources')).single;
      expect(record.entityKey, source.id);
      expect(record.deleted, isTrue);
      expect(record.dirty, isTrue);
    },
  );

  test(
    'remote book source winners materialize and delete registry entries',
    () async {
      final source = _source();
      final recordId = stableRecordId('book_source', source.id);

      await store.applyRemoteBatch(
        SyncBatch.create(
          deviceId: 'remote',
          sequence: 1,
          createdHlc: '2000-0000-remote',
          operations: [
            SyncOperation(
              dataset: 'book_sources',
              recordId: recordId,
              entityKey: source.id,
              hlc: '2000-0000-remote',
              deleted: false,
              payload: source.toJson(),
            ),
          ],
        ),
        applyWinner: adapters.apply,
      );

      final restored = (await registry.load()).single;
      expect(restored.toJson(), source.toJson());

      await store.applyRemoteBatch(
        SyncBatch.create(
          deviceId: 'remote',
          sequence: 2,
          createdHlc: '3000-0000-remote',
          operations: [
            SyncOperation(
              dataset: 'book_sources',
              recordId: recordId,
              entityKey: source.id,
              hlc: '3000-0000-remote',
              deleted: true,
              payload: source.toJson(),
            ),
          ],
        ),
        applyWinner: adapters.apply,
      );

      expect(await registry.load(), isEmpty);
    },
  );

  test('remote online book becomes a usable shelf entry', () async {
    final source = _source();
    final sourceBook = {
      'id': 'book-1',
      'title': 'Remote Book',
      'author': 'Remote Author',
      'description': 'Synced book',
      'categories': ['fiction'],
    };
    const bookUid = 'source:org.example.books:book-1';

    await store.applyRemoteBatch(
      SyncBatch.create(
        deviceId: 'remote',
        sequence: 1,
        createdHlc: '2000-0000-remote',
        operations: [
          SyncOperation(
            dataset: 'books',
            recordId: bookUid,
            entityKey: bookUid,
            hlc: '2000-0000-remote',
            deleted: false,
            payload: {
              'book_uid': bookUid,
              'title': 'Remote Book',
              'author': 'Remote Author',
              'format': 'source',
              'storage_type': 'online',
              'source_id': source.id,
              'source_book_id': 'book-1',
              'source_json': jsonEncode(source.toJson()),
              'source_book_json': jsonEncode(sourceBook),
              'import_date': 1234,
            },
          ),
        ],
      ),
      applyWinner: adapters.apply,
    );

    final row = (await database.query('books')).single;
    expect(row['title'], 'Remote Book');
    expect(row['filePath'], '');
    expect(row['format'], 'source');
    expect(row['storage_type'], 'online');
    expect(row['source_id'], source.id);
    expect(row['source_book_id'], 'book-1');
    expect(row['source_json'], jsonEncode(source.toJson()));
    expect(row['source_book_json'], jsonEncode(sourceBook));

    await store.applyRemoteBatch(
      SyncBatch.create(
        deviceId: 'remote',
        sequence: 2,
        createdHlc: '3000-0000-remote',
        operations: const [
          SyncOperation(
            dataset: 'books',
            recordId: bookUid,
            entityKey: bookUid,
            hlc: '3000-0000-remote',
            deleted: true,
            payload: {'storage_type': 'online'},
          ),
        ],
      ),
      applyWinner: adapters.apply,
    );
    expect(await database.query('books'), isEmpty);
  });

  test(
    'online book scan preserves source snapshots without local paths',
    () async {
      final source = _source();
      final sourceJson = jsonEncode(source.toJson());
      const sourceBookJson = '{"id":"book-1","title":"Remote Book"}';
      await database.insert('books', {
        'title': 'Remote Book',
        'author': 'Remote Author',
        'filePath': '',
        'format': 'source',
        'currentPage': 0,
        'totalPages': 1,
        'importDate': 1234,
        'storage_type': 'online',
        'source_id': source.id,
        'source_book_id': 'book-1',
        'source_json': sourceJson,
        'source_book_json': sourceBookJson,
      });

      await adapters.scan(
        const WebDavSyncScope(
          progress: false,
          bookmarks: false,
          readingSessions: false,
        ),
        HybridLogicalClock(deviceId: 'local', nowMillis: () => 1000),
      );

      final record = (await store.recordsForDataset('books')).single;
      expect(record.payload!['storage_type'], 'online');
      expect(record.payload!['source_json'], sourceJson);
      expect(record.payload!['source_book_json'], sourceBookJson);
      expect(record.payload, isNot(contains('filePath')));
    },
  );

  test('online tombstones do not delete a downloaded local copy', () async {
    final source = _source();
    await database.insert('books', {
      'title': 'Downloaded Book',
      'author': 'Remote Author',
      'filePath': '/tmp/downloaded-book.txt',
      'format': 'txt',
      'currentPage': 0,
      'totalPages': 10,
      'importDate': 1234,
      'storage_type': 'local',
      'source_id': source.id,
      'source_book_id': 'book-1',
      'source_json': jsonEncode(source.toJson()),
      'source_book_json': '{"id":"book-1","title":"Downloaded Book"}',
    });
    const bookUid = 'source:org.example.books:book-1';

    await store.applyRemoteBatch(
      SyncBatch.create(
        deviceId: 'remote',
        sequence: 1,
        createdHlc: '2000-0000-remote',
        operations: const [
          SyncOperation(
            dataset: 'books',
            recordId: bookUid,
            entityKey: bookUid,
            hlc: '2000-0000-remote',
            deleted: true,
            payload: {'storage_type': 'online'},
          ),
        ],
      ),
      applyWinner: adapters.apply,
    );

    final row = (await database.query('books')).single;
    expect(row['storage_type'], 'local');
    expect(row['filePath'], '/tmp/downloaded-book.txt');
  });

  test(
    'online reading progress is restored through the progress dataset',
    () async {
      final source = _source();
      await database.insert('books', {
        'title': 'Remote Book',
        'author': 'Remote Author',
        'filePath': '',
        'format': 'source',
        'currentPage': 0,
        'totalPages': 1,
        'importDate': 1234,
        'storage_type': 'online',
        'source_id': source.id,
        'source_book_id': 'book-1',
        'source_json': jsonEncode(source.toJson()),
        'source_book_json': '{"id":"book-1","title":"Remote Book"}',
      });
      const bookUid = 'source:org.example.books:book-1';

      await store.applyRemoteBatch(
        SyncBatch.create(
          deviceId: 'remote',
          sequence: 1,
          createdHlc: '2000-0000-remote',
          operations: const [
            SyncOperation(
              dataset: 'progress',
              recordId: bookUid,
              entityKey: bookUid,
              hlc: '2000-0000-remote',
              deleted: false,
              payload: {
                'book_uid': bookUid,
                'current_page': 2400,
                'total_pages': 12000,
                'source_progress': {
                  'chapterId': 'chapter-3',
                  'chapterIndex': 2,
                  'chapterProgress': 0.4,
                  'updatedAt': '2026-07-26T00:00:00.000Z',
                },
              },
            ),
          ],
        ),
        applyWinner: adapters.apply,
      );

      final restored = await progressStore.load(
        sourceId: source.id,
        bookId: 'book-1',
      );
      expect(restored?.chapterId, 'chapter-3');
      expect(restored?.chapterIndex, 2);
      expect(restored?.chapterProgress, 0.4);
      final row = (await database.query('books')).single;
      expect(row['currentPage'], 2400);
      expect(row['totalPages'], 12000);

      await store.applyRemoteBatch(
        SyncBatch.create(
          deviceId: 'remote',
          sequence: 2,
          createdHlc: '3000-0000-remote',
          operations: const [
            SyncOperation(
              dataset: 'progress',
              recordId: bookUid,
              entityKey: bookUid,
              hlc: '3000-0000-remote',
              deleted: true,
              payload: {'book_uid': bookUid},
            ),
          ],
        ),
        applyWinner: adapters.apply,
      );
      expect(
        await progressStore.load(sourceId: source.id, bookId: 'book-1'),
        isNull,
      );
      expect((await database.query('books')).single['currentPage'], 0);
    },
  );

  test('online reading progress scans into the progress dataset', () async {
    final source = _source();
    await database.insert('books', {
      'title': 'Remote Book',
      'author': 'Remote Author',
      'filePath': '',
      'format': 'source',
      'currentPage': 2400,
      'totalPages': 12000,
      'importDate': 1234,
      'storage_type': 'online',
      'source_id': source.id,
      'source_book_id': 'book-1',
      'source_json': jsonEncode(source.toJson()),
      'source_book_json': '{"id":"book-1","title":"Remote Book"}',
    });
    await progressStore.save(
      sourceId: source.id,
      bookId: 'book-1',
      progress: BookSourceReadingProgress(
        chapterId: 'chapter-3',
        chapterIndex: 2,
        chapterProgress: 0.4,
        updatedAt: DateTime.utc(2026, 7, 26),
      ),
    );

    await adapters.scan(
      const WebDavSyncScope(
        bookSources: false,
        books: false,
        bookmarks: false,
        readingSessions: false,
      ),
      HybridLogicalClock(deviceId: 'local', nowMillis: () => 1000),
    );

    final record = (await store.recordsForDataset('progress')).single;
    expect(record.entityKey, 'source:org.example.books:book-1');
    expect(record.payload!['current_page'], 2400);
    expect(record.payload!['total_pages'], 12000);
    expect(
      (record.payload!['source_progress'] as Map)['chapterId'],
      'chapter-3',
    );
  });
}

RegisteredBookSource _source() => RegisteredBookSource(
  id: 'org.example.books',
  name: 'Example Books',
  description: 'Example source',
  manifestUrl: Uri.parse(
    'https://example.org/.well-known/open-reading-source.json',
  ),
  apiBaseUrl: Uri.parse('https://example.org/api/'),
  iconUrl: Uri.parse('https://example.org/icon.png'),
  websiteUrl: Uri.parse('https://example.org'),
  operatorName: 'Example Library',
  contactUrl: Uri.parse('https://example.org/contact'),
  contentLicense: 'CC BY 4.0',
  rightsStatement: 'Licensed catalog.',
  protocolVersion: '1.4',
  languages: const ['en'],
  capabilities: const {'search', 'detail', 'catalog', 'content'},
  maxCatalogPageSize: 200,
  enabled: true,
  addedAt: DateTime.utc(2026, 7, 11),
);

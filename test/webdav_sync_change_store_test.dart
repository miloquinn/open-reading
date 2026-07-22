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

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await WebDavSyncSchemaMigration.migrate(database);
    store = SyncChangeStore(database: () async => database);
  });

  tearDown(() => database.close());

  test('remote LWW applies newer HLC and is idempotent', () async {
    final clock = HybridLogicalClock(deviceId: 'local', nowMillis: () => 1000);
    await store.recordLocal(
      dataset: 'progress',
      recordId: 'book-1',
      entityKey: 'book-1',
      payload: const {
        'canonical_locator': {'progression': 0.2}
      },
      deleted: false,
      clock: clock,
    );
    final batch = SyncBatch.create(
      deviceId: 'remote',
      sequence: 1,
      createdHlc: '2000-0000-remote',
      operations: const [
        SyncOperation(
          dataset: 'progress',
          recordId: 'book-1',
          entityKey: 'book-1',
          hlc: '2000-0000-remote',
          deleted: false,
          payload: {
            'canonical_locator': {'progression': 0.1},
          },
        ),
      ],
    );
    var businessApplies = 0;

    expect(
      await store.applyRemoteBatch(
        batch,
        applyWinner: (_, __) async => businessApplies++,
      ),
      1,
    );
    expect(
      await store.applyRemoteBatch(
        batch,
        applyWinner: (_, __) async => businessApplies++,
      ),
      0,
    );
    final record = (await store.recordsForDataset('progress')).single;
    expect(record.payload!['canonical_locator'], {'progression': 0.1});
    expect(record.dirty, isFalse);
    expect(businessApplies, 1);
    expect(await store.cursorFor('remote'), 1);
  });

  test('canonical payload comparison does not create false local changes',
      () async {
    final clock = HybridLogicalClock(deviceId: 'local', nowMillis: () => 1000);
    await store.recordLocal(
      dataset: 'books',
      recordId: 'book-1',
      entityKey: 'book-1',
      payload: const {'title': 'A', 'author': 'B'},
      deleted: false,
      clock: clock,
    );
    await store.markUploaded(await store.dirtyRecords());
    await store.recordLocal(
      dataset: 'books',
      recordId: 'book-1',
      entityKey: 'book-1',
      payload: const {'author': 'B', 'title': 'A'},
      deleted: false,
      clock: clock,
    );

    expect(await store.pendingCount(), 0);
    expect((await store.latestTimestamp()).toString(), '1000-0000-local');
  });

  test('unsupported remote dataset is retained without materialization',
      () async {
    final notesAdapter = _RecordingAdapter('notes');
    final adapters = MetadataSyncAdapters(
      store: store,
      registeredAdapters: [notesAdapter],
    );
    final batch = SyncBatch.create(
      deviceId: 'future-device',
      sequence: 1,
      createdHlc: '2000-0000-future-device',
      operations: const [
        SyncOperation(
          dataset: 'notes',
          recordId: 'note-1',
          entityKey: 'book-1',
          hlc: '2000-0000-future-device',
          deleted: false,
          payload: {'content': 'reserved future payload'},
        ),
      ],
    );

    expect(
      await store.applyRemoteBatch(batch, applyWinner: adapters.apply),
      1,
    );
    final retained = (await store.recordsForDataset('notes')).single;
    expect(retained.recordId, 'note-1');
    expect(retained.dirty, isFalse);
    expect(notesAdapter.applyCount, 0);
    expect(await store.cursorFor('future-device'), 1);
  });

  test('book file payload exposes the content-addressed cover reference', () {
    expect(
      bookFileSyncPayload(const {
        'file_size': 10,
        'file_name': 'book.txt',
        'blob_sha256': 'book-hash',
        'remote_path': 'blobs/books/book-hash',
        'cover_blob_sha256': 'cover-hash',
        'cover_file_name': 'cover.img',
        'cover_file_size': 5,
        'cover_remote_path': 'blobs/covers/cover-hash',
      }),
      {
        'file_available': true,
        'file_size': 10,
        'file_name': 'book.txt',
        'blob_sha256': 'book-hash',
        'remote_path': 'blobs/books/book-hash',
        'cover_available': true,
        'cover_blob_sha256': 'cover-hash',
        'cover_file_name': 'cover.img',
        'cover_file_size': 5,
        'cover_remote_path': 'blobs/covers/cover-hash',
      },
    );
  });
}

class _RecordingAdapter implements MetadataSyncAdapter {
  _RecordingAdapter(this.dataset);

  @override
  final String dataset;

  int applyCount = 0;

  @override
  Future<void> apply(Transaction txn, SyncOperation operation) async {
    applyCount++;
  }

  @override
  Future<void> scan(HybridLogicalClock clock) async {}
}

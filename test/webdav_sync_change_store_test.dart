import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/data/migration/webdav_sync_schema_migration.dart';
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
}

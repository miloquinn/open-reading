import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/database_service.dart';
import 'sync_clock.dart';
import 'sync_protocol.dart';

class SyncRecord {
  const SyncRecord({
    required this.dataset,
    required this.recordId,
    required this.entityKey,
    required this.payload,
    required this.hlc,
    required this.deleted,
    required this.dirty,
  });

  final String dataset;
  final String recordId;
  final String entityKey;
  final Map<String, dynamic>? payload;
  final String hlc;
  final bool deleted;
  final bool dirty;

  SyncOperation toOperation() => SyncOperation(
    dataset: dataset,
    recordId: recordId,
    entityKey: entityKey,
    hlc: hlc,
    deleted: deleted,
    payload: payload,
  );

  factory SyncRecord.fromMap(Map<String, Object?> map) => SyncRecord(
    dataset: map['dataset']! as String,
    recordId: map['record_id']! as String,
    entityKey: map['entity_key']! as String,
    payload: map['payload_json'] == null
        ? null
        : (jsonDecode(map['payload_json']! as String) as Map)
              .cast<String, dynamic>(),
    hlc: map['hlc']! as String,
    deleted: map['deleted'] == 1,
    dirty: map['dirty'] == 1,
  );
}

class SyncChangeStore {
  SyncChangeStore({
    DatabaseService? databaseService,
    Future<Database> Function()? database,
  }) : _databaseService = databaseService ?? DatabaseService(),
       _databaseProvider = database;

  final DatabaseService _databaseService;
  final Future<Database> Function()? _databaseProvider;

  Future<Database> get _db =>
      _databaseProvider?.call() ?? _databaseService.database;

  Future<String?> getState(String key) async {
    final db = await _db;
    final rows = await db.query(
      'sync_local_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setState(String key, String value) async {
    final db = await _db;
    await db.insert('sync_local_state', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> cursorFor(String deviceId) async {
    final db = await _db;
    final rows = await db.query(
      'sync_device_cursors',
      columns: ['applied_sequence'],
      where: 'remote_device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.first['applied_sequence'] as int;
  }

  Future<List<SyncRecord>> recordsForDataset(String dataset) async {
    final db = await _db;
    final rows = await db.query(
      'sync_records',
      where: 'dataset = ?',
      whereArgs: [dataset],
    );
    return rows.map(SyncRecord.fromMap).toList(growable: false);
  }

  Future<List<SyncRecord>> dirtyRecords({int limit = 500}) async {
    final db = await _db;
    final rows = await db.query(
      'sync_records',
      where: 'dirty = 1',
      orderBy: 'dataset, record_id',
      limit: limit,
    );
    return rows.map(SyncRecord.fromMap).toList(growable: false);
  }

  Future<int> pendingCount() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_records WHERE dirty = 1',
    );
    return (rows.first['count'] as num).toInt();
  }

  Future<HybridLogicalTimestamp?> latestTimestamp() async {
    final db = await _db;
    final rows = await db.query('sync_records', columns: ['hlc']);
    HybridLogicalTimestamp? latest;
    for (final row in rows) {
      final timestamp = HybridLogicalTimestamp.parse(row['hlc']! as String);
      if (latest == null || timestamp.compareTo(latest) > 0) {
        latest = timestamp;
      }
    }
    return latest;
  }

  /// Records a local snapshot only when its protocol representation changed.
  Future<void> recordLocal({
    required String dataset,
    required String recordId,
    required String entityKey,
    required Map<String, dynamic>? payload,
    required bool deleted,
    required HybridLogicalClock clock,
  }) async {
    final db = await _db;
    final payloadJson = payload == null ? null : jsonEncode(payload);
    final rows = await db.query(
      'sync_records',
      where: 'dataset = ? AND record_id = ?',
      whereArgs: [dataset, recordId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final current = rows.first;
      final currentPayload = current['payload_json'] == null
          ? null
          : jsonDecode(current['payload_json']! as String);
      if (current['entity_key'] == entityKey &&
          sha256OfCanonicalJson(currentPayload) ==
              sha256OfCanonicalJson(payload) &&
          (current['deleted'] == 1) == deleted) {
        await setState('locally_observed:$dataset:$recordId', '1');
        return;
      }
    }
    await db.insert('sync_records', {
      'dataset': dataset,
      'record_id': recordId,
      'entity_key': entityKey,
      'payload_json': payloadJson,
      'hlc': clock.tick().toString(),
      'deleted': deleted ? 1 : 0,
      'dirty': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await setState('locally_observed:$dataset:$recordId', '1');
  }

  Future<int> applyRemoteBatch(
    SyncBatch batch, {
    required Future<void> Function(Transaction txn, SyncOperation operation)
    applyWinner,
  }) async {
    final db = await _db;
    var applied = 0;
    await db.transaction((txn) async {
      for (final operation in batch.operations) {
        final rows = await txn.query(
          'sync_records',
          where: 'dataset = ? AND record_id = ?',
          whereArgs: [operation.dataset, operation.recordId],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final local = SyncRecord.fromMap(rows.first);
          if (HybridLogicalTimestamp.parse(
                local.hlc,
              ).compareTo(HybridLogicalTimestamp.parse(operation.hlc)) >=
              0) {
            continue;
          }
        }
        await txn.insert('sync_records', {
          'dataset': operation.dataset,
          'record_id': operation.recordId,
          'entity_key': operation.entityKey,
          'payload_json': operation.payload == null
              ? null
              : jsonEncode(operation.payload),
          'hlc': operation.hlc,
          'deleted': operation.deleted ? 1 : 0,
          'dirty': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await applyWinner(txn, operation);
        applied++;
      }
      await txn.insert('sync_device_cursors', {
        'remote_device_id': batch.deviceId,
        'applied_sequence': batch.sequence,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return applied;
  }

  Future<void> markUploaded(List<SyncRecord> records) async {
    if (records.isEmpty) return;
    final db = await _db;
    await db.transaction((txn) async {
      for (final record in records) {
        await txn.update(
          'sync_records',
          {'dirty': 0},
          where: 'dataset = ? AND record_id = ? AND hlc = ?',
          whereArgs: [record.dataset, record.recordId, record.hlc],
        );
      }
    });
  }
}

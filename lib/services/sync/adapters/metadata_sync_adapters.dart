import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/database_service.dart';
import '../sync_change_store.dart';
import '../sync_clock.dart';
import '../sync_dataset_catalog.dart';
import '../sync_models.dart';
import '../sync_protocol.dart';

abstract interface class MetadataSyncAdapter {
  String get dataset;
  Future<void> scan(HybridLogicalClock clock);
  Future<void> apply(Transaction txn, SyncOperation operation);
}

class MetadataSyncAdapters {
  MetadataSyncAdapters({
    required SyncChangeStore store,
    DatabaseService? databaseService,
    Iterable<MetadataSyncAdapter>? registeredAdapters,
  })  : _databaseService = databaseService ?? DatabaseService(),
        _store = store,
        adapters = registeredAdapters == null
            ? []
            : List<MetadataSyncAdapter>.of(registeredAdapters) {
    if (registeredAdapters == null) {
      adapters.addAll([
        BooksSyncAdapter(store, _databaseService),
        ProgressSyncAdapter(store, _databaseService),
        BookmarksSyncAdapter(store, _databaseService),
        NotesSyncAdapter(store, _databaseService),
        ReadingSessionsSyncAdapter(store, _databaseService),
      ]);
    }
  }

  final DatabaseService _databaseService;
  final SyncChangeStore _store;
  final List<MetadataSyncAdapter> adapters;

  Future<void> scan(WebDavSyncScope scope, HybridLogicalClock clock) async {
    for (final adapter in adapters) {
      final dataset = SyncDataset.fromRemoteName(adapter.dataset);
      if (dataset == null || !SyncDatasetCatalog.isEnabled(dataset, scope)) {
        continue;
      }
      await _materializePreviouslyRemoteRecords(adapter);
      await adapter.scan(clock);
    }
  }

  Future<void> _materializePreviouslyRemoteRecords(
    MetadataSyncAdapter adapter,
  ) async {
    final records = await _store.recordsForDataset(adapter.dataset);
    final pending = <SyncRecord>[];
    for (final record in records) {
      final observed = await _store.getState(
        'locally_observed:${adapter.dataset}:${record.recordId}',
      );
      // A previously observed record that disappeared locally represents a
      // real local deletion. Re-applying it here would resurrect it before the
      // scanner can emit its tombstone.
      if (observed != '1') pending.add(record);
    }
    if (pending.isEmpty) return;
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      for (final record in pending) {
        await adapter.apply(txn, record.toOperation());
      }
    });
  }

  Future<void> apply(Transaction txn, SyncOperation operation) async {
    final dataset = SyncDataset.fromRemoteName(operation.dataset);
    if (dataset == null || !SyncDatasetCatalog.isSupported(dataset)) return;
    final adapter = adapters.where((item) => item.dataset == operation.dataset);
    if (adapter.isNotEmpty) await adapter.first.apply(txn, operation);
  }
}

abstract class _BaseAdapter implements MetadataSyncAdapter {
  _BaseAdapter(this.store, this.databaseService);

  final SyncChangeStore store;
  final DatabaseService databaseService;

  Future<Map<int, String>> bookUids() async {
    final db = await databaseService.database;
    final rows = await db.query('books');
    final result = <int, String>{};
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id != null) result[id] = await bookUidForMap(row);
    }
    return result;
  }

  Future<int?> localBookId(DatabaseExecutor db, String bookUid) async {
    final rows = await db.query('books');
    for (final row in rows) {
      if (await bookUidForMap(row) == bookUid) return row['id'] as int?;
    }
    return null;
  }

  Future<void> tombstoneMissing(
    Set<String> seen,
    HybridLogicalClock clock,
  ) async {
    for (final record in await store.recordsForDataset(dataset)) {
      final locallyObserved =
          await store.getState('locally_observed:$dataset:${record.recordId}');
      if (!record.deleted &&
          locallyObserved == '1' &&
          !seen.contains(record.recordId)) {
        await store.recordLocal(
          dataset: dataset,
          recordId: record.recordId,
          entityKey: record.entityKey,
          payload: record.payload,
          deleted: true,
          clock: clock,
        );
      }
    }
  }
}

class BooksSyncAdapter extends _BaseAdapter {
  BooksSyncAdapter(super.store, super.databaseService);

  @override
  String get dataset => 'books';

  @override
  Future<void> scan(HybridLogicalClock clock) async {
    final db = await databaseService.database;
    final rows = await db.query('books');
    final seen = <String>{};
    for (final row in rows) {
      final uid = await bookUidForMap(row);
      seen.add(uid);
      final fileRows = await db.query(
        'sync_book_files',
        where: 'book_uid = ? AND sync_enabled = 1',
        whereArgs: [uid],
        limit: 1,
      );
      final file = fileRows.isEmpty ? null : fileRows.first;
      await store.recordLocal(
        dataset: dataset,
        recordId: uid,
        entityKey: uid,
        payload: {
          'book_uid': uid,
          'title': row['title'],
          'author': row['author'],
          'format': row['format'],
          'storage_type': row['storage_type'],
          'source_id': row['source_id'],
          'source_book_id': row['source_book_id'],
          ...bookFileSyncPayload(file),
        },
        deleted: false,
        clock: clock,
      );
    }
    await tombstoneMissing(seen, clock);
  }

  @override
  Future<void> apply(Transaction txn, SyncOperation operation) async {
    final id = await localBookId(txn, operation.entityKey);
    if (id == null || operation.deleted || operation.payload == null) return;
    await txn.update(
      'books',
      {
        'title': operation.payload!['title'],
        'author': operation.payload!['author'],
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

Map<String, Object?> bookFileSyncPayload(Map<String, Object?>? file) {
  if (file == null) return const {};
  return {
    'file_available': true,
    'file_size': file['file_size'],
    'file_name': file['file_name'],
    'blob_sha256': file['blob_sha256'],
    'remote_path': file['remote_path'],
    if (file['cover_remote_path'] != null) 'cover_available': true,
    if (file['cover_file_size'] != null)
      'cover_file_size': file['cover_file_size'],
    if (file['cover_file_name'] != null)
      'cover_file_name': file['cover_file_name'],
    if (file['cover_blob_sha256'] != null)
      'cover_blob_sha256': file['cover_blob_sha256'],
    if (file['cover_remote_path'] != null)
      'cover_remote_path': file['cover_remote_path'],
  };
}

class ProgressSyncAdapter extends _BaseAdapter {
  ProgressSyncAdapter(super.store, super.databaseService);

  @override
  String get dataset => 'progress';

  @override
  Future<void> scan(HybridLogicalClock clock) async {
    final db = await databaseService.database;
    final rows = await db.query(
      'books',
      where: 'last_canonical_locator IS NOT NULL',
    );
    final seen = <String>{};
    for (final row in rows) {
      final uid = await bookUidForMap(row);
      seen.add(uid);
      dynamic locator;
      try {
        locator = jsonDecode(row['last_canonical_locator'] as String);
      } catch (_) {
        continue;
      }
      await store.recordLocal(
        dataset: dataset,
        recordId: uid,
        entityKey: uid,
        payload: {'book_uid': uid, 'canonical_locator': locator},
        deleted: false,
        clock: clock,
      );
    }
    await tombstoneMissing(seen, clock);
  }

  @override
  Future<void> apply(Transaction txn, SyncOperation operation) async {
    final id = await localBookId(txn, operation.entityKey);
    if (id == null) return;
    await txn.update(
      'books',
      {
        'last_canonical_locator': operation.deleted
            ? null
            : jsonEncode(operation.payload?['canonical_locator']),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class BookmarksSyncAdapter extends _BaseAdapter {
  BookmarksSyncAdapter(super.store, super.databaseService);

  @override
  String get dataset => 'bookmarks';

  @override
  Future<void> scan(HybridLogicalClock clock) async {
    final db = await databaseService.database;
    final uids = await bookUids();
    final rows = await db.query('bookmarks');
    final seen = <String>{};
    for (final row in rows) {
      final bookUid = uids[row['bookId']];
      if (bookUid == null) continue;
      final identity =
          '$bookUid|${row['anchor_key'] ?? row['cfi'] ?? row['canonical_locator'] ?? row['pageNumber']}|${row['createDate']}';
      final recordId = stableRecordId('bookmark', identity);
      seen.add(recordId);
      await store.recordLocal(
        dataset: dataset,
        recordId: recordId,
        entityKey: bookUid,
        payload: {
          'book_uid': bookUid,
          'page_number': row['pageNumber'],
          'note': row['note'],
          'create_date': row['createDate'],
          'cfi': row['cfi'],
          'canonical_locator': _decodeOptionalJson(row['canonical_locator']),
          'anchor_key': row['anchor_key'],
          'chapter_index': row['chapter_index'],
          'chapter_title': row['chapter_title'],
          'excerpt': row['excerpt'],
        },
        deleted: false,
        clock: clock,
      );
    }
    await tombstoneMissing(seen, clock);
  }

  @override
  Future<void> apply(Transaction txn, SyncOperation operation) async {
    final payload = operation.payload;
    if (payload == null) return;
    final bookId = await localBookId(txn, operation.entityKey);
    if (bookId == null) return;
    final localRows = await txn.query(
      'bookmarks',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
    int? existingId;
    for (final row in localRows) {
      final identity =
          '${operation.entityKey}|${row['anchor_key'] ?? row['cfi'] ?? row['canonical_locator'] ?? row['pageNumber']}|${row['createDate']}';
      if (stableRecordId('bookmark', identity) == operation.recordId) {
        existingId = row['id'] as int?;
        break;
      }
    }
    if (operation.deleted) {
      if (existingId != null) {
        await txn.delete(
          'bookmarks',
          where: 'id = ?',
          whereArgs: [existingId],
        );
      }
      return;
    }
    final values = {
      'bookId': bookId,
      'pageNumber': payload['page_number'],
      'note': payload['note'],
      'createDate': payload['create_date'],
      'cfi': payload['cfi'],
      'canonical_locator': payload['canonical_locator'] == null
          ? null
          : jsonEncode(payload['canonical_locator']),
      'anchor_key': payload['anchor_key'],
      'chapter_index': payload['chapter_index'],
      'chapter_title': payload['chapter_title'],
      'excerpt': payload['excerpt'],
    };
    if (existingId == null) {
      await txn.insert('bookmarks', values);
    } else {
      await txn.update(
        'bookmarks',
        values,
        where: 'id = ?',
        whereArgs: [existingId],
      );
    }
  }
}

class NotesSyncAdapter extends _BaseAdapter {
  NotesSyncAdapter(super.store, super.databaseService);

  @override
  String get dataset => 'notes';

  @override
  Future<void> scan(HybridLogicalClock clock) async {
    final db = await databaseService.database;
    final uids = await bookUids();
    final rows = await db.query('book_notes');
    final seen = <String>{};
    for (final row in rows) {
      final bookUid = uids[row['book_id']];
      if (bookUid == null) continue;
      final recordId = stableRecordId(
        'note',
        '$bookUid|${row['cfi']}|${row['create_time'] ?? row['update_time']}',
      );
      seen.add(recordId);
      await store.recordLocal(
        dataset: dataset,
        recordId: recordId,
        entityKey: bookUid,
        payload: {
          'book_uid': bookUid,
          'content': row['content'],
          'cfi': row['cfi'],
          'chapter': row['chapter'],
          'type': row['type'],
          'color': row['color'],
          'reader_note': row['reader_note'],
          'page_number': row['page_number'],
          'start_offset': row['start_offset'],
          'end_offset': row['end_offset'],
          'canonical_locator': _decodeOptionalJson(row['canonical_locator']),
          'create_time': row['create_time'],
          'update_time': row['update_time'],
        },
        deleted: false,
        clock: clock,
      );
    }
    await tombstoneMissing(seen, clock);
  }

  @override
  Future<void> apply(Transaction txn, SyncOperation operation) async {
    final payload = operation.payload;
    if (payload == null) return;
    final bookId = await localBookId(txn, operation.entityKey);
    if (bookId == null) return;
    final localRows = await txn.query(
      'book_notes',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    int? existingId;
    for (final row in localRows) {
      final identity =
          '${operation.entityKey}|${row['cfi']}|${row['create_time'] ?? row['update_time']}';
      if (stableRecordId('note', identity) == operation.recordId) {
        existingId = row['id'] as int?;
        break;
      }
    }
    if (operation.deleted) {
      if (existingId != null) {
        await txn.delete(
          'book_notes',
          where: 'id = ?',
          whereArgs: [existingId],
        );
      }
      return;
    }
    final values = {
      'book_id': bookId,
      'content': payload['content'],
      'cfi': payload['cfi'],
      'chapter': payload['chapter'],
      'type': payload['type'],
      'color': payload['color'],
      'reader_note': payload['reader_note'],
      'page_number': payload['page_number'],
      'start_offset': payload['start_offset'],
      'end_offset': payload['end_offset'],
      'canonical_locator': payload['canonical_locator'] == null
          ? null
          : jsonEncode(payload['canonical_locator']),
      'create_time': payload['create_time'],
      'update_time': payload['update_time'],
    };
    if (existingId == null) {
      await txn.insert('book_notes', values);
    } else {
      await txn.update(
        'book_notes',
        values,
        where: 'id = ?',
        whereArgs: [existingId],
      );
    }
  }
}

class ReadingSessionsSyncAdapter extends _BaseAdapter {
  ReadingSessionsSyncAdapter(super.store, super.databaseService);

  @override
  String get dataset => 'reading_sessions';

  @override
  Future<void> scan(HybridLogicalClock clock) async {
    final db = await databaseService.database;
    final uids = await bookUids();
    final rows = await db.query('reading_sessions');
    final seen = <String>{};
    for (final row in rows) {
      final bookUid = row['bookId'] == null ? null : uids[row['bookId']];
      final recordId = stableRecordId(
        'session',
        '${bookUid ?? 'unknown'}|${row['startTimeMs']}|${row['endTimeMs']}',
      );
      seen.add(recordId);
      await store.recordLocal(
        dataset: dataset,
        recordId: recordId,
        entityKey: bookUid ?? 'unknown',
        payload: {
          'book_uid': bookUid,
          'date': row['date'],
          'start_time_ms': row['startTimeMs'],
          'end_time_ms': row['endTimeMs'],
          'duration_seconds': row['durationInSeconds'],
          'pages_read': row['pagesRead'],
        },
        deleted: false,
        clock: clock,
      );
    }
    // Sessions are append-only. A missing local row must not delete a remote event.
  }

  @override
  Future<void> apply(Transaction txn, SyncOperation operation) async {
    if (operation.deleted || operation.payload == null) return;
    final payload = operation.payload!;
    final bookUid = payload['book_uid'] as String?;
    final bookId = bookUid == null ? null : await localBookId(txn, bookUid);
    final existing = await txn.query(
      'reading_sessions',
      columns: ['id'],
      where: 'startTimeMs = ? AND endTimeMs = ? AND '
          '((bookId IS NULL AND ? IS NULL) OR bookId = ?)',
      whereArgs: [
        payload['start_time_ms'],
        payload['end_time_ms'],
        bookId,
        bookId
      ],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    await txn.insert('reading_sessions', {
      'date': payload['date'],
      'bookId': bookId,
      'startTimeMs': payload['start_time_ms'],
      'endTimeMs': payload['end_time_ms'],
      'durationInSeconds': payload['duration_seconds'],
      'pagesRead': payload['pages_read'],
    });
  }
}

Future<String> bookUidForMap(Map<String, Object?> row) async {
  final sourceId = row['source_id'] as String?;
  final sourceBookId = row['source_book_id'] as String?;
  if (sourceId != null &&
      sourceId.isNotEmpty &&
      sourceBookId != null &&
      sourceBookId.isNotEmpty) {
    return 'source:$sourceId:$sourceBookId';
  }
  final path = row['filePath'] as String?;
  if (path != null && path.isNotEmpty) {
    final file = File(path);
    try {
      if (await file.exists()) {
        final stat = await file.stat();
        final cacheKey =
            '$path|${stat.modified.millisecondsSinceEpoch}|${stat.size}';
        final cached = _bookUidCache[cacheKey];
        if (cached != null) return cached;
        final digest = await sha256.bind(file.openRead()).first;
        final uid = 'sha256:$digest';
        _bookUidCache[cacheKey] = uid;
        return uid;
      }
    } on FileSystemException {
      // Android document providers and files removed between exists/stat/read
      // can become temporarily inaccessible. Fall back to the persisted hash
      // or metadata identity instead of failing the entire metadata sync.
    }
  }
  final legacy = row['content_hash'] as String?;
  if (legacy != null && legacy.isNotEmpty) return 'legacy-hash:$legacy';
  return 'local-meta:${sha256.convert(utf8.encode('${row['title']}|${row['author']}|${row['format']}|${row['importDate']}'))}';
}

final Map<String, String> _bookUidCache = <String, String>{};

String stableRecordId(String type, String identity) {
  final hex = sha256.convert(utf8.encode('$type\u0000$identity')).toString();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-5${hex.substring(13, 16)}-a${hex.substring(17, 20)}-${hex.substring(20, 32)}';
}

Object? _decodeOptionalJson(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

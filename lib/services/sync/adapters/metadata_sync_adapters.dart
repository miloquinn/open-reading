import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../book_sources/models/registered_book_source.dart';
import '../../../book_sources/services/book_source_reading_progress.dart';
import '../../../book_sources/services/book_source_registry.dart';
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

typedef SyncDatabaseProvider = Future<Database> Function();

class MetadataSyncAdapters {
  MetadataSyncAdapters({
    required SyncChangeStore store,
    DatabaseService? databaseService,
    SyncDatabaseProvider? database,
    BookSourceRegistry? bookSourceRegistry,
    BookSourceReadingProgressStore? sourceProgressStore,
    Iterable<MetadataSyncAdapter>? registeredAdapters,
  }) : _databaseProvider =
           database ?? (() => (databaseService ?? DatabaseService()).database),
       _store = store,
       adapters = registeredAdapters == null
           ? []
           : List<MetadataSyncAdapter>.of(registeredAdapters) {
    if (registeredAdapters == null) {
      final registry = bookSourceRegistry ?? BookSourceRegistry();
      final progressStore =
          sourceProgressStore ?? const BookSourceReadingProgressStore();
      adapters.addAll([
        BookSourcesSyncAdapter(store, registry),
        BooksSyncAdapter(store, _databaseProvider),
        ProgressSyncAdapter(store, _databaseProvider, progressStore),
        BookmarksSyncAdapter(store, _databaseProvider),
        NotesSyncAdapter(store, _databaseProvider),
        ReadingSessionsSyncAdapter(store, _databaseProvider),
      ]);
    }
  }

  final SyncDatabaseProvider _databaseProvider;
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
    final db = await _databaseProvider();
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
  _BaseAdapter(this.store, this.database);

  final SyncChangeStore store;
  final SyncDatabaseProvider database;

  Future<Map<int, String>> bookUids() async {
    final db = await database();
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
      final locallyObserved = await store.getState(
        'locally_observed:$dataset:${record.recordId}',
      );
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

class BookSourcesSyncAdapter implements MetadataSyncAdapter {
  BookSourcesSyncAdapter(this.store, this.registry);

  final SyncChangeStore store;
  final BookSourceRegistry registry;

  @override
  String get dataset => 'book_sources';

  @override
  Future<void> scan(HybridLogicalClock clock) async {
    final sources = await registry.load();
    final seen = <String>{};
    for (final source in sources) {
      final recordId = stableRecordId('book_source', source.id);
      seen.add(recordId);
      await store.recordLocal(
        dataset: dataset,
        recordId: recordId,
        entityKey: source.id,
        payload: source.toJson(),
        deleted: false,
        clock: clock,
      );
    }
    for (final record in await store.recordsForDataset(dataset)) {
      final locallyObserved = await store.getState(
        'locally_observed:$dataset:${record.recordId}',
      );
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

  @override
  Future<void> apply(Transaction txn, SyncOperation operation) async {
    if (operation.deleted) {
      await registry.remove(operation.entityKey);
      return;
    }
    final payload = operation.payload;
    if (payload == null) return;
    late final RegisteredBookSource source;
    try {
      source = RegisteredBookSource.fromJson(payload);
    } catch (_) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.corruptRemoteData,
        'A synced book source contains invalid data.',
      );
    }
    if (source.id != operation.entityKey ||
        operation.recordId != stableRecordId('book_source', source.id)) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.corruptRemoteData,
        'A synced book source has an invalid identity.',
      );
    }
    await registry.applySynced(source);
  }
}

class BooksSyncAdapter extends _BaseAdapter {
  BooksSyncAdapter(super.store, super.database);

  @override
  String get dataset => 'books';

  @override
  Future<void> scan(HybridLogicalClock clock) async {
    final db = await database();
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
          'import_date': row['importDate'],
          'storage_type': row['storage_type'],
          'source_id': row['source_id'],
          'source_book_id': row['source_book_id'],
          'source_json': row['source_json'],
          'source_book_json': row['source_book_json'],
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
    if (operation.deleted) {
      if (id == null) return;
      final rows = await txn.query(
        'books',
        columns: ['storage_type'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty && rows.first['storage_type'] == 'online') {
        await txn.delete('books', where: 'id = ?', whereArgs: [id]);
      }
      return;
    }
    final payload = operation.payload;
    if (payload == null) return;
    final sourceId = _nonEmptyString(payload['source_id']);
    final sourceBookId = _nonEmptyString(payload['source_book_id']);
    final sourceJson = _nonEmptyString(payload['source_json']);
    final sourceBookJson = _nonEmptyString(payload['source_book_json']);
    final restorableOnline =
        payload['storage_type'] == 'online' &&
        sourceId != null &&
        sourceBookId != null &&
        sourceJson != null &&
        sourceBookJson != null;
    if (id == null) {
      if (!restorableOnline) return;
      await txn.insert('books', {
        'title': _nonEmptyString(payload['title']) ?? 'Untitled',
        'author': payload['author'] as String? ?? '',
        'filePath': '',
        'format': _nonEmptyString(payload['format']) ?? 'source',
        'currentPage': 0,
        'totalPages': 1,
        'importDate':
            (payload['import_date'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        'storage_type': 'online',
        'source_id': sourceId,
        'source_book_id': sourceBookId,
        'source_json': sourceJson,
        'source_book_json': sourceBookJson,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return;
    }
    final rows = await txn.query(
      'books',
      columns: ['storage_type'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final values = <String, Object?>{
      'title': payload['title'],
      'author': payload['author'],
    };
    if (restorableOnline) {
      values.addAll({
        'source_id': sourceId,
        'source_book_id': sourceBookId,
        'source_json': sourceJson,
        'source_book_json': sourceBookJson,
      });
      if (rows.first['storage_type'] == 'online') {
        values.addAll({
          'filePath': '',
          'format': _nonEmptyString(payload['format']) ?? 'source',
          'storage_type': 'online',
        });
      }
    }
    await txn.update('books', values, where: 'id = ?', whereArgs: [id]);
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
  ProgressSyncAdapter(super.store, super.database, this.progressStore);

  final BookSourceReadingProgressStore progressStore;

  @override
  String get dataset => 'progress';

  @override
  Future<void> scan(HybridLogicalClock clock) async {
    final db = await database();
    final rows = await db.query('books');
    final seen = <String>{};
    for (final row in rows) {
      final uid = await bookUidForMap(row);
      final locator = _decodeOptionalJson(row['last_canonical_locator']);
      BookSourceReadingProgress? sourceProgress;
      final sourceId = _nonEmptyString(row['source_id']);
      final sourceBookId = _nonEmptyString(row['source_book_id']);
      if (row['storage_type'] == 'online' &&
          sourceId != null &&
          sourceBookId != null) {
        sourceProgress = await progressStore.load(
          sourceId: sourceId,
          bookId: sourceBookId,
        );
      }
      final readingProgress = (row['reading_progress'] as num?)?.toDouble();
      if (locator == null &&
          sourceProgress == null &&
          readingProgress == null) {
        continue;
      }
      seen.add(uid);
      final payload = <String, dynamic>{'book_uid': uid};
      if (locator != null) payload['canonical_locator'] = locator;
      if (readingProgress != null) {
        payload['reading_progress'] = readingProgress;
      }
      if (sourceProgress != null) {
        payload.addAll({
          'source_progress': sourceProgress.toJson(),
          'current_page': row['currentPage'],
          'total_pages': row['totalPages'],
        });
      }
      await store.recordLocal(
        dataset: dataset,
        recordId: uid,
        entityKey: uid,
        payload: payload,
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
    final rows = await txn.query(
      'books',
      columns: ['storage_type', 'source_id', 'source_book_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final row = rows.first;
    final sourceId = _nonEmptyString(row['source_id']);
    final sourceBookId = _nonEmptyString(row['source_book_id']);
    if (operation.deleted) {
      final values = <String, Object?>{'last_canonical_locator': null};
      if (row['storage_type'] == 'online') values['currentPage'] = 0;
      await txn.update('books', values, where: 'id = ?', whereArgs: [id]);
      if (row['storage_type'] == 'online' &&
          sourceId != null &&
          sourceBookId != null) {
        await progressStore.delete(sourceId: sourceId, bookId: sourceBookId);
      }
      return;
    }
    final payload = operation.payload;
    if (payload == null) return;
    final values = <String, Object?>{};
    if (payload.containsKey('canonical_locator')) {
      values['last_canonical_locator'] = jsonEncode(
        payload['canonical_locator'],
      );
    }
    if (payload['reading_progress'] is num) {
      values['reading_progress'] = (payload['reading_progress'] as num)
          .toDouble()
          .clamp(0.0, 1.0);
    }
    final rawSourceProgress = payload['source_progress'];
    if (row['storage_type'] == 'online' &&
        sourceId != null &&
        sourceBookId != null &&
        rawSourceProgress is Map) {
      final sourceProgress = BookSourceReadingProgress.fromJson(
        rawSourceProgress.map((key, value) => MapEntry('$key', value)),
      );
      await progressStore.save(
        sourceId: sourceId,
        bookId: sourceBookId,
        progress: sourceProgress,
      );
      values['currentPage'] = (payload['current_page'] as num?)?.toInt() ?? 0;
      values['totalPages'] = (payload['total_pages'] as num?)?.toInt() ?? 1;
    }
    if (values.isNotEmpty) {
      await txn.update('books', values, where: 'id = ?', whereArgs: [id]);
    }
  }
}

class BookmarksSyncAdapter extends _BaseAdapter {
  BookmarksSyncAdapter(super.store, super.database);

  @override
  String get dataset => 'bookmarks';

  @override
  Future<void> scan(HybridLogicalClock clock) async {
    final db = await database();
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
        await txn.delete('bookmarks', where: 'id = ?', whereArgs: [existingId]);
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
  NotesSyncAdapter(super.store, super.database);

  @override
  String get dataset => 'notes';

  @override
  Future<void> scan(HybridLogicalClock clock) async {
    final db = await database();
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
          'annotation_id': row['annotation_id'],
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
          'payload_json': _decodeOptionalJson(row['payload_json']),
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
    final annotationId =
        _nonEmptyString(payload['annotation_id']) ?? operation.recordId;
    int? existingId;
    for (final row in localRows) {
      if (row['annotation_id'] == annotationId) {
        existingId = row['id'] as int?;
        break;
      }
    }
    for (final row in localRows) {
      if (existingId != null) break;
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
      'annotation_id': annotationId,
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
      'payload_json': payload['payload_json'] == null
          ? null
          : jsonEncode(payload['payload_json']),
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
  ReadingSessionsSyncAdapter(super.store, super.database);

  @override
  String get dataset => 'reading_sessions';

  @override
  Future<void> scan(HybridLogicalClock clock) async {
    final db = await database();
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
      where:
          'startTimeMs = ? AND endTimeMs = ? AND '
          '((bookId IS NULL AND ? IS NULL) OR bookId = ?)',
      whereArgs: [
        payload['start_time_ms'],
        payload['end_time_ms'],
        bookId,
        bookId,
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

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : value;
}

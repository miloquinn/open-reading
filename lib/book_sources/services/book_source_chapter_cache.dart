import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../protocol/book_source_protocol.dart';

class BookSourceChapterCache {
  static const String directoryName = 'book_source_chapters';
  static const _memoryLimit = 24;
  static const _catalogMemoryLimit = 12;
  static const chapterRefreshAfter = Duration(hours: 12);
  static const chapterDiskLifetime = Duration(days: 30);
  static const catalogRefreshAfter = Duration(minutes: 30);
  static const catalogDiskLifetime = Duration(days: 30);
  static final Map<String, _CacheEntry<BookSourceChapterContent>> _memory = {};
  static final Map<String, _CacheEntry<List<BookSourceChapter>>>
  _catalogMemory = {};
  static final Map<String, Future<BookSourceChapterContent>> _inFlight = {};
  static final Map<String, Future<List<BookSourceChapter>>> _catalogInFlight =
      {};
  static final Map<String, Future<void>> _diskWriteQueues = {};
  static int _writeGeneration = 0;

  const BookSourceChapterCache({
    this.cacheDirectory,
    @visibleForTesting this.beforeDiskWrite,
  });

  final Directory? cacheDirectory;

  /// Allows tests to hold or fail persistence without coupling cache reads to
  /// the filesystem implementation.
  @visibleForTesting
  final Future<void> Function()? beforeDiskWrite;

  static void clearMemory() {
    _writeGeneration++;
    _memory.clear();
    _catalogMemory.clear();
  }

  Future<BookSourceChapterContent> getOrLoad({
    required String sourceId,
    String sourceRevision = '',
    required String bookId,
    required String chapterId,
    Duration refreshAfter = chapterRefreshAfter,
    bool staleWhileRevalidate = true,
    required Future<BookSourceChapterContent> Function() loader,
  }) async {
    final key = _key(sourceId, sourceRevision, bookId, chapterId);
    final memory = _memory.remove(key);
    if (memory != null) {
      _memory[key] = memory;
      return _resolveCachedContent(
        key,
        memory,
        refreshAfter: refreshAfter,
        staleWhileRevalidate: staleWhileRevalidate,
        loader: loader,
      );
    }

    final disk = await _readDisk(key);
    if (disk != null) {
      _remember(key, disk);
      return _resolveCachedContent(
        key,
        disk,
        refreshAfter: refreshAfter,
        staleWhileRevalidate: staleWhileRevalidate,
        loader: loader,
      );
    }
    return _loadContent(key, loader);
  }

  /// Returns a previously loaded chapter catalog without waiting for the
  /// source. Once the cached catalog is old enough, a refresh is started in
  /// the background so the next open sees additions without delaying this
  /// one. Catalogs remain usable while offline for up to 30 days.
  Future<List<BookSourceChapter>> getChapterCatalogOrLoad({
    required String sourceId,
    String sourceRevision = '',
    required String bookId,
    Duration refreshAfter = catalogRefreshAfter,
    required Future<List<BookSourceChapter>> Function() loader,
  }) async {
    final key = _key(sourceId, sourceRevision, bookId, 'catalog');
    final memory = _catalogMemory.remove(key);
    if (memory != null) {
      _catalogMemory[key] = memory;
      _refreshCatalogIfNeeded(
        key,
        memory,
        refreshAfter: refreshAfter,
        loader: loader,
      );
      return memory.value;
    }

    final disk = await _readCatalogDisk(key);
    if (disk != null) {
      _rememberCatalog(key, disk);
      _refreshCatalogIfNeeded(
        key,
        disk,
        refreshAfter: refreshAfter,
        loader: loader,
      );
      return disk.value;
    }
    return _loadCatalog(key, loader);
  }

  Future<BookSourceChapterContent> _resolveCachedContent(
    String key,
    _CacheEntry<BookSourceChapterContent> cached, {
    required Duration refreshAfter,
    required bool staleWhileRevalidate,
    required Future<BookSourceChapterContent> Function() loader,
  }) async {
    if (DateTime.now().difference(cached.cachedAt) < refreshAfter) {
      return cached.value;
    }
    if (!staleWhileRevalidate) return _loadContent(key, loader);
    unawaited(_refreshContent(key, loader));
    return cached.value;
  }

  Future<void> _refreshContent(
    String key,
    Future<BookSourceChapterContent> Function() loader,
  ) async {
    try {
      await _loadContent(key, loader);
    } catch (_) {
      // Previously read content remains usable while the source is offline.
    }
  }

  Future<BookSourceChapterContent> _loadContent(
    String key,
    Future<BookSourceChapterContent> Function() loader,
  ) async {
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final future = _fetchAndStoreContent(key, loader);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<BookSourceChapterContent> _fetchAndStoreContent(
    String key,
    Future<BookSourceChapterContent> Function() loader,
  ) async {
    final content = await loader();
    _remember(key, _CacheEntry(content, DateTime.now()));
    _scheduleDiskWrite(
      'chapter',
      key,
      (generation) => _writeDisk(key, content, generation),
    );
    return content;
  }

  void _scheduleDiskWrite(
    String scope,
    String key,
    Future<void> Function(int generation) writer,
  ) {
    final generation = _writeGeneration;
    final root = cacheDirectory?.absolute.path ?? '<default-cache-root>';
    final queueKey = '$root:$scope:$key';
    final previous = _diskWriteQueues[queueKey] ?? Future<void>.value();
    late final Future<void> next;
    next = previous.then((_) => writer(generation)).whenComplete(() {
      if (identical(_diskWriteQueues[queueKey], next)) {
        _diskWriteQueues.remove(queueKey);
      }
    });
    _diskWriteQueues[queueKey] = next;
    unawaited(next);
  }

  void _remember(String key, _CacheEntry<BookSourceChapterContent> content) {
    _memory[key] = content;
    while (_memory.length > _memoryLimit) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<_CacheEntry<BookSourceChapterContent>?> _readDisk(String key) async {
    try {
      final file = await _chapterFileFor(key);
      if (!await file.exists()) return null;
      final cachedAt = await file.lastModified();
      final age = DateTime.now().difference(cachedAt);
      if (age > chapterDiskLifetime) {
        await file.delete();
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      return _CacheEntry(
        BookSourceChapterContent.fromJson(
          decoded.map((key, value) => MapEntry('$key', value)),
        ),
        cachedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(
    String key,
    BookSourceChapterContent content,
    int generation,
  ) async {
    try {
      await beforeDiskWrite?.call();
      if (generation != _writeGeneration) return;
      final file = await _chapterFileFor(key);
      await _writeJsonAtomically(
        file,
        jsonEncode({
          'bookId': content.bookId,
          'chapterId': content.chapterId,
          'title': content.title,
          'content': content.content,
          'contentType': content.contentType,
        }),
        generation,
      );
    } catch (_) {
      // Cache failures must never interrupt reading.
    }
  }

  void _refreshCatalogIfNeeded(
    String key,
    _CacheEntry<List<BookSourceChapter>> cached, {
    required Duration refreshAfter,
    required Future<List<BookSourceChapter>> Function() loader,
  }) {
    if (DateTime.now().difference(cached.cachedAt) < refreshAfter) return;
    unawaited(_refreshCatalog(key, loader));
  }

  Future<void> _refreshCatalog(
    String key,
    Future<List<BookSourceChapter>> Function() loader,
  ) async {
    try {
      await _loadCatalog(key, loader);
    } catch (_) {
      // A stale catalog remains useful while a source is slow or offline.
    }
  }

  Future<List<BookSourceChapter>> _loadCatalog(
    String key,
    Future<List<BookSourceChapter>> Function() loader,
  ) async {
    final pending = _catalogInFlight[key];
    if (pending != null) return pending;
    final future = _fetchAndStoreCatalog(key, loader);
    _catalogInFlight[key] = future;
    try {
      return await future;
    } finally {
      _catalogInFlight.remove(key);
    }
  }

  Future<List<BookSourceChapter>> _fetchAndStoreCatalog(
    String key,
    Future<List<BookSourceChapter>> Function() loader,
  ) async {
    final chapters = List<BookSourceChapter>.unmodifiable(await loader());
    final entry = _CacheEntry(chapters, DateTime.now());
    _rememberCatalog(key, entry);
    _scheduleDiskWrite(
      'catalog',
      key,
      (generation) => _writeCatalogDisk(key, entry, generation),
    );
    return chapters;
  }

  void _rememberCatalog(
    String key,
    _CacheEntry<List<BookSourceChapter>> catalog,
  ) {
    _catalogMemory[key] = catalog;
    while (_catalogMemory.length > _catalogMemoryLimit) {
      _catalogMemory.remove(_catalogMemory.keys.first);
    }
  }

  Future<_CacheEntry<List<BookSourceChapter>>?> _readCatalogDisk(
    String key,
  ) async {
    try {
      final file = await _catalogFileFor(key);
      if (!await file.exists()) return null;
      final cachedAt = await file.lastModified();
      final age = DateTime.now().difference(cachedAt);
      if (age > catalogDiskLifetime) {
        await file.delete();
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map || decoded['items'] is! List) return null;
      final chapters = (decoded['items'] as List)
          .map(
            (item) => BookSourceChapter.fromJson(
              (item as Map).map((key, value) => MapEntry('$key', value)),
            ),
          )
          .toList(growable: false);
      return _CacheEntry(List.unmodifiable(chapters), cachedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCatalogDisk(
    String key,
    _CacheEntry<List<BookSourceChapter>> catalog,
    int generation,
  ) async {
    try {
      await beforeDiskWrite?.call();
      if (generation != _writeGeneration) return;
      final file = await _catalogFileFor(key);
      await _writeJsonAtomically(
        file,
        jsonEncode({
          'items': [
            for (final chapter in catalog.value)
              {
                'id': chapter.id,
                'title': chapter.title,
                'order': chapter.order,
                if (chapter.updatedAt != null)
                  'updatedAt': chapter.updatedAt!.toIso8601String(),
              },
          ],
        }),
        generation,
      );
    } catch (_) {
      // Cache failures must never interrupt reading.
    }
  }

  Future<void> _writeJsonAtomically(
    File file,
    String contents,
    int generation,
  ) async {
    if (generation != _writeGeneration) return;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp-$generation');
    await temporary.writeAsString(contents, flush: true);
    if (generation != _writeGeneration) {
      if (await temporary.exists()) await temporary.delete();
      return;
    }
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<Directory> _rootDirectory() async {
    final configuredDirectory = cacheDirectory;
    if (configuredDirectory != null) return configuredDirectory;
    final temp = await getTemporaryDirectory();
    return Directory(path.join(temp.path, directoryName));
  }

  Future<File> _chapterFileFor(String key) async {
    final root = await _rootDirectory();
    return File(path.join(root.path, '${_hash(key)}.json'));
  }

  Future<File> _catalogFileFor(String key) async {
    final root = await _rootDirectory();
    return File(path.join(root.path, 'catalogs', '${_hash(key)}.json'));
  }

  String _key(
    String sourceId,
    String sourceRevision,
    String bookId,
    String chapterId,
  ) =>
      '${cacheDirectory?.absolute.path ?? 'default'}\u0000'
      '$sourceId\u0000$sourceRevision\u0000$bookId\u0000$chapterId';

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
}

class _CacheEntry<T> {
  const _CacheEntry(this.value, this.cachedAt);

  final T value;
  final DateTime cachedAt;
}

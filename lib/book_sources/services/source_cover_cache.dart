import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef SourceCoverLoader = Future<Uint8List> Function(Uri uri);

class SourceCoverLoadException implements Exception {
  const SourceCoverLoadException(this.message, {this.transient = false});

  final String message;
  final bool transient;

  @override
  String toString() => message;
}

/// Shared remote-cover loader for ORSP books.
///
/// Requests are deduplicated by URL, bounded per process, retried once for
/// transient failures, and cached in the platform cache directory. The cache is
/// deliberately separate from saved shelf covers, so clearing it never removes
/// a user's library artwork.
class SourceCoverCache {
  SourceCoverCache({
    Dio? dio,
    SourceCoverLoader? loader,
    Directory? cacheDirectory,
    this.maxConcurrent = 4,
    this.retryDelay = const Duration(milliseconds: 350),
    this.maxDiskAge = const Duration(days: 7),
    this.maxImageBytes = 8 * 1024 * 1024,
    this.maxMemoryBytes = 24 * 1024 * 1024,
  }) : assert(maxConcurrent > 0),
       assert(maxImageBytes > 0),
       assert(maxMemoryBytes > 0),
       _cacheDirectory = cacheDirectory {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 8),
            responseType: ResponseType.bytes,
            headers: const {'Accept': 'image/*'},
          ),
        );
    _loader = loader ?? _download;
  }

  static final SourceCoverCache instance = SourceCoverCache();
  static const String directoryName = 'source_covers';

  final int maxConcurrent;
  final Duration retryDelay;
  final Duration maxDiskAge;
  final int maxImageBytes;
  final int maxMemoryBytes;
  final Directory? _cacheDirectory;

  late final Dio _dio;
  late final SourceCoverLoader _loader;
  final LinkedHashMap<String, Uint8List> _memory = LinkedHashMap();
  final Map<String, Future<Uint8List>> _inFlight = {};
  final Queue<Completer<void>> _waiters = Queue();
  final Map<String, int> _keyEpochs = {};
  int _active = 0;
  int _memoryBytes = 0;
  int _cacheEpoch = 0;

  int get activeRequests => _active;
  int get memorySizeBytes => _memoryBytes;

  Future<Uint8List> load(Uri uri) {
    _validateUri(uri);
    final key = _key(uri);
    final memory = _memory.remove(key);
    if (memory != null) {
      _memory[key] = memory;
      return Future.value(memory);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;

    late final Future<Uint8List> tracked;
    tracked = () async {
      try {
        return await _load(uri, key, (_cacheEpoch, _keyEpochs[key] ?? 0));
      } finally {
        if (identical(_inFlight[key], tracked)) _inFlight.remove(key);
      }
    }();
    _inFlight[key] = tracked;
    return tracked;
  }

  Future<Uint8List> _load(Uri uri, String key, (int, int) epoch) async {
    final disk = await _readDisk(key);
    if (disk != null) {
      if (_isCurrent(key, epoch)) _remember(key, disk);
      return disk;
    }

    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final bytes = await _withPermit(() => _loader(uri));
        _validateBytes(bytes);
        if (_isCurrent(key, epoch)) {
          _remember(key, bytes);
          await _writeDisk(key, bytes);
        }
        return bytes;
      } catch (error, stackTrace) {
        lastError = error;
        lastStack = stackTrace;
        if (attempt == 0 && _isTransient(error)) {
          await Future<void>.delayed(retryDelay);
          continue;
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }

  Future<T> _withPermit<T>(Future<T> Function() action) async {
    await _acquirePermit();
    try {
      return await action();
    } finally {
      _releasePermit();
    }
  }

  Future<void> _acquirePermit() async {
    if (_active < maxConcurrent) {
      _active++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
  }

  void _releasePermit() {
    if (_waiters.isNotEmpty) {
      // Transfer the occupied slot directly to the oldest waiter. Keeping
      // [_active] unchanged prevents a newly arriving request from stealing it.
      _waiters.removeFirst().complete();
      return;
    }
    _active--;
  }

  Future<Uint8List> _download(Uri uri) async {
    try {
      final response = await _dio.get<List<int>>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 600,
        ),
      );
      final status = response.statusCode ?? 0;
      final data = response.data;
      final contentType =
          response.headers.value(Headers.contentTypeHeader) ?? '';
      if (status != HttpStatus.ok || data == null) {
        throw SourceCoverLoadException(
          'Cover request failed with HTTP $status.',
          transient: _isTransientStatus(status),
        );
      }
      if (!contentType.toLowerCase().startsWith('image/')) {
        throw const SourceCoverLoadException('Cover response is not an image.');
      }
      return data is Uint8List ? data : Uint8List.fromList(data);
    } on DioException catch (error) {
      throw SourceCoverLoadException(
        'Cover request failed: ${error.message ?? error.type.name}',
        transient: switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.transformTimeout ||
          DioExceptionType.connectionError ||
          DioExceptionType.unknown => true,
          DioExceptionType.badResponse => _isTransientStatus(
            error.response?.statusCode ?? 0,
          ),
          DioExceptionType.cancel || DioExceptionType.badCertificate => false,
        },
      );
    }
  }

  bool _isTransient(Object error) =>
      error is SourceCoverLoadException && error.transient;

  bool _isTransientStatus(int status) =>
      status == HttpStatus.requestTimeout ||
      status == 425 ||
      status == HttpStatus.tooManyRequests ||
      status == HttpStatus.internalServerError ||
      status == HttpStatus.badGateway ||
      status == HttpStatus.serviceUnavailable ||
      status == HttpStatus.gatewayTimeout;

  void _validateUri(Uri uri) {
    if (!uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const SourceCoverLoadException('Invalid cover URL.');
    }
  }

  void _validateBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const SourceCoverLoadException('Cover response is empty.');
    }
    if (bytes.lengthInBytes > maxImageBytes) {
      throw SourceCoverLoadException(
        'Cover exceeds the $maxImageBytes byte limit.',
      );
    }
  }

  void _remember(String key, Uint8List bytes) {
    final replaced = _memory.remove(key);
    if (replaced != null) _memoryBytes -= replaced.lengthInBytes;
    _memory[key] = bytes;
    _memoryBytes += bytes.lengthInBytes;
    while (_memoryBytes > maxMemoryBytes && _memory.isNotEmpty) {
      final oldestKey = _memory.keys.first;
      _memoryBytes -= _memory.remove(oldestKey)!.lengthInBytes;
    }
  }

  Future<Uint8List?> _readDisk(String key) async {
    try {
      final file = await _fileFor(key);
      if (!await file.exists()) return null;
      if (DateTime.now().difference(await file.lastModified()) > maxDiskAge) {
        await file.delete();
        return null;
      }
      final bytes = await file.readAsBytes();
      _validateBytes(bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(String key, Uint8List bytes) async {
    try {
      final file = await _fileFor(key);
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.part');
      await temporary.writeAsBytes(bytes, flush: true);
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    } catch (_) {
      // A cache write must never turn a valid network image into a UI failure.
    }
  }

  Future<Directory> directory() async {
    if (_cacheDirectory != null) return _cacheDirectory;
    final root = await getApplicationCacheDirectory();
    return Directory(path.join(root.path, directoryName));
  }

  Future<File> _fileFor(String key) async =>
      File(path.join((await directory()).path, '$key.img'));

  String _key(Uri uri) =>
      sha256.convert(utf8.encode(uri.toString())).toString();

  bool _isCurrent(String key, (int, int) epoch) =>
      epoch.$1 == _cacheEpoch && epoch.$2 == (_keyEpochs[key] ?? 0);

  Future<void> evict(Uri uri) async {
    _validateUri(uri);
    final key = _key(uri);
    _keyEpochs[key] = (_keyEpochs[key] ?? 0) + 1;
    _inFlight.remove(key);
    final memory = _memory.remove(key);
    if (memory != null) _memoryBytes -= memory.lengthInBytes;
    final file = await _fileFor(key);
    if (await file.exists()) await file.delete();
  }

  void clearMemory() {
    _memory.clear();
    _memoryBytes = 0;
  }

  Future<void> clearDisk() async {
    _cacheEpoch++;
    _keyEpochs.clear();
    final cacheDirectory = await directory();
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  }

  Future<void> clear() async {
    clearMemory();
    await clearDisk();
  }

  Future<int> diskSizeBytes() async => _directorySize(await directory());

  Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // Ignore files removed concurrently by the OS or cache cleanup.
        }
      }
    }
    return total;
  }
}

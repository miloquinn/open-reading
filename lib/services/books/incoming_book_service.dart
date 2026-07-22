// 文件说明：协调冷/热启动入站书籍、启动门禁、FIFO 与导入/路由。
// 技术要点：单消费者队列、请求去重、完成确认、单文件自动打开。

import 'dart:async';
import 'dart:collection';

import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/books/incoming_book_bridge.dart';
import 'package:xxread/services/books/incoming_book_materializer.dart';
import 'package:xxread/services/books/incoming_book_models.dart';

typedef IncomingBookOpenBook = Future<void> Function(Book book);
typedef IncomingBookOpenImportQueue = Future<void> Function(
  List<BookImportSource> sources,
);
typedef IncomingBookFailureHandler = void Function(IncomingBookFailure failure);
typedef IncomingBookProcessingHandler = void Function(bool processing);

class IncomingBookService {
  IncomingBookService({
    required IncomingBookRequestSource bridge,
    required IncomingBookMaterializer materializer,
    required BookFileImporter importer,
    required IncomingBookOpenBook openBook,
    required IncomingBookOpenImportQueue openImportQueue,
    IncomingBookFailureHandler? onFailure,
    IncomingBookProcessingHandler? onProcessing,
  })  : _bridge = bridge,
        _materializer = materializer,
        _importer = importer,
        _openBook = openBook,
        _openImportQueue = openImportQueue,
        _onFailure = onFailure,
        _onProcessing = onProcessing;

  final IncomingBookRequestSource _bridge;
  final IncomingBookMaterializer _materializer;
  final BookFileImporter _importer;
  final IncomingBookOpenBook _openBook;
  final IncomingBookOpenImportQueue _openImportQueue;
  final IncomingBookFailureHandler? _onFailure;
  final IncomingBookProcessingHandler? _onProcessing;
  final Queue<IncomingBookRequest> _queue = Queue<IncomingBookRequest>();
  final Set<String> _knownRequestIds = <String>{};

  StreamSubscription<IncomingBookRequest>? _subscription;
  Future<void>? _drainFuture;
  bool _ready = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_disposed || _subscription != null) return;
    _subscription = _bridge.requests.listen(addRequest);
    final initial = await _bridge.getInitialRequests();
    for (final request in initial) {
      addRequest(request);
    }
  }

  void addRequest(IncomingBookRequest request) {
    if (_disposed ||
        request.requestId.isEmpty ||
        !_knownRequestIds.add(request.requestId)) {
      return;
    }
    _queue.add(request);
    _scheduleDrain();
  }

  Future<void> setReady(bool ready) async {
    _ready = ready;
    _scheduleDrain();
    await idle;
  }

  Future<void> get idle => _drainFuture ?? Future<void>.value();

  void _scheduleDrain() {
    if (!_ready || _disposed || _queue.isEmpty || _drainFuture != null) return;
    final future = _drain();
    _drainFuture = future;
    unawaited(
      future.whenComplete(() {
        _drainFuture = null;
        _scheduleDrain();
      }),
    );
  }

  Future<void> _drain() async {
    while (_ready && !_disposed && _queue.isNotEmpty) {
      final request = _queue.removeFirst();
      _onProcessing?.call(true);
      try {
        await _handle(request);
        await _completeWithoutMaskingFailure(request.requestId);
      } on IncomingBookFailure catch (failure) {
        _onFailure?.call(failure);
        await _completeWithoutMaskingFailure(request.requestId);
      } catch (error) {
        _onFailure?.call(IncomingBookFailure('import_failed', cause: error));
        await _completeWithoutMaskingFailure(request.requestId);
      } finally {
        _onProcessing?.call(false);
      }
    }
  }

  Future<void> _completeWithoutMaskingFailure(String requestId) async {
    try {
      await _bridge.completeRequest(requestId, deleteFiles: true);
    } catch (_) {
      // 原业务失败码优先；原生暂存区可在下次启动执行陈旧项清理。
    }
  }

  Future<void> _handle(IncomingBookRequest request) async {
    if (request.items.isEmpty) {
      throw IncomingBookFailure(_mapNativeFailure(request.errorCode));
    }
    if (request.items.length > IncomingBookMaterializer.maximumRequestItems) {
      throw const IncomingBookFailure('too_many_files');
    }
    final sources = <BookImportSource>[];
    IncomingBookFailure? firstMaterializationFailure;
    var skippedCount = request.failureCount;
    var aggregateBytes = 0;
    for (final item in request.items) {
      BookImportSource source;
      try {
        source = await _materializer.prepare(request, item);
      } on IncomingBookFailure catch (failure) {
        firstMaterializationFailure ??= failure;
        skippedCount++;
        continue;
      }
      final sourceBytes = source.sizeBytes ?? 0;
      if (sourceBytes >
          IncomingBookMaterializer.maximumRequestBytes - aggregateBytes) {
        throw const IncomingBookFailure('file_too_large');
      }
      aggregateBytes += sourceBytes;
      sources.add(source);
    }
    if (sources.isEmpty) {
      throw firstMaterializationFailure ??
          const IncomingBookFailure('unsupported_format');
    }
    if (skippedCount > 0) {
      _onFailure?.call(const IncomingBookFailure('partial_failure'));
    }

    if (sources.length > 1) {
      await _openImportQueue(List<BookImportSource>.unmodifiable(sources));
      return;
    }
    try {
      final result = await _importer.importFile(sources.single);
      await _openBook(result.book);
    } on BookImportFailure catch (failure) {
      throw IncomingBookFailure(
        _mapImportFailure(failure.code),
        cause: failure,
      );
    }
  }

  String _mapImportFailure(String code) {
    return switch (code) {
      'source_missing' || 'source_not_materialized' => 'permission_expired',
      'file_too_large' => 'file_too_large',
      'aggregate_too_large' => 'file_too_large',
      'too_many_files' => 'too_many_files',
      _ => 'import_failed',
    };
  }

  String _mapNativeFailure(String? code) {
    return switch (code) {
      'no_book_file' => 'no_book_file',
      'unsupported_format' => 'unsupported_format',
      'file_too_large' => 'file_too_large',
      'aggregate_too_large' => 'file_too_large',
      'too_many_files' => 'too_many_files',
      'format_mime_mismatch' || 'format_content_mismatch' => 'content_mismatch',
      'permission_expired' => 'permission_expired',
      'file_access_lost' => 'permission_expired',
      'materialize_failed' => 'permission_expired',
      _ => 'no_book_file',
    };
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    await idle;
    await _bridge.dispose();
  }
}

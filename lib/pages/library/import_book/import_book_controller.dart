// 文件说明：管理多本书籍的暂存、顺序导入、失败重试和汇总状态。
// 技术要点：ChangeNotifier、严格单并发、不可变队列条目。

import 'package:flutter/foundation.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/books/book_import_source_service.dart';

enum ImportQueueItemStatus {
  queued,
  preparing,
  importing,
  imported,
  skipped,
  failed,
}

class ImportQueueItem {
  const ImportQueueItem({
    required this.source,
    this.status = ImportQueueItemStatus.queued,
    this.phase = BookImportPhase.queued,
    this.progress = 0,
    this.result,
    this.failure,
  });

  final BookImportSource source;
  final ImportQueueItemStatus status;
  final BookImportPhase phase;
  final double progress;
  final BookImportResult? result;
  final BookImportFailure? failure;

  ImportQueueItem copyWith({
    BookImportSource? source,
    ImportQueueItemStatus? status,
    BookImportPhase? phase,
    double? progress,
    BookImportResult? result,
    BookImportFailure? failure,
    bool clearResult = false,
    bool clearFailure = false,
  }) {
    return ImportQueueItem(
      source: source ?? this.source,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      result: clearResult ? null : result ?? this.result,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class ImportBookController extends ChangeNotifier {
  ImportBookController({
    required BookFileImporter importer,
    required BookImportSourcePreparer sourcePreparer,
  }) : _importer = importer,
       _sourcePreparer = sourcePreparer;

  final BookFileImporter _importer;
  final BookImportSourcePreparer _sourcePreparer;
  final List<ImportQueueItem> _items = [];
  bool _isRunning = false;

  List<ImportQueueItem> get items => List.unmodifiable(_items);
  bool get isRunning => _isRunning;
  bool get canStart => !_isRunning && queuedCount > 0;
  int get totalCount => _items.length;
  int get queuedCount => _count(ImportQueueItemStatus.queued);
  int get succeededCount => _count(ImportQueueItemStatus.imported);
  int get skippedCount => _count(ImportQueueItemStatus.skipped);
  int get failedCount => _count(ImportQueueItemStatus.failed);
  int get completedCount => succeededCount + skippedCount + failedCount;

  void addSources(Iterable<BookImportSource> sources) {
    final existingIds = _items.map((item) => item.source.id).toSet();
    var changed = false;
    for (final source in sources) {
      if (existingIds.add(source.id)) {
        _items.add(ImportQueueItem(source: source));
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void removeQueued(String sourceId) {
    if (_isRunning) return;
    final previousLength = _items.length;
    _items.removeWhere(
      (item) =>
          item.source.id == sourceId &&
          (item.status == ImportQueueItemStatus.queued ||
              item.status == ImportQueueItemStatus.failed),
    );
    if (_items.length != previousLength) notifyListeners();
  }

  void clearCompleted() {
    if (_isRunning) return;
    final previousLength = _items.length;
    _items.removeWhere(
      (item) =>
          item.status == ImportQueueItemStatus.imported ||
          item.status == ImportQueueItemStatus.skipped,
    );
    if (_items.length != previousLength) notifyListeners();
  }

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    notifyListeners();
    try {
      for (var index = 0; index < _items.length; index++) {
        if (_items[index].status != ImportQueueItemStatus.queued) continue;
        await _importAt(index);
      }
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  Future<void> retryFailed() async {
    if (_isRunning) return;
    var changed = false;
    for (var index = 0; index < _items.length; index++) {
      if (_items[index].status != ImportQueueItemStatus.failed) continue;
      _items[index] = _items[index].copyWith(
        status: ImportQueueItemStatus.queued,
        phase: BookImportPhase.queued,
        progress: 0,
        clearFailure: true,
        clearResult: true,
      );
      changed = true;
    }
    if (changed) notifyListeners();
    await start();
  }

  Future<void> retryOne(String sourceId) async {
    if (_isRunning) return;
    final index = _items.indexWhere(
      (item) =>
          item.source.id == sourceId &&
          item.status == ImportQueueItemStatus.failed,
    );
    if (index < 0) return;
    _items[index] = _items[index].copyWith(
      status: ImportQueueItemStatus.queued,
      phase: BookImportPhase.queued,
      progress: 0,
      clearFailure: true,
      clearResult: true,
    );
    notifyListeners();
    _isRunning = true;
    notifyListeners();
    try {
      await _importAt(index);
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  Future<void> _importAt(int index) async {
    final originalSource = _items[index].source;
    BookImportSource? prepared;
    _replace(
      index,
      _items[index].copyWith(
        status: ImportQueueItemStatus.preparing,
        progress: 0,
        clearFailure: true,
      ),
    );
    try {
      prepared = await _sourcePreparer.prepare(originalSource);
      _replace(
        index,
        _items[index].copyWith(
          source: prepared,
          status: ImportQueueItemStatus.importing,
        ),
      );
      final result = await _importer.importFile(
        prepared,
        onProgress: (phase, progress, _) {
          _replace(
            index,
            _items[index].copyWith(
              status: ImportQueueItemStatus.importing,
              phase: phase,
              progress: progress.clamp(0.0, 1.0).toDouble(),
            ),
          );
        },
      );
      final status = result.outcome == BookImportOutcome.duplicateSkipped
          ? ImportQueueItemStatus.skipped
          : ImportQueueItemStatus.imported;
      _replace(
        index,
        _items[index].copyWith(
          status: status,
          progress: 1,
          result: result,
          clearFailure: true,
        ),
      );
    } on BookImportFailure catch (failure) {
      _markFailed(index, failure);
    } catch (error) {
      _markFailed(
        index,
        BookImportFailure(code: 'source_prepare_failed', cause: error),
      );
    } finally {
      if (prepared != null) {
        try {
          await _sourcePreparer.release(prepared);
        } catch (error) {
          debugPrint('清理导入临时文件失败: $error');
        }
        if (prepared.localPath != originalSource.localPath) {
          _replace(index, _items[index].copyWith(source: originalSource));
        }
      }
    }
  }

  void _markFailed(int index, BookImportFailure failure) {
    _replace(
      index,
      _items[index].copyWith(
        status: ImportQueueItemStatus.failed,
        failure: failure,
      ),
    );
  }

  void _replace(int index, ImportQueueItem item) {
    _items[index] = item;
    notifyListeners();
  }

  int _count(ImportQueueItemStatus status) {
    return _items.where((item) => item.status == status).length;
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/core/background_download_notifier.dart';

enum DownloadTaskState { queued, downloading, completed, failed }

@immutable
class BookDownloadTask {
  const BookDownloadTask({
    required this.id,
    required this.source,
    required this.book,
    required this.state,
    this.completed = 0,
    this.total = 0,
    this.downloadedBook,
    this.error,
  });

  final String id;
  final RegisteredBookSource source;
  final BookSourceBook book;
  final DownloadTaskState state;
  final int completed;
  final int total;
  final Book? downloadedBook;
  final Object? error;

  double? get progress => total > 0 ? completed / total : null;

  BookDownloadTask copyWith({
    DownloadTaskState? state,
    int? completed,
    int? total,
    Book? downloadedBook,
    Object? error,
  }) =>
      BookDownloadTask(
        id: id,
        source: source,
        book: book,
        state: state ?? this.state,
        completed: completed ?? this.completed,
        total: total ?? this.total,
        downloadedBook: downloadedBook ?? this.downloadedBook,
        error: error ?? this.error,
      );
}

/// Owns in-app book download queue state while the application is running.
/// Android adds a foreground service for the active task so the same work can
/// continue after the UI is backgrounded.
class DownloadTaskController extends ChangeNotifier {
  final List<BookDownloadTask> _tasks = <BookDownloadTask>[];
  bool _workerRunning = false;

  List<BookDownloadTask> get tasks => List.unmodifiable(_tasks);

  bool get hasActiveTasks => _tasks.any(
        (task) =>
            task.state == DownloadTaskState.queued ||
            task.state == DownloadTaskState.downloading,
      );

  BookDownloadTask? taskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  String enqueueBookDownload({
    required RegisteredBookSource source,
    required BookSourceBook book,
    required BookSourceShelfService shelfService,
  }) {
    final existing = _tasks.where(
      (task) =>
          task.source.id == source.id &&
          task.book.id == book.id &&
          (task.state == DownloadTaskState.queued ||
              task.state == DownloadTaskState.downloading),
    );
    if (existing.isNotEmpty) return existing.first.id;

    final id =
        'book:${source.id}:${book.id}:${DateTime.now().microsecondsSinceEpoch}';
    _tasks.insert(
      0,
      BookDownloadTask(
        id: id,
        source: source,
        book: book,
        state: DownloadTaskState.queued,
      ),
    );
    notifyListeners();
    unawaited(_runQueue(shelfService));
    return id;
  }

  Future<void> _runQueue(BookSourceShelfService shelfService) async {
    if (_workerRunning) return;
    _workerRunning = true;
    try {
      while (true) {
        final index = _tasks.indexWhere(
          (task) => task.state == DownloadTaskState.queued,
        );
        if (index < 0) return;
        final task = _tasks[index];
        _replace(index, task.copyWith(state: DownloadTaskState.downloading));
        final notificationTask = BackgroundDownloadTask(
          id: task.id,
          kind: BackgroundDownloadKind.book,
          title: task.book.title,
        );
        try {
          await _notify(
              () => BackgroundDownloadNotifier.begin(notificationTask));
          final downloaded = await shelfService.downloadToLocal(
            source: task.source,
            book: task.book,
            onProgress: (completed, total) {
              final currentIndex = _tasks.indexWhere(
                (candidate) => candidate.id == task.id,
              );
              if (currentIndex < 0) return;
              _replace(
                currentIndex,
                _tasks[currentIndex].copyWith(
                  completed: completed,
                  total: total,
                ),
              );
              unawaited(
                _notify(
                  () => BackgroundDownloadNotifier.progress(
                    notificationTask,
                    completed: completed,
                    total: total,
                  ),
                ),
              );
            },
          );
          final currentIndex = _tasks.indexWhere(
            (candidate) => candidate.id == task.id,
          );
          if (currentIndex >= 0) {
            _replace(
              currentIndex,
              _tasks[currentIndex].copyWith(
                state: DownloadTaskState.completed,
                completed: _tasks[currentIndex].total,
                downloadedBook: downloaded,
              ),
            );
          }
          await _notify(
            () => BackgroundDownloadNotifier.completeBook(
              BackgroundDownloadTask(
                id: task.id,
                kind: BackgroundDownloadKind.book,
                title: task.book.title,
                bookId: downloaded.id,
              ),
            ),
          );
        } catch (error) {
          final currentIndex = _tasks.indexWhere(
            (candidate) => candidate.id == task.id,
          );
          if (currentIndex >= 0) {
            _replace(
              currentIndex,
              _tasks[currentIndex].copyWith(
                state: DownloadTaskState.failed,
                error: error,
              ),
            );
          }
          await _notify(
              () => BackgroundDownloadNotifier.fail(notificationTask));
        }
      }
    } finally {
      _workerRunning = false;
      if (_tasks.any((task) => task.state == DownloadTaskState.queued)) {
        unawaited(_runQueue(shelfService));
      }
    }
  }

  Future<void> _notify(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Notification permission and platform failures never stop a download.
    }
  }

  void _replace(int index, BookDownloadTask task) {
    _tasks[index] = task;
    notifyListeners();
  }
}

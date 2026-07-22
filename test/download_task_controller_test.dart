import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_download_cancellation.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/library/download_task_controller.dart';

void main() {
  test(
    'runs queued book downloads one at a time and preserves progress',
    () async {
      final service = _QueuedDownloadService();
      final controller = DownloadTaskController();
      final firstId = controller.enqueueBookDownload(
        source: _source,
        book: _book('first'),
        shelfService: service,
      );
      final secondId = controller.enqueueBookDownload(
        source: _source,
        book: _book('second'),
        shelfService: service,
      );

      await _waitFor(
        () =>
            controller.taskById(firstId)?.state ==
                DownloadTaskState.completed &&
            controller.taskById(secondId)?.state == DownloadTaskState.completed,
      );

      expect(service.maxActive, 1);
      expect(service.downloadedIds, ['first', 'second']);
      expect(controller.taskById(firstId)?.completed, 2);
      expect(controller.taskById(firstId)?.total, 2);
      expect(controller.hasActiveTasks, isFalse);
    },
  );

  test(
    'cancels an active task and continues with the next queued task',
    () async {
      final service = _CancellableDownloadService();
      final controller = DownloadTaskController();
      final firstId = controller.enqueueBookDownload(
        source: _source,
        book: _book('first'),
        shelfService: service,
      );
      final secondId = controller.enqueueBookDownload(
        source: _source,
        book: _book('second'),
        shelfService: service,
      );

      await service.firstStarted.future;
      expect(controller.cancelTask(firstId), isTrue);
      await _waitFor(
        () =>
            controller.taskById(firstId)?.state ==
                DownloadTaskState.cancelled &&
            controller.taskById(secondId)?.state == DownloadTaskState.completed,
      );

      expect(service.completedIds, ['second']);
      expect(controller.hasActiveTasks, isFalse);
    },
  );

  test('cancels a queued task without starting it', () async {
    final service = _CancellableDownloadService();
    final controller = DownloadTaskController();
    final firstId = controller.enqueueBookDownload(
      source: _source,
      book: _book('first'),
      shelfService: service,
    );
    final secondId = controller.enqueueBookDownload(
      source: _source,
      book: _book('second'),
      shelfService: service,
    );

    await service.firstStarted.future;
    expect(controller.cancelTask(secondId), isTrue);
    service.finishFirst.complete();
    await _waitFor(
      () =>
          controller.taskById(firstId)?.state == DownloadTaskState.completed &&
          controller.taskById(secondId)?.state == DownloadTaskState.cancelled,
    );

    expect(service.startedIds, ['first']);
  });

  test(
    'cancels an active task and continues with the next queued task',
    () async {
      final service = _CancellableDownloadService();
      final controller = DownloadTaskController();
      final firstId = controller.enqueueBookDownload(
        source: _source,
        book: _book('first'),
        shelfService: service,
      );
      final secondId = controller.enqueueBookDownload(
        source: _source,
        book: _book('second'),
        shelfService: service,
      );

      await service.firstStarted.future;
      expect(controller.cancelTask(firstId), isTrue);
      await _waitFor(
        () =>
            controller.taskById(firstId)?.state ==
                DownloadTaskState.cancelled &&
            controller.taskById(secondId)?.state == DownloadTaskState.completed,
      );

      expect(service.completedIds, ['second']);
      expect(controller.hasActiveTasks, isFalse);
    },
  );

  test('cancels a queued task without starting it', () async {
    final service = _CancellableDownloadService();
    final controller = DownloadTaskController();
    final firstId = controller.enqueueBookDownload(
      source: _source,
      book: _book('first'),
      shelfService: service,
    );
    final secondId = controller.enqueueBookDownload(
      source: _source,
      book: _book('second'),
      shelfService: service,
    );

    await service.firstStarted.future;
    expect(controller.cancelTask(secondId), isTrue);
    service.finishFirst.complete();
    await _waitFor(
      () =>
          controller.taskById(firstId)?.state == DownloadTaskState.completed &&
          controller.taskById(secondId)?.state == DownloadTaskState.cancelled,
    );

    expect(service.startedIds, ['first']);
  });
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for queued downloads.');
}

final _source = RegisteredBookSource(
  id: 'source',
  name: 'Source',
  description: '',
  manifestUrl: Uri.parse('https://example.com/manifest.json'),
  apiBaseUrl: Uri.parse('https://example.com/api/'),
  protocolVersion: '1.0',
  languages: const ['zh-CN'],
  capabilities: const {'content'},
  enabled: true,
  addedAt: DateTime.utc(2026, 7, 21),
);

BookSourceBook _book(String id) => BookSourceBook(
  id: id,
  title: id,
  author: 'Author',
  description: '',
  categories: const [],
);

class _QueuedDownloadService extends BookSourceShelfService {
  int active = 0;
  int maxActive = 0;
  final List<String> downloadedIds = <String>[];

  @override
  Future<Book> downloadToLocal({
    required RegisteredBookSource source,
    required BookSourceBook book,
    void Function(int completed, int total)? onProgress,
    BookDownloadCancellation? cancellation,
  }) async {
    active++;
    if (active > maxActive) maxActive = active;
    onProgress?.call(0, 2);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    onProgress?.call(1, 2);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    onProgress?.call(2, 2);
    downloadedIds.add(book.id);
    active--;
    return Book(
      id: downloadedIds.length,
      title: book.title,
      author: book.author,
      filePath: '/books/${book.id}.txt',
      format: 'txt',
    );
  }
}

class _CancellableDownloadService extends BookSourceShelfService {
  final Completer<void> firstStarted = Completer<void>();
  final Completer<void> finishFirst = Completer<void>();
  final List<String> startedIds = <String>[];
  final List<String> completedIds = <String>[];

  @override
  Future<Book> downloadToLocal({
    required RegisteredBookSource source,
    required BookSourceBook book,
    void Function(int completed, int total)? onProgress,
    BookDownloadCancellation? cancellation,
  }) async {
    startedIds.add(book.id);
    onProgress?.call(0, 1);
    if (book.id == 'first') {
      if (!firstStarted.isCompleted) firstStarted.complete();
      await Future.any<void>([
        finishFirst.future,
        if (cancellation != null) cancellation.whenCancelled,
      ]);
      cancellation?.throwIfCancelled();
    }
    onProgress?.call(1, 1);
    completedIds.add(book.id);
    return Book(
      id: completedIds.length,
      title: book.title,
      author: book.author,
      filePath: '/books/${book.id}.txt',
      format: 'txt',
    );
  }
}

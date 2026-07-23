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
    'runs two downloads concurrently and fills freed slots in FIFO order',
    () async {
      final service = _ControlledDownloadService();
      final controller = DownloadTaskController();
      final firstId = _enqueue(controller, service, 'first');
      final secondId = _enqueue(controller, service, 'second');
      final thirdId = _enqueue(controller, service, 'third');

      await _waitFor(() => service.startedIds.length == 2);

      expect(service.startedIds, ['first', 'second']);
      expect(service.maxActive, 2);
      expect(controller.taskById(thirdId)?.state, DownloadTaskState.queued);

      service.complete('first');
      await _waitFor(() => service.startedIds.length == 3);

      expect(service.startedIds, ['first', 'second', 'third']);
      expect(service.active, 2);
      service
        ..complete('second')
        ..complete('third');
      await _waitFor(
        () =>
            controller.taskById(firstId)?.state ==
                DownloadTaskState.completed &&
            controller.taskById(secondId)?.state ==
                DownloadTaskState.completed &&
            controller.taskById(thirdId)?.state == DownloadTaskState.completed,
      );

      expect(controller.taskById(firstId)?.completed, 2);
      expect(controller.taskById(firstId)?.total, 2);
      expect(controller.hasActiveTasks, isFalse);
    },
  );

  test('uses the shelf service attached to each queued task', () async {
    final firstService = _ControlledDownloadService();
    final secondService = _ControlledDownloadService();
    final controller = DownloadTaskController();
    final firstId = _enqueue(controller, firstService, 'first');
    final secondId = _enqueue(controller, secondService, 'second');

    await _waitFor(
      () =>
          firstService.startedIds.isNotEmpty &&
          secondService.startedIds.isNotEmpty,
    );

    expect(firstService.startedIds, ['first']);
    expect(secondService.startedIds, ['second']);
    firstService.complete('first');
    secondService.complete('second');
    await _waitFor(
      () =>
          controller.taskById(firstId)?.state == DownloadTaskState.completed &&
          controller.taskById(secondId)?.state == DownloadTaskState.completed,
    );
  });

  test('cancels an active task and starts the next queued task', () async {
    final service = _ControlledDownloadService();
    final controller = DownloadTaskController();
    final firstId = _enqueue(controller, service, 'first');
    final secondId = _enqueue(controller, service, 'second');
    final thirdId = _enqueue(controller, service, 'third');

    await _waitFor(() => service.startedIds.length == 2);
    expect(controller.cancelTask(firstId), isTrue);
    await _waitFor(() => service.startedIds.length == 3);

    expect(service.startedIds, ['first', 'second', 'third']);
    expect(controller.taskById(firstId)?.state, DownloadTaskState.cancelled);
    service
      ..complete('second')
      ..complete('third');
    await _waitFor(
      () =>
          controller.taskById(secondId)?.state == DownloadTaskState.completed &&
          controller.taskById(thirdId)?.state == DownloadTaskState.completed,
    );
    expect(controller.hasActiveTasks, isFalse);
  });

  test('cancels a queued task without starting it', () async {
    final service = _ControlledDownloadService();
    final controller = DownloadTaskController(maxConcurrentDownloads: 1);
    final firstId = _enqueue(controller, service, 'first');
    final secondId = _enqueue(controller, service, 'second');

    await _waitFor(() => service.startedIds.length == 1);
    expect(controller.cancelTask(secondId), isTrue);
    service.complete('first');
    await _waitFor(
      () =>
          controller.taskById(firstId)?.state == DownloadTaskState.completed &&
          controller.taskById(secondId)?.state == DownloadTaskState.cancelled,
    );

    expect(service.startedIds, ['first']);
  });
}

String _enqueue(
  DownloadTaskController controller,
  BookSourceShelfService service,
  String bookId,
) => controller.enqueueBookDownload(
  source: _source,
  book: _book(bookId),
  shelfService: service,
);

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
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

class _ControlledDownloadService extends BookSourceShelfService {
  int active = 0;
  int maxActive = 0;
  final List<String> startedIds = <String>[];
  final Map<String, Completer<void>> _finishes = {};

  @override
  Future<Book> downloadToLocal({
    required RegisteredBookSource source,
    required BookSourceBook book,
    void Function(int completed, int total)? onProgress,
    BookDownloadCancellation? cancellation,
  }) async {
    active++;
    if (active > maxActive) maxActive = active;
    startedIds.add(book.id);
    final finish = _finishes.putIfAbsent(book.id, Completer<void>.new);
    onProgress?.call(0, 2);
    await Future.any<void>([
      finish.future,
      if (cancellation != null) cancellation.whenCancelled,
    ]);
    try {
      cancellation?.throwIfCancelled();
      onProgress?.call(2, 2);
      return Book(
        id: startedIds.indexOf(book.id) + 1,
        title: book.title,
        author: book.author,
        filePath: '/books/${book.id}.txt',
        format: 'txt',
      );
    } finally {
      active--;
    }
  }

  void complete(String bookId) {
    final finish = _finishes.putIfAbsent(bookId, Completer<void>.new);
    if (!finish.isCompleted) finish.complete();
  }
}

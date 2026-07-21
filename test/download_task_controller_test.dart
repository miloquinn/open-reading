import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/library/download_task_controller.dart';

void main() {
  test('runs queued book downloads one at a time and preserves progress',
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
          controller.taskById(firstId)?.state == DownloadTaskState.completed &&
          controller.taskById(secondId)?.state == DownloadTaskState.completed,
    );

    expect(service.maxActive, 1);
    expect(service.downloadedIds, ['first', 'second']);
    expect(controller.taskById(firstId)?.completed, 2);
    expect(controller.taskById(firstId)?.total, 2);
    expect(controller.hasActiveTasks, isFalse);
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

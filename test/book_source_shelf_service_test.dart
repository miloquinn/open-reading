import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_download_cancellation.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/book_sources/services/source_cover_cache.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';

void main() {
  test('adds a source book as an online shelf record without a local file',
      () async {
    final directory = await Directory.systemTemp.createTemp('source-shelf-');
    addTearDown(() => directory.delete(recursive: true));
    final dao = _MemoryBookDao();
    final service = BookSourceShelfService(
      bookDao: dao,
      downloadDirectory: directory,
    );
    final added = await service.addOnline(
      source: _source,
      book: _sourceBook,
    );
    final duplicate = await service.addOnline(
      source: _source,
      book: _sourceBook,
    );

    expect(added.isOnline, isTrue);
    expect(added.filePath, isEmpty);
    expect(added.coverImagePath, isNotNull);
    expect(await File(added.coverImagePath!).exists(), isTrue);
    expect(added.sourceId, _source.id);
    expect(service.sourceFrom(added).apiBaseUrl, _source.apiBaseUrl);
    expect(service.sourceBookFrom(added).title, _sourceBook.title);
    expect(duplicate.id, added.id);
    expect(dao.insertCount, 1);
  });

  test('large downloads use bounded workers and report every chapter',
      () async {
    final directory = await Directory.systemTemp.createTemp('source-download-');
    addTearDown(() => directory.delete(recursive: true));
    final dao = _MemoryBookDao();
    final client = _DownloadClient();
    final service = BookSourceShelfService(
      bookDao: dao,
      client: client,
      downloadDirectory: directory,
    );
    final progress = <(int, int)>[];

    final downloaded = await service.downloadToLocal(
      source: _source,
      book: _sourceBook,
      onProgress: (completed, total) => progress.add((completed, total)),
    );

    expect(client.maxActive, lessThanOrEqualTo(3));
    expect(progress.first, (0, 7));
    expect(progress.last, (7, 7));
    expect(downloaded.isOnline, isFalse);
    expect(await File(downloaded.filePath).exists(), isTrue);
    expect(downloaded.coverImagePath, isNotNull);
    expect(await File(downloaded.coverImagePath!).exists(), isTrue);
    final text = await File(downloaded.filePath).readAsString();
    expect(text.indexOf('正文0'), lessThan(text.indexOf('正文6')));
  });

  test('streams completed batches before the whole book finishes', () async {
    final directory = await Directory.systemTemp.createTemp('source-stream-');
    addTearDown(() => directory.delete(recursive: true));
    final client = _StreamingDownloadClient();
    final service = BookSourceShelfService(
      bookDao: _MemoryBookDao(),
      client: client,
      downloadDirectory: directory,
    );

    final download = service.downloadToLocal(
      source: _source,
      book: _sourceBook,
    );
    await client.secondBatchStarted.future;

    final booksDirectory = Directory('${directory.path}/books');
    final partials = await booksDirectory
        .list()
        .where((entry) => entry.path.endsWith('.part'))
        .toList();
    expect(partials, hasLength(1));
    final partialText = await File(partials.single.path).readAsString();
    expect(partialText, contains('正文0'));
    expect(partialText, contains('正文2'));
    expect(partialText, isNot(contains('正文3')));
    expect(
      await booksDirectory
          .list()
          .where((entry) => entry.path.endsWith('.txt'))
          .isEmpty,
      isTrue,
    );

    client.releaseSecondBatch.complete();
    final downloaded = await download;
    expect(client.maxActive, lessThanOrEqualTo(3));
    expect(await File(downloaded.filePath).exists(), isTrue);
    expect(
      await booksDirectory
          .list()
          .where((entry) => entry.path.endsWith('.part'))
          .isEmpty,
      isTrue,
    );
  });

  test('removes the partial file when a streaming download is cancelled',
      () async {
    final directory = await Directory.systemTemp.createTemp('source-cancel-');
    addTearDown(() => directory.delete(recursive: true));
    final client = _StreamingDownloadClient();
    final cancellation = BookDownloadCancellation();
    final service = BookSourceShelfService(
      bookDao: _MemoryBookDao(),
      client: client,
      downloadDirectory: directory,
    );

    final download = service.downloadToLocal(
      source: _source,
      book: _sourceBook,
      cancellation: cancellation,
    );
    await client.secondBatchStarted.future;
    cancellation.cancel();
    client.releaseSecondBatch.complete();

    await expectLater(
      download,
      throwsA(isA<BookDownloadCancelledException>()),
    );
    final booksDirectory = Directory('${directory.path}/books');
    expect(
      await booksDirectory
          .list()
          .where((entry) =>
              entry.path.endsWith('.part') || entry.path.endsWith('.txt'))
          .isEmpty,
      isTrue,
    );
  });

  test('persists a source-provided cover for offline shelf display', () async {
    final directory = await Directory.systemTemp.createTemp('source-cover-');
    addTearDown(() => directory.delete(recursive: true));
    final dao = _MemoryBookDao();
    final sourceCoverCache = SourceCoverCache(
      cacheDirectory: Directory('${directory.path}/cache'),
      loader: (_) async => Uint8List.fromList([1, 2, 3, 4]),
    );
    final service = BookSourceShelfService(
      bookDao: dao,
      downloadDirectory: directory,
      sourceCoverCache: sourceCoverCache,
    );

    final added = await service.addOnline(
      source: _source,
      book: _sourceBookWithCover,
    );

    expect(added.coverImagePath, isNotNull);
    expect(await File(added.coverImagePath!).readAsBytes(), [1, 2, 3, 4]);
    expect(
      service.sourceBookFrom(added).coverUrl,
      _sourceBookWithCover.coverUrl,
    );
  });
}

final _source = RegisteredBookSource(
  id: 'source-id',
  name: '测试书源',
  description: '',
  manifestUrl: Uri.parse('https://example.org/source.json'),
  apiBaseUrl: Uri.parse('https://example.org/api/'),
  protocolVersion: '1.0',
  languages: const ['zh-CN'],
  capabilities: const {'search', 'catalog', 'content'},
  enabled: true,
  addedAt: DateTime.utc(2026, 7, 12),
);

const _sourceBook = BookSourceBook(
  id: 'book-id',
  title: '测试书籍',
  author: '作者',
  description: '简介',
  categories: [],
);

final _sourceBookWithCover = BookSourceBook(
  id: 'book-with-cover',
  title: '有封面的书',
  author: '作者',
  description: '简介',
  coverUrl: Uri.parse('https://example.org/cover.jpg'),
  categories: const [],
);

class _MemoryBookDao extends BookDao {
  Book? stored;
  int insertCount = 0;

  @override
  Future<Book?> getBookBySource({
    required String sourceId,
    required String sourceBookId,
  }) async =>
      stored;

  @override
  Future<int> insertBook(Book book) async {
    insertCount++;
    stored = book.copyWith(id: 7);
    return 7;
  }
}

class _DownloadClient extends BookSourceClient {
  int active = 0;
  int maxActive = 0;

  @override
  Future<List<BookSourceChapter>> getChaptersForDownload(
    RegisteredBookSource source,
    String bookId, {
    BookDownloadCancellation? cancellation,
  }) async =>
      List.generate(
        7,
        (index) => BookSourceChapter(
          id: 'chapter-$index',
          title: '第${index + 1}章',
          order: index,
        ),
      );

  @override
  Future<BookSourceChapterContent> getChapterContentForDownload(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
    BookDownloadCancellation? cancellation,
  }) async {
    active++;
    if (active > maxActive) maxActive = active;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    active--;
    final index = int.parse(chapterId.split('-').last);
    return BookSourceChapterContent(
      bookId: bookId,
      chapterId: chapterId,
      title: '',
      content: '正文$index',
      contentType: 'text/plain',
    );
  }
}

class _StreamingDownloadClient extends BookSourceClient {
  final secondBatchStarted = Completer<void>();
  final releaseSecondBatch = Completer<void>();
  int active = 0;
  int maxActive = 0;

  @override
  Future<List<BookSourceChapter>> getChaptersForDownload(
    RegisteredBookSource source,
    String bookId, {
    BookDownloadCancellation? cancellation,
  }) async =>
      List.generate(
        6,
        (index) => BookSourceChapter(
          id: 'chapter-$index',
          title: '第${index + 1}章',
          order: index,
        ),
      );

  @override
  Future<BookSourceChapterContent> getChapterContentForDownload(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
    BookDownloadCancellation? cancellation,
  }) async {
    active++;
    if (active > maxActive) maxActive = active;
    try {
      final index = int.parse(chapterId.split('-').last);
      if (index >= 3) {
        if (!secondBatchStarted.isCompleted) secondBatchStarted.complete();
        await releaseSecondBatch.future;
      }
      return BookSourceChapterContent(
        bookId: bookId,
        chapterId: chapterId,
        title: '',
        content: '正文$index',
        contentType: 'text/plain',
      );
    } finally {
      active--;
    }
  }
}

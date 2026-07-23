import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_chapter_cache.dart';

void main() {
  setUp(BookSourceChapterCache.clearMemory);

  test('returns loaded chapter before its disk write completes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'source-chapter-nonblocking-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final writeStarted = Completer<void>();
    final allowWrite = Completer<void>();
    addTearDown(() {
      if (!allowWrite.isCompleted) allowWrite.complete();
    });
    final cache = BookSourceChapterCache(
      cacheDirectory: directory,
      beforeDiskWrite: () {
        writeStarted.complete();
        return allowWrite.future;
      },
    );

    final result = cache.getOrLoad(
      sourceId: 'source',
      bookId: 'book',
      chapterId: 'chapter',
      loader: () async => const BookSourceChapterContent(
        bookId: 'book',
        chapterId: 'chapter',
        title: '第一章',
        content: '正文',
        contentType: 'text/plain',
      ),
    );

    await writeStarted.future;
    expect((await result).content, '正文');
    expect(allowWrite.isCompleted, isFalse);
    allowWrite.complete();
    await _waitForJsonFile(directory);
  });

  test('returns loaded catalog before its disk write completes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'source-catalog-nonblocking-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final writeStarted = Completer<void>();
    final allowWrite = Completer<void>();
    addTearDown(() {
      if (!allowWrite.isCompleted) allowWrite.complete();
    });
    final cache = BookSourceChapterCache(
      cacheDirectory: directory,
      beforeDiskWrite: () {
        writeStarted.complete();
        return allowWrite.future;
      },
    );

    final result = cache.getChapterCatalogOrLoad(
      sourceId: 'source',
      bookId: 'book',
      loader: () async => const [
        BookSourceChapter(id: 'chapter', title: '第一章', order: 1),
      ],
    );

    await writeStarted.future;
    expect((await result).single.id, 'chapter');
    expect(allowWrite.isCompleted, isFalse);
    allowWrite.complete();
    await _waitForJsonFile(directory);
  });

  test('ignores background disk write failures without async errors', () async {
    final errors = <Object>[];

    await runZonedGuarded(() async {
      final cache = BookSourceChapterCache(
        beforeDiskWrite: () async =>
            throw const FileSystemException('cache unavailable'),
      );

      final chapter = await cache.getOrLoad(
        sourceId: 'failure-source',
        bookId: 'failure-book',
        chapterId: 'failure-chapter',
        loader: () async => const BookSourceChapterContent(
          bookId: 'failure-book',
          chapterId: 'failure-chapter',
          title: '失败缓存章节',
          content: '仍可阅读',
          contentType: 'text/plain',
        ),
      );
      final catalog = await cache.getChapterCatalogOrLoad(
        sourceId: 'failure-source',
        bookId: 'failure-book',
        loader: () async => const [
          BookSourceChapter(id: 'failure-chapter', title: '失败缓存章节', order: 1),
        ],
      );

      expect(chapter.content, '仍可阅读');
      expect(catalog.single.id, 'failure-chapter');
      await Future<void>.delayed(Duration.zero);
    }, (error, _) => errors.add(error));

    expect(errors, isEmpty);
  });

  test(
    'serializes writes for the same chapter and keeps the newest value',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'source-chapter-write-order-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final firstWriteStarted = Completer<void>();
      final secondWriteStarted = Completer<void>();
      final allowFirstWrite = Completer<void>();
      final allowSecondWrite = Completer<void>();
      addTearDown(() {
        if (!allowFirstWrite.isCompleted) allowFirstWrite.complete();
        if (!allowSecondWrite.isCompleted) allowSecondWrite.complete();
      });
      var writeCount = 0;
      final cache = BookSourceChapterCache(
        cacheDirectory: directory,
        beforeDiskWrite: () {
          writeCount++;
          if (writeCount == 1) {
            firstWriteStarted.complete();
            return allowFirstWrite.future;
          }
          secondWriteStarted.complete();
          return allowSecondWrite.future;
        },
      );

      await cache.getOrLoad(
        sourceId: 'source',
        bookId: 'book',
        chapterId: 'chapter',
        loader: () async => const BookSourceChapterContent(
          bookId: 'book',
          chapterId: 'chapter',
          title: '第一版',
          content: '旧正文',
          contentType: 'text/plain',
        ),
      );
      await firstWriteStarted.future;
      await cache.getOrLoad(
        sourceId: 'source',
        bookId: 'book',
        chapterId: 'chapter',
        refreshAfter: Duration.zero,
        staleWhileRevalidate: false,
        loader: () async => const BookSourceChapterContent(
          bookId: 'book',
          chapterId: 'chapter',
          title: '第二版',
          content: '新正文',
          contentType: 'text/plain',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(secondWriteStarted.isCompleted, isFalse);

      allowFirstWrite.complete();
      await secondWriteStarted.future;
      allowSecondWrite.complete();
      await _waitForJsonContent(directory, '新正文');
      BookSourceChapterCache.clearMemory();

      final restored = await BookSourceChapterCache(cacheDirectory: directory)
          .getOrLoad(
            sourceId: 'source',
            bookId: 'book',
            chapterId: 'chapter',
            loader: () => throw StateError('disk cache should contain newest'),
          );
      expect(restored.content, '新正文');
    },
  );

  test(
    'a cache clear prevents an older background write from reviving disk',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'source-chapter-clear-generation-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final writeStarted = Completer<void>();
      final allowWrite = Completer<void>();
      addTearDown(() {
        if (!allowWrite.isCompleted) allowWrite.complete();
      });
      final cache = BookSourceChapterCache(
        cacheDirectory: directory,
        beforeDiskWrite: () {
          writeStarted.complete();
          return allowWrite.future;
        },
      );

      await cache.getOrLoad(
        sourceId: 'source',
        bookId: 'book',
        chapterId: 'chapter',
        loader: () async => const BookSourceChapterContent(
          bookId: 'book',
          chapterId: 'chapter',
          title: '待清理',
          content: '不应复活',
          contentType: 'text/plain',
        ),
      );
      await writeStarted.future;
      BookSourceChapterCache.clearMemory();
      allowWrite.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        await directory
            .list(recursive: true)
            .where((entity) => entity is File && entity.path.endsWith('.json'))
            .isEmpty,
        isTrue,
      );
    },
  );

  test(
    'deduplicates concurrent chapter requests and keeps a memory cache',
    () async {
      const cache = BookSourceChapterCache();
      var loads = 0;

      Future<BookSourceChapterContent> loader() async {
        loads++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return const BookSourceChapterContent(
          bookId: 'book',
          chapterId: 'chapter',
          title: '第一章',
          content: '正文',
          contentType: 'text/plain',
        );
      }

      final results = await Future.wait([
        cache.getOrLoad(
          sourceId: 'source',
          bookId: 'book',
          chapterId: 'chapter',
          loader: loader,
        ),
        cache.getOrLoad(
          sourceId: 'source',
          bookId: 'book',
          chapterId: 'chapter',
          loader: loader,
        ),
      ]);
      final cached = await cache.getOrLoad(
        sourceId: 'source',
        bookId: 'book',
        chapterId: 'chapter',
        loader: loader,
      );

      expect(loads, 1);
      expect(results.first.content, '正文');
      expect(cached.content, '正文');
    },
  );

  test(
    'reuses chapter content from disk after the cache is recreated',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'source-chapter-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      var loads = 0;

      Future<BookSourceChapterContent> loader() async {
        loads++;
        return const BookSourceChapterContent(
          bookId: 'disk-book',
          chapterId: 'disk-chapter',
          title: '磁盘章节',
          content: '落盘正文',
          contentType: 'text/plain',
        );
      }

      await BookSourceChapterCache(cacheDirectory: directory).getOrLoad(
        sourceId: 'disk-source',
        sourceRevision: 'https://example.org/api/',
        bookId: 'disk-book',
        chapterId: 'disk-chapter',
        loader: loader,
      );
      await _waitForJsonFile(directory);
      BookSourceChapterCache.clearMemory();
      final cached = await BookSourceChapterCache(cacheDirectory: directory)
          .getOrLoad(
            sourceId: 'disk-source',
            sourceRevision: 'https://example.org/api/',
            bookId: 'disk-book',
            chapterId: 'disk-chapter',
            loader: loader,
          );

      expect(loads, 1);
      expect(cached.content, '落盘正文');
    },
  );

  test(
    'returns stale chapter content while refreshing it in background',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'source-chapter-refresh-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final cache = BookSourceChapterCache(cacheDirectory: directory);
      var loads = 0;

      Future<BookSourceChapterContent> loader() async {
        loads++;
        return BookSourceChapterContent(
          bookId: 'refresh-book',
          chapterId: 'refresh-chapter',
          title: '刷新章节',
          content: '正文 $loads',
          contentType: 'text/plain',
        );
      }

      final first = await cache.getOrLoad(
        sourceId: 'refresh-source',
        bookId: 'refresh-book',
        chapterId: 'refresh-chapter',
        refreshAfter: Duration.zero,
        loader: loader,
      );
      final second = await cache.getOrLoad(
        sourceId: 'refresh-source',
        bookId: 'refresh-book',
        chapterId: 'refresh-chapter',
        refreshAfter: Duration.zero,
        loader: loader,
      );

      expect(first.content, '正文 1');
      expect(second.content, '正文 1');
      for (var attempt = 0; attempt < 20 && loads < 2; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(loads, 2);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final refreshed = await cache.getOrLoad(
        sourceId: 'refresh-source',
        bookId: 'refresh-book',
        chapterId: 'refresh-chapter',
        loader: loader,
      );
      expect(refreshed.content, '正文 2');
    },
  );

  test(
    'returns a cached catalog immediately and refreshes it in background',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'source-catalog-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final cache = BookSourceChapterCache(cacheDirectory: directory);
      var loads = 0;

      Future<List<BookSourceChapter>> loader() async {
        loads++;
        return [
          BookSourceChapter(
            id: 'chapter-$loads',
            title: '第 $loads 章',
            order: loads,
          ),
        ];
      }

      final first = await cache.getChapterCatalogOrLoad(
        sourceId: 'catalog-source',
        sourceRevision: 'https://example.org/api/',
        bookId: 'catalog-book',
        refreshAfter: Duration.zero,
        loader: loader,
      );
      final second = await cache.getChapterCatalogOrLoad(
        sourceId: 'catalog-source',
        sourceRevision: 'https://example.org/api/',
        bookId: 'catalog-book',
        refreshAfter: Duration.zero,
        loader: loader,
      );

      expect(first.single.id, 'chapter-1');
      expect(second.single.id, 'chapter-1');
      for (var attempt = 0; attempt < 20 && loads < 2; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(loads, 2);

      final refreshed = await cache.getChapterCatalogOrLoad(
        sourceId: 'catalog-source',
        sourceRevision: 'https://example.org/api/',
        bookId: 'catalog-book',
        loader: loader,
      );
      expect(refreshed.single.id, 'chapter-2');
    },
  );
}

Future<void> _waitForJsonFile(Directory directory) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final files = await directory
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .toList();
    if (files.isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for the cache file to be persisted.');
}

Future<void> _waitForJsonContent(Directory directory, String content) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final files = await directory
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    for (final file in files) {
      if ((await file.readAsString()).contains(content)) return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for the newest cache content to be persisted.');
}

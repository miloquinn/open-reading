import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_chapter_cache.dart';

void main() {
  setUp(BookSourceChapterCache.clearMemory);

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

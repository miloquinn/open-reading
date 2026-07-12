import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_chapter_cache.dart';

void main() {
  test('deduplicates concurrent chapter requests and keeps a memory cache',
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
  });
}

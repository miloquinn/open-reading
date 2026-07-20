import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_chapter_text.dart';

void main() {
  test('plain source text preserves paragraph structure and existing indent',
      () {
    const content = BookSourceChapterContent(
      bookId: 'book',
      chapterId: 'chapter',
      title: 'Chapter',
      content: '  第一段\r\n\r\n\t第二段',
      contentType: 'text/plain',
    );

    expect(
      readableBookSourceChapterText(content),
      '  第一段\n\n\t第二段',
    );
  });

  test('html extraction produces canonical paragraphs without visual indent',
      () {
    const content = BookSourceChapterContent(
      bookId: 'book',
      chapterId: 'chapter',
      title: 'Chapter',
      content: '<div><p>第一段</p><p>第二段<br>续行</p></div>',
      contentType: 'text/html',
    );

    expect(
      readableBookSourceChapterText(content),
      '第一段\n第二段\n续行',
    );
  });

  test('removes a repeated plain-text chapter title only at the beginning', () {
    const content = BookSourceChapterContent(
      bookId: 'book',
      chapterId: 'chapter',
      title: '第一章 归来',
      content: '第一章　归来\n\n正文第一段\n正文提到第一章 归来但不能删除',
      contentType: 'text/plain',
    );

    expect(
      readableBookSourceChapterText(content),
      '正文第一段\n正文提到第一章 归来但不能删除',
    );
  });

  test('uses the catalog title when chapter content omits its title field', () {
    const content = BookSourceChapterContent(
      bookId: 'book',
      chapterId: 'chapter',
      title: '',
      content: '# Chapter 8\nBody text',
      contentType: 'text/plain',
    );

    expect(
      readableBookSourceChapterText(content, fallbackTitle: 'Chapter 8'),
      'Body text',
    );
  });

  test('keeps a leading sentence that only contains the chapter title', () {
    const content = BookSourceChapterContent(
      bookId: 'book',
      chapterId: 'chapter',
      title: '第一章',
      content: '第一章的故事从这里开始。\n第二段',
      contentType: 'text/plain',
    );

    expect(
      readableBookSourceChapterText(content),
      '第一章的故事从这里开始。\n第二段',
    );
  });
}

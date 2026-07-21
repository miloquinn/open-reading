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

  test('plain text mislabelled as html keeps paragraph breaks', () {
    // Regression: sources that declare `text/html` but return plain,
    // newline-separated text used to be routed through the HTML extractor,
    // which collapsed every paragraph separator into a single space. The
    // shared layout layer then saw one giant paragraph and could only indent
    // the very first line. Content sniffing must route this payload through
    // the plain-text path regardless of the declared content type.
    const content = BookSourceChapterContent(
      bookId: 'book',
      chapterId: 'chapter',
      title: 'Chapter',
      content: '第一段\n第二段\n第三段',
      contentType: 'text/html',
    );

    expect(
      readableBookSourceChapterText(content),
      '第一段\n第二段\n第三段',
    );
  });

  test('html mislabelled as plain text is still extracted as html', () {
    // Symmetric regression: a source that declares `text/plain` but returns
    // real HTML must still be parsed as HTML, otherwise the tags would leak
    // into the rendered text.
    const content = BookSourceChapterContent(
      bookId: 'book',
      chapterId: 'chapter',
      title: 'Chapter',
      content: '<p>第一段</p><p>第二段</p>',
      contentType: 'text/plain',
    );

    expect(
      readableBookSourceChapterText(content),
      '第一段\n第二段',
    );
  });

  test(
      'html paragraphs separated only by a bare newline still split '
      'around a stray inline tag', () {
    // Regression: a chapter wrapped in a single tag (routing it through the
    // HTML extractor) but whose paragraphs are separated only by `\n`, with
    // one stray inline tag (e.g. an illustration) in the middle. Previously
    // the `\s+` collapse in flush() ate literal newlines just like any other
    // whitespace, merging every paragraph around the stray tag into one
    // line, so only the paragraphs next to a real block/`<br>` boundary got
    // indented by the reader.
    const content = BookSourceChapterContent(
      bookId: 'book',
      chapterId: 'chapter',
      title: 'Chapter',
      content: '<div>第一段\n第二段\n<img src="1.jpg"/>\n第三段\n第四段</div>',
      contentType: 'text/html',
    );

    expect(
      readableBookSourceChapterText(content),
      '第一段\n第二段\n第三段\n第四段',
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

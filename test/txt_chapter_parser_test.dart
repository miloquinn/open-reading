import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/txt_chapter_parser.dart';

void main() {
  test('recognized chapter headings are stored separately from body text', () {
    const source =
        '书籍说明\r\n\r\n'
        '第十二章  风暴将至\r\n\r\n'
        '天边压着墨色的云。\r\n第二段。\r\n\r\n'
        '第十三章 雨夜\r\n雨落了下来。\r\n';

    final chapters = parseTxtChapterSections(
      source,
      fallbackTitle: '测试书',
      prefaceTitle: '前言',
    );

    expect(chapters, hasLength(3));
    expect(chapters[0].title, '前言');
    expect(chapters[0].isNeedSplitTitle, isFalse);
    expect(chapters[0].bodyIn(source), '书籍说明');

    expect(chapters[1].title, '第十二章  风暴将至');
    expect(chapters[1].isNeedSplitTitle, isTrue);
    expect(chapters[1].bodyIn(source), '天边压着墨色的云。\r\n第二段。');
    expect(chapters[1].bodyIn(source), isNot(contains('第十二章')));

    expect(chapters[2].title, '第十三章 雨夜');
    expect(chapters[2].bodyIn(source), '雨落了下来。');
  });

  test('markdown-style and English headings request dedicated title pages', () {
    const source =
        '### Chapter 1 - Arrival\nBody one.\n\nPart 2: Return\nBody two.';
    final chapters = parseTxtChapterSections(
      source,
      fallbackTitle: 'Book',
      prefaceTitle: 'Preface',
    );

    expect(chapters.map((chapter) => chapter.title), <String>[
      'Chapter 1 - Arrival',
      'Part 2: Return',
    ]);
    expect(chapters.every((chapter) => chapter.isNeedSplitTitle), isTrue);
    expect(chapters[0].bodyIn(source), 'Body one.');
    expect(chapters[1].bodyIn(source), 'Body two.');
  });

  test(
    'unstructured TXT remains one body without an artificial title page',
    () {
      const source = '第一段正文。\n\n第二段正文。';
      final chapters = parseTxtChapterSections(
        source,
        fallbackTitle: '文件名书名',
        prefaceTitle: '前言',
      );

      expect(chapters, hasLength(1));
      expect(chapters.single.title, '文件名书名');
      expect(chapters.single.isNeedSplitTitle, isFalse);
      expect(chapters.single.bodyIn(source), source);
    },
  );

  test('chapter splitting recognizes Unicode hard line breaks', () {
    const source = '书籍说明\u2028前言正文\u2029第1章 开始\u2028第一段正文';
    final chapters = parseTxtChapterSections(
      source,
      fallbackTitle: 'Book',
      prefaceTitle: 'Preface',
    );

    expect(chapters.map((chapter) => chapter.title), <String>[
      'Preface',
      '第1章 开始',
    ]);
    expect(chapters[0].bodyIn(source), '书籍说明\u2028前言正文');
    expect(chapters[1].bodyIn(source), '第一段正文');
  });
}

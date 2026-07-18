import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/book_sources/services/book_source_text_paginator.dart';
import 'package:xxread/core/reader/reader_text_layout.dart';

void main() {
  const style = TextStyle(fontSize: 18, height: 1.7);

  testWidgets('splits long text into non-empty pages without losing content',
      (tester) async {
    final text = List.generate(
      80,
      (index) => '\u3000\u3000第$index段正文用于测试分页是否完整。',
    ).join('\n');

    final pages = paginateBookSourceText(
      text,
      width: 320,
      firstPageHeight: 360,
      pageHeight: 480,
      style: style,
      textDirection: TextDirection.ltr,
    );

    expect(pages.length, greaterThan(1));
    expect(pages.every((page) => page.text.isNotEmpty), isTrue);
    expectCanonicalCoverage(pages, text);
    expect(pages.first.showsChapterTitle, isTrue);
    expect(pages.skip(1).every((page) => !page.showsChapterTitle), isTrue);
  });

  testWidgets('does not split an emoji surrogate pair', (tester) async {
    final text = List.filled(120, '文字📖翻页。').join();
    final pages = paginateBookSourceText(
      text,
      width: 180,
      firstPageHeight: 120,
      pageHeight: 140,
      style: style,
      textDirection: TextDirection.ltr,
    );

    expect(pages.map((page) => page.text).join(), text);
    for (final page in pages) {
      expect(page.text.codeUnits.last, isNot(inInclusiveRange(0xD800, 0xDBFF)));
      expect(
          page.text.codeUnits.first, isNot(inInclusiveRange(0xDC00, 0xDFFF)));
    }
  });

  testWidgets('paginates a phone reader chapter at wide test viewport',
      (tester) async {
    final text = List.generate(
      80,
      (index) => '测试正文第$index段，用于验证书源阅读分页模式。',
    ).join(r'\n');
    final pages = paginateBookSourceText(
      text,
      width: 756,
      firstPageHeight: 450,
      pageHeight: 532,
      style: const TextStyle(fontSize: 19, height: 1.75),
      textDirection: TextDirection.ltr,
    );

    expect(pages.length, greaterThan(1));
  });

  testWidgets('preserves content when layout dimensions are not ready',
      (tester) async {
    const text = 'Chapter content should stay available.';

    final pages = paginateBookSourceText(
      text,
      width: 0,
      firstPageHeight: 360,
      pageHeight: 480,
      style: style,
      textDirection: TextDirection.ltr,
    );

    expect(pages, hasLength(1));
    expect(pages.single.text, text);
    expect(pages.single.showsChapterTitle, isTrue);
    expect(pages.single.startOffset, 0);
    expect(pages.single.endOffset, text.length);
  });

  testWidgets('preserves long content when continuing page height is invalid',
      (tester) async {
    final text = List.filled(60, 'Long chapter content.').join('\n');

    final pages = paginateBookSourceText(
      text,
      width: 180,
      firstPageHeight: 120,
      pageHeight: 0,
      style: style,
      textDirection: TextDirection.ltr,
    );

    expect(pages, hasLength(1));
    expect(pages.single.text, text);
    expect(pages.single.startOffset, 0);
    expect(pages.single.endOffset, text.length);
  });

  testWidgets('does not strand Chinese closing punctuation at a page start',
      (tester) async {
    const sentence =
        '\u3000\u3000\u67ef\u7136\u95ee\uff0c\u201c\u8fd8\u80fd\u7ad9\u7a33\u5417\uff1f'
        '\u5b9d\u5b9d\u3002\u201d\u6c88\u96fe\u7720\u8f7b\u8f7b\u5e94\u4e86\u4e00\u58f0\u3002';
    final text = List.filled(24, sentence).join('\n');
    const closingPunctuation =
        '\u201d\u2019\u300d\u300f\u3011\uff09\u300b\u3009\u3015\uff3d\uff5d';

    for (final width in <double>[180, 220, 260, 320]) {
      for (final height in <double>[120, 180, 260]) {
        final pages = paginateBookSourceText(
          text,
          width: width,
          firstPageHeight: height,
          pageHeight: height,
          style: const TextStyle(fontSize: 24, height: 1.75),
          textDirection: TextDirection.ltr,
          locale: const Locale('zh', 'CN'),
        );

        expectCanonicalCoverage(pages, text);
        for (final page in pages.skip(1)) {
          final firstCharacter = page.text.trimLeft()[0];
          expect(
            closingPunctuation.contains(firstCharacter),
            isFalse,
            reason: 'width=$width height=$height page=${page.text}',
          );
        }
      }
    }
  });

  test('removes repeated source page markers but preserves ordinary fractions',
      () {
    final cleaned = removeRepeatedSourcePageMarkers(const <String>[
      '正文第一页',
      '6/29',
      '正文第二页',
      '7 / 29',
      '正文第三页',
      '8/29',
      '完成比例为 7/29',
      '1/2',
    ]);

    expect(
      cleaned,
      const <String>[
        '正文第一页',
        '正文第二页',
        '正文第三页',
        '完成比例为 7/29',
        '1/2',
      ],
    );
  });

  testWidgets('restores the same text anchor after line-height repagination',
      (tester) async {
    final text = List.generate(
      60,
      (index) => '\u3000\u3000第$index段正文用于验证行距变化后的字符锚点恢复。',
    ).join('\n');
    List<BookSourceTextPage> paginate(double lineHeight) =>
        paginateBookSourceText(
          text,
          width: 280,
          firstPageHeight: 360,
          pageHeight: 460,
          style: TextStyle(fontSize: 24, height: lineHeight),
          textDirection: TextDirection.ltr,
          locale: const Locale('zh', 'CN'),
        );

    final compactPages = paginate(1.4);
    final anchor = compactPages[compactPages.length ~/ 2].startOffset;
    final spaciousPages = paginate(2.1);
    final restoredIndex = bookSourcePageIndexForOffset(spaciousPages, anchor);
    final restoredPage = spaciousPages[restoredIndex];

    expect(spaciousPages.length, greaterThan(compactPages.length));
    expect(restoredPage.startOffset, lessThanOrEqualTo(anchor));
    expect(restoredPage.endOffset, greaterThan(anchor));
    expectCanonicalCoverage(spaciousPages, text);
  });

  testWidgets(
      'keeps canonical offsets contiguous while indent and spacing alter display text',
      (tester) async {
    final text = List.generate(
      36,
      (index) => index.isEven
          ? '  第$index段包含原有半角缩进和足够长的分页正文。'
          : '\t第$index段包含原有制表符缩进和足够长的分页正文。',
    ).join('\r\n');
    final pages = paginateBookSourceText(
      text,
      width: 190,
      firstPageHeight: 130,
      pageHeight: 150,
      style: style,
      textDirection: TextDirection.ltr,
      locale: const Locale('zh', 'CN'),
      firstLineIndent: 2,
      paragraphSpacing: 1,
    );
    final displayLayout = ReaderTextLayout.build(
      text,
      firstLineIndent: 2,
      paragraphSpacing: 1,
    );

    expect(pages.length, greaterThan(1));
    expect(pages.map((page) => page.text).join(), displayLayout.text);
    expect(pages.map((page) => page.text).join(), isNot(text));
    expectCanonicalCoverage(pages, text);

    for (final offset in <int>[0, 1, text.length ~/ 2, text.length - 1]) {
      final page = pages[bookSourcePageIndexForOffset(pages, offset)];
      expect(page.startOffset, lessThanOrEqualTo(offset));
      expect(page.endOffset, greaterThan(offset));
    }
  });

  testWidgets('keeps an all-indent chapter addressable with zero indentation',
      (tester) async {
    const text = ' \t\u3000  ';
    final pages = paginateBookSourceText(
      text,
      width: 180,
      firstPageHeight: 120,
      pageHeight: 140,
      style: style,
      textDirection: TextDirection.ltr,
      firstLineIndent: 0,
      paragraphSpacing: 2,
    );

    expect(pages, hasLength(1));
    expect(pages.single.text, isEmpty);
    expectCanonicalCoverage(pages, text);
  });
}

void expectCanonicalCoverage(List<BookSourceTextPage> pages, String source) {
  expect(pages, isNotEmpty);
  expect(pages.first.startOffset, 0);
  expect(pages.last.endOffset, source.length);
  for (var index = 0; index < pages.length; index++) {
    final page = pages[index];
    expect(page.startOffset, inInclusiveRange(0, source.length));
    expect(page.endOffset, inInclusiveRange(page.startOffset, source.length));
    if (index > 0) {
      expect(page.startOffset, pages[index - 1].endOffset);
    }
  }
}

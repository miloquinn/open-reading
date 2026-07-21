import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/native_text_paginator.dart';
import 'package:xxread/core/reader/reader_text_layout.dart';

void main() {
  test('normalizes existing indentation without changing canonical boundaries',
      () {
    const source = '\u3000\u3000第一段\n第二段';
    final layout = ReaderTextLayout.build(source, firstLineIndent: 2);

    expect(layout.text, '\u3000\u3000第一段\n\u3000\u3000第二段');
    expect(layout.sourceOffsetForDisplayOffset(0), 0);
    expect(
      layout.sourceOffsetForDisplayOffset(layout.text.length),
      source.length,
    );
  });

  test('zero indent can hide canonical leading spaces without offset drift',
      () {
    const source = '\u3000\u3000正文\n\u3000下一段';
    final layout = ReaderTextLayout.build(source, firstLineIndent: 0);

    expect(layout.text, '正文\n下一段');
    expect(layout.sourceOffsetForDisplayOffset(0), 0);
    expect(
      layout.sourceOffsetForDisplayOffset(layout.text.length),
      source.length,
    );
  });

  test('recognizes Unicode hard breaks and display whitespace in TXT', () {
    const source = '\u00a0第一段\u2028\u2003第二段\u2029\u202f第三段\u0085第四段\u000b第五段';
    final layout = ReaderTextLayout.build(source, firstLineIndent: 2);

    expect(
      layout.text,
      '\u3000\u3000第一段\u2028'
      '\u3000\u3000第二段\u2029'
      '\u3000\u3000第三段\u0085'
      '\u3000\u3000第四段\u000b'
      '\u3000\u3000第五段',
    );
    expect(
        layout.sourceOffsetForDisplayOffset(layout.text.length), source.length);
  });

  test('normalizes EPUB paragraph breaks without changing source offsets', () {
    const source = '第一段\r\n\r\n第二段\u2028\u2029第三段\n\n第四段';
    const expectedBySpacing = <int, String>{
      0: '第一段\n第二段\n第三段\n第四段',
      1: '第一段\n\n第二段\n\n第三段\n\n第四段',
      2: '第一段\n\n\n第二段\n\n\n第三段\n\n\n第四段',
    };

    for (final entry in expectedBySpacing.entries) {
      final layout = ReaderTextLayout.build(
        source,
        paragraphSpacing: entry.key,
        normalizeParagraphBreaks: true,
      );

      expect(layout.text, entry.value);
      expect(layout.sourceOffsetForDisplayOffset(0), 0);
      expect(
        layout.sourceOffsetForDisplayOffset(layout.text.length),
        source.length,
      );
      var previous = 0;
      for (var offset = 0; offset <= layout.text.length; offset++) {
        final mapped = layout.sourceOffsetForDisplayOffset(offset);
        expect(mapped, inInclusiveRange(previous, source.length));
        previous = mapped;
      }
    }
  });

  test('EPUB normalization leaves a single hard line break intact', () {
    const source = '诗歌第一行\n诗歌第二行';
    final layout = ReaderTextLayout.build(
      source,
      normalizeParagraphBreaks: true,
    );

    expect(layout.text, source);
  });

  test('EPUB normalization removes a leading parser paragraph separator', () {
    const source = '\r\n\r\n图片后的第一段';
    final layout = ReaderTextLayout.build(
      source,
      paragraphSpacing: 2,
      normalizeParagraphBreaks: true,
    );

    expect(layout.text, '图片后的第一段');
    expect(layout.sourceOffsetForDisplayOffset(0), 0);
    expect(
      layout.sourceOffsetForDisplayOffset(layout.text.length),
      source.length,
    );
  });

  test(
      'maps CRLF, blank paragraphs, and a non-zero source offset monotonically',
      () {
    const source = '第一段\r\n   \r\n\t第二段\n\n\u3000第三段';
    const sourceOffset = 37;
    final layout = ReaderTextLayout.build(
      source,
      sourceOffset: sourceOffset,
      firstLineIndent: 2,
      paragraphSpacing: 2,
    );

    expect(layout.sourceOffsetForDisplayOffset(0), sourceOffset);
    expect(
      layout.sourceOffsetForDisplayOffset(layout.text.length),
      sourceOffset + source.length,
    );
    var previous = sourceOffset;
    for (var displayOffset = 0;
        displayOffset <= layout.text.length;
        displayOffset++) {
      final mapped = layout.sourceOffsetForDisplayOffset(displayOffset);
      expect(mapped, inInclusiveRange(previous, sourceOffset + source.length));
      previous = mapped;
    }
  });

  testWidgets('pagination keeps source ranges contiguous with paragraph gaps',
      (tester) async {
    const source = '第一段有足够多的文字用于分页测试。第一段继续。\n第二段也有足够多的文字。\n第三段结束。';
    const style = TextStyle(fontSize: 18, height: 1.6);
    final layout = ReaderTextLayout.build(
      source,
      firstLineIndent: 2,
      paragraphSpacing: 1,
    );
    final flow = NativeTextFlowStyle(
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: const Locale('zh'),
      strutStyle: readerStrutStyle(style),
      textHeightBehavior: readerTextHeightBehavior,
    );
    final ranges = NativeTextPaginator(
      maxWidth: 160,
      maxHeight: 96,
      flowStyle: flow,
    ).paginate(
      text: layout.text,
      spanBuilder: (start, end) => layout.buildSpan(
        start,
        end,
        sourceSpanBuilder: (sourceStart, sourceEnd) => TextSpan(
          text: source.substring(sourceStart, sourceEnd),
          style: style,
        ),
        generatedStyle: style,
      ),
    );
    final sourceRanges = [
      for (final range in ranges)
        (
          layout.sourceOffsetForDisplayOffset(range.start),
          layout.sourceOffsetForDisplayOffset(range.end),
        ),
    ];

    expect(sourceRanges.first.$1, 0);
    expect(sourceRanges.last.$2, source.length);
    for (var index = 1; index < sourceRanges.length; index++) {
      expect(sourceRanges[index - 1].$2, sourceRanges[index].$1);
      expect(
        sourceRanges[index].$2,
        greaterThanOrEqualTo(sourceRanges[index].$1),
      );
    }
  });

  testWidgets('normalized EPUB paragraphs keep visible text dense',
      (tester) async {
    const style = TextStyle(fontSize: 19, height: 1.75);
    final source = List.generate(
      48,
      (index) => '第$index段用于验证紧凑排版，段落之间不应预留不可见的整行空白。',
    ).join('\n\n');
    final layout = ReaderTextLayout.build(
      source,
      paragraphSpacing: 0,
      normalizeParagraphBreaks: true,
    );
    final flow = NativeTextFlowStyle(
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: const Locale('zh', 'CN'),
      strutStyle: readerStrutStyle(style),
      textHeightBehavior: readerTextHeightBehavior,
    );
    const width = 320.0;
    const height = 520.0;
    TextSpan buildSpan(int start, int end) => layout.buildSpan(
          start,
          end,
          sourceSpanBuilder: (sourceStart, sourceEnd) => TextSpan(
            text: source.substring(sourceStart, sourceEnd),
            style: style,
          ),
          generatedStyle: style,
        );
    final pages = NativeTextPaginator(
      maxWidth: width,
      maxHeight: height,
      flowStyle: flow,
    ).paginate(
      text: layout.text,
      spanBuilder: buildSpan,
    );

    expect(pages.length, greaterThan(1));
    for (final page in pages.take(pages.length - 1)) {
      final painter = flow.createPainter(buildSpan(page.start, page.end))
        ..layout(maxWidth: width);
      final metrics = painter.computeLineMetrics();
      final pageText = layout.text.substring(page.start, page.end);
      var lastVisibleInkBottom = 0.0;
      for (final metric in metrics) {
        final position = painter.getPositionForOffset(
          Offset(
            metric.left + (metric.width / 2),
            metric.baseline - (metric.ascent / 2),
          ),
        );
        final boundary = painter.getLineBoundary(position);
        if (pageText
            .substring(boundary.start, boundary.end)
            .trim()
            .isNotEmpty) {
          lastVisibleInkBottom = metric.baseline + metric.descent;
        }
      }
      expect(
        lastVisibleInkBottom,
        greaterThan(height * 0.72),
        reason: 'non-final pages should not count invisible blank rows as fill',
      );
      painter.dispose();
    }
  });
}

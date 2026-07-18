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
}

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/native_text_paginator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 字体不内置后，测试用系统默认字体跑文本布局断言；不再 rootBundle.load 已删字体。

  const fontSize = 20.0;
  const lineHeight = 1.8;
  const style = TextStyle(
    fontSize: fontSize,
    height: lineHeight,
    color: Color(0xFF000000),
  );
  const twoLines = TextSpan(text: 'First line\nSecond line', style: style);

  TextPainter layout({StrutStyle? strut, TextHeightBehavior? behavior}) {
    return TextPainter(
      text: twoLines,
      textDirection: TextDirection.ltr,
      strutStyle: strut,
      textHeightBehavior: behavior,
    )..layout(maxWidth: 500);
  }

  test('trimmed behavior removes exactly the first/last line leading', () {
    final full = layout();
    final trimmed = layout(
      strut: readerStrutStyle(style),
      behavior: readerTextHeightBehavior,
    );
    expect(
      full.height - trimmed.height,
      moreOrLessEquals((lineHeight - 1) * fontSize, epsilon: 0.01),
    );
    full.dispose();
    trimmed.dispose();
  });

  test('line pitch between lines is unchanged by trimming', () {
    final full = layout();
    final trimmed = layout(
      strut: readerStrutStyle(style),
      behavior: readerTextHeightBehavior,
    );
    double pitch(TextPainter painter) {
      final metrics = painter.computeLineMetrics();
      expect(metrics, hasLength(2));
      return metrics[1].baseline - metrics[0].baseline;
    }

    expect(pitch(full), moreOrLessEquals(lineHeight * fontSize, epsilon: 0.01));
    expect(pitch(trimmed), moreOrLessEquals(pitch(full), epsilon: 0.01));
    full.dispose();
    trimmed.dispose();
  });

  test('readerStrutStyle does not re-add the trimmed leading', () {
    // StrutStyle.fromTextStyle carries the height multiplier, and struts
    // ignore TextHeightBehavior entirely — guard against regressing to it.
    final withLegacyStrut = layout(
      strut: StrutStyle.fromTextStyle(style),
      behavior: readerTextHeightBehavior,
    );
    final withReaderStrut = layout(
      strut: readerStrutStyle(style),
      behavior: readerTextHeightBehavior,
    );
    final noStrut = layout(behavior: readerTextHeightBehavior);

    expect(
      withReaderStrut.height,
      moreOrLessEquals(noStrut.height, epsilon: 0.01),
    );
    expect(withLegacyStrut.height, greaterThan(withReaderStrut.height));
    withLegacyStrut.dispose();
    withReaderStrut.dispose();
    noStrut.dispose();
  });

  test('paginator fits one extra line per page thanks to trimming', () {
    const text = 'line one\nline two\nline three\nline four';
    TextSpan buildSpan(int start, int end) =>
        TextSpan(text: text.substring(start, end), style: style);
    List<NativeTextPageRange> paginate(NativeTextFlowStyle flowStyle) {
      return NativeTextPaginator(
        maxWidth: 500,
        // Two full line boxes (72) minus a hair: without trimming only one
        // line fits, with trimming the first page gains the leading back.
        maxHeight: 2 * lineHeight * fontSize - 10,
        flowStyle: flowStyle,
      ).paginate(text: text, spanBuilder: buildSpan);
    }

    final untrimmed = paginate(
      const NativeTextFlowStyle(
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        locale: null,
        strutStyle: null,
        textHeightBehavior: null,
      ),
    );
    final trimmed = paginate(
      NativeTextFlowStyle(
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        locale: null,
        strutStyle: readerStrutStyle(style),
        textHeightBehavior: readerTextHeightBehavior,
      ),
    );

    expect(untrimmed.first.lineCount, 1);
    expect(trimmed.first.lineCount, 2);
  });

  test('reader flow fills both edges of wrapped Chinese lines', () {
    const width = 219.0;
    const bodyStyle = TextStyle(
      fontFamily: 'SourceHanSerifCN',
      fontSize: 20,
      letterSpacing: 0.2,
    );
    const flow = NativeTextFlowStyle(
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: Locale('zh', 'CN'),
      strutStyle: StrutStyle(fontFamily: 'SourceHanSerifCN', fontSize: 20),
      textHeightBehavior: readerTextHeightBehavior,
    );
    final painter = flow.createPainter(
      TextSpan(text: List.filled(20, '开元阅读正文排版').join(), style: bodyStyle),
    )..layout(maxWidth: width);
    final lines = painter.computeLineMetrics();

    expect(flow.textAlign, TextAlign.justify);
    expect(lines.length, greaterThan(1));
    for (final line in lines.take(lines.length - 1)) {
      expect(line.left.abs(), lessThanOrEqualTo(0.25));
      expect(line.width, closeTo(width, 0.25));
    }
    painter.dispose();
  });
}

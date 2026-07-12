import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/native_text_paginator.dart';

const _heightBehavior = TextHeightBehavior(
  applyHeightToFirstAscent: true,
  applyHeightToLastDescent: true,
  leadingDistribution: TextLeadingDistribution.proportional,
);

NativeTextFlowStyle _flowStyle(
  TextStyle style, {
  TextScaler scaler = TextScaler.noScaling,
}) {
  return NativeTextFlowStyle(
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    locale: const Locale('zh', 'CN'),
    strutStyle: StrutStyle.fromTextStyle(style),
    textHeightBehavior: _heightBehavior,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('large text pages preserve content and fit complete visual lines', () {
    const style = TextStyle(fontSize: 32, height: 1.75, letterSpacing: 0.2);
    final text = List.generate(
      18,
      (index) => '第$index段用于验证大字体分页不会把下一行的字头切在页面底部。'
          '排版必须根据真实行边界动态变化，而不是依赖固定像素。\n\n',
    ).join();
    const width = 326.0;
    const height = 612.0;
    final flow = _flowStyle(style);
    final paginator = NativeTextPaginator(
      maxWidth: width,
      maxHeight: height,
      flowStyle: flow,
    );

    final pages = paginator.paginate(
      text: text,
      spanBuilder: (start, end) => TextSpan(
        text: text.substring(start, end),
        style: style,
      ),
    );

    expect(pages, isNotEmpty);
    expect(
        pages.map((page) => text.substring(page.start, page.end)).join(), text);
    for (final page in pages) {
      final pageText = text.substring(page.start, page.end);
      final painter = flow.createPainter(TextSpan(text: pageText, style: style))
        ..layout(maxWidth: width);
      expect(painter.height, lessThanOrEqualTo(height));
      final metrics = painter.computeLineMetrics();
      expect(metrics.length, page.lineCount);
      final last = metrics.last;
      final position = painter.getPositionForOffset(
        Offset(last.left + last.width / 2, last.baseline - last.ascent / 2),
      );
      expect(painter.getLineBoundary(position).end, pageText.length);
      painter.dispose();
    }
  });

  test('pagination remains exact across sizes and nonlinear inputs', () {
    const text = '混合文字 English 12345 😀👨‍👩‍👧‍👦，用于验证缩放与窄屏。\n'
        '第二段继续包含标点、括号（内容）以及很长的一串文本。';
    for (final fontSize in <double>[18, 24, 32]) {
      for (final width in <double>[210, 320, 480]) {
        for (final scale in <double>[1, 1.25, 1.6]) {
          final style = TextStyle(fontSize: fontSize, height: 1.75);
          final flow = _flowStyle(style, scaler: TextScaler.linear(scale));
          final pages = NativeTextPaginator(
            maxWidth: width,
            maxHeight: 360,
            flowStyle: flow,
          ).paginate(
            text: text,
            spanBuilder: (start, end) => TextSpan(
              text: text.substring(start, end),
              style: style,
            ),
          );
          expect(
            pages.map((page) => text.substring(page.start, page.end)).join(),
            text,
          );
          for (final page in pages) {
            expect(page.start, lessThan(page.end));
            if (page.end < text.length) {
              expect(text.codeUnitAt(page.end),
                  isNot(inInclusiveRange(0xDC00, 0xDFFF)));
            }
          }
        }
      }
    }
  });

  test('rich text uses the same line layout as the final page slice', () {
    const base = TextStyle(fontSize: 25, height: 1.75);
    const text = '普通正文第一段。\n\n大标题会使用更大的字号，然后继续普通正文，'
        '用于验证 EPUB 富文本分页。后续内容继续填充页面，不能丢字也不能重字。';
    final headingStart = text.indexOf('大标题');
    final headingEnd = headingStart + '大标题会使用更大的字号'.length;
    TextSpan buildSpan(int start, int end) {
      final children = <InlineSpan>[];
      var cursor = start;
      if (start < headingEnd && end > headingStart) {
        final overlapStart = headingStart.clamp(start, end);
        final overlapEnd = headingEnd.clamp(start, end);
        if (cursor < overlapStart) {
          children.add(TextSpan(text: text.substring(cursor, overlapStart)));
        }
        children.add(TextSpan(
          text: text.substring(overlapStart, overlapEnd),
          style: base.copyWith(fontSize: 40, fontWeight: FontWeight.bold),
        ));
        cursor = overlapEnd;
      }
      if (cursor < end) {
        children.add(TextSpan(text: text.substring(cursor, end)));
      }
      return TextSpan(style: base, children: children);
    }

    const width = 280.0;
    const height = 310.0;
    final flow = _flowStyle(base);
    final pages = NativeTextPaginator(
      maxWidth: width,
      maxHeight: height,
      flowStyle: flow,
    ).paginate(text: text, spanBuilder: buildSpan);

    expect(
        pages.map((page) => text.substring(page.start, page.end)).join(), text);
    for (final page in pages) {
      final painter = flow.createPainter(buildSpan(page.start, page.end))
        ..layout(maxWidth: width);
      expect(painter.height, lessThanOrEqualTo(height));
      painter.dispose();
    }
  });

  testWidgets('measured page and RenderParagraph share identical constraints',
      (tester) async {
    const style = TextStyle(fontSize: 32, height: 1.75, letterSpacing: 0.2);
    const text = '这是最终页面实际渲染校验。每一页都只能包含完整的视觉行，'
        '最后一行不能只露出字形顶部。继续填充足够多的内容以产生多个页面。';
    const width = 300.0;
    const height = 330.0;
    final flow = _flowStyle(style, scaler: const TextScaler.linear(1.2));
    final pages = NativeTextPaginator(
      maxWidth: width,
      maxHeight: height,
      flowStyle: flow,
    ).paginate(
      text: text,
      spanBuilder: (start, end) => TextSpan(
        text: text.substring(start, end),
        style: style,
      ),
    );
    final first = pages.first;
    final pageText = text.substring(first.start, first.end);
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: RichText(
              key: key,
              text: TextSpan(text: pageText, style: style),
              textAlign: flow.textAlign,
              textDirection: flow.textDirection,
              textScaler: flow.textScaler,
              locale: flow.locale,
              strutStyle: flow.strutStyle,
              textWidthBasis: flow.textWidthBasis,
              textHeightBehavior: flow.textHeightBehavior,
            ),
          ),
        ),
      ),
    );

    final paragraph =
        key.currentContext!.findRenderObject()! as RenderParagraph;
    final painter = flow.createPainter(TextSpan(text: pageText, style: style))
      ..layout(maxWidth: width);
    expect(painter.height, lessThanOrEqualTo(paragraph.size.height));
    final finalGlyphBoxes = paragraph.getBoxesForSelection(
      TextSelection(
          baseOffset: pageText.length - 1, extentOffset: pageText.length),
    );
    expect(finalGlyphBoxes, isNotEmpty);
    expect(
        finalGlyphBoxes.last.bottom, lessThanOrEqualTo(paragraph.size.height));
    expect(tester.takeException(), isNull);
    painter.dispose();
  });
}

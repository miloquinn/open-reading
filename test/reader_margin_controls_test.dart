import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/widgets/reader_settings_controls.dart';

void main() {
  testWidgets('top and bottom margins expose independent controls',
      (tester) async {
    double? changedTop;
    double? changedBottom;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderMarginControls(
            topLabel: '上页边距',
            bottomLabel: '下页边距',
            topMargin: 4,
            bottomMargin: 0,
            onTopChanged: (value) => changedTop = value,
            onBottomChanged: (value) => changedBottom = value,
          ),
        ),
      ),
    );

    expect(find.text('上页边距'), findsOneWidget);
    expect(find.text('下页边距'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    final topSlider = find.descendant(
      of: find.byKey(const ValueKey('reader-top-margin-slider')),
      matching: find.byType(Slider),
    );
    await tester.drag(topSlider, const Offset(80, 0));
    await tester.pump();

    expect(changedTop, isNotNull);
    expect(changedBottom, isNull);
  });
}

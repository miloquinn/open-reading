import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_opening_loader.dart';

void main() {
  Widget buildLoader({bool reduceMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Scaffold(
          body: ReaderOpeningLoader(palette: ReaderThemes.day),
        ),
      ),
    );
  }

  double dotScale(WidgetTester tester, int index) => tester
      .widget<Transform>(find.byKey(ValueKey('reader-opening-dot-$index')))
      .transform
      .getMaxScaleOnAxis();

  testWidgets('three dots pulse in sequence without resizing their frame', (
    tester,
  ) async {
    await tester.pumpWidget(buildLoader());

    final dots = find.byKey(const ValueKey('reader-opening-dots'));
    expect(tester.getSize(dots), const Size(54, 24));
    final firstFrame = List<double>.generate(
      3,
      (index) => dotScale(tester, index),
    );

    await tester.pump(const Duration(milliseconds: 240));
    expect(tester.getSize(dots), const Size(54, 24));
    final nextFrame = List<double>.generate(
      3,
      (index) => dotScale(tester, index),
    );

    expect(nextFrame, isNot(firstFrame));
    expect(
      nextFrame.indexOf(nextFrame.reduce((a, b) => a > b ? a : b)),
      isNot(firstFrame.indexOf(firstFrame.reduce((a, b) => a > b ? a : b))),
    );
  });

  testWidgets('reduce motion keeps all three dots still', (tester) async {
    await tester.pumpWidget(buildLoader(reduceMotion: true));

    final firstFrame = List<double>.generate(
      3,
      (index) => dotScale(tester, index),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final nextFrame = List<double>.generate(
      3,
      (index) => dotScale(tester, index),
    );

    expect(nextFrame, firstFrame);
    expect(nextFrame.toSet(), hasLength(1));
  });
}

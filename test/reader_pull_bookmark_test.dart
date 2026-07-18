import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_pull_bookmark.dart';

void main() {
  testWidgets('top-edge pull triggers only after crossing the threshold',
      (tester) async {
    var triggered = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPullBookmark(
          enabled: true,
          bookmarked: false,
          busy: false,
          palette: ReaderThemes.day,
          addHint: 'Pull to add',
          removeHint: 'Pull to remove',
          releaseHint: 'Release',
          onTriggered: () => triggered++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final shortPull = await tester.startGesture(const Offset(100, 20));
    await shortPull.moveBy(const Offset(0, 40));
    await shortPull.up();
    expect(triggered, 0);

    final fullPull = await tester.startGesture(const Offset(100, 20));
    await fullPull.moveBy(const Offset(0, 90));
    await tester.pump();
    expect(find.text('Release'), findsOneWidget);
    await fullPull.up();
    expect(triggered, 1);

    final middlePull = await tester.startGesture(const Offset(100, 220));
    await middlePull.moveBy(const Offset(0, 100));
    await middlePull.up();
    expect(triggered, 1);
  });
}

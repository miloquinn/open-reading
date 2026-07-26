import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/widgets/reader_tap_observer.dart';

void main() {
  testWidgets('reader tap observer emits one short stationary tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderTapObserver(
          onTap: (_) => taps++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    await tester.tapAt(const Offset(100, 100));

    expect(taps, 1);
  });

  testWidgets('reader tap observer tolerates normal finger jitter', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderTapObserver(
          onTap: (_) => taps++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(100, 100));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.up();
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('reader tap observer leaves drags and long presses alone', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderTapObserver(
          onTap: (_) => taps++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    await tester.dragFrom(const Offset(100, 100), const Offset(30, 0));
    final longPress = await tester.startGesture(const Offset(100, 100));
    await tester.pump(const Duration(milliseconds: 500));
    await longPress.up();

    expect(taps, 0);
  });
}

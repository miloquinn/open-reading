import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/pages/reader/native_reader_page.dart';

void main() {
  testWidgets('large-reader work stays blocked until the entrance completes', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 460),
    );
    addTearDown(controller.dispose);
    var settled = false;

    final settleFuture = waitForReaderOpeningRouteToSettle(
      routeAnimation: controller,
      routeEntranceCompleted: false,
      isMounted: () => true,
    ).then((value) => settled = value);
    await tester.pump();
    expect(controller.status, AnimationStatus.dismissed);
    expect(settled, isFalse);

    controller.forward();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 459));
    expect(settled, isFalse);

    await tester.pump(const Duration(milliseconds: 10));
    expect(controller.status, AnimationStatus.completed);
    expect(await settleFuture, isTrue);
    expect(settled, isTrue);
  });

  testWidgets(
    'stale completed flag does not cancel an active entrance animation',
    (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 460),
      );
      addTearDown(controller.dispose);

      controller.forward();
      await tester.pump();
      final settleFuture = waitForReaderOpeningRouteToSettle(
        routeAnimation: controller,
        routeEntranceCompleted: true,
        isMounted: () => true,
      );

      await tester.pump(const Duration(milliseconds: 459));
      expect(controller.status, AnimationStatus.forward);

      await tester.pump(const Duration(milliseconds: 10));
      expect(controller.status, AnimationStatus.completed);
      expect(await settleFuture, isTrue);
    },
  );

  testWidgets('large-reader work is cancelled when the route is dismissed', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 460),
    );
    addTearDown(controller.dispose);
    bool? settled;

    controller.forward();
    await tester.pump();
    waitForReaderOpeningRouteToSettle(
      routeAnimation: controller,
      routeEntranceCompleted: false,
      isMounted: () => true,
    ).then((value) => settled = value);
    await tester.pump(const Duration(milliseconds: 100));
    controller.reverse();
    await tester.pumpAndSettle();

    expect(settled, isFalse);
  });
}

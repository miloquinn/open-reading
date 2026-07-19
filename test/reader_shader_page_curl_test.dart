import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_page_turn_geometry.dart';
import 'package:xxread/widgets/reader_shader_page_curl.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';

void main() {
  testWidgets('programmatic forward turn reports the reader page change',
      (tester) async {
    final controller = ReaderPageCurlController();
    var forwardTurns = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            controller: controller,
            currentPage: _snapshot('current'),
            forwardPage: _snapshot('next'),
            onTurnForward: () => forwardTurns++,
            onTurnBackward: () {},
            paperColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final turn = controller.turnForward();
    await tester.pumpAndSettle();
    await turn;

    expect(forwardTurns, 1);
  });

  testWidgets('programmatic backward uses the independent incoming channel',
      (tester) async {
    final controller = ReaderPageCurlController();
    var backwardTurns = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            controller: controller,
            currentPage: _snapshot('current'),
            backwardPage: _snapshot('previous'),
            onTurnForward: () {},
            onTurnBackward: () => backwardTurns++,
            paperColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final turn = controller.turnBackward();
    await tester.pump();
    expect(controller.debugMotion, ReaderPageTurnMotion.incoming);
    expect(controller.debugActiveSourceIsCurrent, isFalse);
    await tester.pumpAndSettle();
    await turn;

    expect(backwardTurns, 1);
  });

  testWidgets('rapid programmatic turns are queued instead of dropped',
      (tester) async {
    final controller = ReaderPageCurlController();
    final pages = List.generate(4, (index) => _snapshot('page-$index'));
    var pageIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setHostState) => SizedBox(
            width: 400,
            height: 700,
            child: ReaderShaderPageCurl(
              controller: controller,
              currentPage: pages[pageIndex],
              backwardPage: pageIndex > 0 ? pages[pageIndex - 1] : null,
              forwardPage:
                  pageIndex + 1 < pages.length ? pages[pageIndex + 1] : null,
              onTurnForward: () => setHostState(() => pageIndex++),
              onTurnBackward: () => setHostState(() => pageIndex--),
              paperColor: Colors.white,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final first = controller.turnForward();
    final second = controller.turnForward();
    await tester.pumpAndSettle();
    await Future.wait([first, second]);

    expect(pageIndex, 2);
    expect(find.text('page-2'), findsOneWidget);
  });

  testWidgets('renders opaque current and adjacent pages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            currentPage: _snapshot('current'),
            backwardPage: _snapshot('previous'),
            forwardPage: _snapshot('next'),
            onTurnForward: () {},
            onTurnBackward: () {},
            paperColor: Colors.amber,
          ),
        ),
      ),
    );

    expect(find.text('current'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == Colors.amber,
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('phone leaf keeps the physical binding on the left',
      (tester) async {
    late ReaderShaderPageCurl curl;
    await tester.pumpWidget(
      MaterialApp(
        home: curl = ReaderShaderPageCurl(
          currentPage: _snapshot('current'),
          backwardPage: _snapshot('previous'),
          onTurnForward: () {},
          onTurnBackward: () {},
          paperColor: Colors.white,
        ),
      ),
    );

    expect(curl.bindingEdge, ReaderPageBindingEdge.left);
  });

  testWidgets('forward curl can start from the middle of the page',
      (tester) async {
    var forwardTurns = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            currentPage: _snapshot('current'),
            forwardPage: _snapshot('next'),
            onTurnForward: () => forwardTurns++,
            onTurnBackward: () {},
            paperColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(ReaderShaderPageCurl));
    await tester.dragFrom(
      Offset(rect.left + rect.width * 0.5, rect.center.dy),
      Offset(-rect.width * 0.4, 0),
    );
    await tester.pumpAndSettle();

    expect(forwardTurns, 1);
  });

  testWidgets('middle forward drag catches up from the right edge',
      (tester) async {
    final controller = ReaderPageCurlController();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            controller: controller,
            currentPage: _snapshot('current'),
            forwardPage: _snapshot('next'),
            onTurnForward: () {},
            onTurnBackward: () {},
            paperColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(ReaderShaderPageCurl));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveBy(const Offset(-60, -45));
    await tester.pump();

    expect(controller.debugIsCatchingUp, isTrue);
    expect(
      controller.debugTouchPosition!.dx,
      closeTo(rect.width, 0.001),
    );
    expect(
      controller.debugTouchPosition!.dy,
      closeTo(rect.height / 2, 0.001),
    );
    expect(controller.debugFoldStart!.dx, closeTo(rect.width, 0.001));
    expect(controller.debugFoldEnd!.dx, closeTo(rect.width, 0.001));

    await tester.pump(const Duration(milliseconds: 40));
    final middle = controller.debugTouchPosition!.dx;
    expect(middle, greaterThan(rect.width * 0.72));
    expect(middle, lessThan(rect.width - 0.5));
    expect(
      controller.debugTouchPosition!.dy,
      closeTo(rect.height / 2, 0.001),
    );

    await gesture.moveBy(const Offset(-35, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.debugIsCatchingUp, isTrue);
    expect(
      controller.debugTouchPosition!.dx,
      greaterThan(rect.width / 2 - 95),
    );

    await tester.pump(const Duration(milliseconds: 40));
    expect(controller.debugIsCatchingUp, isFalse);
    expect(
      controller.debugTouchPosition!.dx,
      closeTo(rect.width / 2 - 95, 1),
    );
    expect(
      controller.debugTouchPosition!.dy,
      closeTo(rect.height / 2 - 45, 1),
    );

    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'middle backward drag drives an incoming crease from displacement',
      (tester) async {
    final controller = ReaderPageCurlController();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            controller: controller,
            currentPage: _snapshot('current'),
            backwardPage: _snapshot('previous'),
            onTurnForward: () {},
            onTurnBackward: () {},
            paperColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(ReaderShaderPageCurl));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();

    expect(controller.debugIsCatchingUp, isFalse);
    expect(controller.debugMotion, ReaderPageTurnMotion.incoming);
    expect(controller.debugActiveSourceIsCurrent, isFalse);
    expect(controller.debugAnimationReady, isTrue);
    expect(
      controller.debugTouchPosition!.dx,
      closeTo(30, 1),
    );

    await gesture.moveBy(const Offset(-18, 45));
    await tester.pump();
    expect(
      (controller.debugTouchPosition! - Offset(12, rect.height / 2 + 45))
          .distance,
      lessThan(1),
    );

    await gesture.moveBy(const Offset(55, -90));
    await tester.pump();
    expect(
      (controller.debugTouchPosition! - Offset(67, rect.height / 2 - 45))
          .distance,
      lessThan(1),
    );

    await gesture.moveBy(const Offset(-22, 60));
    await tester.pump();
    expect(
      (controller.debugTouchPosition! - Offset(45, rect.height / 2 + 15))
          .distance,
      lessThan(1),
    );

    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('cold backward capture paints before async preparation finishes',
      (tester) async {
    final controller = ReaderPageCurlController();
    final preparation = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            controller: controller,
            currentPage: _snapshot('current'),
            backwardPage: _snapshot('previous'),
            preparePages: () => preparation.future,
            onTurnForward: () {},
            onTurnBackward: () {},
            paperColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(ReaderShaderPageCurl));
    final gesture = await tester.startGesture(
      Offset(rect.left + 2, rect.center.dy),
    );
    await gesture.moveBy(const Offset(80, -45));
    await tester.pump();

    expect(controller.debugAnimationReady, isTrue);
    expect(controller.debugUsesProvisionalSnapshot, isTrue);
    expect(controller.debugFoldStart, isNotNull);
    expect(controller.debugFoldEnd, isNotNull);

    preparation.complete();
    for (var frame = 0;
        frame < 20 && controller.debugUsesProvisionalSnapshot;
        frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.debugUsesProvisionalSnapshot, isFalse);

    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'visible forward source stays stable while adjacent preparation finishes',
      (tester) async {
    final controller = ReaderPageCurlController();
    final preparation = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            controller: controller,
            currentPage: _snapshot('current'),
            forwardPage: _snapshot('next'),
            preparePages: () => preparation.future,
            onTurnForward: () {},
            onTurnBackward: () {},
            paperColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(ReaderShaderPageCurl));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();

    expect(controller.debugAnimationReady, isTrue);
    expect(controller.debugUsesProvisionalSnapshot, isFalse);

    preparation.complete();
    await tester.pump(const Duration(milliseconds: 160));
    expect(controller.debugUsesProvisionalSnapshot, isFalse);

    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('active turn keeps stable repaint keys across status revisions',
      (tester) async {
    final controller = ReaderPageCurlController();
    late StateSetter updateHost;
    var revision = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setHostState) {
            updateHost = setHostState;
            return SizedBox(
              width: 400,
              height: 700,
              child: ReaderShaderPageCurl(
                controller: controller,
                currentPage: _revisionSnapshot('current', revision),
                backwardPage: _revisionSnapshot('previous', revision),
                onTurnForward: () {},
                onTurnBackward: () {},
                paperColor: Colors.white,
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(ReaderShaderPageCurl));
    final gesture = await tester.startGesture(
      Offset(rect.left + 2, rect.center.dy),
    );
    await gesture.moveBy(const Offset(90, -45));
    await tester.pump();
    expect(controller.debugAnimationReady, isTrue);

    updateHost(() => revision++);
    await tester.pump();
    expect(controller.debugMotion, ReaderPageTurnMotion.incoming);
    expect(controller.debugAnimationReady, isTrue);

    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('classic fold accepts a horizontal drag below page center',
      (tester) async {
    var forwardTurns = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            currentPage: _snapshot('current'),
            forwardPage: _snapshot('next'),
            onTurnForward: () => forwardTurns++,
            onTurnBackward: () {},
            paperColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(ReaderShaderPageCurl));
    await tester.dragFrom(
      Offset(rect.right - 2, rect.top + rect.height * 0.68),
      Offset(-rect.width * 0.42, 0),
    );
    await tester.pumpAndSettle();

    expect(forwardTurns, 1);
  });

  testWidgets('classic fold turns backward with the phone binding on the left',
      (tester) async {
    var backwardTurns = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            currentPage: _snapshot('current'),
            backwardPage: _snapshot('previous'),
            onTurnForward: () {},
            onTurnBackward: () => backwardTurns++,
            paperColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final curl = tester.widget<ReaderShaderPageCurl>(
      find.byType(ReaderShaderPageCurl),
    );
    expect(curl.bindingEdge, ReaderPageBindingEdge.left);

    final rect = tester.getRect(find.byType(ReaderShaderPageCurl));
    await tester.dragFrom(
      Offset(rect.left + 2, rect.top + rect.height * 0.68),
      Offset(rect.width * 0.42, 0),
    );
    await tester.pumpAndSettle();

    expect(backwardTurns, 1);
  });

  testWidgets('edge-only forward turn cannot start from its binding edge',
      (tester) async {
    var forwardTurns = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            edgeDragOnly: true,
            currentPage: _snapshot('current'),
            forwardPage: _snapshot('next'),
            onTurnForward: () => forwardTurns++,
            onTurnBackward: () {},
            paperColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(ReaderShaderPageCurl));
    await tester.dragFrom(
      Offset(rect.left + 2, rect.center.dy),
      Offset(-rect.width * 0.5, 0),
    );
    await tester.pumpAndSettle();

    expect(forwardTurns, 0);
  });

  testWidgets(
      'tablet left leaf turns from the outer edge, not the center spine',
      (tester) async {
    var backwardTurns = 0;
    final controller = ReaderPageCurlController();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            controller: controller,
            edgeDragOnly: true,
            bindingEdge: ReaderPageBindingEdge.right,
            currentPage: _snapshot('current'),
            backwardPage: _snapshot('previous'),
            onTurnForward: () {},
            onTurnBackward: () => backwardTurns++,
            paperColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(ReaderShaderPageCurl));
    await tester.dragFrom(
      Offset(rect.right - 2, rect.center.dy),
      Offset(rect.width * 0.5, 0),
    );
    await tester.pumpAndSettle();
    expect(backwardTurns, 0);

    await tester.dragFrom(
      Offset(rect.left + 2, rect.center.dy),
      Offset(rect.width * 0.2, 0),
    );
    expect(controller.debugMotion, ReaderPageTurnMotion.outgoing);
    expect(controller.debugActiveSourceIsCurrent, isTrue);
    await tester.pumpAndSettle();
    expect(backwardTurns, 0);

    await tester.dragFrom(
      Offset(rect.left + 2, rect.center.dy),
      Offset(rect.width * 0.5, 0),
    );
    await tester.pumpAndSettle();
    expect(backwardTurns, 1);
  });

  testWidgets('committed diagonal turn snaps to the exact shader endpoint',
      (tester) async {
    final controller = ReaderPageCurlController();
    final callbackGate = Completer<void>();
    var callbackStarted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            controller: controller,
            currentPage: _snapshot('current'),
            forwardPage: _snapshot('next'),
            onTurnForward: () {
              callbackStarted = true;
              return callbackGate.future;
            },
            onTurnBackward: () {},
            paperColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(ReaderShaderPageCurl));
    final gesture = await tester.startGesture(
      Offset(rect.right - 2, rect.top + rect.height * 0.72),
    );
    await gesture.moveBy(Offset(-rect.width * 0.72, -160));
    await gesture.up();
    for (var frame = 0; frame < 30 && !callbackStarted; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(callbackStarted, isTrue);
    expect(controller.debugShaderLineA, Offset.zero);
    expect(controller.debugShaderLineB, Offset(0, rect.height));

    callbackGate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('tablet spread coordinator serializes opposite leaf turns',
      (tester) async {
    final coordinator = ReaderPageCurlCoordinator();
    final forwardController = ReaderPageCurlController();
    final backwardController = ReaderPageCurlController();
    final forwardGate = Completer<void>();
    var forwardCallbacks = 0;
    var backwardCallbacks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            SizedBox(
              width: 400,
              height: 700,
              child: ReaderShaderPageCurl(
                coordinator: coordinator,
                controller: backwardController,
                bindingEdge: ReaderPageBindingEdge.right,
                currentPage: _snapshot('left-current'),
                backwardPage: _snapshot('left-previous'),
                onTurnForward: () {},
                onTurnBackward: () => backwardCallbacks++,
                paperColor: Colors.white,
              ),
            ),
            SizedBox(
              width: 400,
              height: 700,
              child: ReaderShaderPageCurl(
                coordinator: coordinator,
                controller: forwardController,
                currentPage: _snapshot('right-current'),
                forwardPage: _snapshot('right-next'),
                onTurnForward: () {
                  forwardCallbacks++;
                  return forwardGate.future;
                },
                onTurnBackward: () {},
                paperColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final forwardTurn = forwardController.turnForward();
    final backwardTurn = backwardController.turnBackward();
    for (var frame = 0; frame < 30 && forwardCallbacks == 0; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(forwardCallbacks, 1);
    expect(backwardCallbacks, 0);
    expect(backwardController.debugMotion, isNull);
    expect(coordinator.debugIsBusy, isTrue);

    forwardGate.complete();
    for (var frame = 0; frame < 40 && backwardCallbacks == 0; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await Future.wait([forwardTurn, backwardTurn]);

    expect(backwardCallbacks, 1);
    expect(coordinator.debugIsBusy, isFalse);
  });

  test('snapshot ratio stays inside quality and byte ceilings', () {
    expect(
      readerPageSnapshotPixelRatio(
        logicalSize: const Size(400, 800),
        devicePixelRatio: 3,
      ),
      lessThanOrEqualTo(2.5),
    );
    expect(
      readerPageSnapshotPixelRatio(
        logicalSize: const Size(1200, 1600),
        devicePixelRatio: 3,
      ),
      lessThan(1.2),
    );
    const budget = 8 * 1024 * 1024;
    const largeViewport = Size(7680, 4320);
    final downsampledRatio = readerPageSnapshotPixelRatio(
      logicalSize: largeViewport,
      devicePixelRatio: 3,
      perEntryByteBudget: budget,
    );
    expect(downsampledRatio, lessThan(1));
    expect(
      largeViewport.width *
          largeViewport.height *
          downsampledRatio *
          downsampledRatio *
          4,
      lessThanOrEqualTo(budget),
    );
  });
}

ReaderPageSnapshot _snapshot(String id) => ReaderPageSnapshot(
      key: ReaderPageSnapshotKey(
        pageIdentity: id,
        layoutFingerprint: 'layout',
        themeId: 'day',
      ),
      contentRevision: 0,
      child: Text(id),
    );

ReaderPageSnapshot _revisionSnapshot(String id, int revision) =>
    ReaderPageSnapshot(
      key: ReaderPageSnapshotKey(
        pageIdentity: id,
        layoutFingerprint: 'layout',
        themeId: 'day',
      ),
      contentRevision: revision,
      child: Text('$id-$revision'),
    );

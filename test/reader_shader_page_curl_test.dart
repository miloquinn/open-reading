import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_layout.dart';
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

  testWidgets('classic fold accepts a horizontal drag below page center',
      (tester) async {
    var forwardTurns = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            turnStyle: ReaderPageTurnStyle.classicFold,
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

  testWidgets('edge-only backward turn uses the outer edge, not the spine',
      (tester) async {
    var backwardTurns = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: ReaderShaderPageCurl(
            edgeDragOnly: true,
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
      Offset(rect.width * 0.5, 0),
    );
    await tester.pumpAndSettle();
    expect(backwardTurns, 1);
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

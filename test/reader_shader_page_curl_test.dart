import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/widgets/reader_shader_page_curl.dart';

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
            currentPage: const Text('current'),
            forwardPage: const Text('next'),
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
            currentPage: const Text('current'),
            backwardPage: const Text('previous'),
            forwardPage: const Text('next'),
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
            currentPage: const Text('current'),
            forwardPage: const Text('next'),
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
}

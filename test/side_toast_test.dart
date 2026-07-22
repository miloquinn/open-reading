import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/widgets/side_toast.dart';

void main() {
  testWidgets('side toast appears and dismisses automatically', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const Scaffold();
          },
        ),
      ),
    );

    showSideToast(
      context,
      'Saved',
      kind: SideToastKind.success,
      duration: const Duration(milliseconds: 500),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('Saved'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('new side toast replaces the previous message', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const Scaffold();
          },
        ),
      ),
    );

    showSideToast(
      context,
      'First',
      duration: const Duration(seconds: 5),
    );
    await tester.pump();
    showSideToast(
      context,
      'Second',
      duration: const Duration(milliseconds: 100),
    );
    await tester.pump();

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  });

  testWidgets('side toast does not block the interface underneath',
      (tester) async {
    late BuildContext context;
    var taps = 0;
    const buttonKey = Key('underlying-button');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: FilledButton(
                  key: buttonKey,
                  onPressed: () => taps += 1,
                  child: const Text('Continue'),
                ),
              ),
            );
          },
        ),
      ),
    );

    showSideToast(
      context,
      'Background task started',
      duration: const Duration(milliseconds: 100),
    );
    await tester.pump();
    await tester.tap(find.byKey(buttonKey));

    expect(taps, 1);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  });
}

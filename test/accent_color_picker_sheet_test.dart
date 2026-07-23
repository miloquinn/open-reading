import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/widgets/accent_color_picker_sheet.dart';

void main() {
  testWidgets('custom hex color is returned from the accent picker', (
    tester,
  ) async {
    Color? selectedColor;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selectedColor = await showModalBottomSheet<Color>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const AccentColorPickerSheet(
                    initialColor: Color(0xFF1976D2),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('accent-color-hex-field'));
    expect(field, findsOneWidget);
    expect(find.byKey(const ValueKey('accent-color-spectrum')), findsOneWidget);
    expect(find.byKey(const ValueKey('accent-color-hue')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('accent-color-scroll-view')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('accent-color-footer')), findsOneWidget);

    final confirmBeforeScroll = tester.getTopLeft(
      find.byKey(const ValueKey('accent-color-confirm')),
    );
    await tester.drag(
      find.byKey(const ValueKey('accent-color-scroll-view')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('accent-color-confirm'))),
      confirmBeforeScroll,
    );

    await tester.enterText(field, '#123456');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('accent-color-confirm')),
    );
    await tester.tap(find.byKey(const ValueKey('accent-color-confirm')));
    await tester.pumpAndSettle();

    expect(selectedColor, const Color(0xFF123456));
  });

  testWidgets('drag handle dismisses the accent picker sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showModalBottomSheet<Color>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                enableDrag: true,
                showDragHandle: false,
                builder: (_) => const AccentColorPickerSheet(
                  initialColor: Color(0xFF1976D2),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final sheetTop = tester.getTopLeft(find.byType(AccentColorPickerSheet)).dy;
    final handleTop = tester
        .getTopLeft(find.byKey(const ValueKey('accent-color-drag-handle')))
        .dy;
    expect(handleTop - sheetTop, greaterThanOrEqualTo(18));

    await tester.drag(
      find.byKey(const ValueKey('accent-color-drag-area')),
      const Offset(0, 420),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AccentColorPickerSheet), findsNothing);
  });

  testWidgets('invalid hex input shows validation feedback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AccentColorPickerSheet(initialColor: Color(0xFF1976D2)),
        ),
      ),
    );

    final field = find.byKey(const ValueKey('accent-color-hex-field'));
    await tester.enterText(field, '#12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.textContaining('#F6F0E4'), findsOneWidget);
  });
}

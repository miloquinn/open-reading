import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/utils/glass_config.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_control_chrome.dart';

void main() {
  tearDown(() {
    GlassEffectConfig.setDisableAllGlassEffects(false);
  });

  testWidgets('reader chrome follows the global glass effect switch',
      (tester) async {
    GlassEffectConfig.setDisableAllGlassEffects(false);
    await tester.pumpWidget(_testApp(glassEnabled: true));

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(_panelGradient(tester).colors.every((color) => color.a < 1), isTrue);
    expect(_iconBackground(tester).a, lessThan(1));

    GlassEffectConfig.setDisableAllGlassEffects(true);
    await tester.pumpWidget(_testApp(glassEnabled: false));

    expect(find.byType(BackdropFilter), findsNothing);
    expect(
        _panelGradient(tester).colors.every((color) => color.a == 1), isTrue);
    expect(_iconBackground(tester).a, 1);
  });
}

Widget _testApp({required bool glassEnabled}) {
  const palette = ReaderThemes.day;
  return MaterialApp(
    theme: palette.toThemeData(),
    home: Scaffold(
      body: Center(
        child: ReaderControlBar(
          key: ValueKey(glassEnabled),
          palette: palette,
          isTopBar: true,
          child: const SizedBox(
            width: 240,
            height: 58,
            child: ReaderControlIconButton(
              palette: palette,
              onPressed: null,
              tooltip: 'Bookmark',
              icon: Icons.bookmark_border_rounded,
            ),
          ),
        ),
      ),
    ),
  );
}

LinearGradient _panelGradient(WidgetTester tester) {
  return tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((widget) => widget.decoration)
      .whereType<BoxDecoration>()
      .map((decoration) => decoration.gradient)
      .whereType<LinearGradient>()
      .single;
}

Color _iconBackground(WidgetTester tester) {
  final button = tester.widget<IconButton>(find.byType(IconButton));
  return button.style!.backgroundColor!.resolve(const <WidgetState>{})!;
}

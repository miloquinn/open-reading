import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_leaf_status.dart';
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

  testWidgets('reader-owned top information shows time title and battery',
      (tester) async {
    final status = ReaderLeafStatusData(
      time: DateTime(2026, 7, 18, 9, 5),
      battery: const ReaderBatteryStatus(level: 73, charging: false),
      revision: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: Scaffold(
            body: ReaderChromeOverlay(
              palette: ReaderThemes.day,
              visible: false,
              title: 'Chapter 4',
              statusBottom: 8,
              statusBuilder: (context, style, key) => Text(
                '4 / 12',
                key: key,
                style: style,
              ),
              onBack: () {},
              onBookmark: () {},
              onTableOfContents: () {},
              onSettings: () {},
              backTooltip: 'Back',
              bookmarkTooltip: 'Bookmark',
              tableOfContentsTooltip: 'Contents',
              settingsTooltip: 'Settings',
              bookmarked: false,
              showViewportStatus: false,
              showViewportTitle: true,
              viewportTitleTop: 24,
              viewportTitleKey: const ValueKey('reader-top-information'),
              readerStatus: status,
            ),
          ),
        ),
      ),
    );

    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('Chapter 4'), findsNWidgets(2));
    expect(find.text('73%'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('reader-top-information')),
          )
          .opacity,
      1,
    );
  });

  testWidgets('reader chrome preserves the selected reading theme color',
      (tester) async {
    await tester.pumpWidget(
      _testApp(
        glassEnabled: true,
        palette: ReaderThemes.green,
      ),
    );

    final greenSurface = _panelGradient(tester).colors.last;
    final expectedGreen = Color.lerp(
      ReaderThemes.green.controlBar,
      Colors.white,
      0.28,
    )!;
    expect(greenSurface.r, closeTo(expectedGreen.r, 0.001));
    expect(greenSurface.g, closeTo(expectedGreen.g, 0.001));
    expect(greenSurface.b, closeTo(expectedGreen.b, 0.001));

    await tester.pumpWidget(
      _testApp(
        glassEnabled: true,
        palette: ReaderThemes.rose,
      ),
    );

    final roseSurface = _panelGradient(tester).colors.last;
    expect(roseSurface.r, greaterThan(greenSurface.r));
    expect(roseSurface.g, lessThan(greenSurface.g));
  });
}

Widget _testApp({
  required bool glassEnabled,
  ReaderThemePalette palette = ReaderThemes.day,
}) {
  return MaterialApp(
    theme: palette.toThemeData(),
    home: Scaffold(
      body: Center(
        child: ReaderControlBar(
          key: ValueKey(glassEnabled),
          palette: palette,
          isTopBar: true,
          child: SizedBox(
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

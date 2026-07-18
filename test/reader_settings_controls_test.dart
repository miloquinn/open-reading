import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_system_ui.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_settings_controls.dart';

void main() {
  testWidgets('typography sliders expose discrete values and rounded callbacks',
      (tester) async {
    int? changedIndent;
    int? changedSpacing;
    bool? pullBookmark;
    bool? tapAnimation;

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderSettingsSheet(
          title: 'Reading settings',
          themeTitle: 'Theme',
          themeDescription: 'Choose a theme',
          pageModeTitle: 'Page mode',
          pageModeSummary: 'Page curl',
          topBarStyleTitle: 'Top information',
          topBarStyleSummary: 'Reader information bar',
          pullBookmarkTitle: 'Pull bookmark',
          pullBookmarkHint: 'Pull down from the top',
          tapPageAnimationTitle: 'Tap animation',
          tapPageAnimationHint: 'Animate side taps',
          fontSizeLabel: 'Font size',
          lineHeightLabel: 'Line height',
          firstLineIndentLabel: 'First-line indent',
          paragraphSpacingLabel: 'Paragraph spacing',
          horizontalMarginLabel: 'Horizontal margin',
          topMarginLabel: 'Top margin',
          bottomMarginLabel: 'Bottom margin',
          themeId: ReaderThemes.day.id,
          fontSize: 19,
          lineHeight: 1.7,
          firstLineIndent: 2,
          paragraphSpacing: 1,
          horizontalMargin: 18,
          topMargin: 4,
          bottomMargin: 0,
          pullBookmarkEnabled: false,
          tapPageAnimationEnabled: true,
          themeLabelFor: (themeId) => themeId,
          onThemeChanged: (_) {},
          onCustomThemeTap: () {},
          onPageModeTap: () {},
          onTopBarStyleTap: () {},
          onFontSizeChanged: (_) {},
          onLineHeightChanged: (_) {},
          onFirstLineIndentChanged: (value) => changedIndent = value,
          onParagraphSpacingChanged: (value) => changedSpacing = value,
          onHorizontalMarginChanged: (_) {},
          onTopMarginChanged: (_) {},
          onBottomMarginChanged: (_) {},
          onPullBookmarkChanged: (value) => pullBookmark = value,
          onTapPageAnimationChanged: (value) => tapAnimation = value,
        ),
      ),
    );

    final indentFinder = find.descendant(
      of: find.byKey(const ValueKey('reader-first-line-indent-slider')),
      matching: find.byType(Slider),
    );
    final spacingFinder = find.descendant(
      of: find.byKey(const ValueKey('reader-paragraph-spacing-slider')),
      matching: find.byType(Slider),
    );

    final initialIndent = tester.widget<Slider>(indentFinder);
    expect(initialIndent.value, 2);
    expect(initialIndent.min, 0);
    expect(initialIndent.max, 4);
    expect(initialIndent.divisions, 4);

    final initialSpacing = tester.widget<Slider>(spacingFinder);
    expect(initialSpacing.value, 1);
    expect(initialSpacing.min, 0);
    expect(initialSpacing.max, 2);
    expect(initialSpacing.divisions, 2);

    initialIndent.onChanged!(3.6);
    await tester.pump();
    expect(tester.widget<Slider>(indentFinder).value, 4);
    tester.widget<Slider>(indentFinder).onChangeEnd!(3.6);

    initialSpacing.onChanged!(1.6);
    await tester.pump();
    expect(tester.widget<Slider>(spacingFinder).value, 2);
    tester.widget<Slider>(spacingFinder).onChangeEnd!(1.6);

    expect(changedIndent, 4);
    expect(changedSpacing, 2);

    await tester.drag(
      find.byType(ReaderThemeStrip),
      const Offset(-900, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reader-custom-theme-card')), findsOne);
    final pullSwitch = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('reader-pull-bookmark-switch')),
    );
    final animationSwitch = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('reader-tap-page-animation-switch')),
    );
    pullSwitch.onChanged!(true);
    animationSwitch.onChanged!(false);
    expect(pullBookmark, isTrue);
    expect(tapAnimation, isFalse);
  });

  testWidgets('top bar style sheet offers all three shared reader styles',
      (tester) async {
    var selectedStyle = ReaderTopBarStyle.reader;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ReaderTopBarStyleSheet(
              palette: ReaderThemes.day,
              title: 'Top information',
              selectedStyle: selectedStyle,
              titleFor: (style) => style.name,
              hintFor: (style) => '${style.name} hint',
              onSelected: (style) {
                setState(() => selectedStyle = style);
              },
            ),
          ),
        ),
      ),
    );

    for (final style in ReaderTopBarStyle.values) {
      expect(
        find.byKey(ValueKey('reader-top-bar-style-${style.name}')),
        findsOneWidget,
      );
    }

    await tester.tap(find.text('hidden'));
    await tester.pump();
    expect(selectedStyle, ReaderTopBarStyle.hidden);
  });
}

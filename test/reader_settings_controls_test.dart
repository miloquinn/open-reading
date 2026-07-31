import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_system_ui.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_settings_controls.dart';

void main() {
  testWidgets(
    'typography sliders expose discrete values and rounded callbacks',
    (tester) async {
      int? changedIndent;
      int? changedSpacing;
      double? changedLetterSpacing;
      ReaderTextAlignment? changedAlignment;
      bool? pullBookmark;
      bool? tapAnimation;
      bool? tabletTwoPage;
      bool? txtChapterTitlePage;

      await tester.pumpWidget(
        MaterialApp(
          home: ReaderSettingsSheet(
            title: 'Reading settings',
            tabThemeLabel: 'Theme tab',
            tabTextLabel: 'Text tab',
            tabLayoutLabel: 'Layout tab',
            tabPagingLabel: 'Paging tab',
            advancedTypographyTitle: 'Advanced typography',
            themeDescription: 'Choose a theme',
            pageModeTitle: 'Page mode',
            pageModeSummary: 'Page curl',
            topBarStyleTitle: 'Top information',
            topBarStyleSummary: 'Reader information bar',
            pullBookmarkTitle: 'Pull bookmark',
            pullBookmarkHint: 'Pull down from the top',
            tapPageAnimationTitle: 'Tap animation',
            tapPageAnimationHint: 'Animate side taps',
            tapZonesTitle: 'Tap zones',
            tapZonesHint: 'Customize the nine tap areas',
            showTabletTwoPageToggle: true,
            tabletTwoPageTitle: 'Tablet two-page layout',
            tabletTwoPageHint: 'Show two pages in landscape',
            fontSizeLabel: 'Font size',
            lineHeightLabel: 'Line height',
            letterSpacingLabel: 'Letter spacing',
            textAlignmentLabel: 'Alignment',
            textAlignmentNaturalLabel: 'Natural',
            textAlignmentJustifiedLabel: 'Justified',
            firstLineIndentLabel: 'First-line indent',
            paragraphSpacingLabel: 'Paragraph spacing',
            horizontalMarginLabel: 'Horizontal margin',
            topMarginLabel: 'Top margin',
            bottomMarginLabel: 'Bottom margin',
            txtChapterTitlePageTitle: 'Chapter title on its own page',
            txtChapterTitlePageHint: 'Show the title above body text when off',
            themeId: ReaderThemes.day.id,
            fontSize: 19,
            lineHeight: 1.7,
            letterSpacing: 0.3,
            textAlignment: ReaderTextAlignment.natural,
            firstLineIndent: 2,
            paragraphSpacing: 1,
            horizontalMargin: 18,
            topMargin: 4,
            bottomMargin: 0,
            pullBookmarkEnabled: false,
            tapPageAnimationEnabled: true,
            tabletTwoPageEnabled: true,
            txtChapterTitlePageEnabled: true,
            themeLabelFor: (themeId) => themeId,
            onThemeChanged: (_) {},
            onCustomThemeTap: () {},
            onPageModeTap: () {},
            onTopBarStyleTap: () {},
            onTapZonesTap: () {},
            onFontSizeChanged: (_) {},
            onLineHeightChanged: (_) {},
            onLetterSpacingChanged: (value) => changedLetterSpacing = value,
            onTextAlignmentChanged: (value) => changedAlignment = value,
            onFirstLineIndentChanged: (value) => changedIndent = value,
            onParagraphSpacingChanged: (value) => changedSpacing = value,
            onHorizontalMarginChanged: (_) {},
            onTopMarginChanged: (_) {},
            onBottomMarginChanged: (_) {},
            onPullBookmarkChanged: (value) => pullBookmark = value,
            onTapPageAnimationChanged: (value) => tapAnimation = value,
            onTabletTwoPageChanged: (value) => tabletTwoPage = value,
            onTxtChapterTitlePageChanged: (value) =>
                txtChapterTitlePage = value,
          ),
        ),
      );

      await tester.tap(find.text('Text tab'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reader-letter-spacing-slider')),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('reader-advanced-typography-tile')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced typography'));
      await tester.pumpAndSettle();

      final indentFinder = find.descendant(
        of: find.byKey(const ValueKey('reader-first-line-indent-slider')),
        matching: find.byType(Slider),
      );
      final spacingFinder = find.descendant(
        of: find.byKey(const ValueKey('reader-paragraph-spacing-slider')),
        matching: find.byType(Slider),
      );
      final letterSpacingFinder = find.descendant(
        of: find.byKey(const ValueKey('reader-letter-spacing-slider')),
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

      final initialLetterSpacing = tester.widget<Slider>(letterSpacingFinder);
      expect(initialLetterSpacing.value, 0.3);
      expect(initialLetterSpacing.min, ReaderSettings.minLetterSpacing);
      expect(initialLetterSpacing.max, ReaderSettings.maxLetterSpacing);

      initialIndent.onChanged!(3.6);
      await tester.pump();
      expect(tester.widget<Slider>(indentFinder).value, 4);
      tester.widget<Slider>(indentFinder).onChangeEnd!(3.6);

      initialSpacing.onChanged!(1.6);
      await tester.pump();
      expect(tester.widget<Slider>(spacingFinder).value, 2);
      tester.widget<Slider>(spacingFinder).onChangeEnd!(1.6);

      initialLetterSpacing.onChanged!(0.8);
      await tester.pump();
      tester.widget<Slider>(letterSpacingFinder).onChangeEnd!(0.8);
      tester
          .widget<SegmentedButton<ReaderTextAlignment>>(
            find.byKey(const ValueKey('reader-text-alignment-control')),
          )
          .onSelectionChanged!({ReaderTextAlignment.justified});
      await tester.pump();

      expect(changedIndent, 4);
      expect(changedSpacing, 2);
      expect(changedLetterSpacing, 0.8);
      expect(changedAlignment, ReaderTextAlignment.justified);

      await tester.tap(find.text('Layout tab'));
      await tester.pumpAndSettle();
      final titlePageSwitch = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('reader-txt-chapter-title-page-switch')),
      );
      expect(titlePageSwitch.value, isTrue);
      titlePageSwitch.onChanged!(false);
      expect(txtChapterTitlePage, isFalse);

      await tester.tap(find.text('Theme tab'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(ReaderThemeStrip));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ReaderThemeStrip), const Offset(-900, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reader-custom-theme-card')), findsOne);

      await tester.tap(find.text('Paging tab'));
      await tester.pumpAndSettle();
      final pullSwitch = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('reader-pull-bookmark-switch')),
      );
      final animationSwitch = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('reader-tap-page-animation-switch')),
      );
      final tabletSwitch = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('reader-tablet-two-page-switch')),
      );
      pullSwitch.onChanged!(true);
      animationSwitch.onChanged!(false);
      tabletSwitch.onChanged!(false);
      expect(pullBookmark, isTrue);
      expect(tapAnimation, isFalse);
      expect(tabletTwoPage, isFalse);
    },
  );

  testWidgets('top bar style sheet offers all shared reader styles', (
    tester,
  ) async {
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

    await tester.tap(find.text('floating'));
    await tester.pump();
    expect(selectedStyle, ReaderTopBarStyle.floating);

    await tester.tap(find.text('hidden'));
    await tester.pump();
    expect(selectedStyle, ReaderTopBarStyle.hidden);
  });

  testWidgets('selected theme card paints its border above the background', (
    tester,
  ) async {
    ReaderThemes.setCustomThemes(const []);
    ReaderThemes.setThemeOrder(const []);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderThemeStrip(
            selectedThemeId: ReaderThemes.day.id,
            labelFor: (id) => id,
            onSelected: (_) {},
            onCustomThemeTap: () {},
          ),
        ),
      ),
    );

    final card = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('reader-theme-day')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is AnimatedContainer &&
              widget.clipBehavior == Clip.antiAlias,
        ),
      ),
    );
    final decoration = card.decoration! as BoxDecoration;
    final foreground = card.foregroundDecoration! as BoxDecoration;

    expect(decoration.border, isNull);
    expect(foreground.border, isNotNull);
    expect(foreground.borderRadius, BorderRadius.circular(18));
  });

  testWidgets('system theme card is the first reading theme option', (
    tester,
  ) async {
    ReaderThemes.setCustomThemes(const []);
    ReaderThemes.setThemeOrder(const []);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderThemeStrip(
            selectedThemeId: ReaderThemes.systemId,
            labelFor: (id) => id,
            onSelected: (_) {},
            onCustomThemeTap: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('reader-theme-system')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('reader-theme-system'))).dx,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('reader-theme-day'))).dx,
      ),
    );
  });
}

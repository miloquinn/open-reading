import 'package:flutter/material.dart';

import '../core/reader/reader_layout.dart';
import '../core/reader/reader_margin_settings.dart';
import '../core/reader/reader_custom_theme.dart';
import '../core/reader/reader_system_ui.dart';
import '../utils/reader_themes.dart';
import 'reader_theme_background.dart';

class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({
    super.key,
    required this.title,
    required this.themeTitle,
    required this.themeDescription,
    required this.pageModeTitle,
    required this.pageModeSummary,
    required this.topBarStyleTitle,
    required this.topBarStyleSummary,
    required this.pullBookmarkTitle,
    required this.pullBookmarkHint,
    required this.tapPageAnimationTitle,
    required this.tapPageAnimationHint,
    required this.showTabletTwoPageToggle,
    required this.tabletTwoPageTitle,
    required this.tabletTwoPageHint,
    required this.fontSizeLabel,
    required this.lineHeightLabel,
    required this.firstLineIndentLabel,
    required this.paragraphSpacingLabel,
    required this.horizontalMarginLabel,
    required this.topMarginLabel,
    required this.bottomMarginLabel,
    required this.themeId,
    required this.fontSize,
    required this.lineHeight,
    required this.firstLineIndent,
    required this.paragraphSpacing,
    required this.horizontalMargin,
    required this.topMargin,
    required this.bottomMargin,
    required this.pullBookmarkEnabled,
    required this.tapPageAnimationEnabled,
    required this.tabletTwoPageEnabled,
    required this.themeLabelFor,
    required this.onThemeChanged,
    required this.onCustomThemeTap,
    required this.onPageModeTap,
    required this.onTopBarStyleTap,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onFirstLineIndentChanged,
    required this.onParagraphSpacingChanged,
    required this.onHorizontalMarginChanged,
    required this.onTopMarginChanged,
    required this.onBottomMarginChanged,
    required this.onPullBookmarkChanged,
    required this.onTapPageAnimationChanged,
    required this.onTabletTwoPageChanged,
  });

  final String title;
  final String themeTitle;
  final String themeDescription;
  final String pageModeTitle;
  final String pageModeSummary;
  final String topBarStyleTitle;
  final String topBarStyleSummary;
  final String pullBookmarkTitle;
  final String pullBookmarkHint;
  final String tapPageAnimationTitle;
  final String tapPageAnimationHint;
  final bool showTabletTwoPageToggle;
  final String tabletTwoPageTitle;
  final String tabletTwoPageHint;
  final String fontSizeLabel;
  final String lineHeightLabel;
  final String firstLineIndentLabel;
  final String paragraphSpacingLabel;
  final String horizontalMarginLabel;
  final String topMarginLabel;
  final String bottomMarginLabel;
  final String themeId;
  final double fontSize;
  final double lineHeight;
  final int firstLineIndent;
  final int paragraphSpacing;
  final double horizontalMargin;
  final double topMargin;
  final double bottomMargin;
  final bool pullBookmarkEnabled;
  final bool tapPageAnimationEnabled;
  final bool tabletTwoPageEnabled;
  final String Function(String themeId) themeLabelFor;
  final ValueChanged<String> onThemeChanged;
  final VoidCallback onCustomThemeTap;
  final VoidCallback onPageModeTap;
  final VoidCallback onTopBarStyleTap;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<int> onFirstLineIndentChanged;
  final ValueChanged<int> onParagraphSpacingChanged;
  final ValueChanged<double> onHorizontalMarginChanged;
  final ValueChanged<double> onTopMarginChanged;
  final ValueChanged<double> onBottomMarginChanged;
  final ValueChanged<bool> onPullBookmarkChanged;
  final ValueChanged<bool> onTapPageAnimationChanged;
  final ValueChanged<bool> onTabletTwoPageChanged;

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late String _themeId = widget.themeId;
  late double _fontSize = widget.fontSize;
  late double _lineHeight = widget.lineHeight;
  late int _firstLineIndent = widget.firstLineIndent;
  late int _paragraphSpacing = widget.paragraphSpacing;
  late double _horizontalMargin = widget.horizontalMargin;
  late double _topMargin = widget.topMargin;
  late double _bottomMargin = widget.bottomMargin;
  late bool _pullBookmarkEnabled = widget.pullBookmarkEnabled;
  late bool _tapPageAnimationEnabled = widget.tapPageAnimationEnabled;
  late bool _tabletTwoPageEnabled = widget.tabletTwoPageEnabled;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderThemes.byId(_themeId);
    final theme = palette.toThemeData(typography: Theme.of(context).textTheme);
    return ReaderSettingsSheetFrame(
      palette: palette,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            widget.themeTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(widget.themeDescription, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          ReaderThemeStrip(
            selectedThemeId: _themeId,
            labelFor: widget.themeLabelFor,
            onSelected: (themeId) {
              setState(() => _themeId = themeId);
              widget.onThemeChanged(themeId);
            },
            onCustomThemeTap: widget.onCustomThemeTap,
          ),
          const Divider(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.swap_calls),
            title: Text(widget.pageModeTitle),
            subtitle: Text(widget.pageModeSummary),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onPageModeTap,
          ),
          if (widget.showTabletTwoPageToggle)
            SwitchListTile(
              key: const ValueKey('reader-tablet-two-page-switch'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.menu_book_rounded),
              value: _tabletTwoPageEnabled,
              title: Text(widget.tabletTwoPageTitle),
              subtitle: Text(widget.tabletTwoPageHint),
              onChanged: (value) {
                setState(() => _tabletTwoPageEnabled = value);
                widget.onTabletTwoPageChanged(value);
              },
            ),
          ListTile(
            key: const ValueKey('reader-top-bar-style-tile'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.vertical_align_top_rounded),
            title: Text(widget.topBarStyleTitle),
            subtitle: Text(widget.topBarStyleSummary),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onTopBarStyleTap,
          ),
          SwitchListTile(
            key: const ValueKey('reader-pull-bookmark-switch'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.bookmark_add_outlined),
            value: _pullBookmarkEnabled,
            title: Text(widget.pullBookmarkTitle),
            subtitle: Text(widget.pullBookmarkHint),
            onChanged: (value) {
              setState(() => _pullBookmarkEnabled = value);
              widget.onPullBookmarkChanged(value);
            },
          ),
          SwitchListTile(
            key: const ValueKey('reader-tap-page-animation-switch'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.animation_rounded),
            value: _tapPageAnimationEnabled,
            title: Text(widget.tapPageAnimationTitle),
            subtitle: Text(widget.tapPageAnimationHint),
            onChanged: (value) {
              setState(() => _tapPageAnimationEnabled = value);
              widget.onTapPageAnimationChanged(value);
            },
          ),
          const Divider(height: 28),
          ReaderSettingSlider(
            label: widget.fontSizeLabel,
            value: _fontSize,
            valueLabel: _fontSize.round().toString(),
            min: 14,
            max: 32,
            divisions: 18,
            onChanged: (value) => setState(() => _fontSize = value),
            onChangeEnd: widget.onFontSizeChanged,
          ),
          ReaderSettingSlider(
            label: widget.lineHeightLabel,
            value: _lineHeight,
            valueLabel: _lineHeight.toStringAsFixed(1),
            min: 1.4,
            max: 2.1,
            divisions: 7,
            onChanged: (value) => setState(() => _lineHeight = value),
            onChangeEnd: widget.onLineHeightChanged,
          ),
          ReaderSettingSlider(
            key: const ValueKey('reader-first-line-indent-slider'),
            label: widget.firstLineIndentLabel,
            value: _firstLineIndent.toDouble(),
            valueLabel: _firstLineIndent.toString(),
            min: 0,
            max: 4,
            divisions: 4,
            onChanged: (value) => setState(
              () => _firstLineIndent = value.round(),
            ),
            onChangeEnd: (value) =>
                widget.onFirstLineIndentChanged(value.round()),
          ),
          ReaderSettingSlider(
            key: const ValueKey('reader-paragraph-spacing-slider'),
            label: widget.paragraphSpacingLabel,
            value: _paragraphSpacing.toDouble(),
            valueLabel: _paragraphSpacing.toString(),
            min: 0,
            max: 2,
            divisions: 2,
            onChanged: (value) => setState(
              () => _paragraphSpacing = value.round(),
            ),
            onChangeEnd: (value) =>
                widget.onParagraphSpacingChanged(value.round()),
          ),
          ReaderSettingSlider(
            key: const ValueKey('reader-horizontal-margin-slider'),
            label: widget.horizontalMarginLabel,
            value: _horizontalMargin,
            valueLabel: _horizontalMargin.round().toString(),
            min: ReaderMarginSettings.horizontalMin,
            max: ReaderMarginSettings.horizontalMax,
            divisions: 48,
            onChanged: (value) => setState(() => _horizontalMargin = value),
            onChangeEnd: widget.onHorizontalMarginChanged,
          ),
          ReaderMarginControls(
            topLabel: widget.topMarginLabel,
            bottomLabel: widget.bottomMarginLabel,
            topMargin: _topMargin,
            bottomMargin: _bottomMargin,
            onTopChanged: (value) => setState(() => _topMargin = value),
            onBottomChanged: (value) => setState(() => _bottomMargin = value),
            onTopChangeEnd: widget.onTopMarginChanged,
            onBottomChangeEnd: widget.onBottomMarginChanged,
          ),
        ],
      ),
    );
  }
}

class ReaderTopBarStyleSheet extends StatelessWidget {
  const ReaderTopBarStyleSheet({
    super.key,
    required this.palette,
    required this.title,
    required this.selectedStyle,
    required this.titleFor,
    required this.hintFor,
    required this.onSelected,
  });

  final ReaderThemePalette palette;
  final String title;
  final ReaderTopBarStyle selectedStyle;
  final String Function(ReaderTopBarStyle style) titleFor;
  final String Function(ReaderTopBarStyle style) hintFor;
  final ValueChanged<ReaderTopBarStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = palette.toThemeData(typography: Theme.of(context).textTheme);
    return Theme(
      data: theme,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              RadioGroup<ReaderTopBarStyle>(
                groupValue: selectedStyle,
                onChanged: (style) {
                  if (style != null) onSelected(style);
                },
                child: Column(
                  children: [
                    for (final style in ReaderTopBarStyle.values)
                      RadioListTile<ReaderTopBarStyle>(
                        key: ValueKey('reader-top-bar-style-${style.name}'),
                        value: style,
                        contentPadding: EdgeInsets.zero,
                        secondary: _ReaderTopBarStylePreview(
                          style: style,
                          palette: palette,
                        ),
                        title: Text(titleFor(style)),
                        subtitle: Text(hintFor(style)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderTopBarStylePreview extends StatelessWidget {
  const _ReaderTopBarStylePreview({
    required this.style,
    required this.palette,
  });

  final ReaderTopBarStyle style;
  final ReaderThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final muted = palette.secondaryText.withValues(alpha: 0.72);
    return Semantics(
      excludeSemantics: true,
      child: Container(
        width: 72,
        height: 44,
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 4),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border.withValues(alpha: 0.7)),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 10,
              child: switch (style) {
                ReaderTopBarStyle.system => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('9:41', style: TextStyle(fontSize: 5, color: muted)),
                      Icon(Icons.signal_cellular_alt_rounded,
                          size: 7, color: muted),
                    ],
                  ),
                ReaderTopBarStyle.reader => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('9:41', style: TextStyle(fontSize: 5, color: muted)),
                      Expanded(
                        child: Text(
                          '···',
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 5, color: muted),
                        ),
                      ),
                      Icon(Icons.battery_full_rounded, size: 7, color: muted),
                    ],
                  ),
                ReaderTopBarStyle.hidden => const SizedBox.shrink(),
              },
            ),
            const SizedBox(height: 4),
            for (var index = 0; index < 3; index++) ...[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: index == 2 ? 0.62 : 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.text.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
              if (index != 2) const SizedBox(height: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class ReaderPageModeSheet extends StatelessWidget {
  const ReaderPageModeSheet({
    super.key,
    required this.palette,
    required this.title,
    required this.selectedMode,
    required this.titleFor,
    required this.hintFor,
    required this.onSelected,
    this.scrollByChapter,
    this.scrollByChapterTitle,
    this.scrollByChapterOnHint,
    this.scrollByChapterOffHint,
    this.onScrollByChapterChanged,
  });

  final ReaderThemePalette palette;
  final String title;
  final ReaderPageMode selectedMode;
  final String Function(ReaderPageMode mode) titleFor;
  final String Function(ReaderPageMode mode) hintFor;
  final ValueChanged<ReaderPageMode> onSelected;
  final bool? scrollByChapter;
  final String? scrollByChapterTitle;
  final String? scrollByChapterOnHint;
  final String? scrollByChapterOffHint;
  final ValueChanged<bool>? onScrollByChapterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = palette.toThemeData(typography: Theme.of(context).textTheme);
    return Theme(
      data: theme,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              RadioGroup<ReaderPageMode>(
                groupValue: selectedMode,
                onChanged: (mode) {
                  if (mode != null) onSelected(mode);
                },
                child: Column(
                  children: ReaderPageMode.values.expand((mode) sync* {
                    yield RadioListTile<ReaderPageMode>(
                      value: mode,
                      title: Text(titleFor(mode)),
                      subtitle: Text(hintFor(mode)),
                    );
                    if (mode == ReaderPageMode.verticalScroll &&
                        selectedMode == ReaderPageMode.verticalScroll &&
                        scrollByChapter != null) {
                      yield SwitchListTile(
                        contentPadding: const EdgeInsets.only(left: 24),
                        value: scrollByChapter!,
                        title: Text(scrollByChapterTitle!),
                        subtitle: Text(
                          scrollByChapter!
                              ? scrollByChapterOnHint!
                              : scrollByChapterOffHint!,
                        ),
                        onChanged: onScrollByChapterChanged,
                      );
                    }
                  }).toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReaderSettingsSheetFrame extends StatelessWidget {
  const ReaderSettingsSheetFrame({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 20),
  });

  final ReaderThemePalette palette;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // 拖动横条必须留在滚动视图之外：放进滚动区后，下拉手势会被
    // 滚动视图消费，弹窗无法通过拖动收起。
    return Theme(
      data: palette.toThemeData(typography: Theme.of(context).textTheme),
      child: Material(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ReaderSettingsDragHandle(palette: palette),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: padding,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderSettingsDragHandle extends StatelessWidget {
  const ReaderSettingsDragHandle({super.key, required this.palette});

  final ReaderThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: palette.secondaryText.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class ReaderThemeStrip extends StatelessWidget {
  const ReaderThemeStrip({
    super.key,
    required this.selectedThemeId,
    required this.labelFor,
    required this.onSelected,
    required this.onCustomThemeTap,
  });

  final String selectedThemeId;
  final String Function(String themeId) labelFor;
  final ValueChanged<String> onSelected;
  final VoidCallback onCustomThemeTap;

  @override
  Widget build(BuildContext context) {
    final customThemes = ReaderThemes.customThemes;
    final themes = ReaderThemes.orderedPalettes;
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        physics: const BouncingScrollPhysics(),
        itemCount: themes.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == themes.length) {
            final colors = Theme.of(context).colorScheme;
            return SizedBox(
              width: 108,
              child: Semantics(
                button: true,
                label: labelFor(ReaderCustomTheme.legacyThemeId),
                child: InkWell(
                  key: const ValueKey('reader-custom-theme-card'),
                  onTap: onCustomThemeTap,
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colors.outlineVariant,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: colors.outlineVariant),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                size: 20,
                                color: colors.onSurface,
                              ),
                            ),
                            const Spacer(),
                            if (customThemes.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '${customThemes.length}',
                                  style: TextStyle(
                                    color: colors.onPrimaryContainer,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          customThemes.isEmpty ? 'Aa +' : 'Aa ···',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 19,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          labelFor(ReaderCustomTheme.legacyThemeId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          final palette = themes[index];
          final customTheme = ReaderThemes.customThemeById(palette.id);
          final selected = palette.id == selectedThemeId;
          final label = customTheme == null || customTheme.name.trim().isEmpty
              ? labelFor(palette.id)
              : customTheme.name.trim();
          return _ReaderThemeCard(
            key: ValueKey('reader-theme-${palette.id}'),
            palette: palette,
            label: label,
            selected: selected,
            icon: customTheme == null
                ? _iconFor(palette.id)
                : customTheme.hasBackgroundImage
                    ? Icons.image_rounded
                    : Icons.palette_rounded,
            onTap: () => onSelected(palette.id),
          );
        },
      ),
    );
  }

  IconData _iconFor(String id) => switch (id) {
        'pureBlack' => Icons.brightness_1_rounded,
        'night' => Icons.dark_mode_rounded,
        'navy' => Icons.nights_stay_rounded,
        'parchment' => Icons.auto_stories_rounded,
        'green' => Icons.eco_rounded,
        'rose' => Icons.local_florist_rounded,
        'mist' => Icons.cloud_outlined,
        _ => Icons.light_mode_rounded,
      };
}

class _ReaderThemeCard extends StatelessWidget {
  const _ReaderThemeCard({
    super.key,
    required this.palette,
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final ReaderThemePalette palette;
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardRadius = BorderRadius.circular(18);
    return SizedBox(
      width: 108,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: cardRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: cardRadius,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: palette.shadow.withValues(alpha: 0.16),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: cardRadius,
              border: Border.all(
                color: selected ? palette.accent : palette.border,
                width: selected ? 2.2 : 1,
              ),
            ),
            child: ReaderThemeBackground(
              palette: palette,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: palette.secondaryText),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: selected
                                ? palette.accent
                                : palette.controlBar.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.border),
                          ),
                          child: selected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: palette.onAccent,
                                )
                              : null,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Aa',
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderSettingSlider extends StatelessWidget {
  const ReaderSettingSlider({
    super.key,
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String label;
  final double value;
  final String valueLabel;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  valueLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: Theme.of(context).sliderTheme.copyWith(
                  trackHeight: 4,
                  activeTrackColor: colors.primary,
                  inactiveTrackColor: colors.outlineVariant,
                  thumbColor: colors.primary,
                  overlayColor: colors.primary.withValues(alpha: 0.12),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 9),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 20),
                  showValueIndicator: ShowValueIndicator.never,
                ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}

class ReaderMarginControls extends StatelessWidget {
  const ReaderMarginControls({
    super.key,
    required this.topLabel,
    required this.bottomLabel,
    required this.topMargin,
    required this.bottomMargin,
    required this.onTopChanged,
    required this.onBottomChanged,
    this.onTopChangeEnd,
    this.onBottomChangeEnd,
  });

  final String topLabel;
  final String bottomLabel;
  final double topMargin;
  final double bottomMargin;
  final ValueChanged<double> onTopChanged;
  final ValueChanged<double> onBottomChanged;
  final ValueChanged<double>? onTopChangeEnd;
  final ValueChanged<double>? onBottomChangeEnd;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ReaderSettingSlider(
            key: const ValueKey('reader-top-margin-slider'),
            label: topLabel,
            value: topMargin,
            valueLabel: topMargin.round().toString(),
            min: 0,
            max: 40,
            divisions: 40,
            onChanged: onTopChanged,
            onChangeEnd: onTopChangeEnd,
          ),
          ReaderSettingSlider(
            key: const ValueKey('reader-bottom-margin-slider'),
            label: bottomLabel,
            value: bottomMargin,
            valueLabel: bottomMargin.round().toString(),
            min: 0,
            max: 40,
            divisions: 40,
            onChanged: onBottomChanged,
            onChangeEnd: onBottomChangeEnd,
          ),
        ],
      );
}

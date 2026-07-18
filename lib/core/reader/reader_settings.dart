import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reader_layout.dart';
import 'reader_margin_settings.dart';

@immutable
class ReaderSettings {
  static const double defaultFontSize = 19;
  static const double defaultLineHeight = 1.75;
  static const double defaultHorizontalMargin = 18;
  static const int defaultFirstLineIndent = 2;
  static const int defaultParagraphSpacing = 0;
  static const String defaultThemeId = 'day';

  const ReaderSettings({
    required this.fontSize,
    required this.lineHeight,
    required this.horizontalMargin,
    required this.topMargin,
    required this.bottomMargin,
    required this.themeId,
    required this.pageMode,
    this.firstLineIndent = defaultFirstLineIndent,
    this.paragraphSpacing = defaultParagraphSpacing,
    this.pageTurnStyle = ReaderPageTurnStyle.cylinder,
    this.pullBookmarkEnabled = false,
    this.tapPageAnimationEnabled = true,
  });

  final double fontSize;
  final double lineHeight;
  final double horizontalMargin;
  final double topMargin;
  final double bottomMargin;
  final String themeId;
  final ReaderPageMode pageMode;
  final int firstLineIndent;
  final int paragraphSpacing;
  final ReaderPageTurnStyle pageTurnStyle;
  final bool pullBookmarkEnabled;
  final bool tapPageAnimationEnabled;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalMargin,
    double? topMargin,
    double? bottomMargin,
    String? themeId,
    ReaderPageMode? pageMode,
    int? firstLineIndent,
    int? paragraphSpacing,
    ReaderPageTurnStyle? pageTurnStyle,
    bool? pullBookmarkEnabled,
    bool? tapPageAnimationEnabled,
  }) {
    return ReaderSettings(
      fontSize: (fontSize ?? this.fontSize).clamp(14, 32),
      lineHeight: (lineHeight ?? this.lineHeight).clamp(1.4, 2.1),
      horizontalMargin: (horizontalMargin ?? this.horizontalMargin).clamp(
        ReaderMarginSettings.horizontalMin,
        ReaderMarginSettings.horizontalMax,
      ),
      topMargin: (topMargin ?? this.topMargin)
          .clamp(ReaderMarginSettings.min, ReaderMarginSettings.max),
      bottomMargin: (bottomMargin ?? this.bottomMargin)
          .clamp(ReaderMarginSettings.min, ReaderMarginSettings.max),
      themeId: themeId ?? this.themeId,
      pageMode: pageMode ?? this.pageMode,
      firstLineIndent: (firstLineIndent ?? this.firstLineIndent).clamp(0, 4),
      paragraphSpacing: (paragraphSpacing ?? this.paragraphSpacing).clamp(0, 2),
      pageTurnStyle: pageTurnStyle ?? this.pageTurnStyle,
      pullBookmarkEnabled: pullBookmarkEnabled ?? this.pullBookmarkEnabled,
      tapPageAnimationEnabled:
          tapPageAnimationEnabled ?? this.tapPageAnimationEnabled,
    );
  }
}

class ReaderSettingsStore {
  static const fontSizeKey = 'native_reader_font_size';
  static const lineHeightKey = 'native_reader_line_height';
  static const horizontalMarginKey = 'native_reader_horizontal_margin';
  static const topMarginKey = 'native_reader_top_margin';
  static const bottomMarginKey = 'native_reader_bottom_margin';
  static const legacyVerticalMarginKey = 'native_reader_vertical_margin';
  static const themeKey = 'native_reader_theme';
  static const pageModeKey = 'native_reader_page_mode';
  static const firstLineIndentKey = 'native_reader_first_line_indent';
  static const paragraphSpacingKey = 'native_reader_paragraph_spacing';
  static const pageTurnStyleKey = 'native_reader_page_turn_style';
  static const pullBookmarkKey = 'reader_pull_bookmark_enabled';
  static const tapPageAnimationKey = 'reader_tap_page_animation_enabled';
  static const scrollByChapterKey = 'native_reader_scroll_by_chapter';
  static const legacyBookSourceLineHeightKey = 'book_source_reader_line_height';

  const ReaderSettingsStore();

  Future<ReaderSettings> load({
    required ReaderPageMode fallbackPageMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storedTopMargin = prefs.getDouble(topMarginKey);
    final storedBottomMargin = prefs.getDouble(bottomMarginKey);
    final margins = ReaderMarginSettings.fromStored(
      top: storedTopMargin,
      bottom: storedBottomMargin,
      legacyVertical: prefs.getDouble(legacyVerticalMarginKey),
    );
    if (storedTopMargin == null || storedBottomMargin == null) {
      await Future.wait([
        prefs.setDouble(topMarginKey, margins.top),
        prefs.setDouble(bottomMarginKey, margins.bottom),
      ]);
    }

    return ReaderSettings(
      fontSize: (prefs.getDouble(fontSizeKey) ?? ReaderSettings.defaultFontSize)
          .clamp(14, 32),
      lineHeight: (prefs.getDouble(lineHeightKey) ??
              prefs.getDouble(legacyBookSourceLineHeightKey) ??
              ReaderSettings.defaultLineHeight)
          .clamp(1.4, 2.1),
      horizontalMargin: (prefs.getDouble(horizontalMarginKey) ??
              ReaderSettings.defaultHorizontalMargin)
          .clamp(
        ReaderMarginSettings.horizontalMin,
        ReaderMarginSettings.horizontalMax,
      ),
      topMargin: margins.top,
      bottomMargin: margins.bottom,
      themeId: prefs.getString(themeKey) ?? ReaderSettings.defaultThemeId,
      pageMode: readerPageModeFromName(
        prefs.getString(pageModeKey),
        fallback: fallbackPageMode,
      ),
      firstLineIndent: (prefs.getInt(firstLineIndentKey) ??
              ReaderSettings.defaultFirstLineIndent)
          .clamp(0, 4),
      paragraphSpacing: (prefs.getInt(paragraphSpacingKey) ??
              ReaderSettings.defaultParagraphSpacing)
          .clamp(0, 2),
      pageTurnStyle: readerPageTurnStyleFromName(
        prefs.getString(pageTurnStyleKey),
      ),
      pullBookmarkEnabled: prefs.getBool(pullBookmarkKey) ?? false,
      tapPageAnimationEnabled: prefs.getBool(tapPageAnimationKey) ?? true,
    );
  }

  Future<void> save(ReaderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setDouble(fontSizeKey, settings.fontSize),
      prefs.setDouble(lineHeightKey, settings.lineHeight),
      prefs.setDouble(horizontalMarginKey, settings.horizontalMargin),
      prefs.setDouble(topMarginKey, settings.topMargin),
      prefs.setDouble(bottomMarginKey, settings.bottomMargin),
      prefs.setString(themeKey, settings.themeId),
      prefs.setString(pageModeKey, settings.pageMode.name),
      prefs.setInt(firstLineIndentKey, settings.firstLineIndent),
      prefs.setInt(paragraphSpacingKey, settings.paragraphSpacing),
      prefs.setString(pageTurnStyleKey, settings.pageTurnStyle.name),
      prefs.setBool(pullBookmarkKey, settings.pullBookmarkEnabled),
      prefs.setBool(
        tapPageAnimationKey,
        settings.tapPageAnimationEnabled,
      ),
    ]);
  }

  Future<bool> loadScrollByChapter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(scrollByChapterKey) ?? true;
  }

  Future<void> saveScrollByChapter(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(scrollByChapterKey, value);
  }
}

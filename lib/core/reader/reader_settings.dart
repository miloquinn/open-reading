import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reader_layout.dart';
import 'reader_margin_settings.dart';

@immutable
class ReaderSettings {
  static const double defaultFontSize = 19;
  static const double defaultLineHeight = 1.75;
  static const double defaultHorizontalMargin = 18;
  static const String defaultThemeId = 'day';

  const ReaderSettings({
    required this.fontSize,
    required this.lineHeight,
    required this.horizontalMargin,
    required this.topMargin,
    required this.bottomMargin,
    required this.themeId,
    required this.pageMode,
  });

  final double fontSize;
  final double lineHeight;
  final double horizontalMargin;
  final double topMargin;
  final double bottomMargin;
  final String themeId;
  final ReaderPageMode pageMode;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalMargin,
    double? topMargin,
    double? bottomMargin,
    String? themeId,
    ReaderPageMode? pageMode,
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
    ]);
  }
}

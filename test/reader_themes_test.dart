import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_custom_theme.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/utils/reader_themes.dart';

double _relativeLuminance(Color color) {
  double channel(double value) => value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color foreground, Color background) {
  final first = _relativeLuminance(foreground);
  final second = _relativeLuminance(background);
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ReaderThemes.setCustomThemes(const []);
    ReaderThemes.setThemeOrder(const []);
  });

  test('reader themes remain independent and readable', () {
    expect(ReaderThemes.all, hasLength(8));
    expect(
      ReaderThemes.all.map((theme) => theme.id).toSet(),
      hasLength(ReaderThemes.all.length),
    );
    expect(ReaderThemes.day.background, const Color(0xFFFFFFFF));
    expect(ReaderThemes.pureBlack.background, const Color(0xFF000000));
    expect(ReaderThemes.pureBlack.surface, const Color(0xFF000000));
    for (final theme in ReaderThemes.all) {
      expect(
        _contrast(theme.text, theme.background),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.id} body text must meet WCAG AA',
      );
      expect(
        _contrast(theme.text, theme.controlBar),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.id} control text must meet WCAG AA',
      );
    }
  });

  test('unknown saved theme falls back to day', () {
    expect(ReaderThemes.byId('missing'), ReaderThemes.day);
  });

  test('saved palette is available before the reader mounts', () async {
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.themeKey: ReaderThemes.pureBlack.id,
    });

    final palette = await ReaderThemes.loadSavedPalette();

    expect(palette, ReaderThemes.pureBlack);
  });

  test('custom theme derives the full reader palette and cache identity', () {
    const custom = ReaderCustomTheme(
      background: Color(0xFFF4EBD8),
      text: Color(0xFF30271F),
      controlBar: Color(0xFFE1D0B4),
    );
    ReaderThemes.setCustomTheme(custom);

    final palette = ReaderThemes.byId(ReaderCustomTheme.themeId);
    expect(palette.background, custom.background);
    expect(palette.text, custom.text);
    expect(palette.controlBar, custom.controlBar);
    expect(palette.cacheKey, contains(custom.background.toARGB32().toString()));

    final changed = ReaderThemes.fromCustomTheme(
      custom.copyWith(background: const Color(0xFF111111)),
    );
    expect(changed.cacheKey, isNot(palette.cacheKey));
    ReaderThemes.setCustomTheme(null);
  });

  test('multiple custom palettes keep independent ids and display order', () {
    const first = ReaderCustomTheme(
      id: 'custom:first',
      name: 'First',
      background: Color(0xFFF4EBD8),
      text: Color(0xFF30271F),
      controlBar: Color(0xFFE1D0B4),
    );
    const second = ReaderCustomTheme(
      id: 'custom:second',
      name: 'Second',
      background: Color(0xFF101820),
      text: Color(0xFFF5F5F5),
      controlBar: Color(0xFF1E2A34),
      backgroundImagePath: '/themes/night.webp',
      backgroundImageOpacity: 0.5,
    );

    ReaderThemes.setCustomThemes(const [first, second]);

    expect(ReaderThemes.customThemes.map((theme) => theme.id), [
      'custom:first',
      'custom:second',
    ]);
    expect(ReaderThemes.byId(second.id).background, second.background);
    expect(
      ReaderThemes.byId(second.id).backgroundImagePath,
      second.backgroundImagePath,
    );
    expect(ReaderThemes.byId(second.id).cacheKey, contains('night.webp'));
  });

  test('saved order applies to built-in and custom themes together', () {
    const custom = ReaderCustomTheme(
      id: 'custom:first',
      name: 'First',
      background: Color(0xFFF4EBD8),
      text: Color(0xFF30271F),
      controlBar: Color(0xFFE1D0B4),
    );
    ReaderThemes.setCustomThemes(const [custom]);

    ReaderThemes.setThemeOrder(const [
      'green',
      'custom:first',
      'day',
      'missing',
    ]);

    expect(ReaderThemes.orderedPalettes.take(3).map((theme) => theme.id), [
      'green',
      'custom:first',
      'day',
    ]);
    expect(ReaderThemes.themeOrder, hasLength(ReaderThemes.all.length + 1));
  });
}

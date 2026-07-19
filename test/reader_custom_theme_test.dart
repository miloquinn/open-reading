import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_custom_theme.dart';
import 'package:xxread/core/reader/reader_theme_order.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/reader/themes/reader_custom_theme_page.dart';
import 'package:xxread/utils/reader_themes.dart';

void main() {
  test('custom reader theme persists its three user-controlled colors',
      () async {
    SharedPreferences.setMockInitialValues({});
    const theme = ReaderCustomTheme(
      background: Color(0xFF102030),
      text: Color(0xFFF0E0D0),
      controlBar: Color(0xFF203040),
    );
    const store = ReaderCustomThemeStore();

    await store.save(theme);
    final restored = await store.load();

    expect(restored?.background, theme.background);
    expect(restored?.text, theme.text);
    expect(restored?.controlBar, theme.controlBar);
  });

  test('invalid stored custom theme is ignored', () async {
    SharedPreferences.setMockInitialValues({
      ReaderCustomThemeStore.storageKey: '{broken',
    });

    expect(await const ReaderCustomThemeStore().load(), isNull);
  });

  test('custom reader themes persist order, names, and image metadata',
      () async {
    SharedPreferences.setMockInitialValues({});
    const themes = [
      ReaderCustomTheme(
        id: 'custom:first',
        name: 'Rain',
        background: Color(0xFF102030),
        text: Color(0xFFF0E0D0),
        controlBar: Color(0xFF203040),
        backgroundImagePath: r'C:\themes\rain.webp',
        backgroundImageOpacity: 0.42,
      ),
      ReaderCustomTheme(
        id: 'custom:second',
        name: 'Paper',
        background: Color(0xFFF4EBD8),
        text: Color(0xFF30271F),
        controlBar: Color(0xFFE1D0B4),
      ),
    ];
    const store = ReaderCustomThemeStore();

    await store.saveAll(themes);
    final restored = await store.loadAll();

    expect(
        restored.map((theme) => theme.id), ['custom:first', 'custom:second']);
    expect(restored.first.name, 'Rain');
    expect(restored.first.backgroundImagePath, r'C:\themes\rain.webp');
    expect(restored.first.backgroundImageOpacity, 0.42);
  });

  test('legacy single custom theme migrates into the ordered library',
      () async {
    SharedPreferences.setMockInitialValues({
      ReaderCustomThemeStore.legacyStorageKey: jsonEncode({
        'background': const Color(0xFF102030).toARGB32(),
        'text': const Color(0xFFF0E0D0).toARGB32(),
        'controlBar': const Color(0xFF203040).toARGB32(),
      }),
    });
    const store = ReaderCustomThemeStore();

    final restored = await store.loadAll();
    final prefs = await SharedPreferences.getInstance();

    expect(restored, hasLength(1));
    expect(restored.single.id, ReaderCustomTheme.legacyThemeId);
    expect(prefs.getString(ReaderCustomThemeStore.storageKey), isNotNull);
  });

  test('reader theme order store removes blanks and duplicate ids', () async {
    SharedPreferences.setMockInitialValues({});
    const store = ReaderThemeOrderStore();

    await store.save(['mist', 'day', 'mist', ' ', 'custom:first']);

    expect(await store.load(), ['mist', 'day', 'custom:first']);
  });

  testWidgets('editing a preview does not mutate the active saved palette',
      (tester) async {
    const active = ReaderCustomTheme(
      background: Color(0xFFFFFFFF),
      text: Color(0xFF111111),
      controlBar: Color(0xFFF0F0F0),
    );
    const draft = ReaderCustomTheme(
      background: Color(0xFF101820),
      text: Color(0xFFF5F5F5),
      controlBar: Color(0xFF1E2A34),
    );
    ReaderThemes.setCustomTheme(active);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReaderCustomThemePage(initialTheme: draft),
      ),
    );
    await tester.pump();

    expect(ReaderThemes.customTheme, same(active));
    expect(find.byKey(const ValueKey('save-custom-reader-theme')), findsOne);
    ReaderThemes.setCustomTheme(null);
  });
}

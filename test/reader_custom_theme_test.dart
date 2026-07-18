import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_custom_theme.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/reader_custom_theme_page.dart';
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

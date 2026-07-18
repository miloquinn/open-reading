import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_custom_theme.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/reader_custom_themes_page.dart';

void main() {
  testWidgets('custom theme library exposes selection, editing, and reordering',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    const themes = [
      ReaderCustomTheme(
        id: 'custom:first',
        name: 'Rain',
        background: Color(0xFF102030),
        text: Color(0xFFF0E0D0),
        controlBar: Color(0xFF203040),
      ),
      ReaderCustomTheme(
        id: 'custom:second',
        name: 'Paper',
        background: Color(0xFFF4EBD8),
        text: Color(0xFF30271F),
        controlBar: Color(0xFFE1D0B4),
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReaderCustomThemesPage(
          initialThemes: themes,
          initialSelectedThemeId: 'custom:first',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Rain'), findsOne);
    expect(find.text('Paper'), findsOne);
    expect(find.byKey(const ValueKey('add-custom-reader-theme')), findsOne);
    expect(find.byKey(const ValueKey('use-selected-custom-reader-theme')),
        findsOne);

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(0, 1);
    await tester.pump();

    final stored = await const ReaderCustomThemeStore().loadAll();
    expect(stored.map((theme) => theme.id), ['custom:second', 'custom:first']);
  });
}

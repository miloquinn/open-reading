import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/book_source_management_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('imports and displays a scanned Legado source', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 1100);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookSourceManagementPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('legadoImportButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('legadoJsonField')),
      _sourceJson,
    );
    final dialog = find.byType(AlertDialog);
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, 'Import Legado'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Imported source'), findsOneWidget);
    expect(find.text('Lite compatible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _sourceJson = '''
{
  "bookSourceUrl": "https://example.org",
  "bookSourceName": "Imported source",
  "searchUrl": "https://example.org/search?q={key}",
  "ruleSearch": {"bookList": ".book"},
  "ruleBookInfo": {"name": "h1@text"},
  "ruleToc": {"chapterList": ".chapter"},
  "ruleContent": {"content": ".content@html"}
}
''';

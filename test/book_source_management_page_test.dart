import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/services/book_source_registry.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/book_source_management_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('keeps native ORSP source management available', (tester) async {
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

    expect(await BookSourceRegistry().load(), isEmpty);
    expect(find.text('Manage sources'), findsOneWidget);
    expect(find.text('Connected sources'), findsOneWidget);
    expect(find.text('Add source'), findsOneWidget);
    expect(find.text('Open Reading Source Protocol'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding a source requires explicit third-party acknowledgment',
      (tester) async {
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

    await tester.tap(find.widgetWithText(FilledButton, 'Add source'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('OpenReading includes no sources'),
      findsOneWidget,
    );
    FilledButton connectButton() => tester.widget<FilledButton>(
          find.byKey(const Key('bookSourceConnectButton')),
        );
    expect(connectButton().onPressed, isNull);

    await tester.tap(find.byKey(const Key('bookSourceResponsibilityCheckbox')));
    await tester.pump();

    expect(connectButton().onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

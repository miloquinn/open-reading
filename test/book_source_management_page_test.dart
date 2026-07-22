import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/services/book_source_registry.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/book_sources/book_source_management_page.dart';

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

  testWidgets('keeps dense source metadata readable on narrow phones', (
    tester,
  ) async {
    await BookSourceRegistry().upsert(
      RegisteredBookSource(
        id: 'org.example.long-source',
        name: 'A deliberately long connected source name',
        description:
            'A long source description that still needs useful reading width.',
        manifestUrl: Uri.parse('https://example.org/source.json'),
        apiBaseUrl: Uri.parse('https://example.org/api/'),
        protocolVersion: '1.4',
        languages: const ['en'],
        capabilities: const {
          'browse',
          'catalog',
          'categories',
          'content',
          'detail',
          'discover',
          'search',
        },
        enabled: true,
        addedAt: DateTime.utc(2026, 7, 22),
      ),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookSourceManagementPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('bookSourceCard-org.example.long-source')),
      findsOneWidget,
    );
    expect(
      find.text('A deliberately long connected source name'),
      findsOneWidget,
    );
    expect(find.text('categories'), findsOneWidget);
    expect(find.text('Enabled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding a source requires explicit third-party acknowledgment', (
    tester,
  ) async {
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
    expect(find.textContaining('bypass sign-in, payment, DRM'), findsOneWidget);
    FilledButton connectButton() => tester.widget<FilledButton>(
      find.byKey(const Key('bookSourceConnectButton')),
    );
    expect(connectButton().onPressed, isNull);

    await tester.tap(find.byKey(const Key('bookSourceResponsibilityCheckbox')));
    await tester.pump();

    expect(connectButton().onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows operator-supplied rights metadata as unverified', (
    tester,
  ) async {
    await BookSourceRegistry().upsert(
      RegisteredBookSource(
        id: 'org.example.public-books',
        name: 'Example Public Books',
        description: 'Licensed catalog',
        manifestUrl: Uri.parse('https://example.org/source.json'),
        apiBaseUrl: Uri.parse('https://example.org/api/'),
        protocolVersion: '1.2',
        languages: const ['en'],
        capabilities: const {'search', 'content'},
        operatorName: 'Example Library',
        contactUrl: Uri.parse('https://example.org/contact'),
        contentLicense: 'CC BY 4.0',
        rightsStatement: 'Licensed public catalog.',
        enabled: true,
        addedAt: DateTime.utc(2026, 7, 19),
      ),
    );

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
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Operator and rights'));
    await tester.pumpAndSettle();

    expect(find.text('Example Library'), findsOneWidget);
    expect(find.text('CC BY 4.0'), findsOneWidget);
    expect(find.text('Licensed public catalog.'), findsOneWidget);
    expect(find.textContaining('does not verify or endorse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

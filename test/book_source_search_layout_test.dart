import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/book_sources_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('search controls align on wide layouts and stack on mobile',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BookSourcesPage()),
      ),
    );
    await tester.pumpAndSettle();

    final scope = find.byKey(const Key('bookSourceScopeControl'));
    final query = find.byKey(const Key('bookSourceQueryControl'));
    expect(tester.getSize(scope).height, 56);
    expect(tester.getSize(query).height, 56);
    expect(tester.getTopLeft(scope).dy, tester.getTopLeft(query).dy);

    tester.view.physicalSize = const Size(390, 1000);
    await tester.pumpAndSettle();

    expect(tester.getSize(scope).width, tester.getSize(query).width);
    expect(tester.getTopLeft(query).dy,
        greaterThan(tester.getBottomLeft(scope).dy));
  });

  testWidgets('opens the add-source dialog without dependency errors',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BookSourcesPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_link_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/settings/about/open_source_licenses_page.dart';

void main() {
  testWidgets('shows project, font, and dependency license entries',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OpenSourceLicensesPage(appVersion: '1.1.1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('开源许可'), findsOneWidget);
    expect(find.text('Open Reading'), findsOneWidget);
    expect(find.text('GNU Affero General Public License v3.0'), findsOneWidget);
    expect(find.text('Noto Serif SC / Source Han Serif'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('flutter-package-licenses')),
      300,
    );

    expect(find.text('JetBrains Mono'), findsOneWidget);
    expect(find.text('Flutter 与 Dart 依赖'), findsOneWidget);
  });

  testWidgets('opens bundled font license text offline', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OpenSourceLicensesPage(appVersion: '1.1.1'),
      ),
    );
    await tester.pumpAndSettle();

    final fontEntry = find.byKey(
      const ValueKey('font-license-Noto Serif SC / Source Han Serif'),
    );
    await tester.ensureVisible(fontEntry);
    await tester.tap(fontEntry);
    await tester.pumpAndSettle();

    expect(find.text('Noto Serif SC / Source Han Serif'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data?.contains('SIL OPEN FONT LICENSE') == true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('opens the bundled project license text offline', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OpenSourceLicensesPage(appVersion: '1.1.1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-reading-agpl-license')));
    await tester.pumpAndSettle();

    expect(find.text('Open Reading · AGPL-3.0'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data?.contains('GNU AFFERO GENERAL PUBLIC LICENSE') == true,
      ),
      findsOneWidget,
    );
  });
}

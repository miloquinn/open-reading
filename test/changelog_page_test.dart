import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/settings/about/changelog_page.dart';
import 'package:xxread/services/core/changelog_service.dart';

void main() {
  testWidgets('changelog page renders every entry from the shared asset',
      (tester) async {
    const locale = Locale('zh');
    final entries = await ChangelogService().load(locale);

    await tester.pumpWidget(
      const MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangelogPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(entries, isNotEmpty);
    expect(find.text('版本更新记录'), findsOneWidget);
    expect(find.text('当前版本'), findsOneWidget);
    expect(
      find.byKey(ValueKey('changelog-entry-${entries.first.version}')),
      findsOneWidget,
    );
    expect(find.text(entries.first.items.first), findsOneWidget);

    final lastEntry = entries.last;
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('changelog-entry-${lastEntry.version}')),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(
      find.byKey(ValueKey('changelog-entry-${lastEntry.version}')),
      findsOneWidget,
    );
    expect(find.text(lastEntry.items.last), findsOneWidget);
  });

  testWidgets('changelog page exposes a retry state when loading fails',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangelogPage(service: _FailingChangelogService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load release history'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

class _FailingChangelogService extends ChangelogService {
  @override
  Future<List<ChangelogEntry>> load(Locale locale) {
    return Future.error(const FormatException('invalid test catalog'));
  }
}

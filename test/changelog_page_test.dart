import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/settings/about/changelog_page.dart';
import 'package:xxread/services/core/changelog_service.dart';

void main() {
  testWidgets('changelog page renders the current entry from the shared asset',
      (tester) async {
    const locale = Locale('zh');
    const entries = [
      ChangelogEntry(
        version: '2.3.0',
        items: ['支持 ColorOS 流体云实时展示下载进度'],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangelogPage(service: _StaticChangelogService(entries)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(entries, isNotEmpty);
    expect(find.text('版本更新记录'), findsOneWidget);
    expect(find.text('当前版本'), findsOneWidget);
    expect(
      find.byKey(ValueKey('changelog-entry-${entries.first.version}')),
      findsOneWidget,
    );
    expect(find.text(entries.first.items.first), findsOneWidget);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

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

class _StaticChangelogService extends ChangelogService {
  _StaticChangelogService(this.entries);

  final List<ChangelogEntry> entries;

  @override
  Future<List<ChangelogEntry>> load(Locale locale) async => entries;
}

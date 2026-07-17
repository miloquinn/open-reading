import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/changelog_page.dart';

void main() {
  testWidgets('changelog page shows the current and historical releases',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangelogPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('版本更新记录'), findsOneWidget);
    expect(find.text('v1.2.0'), findsOneWidget);
    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text('优化阅读排版，支持零边距与同页更多文字'), findsOneWidget);
    expect(find.text('接入音量键翻页'), findsOneWidget);
    expect(find.text('完善自定义字体，支持导入与管理'), findsOneWidget);
    expect(find.text('v1.1.0'), findsOneWidget);
    expect(find.text('新增自定义字体'), findsOneWidget);
    expect(find.text('新增加入书签'), findsOneWidget);
    expect(find.text('v1.0.2'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('v0.9.1'),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('v1.0.1'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text('v0.9.1'), findsOneWidget);
  });
}

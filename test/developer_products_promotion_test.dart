import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/widgets/developer_products_promotion.dart';

void main() {
  testWidgets('shows and opens both promoted developer products',
      (tester) async {
    var readingOpens = 0;
    var communityOpens = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DeveloperProductsPromotion(
            onOpenXiaoyuanReading: () => readingOpens += 1,
            onOpenXiaoyuanCommunity: () => communityOpens += 1,
          ),
        ),
      ),
    );

    expect(find.text('小元读书'), findsOneWidget);
    expect(find.text('面向用户的阅读产品，目前仅提供 iOS 版本'), findsOneWidget);
    expect(find.text('xxread.top'), findsOneWidget);
    expect(find.text('小元读书社区'), findsOneWidget);
    expect(find.text('阅读、创作与交流社区'), findsOneWidget);
    expect(find.text('community.xxread.top'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('settings-xiaoyuan-reading-link')),
    );
    await tester.tap(
      find.byKey(const ValueKey('settings-xiaoyuan-community-link')),
    );

    expect(readingOpens, 1);
    expect(communityOpens, 1);
  });
}

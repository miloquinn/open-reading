import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/widgets/developer_support_card.dart';

void main() {
  testWidgets('opens both voluntary donation dialogs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: DeveloperSupportCard(
              onWechatTap: () => showDialog<void>(
                context: context,
                builder: (_) => const DeveloperDonationDialog(
                  method: DeveloperDonationMethod.wechat,
                ),
              ),
              onAlipayTap: () => showDialog<void>(
                context: context,
                builder: (_) => const DeveloperDonationDialog(
                  method: DeveloperDonationMethod.alipay,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('支持持续开发'), findsOneWidget);
    expect(find.text('微信捐赠'), findsOneWidget);
    expect(find.text('支付宝捐赠'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('settings-wechat-donation-link')),
    );
    await tester.pumpAndSettle();

    expect(find.text('微信捐赠'), findsWidgets);
    expect(
        find.byKey(const ValueKey('wechat-donation-qr-image')), findsOneWidget);
    expect(
      find.text('捐赠完全自愿，不影响任何功能，也不构成购买或服务承诺。'),
      findsOneWidget,
    );

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-alipay-donation-link')),
    );
    await tester.pumpAndSettle();

    expect(find.text('支付宝捐赠'), findsWidgets);
    expect(
      find.byKey(const ValueKey('alipay-donation-qr-image')),
      findsOneWidget,
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/pages/settings/settings_page.dart';
import 'package:xxread/services/core/first_home_support_intro_service.dart';
import 'package:xxread/widgets/first_home_support_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('support introduction can only be claimed once', () async {
    const service = FirstHomeSupportIntroService();

    expect(await service.claimIfUnseen(), isTrue);
    expect(await service.claimIfUnseen(), isFalse);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(FirstHomeSupportIntroService.preferenceKey),
      isTrue,
    );
  });

  test('settings controller emits a new request for every reveal', () {
    final controller = SettingsPageController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.revealSupportSection();
    controller.revealSupportSection();

    expect(controller.supportRevealRequest, 2);
    expect(notifications, 2);
  });

  testWidgets('paper unroll reveals support and later actions', (tester) async {
    var supported = false;
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: FirstHomeSupportOverlay(
          supportLabel: '立即支持',
          laterLabel: '再说吧',
          paperSemanticLabel: '支持说明',
          onSupport: () => supported = true,
          onLater: () => dismissed = true,
        ),
      ),
    );

    expect(find.bySemanticsLabel('支持说明'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('first-home-support-now-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('first-home-support-later-button')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(
      find.byKey(const ValueKey('first-home-support-now-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(supported, isTrue);
    expect(dismissed, isFalse);
  });

  testWidgets('reduced motion exposes dismiss action immediately',
      (tester) async {
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: FirstHomeSupportOverlay(
            supportLabel: '立即支持',
            laterLabel: '再说吧',
            paperSemanticLabel: '支持说明',
            onSupport: () {},
            onLater: () => dismissed = true,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('first-home-support-later-button')),
    );
    await tester.pump();

    expect(dismissed, isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/legal/user_agreement_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('updated terms require the current version and source acknowledgment',
      () async {
    expect(UserAgreementService.currentAgreementVersion, '2026-07-19.2');

    SharedPreferences.setMockInitialValues({
      'userAgreementAccepted': true,
      'agreementAcceptedVersion': '2026-07-13.1',
      'thirdPartySourceBoundaryAccepted': true,
    });

    expect(await UserAgreementService.hasUserAcceptedAgreement(), isFalse);

    await UserAgreementService.acceptAgreement(locale: 'en');

    expect(await UserAgreementService.hasUserAcceptedAgreement(), isTrue);
  });

  testWidgets('welcome page requires separate third-party source consent',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.reset);
    var agreed = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UserAgreementPage(onAgreed: () => agreed = true),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('agreementSourceBoundaryCard')), findsOneWidget);
    expect(
      find.textContaining('provides no source addresses'),
      findsOneWidget,
    );
    expect(
      find.textContaining('retained for no more than 30 days'),
      findsOneWidget,
    );

    FilledButton continueButton() => tester.widget<FilledButton>(
          find.byKey(const Key('agreementContinueButton')),
        );

    expect(continueButton().onPressed, isNull);

    await tester.tap(find.byKey(const Key('agreementTermsConsent')));
    await tester.pump();
    expect(continueButton().onPressed, isNull);

    await tester.tap(find.byKey(const Key('agreementSourceConsent')));
    await tester.pump();
    expect(continueButton().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('agreementContinueButton')));
    await tester.pump();

    expect(agreed, isTrue);
    expect(await UserAgreementService.hasUserAcceptedAgreement(), isTrue);
    expect(tester.takeException(), isNull);
  });
}

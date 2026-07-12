import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/services/core/update_check_service.dart';
import 'package:xxread/widgets/update_check_gate.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('manual update check shows release notes and update action',
      (tester) async {
    final service = _FakeUpdateCheckService(
      UpdateCheckResult(
        currentVersion: '0.9.1',
        latestRelease: AppRelease(
          version: '0.10.0',
          name: 'Open Reading v0.10.0',
          notes: 'Added automatic update checks.',
          releaseUrl: Uri.parse(
            'https://github.com/miloquinn/open-reading/releases/tag/v0.10.0',
          ),
          publishedAt: DateTime.utc(2026, 7, 12),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => UpdatePromptController.check(
                context,
                manual: true,
                service: service,
              ),
              child: const Text('Check'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(find.text('A new version is available'), findsOneWidget);
    expect(find.text('Added automatic update checks.'), findsOneWidget);
    expect(find.textContaining('Current version: 0.9.1'), findsOneWidget);
    expect(find.text('Go to update'), findsOneWidget);
  });
}

class _FakeUpdateCheckService extends UpdateCheckService {
  _FakeUpdateCheckService(this.result);

  final UpdateCheckResult result;

  @override
  Future<UpdateCheckResult> check({String? currentVersion}) async => result;
}

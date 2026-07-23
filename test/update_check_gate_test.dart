import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/services/core/update_check_service.dart';
import 'package:xxread/widgets/update_check_gate.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('manual update check shows release notes and update action', (
    tester,
  ) async {
    final service = _FakeUpdateCheckService(
      UpdateCheckResult(
        currentVersion: '0.9.1',
        latestRelease: AppRelease(
          version: '0.10.0',
          name: 'Open Reading v0.10.0',
          notes: '''# Highlights

- Added **automatic update checks**.
- Read the [full notes](https://example.com/releases/0.10.0).''',
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
    expect(
      find.byKey(const ValueKey('release-notes-markdown')),
      findsOneWidget,
    );
    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('full notes'), findsOneWidget);
    expect(find.text('v0.9.1'), findsOneWidget);
    expect(find.text('v0.10.0'), findsOneWidget);
    expect(find.text('Skip this version'), findsOneWidget);
    expect(find.text('Update from GitHub'), findsOneWidget);
    expect(find.text('Download from website'), findsOneWidget);
  });

  testWidgets('later keeps reminding while skip suppresses the same version', (
    tester,
  ) async {
    final service = _FakeUpdateCheckService(
      UpdateCheckResult(
        currentVersion: '1.0.0',
        latestRelease: AppRelease(
          version: '2.0.0',
          name: 'Open Reading v2.0.0',
          notes: 'A safer updater.',
          releaseUrl: Uri.parse(
            'https://github.com/miloquinn/open-reading/releases/tag/v2.0.0',
          ),
          publishedAt: DateTime.utc(2026, 7, 19),
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
              onPressed: () =>
                  UpdatePromptController.check(context, service: service),
              child: const Text('Check automatically'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Check automatically'));
    await tester.pumpAndSettle();
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('skipped_update_version'), isNull);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('skipped_update_version'), isNull);

    await tester.tap(find.text('Check automatically'));
    await tester.pumpAndSettle();
    expect(find.text('A new version is available'), findsOneWidget);

    await tester.tap(find.text('Skip this version'));
    await tester.pumpAndSettle();
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('skipped_update_version'), '2.0.0');

    await tester.tap(find.text('Check automatically'));
    await tester.pumpAndSettle();
    expect(find.text('A new version is available'), findsNothing);
  });

  testWidgets('manual checks ignore a skipped version', (tester) async {
    SharedPreferences.setMockInitialValues({'skipped_update_version': '2.0.0'});
    final service = _FakeUpdateCheckService(
      UpdateCheckResult(
        currentVersion: '1.0.0',
        latestRelease: AppRelease(
          version: '2.0.0',
          name: 'Open Reading v2.0.0',
          notes: 'Still available when checked manually.',
          releaseUrl: Uri.parse(
            'https://github.com/miloquinn/open-reading/releases/tag/v2.0.0',
          ),
          publishedAt: DateTime.utc(2026, 7, 19),
        ),
      ),
    );

    await tester.pumpWidget(
      _UpdateCheckTestApp(service: service, manual: true),
    );
    await tester.tap(find.text('Check updates'));
    await tester.pumpAndSettle();

    expect(find.text('A new version is available'), findsOneWidget);
  });

  testWidgets('a skipped older version does not suppress a newer release', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'skipped_update_version': '2.0.0'});
    final service = _FakeUpdateCheckService(
      UpdateCheckResult(
        currentVersion: '1.0.0',
        latestRelease: AppRelease(
          version: '2.1.0',
          name: 'Open Reading v2.1.0',
          notes: 'A newer release.',
          releaseUrl: Uri.parse(
            'https://github.com/miloquinn/open-reading/releases/tag/v2.1.0',
          ),
          publishedAt: DateTime.utc(2026, 7, 20),
        ),
      ),
    );

    await tester.pumpWidget(_UpdateCheckTestApp(service: service));
    await tester.tap(find.text('Check updates'));
    await tester.pumpAndSettle();

    expect(find.text('v2.1.0'), findsOneWidget);
  });

  testWidgets('update dialog fits a compact phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _FakeUpdateCheckService(
      UpdateCheckResult(
        currentVersion: '1.0.0',
        latestRelease: AppRelease(
          version: '2.0.0',
          name: 'Open Reading v2.0.0',
          notes: List.filled(
            8,
            '- A detailed Markdown release-note item.',
          ).join('\n'),
          releaseUrl: Uri.parse(
            'https://github.com/miloquinn/open-reading/releases/tag/v2.0.0',
          ),
          publishedAt: DateTime.utc(2026, 7, 19),
        ),
      ),
    );

    await tester.pumpWidget(
      _UpdateCheckTestApp(service: service, manual: true),
    );
    await tester.tap(find.text('Check updates'));
    await tester.pumpAndSettle();

    expect(find.text('Skip this version'), findsOneWidget);
    expect(find.text('Download from website'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _UpdateCheckTestApp extends StatelessWidget {
  const _UpdateCheckTestApp({required this.service, this.manual = false});

  final UpdateCheckService service;
  final bool manual;

  @override
  Widget build(BuildContext context) => MaterialApp(
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
            manual: manual,
            service: service,
          ),
          child: const Text('Check updates'),
        ),
      ),
    ),
  );
}

class _FakeUpdateCheckService extends UpdateCheckService {
  _FakeUpdateCheckService(this.result);

  final UpdateCheckResult result;

  @override
  Future<UpdateCheckResult> check({String? currentVersion}) async => result;
}

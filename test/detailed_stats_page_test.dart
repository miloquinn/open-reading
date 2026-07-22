import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/reading_stats/detailed_stats_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });

  testWidgets('reading stats tabs render without mobile overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF1976D2),
          fontFamily: 'SourceHanSerifCN',
        ),
        home: const DetailedStatsPage(),
      ),
    );

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('详细统计'), findsOneWidget);
    expect(find.text('总览'), findsOneWidget);
    expect(find.text('阅读总览'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final pageTitle in ['阅读趋势分析', '书籍数量', '阅读成就']) {
      await tester.fling(find.byType(PageView), const Offset(-360, 0), 1000);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text(pageTitle), findsWidgets);
      expect(tester.takeException(), isNull);
    }

    for (var i = 0; i < 3; i++) {
      await tester.fling(find.byType(PageView), const Offset(360, 0), 1000);
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(find.text('阅读总览'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/home/home_mobile_dashboard_page.dart';
import 'package:xxread/services/books/book_services.dart';
import 'package:xxread/services/reading/reading_stats_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory databaseDirectory;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseDirectory = await Directory.systemTemp.createTemp(
      'open-reading-home-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => databaseDirectory.path,
        );
    final bookDao = BookDao();
    final statsDao = ReadingStatsDao();
    final books = [
      Book(
        title: '百年孤独',
        author: '加西亚·马尔克斯',
        filePath: '${databaseDirectory.path}/one.epub',
        format: 'epub',
        currentPage: 128,
        totalPages: 320,
      ),
      Book(
        title: '瓦尔登湖',
        author: '亨利·戴维·梭罗',
        filePath: '${databaseDirectory.path}/two.epub',
        format: 'epub',
        currentPage: 42,
        totalPages: 210,
      ),
      Book(
        title: '人类群星闪耀时',
        author: '斯蒂芬·茨威格',
        filePath: '${databaseDirectory.path}/three.epub',
        format: 'epub',
        currentPage: 76,
        totalPages: 190,
      ),
    ];

    for (var index = 0; index < books.length; index++) {
      final bookId = await bookDao.insertBook(books[index]);
      final end = DateTime.now().subtract(Duration(days: index));
      await statsDao.recordReadingSession(
        startTime: end.subtract(Duration(minutes: 18 + index * 7)),
        endTime: end,
        bookId: bookId,
        pagesRead: 12,
      );
    }
  });

  testWidgets('首页只保留继续阅读、阅读节奏和最近阅读', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget buildApp(Size size) {
      return MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF356C88),
        ),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: const Scaffold(body: HomeMobileDashboardPage()),
        ),
      );
    }

    await tester.pumpWidget(buildApp(const Size(320, 740)));

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-continue-reading-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-reading-rhythm-card')),
      findsOneWidget,
    );
    expect(find.text('最近阅读'), findsOneWidget);
    expect(find.text('今日阅读计划'), findsNothing);
    expect(find.textContaining('AI'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(buildApp(const Size(1280, 800)));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('今日阅读计划'), findsNothing);
    expect(find.textContaining('AI'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

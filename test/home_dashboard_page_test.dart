import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/home/home_mobile_dashboard_page.dart';
import 'package:xxread/pages/reader/book_source_reader_page.dart';
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

  testWidgets('首页收到刷新信号后自动显示新阅读内容', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = HomeDashboardController();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: HomeMobileDashboardPage(controller: controller)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final bookId = await BookDao().insertBook(
        Book(
          title: '自动刷新测试书',
          author: '测试作者',
          filePath: '${databaseDirectory.path}/auto-refresh.epub',
          format: 'epub',
          currentPage: 8,
          totalPages: 100,
        ),
      );
      final end = DateTime.now();
      await ReadingStatsDao().recordReadingSession(
        startTime: end.subtract(const Duration(minutes: 5)),
        endTime: end,
        bookId: bookId,
        pagesRead: 8,
      );
    });

    controller.refresh();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();

    expect(find.text('自动刷新测试书'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  test('首页继续阅读会把在线书籍交给书源阅读器', () {
    const sourceBook = BookSourceBook(
      id: 'online-book',
      title: '在线测试书',
      author: '测试作者',
      description: '',
      categories: [],
    );
    final source = RegisteredBookSource(
      id: 'test.source',
      name: '测试书源',
      description: '',
      manifestUrl: Uri.parse('https://example.org/source.json'),
      apiBaseUrl: Uri.parse('https://example.org/api/'),
      protocolVersion: '1.0',
      languages: const ['zh-CN'],
      capabilities: const {'search', 'catalog', 'content'},
      enabled: true,
      addedAt: DateTime.utc(2026, 7, 23),
    );
    final book = Book(
      title: sourceBook.title,
      author: sourceBook.author,
      filePath: '',
      format: 'source',
      storageType: 'online',
      sourceId: source.id,
      sourceBookId: sourceBook.id,
      sourceJson: jsonEncode(source.toJson()),
      sourceBookJson: jsonEncode(sourceBook.toJson()),
    );
    final client = BookSourceClient();
    final shelfService = BookSourceShelfService(client: client);

    final reader = HomeMobileDashboardPage.buildOnlineReader(
      book: book,
      client: client,
      shelfService: shelfService,
    );

    expect(reader, isA<BookSourceReaderPage>());
    final sourceReader = reader! as BookSourceReaderPage;
    expect(sourceReader.source.id, source.id);
    expect(sourceReader.book.id, sourceBook.id);
    expect(sourceReader.client, same(client));
  });
}

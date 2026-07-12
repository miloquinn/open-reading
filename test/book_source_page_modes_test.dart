import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/book_source_reader_page.dart';
import 'package:xxread/widgets/reader_control_chrome.dart';
import 'package:xxread/widgets/reader_settings_controls.dart';

void main() {
  testWidgets('opens a source chapter in horizontal slide mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'native_reader_page_mode': 'horizontalSlide',
    });

    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.byType(PageView));

    expect(find.byType(PageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reading settings expose all four page turning modes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.textContaining('测试正文'));

    tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.tune_rounded),
            matching: find.byType(IconButton),
          ),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('上下滚动'), findsOneWidget);
    expect(find.text('水平分页'), findsOneWidget);
    expect(find.text('左右滑动'), findsOneWidget);
    expect(find.text('仿真翻页'), findsOneWidget);
  });

  testWidgets('restores normalized progress in a paged mode', (tester) async {
    SharedPreferences.setMockInitialValues({
      'native_reader_page_mode': 'instantPage',
      'book_source_reading_progress_v1:page-mode-source:book-1':
          '{"chapterId":"chapter-1","chapterIndex":0,'
              '"chapterProgress":0.6,"updatedAt":"2026-07-12T00:00:00.000Z"}',
    });

    await tester.pumpWidget(_testApp());
    final statusFinder = find.byKey(
      const ValueKey('book-source-reader-status'),
    );
    await _pumpUntilFound(tester, statusFinder);
    await tester.pump(const Duration(milliseconds: 200));

    final status = tester.widget<Text>(statusFinder).data!;
    final fractions = RegExp(r'(\d+)/(\d+)').allMatches(status).toList();
    expect(fractions.length, 2);
    expect(
      int.parse(fractions[1].group(1)!),
      greaterThan(1),
      reason: status,
    );
  });

  testWidgets('line spacing change repaginates the current chapter',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'native_reader_page_mode': 'instantPage',
      'native_reader_line_height': 1.4,
    });
    await tester.pumpWidget(_testApp());
    final statusFinder = find.byKey(
      const ValueKey('book-source-reader-status'),
    );
    await _pumpUntilFound(tester, statusFinder);
    final before = tester.widget<Text>(statusFinder).data!;

    tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.tune_rounded),
            matching: find.byType(IconButton),
          ),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders.length, greaterThanOrEqualTo(2));
    sliders[1].onChanged!(2.1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final after = tester.widget<Text>(statusFinder).data!;
    final beforePages = RegExp(r'(\d+)/(\d+)').allMatches(before).toList();
    final afterPages = RegExp(r'(\d+)/(\d+)').allMatches(after).toList();
    expect(beforePages.length, 2);
    expect(afterPages.length, 2);
    expect(
      int.parse(afterPages[1].group(2)!),
      greaterThan(int.parse(beforePages[1].group(2)!)),
    );
  });

  testWidgets('day reader settings stay light under system dark mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'native_reader_theme': 'day',
    });
    await tester.pumpWidget(_testApp(darkMode: true));
    await _pumpUntilFound(tester, find.textContaining('娴嬭瘯姝ｆ枃'));

    tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.tune_rounded),
            matching: find.byType(IconButton),
          ),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    final frame = tester.widget<ReaderSettingsSheetFrame>(
      find.byType(ReaderSettingsSheetFrame),
    );
    expect(frame.palette.id, 'day');
    expect(frame.palette.brightness, Brightness.light);
  });

  testWidgets('horizontal slide supports left and right tap navigation',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'native_reader_page_mode': 'horizontalSlide',
    });
    await tester.pumpWidget(_testApp());
    final statusFinder = find.byKey(
      const ValueKey('book-source-reader-status'),
    );
    await _pumpUntilFound(tester, statusFinder);
    String currentStatus() => tester.widget<Text>(statusFinder).data!;
    int currentPage() => int.parse(
          RegExp(r'(\d+)/(\d+)')
              .allMatches(currentStatus())
              .toList()[1]
              .group(1)!,
        );
    final initialPage = currentPage();
    final pageTapDetector = tester
        .widgetList<GestureDetector>(
          find.descendant(
            of: find.byType(PageView),
            matching: find.byType(GestureDetector),
          ),
        )
        .firstWhere((detector) => detector.onTapUp != null);

    pageTapDetector.onTapUp!(
      TapUpDetails(
        localPosition: const Offset(760, 100),
        globalPosition: const Offset(760, 100),
        kind: PointerDeviceKind.touch,
      ),
    );
    await tester.pumpAndSettle();
    expect(currentPage(), initialPage + 1);

    pageTapDetector.onTapUp!(
      TapUpDetails(
        localPosition: const Offset(10, 100),
        globalPosition: const Offset(10, 100),
        kind: PointerDeviceKind.touch,
      ),
    );
    await tester.pumpAndSettle();
    expect(currentPage(), initialPage);
  });

  testWidgets('asks to add a directly opened source book on exit',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_testApp(shelfService: _FakeShelfService()));
    await _pumpUntilFound(tester, find.textContaining('测试正文'));

    tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.arrow_back_rounded),
            matching: find.byType(IconButton),
          ),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('加入书架？'), findsOneWidget);
    expect(find.text('加入书架'), findsOneWidget);
  });

  testWidgets('preloads the next chapter without revealing reader controls',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = _TrackingPageModeClient();
    await tester.pumpWidget(_testApp(client: client));
    await _pumpUntilFound(tester, find.textContaining('测试正文'));
    for (var attempt = 0;
        attempt < 20 && !client.requested.contains('chapter-2');
        attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(client.requested, contains('chapter-2'));
    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey('book-source-reader-surface')),
        )
        .onHorizontalDragEnd!(
      DragEndDetails(
        velocity: const Velocity(pixelsPerSecond: Offset(-600, 0)),
        primaryVelocity: -600,
      ),
    );
    await _pumpUntilFound(tester, find.text('第二章'));

    final top = tester.widget<AnimatedPositioned>(
      find.byKey(const ValueKey('book-source-top-controls')),
    );
    final bottom = tester.widget<AnimatedPositioned>(
      find.byKey(const ValueKey('book-source-bottom-controls')),
    );
    expect(top.top, -130);
    expect(bottom.bottom, -110);
  });

  testWidgets(
      'vertical scrolling uses the shared chrome and chapter page status',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'native_reader_page_mode': 'verticalScroll',
    });
    await tester.pumpWidget(_testApp());
    final statusFinder = find.byKey(
      const ValueKey('book-source-reader-status'),
    );
    await _pumpUntilFound(tester, statusFinder);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ReaderControlBar), findsNWidgets(2));
    final status = tester.widget<Text>(statusFinder).data!;
    final fractions = RegExp(r'(\d+)/(\d+)').allMatches(status).toList();
    expect(fractions.length, 2);
    expect(int.parse(fractions[1].group(2)!), greaterThan(1));
  });
}

Widget _testApp({
  BookSourceShelfService? shelfService,
  BookSourceClient? client,
  bool darkMode = false,
}) =>
    MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BookSourceReaderPage(
        source: RegisteredBookSource(
          id: 'page-mode-source',
          name: '测试书源',
          description: '',
          manifestUrl: Uri.parse('https://example.org/source.json'),
          apiBaseUrl: Uri.parse('https://example.org/api/'),
          protocolVersion: '1.0',
          languages: const ['zh-CN'],
          capabilities: const {'catalog', 'content'},
          enabled: true,
          addedAt: DateTime.utc(2026, 7, 12),
        ),
        book: const BookSourceBook(
          id: 'book-1',
          title: '测试书籍',
          author: '作者',
          description: '',
          categories: [],
        ),
        client: client ?? _PageModeClient(),
        shelfService: shelfService,
      ),
    );

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
}

class _PageModeClient extends BookSourceClient {
  @override
  Future<List<BookSourceChapter>> getChapters(
    RegisteredBookSource source,
    String bookId,
  ) async =>
      const [
        BookSourceChapter(id: 'chapter-1', title: '第一章', order: 1),
        BookSourceChapter(id: 'chapter-2', title: '第二章', order: 2),
      ];

  @override
  Future<BookSourceChapterContent> getChapterContent(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async =>
      BookSourceChapterContent(
        bookId: bookId,
        chapterId: chapterId,
        title: chapterId == 'chapter-1' ? '' : '第二章',
        content: List.generate(
          80,
          (index) => '测试正文第$index段，用于验证书源阅读分页模式。',
        ).join('\n'),
        contentType: 'text/plain',
      );
}

class _TrackingPageModeClient extends _PageModeClient {
  final List<String> requested = [];

  @override
  Future<BookSourceChapterContent> getChapterContent(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async {
    requested.add(chapterId);
    return super.getChapterContent(
      source,
      bookId: bookId,
      chapterId: chapterId,
    );
  }
}

class _FakeShelfService extends BookSourceShelfService {
  @override
  Future<Book?> findShelfBook({
    required String sourceId,
    required String sourceBookId,
  }) async =>
      null;

  @override
  Future<Book> addOnline({
    required RegisteredBookSource source,
    required BookSourceBook book,
  }) async =>
      Book(
        id: 1,
        title: book.title,
        filePath: '',
        format: 'source',
        storageType: 'online',
      );

  @override
  Future<void> updateShelfProgress({
    required int shelfBookId,
    required int chapterIndex,
    required int chapterCount,
    required double chapterProgress,
  }) async {}
}

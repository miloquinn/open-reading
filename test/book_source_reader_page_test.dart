import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_reading_progress.dart';
import 'package:xxread/core/reader/reader_margin_settings.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/book_source_reader_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('loads source chapters and navigates to the next chapter',
      (tester) async {
    final source = RegisteredBookSource(
      id: 'example.source',
      name: 'Example',
      description: '',
      manifestUrl: Uri.parse('https://example.org/source.json'),
      apiBaseUrl: Uri.parse('https://example.org/api/'),
      protocolVersion: '1.0',
      languages: const ['zh-CN'],
      capabilities: const {'search', 'catalog', 'content'},
      enabled: true,
      addedAt: DateTime.utc(2026, 7, 12),
    );
    const book = BookSourceBook(
      id: 'book-1',
      title: '测试书籍',
      author: '作者',
      description: '',
      categories: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookSourceReaderPage(
          source: source,
          book: book,
          client: _FakeBookSourceClient(),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.textContaining('第一章正文'));

    expect(find.text('第一章'), findsWidgets);
    expect(find.textContaining('第一章正文'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await _pumpUntilFound(tester, find.textContaining('第二章正文'));

    expect(find.text('第二章'), findsWidgets);
    expect(find.textContaining('第二章正文'), findsOneWidget);
  });

  testWidgets('restores the last source chapter on reopen', (tester) async {
    final source = _testSource();
    const book = BookSourceBook(
      id: 'book-1',
      title: 'Test book',
      author: 'Author',
      description: '',
      categories: [],
    );
    const store = BookSourceReadingProgressStore();
    await store.save(
      sourceId: source.id,
      bookId: book.id,
      progress: BookSourceReadingProgress(
        chapterId: 'chapter-2',
        chapterIndex: 1,
        chapterProgress: 0.35,
        updatedAt: DateTime.utc(2026, 7, 12),
      ),
    );
    final client = _FakeBookSourceClient();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookSourceReaderPage(
          source: source,
          book: book,
          client: client,
          progressStore: store,
        ),
      ),
    );
    for (var attempt = 0;
        attempt < 30 && client.requestedChapterIds.isEmpty;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(client.requestedChapterIds.first, 'chapter-2');
  });

  testWidgets('uses the shared reader settings with independent margins',
      (tester) async {
    final source = _testSource();
    const book = BookSourceBook(
      id: 'book-1',
      title: 'Test book',
      author: 'Author',
      description: '',
      categories: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookSourceReaderPage(
          source: source,
          book: book,
          client: _FakeBookSourceClient(),
        ),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('book-source-reader-surface')),
    );

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final bottomControls = tester.widget<AnimatedPositioned>(
      find.byKey(const ValueKey('book-source-bottom-controls')),
    );
    expect(bottomControls.bottom, 16);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reader-top-margin-slider')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reader-bottom-margin-slider')),
      findsOneWidget,
    );

    final topSlider = find.descendant(
      of: find.byKey(const ValueKey('reader-top-margin-slider')),
      matching: find.byType(Slider),
    );
    await tester.ensureVisible(topSlider);
    await tester.pumpAndSettle();
    await tester.drag(topSlider, const Offset(80, 0));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getDouble(ReaderSettingsStore.topMarginKey),
      isNot(ReaderMarginSettings.defaultTop),
    );
    expect(
      prefs.getDouble(ReaderSettingsStore.bottomMarginKey),
      ReaderMarginSettings.defaultBottom,
    );
  });

  testWidgets('centers paged content with equal horizontal whitespace',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: BookSourcePageMode.instantPage.name,
      ReaderSettingsStore.horizontalMarginKey: 0.0,
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookSourceReaderPage(
          source: _testSource(),
          book: const BookSourceBook(
            id: 'book-1',
            title: 'Test book',
            author: 'Author',
            description: '',
            categories: [],
          ),
          client: _FakeBookSourceClient(),
        ),
      ),
    );
    const contentKey = ValueKey('book-source-reader-page-content');
    await _pumpUntilFound(tester, find.byKey(contentKey));

    final rect = tester.getRect(find.byKey(contentKey));
    expect(rect.width, 760);
    expect(rect.left, closeTo(1200 - rect.right, 0.01));
  });

  testWidgets('uses the light reader theme for status bar icon contrast',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.themeKey: 'day',
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookSourceReaderPage(
          source: _testSource(),
          book: const BookSourceBook(
            id: 'book-1',
            title: 'Test book',
            author: 'Author',
            description: '',
            categories: [],
          ),
          client: _FakeBookSourceClient(),
        ),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('reader-system-ui-region')),
    );

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byKey(const ValueKey('reader-system-ui-region')),
    );
    expect(region.value.statusBarIconBrightness, Brightness.dark);
    expect(region.value.statusBarBrightness, Brightness.light);
  });

  testWidgets('uses the dark reader theme for status bar icon contrast',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.themeKey: 'night',
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookSourceReaderPage(
          source: _testSource(),
          book: const BookSourceBook(
            id: 'book-1',
            title: 'Test book',
            author: 'Author',
            description: '',
            categories: [],
          ),
          client: _FakeBookSourceClient(),
        ),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('reader-system-ui-region')),
    );

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byKey(const ValueKey('reader-system-ui-region')),
    );
    expect(region.value.statusBarIconBrightness, Brightness.light);
    expect(region.value.statusBarBrightness, Brightness.dark);
  });
}

RegisteredBookSource _testSource() => RegisteredBookSource(
      id: 'example.source',
      name: 'Example',
      description: '',
      manifestUrl: Uri.parse('https://example.org/source.json'),
      apiBaseUrl: Uri.parse('https://example.org/api/'),
      protocolVersion: '1.0',
      languages: const ['zh-CN'],
      capabilities: const {'search', 'catalog', 'content'},
      enabled: true,
      addedAt: DateTime.utc(2026, 7, 12),
    );

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
}

class _FakeBookSourceClient extends BookSourceClient {
  final List<String> requestedChapterIds = [];

  @override
  Future<List<BookSourceChapter>> getChapters(
    RegisteredBookSource source,
    String bookId,
  ) async {
    return const [
      BookSourceChapter(id: 'chapter-1', title: '第一章', order: 1),
      BookSourceChapter(id: 'chapter-2', title: '第二章', order: 2),
    ];
  }

  @override
  Future<BookSourceChapterContent> getChapterContent(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async {
    requestedChapterIds.add(chapterId);
    final second = chapterId == 'chapter-2';
    return BookSourceChapterContent(
      bookId: bookId,
      chapterId: chapterId,
      title: second ? '第二章' : '',
      content: second ? '第二章正文' : '第一章正文',
      contentType: 'text/plain',
    );
  }
}

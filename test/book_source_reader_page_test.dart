import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_reading_progress.dart';
import 'package:xxread/core/reader/reader_page_turn_geometry.dart';
import 'package:xxread/core/reader/reader_margin_settings.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/book_source_reader_page.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';
import 'package:xxread/widgets/reader_shader_page_curl.dart';

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

    await tester.fling(
      find.byKey(const ValueKey('book-source-reader-surface')),
      const Offset(-500, 0),
      1000,
    );
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

  for (final mode in [
    BookSourcePageMode.verticalScroll,
    BookSourcePageMode.instantPage,
  ]) {
    testWidgets('justifies source body text in ${mode.name} mode',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        ReaderSettingsStore.pageModeKey: mode.name,
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
      final bodyFinder = find.textContaining('第一章正文');
      await _pumpUntilFound(tester, bodyFinder);

      expect(tester.widget<Text>(bodyFinder).textAlign, TextAlign.justify);
    });
  }

  testWidgets('vertical source pages are clipped to one fixed reading window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: BookSourcePageMode.verticalScroll.name,
    });
    try {
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
      final windowFinder = find.byKey(
        const ValueKey('book-source-vertical-reading-window'),
      );
      await _pumpUntilFound(tester, windowFinder);

      final window = tester.widget<Padding>(windowFinder);
      final windowPadding = window.padding.resolve(TextDirection.ltr);
      final listRect = tester.getRect(find.byType(ScrollablePositionedList));
      expect(windowPadding.vertical, greaterThan(0));
      expect(listRect.top, closeTo(windowPadding.top, 0.1));
      expect(listRect.bottom, closeTo(800 - windowPadding.bottom, 0.1));

      final pageCells = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>)
                .value
                .startsWith('book-source-vertical-page:'),
      );
      expect(pageCells, findsWidgets);
      expect(
        tester.widget<SizedBox>(pageCells.first).height,
        closeTo(listRect.height, 0.1),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets(
      'tablet source page curl uses two leaves and a fixed center spine',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: BookSourcePageMode.pageCurl.name,
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BookSourceReaderPage(
            source: _testSource(),
            book: const BookSourceBook(
              id: 'book-1',
              title: 'Tablet source book',
              author: 'Author',
              description: '',
              categories: [],
            ),
            client: _LongFakeBookSourceClient(),
          ),
        ),
      );
      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(ReaderShaderPageCurl).evaluate().length >= 2) break;
      }

      final curlFinder = find.byType(ReaderShaderPageCurl);
      expect(curlFinder, findsNWidgets(2));
      final curls =
          tester.widgetList<ReaderShaderPageCurl>(curlFinder).toList();
      expect(curls.every((curl) => curl.edgeDragOnly), isTrue);
      expect(curls[0].bindingEdge, ReaderPageBindingEdge.right);
      expect(curls[1].bindingEdge, ReaderPageBindingEdge.left);

      final rects = curlFinder
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .toList()
        ..sort((left, right) => left.left.compareTo(right.left));
      expect(rects[0].right, closeTo(588, 0.1));
      expect(rects[1].left, closeTo(612, 0.1));

      final rightController = curls[1].controller!;
      final gesture = await tester.startGesture(
        Offset(rects[1].right - 2, rects[1].center.dy),
      );
      await gesture.moveBy(const Offset(-90, -45));
      await tester.pump();
      expect(rightController.debugMotion, ReaderPageTurnMotion.outgoing);
      expect(rightController.debugActiveSourceIsCurrent, isTrue);
      await gesture.cancel();
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets(
      'tablet spread progress tracks the last visible page and restores its left page',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: BookSourcePageMode.pageCurl.name,
    });
    const store = BookSourceReadingProgressStore();
    final content = _tabletChapterText(360);
    try {
      await tester.pumpWidget(
        _buildTabletSourceReader(
          _ConfigurableBookSourceClient({'chapter-1': content}),
          progressStore: store,
        ),
      );
      await _pumpUntilTabletCurls(tester);

      var rightCurl = _spreadCurl(tester, ReaderPageBindingEdge.left);
      expect(rightCurl.forwardPage, isNotNull);
      await rightCurl.onTurnForward();
      await tester.pump();

      rightCurl = _spreadCurl(tester, ReaderPageBindingEdge.left);
      final rightLeaf = rightCurl.currentPage.child as ReaderPaperPageLeaf;
      expect(rightLeaf.metadata.pageNumber, greaterThan(2));
      final expectedProgress = (rightLeaf.metadata.pageNumber - 1) /
          (rightLeaf.metadata.pageCount - 1);

      BookSourceReadingProgress? saved;
      for (var attempt = 0; attempt < 10 && saved == null; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        saved = await store.load(
          sourceId: _testSource().id,
          bookId: 'book-1',
        );
      }
      expect(saved, isNotNull);
      expect(saved!.chapterProgress, closeTo(expectedProgress, 0.000001));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        _buildTabletSourceReader(
          _ConfigurableBookSourceClient({'chapter-1': content}),
          progressStore: store,
        ),
      );
      await _pumpUntilTabletCurls(tester);

      final restoredLeft = _spreadCurl(
        tester,
        ReaderPageBindingEdge.right,
      ).currentPage.child as ReaderPaperPageLeaf;
      final restoredIndex = restoredLeft.metadata.pageNumber - 1;
      final expectedRestoredIndex =
          (((restoredLeft.metadata.pageCount - 1) * saved.chapterProgress)
                      .round() ~/
                  2) *
              2;
      expect(restoredIndex, expectedRestoredIndex);
      expect(restoredIndex.isEven, isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets(
      'tablet forward chapter curl uses prefetched page one at half-page width without refetching',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: BookSourcePageMode.pageCurl.name,
    });
    const store = BookSourceReadingProgressStore();
    await store.save(
      sourceId: _testSource().id,
      bookId: 'book-1',
      progress: BookSourceReadingProgress(
        chapterId: 'chapter-1',
        chapterIndex: 0,
        chapterProgress: 1,
        updatedAt: DateTime.utc(2026, 7, 19),
      ),
    );
    final content = _tabletChapterText(240);
    final client = _ConfigurableBookSourceClient({
      'chapter-1': content,
      'chapter-2': content,
    });
    try {
      await tester.pumpWidget(
        _buildTabletSourceReader(client, progressStore: store),
      );
      final forwardCurl = await _pumpUntilSpreadTarget(
        tester,
        bindingEdge: ReaderPageBindingEdge.left,
        forward: true,
        pageIdentity: (identity) => identity.contains(':chapter-2:1:'),
      );

      final nextLeaf = forwardCurl.forwardPage!.child as ReaderPaperPageLeaf;
      final currentLeft = _spreadCurl(
        tester,
        ReaderPageBindingEdge.right,
      ).currentPage.child as ReaderPaperPageLeaf;
      expect(nextLeaf.metadata.pageNumber, 2);
      expect(nextLeaf.metadata.pageCount, currentLeft.metadata.pageCount);
      expect(
        client.requestedChapterIds.where((id) => id == 'chapter-2').length,
        1,
      );

      await forwardCurl.onTurnForward();
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.pump(const Duration(milliseconds: 50));
        final currentIdentity = _spreadCurl(
          tester,
          ReaderPageBindingEdge.left,
        ).currentPage.key.pageIdentity;
        if (currentIdentity.contains(':chapter-2:1:')) break;
      }
      expect(
        _spreadCurl(tester, ReaderPageBindingEdge.left)
            .currentPage
            .key
            .pageIdentity,
        contains(':chapter-2:1:'),
      );
      expect(
        client.requestedChapterIds.where((id) => id == 'chapter-2').length,
        1,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets(
      'tablet forward chapter curl uses a blank right leaf for a one-page prefetched chapter',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: BookSourcePageMode.pageCurl.name,
    });
    final client = _ConfigurableBookSourceClient(const {
      'chapter-1': 'Short first chapter.',
      'chapter-2': 'Short second chapter.',
    });
    try {
      await tester.pumpWidget(_buildTabletSourceReader(client));
      final forwardCurl = await _pumpUntilSpreadTarget(
        tester,
        bindingEdge: ReaderPageBindingEdge.left,
        forward: true,
        pageIdentity: (identity) =>
            identity.contains('blank:next-chapter-1-right'),
      );

      expect(
        forwardCurl.forwardPage!.key.pageIdentity,
        contains('blank:next-chapter-1-right'),
      );
      expect(
        forwardCurl.forwardPage!.key.pageIdentity,
        isNot(contains('boundary:forward')),
      );
      expect(
        client.requestedChapterIds.where((id) => id == 'chapter-2').length,
        1,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets(
      'tablet backward chapter curl targets the previous final spread left page',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: BookSourcePageMode.pageCurl.name,
    });
    const store = BookSourceReadingProgressStore();
    await store.save(
      sourceId: _testSource().id,
      bookId: 'book-1',
      progress: BookSourceReadingProgress(
        chapterId: 'chapter-2',
        chapterIndex: 1,
        chapterProgress: 0,
        updatedAt: DateTime.utc(2026, 7, 19),
      ),
    );
    final client = _ConfigurableBookSourceClient({
      'chapter-1': _tabletChapterText(300),
      'chapter-2': 'Short current chapter.',
    });
    try {
      await tester.pumpWidget(
        _buildTabletSourceReader(client, progressStore: store),
      );
      final backwardCurl = await _pumpUntilSpreadTarget(
        tester,
        bindingEdge: ReaderPageBindingEdge.right,
        forward: false,
        pageIdentity: (identity) => identity.contains(':chapter-1:'),
      );

      final previousLeaf =
          backwardCurl.backwardPage!.child as ReaderPaperPageLeaf;
      final previousIndex = previousLeaf.metadata.pageNumber - 1;
      final expectedIndex = ((previousLeaf.metadata.pageCount - 1) ~/ 2) * 2;
      expect(previousLeaf.metadata.pageCount, greaterThan(2));
      expect(previousIndex, expectedIndex);
      expect(previousIndex.isEven, isTrue);
      expect(
        client.requestedChapterIds.where((id) => id == 'chapter-1').length,
        1,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    }
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

Widget _buildTabletSourceReader(
  BookSourceClient client, {
  BookSourceReadingProgressStore progressStore =
      const BookSourceReadingProgressStore(),
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BookSourceReaderPage(
        source: _testSource(),
        book: const BookSourceBook(
          id: 'book-1',
          title: 'Tablet source book',
          author: 'Author',
          description: '',
          categories: [],
        ),
        client: client,
        progressStore: progressStore,
      ),
    );

Future<void> _pumpUntilTabletCurls(WidgetTester tester) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(ReaderShaderPageCurl).evaluate().length == 2) return;
  }
  throw TestFailure('Tablet page curl leaves did not appear.');
}

ReaderShaderPageCurl _spreadCurl(
  WidgetTester tester,
  ReaderPageBindingEdge bindingEdge,
) =>
    tester
        .widgetList<ReaderShaderPageCurl>(find.byType(ReaderShaderPageCurl))
        .singleWhere((curl) => curl.bindingEdge == bindingEdge);

Future<ReaderShaderPageCurl> _pumpUntilSpreadTarget(
  WidgetTester tester, {
  required ReaderPageBindingEdge bindingEdge,
  required bool forward,
  required bool Function(String pageIdentity) pageIdentity,
}) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(ReaderShaderPageCurl).evaluate().length != 2) continue;
    final curl = _spreadCurl(tester, bindingEdge);
    final target = forward ? curl.forwardPage : curl.backwardPage;
    if (target != null && pageIdentity(target.key.pageIdentity)) return curl;
  }
  throw TestFailure('Expected tablet page curl target did not appear.');
}

String _tabletChapterText(int paragraphCount) => List.generate(
      paragraphCount,
      (index) => 'Paragraph $index keeps both tablet leaves populated.',
    ).join('\n');

class _ConfigurableBookSourceClient extends BookSourceClient {
  _ConfigurableBookSourceClient(this.contents);

  final Map<String, String> contents;
  final List<String> requestedChapterIds = [];

  @override
  Future<List<BookSourceChapter>> getChapters(
    RegisteredBookSource source,
    String bookId,
  ) async =>
      contents.keys
          .toList()
          .asMap()
          .entries
          .map(
            (entry) => BookSourceChapter(
              id: entry.value,
              title: 'Tablet chapter',
              order: entry.key,
            ),
          )
          .toList();

  @override
  Future<BookSourceChapterContent> getChapterContent(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async {
    requestedChapterIds.add(chapterId);
    return BookSourceChapterContent(
      bookId: bookId,
      chapterId: chapterId,
      title: 'Tablet chapter',
      content: contents[chapterId]!,
      contentType: 'text/plain',
    );
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

class _LongFakeBookSourceClient extends _FakeBookSourceClient {
  @override
  Future<BookSourceChapterContent> getChapterContent(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async {
    requestedChapterIds.add(chapterId);
    return BookSourceChapterContent(
      bookId: bookId,
      chapterId: chapterId,
      title: chapterId == 'chapter-1' ? 'Tablet chapter' : 'Next chapter',
      content: List.generate(
        360,
        (index) => 'Paragraph $index keeps both tablet leaves populated.',
      ).join('\n'),
      contentType: 'text/plain',
    );
  }
}

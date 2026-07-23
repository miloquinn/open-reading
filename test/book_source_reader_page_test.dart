import 'dart:async';

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
import 'package:xxread/pages/reader/book_source_reader_page.dart';
import 'package:xxread/utils/glass_config.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_chapter_title_page.dart';
import 'package:xxread/widgets/reader_opening_loader.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';
import 'package:xxread/widgets/reader_shader_page_curl.dart';
import 'package:xxread/widgets/reader_top_information_bar.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GlassEffectConfig.setDisableAllGlassEffects(false);
  });

  tearDown(() {
    GlassEffectConfig.setDisableAllGlassEffects(false);
  });

  testWidgets(
    'cover opening skips a brief loader and fades directly to content',
    (tester) async {
      final client = _DelayedOpeningBookSourceClient();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BookSourceReaderPage(
            source: _testSource(),
            book: const BookSourceBook(
              id: 'book-1',
              title: 'Opening test',
              author: 'Author',
              description: '',
              categories: [],
            ),
            client: client,
            initialTheme: ReaderThemes.day,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const ValueKey('book-source-reader-loading-placeholder')),
        findsWidgets,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      client.completeCatalog();
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('book-source-reader-content')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('a genuinely slow cover opening crossfades loader into content', (
    tester,
  ) async {
    final client = _DelayedOpeningBookSourceClient();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookSourceReaderPage(
          source: _testSource(),
          book: const BookSourceBook(
            id: 'book-1',
            title: 'Opening test',
            author: 'Author',
            description: '',
            categories: [],
          ),
          client: client,
          initialTheme: ReaderThemes.day,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 660));
    await tester.pump();
    expect(find.byType(ReaderOpeningLoader), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    expect(
      tester
          .widget<AnimatedPositioned>(
            find.byKey(const ValueKey('book-source-top-controls')),
          )
          .top,
      -130,
    );
    await tester.tapAt(tester.getRect(find.byType(ReaderOpeningLoader)).center);
    await tester.pump();
    expect(
      tester
          .widget<AnimatedPositioned>(
            find.byKey(const ValueKey('book-source-top-controls')),
          )
          .top,
      10,
    );
    await tester.pump(const Duration(milliseconds: 300));

    client.completeCatalog();
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('book-source-reader-content')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('loads source chapters and navigates to the next chapter', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: BookSourcePageMode.verticalScroll.name,
    });
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
    final client = _FakeBookSourceClient();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookSourceReaderPage(source: source, book: book, client: client),
      ),
    );
    await _pumpUntilFound(tester, find.text('第一章'));
    expect(find.text('第一章'), findsWidgets);
    expect(find.byType(ReaderChapterTitlePage), findsOneWidget);
    await tester.fling(
      find.byKey(const ValueKey('book-source-reader-surface')),
      const Offset(0, -500),
      1000,
    );
    await tester.pumpAndSettle();
    final firstBody = find.textContaining('第一章正文', findRichText: true);
    await _pumpUntilFound(tester, firstBody);
    expect(firstBody, findsOneWidget);

    for (
      var attempt = 0;
      attempt < 4 && !client.requestedChapterIds.contains('chapter-2');
      attempt++
    ) {
      await tester.fling(
        find.byKey(const ValueKey('book-source-reader-surface')),
        const Offset(0, -500),
        1000,
      );
      await tester.pumpAndSettle();
    }
    expect(client.requestedChapterIds, contains('chapter-2'));
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
    for (
      var attempt = 0;
      attempt < 30 && client.requestedChapterIds.isEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(client.requestedChapterIds.first, 'chapter-2');
  });

  testWidgets('uses the shared reader settings with independent margins', (
    tester,
  ) async {
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
      find.byKey(const ValueKey('source-slide:chapter-1')),
    );
    expect(
      find.byKey(const ValueKey('book-source-vertical-reading-window')),
      findsNothing,
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
    testWidgets('justifies source body text in ${mode.name} mode', (
      tester,
    ) async {
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
      final bodyFinder = find.textContaining('第一章正文', findRichText: true);
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('book-source-reader-surface')),
      );
      if (mode == BookSourcePageMode.verticalScroll) {
        await tester.fling(
          find.byKey(const ValueKey('book-source-reader-surface')),
          const Offset(0, -500),
          1000,
        );
      } else {
        await tester.tapAt(const Offset(760, 300));
      }
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, bodyFinder);

      expect(tester.widget<RichText>(bodyFinder).textAlign, TextAlign.justify);
    });
  }

  testWidgets('vertical source pages are clipped to one fixed reading window', (
    tester,
  ) async {
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
            (widget.key! as ValueKey<String>).value.startsWith(
              'book-source-vertical-page:',
            ),
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
        expect(find.byType(ReaderPageCurlSpread), findsOneWidget);
        final spread = tester.widget<ReaderPageCurlSpread>(
          find.byType(ReaderPageCurlSpread),
        );
        expect(spread.coordinator.gutterWidth, 24);
        final curls = tester
            .widgetList<ReaderShaderPageCurl>(curlFinder)
            .toList();
        expect(curls.every((curl) => curl.edgeDragOnly), isTrue);
        expect(curls[0].bindingEdge, ReaderPageBindingEdge.right);
        expect(curls[1].bindingEdge, ReaderPageBindingEdge.left);
        expect(
          (curls[0].currentPage.child as ReaderPaperPageLeaf)
              .topInformationLayout,
          ReaderTopInformationLayout.spreadLeft,
        );
        expect(
          (curls[1].currentPage.child as ReaderPaperPageLeaf)
              .topInformationLayout,
          ReaderTopInformationLayout.spreadRight,
        );
        final rightCurl = curls[1];
        final currentRightLeaf =
            rightCurl.currentPage.child as ReaderPaperPageLeaf;
        final nextLeftLeaf =
            rightCurl.outgoingBackPage!.child as ReaderPaperPageLeaf;
        final nextRightLeaf =
            rightCurl.forwardPage!.child as ReaderPaperPageLeaf;
        expect(
          nextLeftLeaf.metadata.pageNumber,
          currentRightLeaf.metadata.pageNumber + 1,
        );
        expect(
          nextRightLeaf.metadata.pageNumber,
          nextLeftLeaf.metadata.pageNumber + 1,
        );
        expect(
          nextLeftLeaf.pageNumberPlacement,
          ReaderPageNumberPlacement.bottomLeft,
        );
        expect(
          nextLeftLeaf.topInformationLayout,
          ReaderTopInformationLayout.spreadLeft,
        );
        expect(
          nextRightLeaf.topInformationLayout,
          ReaderTopInformationLayout.spreadRight,
        );

        final rects =
            curlFinder
                .evaluate()
                .map((element) => tester.getRect(find.byWidget(element.widget)))
                .toList()
              ..sort((left, right) => left.left.compareTo(right.left));
        expect(rects[0].right, closeTo(588, 0.1));
        expect(rects[1].left, closeTo(612, 0.1));

        final rightController = rightCurl.controller!;
        final gesture = await tester.startGesture(
          Offset(rects[1].right - 2, rects[1].center.dy),
        );
        await gesture.moveBy(const Offset(-90, -45));
        await tester.pump();
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump();
        expect(rightController.debugMotion, ReaderPageTurnMotion.outgoing);
        expect(rightController.debugActiveSourceIsCurrent, isTrue);
        expect(
          spread.coordinator.activeBindingEdge,
          ReaderPageBindingEdge.left,
        );
        await gesture.cancel();
        for (var frame = 0; frame < 24; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets('tablet source reader can disable the two-page layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.pageModeKey: BookSourcePageMode.pageCurl.name,
      ReaderSettingsStore.tabletTwoPageKey: false,
    });
    try {
      await tester.pumpWidget(
        _buildTabletSourceReader(_LongFakeBookSourceClient()),
      );
      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(ReaderShaderPageCurl).evaluate().isNotEmpty) break;
      }

      expect(find.byType(ReaderShaderPageCurl), findsOneWidget);
      expect(find.byType(ReaderPageCurlSpread), findsNothing);
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
        final expectedProgress =
            (rightLeaf.metadata.pageNumber - 1) /
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

        final restoredLeft =
            _spreadCurl(tester, ReaderPageBindingEdge.right).currentPage.child
                as ReaderPaperPageLeaf;
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
    },
  );

  testWidgets(
    'next chapter preview is ready even while a farther prefetch is pending',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      SharedPreferences.setMockInitialValues({
        ReaderSettingsStore.pageModeKey: BookSourcePageMode.pageCurl.name,
      });
      final client = _DelayedThirdChapterClient();
      try {
        await tester.pumpWidget(_buildTabletSourceReader(client));
        final forwardCurl = await _pumpUntilSpreadTarget(
          tester,
          bindingEdge: ReaderPageBindingEdge.left,
          forward: true,
          pageIdentity: (identity) => identity.contains(':chapter-2:1:'),
        );

        expect(forwardCurl.forwardPage, isNotNull);
        expect(client.requestedChapterIds, contains('chapter-3'));
        expect(client.thirdChapterCompleted, isFalse);
      } finally {
        client.completeThirdChapter();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets(
    'prefetched chapter turn does not wait for progress persistence',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      SharedPreferences.setMockInitialValues({
        ReaderSettingsStore.pageModeKey: BookSourcePageMode.pageCurl.name,
      });
      final store = _BlockingProgressStore();
      final client = _ConfigurableBookSourceClient({
        'chapter-1': 'Short first chapter.',
        'chapter-2': _tabletChapterText(240),
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

        final turn = Future<void>.sync(forwardCurl.onTurnForward);
        await tester.pump();

        expect(store.saveStarted, isTrue);
        expect(store.saveCompleted, isFalse);
        expect(
          _spreadCurl(
            tester,
            ReaderPageBindingEdge.left,
          ).currentPage.key.pageIdentity,
          contains(':chapter-2:1:'),
        );

        store.completeSave();
        await turn;
      } finally {
        store.completeSave();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets(
    'horizontal slide commits a prefetched chapter only after the animation settles',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 700));
      SharedPreferences.setMockInitialValues({
        ReaderSettingsStore.pageModeKey:
            BookSourcePageMode.horizontalSlide.name,
      });
      final store = _BlockingProgressStore();
      final client = _ConfigurableBookSourceClient(const {
        'chapter-1': 'Short first chapter.',
        'chapter-2': 'Short second chapter.',
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
                title: 'Horizontal source book',
                author: 'Author',
                description: '',
                categories: [],
              ),
              client: client,
              progressStore: store,
            ),
          ),
        );
        await _pumpUntilFound(
          tester,
          find.byKey(const ValueKey('source-slide:chapter-1')),
        );
        for (
          var attempt = 0;
          attempt < 30 && !client.requestedChapterIds.contains('chapter-2');
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        var pageView = tester.widget<PageView>(find.byType(PageView));
        final controller = pageView.controller!;
        controller.jumpToPage(1);
        await tester.pump();

        unawaited(
          controller.nextPage(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          ),
        );
        await tester.pump(const Duration(milliseconds: 180));

        expect(
          find.byKey(const ValueKey('source-slide:chapter-1')),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 160));
        await _pumpUntilFound(
          tester,
          find.byKey(const ValueKey('source-slide:chapter-2')),
        );

        expect(store.saveStarted, isTrue);
        expect(store.saveCompleted, isFalse);
        expect(
          client.requestedChapterIds.where((id) => id == 'chapter-2').length,
          1,
        );
        pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.key, const ValueKey('source-slide:chapter-2'));
        final chapterTwoController = pageView.controller!;
        expect(chapterTwoController.page, 2);

        final forward = chapterTwoController.nextPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
        await tester.pumpAndSettle();
        await forward;
        expect(chapterTwoController.page, 3);

        final backward = chapterTwoController.previousPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
        await tester.pumpAndSettle();
        await backward;
        expect(chapterTwoController.page, 2);

        final previousChapter = chapterTwoController.previousPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
        await tester.pumpAndSettle();
        await previousChapter;
        await _pumpUntilFound(
          tester,
          find.byKey(const ValueKey('source-slide:chapter-1')),
        );

        final chapterOneController = tester
            .widget<PageView>(find.byType(PageView))
            .controller!;
        expect(chapterOneController.page, 1);
        final earlierPage = chapterOneController.previousPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
        await tester.pumpAndSettle();
        await earlierPage;
        expect(chapterOneController.page, 0);
      } finally {
        store.completeSave();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets(
    'horizontal slide lets a new drag take over a cross-chapter settle',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 700));
      SharedPreferences.setMockInitialValues({
        ReaderSettingsStore.pageModeKey:
            BookSourcePageMode.horizontalSlide.name,
      });
      final client = _ConfigurableBookSourceClient(const {
        'chapter-1': 'Short first chapter.',
        'chapter-2': 'Short second chapter.',
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
                title: 'Interrupted horizontal source book',
                author: 'Author',
                description: '',
                categories: [],
              ),
              client: client,
            ),
          ),
        );
        await _pumpUntilFound(
          tester,
          find.byKey(const ValueKey('source-slide:chapter-1')),
        );
        for (
          var attempt = 0;
          attempt < 30 && !client.requestedChapterIds.contains('chapter-2');
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        final controller = tester
            .widget<PageView>(find.byType(PageView))
            .controller!;
        controller.jumpToPage(1);
        await tester.pump();
        unawaited(
          controller.nextPage(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(controller.page, greaterThan(1.5));
        final interruptedPage = controller.page!;

        final drag = await tester.startGesture(
          tester.getRect(find.byType(PageView)).center,
        );
        await drag.moveBy(const Offset(360, 0));
        await tester.pump();

        expect(controller.page, lessThan(interruptedPage));
        expect(
          find.byKey(const ValueKey('source-slide:chapter-1')),
          findsOneWidget,
        );

        await drag.up();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('source-slide:chapter-1')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

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
        final nextBackLeaf =
            forwardCurl.outgoingBackPage!.child as ReaderPaperPageLeaf;
        final currentLeft =
            _spreadCurl(tester, ReaderPageBindingEdge.right).currentPage.child
                as ReaderPaperPageLeaf;
        expect(nextBackLeaf.metadata.pageNumber, 1);
        expect(
          nextBackLeaf.topInformationLayout,
          ReaderTopInformationLayout.spreadLeft,
        );
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
          _spreadCurl(
            tester,
            ReaderPageBindingEdge.left,
          ).currentPage.key.pageIdentity,
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
    },
  );

  testWidgets(
    'tablet forward chapter curl previews title and body leaves for a short chapter',
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
          pageIdentity: (identity) => identity.contains(':chapter-2:1:'),
        );

        expect(
          forwardCurl.forwardPage!.key.pageIdentity,
          contains(':chapter-2:1:'),
        );
        expect(
          forwardCurl.outgoingBackPage!.key.pageIdentity,
          contains(':chapter-2:0:'),
        );
        expect(
          forwardCurl.forwardPage!.key.pageIdentity,
          isNot(contains('blank:')),
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
    },
  );

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
        final previousBackLeaf =
            backwardCurl.outgoingBackPage!.child as ReaderPaperPageLeaf;
        final previousIndex = previousLeaf.metadata.pageNumber - 1;
        final expectedIndex = ((previousLeaf.metadata.pageCount - 1) ~/ 2) * 2;
        expect(previousLeaf.metadata.pageCount, greaterThan(2));
        expect(previousIndex, expectedIndex);
        expect(previousIndex.isEven, isTrue);
        expect(
          previousBackLeaf.topInformationLayout,
          ReaderTopInformationLayout.spreadRight,
        );
        if (previousIndex + 1 < previousLeaf.metadata.pageCount) {
          expect(previousBackLeaf.showPageNumber, isTrue);
          expect(
            previousBackLeaf.metadata.pageNumber,
            previousLeaf.metadata.pageNumber + 1,
          );
        } else {
          expect(previousBackLeaf.showPageNumber, isFalse);
        }
        expect(
          client.requestedChapterIds.where((id) => id == 'chapter-1').length,
          1,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets('uses the light reader theme for status bar icon contrast', (
    tester,
  ) async {
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

  testWidgets('uses the dark reader theme for status bar icon contrast', (
    tester,
  ) async {
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

  testWidgets(
    'system reader theme uses a solid pure-black status bar without glass',
    (tester) async {
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      GlassEffectConfig.setDisableAllGlassEffects(true);
      SharedPreferences.setMockInitialValues({
        ReaderSettingsStore.themeKey: ReaderThemes.systemId,
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
      expect(region.value.statusBarColor, ReaderThemes.pureBlack.background);
      expect(
        region.value.systemNavigationBarColor,
        ReaderThemes.pureBlack.background,
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.statusBarBrightness, Brightness.dark);

      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.light;
      await tester.pump();

      final lightRegion = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byKey(const ValueKey('reader-system-ui-region')),
      );
      expect(lightRegion.value.statusBarColor, ReaderThemes.day.background);
      expect(
        lightRegion.value.systemNavigationBarColor,
        ReaderThemes.day.background,
      );
      expect(lightRegion.value.statusBarIconBrightness, Brightness.dark);
      expect(lightRegion.value.statusBarBrightness, Brightness.light);
    },
  );
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
}) => MaterialApp(
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
) => tester
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
  ) async => contents.keys
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

class _DelayedOpeningBookSourceClient extends BookSourceClient {
  final Completer<List<BookSourceChapter>> _catalog = Completer();

  void completeCatalog() {
    if (_catalog.isCompleted) return;
    _catalog.complete(const [
      BookSourceChapter(id: 'chapter-1', title: 'Opening chapter', order: 1),
    ]);
  }

  @override
  Future<List<BookSourceChapter>> getChapters(
    RegisteredBookSource source,
    String bookId,
  ) => _catalog.future;

  @override
  Future<BookSourceChapterContent> getChapterContent(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async {
    return BookSourceChapterContent(
      bookId: bookId,
      chapterId: chapterId,
      title: 'Opening chapter',
      content: 'Opening body',
      contentType: 'text/plain',
    );
  }
}

class _DelayedThirdChapterClient extends BookSourceClient {
  final List<String> requestedChapterIds = [];
  final Completer<BookSourceChapterContent> _thirdChapter = Completer();

  bool get thirdChapterCompleted => _thirdChapter.isCompleted;

  void completeThirdChapter() {
    if (_thirdChapter.isCompleted) return;
    _thirdChapter.complete(
      BookSourceChapterContent(
        bookId: 'book-1',
        chapterId: 'chapter-3',
        title: 'Chapter 3',
        content: _tabletChapterText(240),
        contentType: 'text/plain',
      ),
    );
  }

  @override
  Future<List<BookSourceChapter>> getChapters(
    RegisteredBookSource source,
    String bookId,
  ) async => const [
    BookSourceChapter(id: 'chapter-1', title: 'Chapter 1', order: 1),
    BookSourceChapter(id: 'chapter-2', title: 'Chapter 2', order: 2),
    BookSourceChapter(id: 'chapter-3', title: 'Chapter 3', order: 3),
  ];

  @override
  Future<BookSourceChapterContent> getChapterContent(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async {
    requestedChapterIds.add(chapterId);
    if (chapterId == 'chapter-3') return _thirdChapter.future;
    return BookSourceChapterContent(
      bookId: bookId,
      chapterId: chapterId,
      title: chapterId == 'chapter-1' ? 'Chapter 1' : 'Chapter 2',
      content: chapterId == 'chapter-1'
          ? 'Short first chapter.'
          : _tabletChapterText(240),
      contentType: 'text/plain',
    );
  }
}

class _BlockingProgressStore extends BookSourceReadingProgressStore {
  final Completer<void> _save = Completer<void>();
  bool saveStarted = false;

  bool get saveCompleted => _save.isCompleted;

  void completeSave() {
    if (!_save.isCompleted) _save.complete();
  }

  @override
  Future<void> save({
    required String sourceId,
    required String bookId,
    required BookSourceReadingProgress progress,
  }) {
    saveStarted = true;
    return _save.future;
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

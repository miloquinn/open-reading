import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_chapter_text.dart';
import 'package:xxread/book_sources/services/book_source_reading_progress.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/book_sources/services/book_source_text_paginator.dart';
import 'package:xxread/core/reader/canonical_locator.dart';
import 'package:xxread/core/reader/native_text_paginator.dart';
import 'package:xxread/core/reader/reader_custom_theme.dart';
import 'package:xxread/core/reader/reader_leaf_status.dart';
import 'package:xxread/core/reader/reader_layout.dart';
import 'package:xxread/core/reader/reader_keep_screen_on.dart';
import 'package:xxread/core/reader/reader_margin_settings.dart';
import 'package:xxread/core/reader/reader_safe_area.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/core/reader/reader_system_ui.dart';
import 'package:xxread/core/reader/reader_text_pagination.dart';
import 'package:xxread/core/reader/reader_theme_order.dart';
import 'package:xxread/core/reader/reader_vertical_paging.dart';
import 'package:xxread/core/reader/reader_volume_key_controller.dart';
import 'package:xxread/models/bookmark.dart';
import 'package:xxread/services/books/bookmark_dao.dart';
import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/services/reading/reading_stats_dao.dart';
import 'package:xxread/utils/font_catalog_helper.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/widgets/reader_control_chrome.dart';
import 'package:xxread/widgets/reader_navigation_sheet.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';
import 'package:xxread/widgets/reader_pull_bookmark.dart';
import 'package:xxread/widgets/reader_settings_controls.dart';
import 'package:xxread/widgets/reader_shader_page_curl.dart';
import 'package:xxread/widgets/reader_theme_background.dart';
import 'package:xxread/widgets/reader_text_page_content.dart';
import 'package:xxread/widgets/reader_top_information_bar.dart';
import 'package:xxread/widgets/reader_vertical_paging_surface.dart';
import 'package:xxread/widgets/side_toast.dart';

import 'themes/reader_custom_themes_page.dart';

typedef BookSourcePageMode = ReaderPageMode;

/// Immersive reader for chapters streamed from an Open Reading book source.
class BookSourceReaderPage extends StatefulWidget {
  final RegisteredBookSource source;
  final BookSourceBook book;
  final BookSourceClient? client;
  final BookSourceReadingProgressStore progressStore;
  final BookSourceShelfService? shelfService;

  const BookSourceReaderPage({
    super.key,
    required this.source,
    required this.book,
    this.client,
    this.progressStore = const BookSourceReadingProgressStore(),
    this.shelfService,
  });

  @override
  State<BookSourceReaderPage> createState() => _BookSourceReaderPageState();
}

class _BookSourceReaderPageState extends State<BookSourceReaderPage>
    with WidgetsBindingObserver {
  static const double _spreadGutter = 24;

  late final BookSourceClient _client = widget.client ?? BookSourceClient();
  late final BookSourceShelfService _shelfService =
      widget.shelfService ?? BookSourceShelfService(client: _client);
  PageController _pageController = PageController();
  final ItemScrollController _verticalPageScrollController =
      ItemScrollController();
  final ItemPositionsListener _verticalPagePositionsListener =
      ItemPositionsListener.create();
  final ItemScrollController _verticalChapterScrollController =
      ItemScrollController();
  final ScrollOffsetController _verticalChapterOffsetController =
      ScrollOffsetController();
  final ItemPositionsListener _verticalChapterPositionsListener =
      ItemPositionsListener.create();
  final ReaderPageCurlController _pageCurlController =
      ReaderPageCurlController();
  final ReaderPageCurlController _spreadForwardPageCurlController =
      ReaderPageCurlController();
  final ReaderPageCurlController _spreadBackwardPageCurlController =
      ReaderPageCurlController();
  final ReaderPageCurlCoordinator _spreadPageCurlCoordinator =
      ReaderPageCurlCoordinator(gutterWidth: _spreadGutter);
  final ValueNotifier<double> _scrollProgress = ValueNotifier(0);
  final ReaderLeafStatusController _leafStatusController =
      ReaderLeafStatusController();

  List<BookSourceChapter> _chapters = const [];
  BookSourceChapterContent? _content;
  int _chapterIndex = 0;
  bool _loadingCatalog = true;
  bool _loadingContent = false;
  bool _controlsVisible = false;
  Object? _error;
  double _fontSize = 19;
  double _lineHeight = 1.75;
  int _firstLineIndent = ReaderSettings.defaultFirstLineIndent;
  int _paragraphSpacing = ReaderSettings.defaultParagraphSpacing;
  FontOption _readerFont = FontCatalog.defaultReaderFont;
  double _horizontalMargin = ReaderSettings.defaultHorizontalMargin;
  double _topMargin = ReaderMarginSettings.defaultTop;
  double _bottomMargin = ReaderMarginSettings.defaultBottom;
  String _readerThemeId = ReaderThemes.day.id;
  BookSourcePageMode _pageMode = BookSourcePageMode.verticalScroll;
  bool _pullBookmarkEnabled = false;
  bool _tapPageAnimationEnabled = true;
  bool _tabletTwoPageEnabled = ReaderSettings.defaultTabletTwoPageEnabled;
  int _pageIndex = 0;
  bool _usesTwoPageLayout = false;
  int _pageCount = 1;
  int _verticalPageIndex = 0;
  int _verticalPageCount = 1;
  int _pageViewLeading = 0;
  bool _ignoreSlidePageChanges = true;
  int? _pendingSlideChapterIndex;
  int? _pendingSlideBoundaryViewIndex;
  double _pendingSlideRestoreProgress = 0;
  double _restorePageProgress = 0;
  bool _restorePagedPosition = false;
  int? _restoreTextOffset;
  String? _paginationKey;
  List<BookSourceTextPage> _paginatedPages = const [];
  int _chapterLoadSerial = 0;
  final Map<int, BookSourceChapterContent> _prefetchedContent = {};
  final Map<int, Future<BookSourceChapterContent>> _continuousContentLoads = {};
  final Map<int, _BookSourcePagedLayout> _pagedLayouts = {};
  final Set<int> _queuedPagedLayoutWarms = {};
  final Set<int> _warmedPagedLayoutIndexes = {};
  final Map<int, _BookSourceVerticalLayout> _verticalLayouts = {};
  Future<void> _progressSaveQueue = Future<void>.value();
  bool _scrollByChapter = true;
  Size _pagedViewportSize = Size.zero;
  Size _verticalViewportSize = Size.zero;
  bool _exitPromptVisible = false;
  bool _allowPop = false;
  int? _shelfBookId;
  Timer? _progressSaveTimer;
  Timer? _controlsTimer;
  final ReadingStatsDao _readingStatsDao = ReadingStatsDao();
  final BookmarkDao _bookmarkDao = BookmarkDao();
  final ReaderSettingsStore _readerSettingsStore = const ReaderSettingsStore();
  final ReaderCustomThemeStore _customThemeStore =
      const ReaderCustomThemeStore();
  final ReaderThemeOrderStore _themeOrderStore = const ReaderThemeOrderStore();
  List<Bookmark> _bookmarks = const [];
  bool _bookmarkBusy = false;
  DateTime? _readingSessionStartedAt;
  int _sessionPagesRead = 0;
  bool _readerSystemUiApplied = false;
  ReaderTopBarStyle _topBarStyle = ReaderTopBarStyle.reader;

  ReaderThemePalette get _readerTheme => ReaderThemes.byId(_readerThemeId);

  ThemeData get _readerThemeData => _readerTheme.toThemeData(
        typography: Theme.of(context).textTheme,
      );

  ReaderSettings get _readerSettings => ReaderSettings(
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        horizontalMargin: _horizontalMargin,
        topMargin: _topMargin,
        bottomMargin: _bottomMargin,
        themeId: _readerThemeId,
        pageMode: _pageMode,
        firstLineIndent: _firstLineIndent,
        paragraphSpacing: _paragraphSpacing,
        pullBookmarkEnabled: _pullBookmarkEnabled,
        tapPageAnimationEnabled: _tapPageAnimationEnabled,
        tabletTwoPageEnabled: _tabletTwoPageEnabled,
      );

  ReaderSafeAreaMetrics get _readerSafeArea => ReaderSafeAreaMetrics(
        viewPadding: MediaQuery.viewPaddingOf(context),
        topMargin: _topMargin,
        bottomMargin: _bottomMargin,
        topChromeReserve: _topBarStyle == ReaderTopBarStyle.reader
            ? ReaderSafeAreaMetrics.readerTopBarReserve
            : 0,
      );

  bool _shouldUseTwoPageLayout(Size size) =>
      _tabletTwoPageEnabled &&
      _pageMode == BookSourcePageMode.pageCurl &&
      ReaderLayoutBreakpoints.supportsTwoPageLayout(size);

  Size _paginationViewport(Size viewport, bool usesTwoPageLayout) =>
      usesTwoPageLayout
          ? Size((viewport.width - _spreadGutter) / 2, viewport.height)
          : viewport;

  int _spreadStartForPage(int pageIndex) => (pageIndex ~/ 2) * 2;

  int _lastVisiblePagedIndex(int pageIndex, int pageCount) {
    if (pageCount <= 0) return 0;
    final clamped = pageIndex.clamp(0, pageCount - 1);
    if (!_usesTwoPageLayout) return clamped;
    return math.min(_spreadStartForPage(clamped) + 1, pageCount - 1);
  }

  double _pagedReadingProgress(int pageIndex, int pageCount) => pageCount <= 1
      ? 0
      : (_lastVisiblePagedIndex(pageIndex, pageCount) / (pageCount - 1))
          .clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _leafStatusController
      ..addListener(_onLeafStatusChanged)
      ..start();
    unawaited(ReaderKeepScreenOnController.activate(this));
    _startReadingSession();
    _verticalPagePositionsListener.itemPositions
        .addListener(_onVerticalPagePositionsChanged);
    _verticalChapterPositionsListener.itemPositions
        .addListener(_onVerticalChapterPositionsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _readerSystemUiApplied) return;
      final topBarStyle = await ReaderSystemUiController.applySavedPreference();
      if (!mounted) return;
      setState(() {
        _topBarStyle = topBarStyle;
        _readerSystemUiApplied = true;
      });
    });
    unawaited(_initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var nextReaderFont = FontCatalog.defaultReaderFont;
    try {
      nextReaderFont = context.watch<AppSettingsNotifier>().readerFont;
    } on ProviderNotFoundException {
      // Reader widgets remain embeddable in tests and isolated previews.
    }
    if (_readerFont.id == nextReaderFont.id) return;
    _readerFont = nextReaderFont;
    _paginationKey = null;
    _paginatedPages = const [];
    _pagedLayouts.clear();
    _warmedPagedLayoutIndexes.clear();
    _verticalLayouts.clear();
    _restorePagedPosition = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startReadingSession();
      unawaited(ReaderKeepScreenOnController.reapply(this));
      if (_readerSystemUiApplied) unawaited(_applyReaderSystemUi());
      if (!_loadingCatalog && _error == null) {
        unawaited(_syncVolumeKeyPaging());
      }
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveProgress());
      unawaited(_flushReadingSession());
    }
  }

  void _startReadingSession() {
    _readingSessionStartedAt ??= DateTime.now();
  }

  Future<void> _flushReadingSession() async {
    final startedAt = _readingSessionStartedAt;
    if (startedAt == null) return;

    final endedAt = DateTime.now();
    final pagesRead = _sessionPagesRead;
    _readingSessionStartedAt = null;
    _sessionPagesRead = 0;

    try {
      await _readingStatsDao.recordReadingSession(
        startTime: startedAt,
        endTime: endedAt,
        bookId: _shelfBookId,
        pagesRead: pagesRead,
      );
    } catch (error) {
      debugPrint('record source reading session failed: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressSaveTimer?.cancel();
    _controlsTimer?.cancel();
    unawaited(_saveProgress());
    unawaited(_flushReadingSession());
    _verticalPagePositionsListener.itemPositions
        .removeListener(_onVerticalPagePositionsChanged);
    _verticalChapterPositionsListener.itemPositions
        .removeListener(_onVerticalChapterPositionsChanged);
    _pageController.dispose();
    _scrollProgress.dispose();
    _spreadPageCurlCoordinator.dispose();
    _leafStatusController
      ..removeListener(_onLeafStatusChanged)
      ..dispose();
    unawaited(ReaderVolumeKeyController.deactivate(this));
    unawaited(ReaderKeepScreenOnController.deactivate(this));
    unawaited(ReaderSystemUiController.restore());
    super.dispose();
  }

  Future<void> _applyReaderSystemUi() => ReaderSystemUiController.apply(
        style: _topBarStyle,
      );

  void _onLeafStatusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    setState(() {
      _loadingCatalog = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        _client.getChapters(widget.source, widget.book.id),
        widget.progressStore.load(
          sourceId: widget.source.id,
          bookId: widget.book.id,
        ),
        _readerSettingsStore.load(
          fallbackPageMode: BookSourcePageMode.verticalScroll,
        ),
        _readerSettingsStore.loadScrollByChapter(),
        _customThemeStore.loadAll(),
        _themeOrderStore.load(),
      ]);
      final chapters = [...results[0]! as List<BookSourceChapter>]
        ..sort((a, b) => a.order.compareTo(b.order));
      final saved = results[1] as BookSourceReadingProgress?;
      final settings = results[2]! as ReaderSettings;
      final scrollByChapter = results[3]! as bool;
      final customThemes = results[4] as List<ReaderCustomTheme>;
      final themeOrder = results[5] as List<String>;
      var initialIndex = saved?.chapterIndex ?? 0;
      if (saved != null && saved.chapterId.isNotEmpty) {
        final byId = chapters.indexWhere(
          (chapter) => chapter.id == saved.chapterId,
        );
        if (byId >= 0) initialIndex = byId;
      }
      if (chapters.isNotEmpty) {
        initialIndex = initialIndex.clamp(0, chapters.length - 1);
      }
      if (!mounted) return;
      ReaderThemes.setCustomThemes(customThemes);
      ReaderThemes.setThemeOrder(themeOrder);
      setState(() {
        _chapters = chapters;
        _chapterIndex = initialIndex;
        _fontSize = settings.fontSize;
        _horizontalMargin = settings.horizontalMargin;
        _topMargin = settings.topMargin;
        _bottomMargin = settings.bottomMargin;
        _lineHeight = settings.lineHeight;
        _firstLineIndent = settings.firstLineIndent;
        _paragraphSpacing = settings.paragraphSpacing;
        _readerThemeId = ReaderThemes.byId(settings.themeId).id;
        _pageMode = settings.pageMode;
        _pullBookmarkEnabled = settings.pullBookmarkEnabled;
        _tapPageAnimationEnabled = settings.tapPageAnimationEnabled;
        _tabletTwoPageEnabled = settings.tabletTwoPageEnabled;
        _scrollByChapter = scrollByChapter;
        _loadingCatalog = false;
      });
      unawaited(_syncVolumeKeyPaging());
      if (chapters.isNotEmpty) {
        unawaited(_resolveShelfBook());
        await _loadChapter(
          initialIndex,
          restoreProgress: saved?.chapterProgress ?? 0,
          saveCurrent: false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _error = error;
        _controlsVisible = true;
      });
    }
  }

  Future<void> _syncVolumeKeyPaging() => ReaderVolumeKeyController.activate(
        owner: this,
        pageTurningAvailable: _pageMode != BookSourcePageMode.verticalScroll,
        onNextPage: () => unawaited(_handleVolumePageTurn(forward: true)),
        onPreviousPage: () => unawaited(_handleVolumePageTurn(forward: false)),
      );

  Future<void> _handleVolumePageTurn({required bool forward}) async {
    if (!mounted ||
        _loadingCatalog ||
        _loadingContent ||
        _pageMode == BookSourcePageMode.verticalScroll) {
      return;
    }
    if (_pageMode == BookSourcePageMode.pageCurl) {
      final controller = _usesTwoPageLayout
          ? (forward
              ? _spreadForwardPageCurlController
              : _spreadBackwardPageCurlController)
          : _pageCurlController;
      if (forward) {
        await controller.turnForward();
      } else {
        await controller.turnBackward();
      }
      return;
    }
    if (_pageMode == BookSourcePageMode.horizontalSlide &&
        _pageController.hasClients) {
      if (forward) {
        await _pageController.nextPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        await _pageController.previousPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    if (forward) {
      await _turnForward();
    } else {
      await _turnBackward();
    }
  }

  Future<void> _saveProgress() {
    if (_chapters.isEmpty || _chapterIndex >= _chapters.length) {
      return Future<void>.value();
    }
    final chapterIndex = _chapterIndex;
    final chapterId = _chapters[chapterIndex].id;
    final chapterCount = _chapters.length;
    final shelfBookId = _shelfBookId;
    var progress = _scrollProgress.value;
    if (_pageMode == BookSourcePageMode.verticalScroll) {
      progress = _verticalPageCount <= 1
          ? 0
          : (_verticalPageIndex / (_verticalPageCount - 1)).clamp(0.0, 1.0);
    } else {
      progress = _pagedReadingProgress(_pageIndex, _pageCount);
    }
    final progressSnapshot = BookSourceReadingProgress(
      chapterId: chapterId,
      chapterIndex: chapterIndex,
      chapterProgress: progress,
      updatedAt: DateTime.now().toUtc(),
    );
    _progressSaveQueue = _progressSaveQueue.then((_) async {
      try {
        await widget.progressStore.save(
          sourceId: widget.source.id,
          bookId: widget.book.id,
          progress: progressSnapshot,
        );
        if (shelfBookId != null) {
          await _shelfService.updateShelfProgress(
            shelfBookId: shelfBookId,
            chapterIndex: chapterIndex,
            chapterCount: chapterCount,
            chapterProgress: progress,
          );
        }
      } catch (error) {
        debugPrint('save source reading progress failed: $error');
      }
    });
    return _progressSaveQueue;
  }

  Future<void> _resolveShelfBook() async {
    final shelfBook = await _shelfService.findShelfBook(
      sourceId: widget.source.id,
      sourceBookId: widget.book.id,
    );
    if (!mounted) return;
    _shelfBookId = shelfBook?.id;
    final shelfBookId = _shelfBookId;
    if (shelfBookId == null) return;
    try {
      final bookmarks = await _bookmarkDao.getBookmarksForBook(shelfBookId);
      if (mounted) setState(() => _bookmarks = bookmarks);
    } catch (error) {
      debugPrint('load source bookmarks failed: $error');
    }
  }

  Future<void> _loadChapter(
    int index, {
    double restoreProgress = 0,
    bool saveCurrent = true,
  }) async {
    if (index < 0 || index >= _chapters.length || _loadingContent) return;
    if (saveCurrent && index > _chapterIndex) _sessionPagesRead++;
    if (saveCurrent && _content != null) unawaited(_saveProgress());
    if (!mounted) return;
    final loadSerial = ++_chapterLoadSerial;
    final prefetched = _prefetchedContent[index];
    if (prefetched != null) {
      _applyLoadedChapter(
        index,
        prefetched,
        restoreProgress: restoreProgress,
      );
      return;
    }
    setState(() {
      _loadingContent = true;
      _error = null;
    });
    try {
      final contentFuture = _continuousContentFor(index);
      final content = await contentFuture;
      if (!mounted || loadSerial != _chapterLoadSerial) return;
      _applyLoadedChapter(
        index,
        content,
        restoreProgress: restoreProgress,
      );
    } catch (error) {
      if (!mounted || loadSerial != _chapterLoadSerial) return;
      setState(() {
        _loadingContent = false;
        _error = error;
        _controlsVisible = true;
      });
    }
  }

  void _applyLoadedChapter(
    int index,
    BookSourceChapterContent content, {
    required double restoreProgress,
  }) {
    final normalizedProgress = restoreProgress.clamp(0.0, 1.0);
    final preparedLayout = _preparedPagedLayoutForChapter(index, content);
    final preparedPages = preparedLayout?.pages;
    final preparedPageCount = preparedPages?.length ?? 1;
    final preparedPageIndex = preparedPages == null
        ? 0
        : (_usesTwoPageLayout
                ? _spreadStartForPage(
                    ((preparedPageCount - 1) * normalizedProgress).round(),
                  )
                : ((preparedPageCount - 1) * normalizedProgress).round())
            .clamp(0, preparedPageCount - 1);
    _pagedLayouts.removeWhere(
      (chapterIndex, _) => chapterIndex < index - 1 || chapterIndex > index + 2,
    );
    _warmedPagedLayoutIndexes.removeWhere(
      (chapterIndex) => chapterIndex < index - 1 || chapterIndex > index + 2,
    );
    setState(() {
      _chapterIndex = index;
      _content = content;
      _prefetchedContent[index] = content;
      _loadingContent = false;
      _pageIndex = preparedPageIndex;
      _pageCount = preparedPageCount;
      _paginatedPages = preparedPages ?? const [];
      _paginationKey = preparedLayout?.fingerprint;
      _restorePageProgress = normalizedProgress;
      _restorePagedPosition = preparedLayout == null;
      _ignoreSlidePageChanges = true;
      _pendingSlideChapterIndex = null;
      _pendingSlideBoundaryViewIndex = null;
    });
    if (_pageMode == BookSourcePageMode.horizontalSlide) {
      _replaceSlidePageController(
        initialPage: preparedPageIndex + (index > 0 ? 1 : 0),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ignoreSlidePageChanges = false;
      });
    }
    _scrollProgress.value = normalizedProgress;
    unawaited(_preloadAround(index));
  }

  _BookSourcePagedLayout? _preparedPagedLayoutForChapter(
    int index,
    BookSourceChapterContent content,
  ) {
    if (_pageMode == BookSourcePageMode.verticalScroll ||
        _pagedViewportSize.isEmpty) {
      return null;
    }
    return _pagedLayoutFor(index, content, _pagedViewportSize);
  }

  void _replaceSlidePageController({required int initialPage}) {
    final previous = _pageController;
    _pageController = PageController(initialPage: initialPage);
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  Future<void> _preloadAround(int index) async {
    // The next chapter is the only cache entry needed for a forward turn.
    // Load and lay it out before competing for a source connection with the
    // backwards preview or the farther look-ahead chapter.
    await _preloadChapter(index + 1);
    for (final chapterIndex in <int>[index - 1, index + 2]) {
      unawaited(_preloadChapter(chapterIndex));
    }
  }

  Future<void> _preloadChapter(int index) async {
    if (index < 0 || index >= _chapters.length) return;
    try {
      await _continuousContentFor(index);
    } catch (_) {
      // Adjacent content is opportunistic and can be retried on demand.
    }
  }

  Future<BookSourceChapterContent> _continuousContentFor(int index) {
    final cached = _prefetchedContent[index];
    if (cached != null) return Future.value(cached);
    final inFlight = _continuousContentLoads[index];
    if (inFlight != null) return inFlight;
    late final Future<BookSourceChapterContent> future;
    future = _client
        .getChapterContent(
      widget.source,
      bookId: widget.book.id,
      chapterId: _chapters[index].id,
    )
        .then((content) {
      _prefetchedContent[index] = content;
      if (!mounted) {
        return content;
      }
      final pageStep = _usesTwoPageLayout ? 2 : 1;
      final updatesCurrentContent =
          !_loadingContent && _chapterIndex == index && _content != content;
      final revealsPagedBoundary = !_loadingContent &&
          _pageMode != BookSourcePageMode.verticalScroll &&
          ((index == _chapterIndex + 1 &&
                  _pageIndex + pageStep >= _pageCount) ||
              (index == _chapterIndex - 1 && _pageIndex < pageStep));
      if (updatesCurrentContent || revealsPagedBoundary) {
        setState(() {
          if (updatesCurrentContent) {
            _content = content;
          }
        });
      }
      _schedulePagedLayoutWarm(index);
      return content;
    }).whenComplete(() {
      if (identical(_continuousContentLoads[index], future)) {
        _continuousContentLoads.remove(index);
      }
    });
    _continuousContentLoads[index] = future;
    return future;
  }

  void _schedulePagedLayoutWarm(int index) {
    if (!mounted ||
        _pageMode == BookSourcePageMode.verticalScroll ||
        index != _chapterIndex + 1 ||
        index < 0 ||
        index >= _chapters.length ||
        _pagedViewportSize.isEmpty ||
        _prefetchedContent[index] == null ||
        _warmedPagedLayoutIndexes.contains(index) ||
        !_queuedPagedLayoutWarms.add(index)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queuedPagedLayoutWarms.remove(index);
      if (!mounted ||
          _pageMode == BookSourcePageMode.verticalScroll ||
          index != _chapterIndex + 1 ||
          _pagedViewportSize.isEmpty) {
        return;
      }
      final content = _prefetchedContent[index];
      if (content == null) return;
      _pagedLayoutFor(index, content, _pagedViewportSize);
      _warmedPagedLayoutIndexes.add(index);
    });
  }

  Future<void> _jumpToVerticalChapter(
    int index, {
    int? textOffset,
    double progress = 0,
  }) async {
    if (index < 0 || index >= _chapters.length) return;
    final content = await _continuousContentFor(index);
    if (!mounted) return;
    var targetPage = 0;
    _BookSourceVerticalLayout? layout;
    if (!_verticalViewportSize.isEmpty) {
      layout = _verticalLayoutFor(index, content, _verticalViewportSize);
      targetPage = textOffset != null
          ? bookSourcePageIndexForOffset(layout.pages, textOffset)
          : ((layout.pages.length - 1) * progress.clamp(0.0, 1.0)).round();
    }
    setState(() {
      _chapterIndex = index;
      _content = content;
      _pageIndex = targetPage;
      _verticalPageIndex = targetPage;
      _verticalPageCount = layout?.pages.length ?? 1;
      _restorePagedPosition = false;
      _restoreTextOffset = null;
    });
    _scrollProgress.value =
        _verticalPageCount <= 1 ? 0 : targetPage / (_verticalPageCount - 1);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_verticalChapterScrollController.isAttached) return;
    await _verticalChapterScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    if (targetPage > 0) {
      await _verticalChapterOffsetController.animateScroll(
        offset: targetPage * _verticalPageExtentFor(_verticalViewportSize),
        duration: const Duration(milliseconds: 1),
      );
      if (!mounted) return;
    }
    unawaited(_preloadAround(index));
    _scheduleProgressSave();
  }

  void _restoreScrollProgress(double progress) {
    _restorePageProgress = progress.clamp(0, 1);
    _restorePagedPosition = true;
    _scrollProgress.value = progress.clamp(0.0, 1.0);
  }

  void _showControlsTemporarily() {
    _controlsTimer?.cancel();
    if (mounted) setState(() => _controlsVisible = true);
    _controlsTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    _controlsTimer?.cancel();
    setState(() => _controlsVisible = !_controlsVisible);
  }

  Future<void> _requestExit() async {
    if (_exitPromptVisible) return;
    _exitPromptVisible = true;
    await _saveProgress();
    // 阅读统计是退出后的派生写入，不应阻塞“加入书架？”确认弹窗。
    unawaited(_flushReadingSession());
    final shelfBook = await _shelfService.findShelfBook(
      sourceId: widget.source.id,
      sourceBookId: widget.book.id,
    );
    if (!mounted) return;
    if (shelfBook != null) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
      return;
    }

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.bookSourceExitAddTitle),
        content: Text(
          context.l10n.bookSourceExitAddMessage(widget.book.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.bookSourceNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.bookSourceAddToShelf),
          ),
        ],
      ),
    );
    _exitPromptVisible = false;
    if (!mounted) return;
    if (shouldAdd == true) {
      final added = await _shelfService.addOnline(
        source: widget.source,
        book: widget.book,
      );
      _shelfBookId = added.id;
      await _saveProgress();
      if (!mounted) return;
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -350 && _chapterIndex < _chapters.length - 1) {
      unawaited(_loadChapter(_chapterIndex + 1));
    } else if (velocity > 350 && _chapterIndex > 0) {
      unawaited(_loadChapter(_chapterIndex - 1));
    }
  }

  void _handlePagedSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -350) {
      unawaited(_turnForward());
    } else if (velocity > 350) {
      unawaited(_turnBackward());
    }
  }

  double get _currentReadingProgress {
    if (_pageMode != BookSourcePageMode.verticalScroll) {
      return _pagedReadingProgress(_pageIndex, _pageCount);
    }
    return _verticalPageCount <= 1
        ? 0
        : (_verticalPageIndex / (_verticalPageCount - 1)).clamp(0.0, 1.0);
  }

  int? get _currentTextOffset {
    if (_pageMode == BookSourcePageMode.verticalScroll) {
      final pages = _verticalLayouts[_chapterIndex]?.pages;
      if (pages == null || pages.isEmpty) return null;
      return pages[_verticalPageIndex.clamp(0, pages.length - 1)].startOffset;
    }
    if (_paginatedPages.isEmpty) return null;
    return _paginatedPages[_pageIndex.clamp(0, _paginatedPages.length - 1)]
        .startOffset;
  }

  void _setPagedIndex(int index, {bool jumpPageView = false}) {
    if (_paginatedPages.isEmpty) return;
    final clamped = index.clamp(0, _paginatedPages.length - 1);
    final next = _usesTwoPageLayout ? _spreadStartForPage(clamped) : clamped;
    if (next > _pageIndex) _sessionPagesRead++;
    if (next != _pageIndex) setState(() => _pageIndex = next);
    _pageCount = _paginatedPages.length;
    _scrollProgress.value = _pagedReadingProgress(_pageIndex, _pageCount);
    if (jumpPageView && _pageController.hasClients) {
      _pageController.jumpToPage(_pageIndex + _pageViewLeading);
    }
    _scheduleProgressSave();
  }

  void _scheduleProgressSave() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_saveProgress()),
    );
  }

  void _queueSlideChapterCommit({
    required int chapterIndex,
    required int boundaryViewIndex,
    required double restoreProgress,
  }) {
    _pendingSlideChapterIndex = chapterIndex;
    _pendingSlideBoundaryViewIndex = boundaryViewIndex;
    _pendingSlideRestoreProgress = restoreProgress;
  }

  void _commitPendingSlideChapter() {
    final chapterIndex = _pendingSlideChapterIndex;
    final boundaryViewIndex = _pendingSlideBoundaryViewIndex;
    if (chapterIndex == null || boundaryViewIndex == null) return;
    final settledViewIndex =
        _pageController.hasClients ? _pageController.page?.round() : null;
    _pendingSlideChapterIndex = null;
    _pendingSlideBoundaryViewIndex = null;
    if (settledViewIndex != boundaryViewIndex) return;
    final restoreProgress = _pendingSlideRestoreProgress;
    // Let PageController.nextPage/previousPage finish their own ScrollEnd
    // future before replacing the PageView with the target chapter.
    Timer.run(() {
      if (!mounted) return;
      unawaited(
        _loadChapter(
          chapterIndex,
          restoreProgress: restoreProgress,
        ),
      );
    });
  }

  Future<void> _turnForward() async {
    final pageStep = _usesTwoPageLayout ? 2 : 1;
    if (_pageIndex + pageStep < _pageCount) {
      _setPagedIndex(_pageIndex + pageStep, jumpPageView: true);
    } else if (_chapterIndex + 1 < _chapters.length) {
      await _loadChapter(_chapterIndex + 1, restoreProgress: 0);
    } else {
      _showControlsTemporarily();
    }
  }

  Future<void> _turnBackward() async {
    final pageStep = _usesTwoPageLayout ? 2 : 1;
    if (_pageIndex >= pageStep) {
      _setPagedIndex(_pageIndex - pageStep, jumpPageView: true);
    } else if (_chapterIndex > 0) {
      await _loadChapter(_chapterIndex - 1, restoreProgress: 1);
    } else {
      _showControlsTemporarily();
    }
  }

  int _currentBookmarkOffset(String text) {
    if (_pageMode == BookSourcePageMode.verticalScroll) {
      final pages = _verticalLayouts[_chapterIndex]?.pages;
      if (pages != null && pages.isNotEmpty) {
        return pages[_verticalPageIndex.clamp(0, pages.length - 1)].startOffset;
      }
    } else if (_paginatedPages.isNotEmpty) {
      return _paginatedPages[_pageIndex.clamp(0, _paginatedPages.length - 1)]
          .startOffset;
    }
    return (_scrollProgress.value * text.length).round().clamp(0, text.length);
  }

  String? get _currentBookmarkAnchorKey {
    final content = _content;
    if (content == null || _chapters.isEmpty) return null;
    final text = readableBookSourceChapterText(
      content,
      fallbackTitle: _chapters[_chapterIndex].title,
    );
    final offset = _currentBookmarkOffset(text);
    return '${_chapters[_chapterIndex].id}:$offset';
  }

  Future<void> _toggleCurrentBookmark() async {
    final shelfBookId = _shelfBookId;
    final content = _content;
    if (_bookmarkBusy || content == null || _chapters.isEmpty) return;
    if (shelfBookId == null) {
      showSideToast(
        context,
        context.l10n.readerBookmarkRequiresShelf,
        duration: const Duration(milliseconds: 1900),
        icon: Icons.library_add_rounded,
        kind: SideToastKind.warning,
      );
      return;
    }
    final text = readableBookSourceChapterText(
      content,
      fallbackTitle: _chapters[_chapterIndex].title,
    );
    final offset = _currentBookmarkOffset(text);
    final anchorKey = '${_chapters[_chapterIndex].id}:$offset';
    Bookmark? existing;
    for (final bookmark in _bookmarks) {
      if (bookmark.anchorKey == anchorKey) {
        existing = bookmark;
        break;
      }
    }
    setState(() => _bookmarkBusy = true);
    try {
      if (existing != null) {
        final existingId = existing.id!;
        await _bookmarkDao.deleteBookmark(existingId);
        if (!mounted) return;
        setState(() {
          _bookmarks = _bookmarks
              .where((bookmark) => bookmark.id != existingId)
              .toList(growable: false);
        });
        showSideToast(
          context,
          context.l10n.bookmarkRemoved,
          duration: const Duration(milliseconds: 1600),
          icon: Icons.bookmark_remove_rounded,
          kind: SideToastKind.success,
        );
        return;
      }
      final excerptEnd = (offset + 120).clamp(offset, text.length);
      final excerpt = text
          .substring(offset, excerptEnd)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final locator = CanonicalLocator.fromComponents(
        format: content.contentType == 'text/html'
            ? BookFormat.html
            : BookFormat.txt,
        chapterId: _chapters[_chapterIndex].id,
        offset: offset,
        excerpt: excerpt,
        progression: text.isEmpty ? 0 : offset / text.length,
      );
      final bookmark = Bookmark(
        bookId: shelfBookId,
        pageNumber: _chapterIndex,
        canonicalLocator: LocatorCodec.encodeCanonicalLocator(locator),
        anchorKey: anchorKey,
        chapterIndex: _chapterIndex,
        chapterTitle: _chapters[_chapterIndex].title,
        excerpt: excerpt,
      );
      final id = await _bookmarkDao.insertBookmark(bookmark);
      if (!mounted) return;
      setState(() {
        _bookmarks = [..._bookmarks, bookmark.copyWith(id: id)]..sort((a, b) =>
            (a.chapterIndex ?? a.pageNumber)
                .compareTo(b.chapterIndex ?? b.pageNumber));
      });
      showSideToast(
        context,
        context.l10n.bookmarkAdded,
        duration: const Duration(milliseconds: 1600),
        icon: Icons.bookmark_added_rounded,
        kind: SideToastKind.success,
      );
    } catch (error) {
      debugPrint('toggle source bookmark failed: $error');
    } finally {
      if (mounted) setState(() => _bookmarkBusy = false);
    }
  }

  Future<void> _deleteBookmark(Bookmark bookmark) async {
    final id = bookmark.id;
    if (id == null) return;
    await _bookmarkDao.deleteBookmark(id);
    if (!mounted) return;
    setState(() {
      _bookmarks = _bookmarks
          .where((candidate) => candidate.id != id)
          .toList(growable: false);
    });
    showSideToast(
      context,
      context.l10n.bookmarkRemoved,
      duration: const Duration(milliseconds: 1600),
      icon: Icons.bookmark_remove_rounded,
      kind: SideToastKind.success,
    );
  }

  Future<void> _jumpToBookmark(Bookmark bookmark) async {
    final raw = bookmark.canonicalLocator;
    final locator =
        raw == null ? null : LocatorCodec.decodeCanonicalLocator(raw);
    final chapterId = locator?.chapterId ?? locator?.textAnchor?.chapterId;
    var chapterIndex = chapterId == null
        ? -1
        : _chapters.indexWhere((chapter) => chapter.id == chapterId);
    if (chapterIndex < 0) {
      chapterIndex = (bookmark.chapterIndex ?? bookmark.pageNumber)
          .clamp(0, _chapters.length - 1);
    }
    _restoreTextOffset = locator?.textAnchor?.startOffsetUtf16;
    if (_pageMode == BookSourcePageMode.verticalScroll && !_scrollByChapter) {
      await _jumpToVerticalChapter(
        chapterIndex,
        textOffset: _restoreTextOffset,
        progress: locator?.progression ?? 0,
      );
      return;
    }
    await _loadChapter(
      chapterIndex,
      restoreProgress: locator?.progression ?? 0,
    );
  }

  Future<void> _showCatalog() async {
    if (_chapters.isEmpty) return;
    _controlsTimer?.cancel();
    // Built once outside the StatefulBuilder below: that builder re-runs on
    // every keyboard show/hide animation frame, and reallocating a
    // ReaderNavigationChapter per chapter on every frame is severe jank for
    // books with thousands of chapters.
    final navigationChapters = [
      for (var index = 0; index < _chapters.length; index++)
        ReaderNavigationChapter(
          title: _chapters[index].title,
          index: index,
        ),
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: _readerTheme.shadow.withValues(
        alpha: _readerTheme.brightness == Brightness.dark ? 0.72 : 0.38,
      ),
      showDragHandle: false,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.86,
          child: ReaderNavigationSheet(
            palette: _readerTheme,
            chapters: navigationChapters,
            currentChapterIndex: _chapterIndex,
            bookmarks: _bookmarks,
            currentAnchorKey: _currentBookmarkAnchorKey,
            onChapterSelected: (index) {
              Navigator.of(sheetContext).pop();
              if (_pageMode == BookSourcePageMode.verticalScroll &&
                  !_scrollByChapter) {
                unawaited(_jumpToVerticalChapter(index));
              } else {
                unawaited(_loadChapter(index));
              }
            },
            onBookmarkSelected: (bookmark) {
              Navigator.of(sheetContext).pop();
              unawaited(_jumpToBookmark(bookmark));
            },
            onBookmarkDeleted: (bookmark) async {
              await _deleteBookmark(bookmark);
              if (mounted) setSheetState(() {});
            },
          ),
        ),
      ),
    );
  }

  String _readerThemeName(String themeId) {
    final customName = ReaderThemes.customThemeById(themeId)?.name.trim();
    if (customName != null && customName.isNotEmpty) return customName;
    return switch (themeId) {
      'mist' => context.l10n.readerThemeMist,
      'green' => context.l10n.readerThemeGreen,
      'rose' => context.l10n.readerThemeRose,
      'navy' => context.l10n.readerThemeNavy,
      'night' => context.l10n.readerThemeNight,
      'pureBlack' => context.l10n.readerThemePureBlack,
      'parchment' => context.l10n.readerThemeParchment,
      ReaderCustomTheme.themeId => context.l10n.readerThemeCustom,
      _ => context.l10n.readerThemeDay,
    };
  }

  Future<void> _updateReadingSettings({
    double? fontSize,
    double? lineHeight,
    int? firstLineIndent,
    int? paragraphSpacing,
    double? horizontalMargin,
    double? topMargin,
    double? bottomMargin,
    String? themeId,
    BookSourcePageMode? pageMode,
    bool? pullBookmarkEnabled,
    bool? tapPageAnimationEnabled,
    bool? tabletTwoPageEnabled,
  }) async {
    final repaginate = fontSize != null ||
        lineHeight != null ||
        firstLineIndent != null ||
        paragraphSpacing != null ||
        horizontalMargin != null ||
        topMargin != null ||
        bottomMargin != null ||
        (tabletTwoPageEnabled != null &&
            tabletTwoPageEnabled != _tabletTwoPageEnabled) ||
        (pageMode != null && pageMode != _pageMode);
    final currentProgress = _currentReadingProgress;
    final currentTextOffset = _currentTextOffset;
    setState(() {
      _fontSize = fontSize ?? _fontSize;
      _lineHeight = (lineHeight ?? _lineHeight).clamp(1.4, 2.1);
      _firstLineIndent = (firstLineIndent ?? _firstLineIndent).clamp(0, 4);
      _paragraphSpacing = (paragraphSpacing ?? _paragraphSpacing).clamp(0, 2);
      _horizontalMargin = (horizontalMargin ?? _horizontalMargin).clamp(
        ReaderMarginSettings.horizontalMin,
        ReaderMarginSettings.horizontalMax,
      );
      _topMargin = (topMargin ?? _topMargin)
          .clamp(ReaderMarginSettings.min, ReaderMarginSettings.max);
      _bottomMargin = (bottomMargin ?? _bottomMargin)
          .clamp(ReaderMarginSettings.min, ReaderMarginSettings.max);
      _readerThemeId = ReaderThemes.byId(themeId ?? _readerThemeId).id;
      _pageMode = pageMode ?? _pageMode;
      _pullBookmarkEnabled = pullBookmarkEnabled ?? _pullBookmarkEnabled;
      _tapPageAnimationEnabled =
          tapPageAnimationEnabled ?? _tapPageAnimationEnabled;
      _tabletTwoPageEnabled = tabletTwoPageEnabled ?? _tabletTwoPageEnabled;
      if (repaginate) {
        _paginationKey = null;
        _paginatedPages = const [];
        _pagedLayouts.clear();
        _warmedPagedLayoutIndexes.clear();
        _verticalLayouts.clear();
        _restorePageProgress = currentProgress;
        _restorePagedPosition = true;
        _restoreTextOffset = currentTextOffset;
      }
    });
    unawaited(_syncVolumeKeyPaging());
    await _readerSettingsStore.save(_readerSettings);
    if (repaginate) _restoreScrollProgress(currentProgress);
  }

  Future<void> _setTopBarStyle(ReaderTopBarStyle style) async {
    if (_topBarStyle == style) return;
    final repaginate = (_topBarStyle == ReaderTopBarStyle.reader) !=
        (style == ReaderTopBarStyle.reader);
    final currentProgress = _currentReadingProgress;
    final currentTextOffset = _currentTextOffset;
    setState(() {
      _topBarStyle = style;
      if (repaginate) {
        _paginationKey = null;
        _paginatedPages = const [];
        _pagedLayouts.clear();
        _warmedPagedLayoutIndexes.clear();
        _verticalLayouts.clear();
        _restorePageProgress = currentProgress;
        _restorePagedPosition = true;
        _restoreTextOffset = currentTextOffset;
      }
    });
    await ReaderSystemUiController.savePreference(style);
    await _applyReaderSystemUi();
    if (repaginate) _restoreScrollProgress(currentProgress);
  }

  Future<void> _setScrollByChapter(bool value) async {
    if (_scrollByChapter == value) return;
    final currentProgress = _currentReadingProgress;
    setState(() {
      _scrollByChapter = value;
      _restorePageProgress = currentProgress;
      _restorePagedPosition = true;
    });
    await _readerSettingsStore.saveScrollByChapter(value);
    _restoreScrollProgress(currentProgress);
  }

  String _pageModeSummary() {
    if (_pageMode == BookSourcePageMode.verticalScroll) {
      return _scrollByChapter
          ? context.l10n.readerModeVerticalScrollHint
          : context.l10n.readerModeWholeBookScrollHint;
    }
    return _pageModeHint(_pageMode);
  }

  String _pageModeTitle(BookSourcePageMode mode) => switch (mode) {
        BookSourcePageMode.verticalScroll => context.l10n.pageTurningScroll,
        BookSourcePageMode.instantPage => context.l10n.readerModeHorizontalPage,
        BookSourcePageMode.horizontalSlide => context.l10n.pageTurningSlide,
        BookSourcePageMode.pageCurl => context.l10n.readerModePageCurl,
      };

  String _pageModeHint(BookSourcePageMode mode) => switch (mode) {
        BookSourcePageMode.verticalScroll =>
          context.l10n.readerModeVerticalScrollHint,
        BookSourcePageMode.instantPage =>
          context.l10n.readerModeHorizontalPageHint,
        BookSourcePageMode.horizontalSlide =>
          context.l10n.readerModeHorizontalSlideHint,
        BookSourcePageMode.pageCurl => context.l10n.readerModePageCurlHint,
      };

  String _topBarStyleTitle(ReaderTopBarStyle style) => switch (style) {
        ReaderTopBarStyle.system => context.l10n.readerTopBarStyleSystem,
        ReaderTopBarStyle.reader => context.l10n.readerTopBarStyleReader,
        ReaderTopBarStyle.hidden => context.l10n.readerTopBarStyleHidden,
      };

  String _topBarStyleHint(ReaderTopBarStyle style) => switch (style) {
        ReaderTopBarStyle.system => context.l10n.readerTopBarStyleSystemHint,
        ReaderTopBarStyle.reader => context.l10n.readerTopBarStyleReaderHint,
        ReaderTopBarStyle.hidden => context.l10n.readerTopBarStyleHiddenHint,
      };

  Future<void> _showReadingSettings() async {
    _controlsTimer?.cancel();
    final selectedMode = await showModalBottomSheet<BookSourcePageMode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => ReaderSettingsSheet(
        title: context.l10n.readingSettings,
        themeTitle: context.l10n.readerThemeTitle,
        themeDescription: context.l10n.readerThemeDescription,
        pageModeTitle: context.l10n.pageTurningMode,
        pageModeSummary: _pageModeSummary(),
        topBarStyleTitle: context.l10n.readerTopBarStyleTitle,
        topBarStyleSummary: _topBarStyleTitle(_topBarStyle),
        pullBookmarkTitle: context.l10n.readerPullBookmarkTitle,
        pullBookmarkHint: context.l10n.readerPullBookmarkHint,
        tapPageAnimationTitle: context.l10n.readerTapAnimationTitle,
        tapPageAnimationHint: context.l10n.readerTapAnimationHint,
        showTabletTwoPageToggle: ReaderLayoutBreakpoints.isTablet(
          MediaQuery.sizeOf(context),
        ),
        tabletTwoPageTitle: context.l10n.readerTabletTwoPageTitle,
        tabletTwoPageHint: context.l10n.readerTabletTwoPageHint,
        fontSizeLabel: context.l10n.fontSizeLabel,
        lineHeightLabel: context.l10n.lineSpacingLabel,
        firstLineIndentLabel: context.l10n.firstLineIndentLabel,
        paragraphSpacingLabel: context.l10n.paragraphSpacingLabel,
        horizontalMarginLabel: context.l10n.readerHorizontalMarginLabel,
        topMarginLabel: context.l10n.readerTopMarginLabel,
        bottomMarginLabel: context.l10n.readerBottomMarginLabel,
        themeId: _readerThemeId,
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        firstLineIndent: _firstLineIndent,
        paragraphSpacing: _paragraphSpacing,
        horizontalMargin: _horizontalMargin,
        topMargin: _topMargin,
        bottomMargin: _bottomMargin,
        pullBookmarkEnabled: _pullBookmarkEnabled,
        tapPageAnimationEnabled: _tapPageAnimationEnabled,
        tabletTwoPageEnabled: _tabletTwoPageEnabled,
        themeLabelFor: _readerThemeName,
        onThemeChanged: (themeId) => unawaited(
          _updateReadingSettings(themeId: themeId),
        ),
        onCustomThemeTap: _showCustomThemeEditor,
        onPageModeTap: _showPageModeSettings,
        onTopBarStyleTap: _showTopBarStyleSettings,
        onFontSizeChanged: (value) => unawaited(
          _updateReadingSettings(fontSize: value),
        ),
        onLineHeightChanged: (value) => unawaited(
          _updateReadingSettings(lineHeight: value),
        ),
        onFirstLineIndentChanged: (value) => unawaited(
          _updateReadingSettings(firstLineIndent: value),
        ),
        onParagraphSpacingChanged: (value) => unawaited(
          _updateReadingSettings(paragraphSpacing: value),
        ),
        onHorizontalMarginChanged: (value) => unawaited(
          _updateReadingSettings(horizontalMargin: value),
        ),
        onTopMarginChanged: (value) => unawaited(
          _updateReadingSettings(topMargin: value),
        ),
        onBottomMarginChanged: (value) => unawaited(
          _updateReadingSettings(bottomMargin: value),
        ),
        onPullBookmarkChanged: (value) => unawaited(
          _updateReadingSettings(pullBookmarkEnabled: value),
        ),
        onTapPageAnimationChanged: (value) => unawaited(
          _updateReadingSettings(tapPageAnimationEnabled: value),
        ),
        onTabletTwoPageChanged: (value) => unawaited(
          _updateReadingSettings(tabletTwoPageEnabled: value),
        ),
      ),
    );
    if (mounted) setState(() => _controlsVisible = false);
    if (!mounted) return;
    await _applyReaderSystemUi();
    if (selectedMode == null || !mounted) return;
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _updateReadingSettings(pageMode: selectedMode);
  }

  Future<void> _showCustomThemeEditor() async {
    Navigator.of(context).pop();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final result = await Navigator.of(context).push<ReaderCustomThemesResult>(
      MaterialPageRoute(
        builder: (_) => ReaderCustomThemesPage(
          initialThemes: ReaderThemes.customThemes,
          initialThemeOrder: ReaderThemes.themeOrder,
          initialSelectedThemeId: _readerThemeId,
        ),
      ),
    );
    if (result == null || !mounted) return;
    ReaderThemes.setCustomThemes(result.themes);
    ReaderThemes.setThemeOrder(result.themeOrder);
    final nextThemeId = result.selectedThemeId ??
        (ReaderCustomTheme.isCustomThemeId(_readerThemeId) &&
                ReaderThemes.customThemeById(_readerThemeId) == null
            ? ReaderSettings.defaultThemeId
            : _readerThemeId);
    await _updateReadingSettings(themeId: nextThemeId);
    await _applyReaderSystemUi();
  }

  Future<void> _showPageModeSettings() async {
    var previewScrollByChapter = _scrollByChapter;
    final selectedMode = await showModalBottomSheet<BookSourcePageMode>(
      context: context,
      backgroundColor: _readerTheme.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (menuContext) => StatefulBuilder(
        builder: (context, setMenuState) => ReaderPageModeSheet(
          palette: _readerTheme,
          title: context.l10n.pageTurningMode,
          selectedMode: _pageMode,
          titleFor: _pageModeTitle,
          hintFor: (mode) => mode == BookSourcePageMode.verticalScroll
              ? (previewScrollByChapter
                  ? context.l10n.readerModeVerticalScrollHint
                  : context.l10n.readerModeWholeBookScrollHint)
              : _pageModeHint(mode),
          onSelected: (mode) => Navigator.of(menuContext).pop(mode),
          scrollByChapter: previewScrollByChapter,
          scrollByChapterTitle: context.l10n.readerScrollByChapterTitle,
          scrollByChapterOnHint: context.l10n.readerScrollByChapterOnHint,
          scrollByChapterOffHint: context.l10n.readerScrollByChapterOffHint,
          onScrollByChapterChanged: (value) {
            setMenuState(() => previewScrollByChapter = value);
            unawaited(_setScrollByChapter(value));
          },
        ),
      ),
    );
    if (selectedMode == null || !mounted) return;
    Navigator.of(context).pop(selectedMode);
  }

  Future<void> _showTopBarStyleSettings() async {
    final selectedStyle = await showModalBottomSheet<ReaderTopBarStyle>(
      context: context,
      backgroundColor: _readerTheme.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (menuContext) => ReaderTopBarStyleSheet(
        palette: _readerTheme,
        title: context.l10n.readerTopBarStyleTitle,
        selectedStyle: _topBarStyle,
        titleFor: _topBarStyleTitle,
        hintFor: _topBarStyleHint,
        onSelected: (style) => Navigator.of(menuContext).pop(style),
      ),
    );
    if (selectedStyle == null || !mounted) return;
    Navigator.of(context).pop();
    await _setTopBarStyle(selectedStyle);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('reader-system-ui-region'),
      value: SystemUiHelper.overlayStyleForBackground(
        _readerTheme.background,
      ),
      child: PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_requestExit());
        },
        child: Theme(
          data: _readerThemeData,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            // The reader page has no text field of its own, but Scaffold
            // shrinks `body` for ANY keyboard inset by default, including
            // one raised by a TextField inside a modal sheet stacked on top
            // (e.g. the TOC search box). That resize changes the layout
            // constraints the pagination below reacts to on every animation
            // frame, forcing a full chapter re-pagination each frame.
            resizeToAvoidBottomInset: false,
            body: ReaderThemeBackground(
              palette: _readerTheme,
              child: ReaderPullBookmark(
                enabled: _pullBookmarkEnabled && _chapters.isNotEmpty,
                bookmarked: _currentPageIsBookmarked,
                busy: _bookmarkBusy,
                palette: _readerTheme,
                addHint: context.l10n.readerPullBookmarkAddHint,
                removeHint: context.l10n.readerPullBookmarkRemoveHint,
                releaseHint: context.l10n.readerPullBookmarkReleaseHint,
                onTriggered: () => unawaited(_toggleCurrentBookmark()),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        label: widget.book.title,
                        child: _buildBody(),
                      ),
                    ),
                    ReaderChromeOverlay(
                      palette: _readerTheme,
                      visible: _controlsVisible,
                      title: _chapters.isEmpty
                          ? widget.book.title
                          : _chapters[
                                  _chapterIndex.clamp(0, _chapters.length - 1)]
                              .title,
                      statusBottom: _readerSafeArea.pageNumberBottom,
                      showViewportStatus:
                          _pageMode == BookSourcePageMode.verticalScroll,
                      showViewportTitle:
                          _pageMode == BookSourcePageMode.verticalScroll &&
                              _topBarStyle == ReaderTopBarStyle.reader,
                      viewportTitleTop: _readerSafeArea.readerTopBarTop,
                      viewportTitleKey:
                          const ValueKey('book-source-viewport-title'),
                      readerStatus: _leafStatusController.value,
                      viewportStatusHorizontalPadding:
                          math.max(24, _horizontalMargin),
                      statusBuilder: _buildReaderStatusText,
                      onBack: () => unawaited(_requestExit()),
                      onBookmark: _chapters.isEmpty
                          ? null
                          : () => unawaited(_toggleCurrentBookmark()),
                      onTableOfContents:
                          _chapters.isEmpty ? null : _showCatalog,
                      onSettings: _showReadingSettings,
                      backTooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      bookmarkTooltip: _currentPageIsBookmarked
                          ? context.l10n.bookmarkRemoved
                          : context.l10n.readerAddBookmark,
                      tableOfContentsTooltip: context.l10n.readerToolbarTOC,
                      settingsTooltip: context.l10n.readingSettings,
                      bookmarked: _currentPageIsBookmarked,
                      bookmarkBusy: _bookmarkBusy,
                      topKey: const ValueKey('book-source-top-controls'),
                      bottomKey: const ValueKey('book-source-bottom-controls'),
                      statusKey: const ValueKey('book-source-reader-status'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingCatalog || (_loadingContent && _content == null)) {
      return Center(
        child: CircularProgressIndicator(color: _readerTheme.accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: _readerTheme.secondaryText,
              ),
              const SizedBox(height: 12),
              Text(
                _error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _chapters.isEmpty
                    ? _initialize
                    : () => _loadChapter(
                          _chapterIndex,
                          saveCurrent: false,
                        ),
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }
    if (_chapters.isEmpty || _content == null) {
      return Center(child: Text(context.l10n.readerNoContent));
    }

    final content = _content!;
    if (_pageMode == BookSourcePageMode.verticalScroll) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.biggest;
          _verticalViewportSize = viewport;
          if (!_scrollByChapter) {
            return _buildVerticalReadingWindow(
              _buildVerticalBook(viewport),
            );
          }
          final layout = _verticalLayoutFor(
            _chapterIndex,
            content,
            viewport,
          );
          return _buildVerticalReadingWindow(
            _buildVerticalPageList(layout, viewport),
          );
        },
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final usesTwoPageLayout = _shouldUseTwoPageLayout(constraints.biggest);
        _usesTwoPageLayout = usesTwoPageLayout;
        final paginationViewport =
            _paginationViewport(constraints.biggest, usesTwoPageLayout);
        if (_pagedViewportSize != paginationViewport) {
          _pagedViewportSize = paginationViewport;
          _warmedPagedLayoutIndexes.clear();
        }
        _ensurePagination(
          paginationViewport,
          content: content,
        );
        _schedulePagedLayoutWarm(_chapterIndex + 1);
        return switch (_pageMode) {
          BookSourcePageMode.instantPage => _buildInstantReader(),
          BookSourcePageMode.horizontalSlide => _buildSlideReader(),
          BookSourcePageMode.pageCurl => _buildCurlReader(
              usesTwoPageLayout: usesTwoPageLayout,
            ),
          BookSourcePageMode.verticalScroll => const SizedBox.shrink(),
        };
      },
    );
  }

  TextStyle get _bodyTextStyle => TextStyle(
        inherit: false,
        fontFamily: _readerFont.family,
        fontFamilyFallback: _readerFont.fallbackFamilies.isEmpty
            ? null
            : _readerFont.fallbackFamilies,
        color: _readerTheme.text,
        fontSize: _fontSize,
        height: _lineHeight,
        letterSpacing: 0.2,
      );

  NativeTextFlowStyle _bodyTextFlowStyle({
    TextDirection? direction,
    TextScaler? textScaler,
    Locale? locale,
  }) =>
      NativeTextFlowStyle(
        textDirection: direction ?? Directionality.of(context),
        textScaler: textScaler ?? MediaQuery.textScalerOf(context),
        locale: locale ?? Localizations.maybeLocaleOf(context),
        strutStyle: readerStrutStyle(_bodyTextStyle),
        textHeightBehavior: readerTextHeightBehavior,
      );

  ReaderViewportChromeMetrics get _verticalChrome =>
      ReaderViewportChromeMetrics(safeArea: _readerSafeArea);

  double _verticalPageExtentFor(Size viewport) =>
      _verticalChrome.contentHeight(viewport.height);

  Widget _buildVerticalReadingWindow(Widget child) {
    final chrome = _verticalChrome;
    return Padding(
      key: const ValueKey('book-source-vertical-reading-window'),
      padding: EdgeInsets.only(
        top: chrome.contentTop,
        bottom: chrome.contentBottom,
      ),
      child: ClipRect(child: child),
    );
  }

  ReaderVisibleItemPosition _readerPosition(ItemPosition position) =>
      ReaderVisibleItemPosition(
        index: position.index,
        leadingEdge: position.itemLeadingEdge,
        trailingEdge: position.itemTrailingEdge,
      );

  _BookSourceVerticalLayout _verticalLayoutFor(
    int chapterIndex,
    BookSourceChapterContent content,
    Size viewport,
  ) {
    final chrome = _verticalChrome;
    final width = readerTextContentWidth(
      viewport.width,
      _horizontalMargin,
    );
    final height = _verticalPageExtentFor(viewport);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final direction = Directionality.of(context);
    final fingerprint = ReaderLayoutFingerprint(
      contentKey: _chapters[chapterIndex].id,
      viewport: Size(width, height),
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      horizontalMargin: _horizontalMargin,
      verticalMargin: _topMargin + _bottomMargin,
      textScaler: textScaler,
      locale: locale,
      pageMode: BookSourcePageMode.verticalScroll,
      firstLineIndent: _firstLineIndent,
      paragraphSpacing: _paragraphSpacing,
      textDirection: direction,
      extra: '${chrome.paginationSignature}:${_readerFont.id}',
    ).cacheKey('book-source-vertical-v2');
    final cached = _verticalLayouts[chapterIndex];
    if (cached?.fingerprint == fingerprint) return cached!;
    final pages = paginateBookSourceText(
      readableBookSourceChapterText(
        content,
        fallbackTitle: _chapters[chapterIndex].title,
      ),
      width: width,
      firstPageHeight: height,
      pageHeight: height,
      style: _bodyTextStyle,
      textDirection: direction,
      textScaler: textScaler,
      locale: locale,
      firstLineIndent: _firstLineIndent,
      paragraphSpacing: _paragraphSpacing,
      includeChapterTitlePage: true,
    );
    final layout = _BookSourceVerticalLayout(
      fingerprint: fingerprint,
      pages: pages,
    );
    _verticalLayouts[chapterIndex] = layout;
    return layout;
  }

  void _restoreVerticalPosition(
    _BookSourceVerticalLayout layout, {
    required bool wholeBook,
  }) {
    if (!_restorePagedPosition) return;
    final target = _restoreTextOffset != null
        ? bookSourcePageIndexForOffset(layout.pages, _restoreTextOffset!)
        : ((layout.pages.length - 1) * _restorePageProgress).round();
    _verticalPageCount = layout.pages.length;
    _verticalPageIndex = target.clamp(0, layout.pages.length - 1);
    _pageIndex = _verticalPageIndex;
    _restorePagedPosition = false;
    _restoreTextOffset = null;
    final restoredProgress = _verticalPageCount <= 1
        ? 0.0
        : _verticalPageIndex / (_verticalPageCount - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollProgress.value = restoredProgress;
      if (!wholeBook && _verticalPageScrollController.isAttached) {
        _verticalPageScrollController.jumpTo(index: _verticalPageIndex);
        return;
      }
      if (!_verticalChapterScrollController.isAttached) return;
      _verticalChapterScrollController.jumpTo(index: _chapterIndex);
      if (_verticalPageIndex > 0) {
        unawaited(
          _verticalChapterOffsetController.animateScroll(
            offset: _verticalPageIndex *
                _verticalPageExtentFor(_verticalViewportSize),
            duration: const Duration(milliseconds: 1),
          ),
        );
      }
    });
  }

  void _onVerticalPagePositionsChanged() {
    if (!mounted ||
        _pageMode != BookSourcePageMode.verticalScroll ||
        !_scrollByChapter) {
      return;
    }
    final layout = _verticalLayouts[_chapterIndex];
    if (layout == null || layout.pages.isEmpty) return;
    final primary = pickPrimaryReaderItem(
      _verticalPagePositionsListener.itemPositions.value.map(_readerPosition),
    );
    if (primary == null) return;
    final nextPage = primary.index.clamp(0, layout.pages.length - 1);
    _verticalPageCount = layout.pages.length;
    _verticalPageIndex = nextPage;
    _scrollProgress.value = _verticalPageCount <= 1
        ? 0
        : (nextPage / (_verticalPageCount - 1)).clamp(0.0, 1.0);
    if (nextPage != _pageIndex) {
      if (nextPage > _pageIndex) _sessionPagesRead++;
      setState(() => _pageIndex = nextPage);
    }
    _scheduleProgressSave();
  }

  void _onVerticalChapterPositionsChanged() {
    if (!mounted ||
        _pageMode != BookSourcePageMode.verticalScroll ||
        _scrollByChapter ||
        _chapters.isEmpty ||
        _verticalViewportSize.isEmpty) {
      return;
    }
    final primary = pickPrimaryReaderItem(
      _verticalChapterPositionsListener.itemPositions.value
          .map(_readerPosition),
    );
    if (primary == null) return;
    final nextChapter = primary.index.clamp(0, _chapters.length - 1);
    final content = _prefetchedContent[nextChapter];
    if (content == null) {
      unawaited(_continuousContentFor(nextChapter));
      return;
    }
    final layout = _verticalLayoutFor(
      nextChapter,
      content,
      _verticalViewportSize,
    );
    final nextPage = readerPageIndexWithinItem(primary, layout.pages.length);
    final movedForward = nextChapter > _chapterIndex ||
        (nextChapter == _chapterIndex && nextPage > _verticalPageIndex);
    final chapterChanged = nextChapter != _chapterIndex;
    _verticalPageCount = layout.pages.length;
    _verticalPageIndex = nextPage;
    _scrollProgress.value = _verticalPageCount <= 1
        ? 0
        : (nextPage / (_verticalPageCount - 1)).clamp(0.0, 1.0);
    if (chapterChanged || nextPage != _pageIndex || _content != content) {
      if (movedForward) _sessionPagesRead++;
      setState(() {
        _chapterIndex = nextChapter;
        _content = content;
        _pageIndex = nextPage;
      });
    }
    if (chapterChanged) unawaited(_preloadAround(nextChapter));
    _scheduleProgressSave();
  }

  Widget _buildVerticalPageCell(
    BookSourceTextPage page,
    Size viewport,
    String chapterTitle,
  ) {
    return SizedBox(
      key: ValueKey(
        'book-source-vertical-page:${page.startOffset}:${page.endOffset}:'
        '${page.isChapterTitle}',
      ),
      height: _verticalPageExtentFor(viewport),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _horizontalMargin,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: readerMaxTextContentWidth,
            ),
            child: SizedBox.expand(
              child: ReaderTextPageContent(
                page: page,
                chapterTitle: chapterTitle,
                bodyStyle: _bodyTextStyle,
                flowStyle: _bodyTextFlowStyle(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalChapter(
    int chapterIndex,
    Size viewport,
  ) {
    final cached = _prefetchedContent[chapterIndex];
    Widget buildContent(BookSourceChapterContent content) {
      final layout = _verticalLayoutFor(chapterIndex, content, viewport);
      final chapterTitle =
          content.title.isEmpty ? _chapters[chapterIndex].title : content.title;
      return Column(
        children: [
          for (final page in layout.pages)
            _buildVerticalPageCell(page, viewport, chapterTitle),
        ],
      );
    }

    if (cached != null) return buildContent(cached);
    return FutureBuilder<BookSourceChapterContent>(
      future: _continuousContentFor(chapterIndex),
      builder: (context, snapshot) {
        final content = snapshot.data;
        if (content != null) return buildContent(content);
        if (snapshot.hasError) {
          return SizedBox(
            height: _verticalPageExtentFor(viewport),
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _continuousContentLoads.remove(chapterIndex));
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.retry),
              ),
            ),
          );
        }
        return SizedBox(
          height: _verticalPageExtentFor(viewport),
          child: Center(
            child: CircularProgressIndicator(color: _readerTheme.accent),
          ),
        );
      },
    );
  }

  Widget _buildVerticalPageList(
    _BookSourceVerticalLayout layout,
    Size viewport,
  ) {
    final layoutStateChanged = _verticalPageCount != layout.pages.length ||
        _verticalPageIndex >= layout.pages.length;
    _verticalPageCount = layout.pages.length;
    _verticalPageIndex = _verticalPageIndex.clamp(0, layout.pages.length - 1);
    _pageIndex = _verticalPageIndex;
    if (layoutStateChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    _restoreVerticalPosition(layout, wholeBook: false);
    return ReaderVerticalPagingSurface(
      surfaceKey: const ValueKey('book-source-reader-surface'),
      onTap: _toggleControls,
      onHorizontalDragEnd: _handleHorizontalSwipe,
      child: ScrollablePositionedList.builder(
        key: ValueKey(
          'source-vertical-pages:$_chapterIndex:${layout.fingerprint}',
        ),
        itemScrollController: _verticalPageScrollController,
        itemPositionsListener: _verticalPagePositionsListener,
        initialScrollIndex:
            _verticalPageIndex.clamp(0, layout.pages.length - 1),
        minCacheExtent: _verticalPageExtentFor(viewport),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: layout.pages.length,
        itemBuilder: (context, index) => _buildVerticalPageCell(
          layout.pages[index],
          viewport,
          _content!.title.isEmpty
              ? _chapters[_chapterIndex].title
              : _content!.title,
        ),
      ),
    );
  }

  Widget _buildVerticalBook(Size viewport) {
    final content = _prefetchedContent[_chapterIndex] ?? _content!;
    final currentLayout = _verticalLayoutFor(
      _chapterIndex,
      content,
      viewport,
    );
    final layoutStateChanged =
        _verticalPageCount != currentLayout.pages.length ||
            _verticalPageIndex >= currentLayout.pages.length;
    _verticalPageCount = currentLayout.pages.length;
    _verticalPageIndex =
        _verticalPageIndex.clamp(0, currentLayout.pages.length - 1);
    _pageIndex = _verticalPageIndex;
    if (layoutStateChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    _restoreVerticalPosition(currentLayout, wholeBook: true);
    return ReaderVerticalPagingSurface(
      surfaceKey: const ValueKey('book-source-reader-surface'),
      onTap: _toggleControls,
      child: ScrollablePositionedList.builder(
        key: ValueKey(
          'source-vertical-book:${viewport.width.toStringAsFixed(1)}:'
          '${viewport.height.toStringAsFixed(1)}:'
          '${_fontSize.toStringAsFixed(1)}:${_lineHeight.toStringAsFixed(2)}:'
          '$_firstLineIndent:$_paragraphSpacing:${_readerFont.id}:'
          '${_verticalChrome.paginationSignature}',
        ),
        itemScrollController: _verticalChapterScrollController,
        scrollOffsetController: _verticalChapterOffsetController,
        itemPositionsListener: _verticalChapterPositionsListener,
        initialScrollIndex: _chapterIndex.clamp(0, _chapters.length - 1),
        minCacheExtent: _verticalPageExtentFor(viewport),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: _chapters.length,
        itemBuilder: (context, index) => _buildVerticalChapter(index, viewport),
      ),
    );
  }

  _BookSourcePagedLayout _pagedLayoutFor(
    int chapterIndex,
    BookSourceChapterContent content,
    Size viewport,
  ) {
    final top = _readerSafeArea.contentTop;
    final bottom = _readerSafeArea.contentBottom;
    final width = readerTextContentWidth(
      viewport.width,
      _horizontalMargin,
    );
    final height = readerTextContentHeight(viewport.height, top, bottom);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final key = ReaderLayoutFingerprint(
      contentKey: _chapters[chapterIndex].id,
      viewport: Size(width, height),
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      horizontalMargin: _horizontalMargin,
      verticalMargin: _topMargin + _bottomMargin,
      textScaler: textScaler,
      locale: locale,
      pageMode: _pageMode,
      firstLineIndent: _firstLineIndent,
      paragraphSpacing: _paragraphSpacing,
      textDirection: Directionality.of(context),
      extra: '${_readerSafeArea.paginationSignature}:${_readerFont.id}',
    ).cacheKey('book-source-line-v5');
    final cached = _pagedLayouts[chapterIndex];
    if (cached?.fingerprint == key) return cached!;
    final pages = paginateBookSourceText(
      readableBookSourceChapterText(
        content,
        fallbackTitle: _chapters[chapterIndex].title,
      ),
      width: width,
      firstPageHeight: height,
      pageHeight: height,
      style: _bodyTextStyle,
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      locale: locale,
      firstLineIndent: _firstLineIndent,
      paragraphSpacing: _paragraphSpacing,
      includeChapterTitlePage: true,
    );
    final layout = _BookSourcePagedLayout(
      fingerprint: key,
      pages: pages,
    );
    _pagedLayouts[chapterIndex] = layout;
    return layout;
  }

  void _ensurePagination(
    Size viewport, {
    required BookSourceChapterContent content,
  }) {
    final layout = _pagedLayoutFor(_chapterIndex, content, viewport);
    final key = layout.fingerprint;
    if (_paginationKey == key && _paginatedPages.isNotEmpty) return;
    final currentTextOffset = _paginatedPages.isEmpty
        ? null
        : _paginatedPages[_pageIndex.clamp(0, _paginatedPages.length - 1)]
            .startOffset;
    final pages = layout.pages;
    _paginationKey = key;
    _paginatedPages = pages;
    _pageCount = pages.length;
    final restoredTarget = _restoreTextOffset != null
        ? bookSourcePageIndexForOffset(pages, _restoreTextOffset!)
        : _restorePagedPosition
            ? ((_pageCount - 1) * _restorePageProgress).round()
            : currentTextOffset != null
                ? bookSourcePageIndexForOffset(pages, currentTextOffset)
                : _pageIndex.clamp(0, _pageCount - 1);
    final target = _usesTwoPageLayout
        ? _spreadStartForPage(restoredTarget)
        : restoredTarget;
    _pageIndex = target.clamp(0, _pageCount - 1);
    _restorePagedPosition = false;
    _restoreTextOffset = null;
    final pageProgress = _pagedReadingProgress(_pageIndex, _pageCount);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollProgress.value = pageProgress;
      if (_pageMode == BookSourcePageMode.verticalScroll) {
        _verticalPageCount = _pageCount;
        _verticalPageIndex =
            (pageProgress * (_verticalPageCount - 1)).round().clamp(
                  0,
                  _verticalPageCount - 1,
                );
      }
      setState(() {});
      if (_pageMode != BookSourcePageMode.horizontalSlide) return;
      _pageViewLeading = _chapterIndex > 0 ? 1 : 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_pageIndex + _pageViewLeading);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ignoreSlidePageChanges = false;
      });
    });
  }

  Widget _buildPageLeaf(
    BookSourceTextPage page, {
    required int pageIndex,
    required int pageCount,
    required String layoutFingerprint,
    int? chapterIndex,
    BookSourceChapterContent? chapterContent,
    ReaderPageNumberPlacement pageNumberPlacement =
        ReaderPageNumberPlacement.bottomRight,
    ReaderTopInformationLayout topInformationLayout =
        ReaderTopInformationLayout.full,
  }) {
    final resolvedIndex = chapterIndex ?? _chapterIndex;
    final resolvedContent = chapterContent ?? _content!;
    final chapterTitle = resolvedContent.title.isEmpty
        ? _chapters[resolvedIndex].title
        : resolvedContent.title;
    final metadata = ReaderPaperPageMetadata(
      pageIdentity: 'source:${widget.source.id}:${widget.book.id}:'
          '${_chapters[resolvedIndex].id}:$pageIndex:${page.startOffset}',
      layoutFingerprint: layoutFingerprint,
      themeId: _readerTheme.cacheKey,
      chapterTitle: chapterTitle,
      pageNumber: pageIndex + 1,
      pageCount: pageCount,
    );
    return ReaderPaperPageLeaf(
      palette: _readerTheme,
      safeArea: _readerSafeArea,
      metadata: metadata,
      pageNumberPlacement: pageNumberPlacement,
      horizontalPadding: math.max(14, _horizontalMargin),
      pageNumberHorizontalPadding: math.max(24, _horizontalMargin),
      showTopInformation: _topBarStyle == ReaderTopBarStyle.reader,
      topInformationLayout: topInformationLayout,
      status: _leafStatusController.value,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _horizontalMargin,
          _readerSafeArea.contentTop,
          _horizontalMargin,
          _readerSafeArea.contentBottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: readerMaxTextContentWidth,
            ),
            child: SizedBox.expand(
              child: ReaderTextPageContent(
                page: page,
                chapterTitle: chapterTitle,
                bodyStyle: _bodyTextStyle,
                flowStyle: _bodyTextFlowStyle(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ReaderPageSnapshot _buildPageSnapshot(
    BookSourceTextPage page, {
    required int pageIndex,
    required int pageCount,
    required String layoutFingerprint,
    int? chapterIndex,
    BookSourceChapterContent? chapterContent,
    ReaderPageNumberPlacement pageNumberPlacement =
        ReaderPageNumberPlacement.bottomRight,
    ReaderTopInformationLayout topInformationLayout =
        ReaderTopInformationLayout.full,
  }) {
    final resolvedIndex = chapterIndex ?? _chapterIndex;
    final metadata = ReaderPaperPageMetadata(
      pageIdentity: 'source:${widget.source.id}:${widget.book.id}:'
          '${_chapters[resolvedIndex].id}:$pageIndex:${page.startOffset}',
      layoutFingerprint: layoutFingerprint,
      themeId: _readerTheme.cacheKey,
      chapterTitle: (chapterContent ?? _content!).title.isEmpty
          ? _chapters[resolvedIndex].title
          : (chapterContent ?? _content!).title,
      pageNumber: pageIndex + 1,
      pageCount: pageCount,
    );
    return ReaderPageSnapshot(
      key: metadata.snapshotKey,
      contentRevision: _topBarStyle == ReaderTopBarStyle.reader
          ? _leafStatusController.value.revision
          : 0,
      child: _buildPageLeaf(
        page,
        pageIndex: pageIndex,
        pageCount: pageCount,
        layoutFingerprint: layoutFingerprint,
        chapterIndex: chapterIndex,
        chapterContent: chapterContent,
        pageNumberPlacement: pageNumberPlacement,
        topInformationLayout: topInformationLayout,
      ),
    );
  }

  ({
    BookSourceTextPage page,
    int pageIndex,
    int pageCount,
    String layoutFingerprint,
    BookSourceChapterContent content,
  })? _adjacentPageData(
    int chapterIndex,
    Size viewport, {
    required int Function(int pageCount) selectPageIndex,
  }) {
    final content = _prefetchedContent[chapterIndex];
    if (content == null) return null;
    final layout = _pagedLayoutFor(chapterIndex, content, viewport);
    final pages = layout.pages;
    final pageIndex = selectPageIndex(pages.length);
    if (pageIndex < 0 || pageIndex >= pages.length) return null;
    return (
      page: pages[pageIndex],
      pageIndex: pageIndex,
      pageCount: pages.length,
      layoutFingerprint: layout.fingerprint,
      content: content,
    );
  }

  Widget? _buildAdjacentPreview(
    int chapterIndex, {
    required bool lastPage,
  }) {
    if (_prefetchedContent[chapterIndex] == null) return null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final data = _adjacentPageData(
          chapterIndex,
          constraints.biggest,
          selectPageIndex: lastPage ? (pageCount) => pageCount - 1 : (_) => 0,
        );
        if (data == null) return const SizedBox.shrink();
        return _buildPageLeaf(
          data.page,
          pageIndex: data.pageIndex,
          pageCount: data.pageCount,
          layoutFingerprint: data.layoutFingerprint,
          chapterIndex: chapterIndex,
          chapterContent: data.content,
        );
      },
    );
  }

  Widget _buildBoundaryLeaf({
    required bool forward,
    ReaderTopInformationLayout topInformationLayout =
        ReaderTopInformationLayout.full,
    String slotIdentity = '',
  }) {
    final targetChapterIndex = _chapterIndex + (forward ? 1 : -1);
    final chapterTitle =
        targetChapterIndex >= 0 && targetChapterIndex < _chapters.length
            ? _chapters[targetChapterIndex].title
            : '';
    return ReaderPaperPageLeaf(
      palette: _readerTheme,
      safeArea: _readerSafeArea,
      metadata: ReaderPaperPageMetadata(
        pageIdentity: 'source:${widget.source.id}:${widget.book.id}:'
            'boundary:${forward ? 'forward' : 'backward'}'
            '${slotIdentity.isEmpty ? '' : ':$slotIdentity'}',
        layoutFingerprint: _paginationKey ?? 'unpaginated',
        themeId: _readerTheme.cacheKey,
        chapterTitle: chapterTitle,
        pageNumber: 0,
        pageCount: 0,
      ),
      horizontalPadding: math.max(14, _horizontalMargin),
      showTopInformation: _topBarStyle == ReaderTopBarStyle.reader,
      topInformationLayout: topInformationLayout,
      showPageNumber: false,
      status: _leafStatusController.value,
      child: Center(
        child: Icon(
          forward
              ? Icons.arrow_forward_ios_rounded
              : Icons.arrow_back_ios_new_rounded,
          color: _readerTheme.secondaryText.withValues(alpha: 0.38),
        ),
      ),
    );
  }

  ReaderPageSnapshot _buildBoundarySnapshot({
    required bool forward,
    ReaderTopInformationLayout topInformationLayout =
        ReaderTopInformationLayout.full,
    String slotIdentity = '',
  }) =>
      ReaderPageSnapshot(
        key: ReaderPageSnapshotKey(
          pageIdentity: 'source:${widget.source.id}:${widget.book.id}:'
              'boundary:${forward ? 'forward' : 'backward'}'
              '${slotIdentity.isEmpty ? '' : ':$slotIdentity'}',
          layoutFingerprint: _paginationKey ?? 'unpaginated',
          themeId: _readerTheme.cacheKey,
        ),
        contentRevision: _topBarStyle == ReaderTopBarStyle.reader
            ? _leafStatusController.value.revision
            : 0,
        child: _buildBoundaryLeaf(
          forward: forward,
          topInformationLayout: topInformationLayout,
          slotIdentity: slotIdentity,
        ),
      );

  void _handlePageTap(TapUpDetails details, double width) {
    final x = details.localPosition.dx / width;
    if (x < 0.28) {
      unawaited(_turnFromTap(forward: false));
    } else if (x > 0.72) {
      unawaited(_turnFromTap(forward: true));
    } else {
      _toggleControls();
    }
  }

  Future<void> _turnFromTap({required bool forward}) async {
    if (!_tapPageAnimationEnabled ||
        _pageMode == BookSourcePageMode.instantPage) {
      if (forward) {
        await _turnForward();
      } else {
        await _turnBackward();
      }
      return;
    }
    if (_pageMode == BookSourcePageMode.horizontalSlide &&
        _pageController.hasClients) {
      if (forward) {
        await _pageController.nextPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        await _pageController.previousPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    if (_pageMode == BookSourcePageMode.pageCurl) {
      final controller = _usesTwoPageLayout
          ? (forward
              ? _spreadForwardPageCurlController
              : _spreadBackwardPageCurlController)
          : _pageCurlController;
      if (forward) {
        await controller.turnForward();
      } else {
        await controller.turnBackward();
      }
      return;
    }
    if (forward) {
      await _turnForward();
    } else {
      await _turnBackward();
    }
  }

  Widget _buildInstantReader() => LayoutBuilder(
        builder: (context, constraints) => Semantics(
          label: _pageModeHint(BookSourcePageMode.instantPage),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _handlePageTap(details, constraints.maxWidth),
            onHorizontalDragEnd: _handlePagedSwipe,
            child: _buildPageLeaf(
              _paginatedPages[_pageIndex],
              pageIndex: _pageIndex,
              pageCount: _pageCount,
              layoutFingerprint: _paginationKey!,
            ),
          ),
        ),
      );

  Widget _buildSlideReader() {
    _pageViewLeading = _chapterIndex > 0 ? 1 : 0;
    final trailing = _chapterIndex + 1 < _chapters.length ? 1 : 0;
    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        _commitPendingSlideChapter();
        return false;
      },
      child: PageView.builder(
        key: ValueKey('source-slide:${_chapters[_chapterIndex].id}'),
        controller: _pageController,
        itemCount: _pageViewLeading + _pageCount + trailing,
        onPageChanged: (viewIndex) {
          if (_ignoreSlidePageChanges) return;
          if (_pageViewLeading == 1 && viewIndex == 0) {
            _queueSlideChapterCommit(
              chapterIndex: _chapterIndex - 1,
              boundaryViewIndex: viewIndex,
              restoreProgress: 1,
            );
            return;
          }
          final page = viewIndex - _pageViewLeading;
          if (page >= _pageCount) {
            _queueSlideChapterCommit(
              chapterIndex: _chapterIndex + 1,
              boundaryViewIndex: viewIndex,
              restoreProgress: 0,
            );
            return;
          }
          _pendingSlideChapterIndex = null;
          _pendingSlideBoundaryViewIndex = null;
          _setPagedIndex(page);
        },
        itemBuilder: (context, viewIndex) {
          final page = viewIndex - _pageViewLeading;
          if (page < 0) {
            return _buildAdjacentPreview(
                  _chapterIndex - 1,
                  lastPage: true,
                ) ??
                _buildBoundaryLeaf(forward: false);
          }
          if (page >= _pageCount) {
            return _buildAdjacentPreview(
                  _chapterIndex + 1,
                  lastPage: false,
                ) ??
                _buildBoundaryLeaf(forward: true);
          }
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) => _handlePageTap(
              details,
              MediaQuery.sizeOf(context).width,
            ),
            child: _buildPageLeaf(
              _paginatedPages[page],
              pageIndex: page,
              pageCount: _pageCount,
              layoutFingerprint: _paginationKey!,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurlReader({required bool usesTwoPageLayout}) =>
      usesTwoPageLayout ? _buildCurlSpreadReader() : _buildSingleCurlReader();

  Widget _buildSingleCurlReader() {
    final hasForward =
        _pageIndex + 1 < _pageCount || _chapterIndex + 1 < _chapters.length;
    final hasBackward = _pageIndex > 0 || _chapterIndex > 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final forwardData = _pageIndex + 1 < _pageCount
            ? null
            : _chapterIndex + 1 < _chapters.length
                ? _adjacentPageData(
                    _chapterIndex + 1,
                    constraints.biggest,
                    selectPageIndex: (_) => 0,
                  )
                : null;
        final backwardData = _pageIndex > 0
            ? null
            : _chapterIndex > 0
                ? _adjacentPageData(
                    _chapterIndex - 1,
                    constraints.biggest,
                    selectPageIndex: (pageCount) => pageCount - 1,
                  )
                : null;
        final currentSnapshot = _buildPageSnapshot(
          _paginatedPages[_pageIndex],
          pageIndex: _pageIndex,
          pageCount: _pageCount,
          layoutFingerprint: _paginationKey!,
        );
        final forwardSnapshot = !hasForward
            ? null
            : _pageIndex + 1 < _pageCount
                ? _buildPageSnapshot(
                    _paginatedPages[_pageIndex + 1],
                    pageIndex: _pageIndex + 1,
                    pageCount: _pageCount,
                    layoutFingerprint: _paginationKey!,
                  )
                : forwardData == null
                    ? _buildBoundarySnapshot(forward: true)
                    : _buildPageSnapshot(
                        forwardData.page,
                        pageIndex: forwardData.pageIndex,
                        pageCount: forwardData.pageCount,
                        layoutFingerprint: forwardData.layoutFingerprint,
                        chapterIndex: _chapterIndex + 1,
                        chapterContent: forwardData.content,
                      );
        final backwardSnapshot = !hasBackward
            ? null
            : _pageIndex > 0
                ? _buildPageSnapshot(
                    _paginatedPages[_pageIndex - 1],
                    pageIndex: _pageIndex - 1,
                    pageCount: _pageCount,
                    layoutFingerprint: _paginationKey!,
                  )
                : backwardData == null
                    ? _buildBoundarySnapshot(forward: false)
                    : _buildPageSnapshot(
                        backwardData.page,
                        pageIndex: backwardData.pageIndex,
                        pageCount: backwardData.pageCount,
                        layoutFingerprint: backwardData.layoutFingerprint,
                        chapterIndex: _chapterIndex - 1,
                        chapterContent: backwardData.content,
                      );
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) => _handlePageTap(details, constraints.maxWidth),
          child: ReaderShaderPageCurl(
            key: ValueKey('source-curl:${widget.source.id}:${widget.book.id}'),
            controller: _pageCurlController,
            paperColor: _readerTheme.background,
            currentPage: currentSnapshot,
            forwardPage: forwardSnapshot,
            backwardPage: backwardSnapshot,
            onTurnForward: _turnForward,
            onTurnBackward: _turnBackward,
          ),
        );
      },
    );
  }

  Widget _buildCurlSpreadReader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spreadStart = _spreadStartForPage(_pageIndex);
        final nextSpreadStart = spreadStart + 2;
        final hasPrevious = spreadStart >= 2 || _chapterIndex > 0;
        final hasNext = nextSpreadStart < _pageCount ||
            _chapterIndex + 1 < _chapters.length;
        final adjacentViewport = _paginationViewport(
          constraints.biggest,
          true,
        );
        final previousChapterIndex = _chapterIndex - 1;
        final nextChapterIndex = _chapterIndex + 1;
        final usesPreviousChapter =
            spreadStart == 0 && previousChapterIndex >= 0;
        final usesNextChapter = nextSpreadStart >= _pageCount &&
            nextChapterIndex < _chapters.length;
        final previousChapterCached = usesPreviousChapter &&
            _prefetchedContent[previousChapterIndex] != null;
        final nextChapterCached =
            usesNextChapter && _prefetchedContent[nextChapterIndex] != null;
        final previousChapterLeftData = previousChapterCached
            ? _adjacentPageData(
                previousChapterIndex,
                adjacentViewport,
                selectPageIndex: (pageCount) =>
                    _spreadStartForPage(pageCount - 1),
              )
            : null;
        final previousChapterRightData = previousChapterCached
            ? _adjacentPageData(
                previousChapterIndex,
                adjacentViewport,
                selectPageIndex: (pageCount) =>
                    _spreadStartForPage(pageCount - 1) + 1,
              )
            : null;
        final nextChapterLeftData = nextChapterCached
            ? _adjacentPageData(
                nextChapterIndex,
                adjacentViewport,
                selectPageIndex: (_) => 0,
              )
            : null;
        final nextChapterRightData = nextChapterCached
            ? _adjacentPageData(
                nextChapterIndex,
                adjacentViewport,
                selectPageIndex: (_) => 1,
              )
            : null;

        final currentLeft = _buildPageSnapshot(
          _paginatedPages[spreadStart],
          pageIndex: spreadStart,
          pageCount: _pageCount,
          layoutFingerprint: _paginationKey!,
          pageNumberPlacement: ReaderPageNumberPlacement.bottomLeft,
          topInformationLayout: ReaderTopInformationLayout.spreadLeft,
        );
        final currentRight = spreadStart + 1 < _pageCount
            ? _buildPageSnapshot(
                _paginatedPages[spreadStart + 1],
                pageIndex: spreadStart + 1,
                pageCount: _pageCount,
                layoutFingerprint: _paginationKey!,
                topInformationLayout: ReaderTopInformationLayout.spreadRight,
              )
            : _buildBlankSourceSnapshot(
                'current-$spreadStart-right',
                topInformationLayout: ReaderTopInformationLayout.spreadRight,
              );

        final previousLeft = !hasPrevious
            ? null
            : spreadStart >= 2
                ? _buildPageSnapshot(
                    _paginatedPages[spreadStart - 2],
                    pageIndex: spreadStart - 2,
                    pageCount: _pageCount,
                    layoutFingerprint: _paginationKey!,
                    pageNumberPlacement: ReaderPageNumberPlacement.bottomLeft,
                    topInformationLayout: ReaderTopInformationLayout.spreadLeft,
                  )
                : !previousChapterCached
                    ? _buildBoundarySnapshot(
                        forward: false,
                        topInformationLayout:
                            ReaderTopInformationLayout.spreadLeft,
                        slotIdentity: 'spread-left',
                      )
                    : previousChapterLeftData == null
                        ? _buildBlankSourceSnapshot(
                            'previous-chapter-$previousChapterIndex-left',
                            topInformationLayout:
                                ReaderTopInformationLayout.spreadLeft,
                            chapterTitle: _chapters[previousChapterIndex].title,
                          )
                        : _buildPageSnapshot(
                            previousChapterLeftData.page,
                            pageIndex: previousChapterLeftData.pageIndex,
                            pageCount: previousChapterLeftData.pageCount,
                            layoutFingerprint:
                                previousChapterLeftData.layoutFingerprint,
                            chapterIndex: previousChapterIndex,
                            chapterContent: previousChapterLeftData.content,
                            pageNumberPlacement:
                                ReaderPageNumberPlacement.bottomLeft,
                            topInformationLayout:
                                ReaderTopInformationLayout.spreadLeft,
                          );
        final previousRight = !hasPrevious
            ? null
            : spreadStart >= 2
                ? _buildPageSnapshot(
                    _paginatedPages[spreadStart - 1],
                    pageIndex: spreadStart - 1,
                    pageCount: _pageCount,
                    layoutFingerprint: _paginationKey!,
                    topInformationLayout:
                        ReaderTopInformationLayout.spreadRight,
                  )
                : !previousChapterCached
                    ? _buildBoundarySnapshot(
                        forward: false,
                        topInformationLayout:
                            ReaderTopInformationLayout.spreadRight,
                        slotIdentity: 'spread-right',
                      )
                    : previousChapterRightData == null
                        ? _buildBlankSourceSnapshot(
                            'previous-chapter-$previousChapterIndex-right',
                            topInformationLayout:
                                ReaderTopInformationLayout.spreadRight,
                            chapterTitle: _chapters[previousChapterIndex].title,
                          )
                        : _buildPageSnapshot(
                            previousChapterRightData.page,
                            pageIndex: previousChapterRightData.pageIndex,
                            pageCount: previousChapterRightData.pageCount,
                            layoutFingerprint:
                                previousChapterRightData.layoutFingerprint,
                            chapterIndex: previousChapterIndex,
                            chapterContent: previousChapterRightData.content,
                            topInformationLayout:
                                ReaderTopInformationLayout.spreadRight,
                          );
        final nextLeft = !hasNext
            ? null
            : nextSpreadStart < _pageCount
                ? _buildPageSnapshot(
                    _paginatedPages[nextSpreadStart],
                    pageIndex: nextSpreadStart,
                    pageCount: _pageCount,
                    layoutFingerprint: _paginationKey!,
                    pageNumberPlacement: ReaderPageNumberPlacement.bottomLeft,
                    topInformationLayout: ReaderTopInformationLayout.spreadLeft,
                  )
                : !nextChapterCached
                    ? _buildBoundarySnapshot(
                        forward: true,
                        topInformationLayout:
                            ReaderTopInformationLayout.spreadLeft,
                        slotIdentity: 'spread-left',
                      )
                    : nextChapterLeftData == null
                        ? _buildBlankSourceSnapshot(
                            'next-chapter-$nextChapterIndex-left',
                            topInformationLayout:
                                ReaderTopInformationLayout.spreadLeft,
                            chapterTitle: _chapters[nextChapterIndex].title,
                          )
                        : _buildPageSnapshot(
                            nextChapterLeftData.page,
                            pageIndex: nextChapterLeftData.pageIndex,
                            pageCount: nextChapterLeftData.pageCount,
                            layoutFingerprint:
                                nextChapterLeftData.layoutFingerprint,
                            chapterIndex: nextChapterIndex,
                            chapterContent: nextChapterLeftData.content,
                            pageNumberPlacement:
                                ReaderPageNumberPlacement.bottomLeft,
                            topInformationLayout:
                                ReaderTopInformationLayout.spreadLeft,
                          );
        final nextRight = !hasNext
            ? null
            : nextSpreadStart < _pageCount
                ? nextSpreadStart + 1 < _pageCount
                    ? _buildPageSnapshot(
                        _paginatedPages[nextSpreadStart + 1],
                        pageIndex: nextSpreadStart + 1,
                        pageCount: _pageCount,
                        layoutFingerprint: _paginationKey!,
                        topInformationLayout:
                            ReaderTopInformationLayout.spreadRight,
                      )
                    : _buildBlankSourceSnapshot(
                        'next-$nextSpreadStart-right',
                        topInformationLayout:
                            ReaderTopInformationLayout.spreadRight,
                      )
                : !nextChapterCached
                    ? _buildBoundarySnapshot(
                        forward: true,
                        topInformationLayout:
                            ReaderTopInformationLayout.spreadRight,
                        slotIdentity: 'spread-right',
                      )
                    : nextChapterRightData == null
                        ? _buildBlankSourceSnapshot(
                            'next-chapter-$nextChapterIndex-right',
                            topInformationLayout:
                                ReaderTopInformationLayout.spreadRight,
                          )
                        : _buildPageSnapshot(
                            nextChapterRightData.page,
                            pageIndex: nextChapterRightData.pageIndex,
                            pageCount: nextChapterRightData.pageCount,
                            layoutFingerprint:
                                nextChapterRightData.layoutFingerprint,
                            chapterIndex: nextChapterIndex,
                            chapterContent: nextChapterRightData.content,
                            topInformationLayout:
                                ReaderTopInformationLayout.spreadRight,
                          );

        final left = ReaderShaderPageCurl(
          key: ValueKey(
            'source-spread-curl-left:${widget.source.id}:${widget.book.id}',
          ),
          controller: _spreadBackwardPageCurlController,
          coordinator: _spreadPageCurlCoordinator,
          edgeDragOnly: true,
          bindingEdge: ReaderPageBindingEdge.right,
          paperColor: _readerTheme.background,
          currentPage: currentLeft,
          backwardPage: previousLeft,
          outgoingBackPage: previousRight,
          onTurnForward: () {},
          onTurnBackward: _turnBackward,
        );
        final right = ReaderShaderPageCurl(
          key: ValueKey(
            'source-spread-curl-right:${widget.source.id}:${widget.book.id}',
          ),
          controller: _spreadForwardPageCurlController,
          coordinator: _spreadPageCurlCoordinator,
          edgeDragOnly: true,
          bindingEdge: ReaderPageBindingEdge.left,
          paperColor: _readerTheme.background,
          currentPage: currentRight,
          forwardPage: nextRight,
          outgoingBackPage: nextLeft,
          onTurnForward: _turnForward,
          onTurnBackward: () {},
        );

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) => _handlePageTap(
            details,
            constraints.maxWidth,
          ),
          child: _buildSourceSpread(left: left, right: right),
        );
      },
    );
  }

  ReaderPageSnapshot _buildBlankSourceSnapshot(
    String pageIdentity, {
    ReaderTopInformationLayout topInformationLayout =
        ReaderTopInformationLayout.full,
    String chapterTitle = '',
  }) =>
      ReaderPageSnapshot(
        key: ReaderPageSnapshotKey(
          pageIdentity: 'source:${widget.source.id}:${widget.book.id}:'
              'blank:$pageIdentity',
          layoutFingerprint: _paginationKey ?? 'unpaginated',
          themeId: _readerTheme.cacheKey,
        ),
        contentRevision: _topBarStyle == ReaderTopBarStyle.reader
            ? _leafStatusController.value.revision
            : 0,
        child: ReaderPaperPageLeaf(
          palette: _readerTheme,
          safeArea: _readerSafeArea,
          metadata: ReaderPaperPageMetadata(
            pageIdentity: 'source:${widget.source.id}:${widget.book.id}:'
                'blank:$pageIdentity',
            layoutFingerprint: _paginationKey ?? 'unpaginated',
            themeId: _readerTheme.cacheKey,
            chapterTitle: chapterTitle,
            pageNumber: 0,
            pageCount: 0,
          ),
          horizontalPadding: math.max(14, _horizontalMargin),
          showTopInformation: _topBarStyle == ReaderTopBarStyle.reader,
          topInformationLayout: topInformationLayout,
          showPageNumber: false,
          status: _leafStatusController.value,
          child: const SizedBox.expand(),
        ),
      );

  Widget _buildSourceSpread({
    required Widget left,
    required Widget right,
  }) {
    return ReaderPageCurlSpread(
      coordinator: _spreadPageCurlCoordinator,
      left: left,
      right: right,
      gutter: _buildSourceSpreadGutter(),
    );
  }

  Widget _buildSourceSpreadGutter() {
    final colors = _readerThemeData.colorScheme;
    return SizedBox(
      width: _spreadGutter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.shadow.withValues(alpha: 0),
              colors.shadow.withValues(alpha: 0.09),
              colors.shadow.withValues(alpha: 0),
            ],
          ),
        ),
        child: Center(
          child: Container(
            width: 1,
            color: colors.outlineVariant.withValues(alpha: 0.48),
          ),
        ),
      ),
    );
  }

  String _readerStatus() {
    if (_pageMode == BookSourcePageMode.verticalScroll) {
      return context.l10n.readerStatusPaged(
        _chapterIndex + 1,
        _chapters.length,
        _verticalPageIndex + 1,
        _verticalPageCount,
      );
    }
    return context.l10n.readerStatusPaged(
      _chapterIndex + 1,
      _chapters.length,
      _pageIndex + 1,
      _pageCount,
    );
  }

  bool get _currentPageIsBookmarked {
    final anchorKey = _currentBookmarkAnchorKey;
    return anchorKey != null &&
        _bookmarks.any((bookmark) => bookmark.anchorKey == anchorKey);
  }

  Widget _buildReaderStatusText(
    BuildContext context,
    TextStyle? style,
    Key? key,
  ) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollProgress,
      builder: (context, _, __) => Text(
        _chapters.isEmpty ? widget.book.title : _readerStatus(),
        key: key,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class _BookSourcePagedLayout {
  const _BookSourcePagedLayout({
    required this.fingerprint,
    required this.pages,
  });

  final String fingerprint;
  final List<BookSourceTextPage> pages;
}

class _BookSourceVerticalLayout {
  const _BookSourceVerticalLayout({
    required this.fingerprint,
    required this.pages,
  });

  final String fingerprint;
  final List<BookSourceTextPage> pages;
}

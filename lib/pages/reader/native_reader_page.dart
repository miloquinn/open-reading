import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:xxread/core/reader/canonical_locator.dart';
import 'package:xxread/core/reader/android_reader_aloud_notification.dart';
import 'package:xxread/core/reader/indexed_text_reader.dart';
import 'package:xxread/core/reader/native_text_paginator.dart';
import 'package:xxread/core/reader/reader_annotation.dart';
import 'package:xxread/core/reader/reader_custom_theme.dart';
import 'package:xxread/core/reader/reader_leaf_status.dart';
import 'package:xxread/core/reader/reader_layout.dart';
import 'package:xxread/core/reader/reader_keep_screen_on.dart';
import 'package:xxread/core/reader/reader_margin_settings.dart';
import 'package:xxread/core/reader/reader_aloud_controller.dart';
import 'package:xxread/core/reader/reader_safe_area.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/core/reader/reader_system_ui.dart';
import 'package:xxread/core/reader/reader_tap_zones.dart';
import 'package:xxread/core/reader/reader_text_characters.dart';
import 'package:xxread/core/reader/reader_text_pagination.dart';
import 'package:xxread/core/reader/reader_theme_order.dart';
import 'package:xxread/core/reader/reader_vertical_paging.dart';
import 'package:xxread/core/reader/reader_volume_key_controller.dart';
import 'package:xxread/core/reader/txt_chapter_parser.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/models/book_note.dart';
import 'package:xxread/reader_core/ai/ai_service.dart';
import 'package:xxread/models/bookmark.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/book_note_dao.dart';
import 'package:xxread/services/books/bookmark_dao.dart';
import 'package:xxread/services/books/enhanced_txt_import_service.dart';
import 'package:xxread/services/books/epub_native_parser.dart';
import 'package:xxread/services/books/kindle_book_parser.dart';
import 'package:xxread/services/books/web_book_file_store.dart';
import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/services/reading/reading_resume_service.dart';
import 'package:xxread/services/reading/reading_stats_dao.dart';
import 'package:xxread/services/tts_service.dart';
import 'package:xxread/services/reader_aloud_service.dart';
import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/font_catalog_helper.dart';
import 'package:xxread/utils/glass_config.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/widgets/reader_ai_panel.dart';
import 'package:xxread/widgets/reader_annotated_text_page.dart';
import 'package:xxread/widgets/reader_aloud_panel.dart';
import 'package:xxread/widgets/reader_control_chrome.dart';
import 'package:xxread/widgets/reader_cover_page_turn.dart';
import 'package:xxread/widgets/reader_chapter_title_page.dart';
import 'package:xxread/widgets/reader_navigation_sheet.dart';
import 'package:xxread/widgets/reader_opening_loader.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';
import 'package:xxread/widgets/reader_pull_bookmark.dart';
import 'package:xxread/widgets/reader_settings_controls.dart';
import 'package:xxread/widgets/reader_shader_page_curl.dart';
import 'package:xxread/widgets/reader_tap_observer.dart';
import 'package:xxread/widgets/reader_tap_zone_editor.dart';
import 'package:xxread/widgets/reader_theme_background.dart';
import 'package:xxread/widgets/reader_top_information_bar.dart';
import 'package:xxread/widgets/reader_vertical_paging_surface.dart';
import 'package:xxread/widgets/side_toast.dart';

import 'themes/reader_custom_themes_page.dart';

typedef NativePageMode = ReaderPageMode;

const int _largeTxtFileThreshold = 16 * 1024 * 1024;
const int _txtChapterCacheVersion = 4;
const double _imagePageGap = 10;
const int _imagePageImageFlex = 5;
const int _imagePageTextFlex = 6;
final Map<String, Future<void>> _epubFontLoads = <String, Future<void>>{};

Future<void> _registerEpubFonts(Map<String, String> fonts) => Future.wait(
  fonts.entries.map((entry) {
    return _epubFontLoads.putIfAbsent(entry.key, () async {
      try {
        final bytes = await File(entry.value).readAsBytes();
        final loader = FontLoader(entry.key)
          ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
        await loader.load();
      } catch (error) {
        debugPrint('EPUB font registration failed (${entry.key}): $error');
      }
    });
  }),
);

Future<Directory> _readerCacheDirectory() async {
  try {
    return await getTemporaryDirectory();
  } on MissingPluginException catch (error) {
    debugPrint('EPUB cache uses temporary directory: $error');
    return Directory.systemTemp;
  }
}

@visibleForTesting
Future<bool> waitForReaderOpeningRouteToSettle({
  required Animation<double>? routeAnimation,
  required bool routeEntranceCompleted,
  required bool Function() isMounted,
}) async {
  // The live animation status is authoritative. A completed flag captured
  // before the route's first forward tick must not cancel active opening.
  if (routeAnimation == null ||
      routeAnimation.status == AnimationStatus.completed) {
    return isMounted();
  }

  final completed = Completer<bool>();
  var sawRouteMotion =
      routeAnimation.status == AnimationStatus.forward ||
      routeAnimation.status == AnimationStatus.reverse;
  void handleStatus(AnimationStatus status) {
    if (completed.isCompleted) return;
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.reverse) {
      sawRouteMotion = true;
      return;
    }
    if (status == AnimationStatus.completed) completed.complete(true);
    // A newly pushed route is briefly `dismissed` before its first forward
    // tick. Only treat dismissed as cancellation after motion has actually
    // started; otherwise every large TXT returns an empty chapter list.
    if (status == AnimationStatus.dismissed && sawRouteMotion) {
      completed.complete(false);
    }
  }

  routeAnimation.addStatusListener(handleStatus);
  handleStatus(routeAnimation.status);
  final routeOpened = await completed.future;
  routeAnimation.removeStatusListener(handleStatus);
  return routeOpened && isMounted();
}

class NativeReaderPage extends StatefulWidget {
  const NativeReaderPage({
    super.key,
    required this.book,
    this.initialTheme,
    @visibleForTesting this.onPaginationCacheMiss,
  });

  final Book book;
  final ReaderThemePalette? initialTheme;
  final ValueChanged<int>? onPaginationCacheMiss;

  @override
  State<NativeReaderPage> createState() => _NativeReaderPageState();
}

class _NativeReaderPageState extends State<NativeReaderPage>
    with WidgetsBindingObserver {
  static const _openingLoaderDelay = Duration(milliseconds: 650);
  static const _openingContentSettleDelay = Duration(milliseconds: 360);
  static final Map<String, Future<List<_NativeChapter>>> _bookMemoryCache = {};
  static final Map<String, List<ReaderNavigationChapter>>
  _navigationMemoryCache = {};
  static final Map<String, Map<String, List<_ReaderPageData>>>
  _paginationMemoryCache = {};
  static const _spreadGutter = 24.0;
  late final Future<List<_NativeChapter>> _chaptersFuture;
  PageController? _pageController;
  int _pageControllerGeneration = 0;
  bool _horizontalChapterJumpPending = false;
  bool _horizontalChapterJumpRevealScheduled = false;
  bool _horizontalBackwardExpansionPending = false;
  bool _horizontalBackwardExpansionWarmPending = false;
  bool _horizontalForwardContractionPending = false;
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
  final ReaderCoverPageTurnController _coverPageTurnController =
      ReaderCoverPageTurnController();
  final ValueNotifier<double> _verticalScrollProgress = ValueNotifier(0);
  final ReaderLeafStatusController _leafStatusController =
      ReaderLeafStatusController();
  final Set<String> _queuedHorizontalPaginationWarms = {};
  final Map<String, GlobalKey> _continuousPartKeys = {};
  final Map<String, List<_ContinuousReaderPart>> _continuousPartCache = {};
  late final Map<String, List<_ReaderPageData>> _pageCache;
  List<_NativeChapter> _loadedChapters = const [];
  List<ReaderNavigationChapter> _navigationChapters = const [];
  bool _readerDependenciesInitialized = false;
  int _chapterIndex = 0;
  int _chapterLoadSerial = 0;
  int _horizontalFirstChapter = 0;
  int _horizontalLastChapter = 0;
  int _pageIndex = 0;
  int? _anchorOffset;
  int? _verticalCanonicalOffset;
  String? _savedChapterId;
  bool _savedChapterResolved = false;
  bool _restoreAnchorAfterLayout = true;
  bool _initialPositionRestored = false;
  bool _initialPositionRestoreScheduled = false;
  String? _lastSavedLocation;
  bool _openPreviousChapterAtLastPage = false;
  bool _controlsVisible = false;
  NativePageMode _pageMode = ReaderSettings.defaultPageMode;
  bool _scrollByChapter = true;
  double _fontSize = 19;
  double _lineHeight = 1.75;
  double _letterSpacing = ReaderSettings.defaultLetterSpacing;
  ReaderTextAlignment _textAlignment = ReaderSettings.defaultTextAlignment;
  int _firstLineIndent = ReaderSettings.defaultFirstLineIndent;
  int _paragraphSpacing = ReaderSettings.defaultParagraphSpacing;
  double _horizontalMargin = 18;
  double _topMargin = ReaderMarginSettings.defaultTop;
  double _bottomMargin = ReaderMarginSettings.defaultBottom;
  FontOption _readerFont = FontCatalog.defaultReaderFont;
  String _readerThemeId = ReaderThemes.day.id;
  bool _pullBookmarkEnabled = false;
  bool _tapPageAnimationEnabled = true;
  ReaderTapZones _tapZones = ReaderTapZones.defaults;
  bool _tapZoneEditorVisible = false;
  bool _tabletTwoPageEnabled = ReaderSettings.defaultTabletTwoPageEnabled;
  bool _txtChapterTitlePageEnabled = true;
  bool _readerSettingsLoaded = false;
  bool _readerFontReady = true;
  bool _readerSystemUiApplied = false;
  bool _readerSystemUiApplyScheduled = false;
  bool _routeEntranceCompleted = false;
  ValueListenable<bool>? _openingFlightSettled;
  ValueListenable<bool>? _openingCoverHoldReached;
  bool _showOpeningLoader = false;
  bool _openingContentReadyScheduled = false;
  Timer? _openingLoaderTimer;
  Timer? _openingContentReadyTimer;
  ReaderTopBarStyle _topBarStyle = ReaderTopBarStyle.reader;
  ReaderAloudController? _readerAloudController;
  bool _readerAloudActive = false;
  ReaderAloudHighlight? _readerAloudHighlight;
  final ReadingStatsDao _readingStatsDao = ReadingStatsDao();
  final BookmarkDao _bookmarkDao = BookmarkDao();
  final BookNoteDao _bookNoteDao = BookNoteDao();
  final ReaderSettingsStore _readerSettingsStore = const ReaderSettingsStore();
  final ReaderCustomThemeStore _customThemeStore =
      const ReaderCustomThemeStore();
  final ReaderThemeOrderStore _themeOrderStore = const ReaderThemeOrderStore();
  List<Bookmark> _bookmarks = const [];
  bool _bookmarkBusy = false;
  List<BookNote> _annotations = const [];
  bool _annotationBusy = false;
  bool _annotationInteractionActive = false;
  int _annotationRevision = 0;
  DateTime? _readingSessionStartedAt;
  int _sessionPagesRead = 0;
  List<_ReaderPageData> _visiblePages = const [];
  List<_ContinuousReaderPart> _visibleContinuousParts = const [];
  List<_NativeChapter> _visibleChapters = const [];
  int _visibleChapterCount = 0;
  bool _visibleUsesTwoPageLayout = false;
  Size _verticalViewportSize = Size.zero;
  TextDirection _verticalTextDirection = TextDirection.ltr;
  TextScaler _verticalTextScaler = TextScaler.noScaling;
  Size _lastPaginationSize = Size.zero;
  Size _readerViewportSize = Size.zero;
  bool? _lastUsesTwoPageLayout;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    _showOpeningLoader = widget.initialTheme == null;
    if (!_showOpeningLoader) {
      _openingLoaderTimer = Timer(_openingLoaderDelay, () {
        if (mounted) setState(() => _showOpeningLoader = true);
      });
    }
    WidgetsBinding.instance.addObserver(this);
    _leafStatusController
      ..addListener(_onLeafStatusChanged)
      ..start();
    unawaited(ReaderKeepScreenOnController.activate(this));
    unawaited(ReadingResumeService.markReading(widget.book.id));
    _startReadingSession();
    _chapterIndex = widget.book.currentPage;
    _horizontalFirstChapter = (_chapterIndex - 1).clamp(0, _chapterIndex);
    _horizontalLastChapter = _chapterIndex + 1;
    final savedLocator = widget.book.toCanonicalLocator();
    _anchorOffset = savedLocator?.textAnchor?.startOffsetUtf16;
    _verticalCanonicalOffset = _anchorOffset;
    _savedChapterId =
        savedLocator?.chapterId ?? savedLocator?.textAnchor?.chapterId;
    _initialPositionRestored = _anchorOffset == null;
    _verticalPagePositionsListener.itemPositions.addListener(
      _onVerticalPagePositionsChanged,
    );
    _verticalChapterPositionsListener.itemPositions.addListener(
      _onVerticalChapterPositionsChanged,
    );
    unawaited(_loadPageMode());
    unawaited(_loadBookmarks());
    unawaited(_loadAnnotations());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startReadingSession();
      unawaited(ReaderKeepScreenOnController.reapply(this));
      if (_readerSystemUiApplied) unawaited(_applyReaderSystemUi());
      if (_readerSettingsLoaded) unawaited(_syncVolumeKeyPaging());
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushReadingSession());
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (mounted && _readerThemeId == ReaderThemes.systemId) {
      setState(() {});
      if (_readerSystemUiApplied) unawaited(_applyReaderSystemUi());
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
        bookId: widget.book.id,
        pagesRead: pagesRead,
      );
    } catch (error) {
      debugPrint('record native reading session failed: $error');
    }
  }

  Future<void> _loadBookmarks() async {
    final bookId = widget.book.id;
    if (bookId == null) return;
    try {
      final bookmarks = await _bookmarkDao.getBookmarksForBook(bookId);
      if (mounted) setState(() => _bookmarks = bookmarks);
    } catch (error) {
      debugPrint('load bookmarks failed: $error');
    }
  }

  Future<void> _loadAnnotations() async {
    final bookId = widget.book.id;
    if (bookId == null) return;
    try {
      final annotations = await _bookNoteDao.selectBookNotesByBookId(bookId);
      if (mounted) {
        setState(() {
          _annotations = annotations;
          _annotationRevision++;
        });
      }
    } catch (error) {
      debugPrint('load reader annotations failed: $error');
    }
  }

  Future<void> _saveTextAnnotation(
    ReaderSelectionSnapshot selection,
    ReaderAnnotationEditorResult annotation,
  ) async {
    final bookId = widget.book.id;
    if (bookId == null || _annotationBusy) return;
    setState(() => _annotationBusy = true);
    try {
      final now = DateTime.now();
      final note = BookNote(
        bookId: bookId,
        content: selection.selectedText,
        cfi: selection.cfiFor(annotation.type),
        canonicalLocator: selection.canonicalLocatorJson,
        chapter: selection.chapterTitle,
        type: annotation.type,
        color: annotation.colorHex,
        readerNote: annotation.note,
        pageNumber: selection.pageIndex,
        startOffset: selection.startOffset,
        endOffset: selection.endOffset,
        createTime: now,
        updateTime: now,
      );
      await _bookNoteDao.insertBookNote(note);
      await _loadAnnotations();
      if (!mounted) return;
      showSideToast(
        context,
        context.l10n.readerAnnotationSaved,
        duration: const Duration(milliseconds: 1600),
        icon: annotation.type == readerAnnotationTypeNote
            ? Icons.mode_comment_rounded
            : Icons.auto_awesome_rounded,
        kind: SideToastKind.success,
      );
    } catch (error) {
      debugPrint('save reader annotation failed: $error');
    } finally {
      if (mounted) setState(() => _annotationBusy = false);
    }
  }

  Future<void> _deleteAnnotation(BookNote annotation) async {
    final id = annotation.id;
    if (id == null) return;
    await _bookNoteDao.deleteBookNoteById(id);
    if (!mounted) return;
    setState(() {
      _annotations = _annotations
          .where((candidate) => candidate.id != id)
          .toList(growable: false);
      _annotationRevision++;
    });
    showSideToast(
      context,
      context.l10n.readerAnnotationDeleted,
      duration: const Duration(milliseconds: 1600),
      icon: Icons.delete_outline_rounded,
      kind: SideToastKind.success,
    );
  }

  Future<void> _exitReader() async {
    BookOpenTransition.beginExit();
    unawaited(_flushReadingSession());
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindRouteAnimation();
    _bindOpeningFlightSettled();
    _bindOpeningCoverHold();
    var nextReaderFont = FontCatalog.defaultReaderFont;
    var nextReaderFontReady = true;
    try {
      final appSettings = context.watch<AppSettingsNotifier>();
      nextReaderFontReady = appSettings.isInitialized;
      if (nextReaderFontReady) nextReaderFont = appSettings.readerFont;
    } on ProviderNotFoundException {
      // Reader widgets remain embeddable in tests and isolated previews.
    }
    _readerFontReady = nextReaderFontReady;
    if (_readerFont.id != nextReaderFont.id) {
      _readerFont = nextReaderFont;
      if (_readerDependenciesInitialized) {
        _pageCache.clear();
        _restoreAnchorAfterLayout = true;
      }
    }
    _initializeReaderDependencies();
    if (_routeEntranceCompleted) _scheduleInitialReaderSystemUi();
  }

  /// 打开动画（封面飞行 + 正文渐显）是否已完全结束。
  ///
  /// 路由动画结束时正文渐显往往仍在播放；相邻章节的整章排版、系统栏切换
  /// 都等待该信号，避免这些主线程重活掉帧落在动画后半段。
  bool get _openingFlightSettledNow => _openingFlightSettled?.value ?? true;

  void _bindOpeningFlightSettled() {
    final next = BookOpenTransition.openingFlightSettledListenableOf(context);
    if (identical(next, _openingFlightSettled)) return;
    _openingFlightSettled?.removeListener(_onOpeningFlightSettledChanged);
    _openingFlightSettled = next;
    if (next != null && !next.value) {
      next.addListener(_onOpeningFlightSettledChanged);
    }
  }

  void _onOpeningFlightSettledChanged() {
    _openingFlightSettled?.removeListener(_onOpeningFlightSettledChanged);
    if (!mounted) return;
    _scheduleInitialReaderSystemUi();
    setState(() {});
  }

  /// 封面飞行路由动画是否已完全结束（或本就没有封面飞行）。
  ///
  /// 底层路由动画请求新帧会一直持续到 100%，即使封面在视觉上早就静止；
  /// 这期间执行整章排版（一次 50~100ms）仍会挤占帧预算、拖慢同时播放
  /// 的其它动画（如首页悬浮导航收起），实测会掉帧。等到路由动画彻底
  /// 停止请求新帧才是真正的无感知窗口。
  bool get _openingCoverHoldReachedNow =>
      _openingCoverHoldReached?.value ?? true;

  void _bindOpeningCoverHold() {
    final next = BookOpenTransition.openingCoverHoldListenableOf(context);
    if (identical(next, _openingCoverHoldReached)) return;
    _openingCoverHoldReached?.removeListener(_onOpeningCoverHoldChanged);
    _openingCoverHoldReached = next;
    if (next != null && !next.value) {
      next.addListener(_onOpeningCoverHoldChanged);
    }
  }

  void _onOpeningCoverHoldChanged() {
    _openingCoverHoldReached?.removeListener(_onOpeningCoverHoldChanged);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _waitForOpeningCoverHold() {
    final listenable = _openingCoverHoldReached;
    if (listenable == null || listenable.value) {
      return Future<void>.value();
    }
    final completer = Completer<void>();
    late final VoidCallback onChanged;
    onChanged = () {
      if (!listenable.value) return;
      listenable.removeListener(onChanged);
      if (!completer.isCompleted) completer.complete();
    };
    listenable.addListener(onChanged);
    return completer.future;
  }

  void _bindRouteAnimation() {
    final nextAnimation = ModalRoute.of(context)?.animation;
    if (identical(_routeAnimation, nextAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChanged);
    _routeAnimation = nextAnimation;
    if (nextAnimation == null ||
        nextAnimation.status == AnimationStatus.completed) {
      _routeEntranceCompleted = true;
      return;
    }
    _routeEntranceCompleted = false;
    nextAnimation.addStatusListener(_onRouteAnimationStatusChanged);
  }

  void _onRouteAnimationStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChanged);
    _routeEntranceCompleted = true;
    _scheduleInitialReaderSystemUi();
    setState(() {});
  }

  void _initializeReaderDependencies() {
    if (_readerDependenciesInitialized) return;
    final cacheKey = _bookCacheKey;
    if (_isLargeTxtBook) {
      // Large TXT books already retain their chapter text in memory. Keeping
      // another static cache prevents that memory from being released after
      // leaving the reader and can push Android into heavy GC or an OOM.
      _pageCache = <String, List<_ReaderPageData>>{};
      _chaptersFuture = _prepareLoadedChapters(_loadBook());
      _readerDependenciesInitialized = true;
      return;
    }
    if (!_bookMemoryCache.containsKey(cacheKey) &&
        _bookMemoryCache.length >= 2) {
      final oldestKey = _bookMemoryCache.keys.first;
      _bookMemoryCache.remove(oldestKey);
      _navigationMemoryCache.remove(oldestKey);
      _paginationMemoryCache.remove(oldestKey);
    }
    _pageCache = _paginationMemoryCache.putIfAbsent(cacheKey, () => {});
    final cachedChapters = _bookMemoryCache.putIfAbsent(
      cacheKey,
      () => _loadBook().onError((error, stackTrace) {
        _bookMemoryCache.remove(cacheKey);
        _paginationMemoryCache.remove(cacheKey);
        Error.throwWithStackTrace(
          error ?? StateError('Unknown reader loading error'),
          stackTrace,
        );
      }),
    );
    _chaptersFuture = _prepareLoadedChapters(cachedChapters);
    _readerDependenciesInitialized = true;
  }

  Future<List<_NativeChapter>> _prepareLoadedChapters(
    Future<List<_NativeChapter>> chaptersFuture,
  ) async {
    final chapters = await chaptersFuture;
    if (chapters.isEmpty) return chapters;

    _loadedChapters = chapters;
    final initialChapterIndex = _chapterIndex.clamp(0, chapters.length - 1);
    // 冷缓存打开时，章节文本的读取与 UTF-8 解码（UI isolate 上数十毫秒）
    // 等封面飞到静止的停留画面再执行，避免解码回调冻结飞行帧。
    if (_pageCache.isEmpty) await _waitForOpeningCoverHold();
    await _loadIndexedChapterWindow(chapters, initialChapterIndex);
    _navigationChapters =
        _navigationMemoryCache[_bookCacheKey] ??
        List<ReaderNavigationChapter>.generate(
          chapters.length,
          (index) => ReaderNavigationChapter(
            title: chapters[index].title,
            index: index,
            id: chapters[index].id,
            depth: chapters[index].depth,
          ),
          growable: false,
        );
    return chapters;
  }

  Future<void> _loadIndexedChapterWindow(
    List<_NativeChapter> chapters,
    int chapterIndex,
  ) async {
    final indexes = <int>{
      chapterIndex,
      chapterIndex - 1,
      chapterIndex + 1,
      chapterIndex - 2,
      chapterIndex + 2,
      chapterIndex - 3,
      chapterIndex + 3,
    }.where((index) => index >= 0 && index < chapters.length).toList();
    final epubChapters = indexes
        .map((index) => chapters[index])
        .where((chapter) => chapter.isLazyEpub)
        .toList(growable: false);
    if (epubChapters.isNotEmpty) {
      await _loadEpubChapterBatch(epubChapters);
    }
    await Future.wait<void>([
      for (final index in indexes)
        if (!chapters[index].isLazyEpub) chapters[index].loadTextAsync(),
    ]);
    for (var index = 0; index < chapters.length; index++) {
      if ((index - chapterIndex).abs() > 4) chapters[index].unloadLazyContent();
    }
  }

  Future<void> _loadEpubChapterBatch(List<_NativeChapter> chapters) async {
    final pending = chapters
        .where((chapter) => chapter.hasPendingLoad)
        .map((chapter) => chapter.pendingLoad!)
        .toList(growable: false);
    final missing = chapters
        .where((chapter) => !chapter.hasLoadedText && !chapter.hasPendingLoad)
        .toList(growable: false);
    if (missing.isNotEmpty) {
      final completers = <_NativeChapter, Completer<void>>{
        for (final chapter in missing) chapter: Completer<void>(),
      };
      for (final entry in completers.entries) {
        entry.key.attachPendingLoad(entry.value.future);
      }
      try {
        final first = missing.first;
        final parsed =
            await compute(loadEpubNativeChapterWindow, <String, dynamic>{
              ...first.epubLoadArguments,
              'chapters': missing
                  .map((chapter) => chapter.epubDescriptor)
                  .toList(growable: false),
            });
        final results = (parsed['results'] as List<dynamic>).cast<Map>();
        final fonts = <String, String>{};
        for (final result in results) {
          fonts.addAll(
            Map<String, String>.from(result['fonts'] as Map? ?? const {}),
          );
        }
        await _registerEpubFonts(fonts);
        for (var index = 0; index < missing.length; index++) {
          missing[index].applyEpubResult(
            Map<String, dynamic>.from(results[index]),
          );
          completers[missing[index]]!.complete();
        }
      } catch (error, stackTrace) {
        debugPrint('EPUB batch failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        for (final completer in completers.values) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
        rethrow;
      } finally {
        for (final chapter in missing) {
          chapter.clearPendingLoad();
        }
      }
    }
    await Future.wait<void>(pending);
  }

  void _scheduleInitialReaderSystemUi() {
    if (!_routeEntranceCompleted ||
        !_openingFlightSettledNow ||
        _readerSystemUiApplied ||
        _readerSystemUiApplyScheduled) {
      return;
    }
    _readerSystemUiApplyScheduled = true;
    // Changing window insets while the cover flight or the reveal crossfade
    // is still playing forces the live reader route to relayout mid-flight.
    // Wait for the whole visible opening animation to settle, then apply the
    // saved reader chrome on the following frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _readerSystemUiApplied) return;
      final topBarStyle = await ReaderSystemUiController.applySavedPreference(
        overlayStyle: _readerSystemUiOverlayStyle,
      );
      if (!mounted) return;
      setState(() {
        _topBarStyle = topBarStyle;
        _readerSystemUiApplied = true;
      });
    });
  }

  String get _bookCacheKey =>
      '${widget.book.format.toLowerCase() == 'txt' ? 'txt-parser-v5:' : ''}'
      '${widget.book.contentHash ?? widget.book.filePath}:'
      '${widget.book.fileModifiedTime ?? (kIsWeb ? 0 : File(widget.book.filePath).lastModifiedSync().millisecondsSinceEpoch)}:'
      '${widget.book.textEncoding ?? 'auto'}';

  bool get _isLargeTxtBook {
    if (widget.book.format.toLowerCase() != 'txt') return false;
    if (kIsWeb) return false;
    try {
      return File(widget.book.filePath).lengthSync() > _largeTxtFileThreshold;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _openingLoaderTimer?.cancel();
    _openingContentReadyTimer?.cancel();
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChanged);
    _openingFlightSettled?.removeListener(_onOpeningFlightSettledChanged);
    _openingCoverHoldReached?.removeListener(_onOpeningCoverHoldChanged);
    _readerAloudController?.dispose();
    unawaited(_flushReadingSession());
    _pageController?.dispose();
    _verticalPagePositionsListener.itemPositions.removeListener(
      _onVerticalPagePositionsChanged,
    );
    _verticalChapterPositionsListener.itemPositions.removeListener(
      _onVerticalChapterPositionsChanged,
    );
    _verticalScrollProgress.dispose();
    _spreadPageCurlCoordinator.dispose();
    _leafStatusController
      ..removeListener(_onLeafStatusChanged)
      ..dispose();
    unawaited(ReaderVolumeKeyController.deactivate(this));
    unawaited(ReaderKeepScreenOnController.deactivate(this));
    unawaited(ReaderSystemUiController.restore());
    unawaited(ReadingResumeService.markClosed(widget.book.id));
    super.dispose();
  }

  SystemUiOverlayStyle get _readerSystemUiOverlayStyle =>
      SystemUiHelper.overlayStyleForBackground(
        _readerTheme.background,
        transparentSystemBars: !GlassEffectConfig.shouldDisableBlur,
      );

  Future<void> _applyReaderSystemUi() => ReaderSystemUiController.apply(
    style: _topBarStyle,
    overlayStyle: _readerSystemUiOverlayStyle,
  );

  void _onLeafStatusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPageMode() async {
    try {
      final results = await Future.wait<Object?>([
        _readerSettingsStore.load(),
        _readerSettingsStore.loadScrollByChapter(),
        _customThemeStore.loadAll(),
        _themeOrderStore.load(),
        ReaderSystemUiController.loadPreference(),
        _readerSettingsStore.loadTapZones(),
        _readerSettingsStore.loadTxtChapterTitlePageEnabled(),
      ]);
      final settings = results[0] as ReaderSettings;
      final scrollByChapter = results[1] as bool;
      final customThemes = results[2] as List<ReaderCustomTheme>;
      final themeOrder = results[3] as List<String>;
      final topBarStyle = results[4] as ReaderTopBarStyle;
      final tapZones = results[5] as ReaderTapZones;
      final txtChapterTitlePageEnabled = results[6] as bool;
      if (!mounted) return;
      ReaderThemes.setCustomThemes(customThemes);
      ReaderThemes.setThemeOrder(themeOrder);
      setState(() {
        _pageMode = settings.pageMode;
        _fontSize = settings.fontSize;
        _lineHeight = settings.lineHeight;
        _letterSpacing = settings.letterSpacing;
        _textAlignment = settings.textAlignment;
        _horizontalMargin = settings.horizontalMargin;
        _topMargin = settings.topMargin;
        _bottomMargin = settings.bottomMargin;
        _firstLineIndent = settings.firstLineIndent;
        _paragraphSpacing = settings.paragraphSpacing;
        _scrollByChapter = scrollByChapter;
        _readerThemeId = ReaderThemes.byId(settings.themeId).id;
        _pullBookmarkEnabled = settings.pullBookmarkEnabled;
        _tapPageAnimationEnabled = settings.tapPageAnimationEnabled;
        _tapZones = tapZones;
        _tabletTwoPageEnabled = settings.tabletTwoPageEnabled;
        _topBarStyle = topBarStyle;
        _txtChapterTitlePageEnabled = txtChapterTitlePageEnabled;
        _readerSettingsLoaded = true;
      });
      unawaited(_syncVolumeKeyPaging());
    } catch (error, stackTrace) {
      debugPrint('Reader settings failed to load: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _readerSettingsLoaded = true);
        unawaited(_syncVolumeKeyPaging());
      }
    }
  }

  Future<void> _syncVolumeKeyPaging() => ReaderVolumeKeyController.activate(
    owner: this,
    pageTurningAvailable: _pageMode != NativePageMode.verticalScroll,
    onNextPage: () => _handleVolumePageTurn(forward: true),
    onPreviousPage: () => _handleVolumePageTurn(forward: false),
  );

  void _handleVolumePageTurn({required bool forward}) {
    if (!mounted ||
        _pageMode == NativePageMode.verticalScroll ||
        _visiblePages.isEmpty ||
        _visibleChapterCount <= 0) {
      return;
    }
    if (forward) {
      _nextPage(
        _visiblePages,
        _visibleChapterCount,
        usesTwoPageLayout: _visibleUsesTwoPageLayout,
      );
    } else {
      _previousPage(
        _visiblePages,
        _visibleChapterCount,
        usesTwoPageLayout: _visibleUsesTwoPageLayout,
      );
    }
  }

  ReaderThemePalette get _readerTheme =>
      !_readerSettingsLoaded && widget.initialTheme != null
      ? widget.initialTheme!
      : ReaderThemes.byId(_readerThemeId);

  ThemeData get _readerThemeData =>
      _readerTheme.toThemeData(typography: Theme.of(context).textTheme);

  ReaderSettings get _readerSettings => ReaderSettings(
    fontSize: _fontSize,
    lineHeight: _lineHeight,
    letterSpacing: _letterSpacing,
    textAlignment: _textAlignment,
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

  TextStyle get _readerTextStyle => TextStyle(
    inherit: false,
    fontFamily: _readerFont.family,
    fontFamilyFallback: readerFontFamilyFallbacks(
      fontFamily: _readerFont.family,
      configuredFallbacks: _readerFont.fallbackFamilies,
      locale: Localizations.maybeLocaleOf(context),
    ),
    fontSize: _fontSize,
    height: _lineHeight,
    letterSpacing: _letterSpacing,
    color: _readerTheme.text,
  );

  TextAlign get _readerTextAlign => switch (_textAlignment) {
    ReaderTextAlignment.natural => TextAlign.start,
    ReaderTextAlignment.justified => TextAlign.justify,
  };

  NativeTextFlowStyle _readerTextFlowStyle({
    TextDirection? direction,
    TextScaler? textScaler,
  }) {
    final style = _readerTextStyle;
    return NativeTextFlowStyle(
      textDirection: direction ?? Directionality.of(context),
      textScaler: textScaler ?? readerBodyTextScaler,
      locale: Localizations.maybeLocaleOf(context),
      strutStyle: readerStrutStyle(style),
      textHeightBehavior: readerTextHeightBehavior,
      textAlign: _readerTextAlign,
    );
  }

  Future<void> _setReaderTheme(String themeId) async {
    final nextTheme = ReaderThemes.byId(themeId);
    if (_readerThemeId == nextTheme.id) return;
    setState(() => _readerThemeId = nextTheme.id);
    if (_readerSystemUiApplied) await _applyReaderSystemUi();
    await _readerSettingsStore.save(_readerSettings);
  }

  Widget _buildStyledReaderText(
    _NativeChapter chapter,
    _ReaderPageData page, {
    required int chapterIndex,
    required int pageIndex,
    bool fillAvailableSpace = true,
  }) {
    final flowStyle = _readerTextFlowStyle();
    return ReaderAnnotatedTextPage(
      key: ValueKey(
        'native-annotated-page:${chapter.id}:$pageIndex:'
        '${page.startOffset}:${page.endOffset}',
      ),
      page: page,
      sourceText: chapter.plainText,
      chapterId: chapter.id,
      chapterTitle: chapter.title,
      chapterIndex: chapterIndex,
      pageIndex: pageIndex,
      bookId: widget.book.id,
      format: BookFormat.fromFileExtension(widget.book.format),
      renderer: ReaderRendererType.flutterNative,
      palette: _readerTheme,
      bodyStyle: _readerTextStyle,
      flowStyle: flowStyle,
      annotations: _annotations,
      spokenHighlight: _readerAloudHighlight,
      baseSourceSpanBuilder: (start, end) =>
          _styledSpanForRange(chapter, start, end, _readerTextStyle),
      onSaveTextAnnotation: _saveTextAnnotation,
      onAskAiSelection: _askAiAboutSelection,
      fillAvailableSpace: fillAvailableSpace,
      onInteractionChanged: (active) {
        if (!mounted || _annotationInteractionActive == active) return;
        setState(() => _annotationInteractionActive = active);
      },
    );
  }

  ReaderSafeAreaMetrics get _readerSafeArea => ReaderSafeAreaMetrics(
    viewPadding: MediaQuery.viewPaddingOf(context),
    topMargin: _topMargin,
    bottomMargin: _bottomMargin,
    topChromeReserve: _topChromeReserveFor(_topBarStyle),
  );

  /// 阅读信息栏占一条固定信息条；灵动信息栏借用状态栏区域，仅在设备
  /// 没有状态栏 inset（隐藏后归零）时补足最小高度，避免正文顶进时间与
  /// 电量。其余样式顶部只避开状态栏本身。
  double _topChromeReserveFor(ReaderTopBarStyle style) => switch (style) {
    ReaderTopBarStyle.reader => ReaderSafeAreaMetrics.readerTopBarReserve,
    ReaderTopBarStyle.floating => math.max(
      0,
      ReaderSafeAreaMetrics.floatingStatusMinHeight -
          MediaQuery.viewPaddingOf(context).top,
    ),
    _ => 0,
  };

  bool get _showLeafFloatingStatus =>
      _topBarStyle == ReaderTopBarStyle.floating;

  double get _floatingStatusHorizontalPadding =>
      math.max(32, _horizontalMargin);

  /// 阅读信息栏与灵动信息栏都画进纸页快照，需要随分钟时钟/电量刷新重绘。
  int get _leafContentRevision => Object.hash(
    _topBarStyle == ReaderTopBarStyle.reader || _showLeafFloatingStatus
        ? _leafStatusController.value.revision
        : 0,
    _annotationRevision,
  );

  double get _effectiveTopMargin => _readerSafeArea.contentTop;

  double get _effectiveBottomMargin => _readerSafeArea.contentBottom;

  bool _usesTwoPageLayout(Size size) =>
      _tabletTwoPageEnabled &&
      _pageMode != NativePageMode.verticalScroll &&
      ReaderLayoutBreakpoints.supportsTwoPageLayout(size);

  Size _paginationSize(Size viewport, bool usesTwoPageLayout) {
    if (!usesTwoPageLayout) return viewport;
    return Size((viewport.width - _spreadGutter) / 2, viewport.height);
  }

  int _spreadStartForPage(int pageIndex) => (pageIndex ~/ 2) * 2;

  Future<void> _updateLayout({
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    ReaderTextAlignment? textAlignment,
    int? firstLineIndent,
    int? paragraphSpacing,
    double? horizontalMargin,
    double? topMargin,
    double? bottomMargin,
  }) async {
    setState(() {
      _fontSize = fontSize ?? _fontSize;
      _lineHeight = (lineHeight ?? _lineHeight).clamp(1.4, 2.1);
      _letterSpacing = (letterSpacing ?? _letterSpacing).clamp(
        ReaderSettings.minLetterSpacing,
        ReaderSettings.maxLetterSpacing,
      );
      _textAlignment = textAlignment ?? _textAlignment;
      _firstLineIndent = (firstLineIndent ?? _firstLineIndent).clamp(0, 4);
      _paragraphSpacing = (paragraphSpacing ?? _paragraphSpacing).clamp(0, 2);
      _horizontalMargin = (horizontalMargin ?? _horizontalMargin).clamp(
        ReaderMarginSettings.horizontalMin,
        ReaderMarginSettings.horizontalMax,
      );
      _topMargin = (topMargin ?? _topMargin).clamp(
        ReaderMarginSettings.min,
        ReaderMarginSettings.max,
      );
      _bottomMargin = (bottomMargin ?? _bottomMargin).clamp(
        ReaderMarginSettings.min,
        ReaderMarginSettings.max,
      );
      _pageIndex = 0;
      _restoreAnchorAfterLayout = true;
    });
    await _readerSettingsStore.save(_readerSettings);
  }

  Future<void> _setTxtChapterTitlePageEnabled(bool value) async {
    if (_txtChapterTitlePageEnabled == value) return;
    setState(() {
      _txtChapterTitlePageEnabled = value;
      _pageIndex = 0;
      _restoreAnchorAfterLayout = true;
    });
    await _readerSettingsStore.saveTxtChapterTitlePageEnabled(value);
  }

  String get _layoutSignature =>
      '${_fontSize.toStringAsFixed(1)}:'
      '${_lineHeight.toStringAsFixed(2)}:'
      '${_letterSpacing.toStringAsFixed(1)}:${_textAlignment.name}:'
      '${_horizontalMargin.toStringAsFixed(1)}:'
      '${_topMargin.toStringAsFixed(1)}:'
      '${_bottomMargin.toStringAsFixed(1)}:${_pageMode.name}:'
      '$_firstLineIndent:$_paragraphSpacing:${_readerFont.id}:'
      '${widget.book.format.toLowerCase() == 'txt' ? _txtChapterTitlePageEnabled : true}';

  Future<void> _setTopBarStyle(ReaderTopBarStyle style) async {
    if (_topBarStyle == style) return;
    // 顶部预留高度随样式变化；完全沉浸在上下滚动时取消整个预留区域。
    final repaginate =
        _topChromeReserveFor(_topBarStyle) != _topChromeReserveFor(style) ||
        (_topBarStyle == ReaderTopBarStyle.hidden) !=
            (style == ReaderTopBarStyle.hidden);
    setState(() {
      _topBarStyle = style;
      if (repaginate) {
        _pageIndex = 0;
        _restoreAnchorAfterLayout = true;
      }
    });
    await ReaderSystemUiController.savePreference(style);
    await _applyReaderSystemUi();
  }

  void _saveCanonicalProgress(
    _NativeChapter chapter,
    _ReaderPageData page,
    int chapterIndex,
  ) {
    _anchorOffset = page.startOffset;
    final bookId = widget.book.id;
    if (bookId == null) return;
    final excerptEnd = (page.startOffset + 72).clamp(
      0,
      chapter.plainText.length,
    );
    final excerpt = chapter.plainText.substring(page.startOffset, excerptEnd);
    final locator = CanonicalLocator.fromComponents(
      format: BookFormat.fromFileExtension(widget.book.format),
      chapterId: chapter.id,
      offset: page.startOffset,
      excerpt: excerpt,
      progression: chapter.plainText.isEmpty
          ? 0
          : page.startOffset / chapter.plainText.length,
    );
    final chapterProgress = chapter.plainText.isEmpty
        ? 1.0
        : (page.endOffset / chapter.plainText.length).clamp(0.0, 1.0);
    final chapterCount = _loadedChapters.length;
    final readingProgress = chapterCount <= 0
        ? null
        : ((chapterIndex + chapterProgress) / chapterCount).clamp(0.0, 1.0);
    BookDao().updateBookCanonicalLocator(
      bookId,
      LocatorCodec.encodeCanonicalLocator(locator),
      null,
      _layoutSignature,
      chapterIndex,
      readingProgress: readingProgress,
    );
  }

  Future<void> _setPageMode(NativePageMode mode) async {
    if (_pageMode == mode) return;
    final previousPageController = _pageController;
    _pageController = null;
    _pageControllerGeneration++;
    setState(() {
      _pageMode = mode;
      _pageIndex = 0;
      _restoreAnchorAfterLayout = true;
      _lastSavedLocation = null;
      _horizontalFirstChapter = (_chapterIndex - 1).clamp(0, _chapterIndex);
      _horizontalLastChapter = _chapterIndex + 1;
      _horizontalBackwardExpansionPending = false;
      _horizontalBackwardExpansionWarmPending = false;
      _horizontalForwardContractionPending = false;
      _controlsVisible = false;
    });
    if (previousPageController != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => previousPageController.dispose(),
      );
    }
    unawaited(_syncVolumeKeyPaging());
    await _readerSettingsStore.save(_readerSettings);
  }

  Future<void> _setScrollByChapter(bool value) async {
    if (_scrollByChapter == value) return;
    setState(() {
      _scrollByChapter = value;
      _controlsVisible = false;
    });
    await _readerSettingsStore.saveScrollByChapter(value);
  }

  void _resolveSavedChapter(List<_NativeChapter> chapters) {
    if (_savedChapterResolved) return;
    _savedChapterResolved = true;
    final savedChapterId = _savedChapterId;
    if (savedChapterId == null || savedChapterId.isEmpty) return;
    final resolvedIndex = chapters.indexWhere(
      (chapter) => chapter.id == savedChapterId,
    );
    if (resolvedIndex < 0) return;
    _chapterIndex = resolvedIndex;
    _horizontalFirstChapter = (resolvedIndex - 1).clamp(0, resolvedIndex);
    _horizontalLastChapter = resolvedIndex + 1;
  }

  void _scheduleInitialContinuousScrollRestore(Size viewport) {
    if (_initialPositionRestored || _initialPositionRestoreScheduled) return;
    if ((_anchorOffset ?? 0) <= 0) {
      _initialPositionRestored = true;
      return;
    }
    _initialPositionRestoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controllerReady = _scrollByChapter
          ? _verticalPageScrollController.isAttached
          : _verticalChapterScrollController.isAttached;
      if (!controllerReady) {
        _initialPositionRestoreScheduled = false;
        _scheduleInitialContinuousScrollRestore(viewport);
        return;
      }
      final chapter = _loadedChapters[_chapterIndex];
      final parts = _continuousPartsFor(chapter, viewport);
      var precedingExtent = 0.0;
      for (final part in parts.take(_pageIndex)) {
        precedingExtent += _measureContinuousPartExtent(
          chapter,
          part,
          viewport,
        );
      }
      if (!_scrollByChapter && precedingExtent > 0) {
        unawaited(
          _verticalChapterOffsetController
              .animateScroll(
                offset: precedingExtent,
                duration: const Duration(milliseconds: 1),
              )
              .catchError((error) {
                debugPrint('restore continuous reader offset failed: $error');
              }),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _scrollContinuousAnchorIntoView(
            chapter,
            parts,
            _pageIndex,
            _anchorOffset ?? parts[_pageIndex].content.startOffset,
          ).whenComplete(() {
            if (!mounted) return;
            setState(() {
              _initialPositionRestored = true;
              _initialPositionRestoreScheduled = false;
            });
          }),
        );
      });
    });
  }

  double _measureContinuousPartExtent(
    _NativeChapter chapter,
    _ContinuousReaderPart part,
    Size viewport,
  ) {
    if (part.content.isChapterTitle) return _verticalPageExtentFor(viewport);
    final imageExtent = part.imageBlockIndex == null ? 0.0 : 444.0;
    if (part.content.text.isEmpty) return imageExtent;
    final painter =
        _readerTextFlowStyle(
            direction: _verticalTextDirection,
            textScaler: _verticalTextScaler,
          ).createPainter(
            part.content.buildSpan(
              style: _readerTextStyle,
              sourceSpanBuilder: (start, end) =>
                  _styledSpanForRange(chapter, start, end, _readerTextStyle),
            ),
          )
          ..layout(
            maxWidth: readerTextContentWidth(viewport.width, _horizontalMargin),
          );
    final extent = painter.height + imageExtent;
    painter.dispose();
    return extent;
  }

  Future<List<_NativeChapter>> _loadBook() async {
    final l10n = context.l10n;
    final format = widget.book.format.toLowerCase();
    final webBytes = kIsWeb
        ? await WebBookFileStore().read(widget.book.filePath)
        : null;
    if (kIsWeb && webBytes == null) {
      throw StateError('Web 书籍文件不存在');
    }
    if (format == 'txt') {
      if (webBytes != null) {
        final decoded = EnhancedTxtImportService().decodeWithOverride(
          webBytes,
          encodingOverride: widget.book.textEncoding,
          verifyEncodingOverride: true,
        );
        return _parseTxtChapters(
          decoded,
          widget.book.title,
          l10n.readerPrefaceTitle,
        );
      }
      final sourceFile = File(widget.book.filePath);
      final fileSize = await sourceFile.length();
      final useParsedCache = fileSize <= _largeTxtFileThreshold;
      final cacheDirectory = Directory(
        path.join(
          (await getApplicationSupportDirectory()).path,
          'native_reader_cache',
        ),
      );
      final cacheName = sha1.convert(utf8.encode(_bookCacheKey)).toString();
      final cachePath = path.join(cacheDirectory.path, '$cacheName.json');
      if (useParsedCache) {
        final cached = await compute(_readParsedChapterCache, cachePath);
        if (cached != null) {
          return cached.map(_nativeChapterFromMap).toList(growable: false);
        }
      }

      final parseArguments = <String, dynamic>{
        'path': sourceFile.path,
        'encoding': widget.book.textEncoding,
        'title': widget.book.title,
        'prefaceTitle': l10n.readerPrefaceTitle,
      };
      if (!useParsedCache) {
        final indexPath = '$cachePath.index';
        final dataPath = '$cachePath.data';
        // A cached index avoids the expensive scan, but materializing its
        // chapter descriptors and loading the initial text window can still
        // be substantial for very large books. Keep that work out of the
        // cover flight just like first-time indexing.
        if (!await _waitForOpeningRouteToSettle()) {
          return const <_NativeChapter>[];
        }
        final cachedIndex = await compute(_readLargeTxtIndexCache, indexPath);
        if (cachedIndex != null) {
          return _nativeChaptersFromFileIndex(cachedIndex);
        }

        // A first-time 70 MB index can saturate CPU and storage bandwidth even
        // though it runs in another isolate. Keep it completely outside the
        // cover flight and cover-to-loader handoff so opening motion stays
        // responsive; cached indexes only wait for the route itself above.
        if (!await _waitForLargeTxtIndexingWindow()) {
          return const <_NativeChapter>[];
        }

        unawaited(
          compute(
            _deleteOversizedParsedChapterCaches,
            cacheDirectory.path,
          ).catchError((_) {}),
        );

        // The worker writes normalized UTF-8 chapter data to disk and returns
        // only offsets/titles. The UI isolate loads one chapter at a time.
        final indexed = await compute(
          _indexTxtFileInBackground,
          <String, dynamic>{
            ...parseArguments,
            'indexPath': indexPath,
            'dataPath': dataPath,
          },
        );
        return _nativeChaptersFromFileIndex(indexed);
      }

      // Small TXT books can keep using the JSON chapter cache.
      final parsed = await compute(_parseTxtFileInBackground, parseArguments);
      if (useParsedCache) {
        unawaited(
          compute(_writeParsedChapterCache, <String, dynamic>{
            'path': cachePath,
            'chapters': parsed,
          }).catchError((_) {}),
        );
      }
      return parsed.map(_nativeChapterFromMap).toList(growable: false);
    }

    if (format == 'epub' && !kIsWeb) {
      final sourceFile = File(widget.book.filePath);
      final cacheBase = await _readerCacheDirectory();
      final cacheDirectory = Directory(
        path.join(cacheBase.path, 'native_reader_cache', 'epub'),
      );
      final cacheKey = sha1.convert(utf8.encode(_bookCacheKey)).toString();
      final cacheRoot = path.join(cacheDirectory.path, cacheKey);
      final indexPath = path.join(cacheRoot, 'index.json');
      final sourceSize = await sourceFile.length();
      final sourceModifiedMillis =
          (await sourceFile.lastModified()).millisecondsSinceEpoch;
      final arguments = <String, dynamic>{
        'epubPath': sourceFile.path,
        'cacheDirectory': cacheRoot,
        'indexPath': indexPath,
        'sourceSize': sourceSize,
        'sourceModifiedMillis': sourceModifiedMillis,
        'familyPrefix': cacheKey,
      };
      final cached = await compute(readEpubNativeIndex, arguments);
      final Map<String, dynamic> index;
      if (cached != null) {
        index = cached;
      } else {
        final staleCache = Directory(cacheRoot);
        if (await staleCache.exists()) {
          await staleCache.delete(recursive: true);
        }
        index = await compute(buildEpubNativeIndex, arguments);
      }
      final chapters = (index['chapters'] as List<dynamic>? ?? const [])
          .map(
            (chapter) => _NativeChapter.lazyEpub(
              descriptor: Map<String, dynamic>.from(chapter as Map),
              loadArguments: <String, dynamic>{
                'epubPath': sourceFile.path,
                'cacheDirectory': cacheRoot,
                'cssPaths': index['cssPaths'],
                'familyPrefix': cacheKey,
              },
            ),
          )
          .toList(growable: false);
      final navigation = (index['navigation'] as List<dynamic>? ?? const [])
          .map((entry) {
            final values = Map<String, dynamic>.from(entry as Map);
            final chapterIndex = values['chapterIndex'] as int;
            return ReaderNavigationChapter(
              title: values['title'] as String? ?? '',
              index: chapterIndex,
              id: chapters[chapterIndex].id,
              depth: values['depth'] as int? ?? 0,
            );
          })
          .toList(growable: false);
      if (navigation.isNotEmpty) {
        _navigationMemoryCache[_bookCacheKey] = navigation;
      }
      return chapters;
    }

    final bytes = webBytes ?? await File(widget.book.filePath).readAsBytes();
    switch (format) {
      case 'epub':
        return _richChaptersFromParsed(
          await compute(_parseEpubChapters, bytes),
        );
      case 'mobi':
      case 'azw':
      case 'azw3':
        try {
          return _richChaptersFromParsed(
            await compute(_parseKindleChapters, bytes),
          );
        } on KindleDrmException {
          throw _ReaderBookLoadException(l10n.readerKindleDrmProtected);
        }
      case 'html':
      case 'htm':
      case 'xhtml':
        return _parseHtmlDocument(
          utf8.decode(bytes, allowMalformed: true),
          widget.book.title,
        );
      case 'md':
      case 'markdown':
        return _parseMarkdownDocument(
          utf8.decode(bytes, allowMalformed: true),
          widget.book.title,
          l10n.readerPrefaceTitle,
        );
      case 'fb2':
        return _parseFb2Document(
          utf8.decode(bytes, allowMalformed: true),
          widget.book.title,
        );
      case 'rtf':
        return _parseTxtChapters(
          _extractRtfText(bytes),
          widget.book.title,
          l10n.readerPrefaceTitle,
        );
      case 'docx':
        return _parseTxtChapters(
          _extractDocxText(bytes),
          widget.book.title,
          l10n.readerPrefaceTitle,
        );
      default:
        throw UnsupportedError(l10n.readerUnsupportedFormat);
    }
  }

  Future<bool> _waitForOpeningRouteToSettle() async {
    return waitForReaderOpeningRouteToSettle(
      routeAnimation: _routeAnimation,
      routeEntranceCompleted: _routeEntranceCompleted,
      isMounted: () => mounted,
    );
  }

  Future<bool> _waitForLargeTxtIndexingWindow() async {
    if (!await _waitForOpeningRouteToSettle()) return false;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return mounted &&
        (_routeAnimation == null ||
            _routeAnimation!.status == AnimationStatus.completed);
  }

  Future<void> _setChapter(
    int index,
    int chapterCount, {
    bool recenterContinuousScroll = false,
  }) async {
    final next = index.clamp(0, chapterCount - 1);
    if (next == _chapterIndex && !recenterContinuousScroll) return;
    final loadSerial = ++_chapterLoadSerial;
    final chapters = _loadedChapters.isNotEmpty
        ? _loadedChapters
        : await _chaptersFuture;
    if (next >= chapters.length) return;
    await _loadIndexedChapterWindow(chapters, next);
    if (!mounted || loadSerial != _chapterLoadSerial) return;
    final previousPageController = _pageMode == NativePageMode.horizontalSlide
        ? _pageController
        : null;
    if (previousPageController != null) {
      _pageController = null;
      _pageControllerGeneration++;
    }
    setState(() {
      _chapterIndex = next;
      _pageIndex = 0;
      _horizontalFirstChapter = (next - 1).clamp(0, next);
      _horizontalLastChapter = next + 1;
      _horizontalBackwardExpansionPending = false;
      _horizontalBackwardExpansionWarmPending = false;
      _horizontalForwardContractionPending = false;
      if (previousPageController != null) {
        _horizontalChapterJumpPending = true;
        _horizontalChapterJumpRevealScheduled = false;
        _initialPositionRestored = false;
      }
    });
    if (previousPageController != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => previousPageController.dispose(),
      );
    }
    _verticalScrollProgress.value = 0;
    if (recenterContinuousScroll &&
        _pageMode == NativePageMode.verticalScroll &&
        !_scrollByChapter) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && _verticalChapterScrollController.isAttached) {
        await _verticalChapterScrollController.scrollTo(
          index: next,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }
    final bookId = widget.book.id;
    if (bookId != null) {
      await BookDao().updateBookProgress(bookId, next);
    }
  }

  void _nextPage(
    List<_ReaderPageData> pages,
    int chapterCount, {
    required bool usesTwoPageLayout,
    bool animate = true,
  }) {
    if (_pageMode == NativePageMode.pageCurl && animate) {
      final controller = usesTwoPageLayout
          ? _spreadForwardPageCurlController
          : _pageCurlController;
      unawaited(controller.turnForward());
      return;
    }
    if (_pageMode == NativePageMode.coverSlide && animate) {
      unawaited(_coverPageTurnController.turnForward());
      return;
    }
    final pageController = _pageController;
    if (_pageMode == NativePageMode.horizontalSlide &&
        pageController != null &&
        pageController.hasClients) {
      if (animate) {
        pageController.nextPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        pageController.jumpToPage((pageController.page?.round() ?? 0) + 1);
      }
      return;
    }
    final pageStep = usesTwoPageLayout ? 2 : 1;
    if (_pageIndex + pageStep < pages.length) {
      _sessionPagesRead++;
      setState(() => _pageIndex += pageStep);
    } else if (_chapterIndex < chapterCount - 1) {
      _sessionPagesRead++;
      _setChapter(_chapterIndex + 1, chapterCount);
    }
  }

  void _previousPage(
    List<_ReaderPageData> pages,
    int chapterCount, {
    required bool usesTwoPageLayout,
    bool animate = true,
  }) {
    if (_pageMode == NativePageMode.pageCurl && animate) {
      final controller = usesTwoPageLayout
          ? _spreadBackwardPageCurlController
          : _pageCurlController;
      unawaited(controller.turnBackward());
      return;
    }
    if (_pageMode == NativePageMode.coverSlide && animate) {
      unawaited(_coverPageTurnController.turnBackward());
      return;
    }
    final pageController = _pageController;
    if (_pageMode == NativePageMode.horizontalSlide &&
        pageController != null &&
        pageController.hasClients) {
      if (animate) {
        pageController.previousPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        pageController.jumpToPage(
          math.max(0, (pageController.page?.round() ?? 0) - 1),
        );
      }
      return;
    }
    final pageStep = usesTwoPageLayout ? 2 : 1;
    if (_pageIndex >= pageStep) {
      setState(() => _pageIndex -= pageStep);
    } else if (_chapterIndex > 0) {
      _openPreviousChapterAtLastPage = true;
      _setChapter(_chapterIndex - 1, chapterCount);
    }
  }

  void _handleHorizontalSwipe(
    DragEndDetails details,
    List<_ReaderPageData> pages,
    int chapterCount,
    bool usesTwoPageLayout,
  ) {
    if (_annotationInteractionActive) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_pageMode == NativePageMode.horizontalSlide ||
        _pageMode == NativePageMode.coverSlide ||
        _pageMode == NativePageMode.pageCurl) {
      return;
    }
    if (_pageMode == NativePageMode.instantPage) {
      if (velocity < -350) {
        _nextPage(pages, chapterCount, usesTwoPageLayout: usesTwoPageLayout);
      } else if (velocity > 350) {
        _previousPage(
          pages,
          chapterCount,
          usesTwoPageLayout: usesTwoPageLayout,
        );
      }
      return;
    }
    if (!_scrollByChapter) return;
    if (velocity < -350) {
      _setChapter(_chapterIndex + 1, chapterCount);
    } else if (velocity > 350) {
      _setChapter(_chapterIndex - 1, chapterCount);
    }
  }

  void _handleTap(
    Offset localPosition,
    Size viewportSize,
    List<_ReaderPageData> pages,
    int chapterCount,
    bool usesTwoPageLayout,
  ) {
    if (_annotationInteractionActive) return;
    switch (_tapZones.actionAt(localPosition, viewportSize)) {
      case ReaderTapZoneAction.menu:
        _toggleControls();
      case ReaderTapZoneAction.none:
        break;
      case ReaderTapZoneAction.previousPage:
        // 上下翻页由滚动手势负责，点击翻页保持关闭。
        if (_pageMode == NativePageMode.verticalScroll) return;
        _previousPage(
          pages,
          chapterCount,
          usesTwoPageLayout: usesTwoPageLayout,
          animate: _tapPageAnimationEnabled,
        );
      case ReaderTapZoneAction.nextPage:
        if (_pageMode == NativePageMode.verticalScroll) return;
        _nextPage(
          pages,
          chapterCount,
          usesTwoPageLayout: usesTwoPageLayout,
          animate: _tapPageAnimationEnabled,
        );
      case ReaderTapZoneAction.previousChapter:
        if (_chapterIndex > 0) {
          unawaited(
            _setChapter(
              _chapterIndex - 1,
              chapterCount,
              recenterContinuousScroll: true,
            ),
          );
        }
      case ReaderTapZoneAction.nextChapter:
        if (_chapterIndex < chapterCount - 1) {
          unawaited(
            _setChapter(
              _chapterIndex + 1,
              chapterCount,
              recenterContinuousScroll: true,
            ),
          );
        }
    }
  }

  void _handleReaderTap(Offset localPosition) {
    _handleTap(
      localPosition,
      _readerViewportSize,
      _visiblePages,
      _visibleChapterCount,
      _visibleUsesTwoPageLayout,
    );
  }

  void _setTapZones(ReaderTapZones zones) {
    if (zones == _tapZones) return;
    setState(() => _tapZones = zones);
    unawaited(_readerSettingsStore.saveTapZones(zones));
  }

  Future<void> _showTapZoneSettings() async {
    Navigator.of(context).pop();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() {
      _controlsVisible = false;
      _tapZoneEditorVisible = true;
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  String _readerThemeName(BuildContext context, String themeId) {
    final customName = ReaderThemes.customThemeById(themeId)?.name.trim();
    if (customName != null && customName.isNotEmpty) return customName;
    switch (themeId) {
      case ReaderThemes.systemId:
        return context.l10n.readerThemeFollowSystem;
      case 'mist':
        return context.l10n.readerThemeMist;
      case 'green':
        return context.l10n.readerThemeGreen;
      case 'rose':
        return context.l10n.readerThemeRose;
      case 'navy':
        return context.l10n.readerThemeNavy;
      case 'night':
        return context.l10n.readerThemeNight;
      case 'pureBlack':
        return context.l10n.readerThemePureBlack;
      case 'parchment':
        return context.l10n.readerThemeParchment;
      case ReaderCustomTheme.themeId:
        return context.l10n.readerThemeCustom;
      default:
        return context.l10n.readerThemeDay;
    }
  }

  ReaderAloudController? _ensureReaderAloudController() {
    final existing = _readerAloudController;
    if (existing != null) return existing;
    ReaderAloudService aloudService;
    try {
      aloudService = context.read<ReaderAloudService>();
    } on ProviderNotFoundException {
      return null;
    }
    final controller = ReaderAloudController(
      engine: aloudService,
      notificationSink: AndroidReaderAloudNotification.instance,
      source: CallbackReaderAloudSource(
        bookTitle: widget.book.title,
        chapterCount: () => _loadedChapters.length,
        currentPosition: () async {
          final chapterIndex = _chapterIndex
              .clamp(0, math.max(0, _loadedChapters.length - 1))
              .toInt();
          var offset = _anchorOffset ?? 0;
          if (_pageMode == NativePageMode.verticalScroll &&
              _visibleContinuousParts.isNotEmpty) {
            offset =
                _visibleContinuousParts[_pageIndex.clamp(
                      0,
                      _visibleContinuousParts.length - 1,
                    )]
                    .content
                    .startOffset;
          } else if (_visiblePages.isNotEmpty) {
            offset =
                _visiblePages[_pageIndex.clamp(0, _visiblePages.length - 1)]
                    .startOffset;
          }
          return ReaderAloudPosition(
            chapterIndex: chapterIndex,
            offset: offset,
          );
        },
        loadChapter: (index) async {
          if (index < 0 || index >= _loadedChapters.length) return null;
          final chapter = _loadedChapters[index];
          await chapter.loadTextAsync();
          return ReaderAloudChapter(
            index: index,
            id: chapter.id,
            title: chapter.title,
            text: chapter.plainText,
          );
        },
        revealPosition: _revealReaderAloudPosition,
        persistPosition: _persistReaderAloudPosition,
      ),
    )..addListener(_onReaderAloudChanged);
    _readerAloudController = controller;
    return controller;
  }

  void _onReaderAloudChanged() {
    final active = _readerAloudController?.isActive ?? false;
    final highlight = _readerAloudController?.highlight;
    if (!mounted) return;
    if (active == _readerAloudActive && highlight == _readerAloudHighlight) {
      return;
    }
    setState(() {
      _readerAloudActive = active;
      _readerAloudHighlight = highlight;
    });
  }

  Future<void> _revealReaderAloudPosition(ReaderAloudPosition position) async {
    if (!mounted || _loadedChapters.isEmpty) return;
    final chapterIndex = position.chapterIndex.clamp(
      0,
      _loadedChapters.length - 1,
    );
    final chapter = _loadedChapters[chapterIndex];
    await chapter.loadTextAsync();
    final offset = position.offset.clamp(0, chapter.plainText.length);
    final excerptEnd = (offset + 72).clamp(offset, chapter.plainText.length);
    final locator = CanonicalLocator.fromComponents(
      format: BookFormat.fromFileExtension(widget.book.format),
      chapterId: chapter.id,
      offset: offset,
      excerpt: chapter.plainText.substring(offset, excerptEnd),
      progression: chapter.plainText.isEmpty
          ? 0
          : offset / chapter.plainText.length,
    );
    final revealsWithinCurrentChapter = chapterIndex == _chapterIndex;
    await _jumpToBookmark(
      Bookmark(
        bookId: widget.book.id ?? 0,
        pageNumber: chapterIndex,
        chapterIndex: chapterIndex,
        chapterTitle: chapter.title,
        canonicalLocator: LocatorCodec.encodeCanonicalLocator(locator),
      ),
      _loadedChapters,
    );
    if (revealsWithinCurrentChapter &&
        mounted &&
        _pageMode != NativePageMode.verticalScroll) {
      setState(() {});
    }
  }

  Future<void> _persistReaderAloudPosition(ReaderAloudPosition position) async {
    final bookId = widget.book.id;
    if (bookId == null || _loadedChapters.isEmpty) return;
    final chapterIndex = position.chapterIndex.clamp(
      0,
      _loadedChapters.length - 1,
    );
    final chapter = _loadedChapters[chapterIndex];
    await chapter.loadTextAsync();
    final offset = position.offset.clamp(0, chapter.plainText.length);
    final excerptEnd = (offset + 72).clamp(offset, chapter.plainText.length);
    final locator = CanonicalLocator.fromComponents(
      format: BookFormat.fromFileExtension(widget.book.format),
      chapterId: chapter.id,
      offset: offset,
      excerpt: chapter.plainText.substring(offset, excerptEnd),
      progression: chapter.plainText.isEmpty
          ? 0
          : offset / chapter.plainText.length,
    );
    _anchorOffset = offset;
    await BookDao().updateBookCanonicalLocator(
      bookId,
      LocatorCodec.encodeCanonicalLocator(locator),
      null,
      _layoutSignature,
      chapterIndex,
      readingProgress:
          (chapterIndex +
              (chapter.plainText.isEmpty
                  ? 1.0
                  : offset / chapter.plainText.length)) /
          _loadedChapters.length,
    );
  }

  Future<void> _showReaderAloudPanel() async {
    final controller = _ensureReaderAloudController();
    if (controller == null) return;
    final ttsService = context.read<TtsService>();
    final aloudService = context.read<ReaderAloudService>();
    await showReaderAloudPanelSheet(
      context: context,
      controller: controller,
      ttsService: ttsService,
      aloudService: aloudService,
      palette: _readerTheme,
      themeData: _readerThemeData,
    );
  }

  Future<void> _showAskAiPanel(
    _NativeChapter chapter,
    _ReaderPageData page,
  ) async {
    final pageText = page.text.trim().isEmpty ? chapter.plainText : page.text;
    await showReaderAiPanelSheet(
      context: context,
      palette: _readerTheme,
      themeData: _readerThemeData,
      meta: AIRequestMeta(
        bookId: widget.book.id?.toString() ?? '',
        chapterId: chapter.id,
        pageIndex: _pageIndex,
      ),
      pageText: pageText,
      bookTitle: widget.book.title,
    );
  }

  Future<void> _askAiAboutSelection(ReaderSelectionSnapshot selection) async {
    await showReaderAiPanelSheet(
      context: context,
      palette: _readerTheme,
      themeData: _readerThemeData,
      meta: AIRequestMeta(
        bookId: widget.book.id?.toString() ?? '',
        chapterId: selection.chapterId,
        pageIndex: selection.pageIndex,
      ),
      pageText: readerAiPageContextFromSelection(selection),
      bookTitle: widget.book.title,
      selection: ReaderAiSelectionContext(
        selectedText: selection.selectedText,
        contextBefore: selection.prefix,
        contextAfter: selection.suffix,
      ),
    );
  }

  Future<void> _showReadingSettings() async {
    final selectedMode = await showModalBottomSheet<NativePageMode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => ReaderSettingsSheet(
        title: context.l10n.readingSettings,
        tabThemeLabel: context.l10n.readerSettingsTabTheme,
        tabTextLabel: context.l10n.readerSettingsTabText,
        tabLayoutLabel: context.l10n.readerSettingsTabLayout,
        tabPagingLabel: context.l10n.readerSettingsTabPaging,
        advancedTypographyTitle: context.l10n.readerSettingsAdvancedTypography,
        themeDescription: context.l10n.readerThemeDescription,
        pageModeTitle: context.l10n.pageTurningMode,
        pageModeSummary: _pageModeSummary(context),
        topBarStyleTitle: context.l10n.readerTopBarStyleTitle,
        topBarStyleSummary: _topBarStyleTitle(_topBarStyle),
        pullBookmarkTitle: context.l10n.readerPullBookmarkTitle,
        pullBookmarkHint: context.l10n.readerPullBookmarkHint,
        tapPageAnimationTitle: context.l10n.readerTapAnimationTitle,
        tapPageAnimationHint: context.l10n.readerTapAnimationHint,
        tapZonesTitle: context.l10n.tapZoneSettings,
        tapZonesHint: context.l10n.tapZoneSettingsHint,
        showTabletTwoPageToggle: ReaderLayoutBreakpoints.isTablet(
          MediaQuery.sizeOf(context),
        ),
        tabletTwoPageTitle: context.l10n.readerTabletTwoPageTitle,
        tabletTwoPageHint: context.l10n.readerTabletTwoPageHint,
        fontSizeLabel: context.l10n.fontSizeLabel,
        lineHeightLabel: context.l10n.lineSpacingLabel,
        letterSpacingLabel: context.l10n.letterSpacingLabel,
        textAlignmentLabel: context.l10n.textAlignmentLabel,
        textAlignmentNaturalLabel: context.l10n.textAlignmentNatural,
        textAlignmentJustifiedLabel: context.l10n.textAlignmentJustified,
        firstLineIndentLabel: context.l10n.firstLineIndentLabel,
        paragraphSpacingLabel: context.l10n.paragraphSpacingLabel,
        horizontalMarginLabel: context.l10n.readerHorizontalMarginLabel,
        topMarginLabel: context.l10n.readerTopMarginLabel,
        bottomMarginLabel: context.l10n.readerBottomMarginLabel,
        txtChapterTitlePageTitle: widget.book.format.toLowerCase() == 'txt'
            ? context.l10n.readerTxtChapterTitlePageTitle
            : null,
        txtChapterTitlePageHint: widget.book.format.toLowerCase() == 'txt'
            ? context.l10n.readerTxtChapterTitlePageHint
            : null,
        themeId: _readerThemeId,
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        letterSpacing: _letterSpacing,
        textAlignment: _textAlignment,
        firstLineIndent: _firstLineIndent,
        paragraphSpacing: _paragraphSpacing,
        horizontalMargin: _horizontalMargin,
        topMargin: _topMargin,
        bottomMargin: _bottomMargin,
        pullBookmarkEnabled: _pullBookmarkEnabled,
        tapPageAnimationEnabled: _tapPageAnimationEnabled,
        tabletTwoPageEnabled: _tabletTwoPageEnabled,
        txtChapterTitlePageEnabled: widget.book.format.toLowerCase() == 'txt'
            ? _txtChapterTitlePageEnabled
            : null,
        themeLabelFor: (id) => _readerThemeName(context, id),
        onThemeChanged: (id) => unawaited(_setReaderTheme(id)),
        onCustomThemeTap: _showCustomThemeEditor,
        onPageModeTap: _showPageModeSettings,
        onTopBarStyleTap: _showTopBarStyleSettings,
        onTapZonesTap: () => unawaited(_showTapZoneSettings()),
        onFontSizeChanged: (value) => unawaited(_updateLayout(fontSize: value)),
        onLineHeightChanged: (value) =>
            unawaited(_updateLayout(lineHeight: value)),
        onLetterSpacingChanged: (value) =>
            unawaited(_updateLayout(letterSpacing: value)),
        onTextAlignmentChanged: (value) =>
            unawaited(_updateLayout(textAlignment: value)),
        onFirstLineIndentChanged: (value) =>
            unawaited(_updateLayout(firstLineIndent: value)),
        onParagraphSpacingChanged: (value) =>
            unawaited(_updateLayout(paragraphSpacing: value)),
        onHorizontalMarginChanged: (value) =>
            unawaited(_updateLayout(horizontalMargin: value)),
        onTopMarginChanged: (value) =>
            unawaited(_updateLayout(topMargin: value)),
        onBottomMarginChanged: (value) =>
            unawaited(_updateLayout(bottomMargin: value)),
        onPullBookmarkChanged: (value) =>
            unawaited(_setInteractionPreferences(pullBookmark: value)),
        onTapPageAnimationChanged: (value) =>
            unawaited(_setInteractionPreferences(tapAnimation: value)),
        onTabletTwoPageChanged: (value) =>
            unawaited(_setTabletTwoPageEnabled(value)),
        onTxtChapterTitlePageChanged: widget.book.format.toLowerCase() == 'txt'
            ? (value) => unawaited(_setTxtChapterTitlePageEnabled(value))
            : null,
      ),
    );
    if (!mounted) return;
    await _applyReaderSystemUi();
    if (selectedMode == null || !mounted) return;
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _setPageMode(selectedMode);
  }

  Future<void> _setInteractionPreferences({
    bool? pullBookmark,
    bool? tapAnimation,
  }) async {
    setState(() {
      _pullBookmarkEnabled = pullBookmark ?? _pullBookmarkEnabled;
      _tapPageAnimationEnabled = tapAnimation ?? _tapPageAnimationEnabled;
    });
    await _readerSettingsStore.save(_readerSettings);
  }

  Future<void> _setTabletTwoPageEnabled(bool value) async {
    if (_tabletTwoPageEnabled == value) return;
    setState(() {
      _tabletTwoPageEnabled = value;
      _restoreAnchorAfterLayout = true;
      _lastSavedLocation = null;
    });
    await _readerSettingsStore.save(_readerSettings);
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
    setState(() {
      if (result.selectedThemeId != null) {
        _readerThemeId = result.selectedThemeId!;
      } else if (ReaderCustomTheme.isCustomThemeId(_readerThemeId) &&
          ReaderThemes.customThemeById(_readerThemeId) == null) {
        _readerThemeId = ReaderSettings.defaultThemeId;
      }
    });
    await _readerSettingsStore.save(_readerSettings);
    await _applyReaderSystemUi();
  }

  String _pageModeSummary(BuildContext context) {
    switch (_pageMode) {
      case NativePageMode.verticalScroll:
        return _scrollByChapter
            ? context.l10n.readerModeVerticalScrollHint
            : context.l10n.readerModeWholeBookScrollHint;
      case NativePageMode.instantPage:
        return context.l10n.readerModeHorizontalPageHint;
      case NativePageMode.horizontalSlide:
        return context.l10n.readerModeHorizontalSlideHint;
      case NativePageMode.coverSlide:
        return context.l10n.readerModeCoverSlideHint;
      case NativePageMode.pageCurl:
        return context.l10n.readerModePageCurlHint;
    }
  }

  Future<void> _showPageModeSettings() async {
    var previewScrollByChapter = _scrollByChapter;
    final selectedMode = await showModalBottomSheet<NativePageMode>(
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
          hintFor: (mode) => mode == NativePageMode.verticalScroll
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

  String _pageModeTitle(NativePageMode mode) => switch (mode) {
    NativePageMode.verticalScroll => context.l10n.pageTurningScroll,
    NativePageMode.instantPage => context.l10n.readerModeHorizontalPage,
    NativePageMode.horizontalSlide => context.l10n.pageTurningSlide,
    NativePageMode.coverSlide => context.l10n.readerModeCoverSlide,
    NativePageMode.pageCurl => context.l10n.readerModePageCurl,
  };

  String _pageModeHint(NativePageMode mode) => switch (mode) {
    NativePageMode.verticalScroll => context.l10n.readerModeVerticalScrollHint,
    NativePageMode.instantPage => context.l10n.readerModeHorizontalPageHint,
    NativePageMode.horizontalSlide =>
      context.l10n.readerModeHorizontalSlideHint,
    NativePageMode.coverSlide => context.l10n.readerModeCoverSlideHint,
    NativePageMode.pageCurl => context.l10n.readerModePageCurlHint,
  };

  String _topBarStyleTitle(ReaderTopBarStyle style) => switch (style) {
    ReaderTopBarStyle.system => context.l10n.readerTopBarStyleSystem,
    ReaderTopBarStyle.reader => context.l10n.readerTopBarStyleReader,
    ReaderTopBarStyle.floating => context.l10n.readerTopBarStyleFloating,
    ReaderTopBarStyle.hidden => context.l10n.readerTopBarStyleHidden,
  };

  String _topBarStyleHint(ReaderTopBarStyle style) => switch (style) {
    ReaderTopBarStyle.system => context.l10n.readerTopBarStyleSystemHint,
    ReaderTopBarStyle.reader => context.l10n.readerTopBarStyleReaderHint,
    ReaderTopBarStyle.floating => context.l10n.readerTopBarStyleFloatingHint,
    ReaderTopBarStyle.hidden => context.l10n.readerTopBarStyleHiddenHint,
  };

  _ReaderPageData _bookmarkPageFor(List<_ReaderPageData> pages) {
    if (_pageMode == NativePageMode.verticalScroll) {
      if (_visibleContinuousParts.isNotEmpty &&
          _visibleChapters.isNotEmpty &&
          _chapterIndex < _visibleChapters.length) {
        final partIndex = _pageIndex.clamp(
          0,
          _visibleContinuousParts.length - 1,
        );
        final offset =
            _verticalCanonicalOffset ??
            _visibleContinuousParts[partIndex].content.startOffset;
        return _ReaderPageData(
          text: '',
          startOffset: offset,
          endOffset: offset,
        );
      }
    }
    return pages[_pageIndex.clamp(0, pages.length - 1)];
  }

  String _bookmarkAnchorKey(_NativeChapter chapter, _ReaderPageData page) =>
      '${chapter.id}:${page.startOffset}';

  String _bookmarkExcerpt(_NativeChapter chapter, _ReaderPageData page) {
    final start = page.startOffset.clamp(0, chapter.plainText.length);
    final end = (start + 120).clamp(start, chapter.plainText.length);
    return chapter.plainText
        .substring(start, end)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _toggleBookmark(
    _NativeChapter chapter,
    _ReaderPageData page,
  ) async {
    final bookId = widget.book.id;
    if (bookId == null || _bookmarkBusy) return;
    final anchorKey = _bookmarkAnchorKey(chapter, page);
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

      final excerpt = _bookmarkExcerpt(chapter, page);
      final locator = CanonicalLocator.fromComponents(
        format: BookFormat.fromFileExtension(widget.book.format),
        chapterId: chapter.id,
        offset: page.startOffset,
        excerpt: excerpt,
        progression: chapter.plainText.isEmpty
            ? 0
            : page.startOffset / chapter.plainText.length,
      );
      final bookmark = Bookmark(
        bookId: bookId,
        pageNumber: _chapterIndex,
        canonicalLocator: LocatorCodec.encodeCanonicalLocator(locator),
        anchorKey: anchorKey,
        chapterIndex: _chapterIndex,
        chapterTitle: chapter.title,
        excerpt: excerpt,
      );
      final id = await _bookmarkDao.insertBookmark(bookmark);
      if (!mounted) return;
      setState(() {
        _bookmarks = [..._bookmarks, bookmark.copyWith(id: id)]
          ..sort(
            (a, b) => (a.chapterIndex ?? a.pageNumber).compareTo(
              b.chapterIndex ?? b.pageNumber,
            ),
          );
      });
      showSideToast(
        context,
        context.l10n.bookmarkAdded,
        duration: const Duration(milliseconds: 1600),
        icon: Icons.bookmark_added_rounded,
        kind: SideToastKind.success,
      );
    } catch (error) {
      debugPrint('toggle bookmark failed: $error');
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

  Future<void> _jumpToBookmark(
    Bookmark bookmark,
    List<_NativeChapter> chapters,
  ) async {
    final locatorRaw = bookmark.canonicalLocator;
    final locator = locatorRaw == null
        ? null
        : LocatorCodec.decodeCanonicalLocator(locatorRaw);
    final chapterId = locator?.chapterId ?? locator?.textAnchor?.chapterId;
    var chapterIndex = chapterId == null
        ? -1
        : chapters.indexWhere((chapter) => chapter.id == chapterId);
    if (chapterIndex < 0) {
      chapterIndex = (bookmark.chapterIndex ?? bookmark.pageNumber).clamp(
        0,
        chapters.length - 1,
      );
    }
    _anchorOffset = locator?.textAnchor?.startOffsetUtf16;
    _restoreAnchorAfterLayout = true;
    await _setChapter(
      chapterIndex,
      chapters.length,
      recenterContinuousScroll: false,
    );
    if (_pageMode != NativePageMode.verticalScroll) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _verticalViewportSize.isEmpty) return;
    final parts = _continuousPartsFor(
      chapters[chapterIndex],
      _verticalViewportSize,
    );
    final anchor = _anchorOffset ?? 0;
    final targetPage = parts.indexWhere(
      (part) =>
          anchor >= part.content.startOffset && anchor < part.content.endOffset,
    );
    final safePage = (targetPage < 0 ? parts.length - 1 : targetPage).clamp(
      0,
      parts.length - 1,
    );
    setState(() {
      _pageIndex = safePage;
      _visibleContinuousParts = parts;
      _visiblePages = parts.map((part) => part.content).toList(growable: false);
      _restoreAnchorAfterLayout = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (_scrollByChapter && _verticalPageScrollController.isAttached) {
      _verticalPageScrollController.jumpTo(index: safePage);
    } else if (_verticalChapterScrollController.isAttached) {
      _verticalChapterScrollController.jumpTo(index: chapterIndex);
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _scrollContinuousAnchorIntoView(
      chapters[chapterIndex],
      parts,
      safePage,
      anchor,
    );
  }

  Future<void> _jumpToAnnotation(
    BookNote annotation,
    List<_NativeChapter> chapters,
  ) {
    final chapterId = readerAnnotationChapterId(annotation);
    var chapterIndex = chapterId == null
        ? -1
        : chapters.indexWhere((chapter) => chapter.id == chapterId);
    if (chapterIndex < 0 && annotation.chapter.trim().isNotEmpty) {
      chapterIndex = chapters.indexWhere(
        (chapter) => chapter.title.trim() == annotation.chapter.trim(),
      );
    }
    return _jumpToBookmark(
      Bookmark(
        bookId: annotation.bookId,
        pageNumber: annotation.pageNumber ?? 0,
        canonicalLocator: annotation.canonicalLocator,
        chapterIndex: chapterIndex < 0 ? null : chapterIndex,
        chapterTitle: annotation.chapter,
        excerpt: annotation.content,
      ),
      chapters,
    );
  }

  Future<void> _showTableOfContents(
    List<_NativeChapter> chapters, {
    String? currentAnchorKey,
  }) async {
    // Prepared once while the book is loading. Opening the sheet must not
    // allocate one navigation model per chapter on the interaction frame.
    final navigationChapters = _navigationChapters;
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
            annotations: _annotations,
            currentAnchorKey: currentAnchorKey,
            onChapterSelected: (index) {
              Navigator.of(sheetContext).pop();
              unawaited(
                _setChapter(
                  index,
                  chapters.length,
                  recenterContinuousScroll: true,
                ),
              );
            },
            onBookmarkSelected: (bookmark) {
              Navigator.of(sheetContext).pop();
              unawaited(_jumpToBookmark(bookmark, chapters));
            },
            onBookmarkDeleted: (bookmark) async {
              await _deleteBookmark(bookmark);
              if (mounted) setSheetState(() {});
            },
            onAnnotationSelected: (annotation) {
              Navigator.of(sheetContext).pop();
              unawaited(_jumpToAnnotation(annotation, chapters));
            },
            onAnnotationDeleted: (annotation) async {
              await _deleteAnnotation(annotation);
              if (mounted) setSheetState(() {});
            },
          ),
        ),
      ),
    );
  }

  List<_ReaderPageData> _pagesFor(
    _NativeChapter chapter,
    int chapterIndex,
    Size size,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    final key = _paginationFingerprintFor(
      chapterIndex,
      size,
      direction,
      textScaler,
    );
    final maxCachedLayouts = widget.book.format.toLowerCase() == 'epub'
        ? 12
        : 96;
    if (!_pageCache.containsKey(key) && _pageCache.length >= maxCachedLayouts) {
      _pageCache.remove(_pageCache.keys.first);
    }
    if (!_pageCache.containsKey(key)) {
      widget.onPaginationCacheMiss?.call(chapterIndex);
    }
    return _pageCache.putIfAbsent(key, () {
      final verticalChrome = _pageMode == NativePageMode.verticalScroll
          ? _verticalChrome
          : null;
      return developer.Timeline.timeSync(
        'paginateChapter',
        arguments: {'chapter': chapterIndex, 'chars': chapter.plainText.length},
        () => _paginateChapter(
          chapter,
          maxWidth: readerTextContentWidth(size.width, _horizontalMargin),
          maxHeight:
              verticalChrome?.contentHeight(size.height) ??
              readerTextContentHeight(
                size.height,
                _effectiveTopMargin,
                _effectiveBottomMargin,
              ),
          flowStyle: _readerTextFlowStyle(
            direction: direction,
            textScaler: textScaler,
          ),
          style: _readerTextStyle,
          firstLineIndent: _firstLineIndent,
          paragraphSpacing: _paragraphSpacing,
          normalizeParagraphBreaks: widget.book.format.toLowerCase() == 'epub',
          showDedicatedChapterTitlePage:
              widget.book.format.toLowerCase() != 'txt' ||
              _txtChapterTitlePageEnabled,
        ),
      );
    });
  }

  void _scheduleBookPaginationWarm(
    List<_NativeChapter> chapters,
    int chapterIndex,
    Size size,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    bool supportsBookPaginationWarm() =>
        _pageMode == NativePageMode.horizontalSlide ||
        _pageMode == NativePageMode.coverSlide ||
        _pageMode == NativePageMode.pageCurl;
    if (!supportsBookPaginationWarm() ||
        chapterIndex < 0 ||
        chapterIndex >= chapters.length ||
        size.isEmpty) {
      return;
    }
    final key = _paginationFingerprintFor(
      chapterIndex,
      size,
      direction,
      textScaler,
    );
    if (_pageCache.containsKey(key) ||
        !_queuedHorizontalPaginationWarms.add(key)) {
      return;
    }
    late void Function(Duration) warmAfterFrame;
    void scheduleAfterFrame({bool requestFrame = false}) {
      WidgetsBinding.instance.addPostFrameCallback(warmAfterFrame);
      // Futures completed by the EPUB isolate do not schedule a Flutter frame.
      // Without this request the warmed chapter can remain invisible until an
      // unrelated rebuild, such as opening the table of contents.
      if (requestFrame) WidgetsBinding.instance.ensureVisualUpdate();
    }

    warmAfterFrame = (Duration _) {
      if (!mounted ||
          !supportsBookPaginationWarm() ||
          key !=
              _paginationFingerprintFor(
                chapterIndex,
                size,
                direction,
                textScaler,
              )) {
        _queuedHorizontalPaginationWarms.remove(key);
        return;
      }
      // 整章排版是主线程重活；打开动画（含正文渐显）没播完前先让帧，
      // 每帧末尾重试。动画结束时必有 setState 触发新帧，队列不会滞留。
      if (!_openingFlightSettledNow) {
        scheduleAfterFrame();
        return;
      }
      final pageController = _pageController;
      if (pageController != null &&
          pageController.hasClients &&
          pageController.position.isScrollingNotifier.value) {
        final scrolling = pageController.position.isScrollingNotifier;
        late VoidCallback resumeWhenIdle;
        resumeWhenIdle = () {
          if (scrolling.value) return;
          scrolling.removeListener(resumeWhenIdle);
          if (mounted) {
            scheduleAfterFrame(requestFrame: true);
          } else {
            _queuedHorizontalPaginationWarms.remove(key);
          }
        };
        scrolling.addListener(resumeWhenIdle);
        return;
      }
      final chapter = chapters[chapterIndex];
      if (!chapter.hasLoadedText) {
        _loadIndexedChapterWindow(chapters, chapterIndex).then((_) {
          if (mounted) {
            scheduleAfterFrame(requestFrame: true);
          } else {
            _queuedHorizontalPaginationWarms.remove(key);
          }
        }, onError: (_, _) => _queuedHorizontalPaginationWarms.remove(key));
        return;
      }
      _queuedHorizontalPaginationWarms.remove(key);
      _pagesFor(chapter, chapterIndex, size, direction, textScaler);
      if (mounted &&
          chapterIndex >= _horizontalFirstChapter &&
          chapterIndex <= _horizontalLastChapter) {
        setState(() {});
      }
    };

    scheduleAfterFrame();
  }

  String _paginationFingerprintFor(
    int chapterIndex,
    Size size,
    TextDirection direction,
    TextScaler textScaler,
  ) => ReaderLayoutFingerprint(
    contentKey: '$chapterIndex',
    viewport: size,
    fontSize: _fontSize,
    lineHeight: _lineHeight,
    letterSpacing: _letterSpacing,
    textAlign: _readerTextAlign,
    horizontalMargin: _horizontalMargin,
    verticalMargin: _topMargin + _bottomMargin,
    textScaler: textScaler,
    locale: Localizations.maybeLocaleOf(context),
    pageMode: _pageMode,
    firstLineIndent: _firstLineIndent,
    paragraphSpacing: _paragraphSpacing,
    textDirection: direction,
    extra:
        '${_pageMode == NativePageMode.verticalScroll ? _verticalChrome.paginationSignature : _readerSafeArea.paginationSignature}:'
        '${_readerFont.id}:'
        '${widget.book.format.toLowerCase() == 'txt' ? _txtChapterTitlePageEnabled : true}',
  ).cacheKey('native-line-v7');

  Widget _buildPage(
    _NativeChapter chapter,
    _ReaderPageData page, {
    required int chapterIndex,
    required int pageIndex,
  }) {
    final imageIndex = page.imageBlockIndex;
    if (imageIndex == null) {
      final body = _buildStyledReaderText(
        chapter,
        page,
        chapterIndex: chapterIndex,
        pageIndex: pageIndex,
      );
      if (!page.showsInlineChapterTitle) return body;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReaderInlineChapterTitle(
            title: chapter.title,
            bodyStyle: _readerTextStyle,
          ),
          const SizedBox(height: ReaderInlineChapterTitle.spacingAfter),
          Expanded(child: body),
        ],
      );
    }
    final imageBlock = chapter.blocks[imageIndex];
    final imageProvider = imageBlock.imageProvider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageProvider != null)
          Expanded(
            flex: _imagePageImageFlex,
            child: Image(
              image: imageProvider,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          ),
        if (imageProvider != null && page.text.isNotEmpty)
          const SizedBox(height: _imagePageGap),
        if (page.text.isNotEmpty)
          Expanded(
            flex: _imagePageTextFlex,
            child: _buildStyledReaderText(
              chapter,
              page,
              chapterIndex: chapterIndex,
              pageIndex: pageIndex,
            ),
          ),
      ],
    );
  }

  List<_BookPageRef> _bookPagesFor(
    List<_NativeChapter> chapters,
    int firstChapter,
    int lastChapter,
    Size size,
    TextDirection direction,
    TextScaler textScaler, {
    required bool padOddChapters,
  }) {
    final result = <_BookPageRef>[];
    final safeFirst = firstChapter.clamp(0, chapters.length - 1);
    final safeLast = lastChapter.clamp(safeFirst, chapters.length - 1);
    for (
      var chapterIndex = safeFirst;
      chapterIndex <= safeLast;
      chapterIndex++
    ) {
      final chapter = chapters[chapterIndex];
      final layoutFingerprint = _paginationFingerprintFor(
        chapterIndex,
        size,
        direction,
        textScaler,
      );
      final distanceFromCurrent = (chapterIndex - _chapterIndex).abs();
      // 打开动画播完前，相邻章节若未命中分页缓存，也转入预热队列，
      // 避免整章排版挤在飞行帧里同步执行。
      if (chapterIndex != _chapterIndex &&
          (!chapter.hasLoadedText ||
              (!_openingFlightSettledNow &&
                  !_pageCache.containsKey(layoutFingerprint)) ||
              (distanceFromCurrent > 1 &&
                  !_pageCache.containsKey(layoutFingerprint)))) {
        _scheduleBookPaginationWarm(
          chapters,
          chapterIndex,
          size,
          direction,
          textScaler,
        );
        continue;
      }
      final chapterPages = _pagesFor(
        chapter,
        chapterIndex,
        size,
        direction,
        textScaler,
      );
      for (var pageIndex = 0; pageIndex < chapterPages.length; pageIndex++) {
        result.add(
          _BookPageRef(
            chapterIndex: chapterIndex,
            pageIndex: pageIndex,
            pageCount: chapterPages.length,
            layoutFingerprint: layoutFingerprint,
            content: chapterPages[pageIndex],
          ),
        );
      }
      if (padOddChapters && chapterPages.length.isOdd) {
        result.add(
          _BookPageRef(
            chapterIndex: chapterIndex,
            pageIndex: chapterPages.length,
            pageCount: chapterPages.length,
            layoutFingerprint: layoutFingerprint,
            content: chapterPages.last,
            isBlank: true,
          ),
        );
      }
    }
    return result;
  }

  void _onBookPageChanged(
    int index,
    List<_BookPageRef> bookPages,
    List<_NativeChapter> chapters,
  ) {
    final page = bookPages[index];
    if (page.isBlank) return;
    final movedForward =
        page.chapterIndex > _chapterIndex ||
        (page.chapterIndex == _chapterIndex && page.pageIndex > _pageIndex);
    final chapterChanged = page.chapterIndex != _chapterIndex;
    if (movedForward) _sessionPagesRead++;
    setState(() {
      _chapterIndex = page.chapterIndex;
      _pageIndex = page.pageIndex;
      if (page.chapterIndex <= _horizontalFirstChapter &&
          _horizontalFirstChapter > 0) {
        _horizontalBackwardExpansionPending = true;
      }
      if (page.chapterIndex > _horizontalFirstChapter + 1) {
        if (_pageMode == NativePageMode.horizontalSlide) {
          _horizontalForwardContractionPending = true;
        } else {
          _horizontalFirstChapter = page.chapterIndex - 1;
        }
      }
    });
    if (chapterChanged && widget.book.id != null) {
      BookDao().updateBookProgress(widget.book.id!, page.chapterIndex);
    }
    if (page.chapterIndex >= _horizontalLastChapter - 1 &&
        _horizontalLastChapter < chapters.length - 1) {
      setState(() => _horizontalLastChapter++);
    }
    _saveCanonicalProgress(
      chapters[page.chapterIndex],
      page.content,
      page.chapterIndex,
    );
  }

  void _commitHorizontalForwardContraction(
    List<_BookPageRef> bookPages, {
    required bool usesTwoPageLayout,
  }) {
    if (!_horizontalForwardContractionPending ||
        _pageMode != NativePageMode.horizontalSlide) {
      return;
    }
    final nextFirstChapter = math.max(0, _chapterIndex - 1);
    if (nextFirstChapter <= _horizontalFirstChapter) {
      _horizontalForwardContractionPending = false;
      return;
    }
    final targetPage = bookPages.indexWhere(
      (page) =>
          !page.isBlank &&
          page.chapterIndex == _chapterIndex &&
          page.pageIndex == _pageIndex,
    );
    if (targetPage < 0) return;
    final removedBookPages = bookPages
        .takeWhile((page) => page.chapterIndex < nextFirstChapter)
        .length;
    final localTargetPage = targetPage - removedBookPages;
    final nextControllerPage = usesTwoPageLayout
        ? localTargetPage ~/ 2
        : localTargetPage;
    final previousPageController = _pageController;
    _pageController = PageController(
      initialPage: math.max(0, nextControllerPage),
    );
    _pageControllerGeneration++;
    _horizontalForwardContractionPending = false;
    setState(() => _horizontalFirstChapter = nextFirstChapter);
    if (previousPageController != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => previousPageController.dispose(),
      );
    }
  }

  void _commitHorizontalBackwardExpansion(
    List<_NativeChapter> chapters,
    Size size,
    TextDirection direction,
    TextScaler textScaler, {
    required bool usesTwoPageLayout,
  }) {
    if (!_horizontalBackwardExpansionPending ||
        _horizontalFirstChapter <= 0 ||
        size.isEmpty) {
      return;
    }
    final nextFirstChapter = _horizontalFirstChapter - 1;
    final chapter = chapters[nextFirstChapter];
    final layoutFingerprint = _paginationFingerprintFor(
      nextFirstChapter,
      size,
      direction,
      textScaler,
    );
    if (!chapter.hasLoadedText || !_pageCache.containsKey(layoutFingerprint)) {
      if (!_horizontalBackwardExpansionWarmPending) {
        _horizontalBackwardExpansionWarmPending = true;
        unawaited(
          _prepareHorizontalBackwardExpansion(
            chapters,
            nextFirstChapter,
            size,
            direction,
            textScaler,
            usesTwoPageLayout: usesTwoPageLayout,
          ),
        );
      }
      return;
    }
    _horizontalBackwardExpansionPending = false;
    _horizontalBackwardExpansionWarmPending = false;
    if (_pageMode != NativePageMode.horizontalSlide) {
      // Cover mode locates the current page by identity on every build, so
      // the window can grow without preserving a scroll position.
      setState(() => _horizontalFirstChapter = nextFirstChapter);
      return;
    }
    final addedPages = _pagesFor(
      chapter,
      nextFirstChapter,
      size,
      direction,
      textScaler,
    ).length;
    final addedBookPages = usesTwoPageLayout && addedPages.isOdd
        ? addedPages + 1
        : addedPages;
    final addedControllerPages = usesTwoPageLayout
        ? addedBookPages ~/ 2
        : addedBookPages;
    final previousPageController = _pageController;
    final currentControllerPage = previousPageController?.hasClients == true
        ? previousPageController!.page?.round() ?? 0
        : 0;
    _pageController = PageController(
      initialPage: currentControllerPage + addedControllerPages,
    );
    _pageControllerGeneration++;
    setState(() => _horizontalFirstChapter = nextFirstChapter);
    if (previousPageController != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => previousPageController.dispose(),
      );
    }
  }

  Future<void> _prepareHorizontalBackwardExpansion(
    List<_NativeChapter> chapters,
    int chapterIndex,
    Size size,
    TextDirection direction,
    TextScaler textScaler, {
    required bool usesTwoPageLayout,
  }) async {
    try {
      await _loadIndexedChapterWindow(chapters, chapterIndex);
      while (mounted &&
          _pageController?.hasClients == true &&
          _pageController!.position.isScrollingNotifier.value) {
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted || !_horizontalBackwardExpansionPending) return;
      _pagesFor(
        chapters[chapterIndex],
        chapterIndex,
        size,
        direction,
        textScaler,
      );
    } catch (error) {
      debugPrint('prepare previous native chapter failed: $error');
      return;
    } finally {
      _horizontalBackwardExpansionWarmPending = false;
    }
    if (!mounted || !_horizontalBackwardExpansionPending) return;
    _commitHorizontalBackwardExpansion(
      chapters,
      size,
      direction,
      textScaler,
      usesTwoPageLayout: usesTwoPageLayout,
    );
  }

  Future<void> _precacheBookPageImages(
    BuildContext context,
    List<_NativeChapter> chapters,
    Iterable<_BookPageRef> pages,
  ) async {
    final images = <ImageProvider>{};
    for (final page in pages) {
      if (page.isBlank) continue;
      final imageIndex = page.content.imageBlockIndex;
      if (imageIndex == null) continue;
      final image =
          chapters[page.chapterIndex].blocks[imageIndex].imageProvider;
      if (image != null) images.add(image);
    }
    await Future.wait(images.map((image) => precacheImage(image, context)));
  }

  ReaderViewportChromeMetrics get _verticalChrome =>
      ReaderViewportChromeMetrics(
        safeArea: _readerSafeArea,
        immersive: _topBarStyle == ReaderTopBarStyle.hidden,
        reservesTitle: _topBarStyle == ReaderTopBarStyle.reader,
      );

  double _verticalPageExtentFor(Size viewport) =>
      _verticalChrome.contentHeight(viewport.height);

  Widget _buildVerticalReadingWindow(Widget child) {
    final chrome = _verticalChrome;
    return Padding(
      key: const ValueKey('native-vertical-reading-window'),
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

  GlobalKey _continuousPartKey(String chapterId, int partIndex) =>
      _continuousPartKeys.putIfAbsent('$chapterId:$partIndex', GlobalKey.new);

  void _onVerticalPagePositionsChanged() {
    if (!mounted ||
        _pageMode != NativePageMode.verticalScroll ||
        !_scrollByChapter ||
        _visibleContinuousParts.isEmpty) {
      return;
    }
    final primary = pickPrimaryReaderItem(
      _verticalPagePositionsListener.itemPositions.value.map(_readerPosition),
    );
    if (primary == null) return;
    final nextPage = primary.index.clamp(0, _visibleContinuousParts.length - 1);
    _verticalScrollProgress.value = _visibleContinuousParts.length <= 1
        ? 0
        : (nextPage / (_visibleContinuousParts.length - 1)).clamp(0.0, 1.0);
    if (nextPage != _pageIndex) {
      if (nextPage > _pageIndex) _sessionPagesRead++;
      setState(() => _pageIndex = nextPage);
    }
    final chapter = _visibleChapters[_chapterIndex];
    final part = _visibleContinuousParts[nextPage];
    final offset = _continuousOffsetAtViewportCenter(chapter, part, nextPage);
    _verticalCanonicalOffset = offset;
    _saveCanonicalProgress(
      chapter,
      _ReaderPageData(text: '', startOffset: offset, endOffset: offset),
      _chapterIndex,
    );
  }

  void _onVerticalChapterPositionsChanged() {
    if (!mounted ||
        !_initialPositionRestored ||
        _pageMode != NativePageMode.verticalScroll ||
        _scrollByChapter ||
        _visibleChapters.isEmpty ||
        _verticalViewportSize.isEmpty) {
      return;
    }
    final primary = pickPrimaryReaderItem(
      _verticalChapterPositionsListener.itemPositions.value.map(
        _readerPosition,
      ),
    );
    if (primary == null) return;
    final nextChapter = primary.index.clamp(0, _visibleChapters.length - 1);
    final parts = _continuousPartsFor(
      _visibleChapters[nextChapter],
      _verticalViewportSize,
    );
    var nextPage = readerPageIndexWithinItem(primary, parts.length);
    var closestDistance = double.infinity;
    final viewportCenter = MediaQuery.sizeOf(context).height / 2;
    for (var index = 0; index < parts.length; index++) {
      final renderObject = _continuousPartKey(
        _visibleChapters[nextChapter].id,
        index,
      ).currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      if (top <= viewportCenter && bottom > viewportCenter) {
        nextPage = index;
        break;
      }
      final distance = math.min(
        (top - viewportCenter).abs(),
        (bottom - viewportCenter).abs(),
      );
      if (distance < closestDistance) {
        closestDistance = distance;
        nextPage = index;
      }
    }
    final movedForward =
        nextChapter > _chapterIndex ||
        (nextChapter == _chapterIndex && nextPage > _pageIndex);
    final chapterChanged = nextChapter != _chapterIndex;
    _verticalScrollProgress.value = parts.length <= 1
        ? 0
        : (nextPage / (parts.length - 1)).clamp(0.0, 1.0);
    if (chapterChanged || nextPage != _pageIndex) {
      if (movedForward) _sessionPagesRead++;
      setState(() {
        _chapterIndex = nextChapter;
        _pageIndex = nextPage;
        _visibleContinuousParts = parts;
        _visiblePages = parts
            .map((part) => part.content)
            .toList(growable: false);
      });
    }
    if (chapterChanged && widget.book.id != null) {
      BookDao().updateBookProgress(widget.book.id!, nextChapter);
    }
    final offset = _continuousOffsetAtViewportCenter(
      _visibleChapters[nextChapter],
      parts[nextPage],
      nextPage,
    );
    _verticalCanonicalOffset = offset;
    _saveCanonicalProgress(
      _visibleChapters[nextChapter],
      _ReaderPageData(text: '', startOffset: offset, endOffset: offset),
      nextChapter,
    );
  }

  RenderParagraph? _continuousParagraph(String chapterId, int partIndex) {
    final root = _continuousPartKey(chapterId, partIndex).currentContext;
    if (root == null) return null;
    RenderParagraph? result;
    void visit(Element element) {
      if (result != null) return;
      final renderObject = element.renderObject;
      if (renderObject is RenderParagraph) {
        result = renderObject;
        return;
      }
      element.visitChildElements(visit);
    }

    root.visitChildElements(visit);
    return result;
  }

  int _continuousOffsetAtViewportCenter(
    _NativeChapter chapter,
    _ContinuousReaderPart part,
    int partIndex,
  ) {
    final paragraph = _continuousParagraph(chapter.id, partIndex);
    if (paragraph == null || !paragraph.hasSize || part.content.text.isEmpty) {
      return part.content.startOffset;
    }
    final center = Offset(
      paragraph.size.width / 2,
      MediaQuery.sizeOf(context).height / 2 -
          paragraph.localToGlobal(Offset.zero).dy,
    );
    final textPosition = paragraph.getPositionForOffset(center);
    return part.content.sourceOffsetForTextOffset(textPosition.offset);
  }

  double? _continuousCaretOffset(
    _NativeChapter chapter,
    _ContinuousReaderPart part,
    int partIndex,
    int sourceOffset,
  ) {
    final paragraph = _continuousParagraph(chapter.id, partIndex);
    if (paragraph == null || !paragraph.hasSize || part.content.text.isEmpty) {
      return null;
    }
    final textOffset = part.content.textOffsetForSourceOffset(sourceOffset);
    return paragraph
        .getOffsetForCaret(TextPosition(offset: textOffset), Rect.zero)
        .dy;
  }

  Future<void> _scrollContinuousAnchorIntoView(
    _NativeChapter chapter,
    List<_ContinuousReaderPart> parts,
    int partIndex,
    int sourceOffset,
  ) async {
    final targetContext = _continuousPartKey(
      chapter.id,
      partIndex,
    ).currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0,
        duration: Duration.zero,
      );
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final caretOffset = _continuousCaretOffset(
      chapter,
      parts[partIndex],
      partIndex,
      sourceOffset,
    );
    if (caretOffset == null || caretOffset <= 0) return;
    if (_scrollByChapter) {
      final scrollable = Scrollable.maybeOf(
        _continuousPartKey(chapter.id, partIndex).currentContext!,
      );
      if (scrollable != null) {
        scrollable.position.jumpTo(
          (scrollable.position.pixels + caretOffset).clamp(
            scrollable.position.minScrollExtent,
            scrollable.position.maxScrollExtent,
          ),
        );
      }
      return;
    }
    await _verticalChapterOffsetController.animateScroll(
      offset: caretOffset,
      duration: const Duration(milliseconds: 1),
    );
  }

  List<_ContinuousReaderPart> _continuousPartsFor(
    _NativeChapter chapter,
    Size viewport,
  ) {
    final cacheKey =
        '${chapter.id}:$_layoutSignature:'
        '${viewport.width.toStringAsFixed(1)}:'
        '${Directionality.of(context).name}';
    final cached = _continuousPartCache[cacheKey];
    if (cached != null) return cached;
    if (_continuousPartCache.length >= 24) {
      _continuousPartCache.remove(_continuousPartCache.keys.first);
    }
    final maxWidth = readerTextContentWidth(viewport.width, _horizontalMargin);
    final flowStyle = _readerTextFlowStyle(
      direction: _verticalTextDirection,
      textScaler: _verticalTextScaler,
    );
    final imageOffsets = <(int, int)>[];
    var searchFrom = 0;
    for (var index = 0; index < chapter.blocks.length; index++) {
      final block = chapter.blocks[index];
      if (block.hasImage) {
        imageOffsets.add((
          block.startOffset >= 0
              ? block.startOffset.clamp(searchFrom, chapter.plainText.length)
              : searchFrom,
          index,
        ));
        continue;
      }
      final text = block.text;
      if (text == null || text.isEmpty) continue;
      if (block.startOffset >= searchFrom &&
          block.endOffset >= block.startOffset) {
        searchFrom = block.endOffset.clamp(
          searchFrom,
          chapter.plainText.length,
        );
      } else {
        final found = chapter.plainText.indexOf(text, searchFrom);
        if (found >= 0) searchFrom = found + text.length;
      }
    }

    final hasSplitChapterTitle =
        chapter.isNeedSplitTitle && chapter.title.trim().isNotEmpty;
    final showsDedicatedChapterTitle =
        hasSplitChapterTitle &&
        widget.book.format.toLowerCase() == 'txt' &&
        _txtChapterTitlePageEnabled;
    final parts = <_ContinuousReaderPart>[
      if (showsDedicatedChapterTitle)
        const _ContinuousReaderPart(_ReaderPageData.chapterTitle()),
    ];
    void addText(int start, int end) {
      if (start >= end) return;
      var chunkStart = start;
      while (chunkStart < end) {
        var chunkEnd = math.min(chunkStart + 1024, end);
        if (chunkEnd < end) {
          final searchLimit = math.min(chunkStart + 1536, end);
          final nextBreak = chapter.plainText.indexOf('\n', chunkEnd);
          if (nextBreak >= chunkEnd && nextBreak < searchLimit) {
            chunkEnd = nextBreak + 1;
          } else {
            final previousBreak = chapter.plainText.lastIndexOf('\n', chunkEnd);
            if (previousBreak > chunkStart + 512) {
              chunkEnd = previousBreak + 1;
            }
          }
        }
        if (chunkEnd < end &&
            chunkEnd > chunkStart &&
            chapter.plainText.codeUnitAt(chunkEnd) >= 0xDC00 &&
            chapter.plainText.codeUnitAt(chunkEnd) <= 0xDFFF) {
          chunkEnd--;
        }
        final page = paginateReaderText(
          text: chapter.plainText.substring(chunkStart, chunkEnd),
          maxWidth: maxWidth,
          maxHeight: 0,
          flowStyle: flowStyle,
          style: _readerTextStyle,
          sourceOffset: chunkStart,
          firstLineIndent: _firstLineIndent,
          paragraphSpacing: _paragraphSpacing,
          normalizeParagraphBreaks: widget.book.format.toLowerCase() == 'epub',
          indentFirstParagraph:
              chunkStart == 0 ||
              isReaderLineBreakCodeUnit(
                chapter.plainText.codeUnitAt(chunkStart - 1),
              ),
          sourceSpanBuilder: (sourceStart, sourceEnd) => _styledSpanForRange(
            chapter,
            sourceStart,
            sourceEnd,
            _readerTextStyle,
          ),
        ).single;
        parts.add(_ContinuousReaderPart(_ReaderPageData.fromTextPage(page)));
        chunkStart = chunkEnd;
      }
    }

    var cursor = 0;
    for (var index = 0; index < imageOffsets.length; index++) {
      final offset = imageOffsets[index].$1.clamp(
        cursor,
        chapter.plainText.length,
      );
      addText(cursor, offset);
      parts.add(
        _ContinuousReaderPart(
          _ReaderPageData(text: '', startOffset: offset, endOffset: offset),
          imageBlockIndex: imageOffsets[index].$2,
        ),
      );
      cursor = offset;
    }
    addText(cursor, chapter.plainText.length);
    if (parts.isEmpty) {
      parts.add(
        _ContinuousReaderPart(
          _ReaderPageData(
            text: '',
            startOffset: 0,
            endOffset: chapter.plainText.length,
          ),
        ),
      );
    }
    _continuousPartCache[cacheKey] = parts;
    return parts;
  }

  Widget _buildContinuousPart(
    _NativeChapter chapter,
    _ContinuousReaderPart part, {
    required int chapterIndex,
    required int partIndex,
  }) {
    if (part.content.isChapterTitle) {
      return SizedBox(
        key: _continuousPartKey(chapter.id, partIndex),
        height: _verticalPageExtentFor(_verticalViewportSize),
        child: ReaderChapterTitlePage(
          title: chapter.title,
          bodyStyle: _readerTextStyle,
        ),
      );
    }
    final imageProvider = part.imageBlockIndex == null
        ? null
        : chapter.blocks[part.imageBlockIndex!].imageProvider;
    return Padding(
      key: _continuousPartKey(chapter.id, partIndex),
      padding: EdgeInsets.symmetric(horizontal: _horizontalMargin),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: readerMaxTextContentWidth,
          ),
          child: Column(
            key: ValueKey(
              'native-vertical-part:${chapter.id}:'
              '${part.content.startOffset}:$partIndex',
            ),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (partIndex == 0 &&
                  chapter.isNeedSplitTitle &&
                  chapter.title.trim().isNotEmpty &&
                  (widget.book.format.toLowerCase() != 'txt' ||
                      !_txtChapterTitlePageEnabled)) ...[
                ReaderInlineChapterTitle(
                  title: chapter.title,
                  bodyStyle: _readerTextStyle,
                ),
                const SizedBox(height: ReaderInlineChapterTitle.spacingAfter),
              ],
              if (imageProvider != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: Image(image: imageProvider, fit: BoxFit.contain),
                  ),
                ),
              if (part.content.text.isNotEmpty)
                _buildStyledReaderText(
                  chapter,
                  part.content,
                  chapterIndex: chapterIndex,
                  pageIndex: partIndex,
                  fillAvailableSpace: false,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalChapterItem(
    List<_NativeChapter> chapters,
    int chapterIndex,
    Size viewport,
  ) {
    final chapter = chapters[chapterIndex];
    if (!chapter.hasLoadedText) {
      return FutureBuilder<void>(
        future: _loadIndexedChapterWindow(chapters, chapterIndex),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError) {
            return _buildVerticalChapterItem(chapters, chapterIndex, viewport);
          }
          return SizedBox(
            height: _verticalPageExtentFor(viewport),
            child: Center(
              child: snapshot.hasError
                  ? const Icon(Icons.error_outline_rounded)
                  : CircularProgressIndicator(color: _readerTheme.accent),
            ),
          );
        },
      );
    }
    final parts = _continuousPartsFor(chapter, viewport);
    return Column(
      children: [
        for (var partIndex = 0; partIndex < parts.length; partIndex++)
          _buildContinuousPart(
            chapter,
            parts[partIndex],
            chapterIndex: chapterIndex,
            partIndex: partIndex,
          ),
      ],
    );
  }

  Widget _buildVerticalPageList(
    _NativeChapter chapter,
    List<_ReaderPageData> pages,
    Size viewport,
  ) {
    final parts = _continuousPartsFor(chapter, viewport);
    _visibleContinuousParts = parts;
    _visiblePages = parts.map((part) => part.content).toList(growable: false);
    return ReaderVerticalPagingSurface(
      surfaceKey: const ValueKey('native-reader-surface'),
      child: ScrollablePositionedList.builder(
        key: ValueKey('native-vertical-pages:$_chapterIndex:$_layoutSignature'),
        itemScrollController: _verticalPageScrollController,
        itemPositionsListener: _verticalPagePositionsListener,
        initialScrollIndex: _pageIndex.clamp(0, parts.length - 1),
        minCacheExtent: _verticalPageExtentFor(viewport),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: parts.length,
        itemBuilder: (context, index) => _buildContinuousPart(
          chapter,
          parts[index],
          chapterIndex: _chapterIndex,
          partIndex: index,
        ),
      ),
    );
  }

  Widget _buildVerticalBook(List<_NativeChapter> chapters, Size viewport) {
    return ReaderVerticalPagingSurface(
      surfaceKey: const ValueKey('native-reader-surface'),
      child: ScrollablePositionedList.builder(
        key: ValueKey('native-vertical-book:$_layoutSignature'),
        itemScrollController: _verticalChapterScrollController,
        scrollOffsetController: _verticalChapterOffsetController,
        itemPositionsListener: _verticalChapterPositionsListener,
        initialScrollIndex: _chapterIndex.clamp(0, chapters.length - 1),
        minCacheExtent: _verticalPageExtentFor(viewport),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: chapters.length,
        itemBuilder: (context, index) =>
            _buildVerticalChapterItem(chapters, index, viewport),
      ),
    );
  }

  Widget _buildReaderContent(
    List<_NativeChapter> chapters,
    _NativeChapter chapter,
    List<_ReaderPageData> pages,
    List<_BookPageRef> bookPages,
    bool usesTwoPageLayout,
    String layoutFingerprint,
    Size viewport,
  ) {
    if (_pageMode == NativePageMode.verticalScroll) {
      _visibleChapters = chapters;
      _verticalViewportSize = viewport;
      _verticalTextDirection = Directionality.of(context);
      _verticalTextScaler = readerBodyTextScaler;
      if (!_scrollByChapter) {
        return _buildVerticalReadingWindow(
          _buildVerticalBook(chapters, viewport),
        );
      }
      return _buildVerticalReadingWindow(
        _buildVerticalPageList(chapter, pages, viewport),
      );
    }
    if (_pageMode == NativePageMode.horizontalSlide) {
      return NotificationListener<ScrollEndNotification>(
        onNotification: (_) {
          _commitHorizontalBackwardExpansion(
            chapters,
            _paginationSize(viewport, usesTwoPageLayout),
            Directionality.of(context),
            readerBodyTextScaler,
            usesTwoPageLayout: usesTwoPageLayout,
          );
          _commitHorizontalForwardContraction(
            bookPages,
            usesTwoPageLayout: usesTwoPageLayout,
          );
          return false;
        },
        child: PageView.builder(
          controller: _pageController,
          physics: _annotationInteractionActive
              ? const NeverScrollableScrollPhysics()
              : null,
          itemCount: usesTwoPageLayout
              ? (bookPages.length + 1) ~/ 2
              : bookPages.length,
          onPageChanged: (index) => _onBookPageChanged(
            usesTwoPageLayout ? index * 2 : index,
            bookPages,
            chapters,
          ),
          itemBuilder: (context, index) {
            if (!usesTwoPageLayout) {
              final page = bookPages[index];
              return _buildBookPageLeaf(chapters, page);
            }
            final firstIndex = index * 2;
            return _buildSpread(
              left: _buildBookPageLeaf(
                chapters,
                bookPages[firstIndex],
                pageNumberPlacement: ReaderPageNumberPlacement.bottomLeft,
                topInformationLayout: ReaderTopInformationLayout.spreadLeft,
              ),
              right: firstIndex + 1 < bookPages.length
                  ? _buildBookPageLeaf(
                      chapters,
                      bookPages[firstIndex + 1],
                      pageNumberPlacement:
                          ReaderPageNumberPlacement.bottomRight,
                      topInformationLayout:
                          ReaderTopInformationLayout.spreadRight,
                    )
                  : null,
            );
          },
        ),
      );
    }
    if (_pageMode == NativePageMode.coverSlide) {
      final currentIndex = bookPages.indexWhere(
        (page) =>
            page.chapterIndex == _chapterIndex && page.pageIndex == _pageIndex,
      );
      if (currentIndex < 0) {
        return _buildPageLeaf(
          chapter,
          pages[_pageIndex],
          chapterIndex: _chapterIndex,
          pageIndex: _pageIndex,
          pageCount: pages.length,
          layoutFingerprint: layoutFingerprint,
        );
      }
      final paginationSize = _paginationSize(viewport, usesTwoPageLayout);
      final textDirection = Directionality.of(context);
      void commitTurn(int targetIndex) {
        _onBookPageChanged(targetIndex, bookPages, chapters);
        _commitHorizontalBackwardExpansion(
          chapters,
          paginationSize,
          textDirection,
          readerBodyTextScaler,
          usesTwoPageLayout: usesTwoPageLayout,
        );
      }

      final coverKey = ValueKey(
        'native-cover:${widget.book.id ?? _bookCacheKey}',
      );
      if (usesTwoPageLayout) {
        final spreadStart = _spreadStartForPage(currentIndex);
        final hasForward = spreadStart + 2 < bookPages.length;
        final hasBackward = spreadStart >= 2;
        return ReaderCoverPageTurn(
          key: coverKey,
          controller: _coverPageTurnController,
          currentPage: _buildCoverSpreadSnapshot(
            chapters,
            bookPages,
            spreadStart,
          ),
          forwardPage: hasForward
              ? _buildCoverSpreadSnapshot(chapters, bookPages, spreadStart + 2)
              : null,
          backwardPage: hasBackward
              ? _buildCoverSpreadSnapshot(chapters, bookPages, spreadStart - 2)
              : null,
          onTurnForward: () => commitTurn(spreadStart + 2),
          onTurnBackward: () => commitTurn(spreadStart - 2),
          paperColor: _readerTheme.background,
        );
      }
      final current = bookPages[currentIndex];
      final forward = currentIndex + 1 < bookPages.length
          ? bookPages[currentIndex + 1]
          : null;
      final backward = currentIndex > 0 ? bookPages[currentIndex - 1] : null;
      return ReaderCoverPageTurn(
        key: coverKey,
        controller: _coverPageTurnController,
        currentPage: _buildBookPageSnapshot(chapters, current),
        forwardPage: forward != null
            ? _buildBookPageSnapshot(chapters, forward)
            : null,
        backwardPage: backward != null
            ? _buildBookPageSnapshot(chapters, backward)
            : null,
        onTurnForward: () => commitTurn(currentIndex + 1),
        onTurnBackward: () => commitTurn(currentIndex - 1),
        paperColor: _readerTheme.background,
      );
    }
    if (_pageMode == NativePageMode.pageCurl) {
      final currentIndex = bookPages.indexWhere(
        (page) =>
            page.chapterIndex == _chapterIndex && page.pageIndex == _pageIndex,
      );
      if (currentIndex < 0) {
        return _buildPageLeaf(
          chapter,
          pages[_pageIndex],
          chapterIndex: _chapterIndex,
          pageIndex: _pageIndex,
          pageCount: pages.length,
          layoutFingerprint: layoutFingerprint,
        );
      }
      if (usesTwoPageLayout) {
        return _buildPageCurlSpread(context, chapters, bookPages, currentIndex);
      }
      final current = bookPages[currentIndex];
      final forward = currentIndex + 1 < bookPages.length
          ? bookPages[currentIndex + 1]
          : null;
      final backward = currentIndex > 0 ? bookPages[currentIndex - 1] : null;
      return ReaderShaderPageCurl(
        key: ValueKey('native-curl:${widget.book.id ?? _bookCacheKey}'),
        controller: _pageCurlController,
        currentPage: _buildBookPageSnapshot(chapters, current),
        forwardPage: forward != null
            ? _buildBookPageSnapshot(chapters, forward)
            : null,
        backwardPage: backward != null
            ? _buildBookPageSnapshot(chapters, backward)
            : null,
        preparePages: () => _precacheBookPageImages(context, chapters, [
          current,
          if (forward != null) forward,
          if (backward != null) backward,
        ]),
        onTurnForward: () =>
            _onBookPageChanged(currentIndex + 1, bookPages, chapters),
        onTurnBackward: () =>
            _onBookPageChanged(currentIndex - 1, bookPages, chapters),
        paperColor: _readerTheme.background,
      );
    }
    if (usesTwoPageLayout) {
      final spreadStart = _spreadStartForPage(_pageIndex);
      return _buildSpread(
        left: _buildPageLeaf(
          chapter,
          pages[spreadStart],
          chapterIndex: _chapterIndex,
          pageIndex: spreadStart,
          pageCount: pages.length,
          layoutFingerprint: layoutFingerprint,
          pageNumberPlacement: ReaderPageNumberPlacement.bottomLeft,
          topInformationLayout: ReaderTopInformationLayout.spreadLeft,
        ),
        right: spreadStart + 1 < pages.length
            ? _buildPageLeaf(
                chapter,
                pages[spreadStart + 1],
                chapterIndex: _chapterIndex,
                pageIndex: spreadStart + 1,
                pageCount: pages.length,
                layoutFingerprint: layoutFingerprint,
                pageNumberPlacement: ReaderPageNumberPlacement.bottomRight,
                topInformationLayout: ReaderTopInformationLayout.spreadRight,
              )
            : null,
      );
    }
    return _buildPageLeaf(
      chapter,
      pages[_pageIndex],
      chapterIndex: _chapterIndex,
      pageIndex: _pageIndex,
      pageCount: pages.length,
      layoutFingerprint: layoutFingerprint,
    );
  }

  Widget _buildBookPageLeaf(
    List<_NativeChapter> chapters,
    _BookPageRef page, {
    ReaderPageNumberPlacement pageNumberPlacement =
        ReaderPageNumberPlacement.bottomRight,
    ReaderTopInformationLayout topInformationLayout =
        ReaderTopInformationLayout.full,
  }) {
    if (page.isBlank) {
      return _buildBlankPageLeaf(
        pageIdentity: 'chapter-${page.chapterIndex}-padding',
        layoutFingerprint: page.layoutFingerprint,
        topInformationLayout: topInformationLayout,
      );
    }
    return _buildPageLeaf(
      chapters[page.chapterIndex],
      page.content,
      chapterIndex: page.chapterIndex,
      pageIndex: page.pageIndex,
      pageCount: page.pageCount,
      layoutFingerprint: page.layoutFingerprint,
      pageNumberPlacement: pageNumberPlacement,
      topInformationLayout: topInformationLayout,
    );
  }

  ReaderPageSnapshot _buildCoverSpreadSnapshot(
    List<_NativeChapter> chapters,
    List<_BookPageRef> bookPages,
    int spreadStart,
  ) {
    final left = bookPages[spreadStart];
    final right = spreadStart + 1 < bookPages.length
        ? bookPages[spreadStart + 1]
        : null;
    return ReaderPageSnapshot(
      key: ReaderPageSnapshotKey(
        pageIdentity:
            'native:${widget.book.id ?? _bookCacheKey}:'
            'cover-spread:${left.chapterIndex}:${left.pageIndex}',
        layoutFingerprint: left.layoutFingerprint,
        themeId: _readerTheme.cacheKey,
      ),
      contentRevision: _leafContentRevision,
      child: _buildSpread(
        left: _buildBookPageLeaf(
          chapters,
          left,
          pageNumberPlacement: ReaderPageNumberPlacement.bottomLeft,
          topInformationLayout: ReaderTopInformationLayout.spreadLeft,
        ),
        right: right == null
            ? null
            : _buildBookPageLeaf(
                chapters,
                right,
                pageNumberPlacement: ReaderPageNumberPlacement.bottomRight,
                topInformationLayout: ReaderTopInformationLayout.spreadRight,
              ),
      ),
    );
  }

  ReaderPageSnapshot _buildBookPageSnapshot(
    List<_NativeChapter> chapters,
    _BookPageRef page, {
    ReaderPageNumberPlacement pageNumberPlacement =
        ReaderPageNumberPlacement.bottomRight,
    ReaderTopInformationLayout topInformationLayout =
        ReaderTopInformationLayout.full,
  }) {
    if (page.isBlank) {
      return _buildBlankPageSnapshot(
        pageIdentity: 'chapter-${page.chapterIndex}-padding',
        layoutFingerprint: page.layoutFingerprint,
        topInformationLayout: topInformationLayout,
      );
    }
    final metadata = _nativePageMetadata(
      chapters[page.chapterIndex],
      page.content,
      chapterIndex: page.chapterIndex,
      pageIndex: page.pageIndex,
      pageCount: page.pageCount,
      layoutFingerprint: page.layoutFingerprint,
    );
    return ReaderPageSnapshot(
      key: metadata.snapshotKey,
      contentRevision: _leafContentRevision,
      child: _buildBookPageLeaf(
        chapters,
        page,
        pageNumberPlacement: pageNumberPlacement,
        topInformationLayout: topInformationLayout,
      ),
    );
  }

  Widget _buildPageCurlSpread(
    BuildContext context,
    List<_NativeChapter> chapters,
    List<_BookPageRef> bookPages,
    int currentIndex,
  ) {
    final spreadStart = (currentIndex ~/ 2) * 2;
    final nextSpreadStart = spreadStart + 2;
    final hasPreviousSpread = spreadStart >= 2;
    final hasNextSpread = nextSpreadStart < bookPages.length;
    final currentLeft = bookPages[spreadStart];
    final currentRight = spreadStart + 1 < bookPages.length
        ? bookPages[spreadStart + 1]
        : null;
    final previousLeft = hasPreviousSpread ? bookPages[spreadStart - 2] : null;
    final previousRight = hasPreviousSpread ? bookPages[spreadStart - 1] : null;
    final nextLeft = hasNextSpread ? bookPages[nextSpreadStart] : null;
    final nextRight = nextSpreadStart + 1 < bookPages.length
        ? bookPages[nextSpreadStart + 1]
        : null;
    final pagesToPrepare = <_BookPageRef>[
      currentLeft,
      if (currentRight != null) currentRight,
      if (previousLeft != null) previousLeft,
      if (previousRight != null) previousRight,
      if (nextLeft != null) nextLeft,
      if (nextRight != null) nextRight,
    ];

    final left = ReaderShaderPageCurl(
      key: ValueKey(
        'native-spread-curl-left:${widget.book.id ?? _bookCacheKey}',
      ),
      controller: _spreadBackwardPageCurlController,
      coordinator: _spreadPageCurlCoordinator,
      edgeDragOnly: true,
      bindingEdge: ReaderPageBindingEdge.right,
      currentPage: _buildBookPageSnapshot(
        chapters,
        currentLeft,
        pageNumberPlacement: ReaderPageNumberPlacement.bottomLeft,
        topInformationLayout: ReaderTopInformationLayout.spreadLeft,
      ),
      backwardPage: previousLeft == null
          ? null
          : _buildBookPageSnapshot(
              chapters,
              previousLeft,
              pageNumberPlacement: ReaderPageNumberPlacement.bottomLeft,
              topInformationLayout: ReaderTopInformationLayout.spreadLeft,
            ),
      outgoingBackPage: previousRight == null
          ? null
          : _buildBookPageSnapshot(
              chapters,
              previousRight,
              pageNumberPlacement: ReaderPageNumberPlacement.bottomRight,
              topInformationLayout: ReaderTopInformationLayout.spreadRight,
            ),
      preparePages: () =>
          _precacheBookPageImages(context, chapters, pagesToPrepare),
      onTurnForward: () {},
      onTurnBackward: () =>
          _onBookPageChanged(spreadStart - 2, bookPages, chapters),
      paperColor: _readerTheme.background,
    );

    final right = currentRight == null
        ? null
        : ReaderShaderPageCurl(
            key: ValueKey(
              'native-spread-curl-right:${widget.book.id ?? _bookCacheKey}',
            ),
            controller: _spreadForwardPageCurlController,
            coordinator: _spreadPageCurlCoordinator,
            edgeDragOnly: true,
            currentPage: _buildBookPageSnapshot(
              chapters,
              currentRight,
              pageNumberPlacement: ReaderPageNumberPlacement.bottomRight,
              topInformationLayout: ReaderTopInformationLayout.spreadRight,
            ),
            outgoingBackPage: nextLeft == null
                ? null
                : _buildBookPageSnapshot(
                    chapters,
                    nextLeft,
                    pageNumberPlacement: ReaderPageNumberPlacement.bottomLeft,
                    topInformationLayout: ReaderTopInformationLayout.spreadLeft,
                  ),
            forwardPage: !hasNextSpread
                ? null
                : nextRight == null
                ? _buildBlankPageSnapshot(
                    pageIdentity: 'spread-$nextSpreadStart-right',
                    layoutFingerprint: nextLeft!.layoutFingerprint,
                    topInformationLayout:
                        ReaderTopInformationLayout.spreadRight,
                  )
                : _buildBookPageSnapshot(
                    chapters,
                    nextRight,
                    pageNumberPlacement: ReaderPageNumberPlacement.bottomRight,
                    topInformationLayout:
                        ReaderTopInformationLayout.spreadRight,
                  ),
            preparePages: () =>
                _precacheBookPageImages(context, chapters, pagesToPrepare),
            onTurnForward: () =>
                _onBookPageChanged(nextSpreadStart, bookPages, chapters),
            onTurnBackward: () {},
            paperColor: _readerTheme.background,
          );

    return ReaderPageCurlSpread(
      coordinator: _spreadPageCurlCoordinator,
      left: left,
      right: right,
      gutter: _buildSpreadGutter(),
    );
  }

  ReaderPageSnapshot _buildBlankPageSnapshot({
    required String pageIdentity,
    required String layoutFingerprint,
    ReaderTopInformationLayout topInformationLayout =
        ReaderTopInformationLayout.full,
  }) => ReaderPageSnapshot(
    key: ReaderPageSnapshotKey(
      pageIdentity:
          'native:${widget.book.id ?? _bookCacheKey}:'
          '$pageIdentity',
      layoutFingerprint: layoutFingerprint,
      themeId: _readerTheme.cacheKey,
    ),
    contentRevision: _leafContentRevision,
    child: _buildBlankPageLeaf(
      pageIdentity: pageIdentity,
      layoutFingerprint: layoutFingerprint,
      topInformationLayout: topInformationLayout,
    ),
  );

  Widget _buildBlankPageLeaf({
    required String pageIdentity,
    required String layoutFingerprint,
    required ReaderTopInformationLayout topInformationLayout,
  }) => ReaderPaperPageLeaf(
    palette: _readerTheme,
    safeArea: _readerSafeArea,
    metadata: ReaderPaperPageMetadata(
      pageIdentity:
          'native:${widget.book.id ?? _bookCacheKey}:'
          'blank:$pageIdentity',
      layoutFingerprint: layoutFingerprint,
      themeId: _readerTheme.cacheKey,
      chapterTitle: '',
      pageNumber: 0,
      pageCount: 0,
    ),
    horizontalPadding: math.max(14, _horizontalMargin),
    showTopInformation: _topBarStyle == ReaderTopBarStyle.reader,
    showFloatingStatus: _showLeafFloatingStatus,
    floatingStatusHorizontalPadding: _floatingStatusHorizontalPadding,
    topInformationLayout: topInformationLayout,
    showPageNumber: false,
    status: _leafStatusController.value,
    child: const SizedBox.expand(),
  );

  ReaderPaperPageMetadata _nativePageMetadata(
    _NativeChapter chapter,
    _ReaderPageData page, {
    required int chapterIndex,
    required int pageIndex,
    required int pageCount,
    required String layoutFingerprint,
  }) {
    final resolvedChapterTitle = chapter.title.isEmpty
        ? context.l10n.readerChapterFallback(chapterIndex + 1)
        : chapter.title;
    return ReaderPaperPageMetadata(
      pageIdentity:
          'native:${widget.book.id ?? _bookCacheKey}:'
          '${chapter.id}:$pageIndex:${page.startOffset}',
      layoutFingerprint: layoutFingerprint,
      themeId: _readerTheme.cacheKey,
      chapterTitle: resolvedChapterTitle,
      pageNumber: pageIndex + 1,
      pageCount: pageCount,
    );
  }

  Widget _buildPageLeaf(
    _NativeChapter chapter,
    _ReaderPageData page, {
    required int chapterIndex,
    required int pageIndex,
    required int pageCount,
    required String layoutFingerprint,
    ReaderPageNumberPlacement pageNumberPlacement =
        ReaderPageNumberPlacement.bottomRight,
    ReaderTopInformationLayout topInformationLayout =
        ReaderTopInformationLayout.full,
  }) {
    final metadata = _nativePageMetadata(
      chapter,
      page,
      chapterIndex: chapterIndex,
      pageIndex: pageIndex,
      pageCount: pageCount,
      layoutFingerprint: layoutFingerprint,
    );
    return ReaderPaperPageLeaf(
      palette: _readerTheme,
      safeArea: _readerSafeArea,
      metadata: metadata,
      pageNumberPlacement: pageNumberPlacement,
      horizontalPadding: math.max(14, _horizontalMargin),
      pageNumberHorizontalPadding: math.max(24, _horizontalMargin),
      showTopInformation: _topBarStyle == ReaderTopBarStyle.reader,
      showFloatingStatus: _showLeafFloatingStatus,
      floatingStatusHorizontalPadding: _floatingStatusHorizontalPadding,
      topInformationLayout: topInformationLayout,
      status: _leafStatusController.value,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _horizontalMargin,
          _effectiveTopMargin,
          _horizontalMargin,
          _effectiveBottomMargin,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: readerMaxTextContentWidth,
            ),
            child: SizedBox.expand(
              child: _buildPage(
                chapter,
                page,
                chapterIndex: chapterIndex,
                pageIndex: pageIndex,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpread({required Widget left, Widget? right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        _buildSpreadGutter(),
        Expanded(child: right ?? const SizedBox.expand()),
      ],
    );
  }

  Widget _buildSpreadGutter() {
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

  String _readerStatus(List<_ReaderPageData> pages, int chapterCount) {
    final statusPages =
        _pageMode == NativePageMode.verticalScroll &&
            _visibleContinuousParts.isNotEmpty
        ? _visibleContinuousParts.length
        : pages.length;
    final page = _pageIndex + 1;
    return context.l10n.readerStatusPaged(
      _chapterIndex + 1,
      chapterCount,
      page.clamp(1, statusPages),
      statusPages,
    );
  }

  Widget _buildReaderStatusText({
    required List<_ReaderPageData> pages,
    required int chapterCount,
    required TextStyle? style,
    Key? key,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _verticalScrollProgress,
      builder: (context, _, _) => Text(
        _readerStatus(pages, chapterCount),
        key: key,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }

  Widget _openingCrossfade(Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    );
  }

  Widget _buildOpeningScaffold({required Key key, required bool showLoader}) {
    return Scaffold(
      key: key,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: ReaderThemeBackground(
        palette: _readerTheme,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: showLoader
                    ? ReaderOpeningLoader(palette: _readerTheme)
                    : const SizedBox.expand(),
              ),
            ),
            ReaderChromeOverlay(
              palette: _readerTheme,
              visible: _controlsVisible,
              title: widget.book.title,
              statusBottom: _readerSafeArea.pageNumberBottom,
              showViewportStatus: false,
              statusBuilder: (_, _, _) => const SizedBox.shrink(),
              onBack: () => unawaited(_exitReader()),
              onBookmark: null,
              onTableOfContents: null,
              onSettings: _readerSettingsLoaded ? _showReadingSettings : () {},
              backTooltip: MaterialLocalizations.of(context).backButtonTooltip,
              bookmarkTooltip: context.l10n.readerAddBookmark,
              tableOfContentsTooltip: context.l10n.readerToolbarTOC,
              settingsTooltip: context.l10n.readingSettings,
              bookmarked: false,
              showSettingsAction: false,
              topKey: const ValueKey('native-reader-opening-top-controls'),
              bottomKey: const ValueKey(
                'native-reader-opening-bottom-controls',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderMessageScaffold({
    required Key key,
    required String message,
    bool showAppBar = false,
  }) {
    return Scaffold(
      key: key,
      backgroundColor: Colors.transparent,
      appBar: showAppBar ? AppBar(title: Text(widget.book.title)) : null,
      body: ReaderThemeBackground(
        palette: _readerTheme,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: _readerTheme.text, height: 1.4),
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleOpeningContentReady() {
    if (_openingContentReadyScheduled) return;
    _openingContentReadyScheduled = true;
    _openingLoaderTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openingContentReadyTimer = Timer(_openingContentSettleDelay, () {
        if (mounted) BookOpenTransition.markReaderContentReady(context);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final systemUiOverlayStyle = _readerSystemUiOverlayStyle;
    if (!_readerDependenciesInitialized) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        key: const ValueKey('reader-system-ui-region'),
        value: systemUiOverlayStyle,
        child: Theme(
          data: _readerThemeData,
          child: _buildOpeningScaffold(
            key: const ValueKey('native-reader-opening-placeholder'),
            showLoader: false,
          ),
        ),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('reader-system-ui-region'),
      value: systemUiOverlayStyle,
      child: PopScope(
        canPop: !_tapZoneEditorVisible,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            BookOpenTransition.beginExit();
          } else if (_tapZoneEditorVisible) {
            setState(() => _tapZoneEditorVisible = false);
          } else {
            unawaited(_exitReader());
          }
        },
        child: Theme(
          data: _readerThemeData,
          child: FutureBuilder<List<_NativeChapter>>(
            future: _chaptersFuture,
            builder: (context, snapshot) {
              if (!_readerSettingsLoaded || !_readerFontReady) {
                return _openingCrossfade(
                  _buildOpeningScaffold(
                    key: const ValueKey('native-reader-opening-placeholder'),
                    showLoader: false,
                  ),
                );
              }
              if (snapshot.hasError) {
                _scheduleOpeningContentReady();
                return _openingCrossfade(
                  _buildReaderMessageScaffold(
                    key: const ValueKey('native-reader-error'),
                    message: context.l10n.readerOpenFailed(
                      snapshot.error.toString(),
                    ),
                    showAppBar: true,
                  ),
                );
              }
              final chapters = snapshot.data;
              if (chapters == null) {
                if (!_showOpeningLoader) {
                  return _openingCrossfade(
                    _buildOpeningScaffold(
                      key: const ValueKey('native-reader-loading-placeholder'),
                      showLoader: false,
                    ),
                  );
                }
                return _openingCrossfade(
                  _buildOpeningScaffold(
                    key: const ValueKey('native-reader-loading'),
                    showLoader: true,
                  ),
                );
              }
              if (chapters.isEmpty) {
                _scheduleOpeningContentReady();
                return _openingCrossfade(
                  _buildReaderMessageScaffold(
                    key: const ValueKey('native-reader-empty'),
                    message: context.l10n.readerNoContent,
                  ),
                );
              }
              // 封面还在飞行时不构建正文：首次整章排版（50~100ms）会
              // 冻结飞行帧。等封面到达静止停留画面后再构建，排版落在
              // 无感知窗口里；已有分页缓存（重开同一本书）则立即构建。
              if (!_openingCoverHoldReachedNow && _pageCache.isEmpty) {
                return _openingCrossfade(
                  _buildOpeningScaffold(
                    key: const ValueKey('native-reader-loading-placeholder'),
                    showLoader: false,
                  ),
                );
              }

              _resolveSavedChapter(chapters);
              _chapterIndex = _chapterIndex.clamp(0, chapters.length - 1);
              final chapter = chapters[_chapterIndex];
              _scheduleOpeningContentReady();
              return _openingCrossfade(
                Scaffold(
                  key: const ValueKey('native-reader-content'),
                  backgroundColor: Colors.transparent,
                  // The reader page has no text field of its own, but Scaffold
                  // shrinks `body` for ANY keyboard inset by default, including
                  // one raised by a TextField inside a modal sheet stacked on
                  // top (e.g. the TOC search box). That resize changes the
                  // LayoutBuilder constraints below every animation frame,
                  // forcing a full chapter re-pagination each frame.
                  resizeToAvoidBottomInset: false,
                  body: ReaderThemeBackground(
                    palette: _readerTheme,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        _readerViewportSize = size;
                        final usesTwoPageLayout = _usesTwoPageLayout(size);
                        final paginationSize = _paginationSize(
                          size,
                          usesTwoPageLayout,
                        );
                        final paginationGeometryChanged =
                            !_lastPaginationSize.isEmpty &&
                            (_lastPaginationSize != paginationSize ||
                                _lastUsesTwoPageLayout != usesTwoPageLayout);
                        if (paginationGeometryChanged) {
                          _restoreAnchorAfterLayout = true;
                          _lastSavedLocation = null;
                        }
                        _lastPaginationSize = paginationSize;
                        _lastUsesTwoPageLayout = usesTwoPageLayout;
                        final textDirection = Directionality.of(context);
                        const textScaler = readerBodyTextScaler;
                        final pages = _pagesFor(
                          chapter,
                          _chapterIndex,
                          paginationSize,
                          textDirection,
                          textScaler,
                        );
                        _visiblePages = pages;
                        if (_pageMode == NativePageMode.verticalScroll) {
                          _visibleContinuousParts = _continuousPartsFor(
                            chapter,
                            size,
                          );
                          _visiblePages = _visibleContinuousParts
                              .map((part) => part.content)
                              .toList(growable: false);
                        }
                        _visibleChapterCount = chapters.length;
                        _visibleUsesTwoPageLayout = usesTwoPageLayout;
                        final bookPages =
                            _pageMode == NativePageMode.horizontalSlide ||
                                _pageMode == NativePageMode.coverSlide ||
                                _pageMode == NativePageMode.pageCurl
                            ? _bookPagesFor(
                                chapters,
                                _horizontalFirstChapter,
                                _horizontalLastChapter,
                                paginationSize,
                                textDirection,
                                textScaler,
                                padOddChapters: usesTwoPageLayout,
                              )
                            : const <_BookPageRef>[];
                        if (_pageMode == NativePageMode.horizontalSlide ||
                            _pageMode == NativePageMode.coverSlide ||
                            _pageMode == NativePageMode.pageCurl) {
                          _scheduleBookPaginationWarm(
                            chapters,
                            _horizontalLastChapter + 1,
                            paginationSize,
                            textDirection,
                            textScaler,
                          );
                          _scheduleBookPaginationWarm(
                            chapters,
                            _horizontalFirstChapter - 1,
                            paginationSize,
                            textDirection,
                            textScaler,
                          );
                        }
                        if (_openPreviousChapterAtLastPage) {
                          _pageIndex = usesTwoPageLayout
                              ? _spreadStartForPage(pages.length - 1)
                              : pages.length - 1;
                          _openPreviousChapterAtLastPage = false;
                        }
                        _pageIndex = _pageIndex.clamp(0, pages.length - 1);
                        if (usesTwoPageLayout) {
                          _pageIndex = _spreadStartForPage(_pageIndex);
                        }
                        if (_restoreAnchorAfterLayout &&
                            _anchorOffset != null) {
                          final anchor = _anchorOffset!;
                          final restoredIndex =
                              _pageMode == NativePageMode.verticalScroll
                              ? _continuousPartsFor(chapter, size).indexWhere(
                                  (part) =>
                                      anchor >= part.content.startOffset &&
                                      anchor < part.content.endOffset,
                                )
                              : anchor == 0 && pages.first.isChapterTitle
                              ? 0
                              : pages.indexWhere(
                                  (page) =>
                                      anchor >= page.startOffset &&
                                      anchor < page.endOffset,
                                );
                          if (restoredIndex >= 0) _pageIndex = restoredIndex;
                          if (usesTwoPageLayout) {
                            _pageIndex = _spreadStartForPage(_pageIndex);
                          }
                          _restoreAnchorAfterLayout = false;
                          if (_pageMode == NativePageMode.verticalScroll &&
                              anchor > 0) {
                            _scheduleInitialContinuousScrollRestore(size);
                          } else {
                            _initialPositionRestored = true;
                          }
                        }
                        if (_pageMode != NativePageMode.verticalScroll) {
                          final locationKey =
                              '$_chapterIndex:$_pageIndex:'
                              '${pages[_pageIndex].startOffset}';
                          if (_lastSavedLocation != locationKey) {
                            _lastSavedLocation = locationKey;
                            final pageToSave = pages[_pageIndex];
                            final chapterToSave = chapter;
                            final chapterIndexToSave = _chapterIndex;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _saveCanonicalProgress(
                                chapterToSave,
                                pageToSave,
                                chapterIndexToSave,
                              );
                            });
                          }
                        }
                        if (_pageMode == NativePageMode.horizontalSlide) {
                          final targetPage = bookPages.indexWhere(
                            (page) =>
                                page.chapterIndex == _chapterIndex &&
                                page.pageIndex == _pageIndex,
                          );
                          final targetControllerPage = usesTwoPageLayout
                              ? targetPage ~/ 2
                              : targetPage;
                          _pageController ??= PageController(
                            initialPage: math.max(0, targetControllerPage),
                          );
                          final pageControllerGeneration =
                              _pageControllerGeneration;
                          if (_horizontalChapterJumpPending) {
                            if (!_horizontalChapterJumpRevealScheduled) {
                              _horizontalChapterJumpRevealScheduled = true;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted ||
                                    pageControllerGeneration !=
                                        _pageControllerGeneration) {
                                  return;
                                }
                                setState(() {
                                  _horizontalChapterJumpPending = false;
                                  _horizontalChapterJumpRevealScheduled = false;
                                  _initialPositionRestored = true;
                                });
                              });
                            }
                          } else {
                            _initialPositionRestored = true;
                          }
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (pageControllerGeneration !=
                                _pageControllerGeneration) {
                              return;
                            }
                            final pageController = _pageController;
                            if (pageController == null ||
                                !pageController.hasClients) {
                              return;
                            }
                            final current = pageController.page?.round();
                            if (targetPage >= 0 &&
                                current != targetControllerPage) {
                              pageController.jumpToPage(targetControllerPage);
                            }
                          });
                        }

                        final bookmarkPage = _bookmarkPageFor(pages);
                        final currentBookmarkAnchorKey = _bookmarkAnchorKey(
                          chapter,
                          bookmarkPage,
                        );
                        final currentPageIsBookmarked = _bookmarks.any(
                          (bookmark) =>
                              bookmark.anchorKey == currentBookmarkAnchorKey,
                        );

                        final reader = ReaderPullBookmark(
                          enabled: _pullBookmarkEnabled,
                          bookmarked: currentPageIsBookmarked,
                          busy: _bookmarkBusy,
                          palette: _readerTheme,
                          addHint: context.l10n.readerPullBookmarkAddHint,
                          removeHint: context.l10n.readerPullBookmarkRemoveHint,
                          releaseHint:
                              context.l10n.readerPullBookmarkReleaseHint,
                          onTriggered: () =>
                              unawaited(_toggleBookmark(chapter, bookmarkPage)),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ReaderTapObserver(
                                  key: const ValueKey(
                                    'native-reader-tap-observer',
                                  ),
                                  enabled: !_annotationInteractionActive,
                                  onTap: _handleReaderTap,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onHorizontalDragEnd:
                                        _pageMode ==
                                                NativePageMode
                                                    .horizontalSlide ||
                                            _pageMode ==
                                                NativePageMode.coverSlide ||
                                            _pageMode == NativePageMode.pageCurl
                                        ? null
                                        : (details) => _handleHorizontalSwipe(
                                            details,
                                            pages,
                                            chapters.length,
                                            usesTwoPageLayout,
                                          ),
                                    child: _buildReaderContent(
                                      chapters,
                                      chapter,
                                      pages,
                                      bookPages,
                                      usesTwoPageLayout,
                                      _paginationFingerprintFor(
                                        _chapterIndex,
                                        paginationSize,
                                        textDirection,
                                        textScaler,
                                      ),
                                      size,
                                    ),
                                  ),
                                ),
                              ),
                              if (_showLeafFloatingStatus &&
                                  _pageMode == NativePageMode.verticalScroll)
                                ReaderFloatingStatusOverlay(
                                  palette: _readerTheme,
                                  status: _leafStatusController.value,
                                  safeArea: _readerSafeArea,
                                  horizontalPadding:
                                      _floatingStatusHorizontalPadding,
                                ),
                              ReaderChromeOverlay(
                                palette: _readerTheme,
                                visible: _controlsVisible,
                                title: chapter.title.isEmpty
                                    ? widget.book.title
                                    : chapter.title,
                                statusBottom: _readerSafeArea.pageNumberBottom,
                                showViewportStatus:
                                    _pageMode ==
                                        NativePageMode.verticalScroll &&
                                    _topBarStyle != ReaderTopBarStyle.hidden,
                                showViewportTitle:
                                    _pageMode ==
                                        NativePageMode.verticalScroll &&
                                    _topBarStyle == ReaderTopBarStyle.reader,
                                viewportTitleTop:
                                    _readerSafeArea.readerTopBarTop,
                                viewportTitleKey: const ValueKey(
                                  'native-reader-viewport-title',
                                ),
                                readerStatus: _leafStatusController.value,
                                viewportStatusHorizontalPadding: math.max(
                                  24,
                                  _horizontalMargin,
                                ),
                                statusBuilder: (context, style, key) =>
                                    _buildReaderStatusText(
                                      pages: pages,
                                      chapterCount: chapters.length,
                                      style: style,
                                      key: key,
                                    ),
                                onBack: () => unawaited(_exitReader()),
                                onBookmark: () => unawaited(
                                  _toggleBookmark(chapter, bookmarkPage),
                                ),
                                onTableOfContents: () => unawaited(
                                  _showTableOfContents(
                                    chapters,
                                    currentAnchorKey: currentBookmarkAnchorKey,
                                  ),
                                ),
                                onReadAloud: isReaderAloudPlatformSupported
                                    ? () => unawaited(_showReaderAloudPanel())
                                    : null,
                                readAloudTooltip: context.l10n.ttsReading,
                                readAloudActive: _readerAloudActive,
                                onAskAi: () => unawaited(
                                  _showAskAiPanel(chapter, bookmarkPage),
                                ),
                                askAiTooltip: context.l10n.readerAskAi,
                                onSettings: _showReadingSettings,
                                backTooltip: MaterialLocalizations.of(
                                  context,
                                ).backButtonTooltip,
                                bookmarkTooltip: currentPageIsBookmarked
                                    ? context.l10n.bookmarkRemoved
                                    : context.l10n.readerAddBookmark,
                                tableOfContentsTooltip:
                                    context.l10n.readerToolbarTOC,
                                settingsTooltip: context.l10n.readingSettings,
                                bookmarked: currentPageIsBookmarked,
                                bookmarkBusy: _bookmarkBusy,
                                topKey: const ValueKey(
                                  'native-reader-top-controls',
                                ),
                                bottomKey: const ValueKey(
                                  'native-reader-bottom-controls',
                                ),
                                statusKey: const ValueKey(
                                  'native-reader-status',
                                ),
                              ),
                            ],
                          ),
                        );
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            reader,
                            if (!_initialPositionRestored)
                              Positioned.fill(
                                child: ColoredBox(
                                  key: const ValueKey(
                                    'native-reader-positioning-placeholder',
                                  ),
                                  color: _readerTheme.background,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            if (_tapZoneEditorVisible)
                              Positioned.fill(
                                child: ReaderTapZoneEditorOverlay(
                                  palette: _readerTheme,
                                  zones: _tapZones,
                                  onZonesChanged: _setTapZones,
                                  onClose: () => setState(
                                    () => _tapZoneEditorVisible = false,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

List<_ReaderPageData> _paginateChapter(
  _NativeChapter chapter, {
  required double maxWidth,
  required double maxHeight,
  required NativeTextFlowStyle flowStyle,
  required TextStyle style,
  required int firstLineIndent,
  required int paragraphSpacing,
  required bool normalizeParagraphBreaks,
  required bool showDedicatedChapterTitlePage,
}) {
  final imageOffsets = <(int, int)>[];
  var searchFrom = 0;
  for (var i = 0; i < chapter.blocks.length; i++) {
    final block = chapter.blocks[i];
    if (block.hasImage) {
      final offset = block.startOffset >= 0 ? block.startOffset : searchFrom;
      imageOffsets.add((offset.clamp(searchFrom, chapter.plainText.length), i));
      continue;
    }
    final text = block.text;
    if (text == null || text.isEmpty) continue;
    if (block.startOffset >= searchFrom &&
        block.endOffset >= block.startOffset) {
      searchFrom = block.endOffset.clamp(searchFrom, chapter.plainText.length);
      continue;
    }
    final found = chapter.plainText.indexOf(text, searchFrom);
    if (found >= 0) searchFrom = found + text.length;
  }

  final hasChapterTitle =
      chapter.isNeedSplitTitle && chapter.title.trim().isNotEmpty;
  final showInlineChapterTitle =
      hasChapterTitle && !showDedicatedChapterTitlePage;
  final inlineTitleExtent = showInlineChapterTitle
      ? ReaderInlineChapterTitle.extentFor(
          title: chapter.title,
          maxWidth: maxWidth,
          bodyStyle: style,
          textDirection: flowStyle.textDirection,
          textScaler: flowStyle.textScaler,
          locale: flowStyle.locale,
        )
      : 0.0;
  var inlineTitlePending = showInlineChapterTitle;
  final pages = <_ReaderPageData>[
    if (hasChapterTitle && showDedicatedChapterTitlePage)
      const _ReaderPageData.chapterTitle(),
  ];
  var cursor = 0;
  List<_ReaderPageData> paginateRange(
    String text, {
    required int sourceOffset,
    required double pageHeight,
    double? firstPageHeight,
  }) {
    if (text.isEmpty) return const <_ReaderPageData>[];
    final effectiveFirstPageHeight = inlineTitlePending
        ? ((firstPageHeight ?? pageHeight) - inlineTitleExtent).clamp(
            0.0,
            double.infinity,
          )
        : firstPageHeight;
    final textPages = paginateReaderText(
      text: text,
      maxWidth: maxWidth,
      maxHeight: pageHeight,
      firstPageHeight: effectiveFirstPageHeight,
      flowStyle: flowStyle,
      style: style,
      sourceOffset: sourceOffset,
      firstLineIndent: firstLineIndent,
      paragraphSpacing: paragraphSpacing,
      normalizeParagraphBreaks: normalizeParagraphBreaks,
      indentFirstParagraph:
          sourceOffset == 0 ||
          isReaderLineBreakCodeUnit(
            chapter.plainText.codeUnitAt(sourceOffset - 1),
          ),
      sourceSpanBuilder: (sourceStart, sourceEnd) =>
          _styledSpanForRange(chapter, sourceStart, sourceEnd, style),
    );
    final result = textPages
        .map(_ReaderPageData.fromTextPage)
        .toList(growable: false);
    if (inlineTitlePending && result.isNotEmpty) {
      result[0] = result[0].copyWith(showsInlineChapterTitle: true);
      inlineTitlePending = false;
    }
    return result;
  }

  for (var imageIndex = 0; imageIndex < imageOffsets.length; imageIndex++) {
    final image = imageOffsets[imageIndex];
    final offset = image.$1.clamp(cursor, chapter.plainText.length);
    final before = chapter.plainText.substring(cursor, offset);
    pages.addAll(
      paginateRange(before, sourceOffset: cursor, pageHeight: maxHeight),
    );

    final nextImageOffset = imageIndex + 1 < imageOffsets.length
        ? imageOffsets[imageIndex + 1].$1
        : chapter.plainText.length;
    final available = chapter.plainText.substring(offset, nextImageOffset);
    final hasImage = chapter.blocks[image.$2].hasImage;
    final inlineTextHeight = hasImage
        ? ((maxHeight - _imagePageGap).clamp(0, double.infinity) *
              _imagePageTextFlex /
              (_imagePageImageFlex + _imagePageTextFlex))
        : maxHeight;
    final inlineChunks = paginateRange(
      available,
      sourceOffset: offset,
      pageHeight: maxHeight,
      firstPageHeight: inlineTextHeight,
    );
    assert(inlineChunks.isEmpty || inlineChunks.first.startOffset == offset);
    assert(
      inlineChunks.isEmpty || inlineChunks.last.endOffset == nextImageOffset,
    );
    final inlinePage = inlineChunks.isEmpty
        ? _ReaderPageData(
            text: '',
            imageBlockIndex: image.$2,
            startOffset: offset,
            endOffset: nextImageOffset,
          )
        : inlineChunks.first.copyWith(imageBlockIndex: image.$2);
    pages.add(inlinePage);
    // The shared projection keeps canonical/display offsets continuous. Only
    // the image-bearing first page uses the reduced text area; continuing text
    // pages return to the full page height.
    pages.addAll(inlineChunks.skip(1));
    cursor = nextImageOffset;
  }

  if (cursor < chapter.plainText.length || pages.isEmpty) {
    pages.addAll(
      paginateRange(
        chapter.plainText.substring(cursor),
        sourceOffset: cursor,
        pageHeight: maxHeight,
      ),
    );
  }
  if (pages.isEmpty) {
    pages.add(
      _ReaderPageData(
        text: '',
        startOffset: 0,
        endOffset: chapter.plainText.length,
        showsInlineChapterTitle: showInlineChapterTitle,
      ),
    );
  }
  assert(pages.isNotEmpty);
  assert(pages.first.startOffset == 0);
  assert(pages.last.endOffset == chapter.plainText.length);
  for (var index = 1; index < pages.length; index++) {
    assert(pages[index - 1].endOffset == pages[index].startOffset);
  }
  return pages;
}

class _NativeChapter {
  _NativeChapter({
    required this.id,
    required this.title,
    required this._plainText,
    required this._blocks,
    this.depth = 0,
    this.isNeedSplitTitle = false,
  }) : _dataPath = null,
       _startOffset = 0,
       _endOffset = 0;

  _NativeChapter.lazyFileText({
    required this.id,
    required this.title,
    required this._dataPath,
    required this._startOffset,
    required this._endOffset,
    this.depth = 0,
    this.isNeedSplitTitle = false,
  }) : _plainText = null,
       _blocks = null;

  _NativeChapter.lazyEpub({
    required Map<String, dynamic> descriptor,
    required Map<String, dynamic> loadArguments,
  }) : id = descriptor['id'] as String? ?? '',
       title = descriptor['title'] as String? ?? '',
       depth = descriptor['depth'] as int? ?? 0,
       isNeedSplitTitle = false,
       _plainText = null,
       _blocks = null,
       _dataPath = null,
       _startOffset = 0,
       _endOffset = 0,
       _epubDescriptor = descriptor,
       _epubLoadArguments = loadArguments;

  final String id;
  final String title;
  final int depth;
  final bool isNeedSplitTitle;
  final String? _plainText;
  final List<_NativeBlock>? _blocks;
  final String? _dataPath;
  final int _startOffset;
  final int _endOffset;
  Map<String, dynamic>? _epubDescriptor;
  Map<String, dynamic>? _epubLoadArguments;
  String? _loadedText;
  Future<String>? _textLoad;
  Future<void>? _pendingLoad;
  List<_NativeBlock>? _loadedBlocks;
  List<_NativeBlock>? _textBlocks;

  bool get hasLoadedText => _plainText != null || _loadedText != null;

  bool get isLazyEpub => _epubDescriptor != null;
  bool get hasPendingLoad => _pendingLoad != null;
  Future<void>? get pendingLoad => _pendingLoad;
  Map<String, dynamic> get epubDescriptor => _epubDescriptor!;
  Map<String, dynamic> get epubLoadArguments => _epubLoadArguments!;

  String get plainText => _plainText ?? (_loadedText ??= _readIndexedText());

  List<_NativeBlock> get blocks =>
      _blocks ??
      (_loadedBlocks ??= <_NativeBlock>[_NativeBlock.text(plainText)]);

  List<_NativeBlock> get textBlocks => _textBlocks ??= blocks
      .where((block) => block.text != null && block.startOffset >= 0)
      .toList(growable: false);

  Future<void> loadTextAsync() async {
    final pendingEpub = _pendingLoad;
    if (pendingEpub != null) {
      await pendingEpub;
      return;
    }
    if (hasLoadedText || _dataPath == null) return;
    final pending = _textLoad;
    if (pending != null) {
      await pending;
      return;
    }
    final future = _readIndexedTextAsync();
    _textLoad = future;
    try {
      _loadedText = await future;
    } finally {
      if (identical(_textLoad, future)) _textLoad = null;
    }
  }

  String _readIndexedText() {
    return readIndexedUtf8RangeSync(
      path: _dataPath!,
      startOffset: _startOffset,
      endOffset: _endOffset,
    );
  }

  Future<String> _readIndexedTextAsync() => readIndexedUtf8Range(
    path: _dataPath!,
    startOffset: _startOffset,
    endOffset: _endOffset,
  );

  void attachPendingLoad(Future<void> load) => _pendingLoad = load;

  void clearPendingLoad() => _pendingLoad = null;

  void applyEpubResult(Map<String, dynamic> result) {
    final chapter = Map<String, dynamic>.from(result['chapter'] as Map);
    _loadedText = chapter['plainText'] as String? ?? '';
    _loadedBlocks = (chapter['blocks'] as List<dynamic>? ?? const [])
        .map(
          (block) =>
              _NativeBlock.fromMap(Map<String, dynamic>.from(block as Map)),
        )
        .toList(growable: false);
    _textBlocks = null;
  }

  void unloadLazyContent() {
    if (!isLazyEpub || _pendingLoad != null) return;
    _loadedText = null;
    _loadedBlocks = null;
    _textBlocks = null;
  }
}

class _BookPageRef {
  const _BookPageRef({
    required this.chapterIndex,
    required this.pageIndex,
    required this.pageCount,
    required this.layoutFingerprint,
    required this.content,
    this.isBlank = false,
  });

  final int chapterIndex;
  final int pageIndex;
  final int pageCount;
  final String layoutFingerprint;
  final _ReaderPageData content;
  final bool isBlank;
}

class _ReaderPageData extends ReaderTextPage {
  const _ReaderPageData({
    required super.text,
    this.imageBlockIndex,
    super.startOffset = 0,
    super.endOffset,
    super.layout,
    super.displayStart = 0,
    super.displayEnd,
    super.isChapterTitle = false,
    this.showsInlineChapterTitle = false,
  });

  const _ReaderPageData.chapterTitle()
    : imageBlockIndex = null,
      showsInlineChapterTitle = false,
      super.chapterTitle();

  factory _ReaderPageData.fromTextPage(ReaderTextPage page) => _ReaderPageData(
    text: page.text,
    startOffset: page.startOffset,
    endOffset: page.endOffset,
    layout: page.layout,
    displayStart: page.displayStart,
    displayEnd: page.displayEnd,
    isChapterTitle: page.isChapterTitle,
  );

  final int? imageBlockIndex;
  final bool showsInlineChapterTitle;

  _ReaderPageData copyWith({
    int? imageBlockIndex,
    bool? showsInlineChapterTitle,
  }) => _ReaderPageData(
    text: text,
    imageBlockIndex: imageBlockIndex ?? this.imageBlockIndex,
    startOffset: startOffset,
    endOffset: endOffset,
    layout: layout,
    displayStart: displayStart,
    displayEnd: displayEnd,
    isChapterTitle: isChapterTitle,
    showsInlineChapterTitle:
        showsInlineChapterTitle ?? this.showsInlineChapterTitle,
  );
}

class _ContinuousReaderPart {
  const _ContinuousReaderPart(this.content, {this.imageBlockIndex});

  final _ReaderPageData content;
  final int? imageBlockIndex;
}

class _NativeBlock {
  _NativeBlock._({
    this.text,
    this.imageBytes,
    this.imagePath,
    this.startOffset = -1,
    this.endOffset = -1,
    this.fontScale = 1,
    this.bold = false,
    this.italic = false,
    this.fontFamily,
    this.colorHex,
  });

  factory _NativeBlock.text(String text) => _NativeBlock._(text: text);

  /// [resolveImage] looks up already-decoded bytes by the shared image name
  /// stashed in `content` (see [_richChaptersFromParsed]) instead of each
  /// block carrying its own base64 copy — a page-header image reused across
  /// thousands of chapters would otherwise be duplicated and re-decoded that
  /// many times.
  factory _NativeBlock.fromMap(
    Map<String, dynamic> map, {
    Uint8List? Function(String name)? resolveImage,
  }) => _NativeBlock._(
    text: map['type'] == 'text' ? map['content'] : null,
    imageBytes: map['type'] == 'image'
        ? resolveImage?.call(map['content'] ?? '')
        : null,
    imagePath: map['type'] == 'image' ? map['imagePath'] as String? : null,
    startOffset: _nativeInt(map['startOffset']),
    endOffset: _nativeInt(map['endOffset']),
    fontScale: _nativeDouble(map['fontScale']),
    bold: map['bold'] == true || map['bold'] == 'true',
    italic: map['italic'] == true || map['italic'] == 'true',
    fontFamily: map['fontFamily'] as String?,
    colorHex: map['color'],
  );

  final String? text;
  final Uint8List? imageBytes;
  final String? imagePath;
  final int startOffset;
  final int endOffset;
  final double fontScale;
  final bool bold;
  final bool italic;
  final String? fontFamily;
  final String? colorHex;

  ImageProvider? get imageProvider {
    final memory = imageBytes;
    if (memory != null) return MemoryImage(memory);
    final filePath = imagePath;
    return filePath == null ? null : FileImage(File(filePath));
  }

  bool get hasImage => imageBytes != null || imagePath != null;
}

int _nativeInt(Object? value) => switch (value) {
  final int value => value,
  final String value => int.tryParse(value) ?? -1,
  _ => -1,
};

double _nativeDouble(Object? value) => switch (value) {
  final num value => value.toDouble(),
  final String value => double.tryParse(value) ?? 1,
  _ => 1,
};

@visibleForTesting
String? resolveNativeReaderFontFamily({
  required String? readerFontFamily,
  required String? epubFontFamily,
}) => readerFontFamily ?? epubFontFamily;

TextStyle _styleForNativeBlock(_NativeBlock block, TextStyle base) {
  return base.copyWith(
    fontSize: (base.fontSize ?? 19) * block.fontScale,
    fontWeight: block.bold ? FontWeight.w700 : base.fontWeight,
    fontStyle: block.italic ? FontStyle.italic : base.fontStyle,
    fontFamily: resolveNativeReaderFontFamily(
      readerFontFamily: base.fontFamily,
      epubFontFamily: block.fontFamily,
    ),
    // Keep EPUB typography, but the reader theme owns foreground color so
    // embedded black/white text cannot disappear in night/day modes.
    color: base.color,
  );
}

TextSpan _styledSpanForRange(
  _NativeChapter chapter,
  int start,
  int end,
  TextStyle base,
) {
  if (start >= end) return TextSpan(style: base, text: '');
  final children = <InlineSpan>[];
  var cursor = start;
  final blocks = chapter.textBlocks;
  var low = 0;
  var high = blocks.length;
  while (low < high) {
    final middle = (low + high) >> 1;
    if (blocks[middle].endOffset <= start) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  for (var index = low; index < blocks.length; index++) {
    final block = blocks[index];
    if (block.startOffset >= end) break;
    final overlapStart = block.startOffset.clamp(start, end);
    final overlapEnd = block.endOffset.clamp(start, end);
    if (overlapStart > cursor) {
      children.add(
        TextSpan(
          text: chapter.plainText.substring(cursor, overlapStart),
          style: base,
        ),
      );
    }
    children.add(
      TextSpan(
        text: chapter.plainText.substring(overlapStart, overlapEnd),
        style: _styleForNativeBlock(block, base),
      ),
    );
    cursor = overlapEnd;
  }
  if (cursor < end) {
    children.add(
      TextSpan(text: chapter.plainText.substring(cursor, end), style: base),
    );
  }
  return TextSpan(style: base, children: children);
}

/// 获取 `<img>`/`<svg><image>` 元素的图片地址。
///
/// package:html 对带命名空间前缀的属性（如 xlink:href）使用 [html_dom.AttributeName]
/// 作为 attributes map 的 key 而非普通字符串，直接用字符串字面量查找会失配，
/// 因此这里按 toString() 结果比对。
String? _epubImageSrc(html_dom.Element element) {
  for (final entry in element.attributes.entries) {
    final key = entry.key.toString();
    if (key == 'src' || key == 'href' || key == 'xlink:href') {
      return entry.value;
    }
  }
  return null;
}

Future<Map<String, dynamic>> _parseEpubChapters(Uint8List bytes) async {
  final epub = await EpubReader.readBook(bytes);
  final result = <Map<String, dynamic>>[];
  final imagesByName = <String, String>{};

  final imageEntries = epub.Content?.Images?.entries;
  if (imageEntries != null) {
    for (final entry in imageEntries) {
      final content = entry.value.Content;
      if (content == null || content.isEmpty) continue;
      final name = path.basename(Uri.decodeFull(entry.key)).toLowerCase();
      imagesByName[name] = base64Encode(content);
    }
  }

  final cssSources = <String>[];
  final cssEntries = epub.Content?.Css?.values;
  if (cssEntries != null) {
    for (final cssFile in cssEntries) {
      cssSources.add(cssFile.Content ?? '');
    }
  }
  final cssRules = _cssRulesFromSources(cssSources);

  // epub.Chapters only covers files that have a navPoint in toc.ncx. Some
  // EPUBs (e.g. color-plate pages exported without TOC entries) put extra
  // XHTML files in the spine that never show up there, so building chapters
  // from epub.Chapters alone silently drops those pages/images entirely.
  // Walk the spine — the actual reading order — instead, and only borrow
  // titles/depth from the NCX tree for files that happen to match one.
  final titleByFile = <String, String>{};
  final depthByFile = <String, int>{};
  void indexNavChapters(List<EpubChapter>? chapters, [int depth = 0]) {
    if (chapters == null) return;
    for (final chapter in chapters) {
      final file = chapter.ContentFileName;
      if (file != null) {
        titleByFile[file] = chapter.Title ?? '';
        depthByFile[file] = depth;
      }
      indexNavChapters(chapter.SubChapters, depth + 1);
    }
  }

  indexNavChapters(epub.Chapters);

  final manifestHrefById = <String, String>{};
  for (final item in epub.Schema?.Package?.Manifest?.Items ?? const []) {
    final id = item.Id;
    final href = item.Href;
    if (id != null && href != null) manifestHrefById[id] = href;
  }

  final htmlContent = epub.Content?.Html;
  final spineFiles = <String>[];
  for (final itemRef in epub.Schema?.Package?.Spine?.Items ?? const []) {
    final href = manifestHrefById[itemRef.IdRef];
    if (href == null) continue;
    if (htmlContent == null || !htmlContent.containsKey(href)) continue;
    spineFiles.add(href);
  }

  for (final href in spineFiles) {
    final decodedHref = Uri.decodeFull(href);
    final chapter = _chapterMapFromHtmlDocument(
      id: decodedHref,
      title: titleByFile[decodedHref] ?? '',
      depth: depthByFile[decodedHref] ?? 0,
      document: html_parser.parse(htmlContent![href]?.Content ?? ''),
      imagesByName: imagesByName,
      cssRules: cssRules,
    );
    if (chapter != null) result.add(chapter);
  }
  return <String, dynamic>{'chapters': result, 'images': imagesByName};
}

/// 把扁平 CSS 文本解析为「选择器 → 声明」查找表（与阅读器的
/// 样式块提取相配的近似解析，不处理嵌套/媒体查询）。
Map<String, String> _cssRulesFromSources(Iterable<String> sources) {
  final cssRules = <String, String>{};
  for (final css in sources) {
    for (final match in RegExp(r'([^{}]+)\{([^{}]+)\}').allMatches(css)) {
      final declarations = match.group(2)?.trim() ?? '';
      for (final selector in (match.group(1) ?? '').split(',')) {
        cssRules[selector.trim().toLowerCase()] = declarations;
      }
    }
  }
  return cssRules;
}

/// 把单个 XHTML 文档转换为章节 map（plainText + 样式/图片 blocks）。
///
/// EPUB 与 Kindle（MOBI/KF8）共用：两者正文都是 HTML，差异只在
/// 图片命名与 CSS 来源，由调用方先行归一化（imagesByName 的值为
/// base64 字符串，图片引用需已重写为可按 basename 命中的文件名）。
Map<String, dynamic>? _chapterMapFromHtmlDocument({
  required String id,
  required String title,
  required int depth,
  required html_dom.Document document,
  required Map<String, String> imagesByName,
  required Map<String, String> cssRules,
}) {
  final blocks = <Map<String, String>>[];
  final plainText = StringBuffer();
  final elements =
      document.body?.querySelectorAll(
        'h1,h2,h3,h4,h5,h6,p,div,section,article,li,dd,dt,blockquote,pre,stanza,v,subtitle,a,img,svg image',
      ) ??
      const <html_dom.Element>[];
  for (final element in elements) {
    final isImage =
        element.localName == 'img' ||
        (element.localName == 'image' && element.namespaceUri != null);
    if (isImage) {
      final src = _epubImageSrc(element);
      if (src == null || src.startsWith('data:')) continue;
      final name = path
          .basename(Uri.decodeFull(src.split('?').first.split('#').first))
          .toLowerCase();
      // 只存图片名，不把 base64 内容内联进每一个块：同一张图（例如页头
      // logo）可能被数千个章节复用，内联会把它的编码内容复制数千份，
      // 拖慢解析并在重建 _NativeBlock 时于主线程重复 base64 解码。真正的
      // 内容由 [_richChaptersFromParsed] 按图片名解码一次、共享给所有引用。
      if (imagesByName.containsKey(name)) {
        blocks.add(<String, String>{
          'type': 'image',
          'content': name,
          'startOffset': '${plainText.length}',
          'endOffset': '${plainText.length}',
        });
      }
      continue;
    }
    if (element.localName == 'a' && _hasEpubTextBlockAncestor(element)) {
      continue;
    }
    // 只取块的"自有文本"（排除嵌套块子树）：querySelectorAll 会同时
    // 命中 blockquote 与其内部的 p，用整棵子树的 text 会导致正文重复。
    //
    // 源 XHTML 常把一个段落的文本折行排版，文本节点里会带着裸换行；
    // 这些换行只是排版折行，不是真正的段落分隔（段落间已由下方的
    // `\n\n` 显式分隔）。除 <pre> 外一律把内部空白（含换行）折叠成
    // 空格，否则会被 normalizeParagraphBreaks 误判成新段落，导致
    // 首行缩进出现在折行处而非每段真正的开头。
    final isPreformatted = element.localName == 'pre';
    final rawText = _epubElementOwnText(element);
    final text = _normalizeEpubElementText(
      rawText,
      preformatted: isPreformatted,
    );
    if (text.isNotEmpty) {
      if (plainText.isNotEmpty) plainText.write('\n\n');
      final startOffset = plainText.length;
      plainText.write(text);
      final tag = (element.localName ?? '').toLowerCase();
      final classes = element.classes
          .map((className) => cssRules['.${className.toLowerCase()}'])
          .whereType<String>();
      final styleSource = <String>[
        cssRules[tag] ?? '',
        ...classes,
        element.attributes['style'] ?? '',
      ].join(';').toLowerCase();
      final headingLevel = tag.startsWith('h')
          ? int.tryParse(tag.substring(1))?.clamp(1, 6)
          : null;
      const headingScales = <int, double>{
        1: 1.75,
        2: 1.5,
        3: 1.3,
        4: 1.18,
        5: 1.1,
        6: 1.05,
      };
      final color = RegExp(
        r'color\s*:\s*([^;]+)',
      ).firstMatch(styleSource)?.group(1)?.trim();
      final block = <String, String>{
        'type': 'text',
        'content': text,
        'startOffset': '$startOffset',
        'endOffset': '${plainText.length}',
        'fontScale': '${headingScales[headingLevel] ?? 1}',
        'bold':
            '${headingLevel != null || tag == 'strong' || tag == 'b' || styleSource.contains('font-weight:bold') || styleSource.contains('font-weight: bold')}',
        'italic':
            '${tag == 'em' || tag == 'i' || styleSource.contains('font-style:italic') || styleSource.contains('font-style: italic')}',
      };
      if (color != null) block['color'] = color;
      blocks.add(block);
    }
  }
  if (blocks.isEmpty) {
    final fallback = _extractHtmlParagraphText(
      document.body?.nodes ?? const [],
    );
    if (fallback.isNotEmpty) {
      plainText.write(fallback);
      blocks.add(<String, String>{
        'type': 'text',
        'content': fallback,
        'startOffset': '0',
        'endOffset': '${fallback.length}',
      });
    }
  }
  if (plainText.isEmpty && blocks.isEmpty) return null;
  return <String, dynamic>{
    'id': id,
    'title': title,
    'depth': depth,
    'plainText': plainText.toString(),
    'blocks': blocks,
  };
}

/// Kindle（MOBI/AZW/AZW3）→ 章节 map 列表，在 compute isolate 中执行。
///
/// KF8 的 skeleton 分段天然就是章节；MOBI7 只有一整段 HTML，按
/// `<mbp:pagebreak>` 切分。图片引用（`recindex` / `kindle:embed`，均为
/// 1-based 块索引）先重写成 KindleUnpack 文件名，再走共用的 HTML
/// 章节转换。DRM 书籍抛 [KindleDrmException]。
Future<Map<String, dynamic>> _parseKindleChapters(Uint8List bytes) async {
  final content = parseKindleContent(bytes);
  final imagesByName = <String, String>{
    for (final entry in content.imagesByName.entries)
      entry.key.toLowerCase(): base64Encode(entry.value),
  };
  final cssRules = _cssRulesFromSources(content.cssParts);

  final sections = <String>[];
  if (content.htmlParts.length == 1) {
    sections.addAll(
      content.htmlParts.single
          .split(RegExp(r'<mbp:pagebreak[^>]*>', caseSensitive: false))
          .where((part) => part.trim().isNotEmpty),
    );
  } else {
    sections.addAll(content.htmlParts);
  }

  final result = <Map<String, dynamic>>[];
  for (var i = 0; i < sections.length; i++) {
    final html = rewriteKindleImageRefs(
      sections[i],
      content.imageNameByBlockIndex,
    );
    final document = html_parser.parse(html);
    // Kindle 没有可靠的 TOC 标签传导到分段这里，用分段内第一个标题
    // 作为章节名；没有标题的分段留空，与无 NCX 条目的 EPUB 行为一致。
    final heading = document.body
        ?.querySelector('h1,h2,h3,h4,h5,h6')
        ?.text
        .trim();
    final chapter = _chapterMapFromHtmlDocument(
      id: 'kindle-$i',
      title: heading ?? '',
      depth: 0,
      document: document,
      imagesByName: imagesByName,
      cssRules: cssRules,
    );
    if (chapter != null) result.add(chapter);
  }
  return <String, dynamic>{'chapters': result, 'images': imagesByName};
}

bool _hasEpubTextBlockAncestor(html_dom.Element element) {
  html_dom.Element? ancestor = element.parent;
  while (ancestor != null) {
    if (_epubTextBlockTags.contains(ancestor.localName)) return true;
    ancestor = ancestor.parent;
  }
  return false;
}

const Set<String> _epubTextBlockTags = <String>{
  'address',
  'article',
  'div',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'p',
  'li',
  'dd',
  'dt',
  'blockquote',
  'pre',
  'section',
  'stanza',
  'subtitle',
  'v',
};

String _normalizeEpubElementText(String rawText, {required bool preformatted}) {
  if (preformatted) {
    return rawText
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
        .trim();
  }
  return rawText
      .split(RegExp(r'[\u000b\u000c\u0085\u2028\u2029]'))
      .map((segment) => segment.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((segment) => segment.isNotEmpty)
      .join('\n\n');
}

/// 收集元素的自有文本：遇到嵌套的文本块子元素时跳过其子树，
/// 该子树的文本由它自己作为独立块处理。
String _epubElementOwnText(html_dom.Element element) {
  final buffer = StringBuffer();
  void visit(html_dom.Node node) {
    for (final child in node.nodes) {
      if (child is html_dom.Element) {
        if (child.localName == 'br') {
          buffer.write('\u2029');
          continue;
        }
        if (_epubTextBlockTags.contains(child.localName)) continue;
        visit(child);
      } else if (child is html_dom.Text) {
        buffer.write(child.data);
      }
    }
  }

  visit(element);
  return buffer.toString();
}

List<Map<String, dynamic>> _parseTxtFileInBackground(
  Map<String, dynamic> arguments,
) {
  final bytes = File(arguments['path'] as String).readAsBytesSync();
  final decoded = EnhancedTxtImportService().decodeWithOverride(
    bytes,
    encodingOverride: arguments['encoding'] as String?,
    verifyEncodingOverride: true,
  );
  final chapters = _parseTxtChapters(
    decoded,
    arguments['title'] as String,
    arguments['prefaceTitle'] as String,
  );
  return chapters
      .map(
        (chapter) => <String, dynamic>{
          'id': chapter.id,
          'title': chapter.title,
          'depth': chapter.depth,
          'plainText': chapter.plainText,
          'isNeedSplitTitle': chapter.isNeedSplitTitle,
        },
      )
      .toList(growable: false);
}

Map<String, dynamic> _indexTxtFileInBackground(Map<String, dynamic> arguments) {
  final bytes = File(arguments['path'] as String).readAsBytesSync();
  final decoded = EnhancedTxtImportService().decodeWithOverride(
    bytes,
    encodingOverride: arguments['encoding'] as String?,
    verifyEncodingOverride: true,
  );
  final sections = splitOversizedTxtSections(
    decoded,
    parseTxtChapterSections(
      decoded,
      fallbackTitle: arguments['title'] as String,
      prefaceTitle: arguments['prefaceTitle'] as String,
    ),
  );
  final chapters = <Map<String, dynamic>>[];
  final indexPath = arguments['indexPath'] as String;
  final dataPath = arguments['dataPath'] as String;
  final dataFile = File(dataPath);
  dataFile.parent.createSync(recursive: true);
  final temporaryData = File('$dataPath.tmp');
  final output = temporaryData.openSync(mode: FileMode.write);

  void writeChapter({
    required String id,
    required String title,
    required int startChar,
    required int endChar,
    required bool isNeedSplitTitle,
  }) {
    final startByte = output.positionSync();
    output.writeFromSync(utf8.encode(decoded.substring(startChar, endChar)));
    chapters.add(<String, dynamic>{
      'id': id,
      'title': title,
      'depth': 0,
      'isNeedSplitTitle': isNeedSplitTitle,
      'start': startByte,
      'end': output.positionSync(),
    });
  }

  try {
    for (final section in sections) {
      writeChapter(
        id: section.id,
        title: section.title,
        startChar: section.bodyStart,
        endChar: section.bodyEnd,
        isNeedSplitTitle: section.isNeedSplitTitle,
      );
    }
  } finally {
    output.closeSync();
  }

  if (dataFile.existsSync()) dataFile.deleteSync();
  temporaryData.renameSync(dataPath);

  final result = <String, dynamic>{
    'version': _txtChapterCacheVersion,
    'dataPath': dataPath,
    'chapters': chapters,
  };
  final indexFile = File(indexPath);
  final temporaryIndex = File('$indexPath.tmp');
  temporaryIndex.writeAsStringSync(jsonEncode(result), flush: true);
  if (indexFile.existsSync()) indexFile.deleteSync();
  temporaryIndex.renameSync(indexPath);
  return result;
}

Map<String, dynamic>? _readLargeTxtIndexCache(String indexPath) {
  try {
    final indexFile = File(indexPath);
    if (!indexFile.existsSync()) return null;
    final decoded = jsonDecode(indexFile.readAsStringSync());
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != _txtChapterCacheVersion) {
      return null;
    }
    final dataPath = decoded['dataPath'] as String?;
    final chapters = decoded['chapters'];
    if (dataPath == null || !File(dataPath).existsSync() || chapters is! List) {
      return null;
    }
    return decoded;
  } catch (_) {
    return null;
  }
}

void _deleteOversizedParsedChapterCaches(String cacheDirectoryPath) {
  final directory = Directory(cacheDirectoryPath);
  if (!directory.existsSync()) return;
  for (final entry in directory.listSync().whereType<File>()) {
    if (entry.path.endsWith('.json') &&
        entry.lengthSync() > _largeTxtFileThreshold) {
      entry.deleteSync();
    }
  }
}

List<Map<String, dynamic>>? _readParsedChapterCache(String cachePath) {
  try {
    final file = File(cachePath);
    if (!file.existsSync()) return null;
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != _txtChapterCacheVersion) {
      file.deleteSync();
      return null;
    }
    final chapters = decoded['chapters'];
    if (chapters is! List) return null;
    return chapters
        .map((chapter) => Map<String, dynamic>.from(chapter as Map))
        .toList(growable: false);
  } catch (_) {
    try {
      File(cachePath).deleteSync();
    } catch (_) {}
    return null;
  }
}

void _writeParsedChapterCache(Map<String, dynamic> arguments) {
  final cachePath = arguments['path'] as String;
  final file = File(cachePath);
  file.parent.createSync(recursive: true);
  final temporary = File('$cachePath.tmp');
  temporary.writeAsStringSync(
    jsonEncode(<String, dynamic>{
      'version': _txtChapterCacheVersion,
      'chapters': arguments['chapters'],
    }),
    flush: true,
  );
  if (file.existsSync()) file.deleteSync();
  temporary.renameSync(cachePath);

  final cachedFiles =
      file.parent
          .listSync()
          .whereType<File>()
          .where((entry) => entry.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  for (final stale in cachedFiles.skip(3)) {
    stale.deleteSync();
  }
}

/// 携带面向用户文案的书籍加载异常；错误页直接展示 [message]。
class _ReaderBookLoadException implements Exception {
  const _ReaderBookLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// EPUB/Kindle 等富文本管线的解析结果（`{'chapters': [...], 'images': {name:
/// base64}}`，见 [_parseEpubChapters]/[_parseKindleChapters]）→
/// [_NativeChapter]（保留样式与图片块）。
///
/// 每张图片的 base64 只在这里按名字解码一次并在所有引用它的章节间共享——
/// 图片内容不会像章节文本那样逐块内联，避免一张被数千个章节复用的页头图
/// 被重复解码数千次。
List<_NativeChapter> _richChaptersFromParsed(Map<String, dynamic> parsed) {
  final imagesByName = Map<String, String>.from(
    parsed['images'] as Map? ?? const {},
  );
  final decodedImages = <String, Uint8List>{};
  Uint8List? resolveImage(String name) {
    final cached = decodedImages[name];
    if (cached != null) return cached;
    final encoded = imagesByName[name];
    if (encoded == null) return null;
    final decoded = base64Decode(encoded);
    decodedImages[name] = decoded;
    return decoded;
  }

  final chapters = parsed['chapters'] as List<dynamic>? ?? const [];
  return chapters
      .map((chapter) => Map<String, dynamic>.from(chapter as Map))
      .map(
        (chapter) => _NativeChapter(
          id: chapter['id'] as String? ?? '',
          title: chapter['title'] as String? ?? '',
          depth: chapter['depth'] as int? ?? 0,
          plainText: chapter['plainText'] as String? ?? '',
          blocks: (chapter['blocks'] as List<dynamic>)
              .map(
                (block) => _NativeBlock.fromMap(
                  Map<String, String>.from(block as Map),
                  resolveImage: resolveImage,
                ),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
}

_NativeChapter _nativeChapterFromMap(Map<String, dynamic> chapter) {
  final text = chapter['plainText'] as String? ?? '';
  return _NativeChapter(
    id: chapter['id'] as String? ?? '',
    title: chapter['title'] as String? ?? '',
    depth: chapter['depth'] as int? ?? 0,
    isNeedSplitTitle: chapter['isNeedSplitTitle'] as bool? ?? false,
    plainText: text,
    blocks: <_NativeBlock>[_NativeBlock.text(text)],
  );
}

List<_NativeChapter> _nativeChaptersFromFileIndex(Map<String, dynamic> index) {
  final dataPath = index['dataPath'] as String? ?? '';
  final chapters = index['chapters'] as List<dynamic>? ?? const [];
  return chapters
      .map((chapter) {
        final values = Map<String, dynamic>.from(chapter as Map);
        return _NativeChapter.lazyFileText(
          id: values['id'] as String? ?? '',
          title: values['title'] as String? ?? '',
          depth: values['depth'] as int? ?? 0,
          isNeedSplitTitle: values['isNeedSplitTitle'] as bool? ?? false,
          dataPath: dataPath,
          startOffset: values['start'] as int? ?? 0,
          endOffset: values['end'] as int? ?? 0,
        );
      })
      .toList(growable: false);
}

List<_NativeChapter> _parseHtmlDocument(String source, String fallbackTitle) {
  final document = html_parser.parse(source);
  final headings = document.body?.querySelectorAll('h1,h2,h3,h4,h5,h6') ?? [];
  if (headings.isEmpty) {
    final text = _extractHtmlParagraphText(document.body?.nodes ?? const []);
    return <_NativeChapter>[
      _NativeChapter(
        id: 'html-0',
        title: document.querySelector('title')?.text.trim().isNotEmpty == true
            ? document.querySelector('title')!.text.trim()
            : fallbackTitle,
        plainText: text,
        blocks: <_NativeBlock>[_NativeBlock.text(text)],
      ),
    ];
  }
  final chapters = <_NativeChapter>[];
  for (var i = 0; i < headings.length; i++) {
    final heading = headings[i];
    final buffer = StringBuffer('${heading.text.trim()}\n\n');
    var node = heading.nextElementSibling;
    while (node != null &&
        !RegExp(r'^h[1-6]$').hasMatch(node.localName ?? '')) {
      final text = _extractHtmlParagraphText(<html_dom.Node>[node]);
      if (text.isNotEmpty) buffer.writeln('$text\n');
      node = node.nextElementSibling;
    }
    final text = buffer.toString();
    chapters.add(
      _NativeChapter(
        id: heading.id.isNotEmpty ? heading.id : 'html-$i',
        title: heading.text.trim(),
        depth:
            int.tryParse(
              (heading.localName ?? 'h1').substring(1),
            )?.clamp(1, 6) ??
            1,
        plainText: text,
        blocks: <_NativeBlock>[_NativeBlock.text(text)],
      ),
    );
  }
  return chapters;
}

List<_NativeChapter> _parseMarkdownDocument(
  String source,
  String fallbackTitle,
  String prefaceTitle,
) {
  final plain = source
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), r'$1')
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1')
      .replaceAll(RegExp(r'(^|\s)[*_~`]{1,3}|[*_~`]{1,3}(?=\s|$)'), r'$1');
  return _parseTxtChapters(plain, fallbackTitle, prefaceTitle);
}

List<_NativeChapter> _parseFb2Document(String source, String fallbackTitle) {
  final sections = RegExp(
    r'<section\b[^>]*>(.*?)</section>',
    caseSensitive: false,
    dotAll: true,
  ).allMatches(source).toList();
  if (sections.isEmpty) {
    final document = html_parser.parse(source);
    final text = _extractHtmlParagraphText(document.body?.nodes ?? const []);
    return <_NativeChapter>[
      _NativeChapter(
        id: 'fb2-0',
        title: fallbackTitle,
        plainText: text,
        blocks: <_NativeBlock>[_NativeBlock.text(text)],
      ),
    ];
  }
  return List<_NativeChapter>.generate(sections.length, (index) {
    final xml = sections[index].group(1) ?? '';
    final titleMatch = RegExp(
      r'<title\b[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(xml);
    final title = titleMatch == null
        ? '$fallbackTitle ${index + 1}'
        : html_parser.parse(titleMatch.group(1)).body?.text.trim() ?? '';
    final bodyXml = titleMatch == null
        ? xml
        : xml.replaceFirst(titleMatch.group(0)!, '');
    final text = _extractHtmlParagraphText(
      html_parser.parseFragment(bodyXml).nodes,
    );
    return _NativeChapter(
      id: 'fb2-$index',
      title: title,
      plainText: text,
      blocks: <_NativeBlock>[_NativeBlock.text(text)],
    );
  });
}

const _htmlParagraphTags = <String>{
  'address',
  'article',
  'blockquote',
  'dd',
  'div',
  'dl',
  'dt',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'li',
  'p',
  'section',
  'stanza',
  'subtitle',
  'v',
};

String _extractHtmlParagraphText(Iterable<html_dom.Node> nodes) {
  final output = StringBuffer();

  void walk(Iterable<html_dom.Node> children, {bool preformatted = false}) {
    for (final node in children) {
      if (node is html_dom.Text) {
        output.write(
          preformatted ? node.data : node.data.replaceAll(RegExp(r'\s+'), ' '),
        );
        continue;
      }
      if (node is! html_dom.Element) continue;
      final tag = (node.localName ?? '').toLowerCase();
      if (tag == 'br' || tag == 'empty-line') {
        output.write('\n');
        continue;
      }
      final isParagraph = _htmlParagraphTags.contains(tag);
      if (isParagraph) output.write('\n\n');
      walk(node.nodes, preformatted: preformatted || tag == 'pre');
      if (isParagraph) output.write('\n\n');
    }
  }

  walk(nodes);
  return output
      .toString()
      .replaceAll(RegExp(r'[ \t\u00a0]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _extractRtfText(Uint8List bytes) {
  final source = latin1.decode(bytes, allowInvalid: true);
  return source
      .replaceAllMapped(
        RegExp(r"\\'([0-9a-fA-F]{2})"),
        (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
      )
      .replaceAll(RegExp(r'\\par[d]?\b'), '\n')
      .replaceAll(RegExp(r'\\[a-zA-Z]+-?\d* ?'), '')
      .replaceAll(RegExp(r'[{}]'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _extractDocxText(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final document = archive.files.cast<ArchiveFile?>().firstWhere(
    (file) => file?.name == 'word/document.xml',
    orElse: () => null,
  );
  if (document == null) {
    throw const FormatException('DOCX document.xml missing');
  }
  final xml = utf8.decode(document.content as List<int>, allowMalformed: true);
  return xml
      .replaceAll(RegExp(r'</w:p>'), '\n')
      .replaceAll(RegExp(r'</w:tab>'), '\t')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

List<_NativeChapter> _parseTxtChapters(
  String text,
  String fallbackTitle,
  String prefaceTitle,
) {
  return parseTxtChapterSections(
        text,
        fallbackTitle: fallbackTitle,
        prefaceTitle: prefaceTitle,
      )
      .map((section) {
        final body = section.bodyIn(text);
        return _NativeChapter(
          id: section.id,
          title: section.title,
          plainText: body,
          blocks: <_NativeBlock>[_NativeBlock.text(body)],
          isNeedSplitTitle: section.isNeedSplitTitle,
        );
      })
      .toList(growable: false);
}

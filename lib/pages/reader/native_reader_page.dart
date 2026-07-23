import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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
import 'package:xxread/core/reader/reader_text_characters.dart';
import 'package:xxread/core/reader/reader_text_pagination.dart';
import 'package:xxread/core/reader/reader_theme_order.dart';
import 'package:xxread/core/reader/reader_vertical_paging.dart';
import 'package:xxread/core/reader/reader_volume_key_controller.dart';
import 'package:xxread/core/reader/txt_chapter_parser.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/models/bookmark.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/bookmark_dao.dart';
import 'package:xxread/services/books/enhanced_txt_import_service.dart';
import 'package:xxread/services/books/web_book_file_store.dart';
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

typedef NativePageMode = ReaderPageMode;

const int _largeTxtFileThreshold = 16 * 1024 * 1024;
const int _txtChapterCacheVersion = 2;
const double _imagePageGap = 10;
const int _imagePageImageFlex = 5;
const int _imagePageTextFlex = 6;

class NativeReaderPage extends StatefulWidget {
  const NativeReaderPage({super.key, required this.book, this.initialTheme});

  final Book book;
  final ReaderThemePalette? initialTheme;

  @override
  State<NativeReaderPage> createState() => _NativeReaderPageState();
}

class _NativeReaderPageState extends State<NativeReaderPage>
    with WidgetsBindingObserver {
  static final Map<String, Future<List<_NativeChapter>>> _bookMemoryCache = {};
  static final Map<String, Map<String, List<_ReaderPageData>>>
  _paginationMemoryCache = {};
  static const _spreadGutter = 24.0;
  static const _textStyle = TextStyle(
    fontSize: 19,
    height: 1.75,
    letterSpacing: 0.2,
  );

  late final Future<List<_NativeChapter>> _chaptersFuture;
  final PageController _pageController = PageController();
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
  final ValueNotifier<double> _verticalScrollProgress = ValueNotifier(0);
  final ReaderLeafStatusController _leafStatusController =
      ReaderLeafStatusController();
  late final Map<String, List<_ReaderPageData>> _pageCache;
  bool _readerDependenciesInitialized = false;
  int _chapterIndex = 0;
  int _horizontalFirstChapter = 0;
  int _horizontalLastChapter = 0;
  int _pageIndex = 0;
  int? _anchorOffset;
  bool _restoreAnchorAfterLayout = true;
  String? _lastSavedLocation;
  bool _openPreviousChapterAtLastPage = false;
  bool _controlsVisible = false;
  NativePageMode _pageMode = ReaderSettings.defaultPageMode;
  bool _scrollByChapter = true;
  double _fontSize = 19;
  double _lineHeight = 1.75;
  int _firstLineIndent = ReaderSettings.defaultFirstLineIndent;
  int _paragraphSpacing = ReaderSettings.defaultParagraphSpacing;
  double _horizontalMargin = 18;
  double _topMargin = ReaderMarginSettings.defaultTop;
  double _bottomMargin = ReaderMarginSettings.defaultBottom;
  FontOption _readerFont = FontCatalog.defaultReaderFont;
  String _readerThemeId = ReaderThemes.day.id;
  bool _pullBookmarkEnabled = false;
  bool _tapPageAnimationEnabled = true;
  bool _tabletTwoPageEnabled = ReaderSettings.defaultTabletTwoPageEnabled;
  bool _readerSettingsLoaded = false;
  bool _readerSystemUiApplied = false;
  bool _readerSystemUiApplyScheduled = false;
  bool _routeEntranceCompleted = false;
  ReaderTopBarStyle _topBarStyle = ReaderTopBarStyle.reader;
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
  bool _allowPop = false;
  List<_ReaderPageData> _visiblePages = const [];
  List<_NativeChapter> _visibleChapters = const [];
  int _visibleChapterCount = 0;
  bool _visibleUsesTwoPageLayout = false;
  Size _verticalViewportSize = Size.zero;
  TextDirection _verticalTextDirection = TextDirection.ltr;
  TextScaler _verticalTextScaler = TextScaler.noScaling;
  Size _lastPaginationSize = Size.zero;
  bool? _lastUsesTwoPageLayout;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _leafStatusController
      ..addListener(_onLeafStatusChanged)
      ..start();
    unawaited(ReaderKeepScreenOnController.activate(this));
    _startReadingSession();
    _chapterIndex = widget.book.currentPage;
    _horizontalFirstChapter = (_chapterIndex - 1).clamp(0, _chapterIndex);
    _horizontalLastChapter = _chapterIndex + 1;
    final savedLocator = widget.book.toCanonicalLocator();
    _anchorOffset = savedLocator?.textAnchor?.startOffsetUtf16;
    _verticalPagePositionsListener.itemPositions.addListener(
      _onVerticalPagePositionsChanged,
    );
    _verticalChapterPositionsListener.itemPositions.addListener(
      _onVerticalChapterPositionsChanged,
    );
    unawaited(_loadPageMode());
    unawaited(_loadBookmarks());
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

  Future<void> _exitReader() async {
    await _flushReadingSession();
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindRouteAnimation();
    var nextReaderFont = FontCatalog.defaultReaderFont;
    try {
      nextReaderFont = context.watch<AppSettingsNotifier>().readerFont;
    } on ProviderNotFoundException {
      // Reader widgets remain embeddable in tests and isolated previews.
    }
    if (_readerFont.id != nextReaderFont.id) {
      _readerFont = nextReaderFont;
      if (_readerDependenciesInitialized) {
        _pageCache.clear();
        _restoreAnchorAfterLayout = true;
      }
    }
    if (!_routeEntranceCompleted) return;
    _initializeReaderDependencies();
    _scheduleInitialReaderSystemUi();
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
    _initializeReaderDependencies();
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
      _chaptersFuture = _loadBook();
      _readerDependenciesInitialized = true;
      return;
    }
    if (!_bookMemoryCache.containsKey(cacheKey) &&
        _bookMemoryCache.length >= 2) {
      final oldestKey = _bookMemoryCache.keys.first;
      _bookMemoryCache.remove(oldestKey);
      _paginationMemoryCache.remove(oldestKey);
    }
    _pageCache = _paginationMemoryCache.putIfAbsent(cacheKey, () => {});
    _chaptersFuture = _bookMemoryCache.putIfAbsent(
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
    _readerDependenciesInitialized = true;
  }

  void _scheduleInitialReaderSystemUi() {
    if (!_routeEntranceCompleted ||
        _readerSystemUiApplied ||
        _readerSystemUiApplyScheduled) {
      return;
    }
    _readerSystemUiApplyScheduled = true;
    // Changing Android window insets while the cover is expanding forces the
    // live reader route to relayout mid-flight. Wait for the route to settle,
    // then apply the saved reader chrome on the following frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _readerSystemUiApplied) return;
      final topBarStyle = await ReaderSystemUiController.applySavedPreference();
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
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChanged);
    unawaited(_flushReadingSession());
    _pageController.dispose();
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
    super.dispose();
  }

  Future<void> _applyReaderSystemUi() =>
      ReaderSystemUiController.apply(style: _topBarStyle);

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
      ]);
      final settings = results[0] as ReaderSettings;
      final scrollByChapter = results[1] as bool;
      final customThemes = results[2] as List<ReaderCustomTheme>;
      final themeOrder = results[3] as List<String>;
      if (!mounted) return;
      ReaderThemes.setCustomThemes(customThemes);
      ReaderThemes.setThemeOrder(themeOrder);
      setState(() {
        _pageMode = settings.pageMode;
        _fontSize = settings.fontSize;
        _lineHeight = settings.lineHeight;
        _horizontalMargin = settings.horizontalMargin;
        _topMargin = settings.topMargin;
        _bottomMargin = settings.bottomMargin;
        _firstLineIndent = settings.firstLineIndent;
        _paragraphSpacing = settings.paragraphSpacing;
        _scrollByChapter = scrollByChapter;
        _readerThemeId = ReaderThemes.byId(settings.themeId).id;
        _pullBookmarkEnabled = settings.pullBookmarkEnabled;
        _tapPageAnimationEnabled = settings.tapPageAnimationEnabled;
        _tabletTwoPageEnabled = settings.tabletTwoPageEnabled;
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
    fontFamilyFallback: _readerFont.fallbackFamilies.isEmpty
        ? null
        : _readerFont.fallbackFamilies,
    fontSize: _fontSize,
    height: _lineHeight,
    letterSpacing: _textStyle.letterSpacing,
    color: _readerTheme.text,
  );

  NativeTextFlowStyle _readerTextFlowStyle({
    TextDirection? direction,
    TextScaler? textScaler,
  }) {
    final style = _readerTextStyle;
    return NativeTextFlowStyle(
      textDirection: direction ?? Directionality.of(context),
      textScaler: textScaler ?? MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      strutStyle: readerStrutStyle(style),
      textHeightBehavior: readerTextHeightBehavior,
    );
  }

  Future<void> _setReaderTheme(String themeId) async {
    final nextTheme = ReaderThemes.byId(themeId);
    if (_readerThemeId == nextTheme.id) return;
    setState(() => _readerThemeId = nextTheme.id);
    await _readerSettingsStore.save(_readerSettings);
  }

  Widget _buildStyledReaderText(_NativeChapter chapter, _ReaderPageData page) {
    final flowStyle = _readerTextFlowStyle();
    return ReaderTextPageContent(
      page: page,
      chapterTitle: chapter.title,
      bodyStyle: _readerTextStyle,
      flowStyle: flowStyle,
      sourceSpanBuilder: (start, end) =>
          _styledSpanForRange(chapter, start, end, _readerTextStyle),
    );
  }

  ReaderSafeAreaMetrics get _readerSafeArea => ReaderSafeAreaMetrics(
    viewPadding: MediaQuery.viewPaddingOf(context),
    topMargin: _topMargin,
    bottomMargin: _bottomMargin,
    topChromeReserve: _topBarStyle == ReaderTopBarStyle.reader
        ? ReaderSafeAreaMetrics.readerTopBarReserve
        : 0,
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
    int? firstLineIndent,
    int? paragraphSpacing,
    double? horizontalMargin,
    double? topMargin,
    double? bottomMargin,
  }) async {
    setState(() {
      _fontSize = fontSize ?? _fontSize;
      _lineHeight = (lineHeight ?? _lineHeight).clamp(1.4, 2.1);
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

  String get _layoutSignature =>
      '${_fontSize.toStringAsFixed(1)}:'
      '${_lineHeight.toStringAsFixed(2)}:'
      '${_horizontalMargin.toStringAsFixed(1)}:'
      '${_topMargin.toStringAsFixed(1)}:'
      '${_bottomMargin.toStringAsFixed(1)}:${_pageMode.name}:'
      '$_firstLineIndent:$_paragraphSpacing:${_readerFont.id}';

  Future<void> _setTopBarStyle(ReaderTopBarStyle style) async {
    if (_topBarStyle == style) return;
    final repaginate =
        (_topBarStyle == ReaderTopBarStyle.reader) !=
        (style == ReaderTopBarStyle.reader);
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
    BookDao().updateBookCanonicalLocator(
      bookId,
      LocatorCodec.encodeCanonicalLocator(locator),
      null,
      _layoutSignature,
      chapterIndex,
    );
  }

  Future<void> _setPageMode(NativePageMode mode) async {
    if (_pageMode == mode) return;
    setState(() {
      _pageMode = mode;
      _pageIndex = 0;
      _restoreAnchorAfterLayout = true;
      _lastSavedLocation = null;
      _horizontalFirstChapter = (_chapterIndex - 1).clamp(0, _chapterIndex);
      _horizontalLastChapter = _chapterIndex + 1;
      _controlsVisible = false;
    });
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
        final cachedIndex = await compute(_readLargeTxtIndexCache, indexPath);
        if (cachedIndex != null) {
          return _nativeChaptersFromFileIndex(cachedIndex);
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

    final bytes = webBytes ?? await File(widget.book.filePath).readAsBytes();
    switch (format) {
      case 'epub':
        final parsed = await compute(_parseEpubChapters, bytes);
        return parsed
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
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false);
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

  Future<void> _setChapter(
    int index,
    int chapterCount, {
    bool recenterContinuousScroll = false,
  }) async {
    final next = index.clamp(0, chapterCount - 1);
    if (next == _chapterIndex && !recenterContinuousScroll) return;
    setState(() {
      _chapterIndex = next;
      _pageIndex = 0;
      _horizontalFirstChapter = (next - 1).clamp(0, next);
      _horizontalLastChapter = next + 1;
    });
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
    if (_pageMode == NativePageMode.horizontalSlide &&
        _pageController.hasClients) {
      if (animate) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _pageController.jumpToPage((_pageController.page?.round() ?? 0) + 1);
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
    if (_pageMode == NativePageMode.horizontalSlide &&
        _pageController.hasClients) {
      if (animate) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _pageController.jumpToPage(
          math.max(0, (_pageController.page?.round() ?? 0) - 1),
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
    final velocity = details.primaryVelocity ?? 0;
    if (_pageMode == NativePageMode.horizontalSlide ||
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
    double width,
    List<_ReaderPageData> pages,
    int chapterCount,
    bool usesTwoPageLayout,
  ) {
    final fraction = localPosition.dx / width;
    if (fraction < 0.28) {
      if (_pageMode == NativePageMode.verticalScroll) return;
      _previousPage(
        pages,
        chapterCount,
        usesTwoPageLayout: usesTwoPageLayout,
        animate: _tapPageAnimationEnabled,
      );
    } else if (fraction > 0.72) {
      if (_pageMode == NativePageMode.verticalScroll) return;
      _nextPage(
        pages,
        chapterCount,
        usesTwoPageLayout: usesTwoPageLayout,
        animate: _tapPageAnimationEnabled,
      );
    } else {
      _toggleControls();
    }
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  String _readerThemeName(BuildContext context, String themeId) {
    final customName = ReaderThemes.customThemeById(themeId)?.name.trim();
    if (customName != null && customName.isNotEmpty) return customName;
    switch (themeId) {
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

  Future<void> _showReadingSettings() async {
    final selectedMode = await showModalBottomSheet<NativePageMode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => ReaderSettingsSheet(
        title: context.l10n.readingSettings,
        themeTitle: context.l10n.readerThemeTitle,
        themeDescription: context.l10n.readerThemeDescription,
        pageModeTitle: context.l10n.pageTurningMode,
        pageModeSummary: _pageModeSummary(context),
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
        themeLabelFor: (id) => _readerThemeName(context, id),
        onThemeChanged: (id) => unawaited(_setReaderTheme(id)),
        onCustomThemeTap: _showCustomThemeEditor,
        onPageModeTap: _showPageModeSettings,
        onTopBarStyleTap: _showTopBarStyleSettings,
        onFontSizeChanged: (value) => unawaited(_updateLayout(fontSize: value)),
        onLineHeightChanged: (value) =>
            unawaited(_updateLayout(lineHeight: value)),
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
    NativePageMode.pageCurl => context.l10n.readerModePageCurl,
  };

  String _pageModeHint(NativePageMode mode) => switch (mode) {
    NativePageMode.verticalScroll => context.l10n.readerModeVerticalScrollHint,
    NativePageMode.instantPage => context.l10n.readerModeHorizontalPageHint,
    NativePageMode.horizontalSlide =>
      context.l10n.readerModeHorizontalSlideHint,
    NativePageMode.pageCurl => context.l10n.readerModePageCurlHint,
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

  _ReaderPageData _bookmarkPageFor(List<_ReaderPageData> pages) {
    if (_pageMode == NativePageMode.verticalScroll) {
      return pages[_pageIndex.clamp(0, pages.length - 1)];
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
    final pages = _pagesFor(
      chapters[chapterIndex],
      chapterIndex,
      _verticalViewportSize,
      _verticalTextDirection,
      _verticalTextScaler,
    );
    final anchor = _anchorOffset ?? 0;
    final targetPage = pages.indexWhere(
      (page) => anchor >= page.startOffset && anchor < page.endOffset,
    );
    final safePage = (targetPage < 0 ? 0 : targetPage).clamp(
      0,
      pages.length - 1,
    );
    setState(() {
      _pageIndex = safePage;
      _visiblePages = pages;
      _restoreAnchorAfterLayout = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (_scrollByChapter && _verticalPageScrollController.isAttached) {
      _verticalPageScrollController.jumpTo(index: safePage);
      return;
    }
    if (_verticalChapterScrollController.isAttached) {
      _verticalChapterScrollController.jumpTo(index: chapterIndex);
      if (safePage > 0) {
        await _verticalChapterOffsetController.animateScroll(
          offset: safePage * _verticalPageExtentFor(_verticalViewportSize),
          duration: const Duration(milliseconds: 1),
        );
      }
    }
  }

  Future<void> _showTableOfContents(
    List<_NativeChapter> chapters, {
    String? currentAnchorKey,
  }) async {
    // Built once outside the StatefulBuilder below: that builder re-runs on
    // every keyboard show/hide animation frame, and reallocating a
    // ReaderNavigationChapter per chapter on every frame is severe jank for
    // books with thousands of chapters.
    final navigationChapters = [
      for (var index = 0; index < chapters.length; index++)
        ReaderNavigationChapter(
          title: chapters[index].title,
          index: index,
          depth: chapters[index].depth,
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
    if (!_pageCache.containsKey(key) && _pageCache.length >= 96) {
      _pageCache.remove(_pageCache.keys.first);
    }
    return _pageCache.putIfAbsent(key, () {
      final verticalChrome = _pageMode == NativePageMode.verticalScroll
          ? _verticalChrome
          : null;
      return _paginateChapter(
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
      );
    });
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
        '${_readerFont.id}',
  ).cacheKey('native-line-v7');

  Widget _buildPage(_NativeChapter chapter, _ReaderPageData page) {
    final imageIndex = page.imageBlockIndex;
    if (imageIndex == null) {
      return _buildStyledReaderText(chapter, page);
    }
    final bytes = chapter.blocks[imageIndex].imageBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bytes != null)
          Expanded(
            flex: _imagePageImageFlex,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          ),
        if (bytes != null && page.text.isNotEmpty)
          const SizedBox(height: _imagePageGap),
        if (page.text.isNotEmpty)
          Expanded(
            flex: _imagePageTextFlex,
            child: _buildStyledReaderText(chapter, page),
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
      final chapterPages = _pagesFor(
        chapters[chapterIndex],
        chapterIndex,
        size,
        direction,
        textScaler,
      );
      final layoutFingerprint = _paginationFingerprintFor(
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
    });
    if (chapterChanged && widget.book.id != null) {
      BookDao().updateBookProgress(widget.book.id!, page.chapterIndex);
    }
    if (page.chapterIndex >= _horizontalLastChapter - 1 &&
        _horizontalLastChapter < chapters.length - 1) {
      setState(() => _horizontalLastChapter++);
    }
    if (page.chapterIndex <= _horizontalFirstChapter &&
        _horizontalFirstChapter > 0) {
      setState(() => _horizontalFirstChapter--);
    }
    _saveCanonicalProgress(
      chapters[page.chapterIndex],
      page.content,
      page.chapterIndex,
    );
  }

  Future<void> _precacheBookPageImages(
    BuildContext context,
    List<_NativeChapter> chapters,
    Iterable<_BookPageRef> pages,
  ) async {
    final images = <Uint8List>{};
    for (final page in pages) {
      if (page.isBlank) continue;
      final imageIndex = page.content.imageBlockIndex;
      if (imageIndex == null) continue;
      final bytes = chapters[page.chapterIndex].blocks[imageIndex].imageBytes;
      if (bytes != null) images.add(bytes);
    }
    await Future.wait(
      images.map((bytes) => precacheImage(MemoryImage(bytes), context)),
    );
  }

  ReaderViewportChromeMetrics get _verticalChrome =>
      ReaderViewportChromeMetrics(safeArea: _readerSafeArea);

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

  void _onVerticalPagePositionsChanged() {
    if (!mounted ||
        _pageMode != NativePageMode.verticalScroll ||
        !_scrollByChapter ||
        _visiblePages.isEmpty) {
      return;
    }
    final primary = pickPrimaryReaderItem(
      _verticalPagePositionsListener.itemPositions.value.map(_readerPosition),
    );
    if (primary == null) return;
    final nextPage = primary.index.clamp(0, _visiblePages.length - 1);
    _verticalScrollProgress.value = _visiblePages.length <= 1
        ? 0
        : (nextPage / (_visiblePages.length - 1)).clamp(0.0, 1.0);
    if (nextPage != _pageIndex) {
      if (nextPage > _pageIndex) _sessionPagesRead++;
      setState(() => _pageIndex = nextPage);
    }
    _saveCanonicalProgress(
      _visibleChapters[_chapterIndex],
      _visiblePages[nextPage],
      _chapterIndex,
    );
  }

  void _onVerticalChapterPositionsChanged() {
    if (!mounted ||
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
    final pages = _pagesFor(
      _visibleChapters[nextChapter],
      nextChapter,
      _verticalViewportSize,
      _verticalTextDirection,
      _verticalTextScaler,
    );
    final nextPage = readerPageIndexWithinItem(primary, pages.length);
    final movedForward =
        nextChapter > _chapterIndex ||
        (nextChapter == _chapterIndex && nextPage > _pageIndex);
    final chapterChanged = nextChapter != _chapterIndex;
    _verticalScrollProgress.value = pages.length <= 1
        ? 0
        : (nextPage / (pages.length - 1)).clamp(0.0, 1.0);
    if (chapterChanged || nextPage != _pageIndex) {
      if (movedForward) _sessionPagesRead++;
      setState(() {
        _chapterIndex = nextChapter;
        _pageIndex = nextPage;
        _visiblePages = pages;
      });
    }
    if (chapterChanged && widget.book.id != null) {
      BookDao().updateBookProgress(widget.book.id!, nextChapter);
    }
    _saveCanonicalProgress(
      _visibleChapters[nextChapter],
      pages[nextPage],
      nextChapter,
    );
  }

  Widget _buildVerticalPageCell(
    _NativeChapter chapter,
    _ReaderPageData page,
    Size viewport,
  ) {
    return SizedBox(
      key: ValueKey(
        'native-vertical-page:${chapter.id}:${page.startOffset}:'
        '${page.endOffset}:${page.isChapterTitle}',
      ),
      height: _verticalPageExtentFor(viewport),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _horizontalMargin),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: readerMaxTextContentWidth,
            ),
            child: SizedBox.expand(child: _buildPage(chapter, page)),
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
    final pages = _pagesFor(
      chapter,
      chapterIndex,
      viewport,
      _verticalTextDirection,
      _verticalTextScaler,
    );
    return Column(
      children: [
        for (final page in pages)
          _buildVerticalPageCell(chapter, page, viewport),
      ],
    );
  }

  Widget _buildVerticalPageList(
    _NativeChapter chapter,
    List<_ReaderPageData> pages,
    Size viewport,
  ) {
    return ReaderVerticalPagingSurface(
      surfaceKey: const ValueKey('native-reader-surface'),
      onTap: _toggleControls,
      child: ScrollablePositionedList.builder(
        key: ValueKey('native-vertical-pages:$_chapterIndex:$_layoutSignature'),
        itemScrollController: _verticalPageScrollController,
        itemPositionsListener: _verticalPagePositionsListener,
        initialScrollIndex: _pageIndex.clamp(0, pages.length - 1),
        minCacheExtent: _verticalPageExtentFor(viewport),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: pages.length,
        itemBuilder: (context, index) =>
            _buildVerticalPageCell(chapter, pages[index], viewport),
      ),
    );
  }

  Widget _buildVerticalBook(List<_NativeChapter> chapters, Size viewport) {
    return ReaderVerticalPagingSurface(
      surfaceKey: const ValueKey('native-reader-surface'),
      onTap: _toggleControls,
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
      _verticalTextScaler = MediaQuery.textScalerOf(context);
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
      return PageView.builder(
        controller: _pageController,
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
                    pageNumberPlacement: ReaderPageNumberPlacement.bottomRight,
                    topInformationLayout:
                        ReaderTopInformationLayout.spreadRight,
                  )
                : null,
          );
        },
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
      contentRevision: _topBarStyle == ReaderTopBarStyle.reader
          ? _leafStatusController.value.revision
          : 0,
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
    contentRevision: _topBarStyle == ReaderTopBarStyle.reader
        ? _leafStatusController.value.revision
        : 0,
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
            child: SizedBox.expand(child: _buildPage(chapter, page)),
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
    final page = _pageIndex + 1;
    return context.l10n.readerStatusPaged(
      _chapterIndex + 1,
      chapterCount,
      page.clamp(1, pages.length),
      pages.length,
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
      builder: (context, _, __) => Text(
        _readerStatus(pages, chapterCount),
        key: key,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final systemUiOverlayStyle = SystemUiHelper.overlayStyleForBackground(
      _readerTheme.background,
    );
    if (!_routeEntranceCompleted ||
        !_readerDependenciesInitialized ||
        !_readerSettingsLoaded ||
        !_readerSystemUiApplied) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        key: const ValueKey('reader-system-ui-region'),
        value: systemUiOverlayStyle,
        child: ColoredBox(
          key: const ValueKey('native-reader-opening-placeholder'),
          color: _readerTheme.background,
          child: const SizedBox.expand(),
        ),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('reader-system-ui-region'),
      value: systemUiOverlayStyle,
      child: PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_exitReader());
        },
        child: Theme(
          data: _readerThemeData,
          child: FutureBuilder<List<_NativeChapter>>(
            future: _chaptersFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Scaffold(
                  appBar: AppBar(title: Text(widget.book.title)),
                  body: Center(
                    child: Text(
                      context.l10n.readerOpenFailed(snapshot.error.toString()),
                    ),
                  ),
                );
              }
              final chapters = snapshot.data;
              if (chapters == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (chapters.isEmpty) {
                return Scaffold(
                  body: Center(child: Text(context.l10n.readerNoContent)),
                );
              }

              _chapterIndex = _chapterIndex.clamp(0, chapters.length - 1);
              final chapter = chapters[_chapterIndex];
              return Scaffold(
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
                      final pages = _pagesFor(
                        chapter,
                        _chapterIndex,
                        paginationSize,
                        Directionality.of(context),
                        MediaQuery.textScalerOf(context),
                      );
                      _visiblePages = pages;
                      _visibleChapterCount = chapters.length;
                      _visibleUsesTwoPageLayout = usesTwoPageLayout;
                      final bookPages =
                          _pageMode == NativePageMode.horizontalSlide ||
                              _pageMode == NativePageMode.pageCurl
                          ? _bookPagesFor(
                              chapters,
                              _horizontalFirstChapter,
                              _horizontalLastChapter,
                              paginationSize,
                              Directionality.of(context),
                              MediaQuery.textScalerOf(context),
                              padOddChapters: usesTwoPageLayout,
                            )
                          : const <_BookPageRef>[];
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
                      if (_restoreAnchorAfterLayout && _anchorOffset != null) {
                        final anchor = _anchorOffset!;
                        final restoredIndex =
                            anchor == 0 && pages.first.isChapterTitle
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
                            !_scrollByChapter &&
                            _pageIndex > 0) {
                          final restoreOffset =
                              _pageIndex * _verticalPageExtentFor(size);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted ||
                                !_verticalChapterScrollController.isAttached) {
                              return;
                            }
                            unawaited(
                              _verticalChapterOffsetController.animateScroll(
                                offset: restoreOffset,
                                duration: const Duration(milliseconds: 1),
                              ),
                            );
                          });
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
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!_pageController.hasClients) return;
                          final current = _pageController.page?.round();
                          if (targetPage >= 0 &&
                              current != targetControllerPage) {
                            _pageController.jumpToPage(targetControllerPage);
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

                      return ReaderPullBookmark(
                        enabled: _pullBookmarkEnabled,
                        bookmarked: currentPageIsBookmarked,
                        busy: _bookmarkBusy,
                        palette: _readerTheme,
                        addHint: context.l10n.readerPullBookmarkAddHint,
                        removeHint: context.l10n.readerPullBookmarkRemoveHint,
                        releaseHint: context.l10n.readerPullBookmarkReleaseHint,
                        onTriggered: () =>
                            unawaited(_toggleBookmark(chapter, bookmarkPage)),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTapUp: (details) => _handleTap(
                                  details.localPosition,
                                  size.width,
                                  pages,
                                  chapters.length,
                                  usesTwoPageLayout,
                                ),
                                onHorizontalDragEnd:
                                    _pageMode ==
                                            NativePageMode.horizontalSlide ||
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
                                    Directionality.of(context),
                                    MediaQuery.textScalerOf(context),
                                  ),
                                  size,
                                ),
                              ),
                            ),
                            ReaderChromeOverlay(
                              palette: _readerTheme,
                              visible: _controlsVisible,
                              title: chapter.title.isEmpty
                                  ? widget.book.title
                                  : chapter.title,
                              statusBottom: _readerSafeArea.pageNumberBottom,
                              showViewportStatus:
                                  _pageMode == NativePageMode.verticalScroll,
                              showViewportTitle:
                                  _pageMode == NativePageMode.verticalScroll &&
                                  _topBarStyle == ReaderTopBarStyle.reader,
                              viewportTitleTop: _readerSafeArea.readerTopBarTop,
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
                              statusKey: const ValueKey('native-reader-status'),
                            ),
                          ],
                        ),
                      );
                    },
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
}) {
  final imageOffsets = <(int, int)>[];
  var searchFrom = 0;
  for (var i = 0; i < chapter.blocks.length; i++) {
    final block = chapter.blocks[i];
    if (block.imageBase64 != null) {
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

  final pages = <_ReaderPageData>[
    if (chapter.isNeedSplitTitle && chapter.title.trim().isNotEmpty)
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
    final textPages = paginateReaderText(
      text: text,
      maxWidth: maxWidth,
      maxHeight: pageHeight,
      firstPageHeight: firstPageHeight,
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
    return textPages.map(_ReaderPageData.fromTextPage).toList(growable: false);
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
    final hasImage = chapter.blocks[image.$2].imageBytes != null;
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
    required String plainText,
    required List<_NativeBlock> blocks,
    this.depth = 0,
    this.isNeedSplitTitle = false,
  }) : _plainText = plainText,
       _blocks = blocks,
       _dataPath = null,
       _startOffset = 0,
       _endOffset = 0;

  _NativeChapter.lazyFileText({
    required this.id,
    required this.title,
    required String dataPath,
    required int startOffset,
    required int endOffset,
    this.depth = 0,
    this.isNeedSplitTitle = false,
  }) : _plainText = null,
       _blocks = null,
       _dataPath = dataPath,
       _startOffset = startOffset,
       _endOffset = endOffset;

  final String id;
  final String title;
  final int depth;
  final bool isNeedSplitTitle;
  final String? _plainText;
  final List<_NativeBlock>? _blocks;
  final String? _dataPath;
  final int _startOffset;
  final int _endOffset;

  late final String plainText = _plainText ?? _readIndexedText();

  late final List<_NativeBlock> blocks =
      _blocks ?? <_NativeBlock>[_NativeBlock.text(plainText)];

  String _readIndexedText() {
    final file = File(_dataPath!);
    final handle = file.openSync();
    try {
      handle.setPositionSync(_startOffset);
      return utf8.decode(handle.readSync(_endOffset - _startOffset));
    } finally {
      handle.closeSync();
    }
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
  });

  const _ReaderPageData.chapterTitle()
    : imageBlockIndex = null,
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

  _ReaderPageData copyWith({int? imageBlockIndex}) => _ReaderPageData(
    text: text,
    imageBlockIndex: imageBlockIndex ?? this.imageBlockIndex,
    startOffset: startOffset,
    endOffset: endOffset,
    layout: layout,
    displayStart: displayStart,
    displayEnd: displayEnd,
    isChapterTitle: isChapterTitle,
  );
}

class _NativeBlock {
  _NativeBlock._({
    this.text,
    this.imageBase64,
    this.startOffset = -1,
    this.endOffset = -1,
    this.fontScale = 1,
    this.bold = false,
    this.italic = false,
    this.colorHex,
  }) : imageBytes = imageBase64 == null ? null : base64Decode(imageBase64);

  factory _NativeBlock.text(String text) => _NativeBlock._(text: text);

  factory _NativeBlock.fromMap(Map<String, String> map) => _NativeBlock._(
    text: map['type'] == 'text' ? map['content'] : null,
    imageBase64: map['type'] == 'image' ? map['content'] : null,
    startOffset: int.tryParse(map['startOffset'] ?? '') ?? -1,
    endOffset: int.tryParse(map['endOffset'] ?? '') ?? -1,
    fontScale: double.tryParse(map['fontScale'] ?? '') ?? 1,
    bold: map['bold'] == 'true',
    italic: map['italic'] == 'true',
    colorHex: map['color'],
  );

  final String? text;
  final String? imageBase64;
  final Uint8List? imageBytes;
  final int startOffset;
  final int endOffset;
  final double fontScale;
  final bool bold;
  final bool italic;
  final String? colorHex;
}

TextStyle _styleForNativeBlock(_NativeBlock block, TextStyle base) {
  return base.copyWith(
    fontSize: (base.fontSize ?? 19) * block.fontScale,
    fontWeight: block.bold ? FontWeight.w700 : base.fontWeight,
    fontStyle: block.italic ? FontStyle.italic : base.fontStyle,
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
  for (final block in chapter.blocks) {
    if (block.text == null || block.startOffset < 0) continue;
    if (block.endOffset <= start || block.startOffset >= end) continue;
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

Future<List<Map<String, dynamic>>> _parseEpubChapters(Uint8List bytes) async {
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

  final cssRules = <String, String>{};
  final cssEntries = epub.Content?.Css?.values;
  if (cssEntries != null) {
    for (final cssFile in cssEntries) {
      final css = cssFile.Content ?? '';
      for (final match in RegExp(r'([^{}]+)\{([^{}]+)\}').allMatches(css)) {
        final declarations = match.group(2)?.trim() ?? '';
        for (final selector in (match.group(1) ?? '').split(',')) {
          cssRules[selector.trim().toLowerCase()] = declarations;
        }
      }
    }
  }

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

  void append(List<String> files) {
    for (final href in files) {
      final decodedHref = Uri.decodeFull(href);
      final title = titleByFile[decodedHref] ?? '';
      final depth = depthByFile[decodedHref] ?? 0;
      final document = html_parser.parse(htmlContent![href]?.Content ?? '');
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
          final encoded = imagesByName[name];
          if (encoded != null) {
            blocks.add(<String, String>{
              'type': 'image',
              'content': encoded,
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
          blocks.add(<String, String>{
            'type': 'text',
            'content': text,
            'startOffset': '$startOffset',
            'endOffset': '${plainText.length}',
            'fontScale': '${headingScales[headingLevel] ?? 1}',
            'bold':
                '${headingLevel != null || tag == 'strong' || tag == 'b' || styleSource.contains('font-weight:bold') || styleSource.contains('font-weight: bold')}',
            'italic':
                '${tag == 'em' || tag == 'i' || styleSource.contains('font-style:italic') || styleSource.contains('font-style: italic')}',
            if (color != null) 'color': color,
          });
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
      if (plainText.isNotEmpty || blocks.isNotEmpty) {
        result.add(<String, dynamic>{
          'id': decodedHref,
          'title': title,
          'depth': depth,
          'plainText': plainText.toString(),
          'blocks': blocks,
        });
      }
    }
  }

  append(spineFiles);
  return result;
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
  final sections = parseTxtChapterSections(
    decoded,
    fallbackTitle: arguments['title'] as String,
    prefaceTitle: arguments['prefaceTitle'] as String,
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

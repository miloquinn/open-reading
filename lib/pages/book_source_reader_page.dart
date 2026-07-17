import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:provider/provider.dart';

import 'package:xxread/core/reader/canonical_locator.dart';
import 'package:xxread/core/reader/native_text_paginator.dart';
import 'package:xxread/core/reader/reader_layout.dart';
import 'package:xxread/core/reader/reader_margin_settings.dart';
import 'package:xxread/core/reader/reader_safe_area.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/core/reader/reader_system_ui.dart';
import 'package:xxread/core/reader/reader_volume_key_controller.dart';
import 'package:xxread/models/bookmark.dart';

import '../book_sources/models/registered_book_source.dart';
import '../book_sources/protocol/book_source_protocol.dart';
import '../book_sources/services/book_source_client.dart';
import '../book_sources/services/book_source_reading_progress.dart';
import '../book_sources/services/book_source_shelf_service.dart';
import '../book_sources/services/book_source_text_paginator.dart';
import '../services/reading/reading_stats_dao.dart';
import '../services/books/bookmark_dao.dart';
import '../services/core/app_settings_service.dart';
import '../utils/font_catalog_helper.dart';
import '../utils/localization_extension.dart';
import '../utils/reader_themes.dart';
import '../utils/system_ui_helper.dart';
import '../widgets/reader_shader_page_curl.dart';
import '../widgets/reader_control_chrome.dart';
import '../widgets/reader_navigation_sheet.dart';
import '../widgets/reader_settings_controls.dart';
import '../widgets/side_toast.dart';

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
  late final BookSourceClient _client = widget.client ?? BookSourceClient();
  late final BookSourceShelfService _shelfService =
      widget.shelfService ?? BookSourceShelfService(client: _client);
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final ReaderPageCurlController _pageCurlController =
      ReaderPageCurlController();
  final ValueNotifier<double> _scrollProgress = ValueNotifier(0);

  List<BookSourceChapter> _chapters = const [];
  BookSourceChapterContent? _content;
  int _chapterIndex = 0;
  bool _loadingCatalog = true;
  bool _loadingContent = false;
  bool _controlsVisible = false;
  bool _restoringScroll = false;
  Object? _error;
  double _fontSize = 19;
  double _lineHeight = 1.75;
  FontOption _readerFont = FontCatalog.defaultReaderFont;
  double _horizontalMargin = ReaderSettings.defaultHorizontalMargin;
  double _topMargin = ReaderMarginSettings.defaultTop;
  double _bottomMargin = ReaderMarginSettings.defaultBottom;
  String _readerThemeId = ReaderThemes.day.id;
  BookSourcePageMode _pageMode = BookSourcePageMode.verticalScroll;
  int _pageIndex = 0;
  int _pageCount = 1;
  int _verticalPageIndex = 0;
  int _verticalPageCount = 1;
  int _pageViewLeading = 0;
  bool _ignoreSlidePageChanges = true;
  double _restorePageProgress = 0;
  bool _restorePagedPosition = false;
  int? _restoreTextOffset;
  String? _paginationKey;
  List<BookSourceTextPage> _paginatedPages = const [];
  int _chapterLoadSerial = 0;
  final Map<int, BookSourceChapterContent> _prefetchedContent = {};
  bool _exitPromptVisible = false;
  bool _allowPop = false;
  int? _shelfBookId;
  Timer? _progressSaveTimer;
  Timer? _controlsTimer;
  final ReadingStatsDao _readingStatsDao = ReadingStatsDao();
  final BookmarkDao _bookmarkDao = BookmarkDao();
  final ReaderSettingsStore _readerSettingsStore = const ReaderSettingsStore();
  List<Bookmark> _bookmarks = const [];
  bool _bookmarkBusy = false;
  DateTime? _readingSessionStartedAt;
  int _sessionPagesRead = 0;
  bool _readerSystemUiApplied = false;
  bool _showSystemStatusBarInReader = false;

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
      );

  ReaderSafeAreaMetrics get _readerSafeArea => ReaderSafeAreaMetrics(
        viewPadding: MediaQuery.viewPaddingOf(context),
        topMargin: _topMargin,
        bottomMargin: _bottomMargin,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startReadingSession();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _readerSystemUiApplied) return;
      final showStatusBar =
          await ReaderSystemUiController.applySavedPreference();
      if (!mounted) return;
      setState(() {
        _showSystemStatusBarInReader = showStatusBar;
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
    _restorePagedPosition = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startReadingSession();
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
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _pageController.dispose();
    _scrollProgress.dispose();
    unawaited(ReaderVolumeKeyController.deactivate(this));
    unawaited(ReaderSystemUiController.restore());
    super.dispose();
  }

  Future<void> _applyReaderSystemUi() => ReaderSystemUiController.apply(
        showStatusBar: _showSystemStatusBarInReader,
      );

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
      ]);
      final chapters = [...results[0]! as List<BookSourceChapter>]
        ..sort((a, b) => a.order.compareTo(b.order));
      final saved = results[1] as BookSourceReadingProgress?;
      final settings = results[2]! as ReaderSettings;
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
      setState(() {
        _chapters = chapters;
        _chapterIndex = initialIndex;
        _fontSize = settings.fontSize;
        _horizontalMargin = settings.horizontalMargin;
        _topMargin = settings.topMargin;
        _bottomMargin = settings.bottomMargin;
        _lineHeight = settings.lineHeight;
        _readerThemeId = ReaderThemes.byId(settings.themeId).id;
        _pageMode = settings.pageMode;
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
      if (forward) {
        await _pageCurlController.turnForward();
      } else {
        await _pageCurlController.turnBackward();
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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final progress =
        max <= 0 ? 0.0 : (_scrollController.offset / max).clamp(0.0, 1.0);
    _verticalPageCount = _pageCount.clamp(1, 1000000);
    _verticalPageIndex = (progress * (_verticalPageCount - 1)).round().clamp(
          0,
          _verticalPageCount - 1,
        );
    _scrollProgress.value = progress;
    if (_restoringScroll) return;
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_saveProgress()),
    );
  }

  Future<void> _saveProgress() async {
    if (_chapters.isEmpty || _chapterIndex >= _chapters.length) return;
    var progress = _scrollProgress.value;
    if (_pageMode == BookSourcePageMode.verticalScroll &&
        _scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      progress =
          max <= 0 ? 0 : (_scrollController.offset / max).clamp(0.0, 1.0);
    } else if (_pageMode != BookSourcePageMode.verticalScroll) {
      progress =
          _pageCount <= 1 ? 0 : (_pageIndex / (_pageCount - 1)).clamp(0.0, 1.0);
    }
    await widget.progressStore.save(
      sourceId: widget.source.id,
      bookId: widget.book.id,
      progress: BookSourceReadingProgress(
        chapterId: _chapters[_chapterIndex].id,
        chapterIndex: _chapterIndex,
        chapterProgress: progress,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    final shelfBookId = _shelfBookId;
    if (shelfBookId != null) {
      await _shelfService.updateShelfProgress(
        shelfBookId: shelfBookId,
        chapterIndex: _chapterIndex,
        chapterCount: _chapters.length,
        chapterProgress: progress,
      );
    }
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
    if (saveCurrent && _content != null) await _saveProgress();
    if (!mounted) return;
    final loadSerial = ++_chapterLoadSerial;
    setState(() {
      _loadingContent = true;
      _error = null;
    });
    try {
      final chapter = _chapters[index];
      final content = await _client.getChapterContent(
        widget.source,
        bookId: widget.book.id,
        chapterId: chapter.id,
      );
      if (!mounted || loadSerial != _chapterLoadSerial) return;
      setState(() {
        _chapterIndex = index;
        _content = content;
        _loadingContent = false;
        _pageIndex = 0;
        _pageCount = 1;
        _paginatedPages = const [];
        _paginationKey = null;
        _restorePageProgress = restoreProgress.clamp(0, 1);
        _restorePagedPosition = true;
        _ignoreSlidePageChanges = true;
      });
      _scrollProgress.value = restoreProgress.clamp(0, 1);
      _restoreScrollProgress(restoreProgress);
      unawaited(_preloadAround(index));
    } catch (error) {
      if (!mounted || loadSerial != _chapterLoadSerial) return;
      setState(() {
        _loadingContent = false;
        _error = error;
        _controlsVisible = true;
      });
    }
  }

  Future<void> _preloadAround(int index) async {
    final indexes = <int>{index - 1, index + 1, index + 2}
        .where((value) => value >= 0 && value < _chapters.length);
    final loaded = await Future.wait(
      indexes.map(
        (chapterIndex) async {
          try {
            return MapEntry(
              chapterIndex,
              await _client.getChapterContent(
                widget.source,
                bookId: widget.book.id,
                chapterId: _chapters[chapterIndex].id,
              ),
            );
          } catch (_) {
            return null;
          }
        },
      ),
    );
    if (!mounted) return;
    setState(
      () => _prefetchedContent.addEntries(
        loaded.whereType<MapEntry<int, BookSourceChapterContent>>(),
      ),
    );
  }

  void _restoreScrollProgress(double progress) {
    _restorePageProgress = progress.clamp(0, 1);
    _restorePagedPosition = true;
    if (_pageMode != BookSourcePageMode.verticalScroll) return;
    _restoringScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        _restoringScroll = false;
        return;
      }
      final target =
          _scrollController.position.maxScrollExtent * progress.clamp(0, 1);
      _scrollController.jumpTo(target);
      _scrollProgress.value = progress.clamp(0, 1);
      _restoringScroll = false;
    });
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
      return _pageCount <= 1
          ? 0
          : (_pageIndex / (_pageCount - 1)).clamp(0.0, 1.0);
    }
    if (_scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      return max <= 0 ? 0 : (_scrollController.offset / max).clamp(0.0, 1.0);
    }
    return _scrollProgress.value;
  }

  void _setPagedIndex(int index, {bool jumpPageView = false}) {
    if (_paginatedPages.isEmpty) return;
    final next = index.clamp(0, _paginatedPages.length - 1);
    if (next > _pageIndex) _sessionPagesRead++;
    if (next != _pageIndex) setState(() => _pageIndex = next);
    _pageCount = _paginatedPages.length;
    _scrollProgress.value =
        _pageCount <= 1 ? 0 : (_pageIndex / (_pageCount - 1)).clamp(0.0, 1.0);
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

  Future<void> _turnForward() async {
    if (_pageIndex + 1 < _pageCount) {
      _setPagedIndex(_pageIndex + 1, jumpPageView: true);
    } else if (_chapterIndex + 1 < _chapters.length) {
      await _loadChapter(_chapterIndex + 1, restoreProgress: 0);
    } else {
      _showControlsTemporarily();
    }
  }

  Future<void> _turnBackward() async {
    if (_pageIndex > 0) {
      _setPagedIndex(_pageIndex - 1, jumpPageView: true);
    } else if (_chapterIndex > 0) {
      await _loadChapter(_chapterIndex - 1, restoreProgress: 1);
    } else {
      _showControlsTemporarily();
    }
  }

  int _currentBookmarkOffset(String text) {
    if (_pageMode != BookSourcePageMode.verticalScroll &&
        _paginatedPages.isNotEmpty) {
      return _paginatedPages[_pageIndex.clamp(0, _paginatedPages.length - 1)]
          .startOffset;
    }
    return (_scrollProgress.value * text.length).round().clamp(0, text.length);
  }

  String? get _currentBookmarkAnchorKey {
    final content = _content;
    if (content == null || _chapters.isEmpty) return null;
    final text = _readableChapterText(content);
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
      );
      return;
    }
    final text = _readableChapterText(content);
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
    await _loadChapter(
      chapterIndex,
      restoreProgress: locator?.progression ?? 0,
    );
  }

  Future<void> _showCatalog() async {
    if (_chapters.isEmpty) return;
    _controlsTimer?.cancel();
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
            chapters: [
              for (var index = 0; index < _chapters.length; index++)
                ReaderNavigationChapter(
                  title: _chapters[index].title,
                  index: index,
                ),
            ],
            currentChapterIndex: _chapterIndex,
            bookmarks: _bookmarks,
            currentAnchorKey: _currentBookmarkAnchorKey,
            onChapterSelected: (index) {
              Navigator.of(sheetContext).pop();
              unawaited(_loadChapter(index));
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
    return switch (themeId) {
      'mist' => context.l10n.readerThemeMist,
      'green' => context.l10n.readerThemeGreen,
      'rose' => context.l10n.readerThemeRose,
      'navy' => context.l10n.readerThemeNavy,
      'night' => context.l10n.readerThemeNight,
      'pureBlack' => context.l10n.readerThemePureBlack,
      'parchment' => context.l10n.readerThemeParchment,
      _ => context.l10n.readerThemeDay,
    };
  }

  Future<void> _updateReadingSettings({
    double? fontSize,
    double? lineHeight,
    double? horizontalMargin,
    double? topMargin,
    double? bottomMargin,
    String? themeId,
    BookSourcePageMode? pageMode,
  }) async {
    final currentProgress = _currentReadingProgress;
    final currentTextOffset = _pageMode != BookSourcePageMode.verticalScroll &&
            _paginatedPages.isNotEmpty
        ? _paginatedPages[_pageIndex.clamp(0, _paginatedPages.length - 1)]
            .startOffset
        : null;
    setState(() {
      _fontSize = fontSize ?? _fontSize;
      _lineHeight = (lineHeight ?? _lineHeight).clamp(1.4, 2.1);
      _horizontalMargin = (horizontalMargin ?? _horizontalMargin).clamp(8, 48);
      _topMargin = (topMargin ?? _topMargin)
          .clamp(ReaderMarginSettings.min, ReaderMarginSettings.max);
      _bottomMargin = (bottomMargin ?? _bottomMargin)
          .clamp(ReaderMarginSettings.min, ReaderMarginSettings.max);
      _readerThemeId = ReaderThemes.byId(themeId ?? _readerThemeId).id;
      _pageMode = pageMode ?? _pageMode;
      _paginationKey = null;
      _paginatedPages = const [];
      _restorePageProgress = currentProgress;
      _restorePagedPosition = true;
      _restoreTextOffset = currentTextOffset;
    });
    unawaited(_syncVolumeKeyPaging());
    await _readerSettingsStore.save(_readerSettings);
    _restoreScrollProgress(currentProgress);
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
        pageModeSummary: _pageModeHint(_pageMode),
        fontSizeLabel: context.l10n.fontSizeLabel,
        lineHeightLabel: context.l10n.lineSpacingLabel,
        horizontalMarginLabel: context.l10n.readerHorizontalMarginLabel,
        topMarginLabel: context.l10n.readerTopMarginLabel,
        bottomMarginLabel: context.l10n.readerBottomMarginLabel,
        themeId: _readerThemeId,
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        horizontalMargin: _horizontalMargin,
        topMargin: _topMargin,
        bottomMargin: _bottomMargin,
        themeLabelFor: _readerThemeName,
        onThemeChanged: (themeId) => unawaited(
          _updateReadingSettings(themeId: themeId),
        ),
        onPageModeTap: _showPageModeSettings,
        onFontSizeChanged: (value) => unawaited(
          _updateReadingSettings(fontSize: value),
        ),
        onLineHeightChanged: (value) => unawaited(
          _updateReadingSettings(lineHeight: value),
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

  Future<void> _showPageModeSettings() async {
    final selectedMode = await showModalBottomSheet<BookSourcePageMode>(
      context: context,
      backgroundColor: _readerTheme.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (menuContext) => ReaderPageModeSheet(
        palette: _readerTheme,
        title: context.l10n.pageTurningMode,
        selectedMode: _pageMode,
        titleFor: _pageModeTitle,
        hintFor: _pageModeHint,
        onSelected: (mode) => Navigator.of(menuContext).pop(mode),
      ),
    );
    if (selectedMode == null || !mounted) return;
    Navigator.of(context).pop(selectedMode);
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
            backgroundColor: _readerTheme.background,
            body: Stack(
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
                      : _chapters[_chapterIndex.clamp(0, _chapters.length - 1)]
                          .title,
                  statusBottom: _readerSafeArea.pageNumberBottom,
                  statusBuilder: _buildReaderStatusText,
                  onBack: () => unawaited(_requestExit()),
                  onBookmark: _chapters.isEmpty
                      ? null
                      : () => unawaited(_toggleCurrentBookmark()),
                  onTableOfContents: _chapters.isEmpty ? null : _showCatalog,
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
    final chapterTitle =
        content.title.isEmpty ? _chapters[_chapterIndex].title : content.title;
    final text = _readableChapterText(content);
    if (_pageMode == BookSourcePageMode.verticalScroll) {
      return LayoutBuilder(
        builder: (context, constraints) {
          _ensurePagination(
            constraints.biggest,
            chapterTitle: chapterTitle,
            text: text,
          );
          return GestureDetector(
            key: const ValueKey('book-source-reader-surface'),
            behavior: HitTestBehavior.translucent,
            onTap: _toggleControls,
            onHorizontalDragEnd: _handleHorizontalSwipe,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                _horizontalMargin,
                _readerSafeArea.contentTop,
                _horizontalMargin,
                _readerSafeArea.contentBottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChapterTitle(chapterTitle),
                      const SizedBox(height: 26),
                      Text(
                        text,
                        style: _bodyTextStyle,
                        strutStyle: readerStrutStyle(_bodyTextStyle),
                        textHeightBehavior: readerTextHeightBehavior,
                      ),
                      const SizedBox(height: 34),
                      Divider(
                        color: _readerTheme.border.withValues(alpha: 0.48),
                      ),
                      const SizedBox(height: 8),
                      _buildChapterButtons(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _ensurePagination(
          constraints.biggest,
          chapterTitle: chapterTitle,
          text: text,
        );
        return switch (_pageMode) {
          BookSourcePageMode.instantPage => _buildInstantReader(),
          BookSourcePageMode.horizontalSlide => _buildSlideReader(),
          BookSourcePageMode.pageCurl => _buildCurlReader(),
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

  TextStyle get _chapterTitleStyle {
    final base = _readerThemeData.textTheme.headlineSmall;
    return TextStyle(
      inherit: false,
      fontFamily: _readerFont.family,
      fontFamilyFallback: _readerFont.fallbackFamilies.isEmpty
          ? null
          : _readerFont.fallbackFamilies,
      color: _readerTheme.text,
      fontSize: base?.fontSize,
      fontWeight: FontWeight.w700,
      height: 1.35,
    );
  }

  Widget _buildChapterTitle(String title) => Text(
        title,
        style: _chapterTitleStyle,
      );

  Widget _buildChapterButtons() => Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: _chapterIndex > 0
                  ? () => _loadChapter(_chapterIndex - 1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
              label: Text(context.l10n.previous),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: _chapterIndex < _chapters.length - 1
                  ? () => _loadChapter(_chapterIndex + 1)
                  : null,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right_rounded),
              label: Text(context.l10n.next),
            ),
          ),
        ],
      );

  void _ensurePagination(
    Size viewport, {
    required String chapterTitle,
    required String text,
  }) {
    final top = _readerSafeArea.contentTop;
    final bottom = _readerSafeArea.contentBottom;
    final width = (viewport.width - _horizontalMargin * 2).clamp(80.0, 760.0);
    final height = (viewport.height - top - bottom).clamp(120.0, 1600.0);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final titlePainter = TextPainter(
      text: TextSpan(
        text: chapterTitle,
        style: _chapterTitleStyle,
      ),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      locale: locale,
    )..layout(maxWidth: width);
    final firstHeight = (height - titlePainter.height - 26).clamp(44.0, height);
    final key = ReaderLayoutFingerprint(
      contentKey: _chapters[_chapterIndex].id,
      viewport: Size(width, height),
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      horizontalMargin: _horizontalMargin,
      verticalMargin: _topMargin + _bottomMargin,
      textScaler: textScaler,
      locale: locale,
      pageMode: _pageMode,
      extra: '${firstHeight.toStringAsFixed(2)}:'
          '${_readerSafeArea.paginationSignature}:${_readerFont.id}',
    ).cacheKey('book-source-line-v3');
    if (_paginationKey == key && _paginatedPages.isNotEmpty) return;
    final pages = paginateBookSourceText(
      text,
      width: width,
      firstPageHeight: firstHeight,
      pageHeight: height,
      style: _bodyTextStyle,
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      locale: locale,
    );
    _paginationKey = key;
    _paginatedPages = pages;
    _pageCount = pages.length;
    final target = _restoreTextOffset != null
        ? bookSourcePageIndexForOffset(pages, _restoreTextOffset!)
        : _restorePagedPosition
            ? ((_pageCount - 1) * _restorePageProgress).round()
            : _pageIndex.clamp(0, _pageCount - 1);
    _pageIndex = target.clamp(0, _pageCount - 1);
    _restorePagedPosition = false;
    _restoreTextOffset = null;
    final pageProgress =
        _pageCount <= 1 ? 0.0 : (_pageIndex / (_pageCount - 1)).clamp(0.0, 1.0);
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
    int? chapterIndex,
    BookSourceChapterContent? chapterContent,
  }) {
    final resolvedIndex = chapterIndex ?? _chapterIndex;
    final resolvedContent = chapterContent ?? _content!;
    return ColoredBox(
      color: _readerTheme.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _horizontalMargin,
          _readerSafeArea.contentTop,
          _horizontalMargin,
          _readerSafeArea.contentBottom,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (page.showsChapterTitle) ...[
                _buildChapterTitle(
                  resolvedContent.title.isEmpty
                      ? _chapters[resolvedIndex].title
                      : resolvedContent.title,
                ),
                const SizedBox(height: 26),
              ],
              Text(
                page.text,
                style: _bodyTextStyle,
                strutStyle: readerStrutStyle(_bodyTextStyle),
                textHeightBehavior: readerTextHeightBehavior,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildAdjacentPreview(int chapterIndex) {
    final content = _prefetchedContent[chapterIndex];
    if (content == null) return null;
    final title =
        content.title.isEmpty ? _chapters[chapterIndex].title : content.title;
    final text = _readableChapterText(content);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final top = _readerSafeArea.contentTop;
        final bottom = _readerSafeArea.contentBottom;
        final width =
            (viewport.width - _horizontalMargin * 2).clamp(80.0, 760.0);
        final height = (viewport.height - top - bottom).clamp(120.0, 1600.0);
        final scaler = MediaQuery.textScalerOf(context);
        final titlePainter = TextPainter(
          text: TextSpan(
            text: title,
            style: _chapterTitleStyle,
          ),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          locale: Localizations.maybeLocaleOf(context),
        )..layout(maxWidth: width);
        final pages = paginateBookSourceText(
          text,
          width: width,
          firstPageHeight:
              (height - titlePainter.height - 26).clamp(44.0, height),
          pageHeight: height,
          style: _bodyTextStyle,
          textDirection: Directionality.of(context),
          textScaler: scaler,
          locale: Localizations.maybeLocaleOf(context),
        );
        return _buildPageLeaf(
          pages.first,
          chapterIndex: chapterIndex,
          chapterContent: content,
        );
      },
    );
  }

  Widget _buildBoundaryLeaf({required bool forward}) => ColoredBox(
        color: _readerTheme.background,
        child: Center(
          child: Icon(
            forward
                ? Icons.arrow_forward_ios_rounded
                : Icons.arrow_back_ios_new_rounded,
            color: _readerTheme.secondaryText.withValues(alpha: 0.38),
          ),
        ),
      );

  void _handlePageTap(TapUpDetails details, double width) {
    final x = details.localPosition.dx / width;
    if (x < 0.28) {
      unawaited(_turnBackward());
    } else if (x > 0.72) {
      unawaited(_turnForward());
    } else {
      _toggleControls();
    }
  }

  Widget _buildInstantReader() => LayoutBuilder(
        builder: (context, constraints) => Semantics(
          label: _pageModeHint(BookSourcePageMode.instantPage),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _handlePageTap(details, constraints.maxWidth),
            onHorizontalDragEnd: _handlePagedSwipe,
            child: _buildPageLeaf(_paginatedPages[_pageIndex]),
          ),
        ),
      );

  Widget _buildSlideReader() {
    _pageViewLeading = _chapterIndex > 0 ? 1 : 0;
    final trailing = _chapterIndex + 1 < _chapters.length ? 1 : 0;
    return PageView.builder(
      key: ValueKey('source-slide:${_chapters[_chapterIndex].id}'),
      controller: _pageController,
      itemCount: _pageViewLeading + _pageCount + trailing,
      onPageChanged: (viewIndex) {
        if (_ignoreSlidePageChanges) return;
        if (_pageViewLeading == 1 && viewIndex == 0) {
          unawaited(_loadChapter(_chapterIndex - 1, restoreProgress: 1));
          return;
        }
        final page = viewIndex - _pageViewLeading;
        if (page >= _pageCount) {
          unawaited(_loadChapter(_chapterIndex + 1));
          return;
        }
        _setPagedIndex(page);
      },
      itemBuilder: (context, viewIndex) {
        final page = viewIndex - _pageViewLeading;
        if (page < 0) {
          return _buildAdjacentPreview(_chapterIndex - 1) ??
              _buildBoundaryLeaf(forward: false);
        }
        if (page >= _pageCount) {
          return _buildAdjacentPreview(_chapterIndex + 1) ??
              _buildBoundaryLeaf(forward: true);
        }
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) => _handlePageTap(
            details,
            MediaQuery.sizeOf(context).width,
          ),
          child: _buildPageLeaf(_paginatedPages[page]),
        );
      },
    );
  }

  Widget _buildCurlReader() {
    final hasForward =
        _pageIndex + 1 < _pageCount || _chapterIndex + 1 < _chapters.length;
    final hasBackward = _pageIndex > 0 || _chapterIndex > 0;
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (details) {
          final x = details.localPosition.dx / constraints.maxWidth;
          if (x < 0.28 && hasBackward) {
            unawaited(_pageCurlController.turnBackward());
          } else if (x > 0.72 && hasForward) {
            unawaited(_pageCurlController.turnForward());
          } else {
            _toggleControls();
          }
        },
        child: ReaderShaderPageCurl(
          key: ValueKey(
            'source-curl:${_chapters[_chapterIndex].id}:$_pageIndex:'
            '$_paginationKey:$_readerThemeId',
          ),
          controller: _pageCurlController,
          paperColor: _readerTheme.background,
          currentPage: _buildPageLeaf(_paginatedPages[_pageIndex]),
          forwardPage: hasForward
              ? (_pageIndex + 1 < _pageCount
                  ? _buildPageLeaf(_paginatedPages[_pageIndex + 1])
                  : _buildAdjacentPreview(_chapterIndex + 1) ??
                      _buildBoundaryLeaf(forward: true))
              : null,
          backwardPage: hasBackward
              ? (_pageIndex > 0
                  ? _buildPageLeaf(_paginatedPages[_pageIndex - 1])
                  : _buildAdjacentPreview(_chapterIndex - 1) ??
                      _buildBoundaryLeaf(forward: false))
              : null,
          onTurnForward: () => unawaited(_turnForward()),
          onTurnBackward: () => unawaited(_turnBackward()),
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
      builder: (context, progress, _) => Text(
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

String _readableChapterText(BookSourceChapterContent content) {
  final paragraphs = <String>[];
  if (content.contentType == 'text/html') {
    final fragment = html_parser.parseFragment(content.content);

    void visit(dom.Node node) {
      if (node is dom.Element &&
          const {
            'p',
            'div',
            'li',
            'blockquote',
          }.contains(node.localName)) {
        final text = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.isNotEmpty) paragraphs.add(text);
        return;
      }
      for (final child in node.nodes) {
        visit(child);
      }
    }

    for (final node in fragment.nodes) {
      visit(node);
    }
  } else {
    paragraphs.addAll(
      content.content
          .split(RegExp(r'\n+'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty),
    );
  }
  if (paragraphs.isEmpty) return content.content.trim();
  final cleanedParagraphs = removeRepeatedSourcePageMarkers(paragraphs);
  return cleanedParagraphs
      .map((paragraph) => '\u3000\u3000$paragraph')
      .join('\n');
}

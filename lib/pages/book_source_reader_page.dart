import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/core/reader/reader_layout.dart';

import '../book_sources/models/registered_book_source.dart';
import '../book_sources/protocol/book_source_protocol.dart';
import '../book_sources/services/book_source_client.dart';
import '../book_sources/services/book_source_reading_progress.dart';
import '../book_sources/services/book_source_shelf_service.dart';
import '../book_sources/services/book_source_text_paginator.dart';
import '../services/reading/reading_stats_dao.dart';
import '../utils/localization_extension.dart';
import '../utils/reader_themes.dart';
import '../widgets/reader_shader_page_curl.dart';
import '../widgets/reader_control_chrome.dart';
import '../widgets/reader_settings_controls.dart';

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
  static const _fontSizeKey = 'native_reader_font_size';
  static const _lineHeightKey = 'native_reader_line_height';
  static const _horizontalMarginKey = 'native_reader_horizontal_margin';
  static const _verticalMarginKey = 'native_reader_vertical_margin';
  static const _readerThemeKey = 'native_reader_theme';
  static const _pageModeKey = 'native_reader_page_mode';
  static const _remoteLineHeightKey = 'book_source_reader_line_height';

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
  double _horizontalMargin = 22;
  double _verticalMargin = 28;
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
  DateTime? _readingSessionStartedAt;
  int _sessionPagesRead = 0;

  ReaderThemePalette get _readerTheme => ReaderThemes.byId(_readerThemeId);

  ThemeData get _readerThemeData => _readerTheme.toThemeData(
        typography: Theme.of(context).textTheme,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startReadingSession();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
    unawaited(_initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startReadingSession();
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _loadingCatalog = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final results = await Future.wait<Object?>([
        _client.getChapters(widget.source, widget.book.id),
        widget.progressStore.load(
          sourceId: widget.source.id,
          bookId: widget.book.id,
        ),
      ]);
      final chapters = [...results[0]! as List<BookSourceChapter>]
        ..sort((a, b) => a.order.compareTo(b.order));
      final saved = results[1] as BookSourceReadingProgress?;
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
        _fontSize = prefs.getDouble(_fontSizeKey) ?? 19;
        _horizontalMargin =
            (prefs.getDouble(_horizontalMarginKey) ?? 22).clamp(8, 48);
        _verticalMargin =
            (prefs.getDouble(_verticalMarginKey) ?? 28).clamp(28, 48);
        _lineHeight = (prefs.getDouble(_lineHeightKey) ??
                prefs.getDouble(_remoteLineHeightKey) ??
                1.75)
            .clamp(1.4, 2.1);
        _readerThemeId = ReaderThemes.byId(
          prefs.getString(_readerThemeKey),
        ).id;
        _pageMode = _pageModeFromName(prefs.getString(_pageModeKey));
        _loadingCatalog = false;
      });
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
    if (mounted) _shelfBookId = shelfBook?.id;
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
    await _saveProgress();
    await _flushReadingSession();
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

    _exitPromptVisible = true;
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

  Future<void> _showCatalog() async {
    if (_chapters.isEmpty) return;
    _controlsTimer?.cancel();
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Theme(
        data: _readerThemeData,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.76,
            child: ListView.builder(
              itemCount: _chapters.length,
              itemBuilder: (context, index) {
                final isSelected = index == _chapterIndex;
                return ListTile(
                  selected: isSelected,
                  leading: isSelected
                      ? Icon(
                          Icons.play_arrow_rounded,
                          color: _readerTheme.accent,
                        )
                      : Text('${index + 1}'),
                  title: Text(_chapters[index].title),
                  onTap: () => Navigator.pop(context, index),
                );
              },
            ),
          ),
        ),
      ),
    );
    if (selected != null && selected != _chapterIndex) {
      await _loadChapter(selected);
    }
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
    double? verticalMargin,
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
      _verticalMargin = (verticalMargin ?? _verticalMargin).clamp(28, 48);
      _readerThemeId = ReaderThemes.byId(themeId ?? _readerThemeId).id;
      _pageMode = pageMode ?? _pageMode;
      _paginationKey = null;
      _paginatedPages = const [];
      _restorePageProgress = currentProgress;
      _restorePagedPosition = true;
      _restoreTextOffset = currentTextOffset;
    });
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setDouble(_fontSizeKey, _fontSize),
      prefs.setDouble(_lineHeightKey, _lineHeight),
      prefs.setDouble(_horizontalMarginKey, _horizontalMargin),
      prefs.setDouble(_verticalMarginKey, _verticalMargin),
      prefs.setString(_readerThemeKey, _readerThemeId),
      prefs.setString(_pageModeKey, _pageMode.name),
    ]);
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void updateSheet(VoidCallback callback) {
            callback();
            setSheetState(() {});
          }

          return ReaderSettingsSheetFrame(
            palette: _readerTheme,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReaderSettingsDragHandle(palette: _readerTheme),
                const SizedBox(height: 14),
                Text(
                  context.l10n.readingSettings,
                  style: _readerThemeData.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.readerThemeTitle,
                  style: _readerThemeData.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.readerThemeDescription,
                  style: _readerThemeData.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ReaderThemeStrip(
                  selectedThemeId: _readerThemeId,
                  labelFor: _readerThemeName,
                  onSelected: (themeId) => updateSheet(
                    () => unawaited(
                      _updateReadingSettings(themeId: themeId),
                    ),
                  ),
                ),
                const Divider(height: 28),
                Text(
                  context.l10n.pageTurningMode,
                  style: _readerThemeData.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                RadioGroup<BookSourcePageMode>(
                  groupValue: _pageMode,
                  onChanged: (mode) {
                    if (mode == null) return;
                    updateSheet(
                      () => unawaited(
                        _updateReadingSettings(pageMode: mode),
                      ),
                    );
                  },
                  child: Column(
                    children: BookSourcePageMode.values
                        .map(
                          (mode) => RadioListTile<BookSourcePageMode>(
                            value: mode,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(_pageModeTitle(mode)),
                            subtitle: Text(_pageModeHint(mode)),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 10),
                _buildSettingSlider(
                  label: context.l10n.fontSizeLabel,
                  value: _fontSize,
                  min: 15,
                  max: 30,
                  divisions: 15,
                  valueLabel: _fontSize.round().toString(),
                  onChanged: (value) => updateSheet(
                    () => unawaited(
                      _updateReadingSettings(fontSize: value),
                    ),
                  ),
                ),
                _buildSettingSlider(
                  label: context.l10n.lineSpacingLabel,
                  value: _lineHeight,
                  min: 1.4,
                  max: 2.1,
                  divisions: 7,
                  valueLabel: _lineHeight.toStringAsFixed(1),
                  onChanged: (value) => updateSheet(
                    () => unawaited(
                      _updateReadingSettings(lineHeight: value),
                    ),
                  ),
                ),
                _buildSettingSlider(
                  label: context.l10n.readerHorizontalMarginLabel,
                  value: _horizontalMargin,
                  min: 8,
                  max: 48,
                  divisions: 40,
                  valueLabel: _horizontalMargin.round().toString(),
                  onChanged: (value) => updateSheet(
                    () => unawaited(
                      _updateReadingSettings(horizontalMargin: value),
                    ),
                  ),
                ),
                _buildSettingSlider(
                  label: context.l10n.readerVerticalMarginLabel,
                  value: _verticalMargin,
                  min: 28,
                  max: 48,
                  divisions: 20,
                  valueLabel: _verticalMargin.round().toString(),
                  onChanged: (value) => updateSheet(
                    () => unawaited(
                      _updateReadingSettings(verticalMargin: value),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (mounted) setState(() => _controlsVisible = false);
  }

  Widget _buildSettingSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return ReaderSettingSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      valueLabel: valueLabel,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
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
              if (_chapters.isNotEmpty && _content != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.viewPaddingOf(context).bottom + 3,
                  child: IgnorePointer(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _scrollProgress,
                      builder: (context, progress, _) => Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _readerTheme.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Text(
                              _readerStatus(),
                              key: const ValueKey(
                                'book-source-reader-status',
                              ),
                              textAlign: TextAlign.center,
                              style: _readerThemeData.textTheme.labelSmall
                                  ?.copyWith(
                                fontSize: 10,
                                height: 1,
                                color: _readerThemeData
                                    .colorScheme.onSurfaceVariant
                                    .withValues(
                                  alpha: _controlsVisible ? 0 : 0.58,
                                ),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              _buildTopControls(),
              _buildBottomControls(),
            ],
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
                MediaQuery.viewPaddingOf(context).top + _verticalMargin,
                _horizontalMargin,
                MediaQuery.viewPaddingOf(context).bottom + _verticalMargin,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChapterTitle(chapterTitle),
                      const SizedBox(height: 26),
                      Text(text, style: _bodyTextStyle),
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

  TextStyle get _bodyTextStyle =>
      _readerThemeData.textTheme.bodyLarge?.copyWith(
        fontFamily: 'SourceHanSansCN',
        color: _readerTheme.text,
        fontSize: _fontSize,
        height: _lineHeight,
        letterSpacing: 0.2,
      ) ??
      TextStyle(
        color: _readerTheme.text,
        fontSize: _fontSize,
        height: _lineHeight,
      );

  Widget _buildChapterTitle(String title) => Text(
        title,
        style: _readerThemeData.textTheme.headlineSmall?.copyWith(
          color: _readerTheme.text,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
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
    final top = MediaQuery.viewPaddingOf(context).top + _verticalMargin;
    final bottom = MediaQuery.viewPaddingOf(context).bottom + _verticalMargin;
    final width = (viewport.width - _horizontalMargin * 2).clamp(80.0, 760.0);
    final height = (viewport.height - top - bottom).clamp(120.0, 1600.0);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final titlePainter = TextPainter(
      text: TextSpan(
        text: chapterTitle,
        style: _readerThemeData.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
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
      verticalMargin: _verticalMargin,
      textScaler: textScaler,
      locale: locale,
      pageMode: _pageMode,
      extra: firstHeight.toStringAsFixed(2),
    ).cacheKey('book-source-line-v2');
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
          MediaQuery.viewPaddingOf(context).top + _verticalMargin,
          _horizontalMargin,
          MediaQuery.viewPaddingOf(context).bottom + _verticalMargin,
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
              Text(page.text, style: _bodyTextStyle),
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
        final top = MediaQuery.viewPaddingOf(context).top + _verticalMargin;
        final bottom =
            MediaQuery.viewPaddingOf(context).bottom + _verticalMargin;
        final width =
            (viewport.width - _horizontalMargin * 2).clamp(80.0, 760.0);
        final height = (viewport.height - top - bottom).clamp(120.0, 1600.0);
        final scaler = MediaQuery.textScalerOf(context);
        final titlePainter = TextPainter(
          text: TextSpan(
            text: title,
            style: _readerThemeData.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
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

  Widget _buildTopControls() {
    final title = _chapters.isEmpty
        ? widget.book.title
        : _chapters[_chapterIndex.clamp(0, _chapters.length - 1)].title;
    return AnimatedPositioned(
      key: const ValueKey('book-source-top-controls'),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      left: 20,
      right: 20,
      top: _controlsVisible ? 10 : -130,
      child: SafeArea(
        bottom: false,
        child: _buildReaderBar(
          isTopBar: true,
          child: SizedBox(
            height: 58,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
              child: Row(
                children: [
                  _readerIconButton(
                    onPressed: _requestExit,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    icon: Icons.arrow_back_rounded,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _readerThemeData.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 54),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return AnimatedPositioned(
      key: const ValueKey('book-source-bottom-controls'),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      left: 22,
      right: 22,
      bottom: _controlsVisible ? 16 : -110,
      child: SafeArea(
        top: false,
        child: _buildReaderBar(
          isTopBar: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
              child: Row(
                children: [
                  _readerIconButton(
                    onPressed: _chapters.isEmpty ? null : _showCatalog,
                    tooltip: context.l10n.readerToolbarTOC,
                    icon: Icons.format_list_bulleted_rounded,
                  ),
                  Expanded(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _scrollProgress,
                      builder: (context, progress, _) => Text(
                        _chapters.isEmpty ? widget.book.title : _readerStatus(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _readerThemeData.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ),
                  ),
                  _readerIconButton(
                    onPressed: _showReadingSettings,
                    tooltip: context.l10n.readingSettings,
                    icon: Icons.tune_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReaderBar({
    required Widget child,
    required bool isTopBar,
  }) =>
      ReaderControlBar(
        palette: _readerTheme,
        isTopBar: isTopBar,
        child: child,
      );

  Widget _readerIconButton({
    required VoidCallback? onPressed,
    required String tooltip,
    required IconData icon,
  }) {
    return ReaderControlIconButton(
      palette: _readerTheme,
      onPressed: onPressed,
      tooltip: tooltip,
      icon: icon,
    );
  }
}

BookSourcePageMode _pageModeFromName(String? name) => readerPageModeFromName(
      name,
      fallback: BookSourcePageMode.verticalScroll,
    );

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

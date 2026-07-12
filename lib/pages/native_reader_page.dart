import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/core/reader/canonical_locator.dart';
import 'package:xxread/core/reader/native_text_paginator.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/enhanced_txt_import_service.dart';

import '../utils/localization_extension.dart';
import '../utils/glass_config.dart';
import '../utils/reader_themes.dart';
import '../widgets/reader_shader_page_curl.dart';

enum NativePageMode { verticalScroll, instantPage, horizontalSlide, pageCurl }

const int _largeTxtFileThreshold = 16 * 1024 * 1024;
const double _imagePageGap = 10;
const int _imagePageImageFlex = 5;
const int _imagePageTextFlex = 6;

class NativeReaderPage extends StatefulWidget {
  const NativeReaderPage({super.key, required this.book});

  final Book book;

  @override
  State<NativeReaderPage> createState() => _NativeReaderPageState();
}

class _NativeReaderPageState extends State<NativeReaderPage> {
  static final Map<String, Future<List<_NativeChapter>>> _bookMemoryCache = {};
  static final Map<String, Map<String, List<_ReaderPageData>>>
      _paginationMemoryCache = {};
  static const _pageModeKey = 'native_reader_page_mode';
  static const _scrollByChapterKey = 'native_reader_scroll_by_chapter';
  static const _fontSizeKey = 'native_reader_font_size';
  static const _horizontalMarginKey = 'native_reader_horizontal_margin';
  static const _verticalMarginKey = 'native_reader_vertical_margin';
  static const _readerThemeKey = 'native_reader_theme';
  static const _pageNumberReserve = 16.0;
  static const _tabletShortestSide = 600.0;
  static const _twoPageMinimumWidth = 720.0;
  static const _spreadGutter = 24.0;
  static const _textStyle = TextStyle(
    fontSize: 19,
    height: 1.75,
    letterSpacing: 0.2,
  );

  late final Future<List<_NativeChapter>> _chaptersFuture;
  final PageController _pageController = PageController();
  final ReaderPageCurlController _pageCurlController =
      ReaderPageCurlController();
  final Map<int, GlobalKey> _continuousChapterKeys = {};
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
  NativePageMode _pageMode = NativePageMode.horizontalSlide;
  bool _scrollByChapter = true;
  int _continuousAnchorChapter = 0;
  Key _continuousCenterKey = GlobalKey();
  bool _continuousVisibilityUpdateScheduled = false;
  double _fontSize = 19;
  double _horizontalMargin = 18;
  double _verticalMargin = 28;
  String _readerThemeId = ReaderThemes.day.id;
  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;
  bool _pointerMoved = false;
  bool _readerSettingsLoaded = false;
  bool _readerSystemUiApplied = false;

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.book.currentPage;
    _continuousAnchorChapter = _chapterIndex;
    _horizontalFirstChapter = (_chapterIndex - 1).clamp(0, _chapterIndex);
    _horizontalLastChapter = _chapterIndex + 1;
    final savedLocator = widget.book.toCanonicalLocator();
    _anchorOffset = savedLocator?.textAnchor?.startOffsetUtf16;
    unawaited(_loadPageMode());
    // Let the route paint its opaque first frame before Android changes the
    // window insets. Applying immersive mode synchronously in initState made
    // tablets visibly relayout underneath the opening transition.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _readerSystemUiApplied) return;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (!mounted) return;
      setState(() => _readerSystemUiApplied = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  String get _bookCacheKey =>
      '${widget.book.format.toLowerCase() == 'txt' ? 'txt-parser-v4:' : ''}'
      '${widget.book.contentHash ?? widget.book.filePath}:'
      '${widget.book.fileModifiedTime ?? File(widget.book.filePath).lastModifiedSync().millisecondsSinceEpoch}:'
      '${widget.book.textEncoding ?? 'auto'}';

  bool get _isLargeTxtBook {
    if (widget.book.format.toLowerCase() != 'txt') return false;
    try {
      return File(widget.book.filePath).lengthSync() > _largeTxtFileThreshold;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadPageMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_pageModeKey);
      if (!mounted) return;
      setState(() {
        if (name != null) {
          _pageMode = NativePageMode.values.firstWhere(
            (mode) => mode.name == name,
            orElse: () => name == 'horizontalPage'
                ? NativePageMode.instantPage
                : NativePageMode.horizontalSlide,
          );
        }
        _fontSize = prefs.getDouble(_fontSizeKey) ?? 19;
        _horizontalMargin = prefs.getDouble(_horizontalMarginKey) ?? 18;
        _verticalMargin =
            (prefs.getDouble(_verticalMarginKey) ?? 28).clamp(28, 48);
        _scrollByChapter = prefs.getBool(_scrollByChapterKey) ?? true;
        _readerThemeId = ReaderThemes.byId(
          prefs.getString(_readerThemeKey),
        ).id;
        _readerSettingsLoaded = true;
      });
    } catch (error, stackTrace) {
      debugPrint('Reader settings failed to load: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _readerSettingsLoaded = true);
    }
  }

  ReaderThemePalette get _readerTheme => ReaderThemes.byId(_readerThemeId);

  ThemeData get _readerThemeData => _readerTheme.toThemeData(
        typography: Theme.of(context).textTheme,
      );

  TextStyle get _readerTextStyle =>
      (_readerThemeData.textTheme.bodyMedium ?? const TextStyle()).merge(
        _textStyle.copyWith(
          fontSize: _fontSize,
          color: _readerTheme.text,
        ),
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
      strutStyle: StrutStyle.fromTextStyle(style),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: true,
        applyHeightToLastDescent: true,
        leadingDistribution: TextLeadingDistribution.proportional,
      ),
    );
  }

  Future<void> _setReaderTheme(String themeId) async {
    final nextTheme = ReaderThemes.byId(themeId);
    if (_readerThemeId == nextTheme.id) return;
    setState(() => _readerThemeId = nextTheme.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readerThemeKey, nextTheme.id);
  }

  Widget _buildStyledReaderText(
    _NativeChapter chapter,
    int start,
    int end,
  ) {
    final flowStyle = _readerTextFlowStyle();
    return RichText(
      text: _styledSpanForRange(chapter, start, end, _readerTextStyle),
      textAlign: flowStyle.textAlign,
      textDirection: flowStyle.textDirection,
      textScaler: flowStyle.textScaler,
      locale: flowStyle.locale,
      strutStyle: flowStyle.strutStyle,
      textWidthBasis: flowStyle.textWidthBasis,
      textHeightBehavior: flowStyle.textHeightBehavior,
    );
  }

  double get _readerBottomMargin => (_verticalMargin - 14).clamp(4, 34);

  double get _effectiveBottomMargin =>
      _readerBottomMargin +
      MediaQuery.viewPaddingOf(context).bottom +
      _pageNumberReserve;

  bool _usesTwoPageLayout(Size size) =>
      _pageMode != NativePageMode.verticalScroll &&
      _pageMode != NativePageMode.pageCurl &&
      size.shortestSide >= _tabletShortestSide &&
      size.width >= _twoPageMinimumWidth;

  Size _paginationSize(Size viewport, bool usesTwoPageLayout) {
    if (!usesTwoPageLayout) return viewport;
    return Size(
      (viewport.width - _spreadGutter) / 2,
      viewport.height,
    );
  }

  int _spreadStartForPage(int pageIndex) => (pageIndex ~/ 2) * 2;

  Future<void> _updateLayout({
    double? fontSize,
    double? horizontalMargin,
    double? verticalMargin,
  }) async {
    setState(() {
      _fontSize = fontSize ?? _fontSize;
      _horizontalMargin = horizontalMargin ?? _horizontalMargin;
      _verticalMargin = (verticalMargin ?? _verticalMargin).clamp(28, 48);
      _pageIndex = 0;
      _restoreAnchorAfterLayout = true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, _fontSize);
    await prefs.setDouble(_horizontalMarginKey, _horizontalMargin);
    await prefs.setDouble(_verticalMarginKey, _verticalMargin);
  }

  String get _layoutSignature => '${_fontSize.toStringAsFixed(1)}:'
      '${_horizontalMargin.toStringAsFixed(1)}:'
      '${_verticalMargin.toStringAsFixed(1)}:${_pageMode.name}';

  void _saveCanonicalProgress(
    _NativeChapter chapter,
    _ReaderPageData page,
    int chapterIndex,
  ) {
    _anchorOffset = page.startOffset;
    final bookId = widget.book.id;
    if (bookId == null) return;
    final excerptEnd =
        (page.startOffset + 72).clamp(0, chapter.plainText.length);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pageModeKey, mode.name);
  }

  Future<void> _setScrollByChapter(bool value) async {
    if (_scrollByChapter == value) return;
    setState(() {
      _scrollByChapter = value;
      _continuousAnchorChapter = _chapterIndex;
      _continuousCenterKey = GlobalKey();
      _controlsVisible = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scrollByChapterKey, value);
  }

  Future<List<_NativeChapter>> _loadBook() async {
    final l10n = context.l10n;
    final format = widget.book.format.toLowerCase();
    if (format == 'txt') {
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
      final parsed = await compute(
        _parseTxtFileInBackground,
        parseArguments,
      );
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

    final bytes = await File(widget.book.filePath).readAsBytes();
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
      if (recenterContinuousScroll && !_scrollByChapter) {
        _continuousAnchorChapter = next;
        _continuousCenterKey = GlobalKey();
      }
    });
    final bookId = widget.book.id;
    if (bookId != null) {
      await BookDao().updateBookProgress(bookId, next);
    }
  }

  void _nextPage(
    List<_ReaderPageData> pages,
    int chapterCount, {
    required bool usesTwoPageLayout,
  }) {
    if (_pageMode == NativePageMode.pageCurl) {
      unawaited(_pageCurlController.turnForward());
      return;
    }
    if (_pageMode == NativePageMode.horizontalSlide &&
        _pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final pageStep = usesTwoPageLayout ? 2 : 1;
    if (_pageIndex + pageStep < pages.length) {
      setState(() => _pageIndex += pageStep);
    } else if (_chapterIndex < chapterCount - 1) {
      _setChapter(_chapterIndex + 1, chapterCount);
    }
  }

  void _previousPage(
    List<_ReaderPageData> pages,
    int chapterCount, {
    required bool usesTwoPageLayout,
  }) {
    if (_pageMode == NativePageMode.pageCurl) {
      unawaited(_pageCurlController.turnBackward());
      return;
    }
    if (_pageMode == NativePageMode.horizontalSlide &&
        _pageController.hasClients) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
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
        _nextPage(
          pages,
          chapterCount,
          usesTwoPageLayout: usesTwoPageLayout,
        );
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
    if (fraction >= 1 / 3 && fraction <= 2 / 3) {
      setState(() => _controlsVisible = !_controlsVisible);
      return;
    }
    if (_pageMode == NativePageMode.verticalScroll) return;
    if (fraction < 1 / 3) {
      _previousPage(
        pages,
        chapterCount,
        usesTwoPageLayout: usesTwoPageLayout,
      );
    } else {
      _nextPage(
        pages,
        chapterCount,
        usesTwoPageLayout: usesTwoPageLayout,
      );
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.localPosition;
    _pointerDownTime = DateTime.now();
    _pointerMoved = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _pointerDownPosition;
    if (start != null && (event.localPosition - start).distance > 14) {
      _pointerMoved = true;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerDownPosition = null;
    _pointerDownTime = null;
    _pointerMoved = false;
  }

  void _onPointerUp(
    PointerUpEvent event,
    double width,
    List<_ReaderPageData> pages,
    int chapterCount,
    bool usesTwoPageLayout,
  ) {
    final startedAt = _pointerDownTime;
    final isQuickTap = startedAt != null &&
        DateTime.now().difference(startedAt) <
            const Duration(milliseconds: 500);
    if (!_pointerMoved && isQuickTap) {
      _handleTap(
        event.localPosition,
        width,
        pages,
        chapterCount,
        usesTwoPageLayout,
      );
    }
    _pointerDownPosition = null;
    _pointerDownTime = null;
    _pointerMoved = false;
  }

  String _readerThemeName(BuildContext context, String themeId) {
    switch (themeId) {
      case 'night':
        return context.l10n.readerThemeNight;
      case 'parchment':
        return context.l10n.readerThemeParchment;
      default:
        return context.l10n.readerThemeDay;
    }
  }

  Widget _buildReaderThemeOption({
    required BuildContext context,
    required ReaderThemePalette palette,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final label = _readerThemeName(context, palette.id);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? palette.accent : palette.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: palette.shadow.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: palette.controlBar,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.border),
                      ),
                      child: selected
                          ? Icon(Icons.check, size: 15, color: palette.text)
                          : null,
                    ),
                    const Spacer(),
                    Icon(
                      palette.id == 'night'
                          ? Icons.dark_mode_outlined
                          : palette.id == 'parchment'
                              ? Icons.auto_stories_outlined
                              : Icons.light_mode_outlined,
                      size: 18,
                      color: palette.text,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  'Aa',
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReadingSettings() async {
    var previewFontSize = _fontSize;
    var previewHorizontalMargin = _horizontalMargin;
    var previewVerticalMargin = _verticalMargin;
    var previewThemeId = _readerThemeId;
    final selectedMode = await showModalBottomSheet<NativePageMode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Theme(
          data: ReaderThemes.byId(previewThemeId).toThemeData(
            typography: Theme.of(context).textTheme,
          ),
          child: Material(
            color: ReaderThemes.byId(previewThemeId).surface,
            surfaceTintColor: Colors.transparent,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ReaderThemes.byId(previewThemeId)
                              .secondaryText
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(context.l10n.readingSettings,
                        style: _readerThemeData.textTheme.titleLarge),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var index = 0;
                            index < ReaderThemes.all.length;
                            index++) ...[
                          if (index > 0) const SizedBox(width: 8),
                          _buildReaderThemeOption(
                            context: context,
                            palette: ReaderThemes.all[index],
                            selected:
                                ReaderThemes.all[index].id == previewThemeId,
                            onTap: () {
                              final nextId = ReaderThemes.all[index].id;
                              setSheetState(() => previewThemeId = nextId);
                              _setReaderTheme(nextId);
                            },
                          ),
                        ],
                      ],
                    ),
                    const Divider(height: 28),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.swap_calls),
                      title: Text(context.l10n.pageTurningMode),
                      subtitle: Text(_pageModeSummary(context)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showPageModeSettings,
                    ),
                    const Divider(height: 28),
                    Text(
                        context.l10n
                            .readerFontSizeValue(previewFontSize.round()),
                        style: _readerThemeData.textTheme.titleMedium),
                    Slider(
                      value: previewFontSize,
                      min: 14,
                      max: 32,
                      divisions: 18,
                      onChanged: (value) =>
                          setSheetState(() => previewFontSize = value),
                      onChangeEnd: (value) => _updateLayout(fontSize: value),
                    ),
                    Text(
                        context.l10n.readerHorizontalMarginValue(
                            previewHorizontalMargin.round()),
                        style: _readerThemeData.textTheme.titleMedium),
                    Slider(
                      value: previewHorizontalMargin,
                      min: 8,
                      max: 48,
                      divisions: 40,
                      onChanged: (value) =>
                          setSheetState(() => previewHorizontalMargin = value),
                      onChangeEnd: (value) =>
                          _updateLayout(horizontalMargin: value),
                    ),
                    Text(
                        context.l10n.readerVerticalMarginValue(
                            previewVerticalMargin.round()),
                        style: _readerThemeData.textTheme.titleMedium),
                    Slider(
                      value: previewVerticalMargin,
                      min: 28,
                      max: 48,
                      divisions: 20,
                      onChanged: (value) =>
                          setSheetState(() => previewVerticalMargin = value),
                      onChangeEnd: (value) =>
                          _updateLayout(verticalMargin: value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (selectedMode == null || !mounted) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _setPageMode(selectedMode);
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
        builder: (context, setMenuState) => Theme(
          data: _readerThemeData,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.pageTurningMode,
                    style: _readerThemeData.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<NativePageMode>(
                    groupValue: _pageMode,
                    onChanged: (mode) {
                      if (mode == null) return;
                      Navigator.of(menuContext).pop(mode);
                    },
                    child: Column(
                      children: [
                        RadioListTile<NativePageMode>(
                          value: NativePageMode.verticalScroll,
                          title: Text(context.l10n.pageTurningScroll),
                          subtitle: Text(previewScrollByChapter
                              ? context.l10n.readerModeVerticalScrollHint
                              : context.l10n.readerModeWholeBookScrollHint),
                        ),
                        if (_pageMode == NativePageMode.verticalScroll)
                          SwitchListTile(
                            contentPadding: const EdgeInsets.only(left: 24),
                            value: previewScrollByChapter,
                            title:
                                Text(context.l10n.readerScrollByChapterTitle),
                            subtitle: Text(previewScrollByChapter
                                ? context.l10n.readerScrollByChapterOnHint
                                : context.l10n.readerScrollByChapterOffHint),
                            onChanged: (value) {
                              setMenuState(
                                  () => previewScrollByChapter = value);
                              _setScrollByChapter(value);
                            },
                          ),
                        RadioListTile<NativePageMode>(
                          value: NativePageMode.instantPage,
                          title: Text(context.l10n.readerModeHorizontalPage),
                          subtitle:
                              Text(context.l10n.readerModeHorizontalPageHint),
                        ),
                        RadioListTile<NativePageMode>(
                          value: NativePageMode.horizontalSlide,
                          title: Text(context.l10n.pageTurningSlide),
                          subtitle:
                              Text(context.l10n.readerModeHorizontalSlideHint),
                        ),
                        RadioListTile<NativePageMode>(
                          value: NativePageMode.pageCurl,
                          title: Text(context.l10n.readerModePageCurl),
                          subtitle: Text(context.l10n.readerModePageCurlHint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (selectedMode == null || !mounted) return;
    Navigator.of(context).pop(selectedMode);
  }

  void _showTableOfContents(List<_NativeChapter> chapters) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _readerTheme.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Theme(
        data: _readerThemeData,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Text(context.l10n.readerToolbarTOC,
                          style: _readerThemeData.textTheme.titleLarge),
                      const Spacer(),
                      Text(context.l10n.readerChapterCount(chapters.length)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      return ListTile(
                        selected: index == _chapterIndex,
                        contentPadding: EdgeInsets.only(
                          left: 20 + chapter.depth * 18,
                          right: 16,
                        ),
                        title: Text(
                          chapter.title.isEmpty
                              ? context.l10n.readerChapterFallback(index + 1)
                              : chapter.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _setChapter(
                            index,
                            chapters.length,
                            recenterContinuousScroll: true,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
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
    final scaleKey = textScaler.scale(100).round();
    final localeKey = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final key = 'line-v1:${_pageMode.name}:$chapterIndex:'
        '${size.width.round()}:${size.height.round()}:'
        '$scaleKey:$localeKey:${_fontSize.toStringAsFixed(1)}:'
        '${_horizontalMargin.toStringAsFixed(1)}:'
        '${_verticalMargin.toStringAsFixed(1)}:'
        '${_effectiveBottomMargin.toStringAsFixed(1)}';
    if (!_pageCache.containsKey(key) && _pageCache.length >= 96) {
      _pageCache.remove(_pageCache.keys.first);
    }
    return _pageCache.putIfAbsent(
      key,
      () {
        return _paginateChapter(
          chapter,
          maxWidth: size.width - (_horizontalMargin * 2),
          maxHeight: size.height - _verticalMargin - _effectiveBottomMargin,
          flowStyle: _readerTextFlowStyle(
            direction: direction,
            textScaler: textScaler,
          ),
          style: _readerTextStyle,
        );
      },
    );
  }

  Widget _buildPage(_NativeChapter chapter, _ReaderPageData page) {
    final imageIndex = page.imageBlockIndex;
    if (imageIndex == null) {
      return _buildStyledReaderText(
        chapter,
        page.startOffset,
        page.endOffset,
      );
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
            child: _buildStyledReaderText(
              chapter,
              page.startOffset,
              page.endOffset,
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
    TextScaler textScaler,
  ) {
    final result = <_BookPageRef>[];
    final safeFirst = firstChapter.clamp(0, chapters.length - 1);
    final safeLast = lastChapter.clamp(safeFirst, chapters.length - 1);
    for (var chapterIndex = safeFirst;
        chapterIndex <= safeLast;
        chapterIndex++) {
      final chapterPages = _pagesFor(
        chapters[chapterIndex],
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
            content: chapterPages[pageIndex],
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
    final chapterChanged = page.chapterIndex != _chapterIndex;
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
      final imageIndex = page.content.imageBlockIndex;
      if (imageIndex == null) continue;
      final bytes = chapters[page.chapterIndex].blocks[imageIndex].imageBytes;
      if (bytes != null) images.add(bytes);
    }
    await Future.wait(
      images.map(
        (bytes) => precacheImage(MemoryImage(bytes), context),
      ),
    );
  }

  Widget _buildScrollableChapterBlocks(_NativeChapter chapter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: chapter.blocks.map((block) {
        final imageBytes = block.imageBytes;
        if (imageBytes != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RichText(
            text: TextSpan(
              text: block.text ?? '',
              style: _styleForNativeBlock(block, _readerTextStyle),
            ),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildContinuousChapter(
    List<_NativeChapter> chapters,
    int chapterIndex,
  ) {
    final chapter = chapters[chapterIndex];
    final chapterKey = _continuousChapterKeys.putIfAbsent(
      chapterIndex,
      GlobalKey.new,
    );
    return KeyedSubtree(
      key: chapterKey,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _horizontalMargin,
          chapterIndex == 0 ? _verticalMargin : 28,
          _horizontalMargin,
          chapterIndex == chapters.length - 1 ? _effectiveBottomMargin : 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              chapter.title.isEmpty
                  ? context.l10n.readerChapterFallback(chapterIndex + 1)
                  : chapter.title,
              style: _readerThemeData.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _buildScrollableChapterBlocks(chapter),
            if (chapterIndex < chapters.length - 1) ...[
              const SizedBox(height: 18),
              const Divider(),
            ],
          ],
        ),
      ),
    );
  }

  bool _handleContinuousScrollNotification(
    ScrollNotification notification,
    List<_NativeChapter> chapters,
  ) {
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    if (_continuousVisibilityUpdateScheduled) return false;
    _continuousVisibilityUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _continuousVisibilityUpdateScheduled = false;
      if (!mounted ||
          _scrollByChapter ||
          _pageMode != NativePageMode.verticalScroll) {
        return;
      }
      final targetY = MediaQuery.sizeOf(context).height * 0.28;
      int? visibleChapter;
      var nearestDistance = double.infinity;
      for (final entry in _continuousChapterKeys.entries) {
        final renderObject = entry.value.currentContext?.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.attached) continue;
        final top = renderObject.localToGlobal(Offset.zero).dy;
        final bottom = top + renderObject.size.height;
        if (top <= targetY && bottom > targetY) {
          visibleChapter = entry.key;
          break;
        }
        final distance = (top - targetY).abs();
        if (bottom > 0 &&
            top < MediaQuery.sizeOf(context).height &&
            distance < nearestDistance) {
          nearestDistance = distance;
          visibleChapter = entry.key;
        }
      }
      if (visibleChapter == null || visibleChapter == _chapterIndex) return;
      final nextChapter = visibleChapter;
      setState(() {
        _chapterIndex = nextChapter;
        _pageIndex = 0;
      });
      final bookId = widget.book.id;
      if (bookId != null) {
        BookDao().updateBookProgress(bookId, nextChapter);
      }
      _saveCanonicalProgress(
        chapters[nextChapter],
        const _ReaderPageData(text: '', startOffset: 0),
        nextChapter,
      );
    });
    return false;
  }

  Widget _buildContinuousBook(List<_NativeChapter> chapters) {
    final anchor = _continuousAnchorChapter.clamp(0, chapters.length - 1);
    return SelectionArea(
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) =>
            _handleContinuousScrollNotification(notification, chapters),
        child: CustomScrollView(
          center: _continuousCenterKey,
          slivers: [
            if (anchor > 0)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildContinuousChapter(chapters, index),
                  childCount: anchor,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                ),
              ),
            SliverList(
              key: _continuousCenterKey,
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final chapterIndex = anchor + index;
                  return _buildContinuousChapter(chapters, chapterIndex);
                },
                childCount: chapters.length - anchor,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderContent(
    List<_NativeChapter> chapters,
    _NativeChapter chapter,
    List<_ReaderPageData> pages,
    List<_BookPageRef> bookPages,
    bool usesTwoPageLayout,
  ) {
    if (_pageMode == NativePageMode.verticalScroll) {
      if (!_scrollByChapter) {
        return _buildContinuousBook(chapters);
      }
      return SelectionArea(
        child: SingleChildScrollView(
          key: ValueKey(_chapterIndex),
          padding: EdgeInsets.fromLTRB(
            _horizontalMargin,
            _verticalMargin,
            _horizontalMargin,
            _effectiveBottomMargin,
          ),
          child: _buildScrollableChapterBlocks(chapter),
        ),
      );
    }
    if (_pageMode == NativePageMode.horizontalSlide) {
      return PageView.builder(
        controller: _pageController,
        itemCount:
            usesTwoPageLayout ? (bookPages.length + 1) ~/ 2 : bookPages.length,
        onPageChanged: (index) => _onBookPageChanged(
          usesTwoPageLayout ? index * 2 : index,
          bookPages,
          chapters,
        ),
        itemBuilder: (context, index) {
          if (!usesTwoPageLayout) {
            final page = bookPages[index];
            return _buildPageLeaf(
              chapters[page.chapterIndex],
              page.content,
            );
          }
          final firstIndex = index * 2;
          return _buildSpread(
            left: _buildBookPageLeaf(
              chapters,
              bookPages[firstIndex],
            ),
            right: firstIndex + 1 < bookPages.length
                ? _buildBookPageLeaf(
                    chapters,
                    bookPages[firstIndex + 1],
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
        return _buildPageLeaf(chapter, pages[_pageIndex]);
      }
      final current = bookPages[currentIndex];
      final forward = currentIndex + 1 < bookPages.length
          ? bookPages[currentIndex + 1]
          : null;
      final backward = currentIndex > 0 ? bookPages[currentIndex - 1] : null;
      return ReaderShaderPageCurl(
        key: ValueKey(
          'shader-curl:$_readerThemeId:${_fontSize.toStringAsFixed(1)}:'
          '${_horizontalMargin.toStringAsFixed(1)}:'
          '${_verticalMargin.toStringAsFixed(1)}:'
          '${current.chapterIndex}:${current.pageIndex}',
        ),
        controller: _pageCurlController,
        currentPage: _buildBookPageLeaf(
          chapters,
          current,
        ),
        forwardPage: forward != null
            ? _buildBookPageLeaf(
                chapters,
                forward,
              )
            : null,
        backwardPage: backward != null
            ? _buildBookPageLeaf(
                chapters,
                backward,
              )
            : null,
        preparePages: () => _precacheBookPageImages(
          context,
          chapters,
          [
            current,
            if (forward != null) forward,
            if (backward != null) backward
          ],
        ),
        onTurnForward: () => _onBookPageChanged(
          currentIndex + 1,
          bookPages,
          chapters,
        ),
        onTurnBackward: () => _onBookPageChanged(
          currentIndex - 1,
          bookPages,
          chapters,
        ),
        paperColor: _readerTheme.surface,
      );
    }
    if (usesTwoPageLayout) {
      final spreadStart = _spreadStartForPage(_pageIndex);
      return _buildSpread(
        left: _buildPageLeaf(
          chapter,
          pages[spreadStart],
          pageNumber: spreadStart + 1,
          pageCount: pages.length,
        ),
        right: spreadStart + 1 < pages.length
            ? _buildPageLeaf(
                chapter,
                pages[spreadStart + 1],
                pageNumber: spreadStart + 2,
                pageCount: pages.length,
              )
            : null,
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalMargin,
        _verticalMargin,
        _horizontalMargin,
        _effectiveBottomMargin,
      ),
      child: SizedBox.expand(
        child: KeyedSubtree(
          key: ValueKey('$_chapterIndex:$_pageIndex'),
          child: _buildPage(chapter, pages[_pageIndex]),
        ),
      ),
    );
  }

  Widget _buildBookPageLeaf(
    List<_NativeChapter> chapters,
    _BookPageRef page,
  ) =>
      _buildPageLeaf(
        chapters[page.chapterIndex],
        page.content,
        pageNumber: page.pageIndex + 1,
        pageCount: page.pageCount,
      );

  Widget _buildPageLeaf(
    _NativeChapter chapter,
    _ReaderPageData page, {
    int? pageNumber,
    int? pageCount,
  }) {
    final colors = _readerThemeData.colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _horizontalMargin,
              _verticalMargin,
              _horizontalMargin,
              _effectiveBottomMargin,
            ),
            child: SizedBox.expand(
              child: _buildPage(chapter, page),
            ),
          ),
        ),
        if (pageNumber != null && pageCount != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.viewPaddingOf(context).bottom + 3,
            child: Center(
              child: Text(
                '$pageNumber/$pageCount',
                style: _readerThemeData.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  height: 1,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.58),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSpread({
    required Widget left,
    Widget? right,
  }) {
    final colors = _readerThemeData.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        SizedBox(
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
        ),
        Expanded(child: right ?? const SizedBox.expand()),
      ],
    );
  }

  String _pageIndicator(
    List<_ReaderPageData> pages,
    bool usesTwoPageLayout,
  ) {
    final start = usesTwoPageLayout && _pageMode == NativePageMode.instantPage
        ? _spreadStartForPage(_pageIndex)
        : _pageIndex;
    final end =
        usesTwoPageLayout ? (start + 1).clamp(0, pages.length - 1) : start;
    if (end == start) return '${start + 1}/${pages.length}';
    return '${start + 1}-${end + 1}/${pages.length}';
  }

  Widget _buildReaderGlassBar({
    required Widget child,
    required bool isTopBar,
  }) {
    final colors = _readerThemeData.colorScheme;
    final borderRadius = BorderRadius.circular(999);
    final blurEnabled = !GlassEffectConfig.shouldDisableBlur;
    final config = GlassEffectHelper.getReadingControlConfig(
      preset: GlassEffectConfig.dreamyMode,
      isTopBar: isTopBar,
    );
    final highlight = Color.lerp(
      _readerTheme.controlBar,
      Colors.white,
      _readerTheme.brightness == Brightness.dark ? 0.06 : 0.18,
    )!;
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            highlight.withValues(
              alpha: blurEnabled ? 0.92 : 1,
            ),
            _readerTheme.controlBar.withValues(
              alpha: blurEnabled ? 0.88 : 1,
            ),
          ],
        ),
        border: Border.all(
          color: Color.lerp(
            colors.outline,
            Colors.white,
            _readerTheme.brightness == Brightness.dark ? 0.16 : 0.38,
          )!
              .withValues(alpha: blurEnabled ? 0.54 : 0.68),
          width: 0.9,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(
              alpha: _readerTheme.brightness == Brightness.dark ? 0.46 : 0.22,
            ),
            blurRadius: 32,
            spreadRadius: -5,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: blurEnabled
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: config['blur']!,
                  sigmaY: config['blur']!,
                ),
                child: panel,
              )
            : panel,
      ),
    );
  }

  Widget _buildReaderBarIconButton({
    required VoidCallback onPressed,
    required String tooltip,
    required IconData icon,
  }) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        foregroundColor: _readerTheme.text,
        backgroundColor: _readerTheme.controlFill.withValues(alpha: 0.78),
        minimumSize: const Size.square(44),
        maximumSize: const Size.square(44),
        padding: EdgeInsets.zero,
        side: BorderSide(
          color: _readerTheme.border.withValues(alpha: 0.42),
          width: 0.8,
        ),
        shape: const CircleBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_readerSettingsLoaded || !_readerSystemUiApplied) {
      return const ColoredBox(
        color: Color(0xFFFAF8F3),
        child: SizedBox.expand(),
      );
    }
    return Theme(
      data: _readerThemeData,
      child: FutureBuilder<List<_NativeChapter>>(
        future: _chaptersFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: Text(widget.book.title)),
              body: Center(
                  child: Text(context.l10n
                      .readerOpenFailed(snapshot.error.toString()))),
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
                body: Center(child: Text(context.l10n.readerNoContent)));
          }

          _chapterIndex = _chapterIndex.clamp(0, chapters.length - 1);
          final chapter = chapters[_chapterIndex];
          final colors = _readerThemeData.colorScheme;

          return Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final usesTwoPageLayout = _usesTwoPageLayout(size);
                final paginationSize = _paginationSize(
                  size,
                  usesTwoPageLayout,
                );
                final pages = _pageMode == NativePageMode.verticalScroll
                    ? const <_ReaderPageData>[
                        _ReaderPageData(text: '', startOffset: 0),
                      ]
                    : _pagesFor(
                        chapter,
                        _chapterIndex,
                        paginationSize,
                        Directionality.of(context),
                        MediaQuery.textScalerOf(context),
                      );
                final bookPages = _pageMode == NativePageMode.horizontalSlide ||
                        _pageMode == NativePageMode.pageCurl
                    ? _bookPagesFor(
                        chapters,
                        _horizontalFirstChapter,
                        _horizontalLastChapter,
                        paginationSize,
                        Directionality.of(context),
                        MediaQuery.textScalerOf(context),
                      )
                    : const <_BookPageRef>[];
                if (_openPreviousChapterAtLastPage) {
                  _pageIndex = usesTwoPageLayout &&
                          _pageMode == NativePageMode.instantPage
                      ? _spreadStartForPage(pages.length - 1)
                      : pages.length - 1;
                  _openPreviousChapterAtLastPage = false;
                }
                _pageIndex = _pageIndex.clamp(0, pages.length - 1);
                if (usesTwoPageLayout &&
                    _pageMode == NativePageMode.instantPage) {
                  _pageIndex = _spreadStartForPage(_pageIndex);
                }
                if (_pageMode != NativePageMode.verticalScroll &&
                    _restoreAnchorAfterLayout &&
                    _anchorOffset != null) {
                  final anchor = _anchorOffset!;
                  final restoredIndex = pages.indexWhere(
                    (page) =>
                        anchor >= page.startOffset && anchor < page.endOffset,
                  );
                  if (restoredIndex >= 0) _pageIndex = restoredIndex;
                  if (usesTwoPageLayout &&
                      _pageMode == NativePageMode.instantPage) {
                    _pageIndex = _spreadStartForPage(_pageIndex);
                  }
                  _restoreAnchorAfterLayout = false;
                }
                if (_pageMode != NativePageMode.verticalScroll) {
                  final locationKey = '$_chapterIndex:$_pageIndex:'
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
                  final targetControllerPage =
                      usesTwoPageLayout ? targetPage ~/ 2 : targetPage;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_pageController.hasClients) return;
                    final current = _pageController.page?.round();
                    if (targetPage >= 0 && current != targetControllerPage) {
                      _pageController.jumpToPage(targetControllerPage);
                    }
                  });
                }

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: _onPointerDown,
                        onPointerMove: _onPointerMove,
                        onPointerCancel: _onPointerCancel,
                        onPointerUp: (event) => _onPointerUp(
                          event,
                          size.width,
                          pages,
                          chapters.length,
                          usesTwoPageLayout,
                        ),
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragEnd:
                              _pageMode == NativePageMode.horizontalSlide ||
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
                          ),
                        ),
                      ),
                    ),
                    if (_pageMode != NativePageMode.verticalScroll &&
                        _pageMode != NativePageMode.pageCurl &&
                        !usesTwoPageLayout)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: MediaQuery.viewPaddingOf(context).bottom + 3,
                        child: IgnorePointer(
                          child: Text(
                            _pageIndicator(pages, usesTwoPageLayout),
                            textAlign: TextAlign.center,
                            style:
                                _readerThemeData.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              height: 1,
                              color: colors.onSurfaceVariant
                                  .withValues(alpha: 0.58),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      left: 20,
                      right: 20,
                      top: _controlsVisible ? 10 : -130,
                      child: SafeArea(
                        bottom: false,
                        child: _buildReaderGlassBar(
                          isTopBar: true,
                          child: SizedBox(
                            height: 58,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 7,
                              ),
                              child: Row(
                                children: [
                                  _buildReaderBarIconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    tooltip: MaterialLocalizations.of(context)
                                        .backButtonTooltip,
                                    icon: Icons.arrow_back_rounded,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      chapter.title.isEmpty
                                          ? widget.book.title
                                          : chapter.title,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _readerThemeData
                                          .textTheme.titleMedium
                                          ?.copyWith(
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
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      left: 22,
                      right: 22,
                      bottom: _controlsVisible ? 16 : -110,
                      child: SafeArea(
                        top: false,
                        child: _buildReaderGlassBar(
                          isTopBar: false,
                          child: SizedBox(
                            height: 64,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 9,
                              ),
                              child: Row(
                                children: [
                                  _buildReaderBarIconButton(
                                    onPressed: () =>
                                        _showTableOfContents(chapters),
                                    tooltip: context.l10n.readerToolbarTOC,
                                    icon: Icons.format_list_bulleted_rounded,
                                  ),
                                  Expanded(
                                    child: Text(
                                      _pageMode != NativePageMode.verticalScroll
                                          ? context.l10n.readerStatusPaged(
                                              _chapterIndex + 1,
                                              chapters.length,
                                              _pageIndex + 1,
                                              pages.length,
                                            )
                                          : context.l10n.readerStatusScroll(
                                              _chapterIndex + 1,
                                              chapters.length,
                                            ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _readerThemeData
                                          .textTheme.labelLarge
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.15,
                                      ),
                                    ),
                                  ),
                                  _buildReaderBarIconButton(
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
                    ),
                  ],
                );
              },
            ),
          );
        },
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
}) {
  final imageOffsets = <(int, int)>[];
  var searchFrom = 0;
  for (var i = 0; i < chapter.blocks.length; i++) {
    final block = chapter.blocks[i];
    if (block.imageBase64 != null) {
      imageOffsets.add((searchFrom, i));
      continue;
    }
    final text = block.text;
    if (text == null || text.isEmpty) continue;
    final found = chapter.plainText.indexOf(text, searchFrom);
    if (found >= 0) searchFrom = found + text.length;
  }

  final pages = <_ReaderPageData>[];
  var cursor = 0;
  TextSpan buildSpan(int start, int end) =>
      _styledSpanForRange(chapter, start, end, style);
  List<_ReaderPageData> paginateRange(
    String text, {
    required int sourceOffset,
    required double height,
  }) {
    if (text.isEmpty) return const <_ReaderPageData>[];
    final ranges = NativeTextPaginator(
      maxWidth: maxWidth,
      maxHeight: height,
      flowStyle: flowStyle,
    ).paginate(
      text: text,
      sourceOffset: sourceOffset,
      spanBuilder: buildSpan,
    );
    return ranges
        .map(
          (range) => _ReaderPageData(
            text: text.substring(range.start, range.end),
          ),
        )
        .toList(growable: false);
  }

  for (final image in imageOffsets) {
    final offset = image.$1.clamp(cursor, chapter.plainText.length);
    final before = chapter.plainText.substring(cursor, offset);
    pages.addAll(
      paginateRange(
        before,
        sourceOffset: cursor,
        height: maxHeight,
      ),
    );

    final nextImageOffset =
        imageOffsets.indexOf(image) + 1 < imageOffsets.length
            ? imageOffsets[imageOffsets.indexOf(image) + 1].$1
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
      height: inlineTextHeight,
    );
    final inlineText = inlineChunks.isEmpty ? '' : inlineChunks.first.text;
    pages.add(
      _ReaderPageData(text: inlineText, imageBlockIndex: image.$2),
    );
    cursor = offset + inlineText.length;
  }

  if (cursor < chapter.plainText.length || pages.isEmpty) {
    pages.addAll(
      paginateRange(
        chapter.plainText.substring(cursor),
        sourceOffset: cursor,
        height: maxHeight,
      ),
    );
  }
  assert(pages.map((page) => page.text).join() == chapter.plainText,
      'Chapter pagination must preserve every character');
  var offset = 0;
  final anchoredPages = <_ReaderPageData>[];
  for (final page in pages) {
    anchoredPages.add(
      _ReaderPageData(
        text: page.text,
        imageBlockIndex: page.imageBlockIndex,
        startOffset: offset,
        endOffset: offset + page.text.length,
      ),
    );
    offset += page.text.length;
  }
  assert(offset == chapter.plainText.length,
      'Page boundaries must cover the complete chapter');
  return anchoredPages;
}

class _NativeChapter {
  _NativeChapter({
    required this.id,
    required this.title,
    required String plainText,
    required List<_NativeBlock> blocks,
    this.depth = 0,
  })  : _plainText = plainText,
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
  })  : _plainText = null,
        _blocks = null,
        _dataPath = dataPath,
        _startOffset = startOffset,
        _endOffset = endOffset;

  final String id;
  final String title;
  final int depth;
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
    required this.content,
  });

  final int chapterIndex;
  final int pageIndex;
  final int pageCount;
  final _ReaderPageData content;
}

class _ReaderPageData {
  const _ReaderPageData({
    required this.text,
    this.imageBlockIndex,
    this.startOffset = 0,
    int? endOffset,
  }) : endOffset = endOffset ?? startOffset + text.length;

  final String text;
  final int? imageBlockIndex;
  final int startOffset;
  final int endOffset;
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
      children.add(TextSpan(
        text: chapter.plainText.substring(cursor, overlapStart),
        style: base,
      ));
    }
    children.add(TextSpan(
      text: chapter.plainText.substring(overlapStart, overlapEnd),
      style: _styleForNativeBlock(block, base),
    ));
    cursor = overlapEnd;
  }
  if (cursor < end) {
    children.add(TextSpan(
      text: chapter.plainText.substring(cursor, end),
      style: base,
    ));
  }
  return TextSpan(style: base, children: children);
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

  void append(List<EpubChapter>? chapters, [int depth = 0]) {
    if (chapters == null) return;
    for (final chapter in chapters) {
      final document = html_parser.parse(chapter.HtmlContent ?? '');
      final blocks = <Map<String, String>>[];
      final plainText = StringBuffer();
      final elements = document.body?.querySelectorAll(
            'h1,h2,h3,h4,h5,h6,p,li,blockquote,pre,a,img,svg image',
          ) ??
          const <html_dom.Element>[];
      for (final element in elements) {
        final isImage = element.localName == 'img' ||
            (element.localName == 'image' && element.namespaceUri != null);
        if (isImage) {
          final src = element.attributes['src'] ??
              element.attributes['href'] ??
              element.attributes['xlink:href'];
          if (src == null || src.startsWith('data:')) continue;
          final name = path
              .basename(Uri.decodeFull(src.split('?').first.split('#').first))
              .toLowerCase();
          final encoded = imagesByName[name];
          if (encoded != null) {
            blocks.add(<String, String>{'type': 'image', 'content': encoded});
          }
          continue;
        }
        if (element.localName == 'a' && _hasEpubTextBlockAncestor(element)) {
          continue;
        }
        // 只取块的"自有文本"（排除嵌套块子树）：querySelectorAll 会同时
        // 命中 blockquote 与其内部的 p，用整棵子树的 text 会导致正文重复。
        final text = _epubElementOwnText(element)
            .replaceAll(RegExp(r'[ \t]+'), ' ')
            .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
            .trim();
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
          final color = RegExp(r'color\s*:\s*([^;]+)')
              .firstMatch(styleSource)
              ?.group(1)
              ?.trim();
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
        final fallback = document.body?.text.trim() ?? '';
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
          'id': chapter.ContentFileName ?? 'epub-${result.length}',
          'title': chapter.Title ?? '',
          'depth': depth,
          'plainText': plainText.toString(),
          'blocks': blocks,
        });
      }
      append(chapter.SubChapters, depth + 1);
    }
  }

  append(epub.Chapters);
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
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'p',
  'li',
  'blockquote',
  'pre',
};

/// 收集元素的自有文本：遇到嵌套的文本块子元素时跳过其子树，
/// 该子树的文本由它自己作为独立块处理。
String _epubElementOwnText(html_dom.Element element) {
  final buffer = StringBuffer();
  void visit(html_dom.Node node) {
    for (final child in node.nodes) {
      if (child is html_dom.Element) {
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
        },
      )
      .toList(growable: false);
}

Map<String, dynamic> _indexTxtFileInBackground(
  Map<String, dynamic> arguments,
) {
  final bytes = File(arguments['path'] as String).readAsBytesSync();
  final decoded = EnhancedTxtImportService().decodeWithOverride(
    bytes,
    encodingOverride: arguments['encoding'] as String?,
    verifyEncodingOverride: true,
  );
  final matches = _findTxtChapterMatches(decoded);
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
  }) {
    final startByte = output.positionSync();
    output.writeFromSync(
      utf8.encode(decoded.substring(startChar, endChar)),
    );
    chapters.add(<String, dynamic>{
      'id': id,
      'title': title,
      'depth': 0,
      'start': startByte,
      'end': output.positionSync(),
    });
  }

  try {
    if (matches.isEmpty) {
      writeChapter(
        id: 'txt-0',
        title: arguments['title'] as String,
        startChar: 0,
        endChar: decoded.length,
      );
    } else {
      if (matches.first.$1 > 0 &&
          decoded.substring(0, matches.first.$1).trim().isNotEmpty) {
        writeChapter(
          id: 'txt-preface',
          title: arguments['prefaceTitle'] as String,
          startChar: 0,
          endChar: matches.first.$1,
        );
      }
      for (var i = 0; i < matches.length; i++) {
        writeChapter(
          id: 'txt-$i',
          title: matches[i].$2,
          startChar: matches[i].$1,
          endChar: i + 1 < matches.length ? matches[i + 1].$1 : decoded.length,
        );
      }
    }
  } finally {
    output.closeSync();
  }

  if (dataFile.existsSync()) dataFile.deleteSync();
  temporaryData.renameSync(dataPath);

  final result = <String, dynamic>{
    'version': 1,
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
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
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
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
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
      'version': 1,
      'chapters': arguments['chapters'],
    }),
    flush: true,
  );
  if (file.existsSync()) file.deleteSync();
  temporary.renameSync(cachePath);

  final cachedFiles = file.parent
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
    plainText: text,
    blocks: <_NativeBlock>[_NativeBlock.text(text)],
  );
}

List<_NativeChapter> _nativeChaptersFromFileIndex(
  Map<String, dynamic> index,
) {
  final dataPath = index['dataPath'] as String? ?? '';
  final chapters = index['chapters'] as List<dynamic>? ?? const [];
  return chapters.map((chapter) {
    final values = Map<String, dynamic>.from(chapter as Map);
    return _NativeChapter.lazyFileText(
      id: values['id'] as String? ?? '',
      title: values['title'] as String? ?? '',
      depth: values['depth'] as int? ?? 0,
      dataPath: dataPath,
      startOffset: values['start'] as int? ?? 0,
      endOffset: values['end'] as int? ?? 0,
    );
  }).toList(growable: false);
}

List<_NativeChapter> _parseHtmlDocument(String source, String fallbackTitle) {
  final document = html_parser.parse(source);
  final headings = document.body?.querySelectorAll('h1,h2,h3,h4,h5,h6') ?? [];
  if (headings.isEmpty) {
    final text = document.body?.text.trim() ?? '';
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
    while (
        node != null && !RegExp(r'^h[1-6]$').hasMatch(node.localName ?? '')) {
      final text = node.text.trim();
      if (text.isNotEmpty) buffer.writeln('$text\n');
      node = node.nextElementSibling;
    }
    final text = buffer.toString();
    chapters.add(_NativeChapter(
      id: heading.id.isNotEmpty ? heading.id : 'html-$i',
      title: heading.text.trim(),
      depth:
          int.tryParse((heading.localName ?? 'h1').substring(1))?.clamp(1, 6) ??
              1,
      plainText: text,
      blocks: <_NativeBlock>[_NativeBlock.text(text)],
    ));
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
  final sections = RegExp(r'<section\b[^>]*>(.*?)</section>',
          caseSensitive: false, dotAll: true)
      .allMatches(source)
      .toList();
  if (sections.isEmpty) {
    final text = html_parser.parse(source).body?.text.trim() ?? '';
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
    final titleMatch = RegExp(r'<title\b[^>]*>(.*?)</title>',
            caseSensitive: false, dotAll: true)
        .firstMatch(xml);
    final title = titleMatch == null
        ? '$fallbackTitle ${index + 1}'
        : html_parser.parse(titleMatch.group(1)).body?.text.trim() ?? '';
    final text = html_parser.parse(xml).body?.text.trim() ?? '';
    return _NativeChapter(
      id: 'fb2-$index',
      title: title,
      plainText: text,
      blocks: <_NativeBlock>[_NativeBlock.text(text)],
    );
  });
}

String _extractRtfText(Uint8List bytes) {
  final source = latin1.decode(bytes, allowInvalid: true);
  return source
      .replaceAllMapped(RegExp(r"\\'([0-9a-fA-F]{2})"),
          (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)))
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
    String text, String fallbackTitle, String prefaceTitle) {
  final matches = _findTxtChapterMatches(text);
  if (matches.isEmpty) {
    return <_NativeChapter>[
      _NativeChapter(
        id: 'txt-0',
        title: fallbackTitle,
        plainText: text,
        blocks: <_NativeBlock>[_NativeBlock.text(text)],
      ),
    ];
  }
  final chapters = <_NativeChapter>[];
  if (matches.first.$1 > 0 &&
      text.substring(0, matches.first.$1).trim().isNotEmpty) {
    final preface = text.substring(0, matches.first.$1);
    chapters.add(_NativeChapter(
      id: 'txt-preface',
      title: prefaceTitle,
      plainText: preface,
      blocks: <_NativeBlock>[_NativeBlock.text(preface)],
    ));
  }
  for (var i = 0; i < matches.length; i++) {
    final start = matches[i].$1;
    final end = i + 1 < matches.length ? matches[i + 1].$1 : text.length;
    final content = text.substring(start, end);
    chapters.add(_NativeChapter(
      id: 'txt-$i',
      title: matches[i].$2,
      plainText: content,
      blocks: <_NativeBlock>[_NativeBlock.text(content)],
    ));
  }
  return chapters;
}

List<(int, String)> _findTxtChapterMatches(String text) {
  final heading = RegExp(
    r'^(?:第[0-9零〇一二三四五六七八九十百千万两]+[章节卷部篇回]|chapter\s+\d+|part\s+\d+|序章|序言|前言|引言|楔子|后记|尾声|番外)(?:[\s　:：.-]+.*)?$',
    caseSensitive: false,
  );
  final matches = <(int, String)>[];
  var offset = 0;
  while (offset < text.length) {
    final lineEnd = text.indexOf('\n', offset);
    final end = lineEnd < 0 ? text.length : lineEnd;
    final line = text.substring(offset, end);
    final title = line.trim();
    final normalizedTitle =
        title.replaceFirst(RegExp(r'^#{1,6}\s*'), '').trim();
    if (normalizedTitle.length <= 80 && heading.hasMatch(normalizedTitle)) {
      matches.add((offset, normalizedTitle));
    }
    offset = lineEnd < 0 ? text.length : lineEnd + 1;
  }
  return matches;
}

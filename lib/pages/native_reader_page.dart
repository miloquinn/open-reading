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
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/enhanced_txt_import_service.dart';

import '../utils/localization_extension.dart';
import '../utils/glass_config.dart';

enum NativePageMode { verticalScroll, instantPage, horizontalSlide }

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
  static const _pageNumberReserve = 16.0;
  static const _textStyle = TextStyle(
    fontSize: 19,
    height: 1.75,
    letterSpacing: 0.2,
  );

  late final Future<List<_NativeChapter>> _chaptersFuture;
  final PageController _pageController = PageController();
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
  NativePageMode _pageMode = NativePageMode.verticalScroll;
  bool _scrollByChapter = true;
  int _continuousAnchorChapter = 0;
  Key _continuousCenterKey = GlobalKey();
  bool _continuousVisibilityUpdateScheduled = false;
  double _fontSize = 19;
  double _horizontalMargin = 18;
  double _verticalMargin = 24;
  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;
  bool _pointerMoved = false;

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.book.currentPage;
    _continuousAnchorChapter = _chapterIndex;
    _horizontalFirstChapter = (_chapterIndex - 1).clamp(0, _chapterIndex);
    _horizontalLastChapter = _chapterIndex + 1;
    final savedLocator = widget.book.toCanonicalLocator();
    _anchorOffset = savedLocator?.textAnchor?.startOffsetUtf16;
    _loadPageMode();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readerDependenciesInitialized) return;
    final cacheKey = _bookCacheKey;
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
      '${widget.book.contentHash ?? widget.book.filePath}:'
      '${widget.book.fileModifiedTime ?? File(widget.book.filePath).lastModifiedSync().millisecondsSinceEpoch}:'
      '${widget.book.textEncoding ?? 'auto'}';

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadPageMode() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_pageModeKey);
    if (!mounted) return;
    setState(() {
      if (name != null) {
        _pageMode = NativePageMode.values.firstWhere(
          (mode) => mode.name == name,
          orElse: () => name == 'horizontalPage'
              ? NativePageMode.instantPage
              : NativePageMode.verticalScroll,
        );
      }
      _fontSize = prefs.getDouble(_fontSizeKey) ?? 19;
      _horizontalMargin = prefs.getDouble(_horizontalMarginKey) ?? 18;
      _verticalMargin = prefs.getDouble(_verticalMarginKey) ?? 24;
      _scrollByChapter = prefs.getBool(_scrollByChapterKey) ?? true;
    });
  }

  TextStyle get _readerTextStyle =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).merge(
        _textStyle.copyWith(fontSize: _fontSize),
      );

  Widget _buildStyledReaderText(
    _NativeChapter chapter,
    int start,
    int end,
  ) =>
      RichText(
        text: _styledSpanForRange(chapter, start, end, _readerTextStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      );

  double get _readerBottomMargin => (_verticalMargin - 14).clamp(4, 34);

  double get _effectiveBottomMargin =>
      _readerBottomMargin +
      MediaQuery.viewPaddingOf(context).bottom +
      _pageNumberReserve;

  Future<void> _updateLayout({
    double? fontSize,
    double? horizontalMargin,
    double? verticalMargin,
  }) async {
    setState(() {
      _fontSize = fontSize ?? _fontSize;
      _horizontalMargin = horizontalMargin ?? _horizontalMargin;
      _verticalMargin = verticalMargin ?? _verticalMargin;
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
      final cacheDirectory = Directory(
        path.join(
          (await getApplicationSupportDirectory()).path,
          'native_reader_cache',
        ),
      );
      final cacheName = sha1.convert(utf8.encode(_bookCacheKey)).toString();
      final cachePath = path.join(cacheDirectory.path, '$cacheName.json');
      final cached = await compute(_readParsedChapterCache, cachePath);
      if (cached != null) {
        return cached.map(_nativeChapterFromMap).toList(growable: false);
      }

      final bytes = await File(widget.book.filePath).readAsBytes();
      final parsed = await compute(_parseTxtInBackground, <String, dynamic>{
        'bytes': bytes,
        'encoding': widget.book.textEncoding,
        'title': widget.book.title,
        'prefaceTitle': l10n.readerPrefaceTitle,
      });
      unawaited(
        compute(_writeParsedChapterCache, <String, dynamic>{
          'path': cachePath,
          'chapters': parsed,
        }).catchError((_) {}),
      );
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

  void _nextPage(List<_ReaderPageData> pages, int chapterCount) {
    if (_pageMode == NativePageMode.horizontalSlide &&
        _pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_pageIndex < pages.length - 1) {
      setState(() => _pageIndex++);
    } else if (_chapterIndex < chapterCount - 1) {
      _setChapter(_chapterIndex + 1, chapterCount);
    }
  }

  void _previousPage(List<_ReaderPageData> pages, int chapterCount) {
    if (_pageMode == NativePageMode.horizontalSlide &&
        _pageController.hasClients) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_pageIndex > 0) {
      setState(() => _pageIndex--);
    } else if (_chapterIndex > 0) {
      _openPreviousChapterAtLastPage = true;
      _setChapter(_chapterIndex - 1, chapterCount);
    }
  }

  void _handleHorizontalSwipe(
    DragEndDetails details,
    List<_ReaderPageData> pages,
    int chapterCount,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    if (_pageMode == NativePageMode.horizontalSlide) return;
    if (_pageMode == NativePageMode.instantPage) {
      if (velocity < -350) {
        _nextPage(pages, chapterCount);
      } else if (velocity > 350) {
        _previousPage(pages, chapterCount);
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
  ) {
    final fraction = localPosition.dx / width;
    if (fraction >= 1 / 3 && fraction <= 2 / 3) {
      setState(() => _controlsVisible = !_controlsVisible);
      return;
    }
    if (_pageMode == NativePageMode.verticalScroll) return;
    if (fraction < 1 / 3) {
      _previousPage(pages, chapterCount);
    } else {
      _nextPage(pages, chapterCount);
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
      );
    }
    _pointerDownPosition = null;
    _pointerDownTime = null;
    _pointerMoved = false;
  }

  void _showReadingSettings() {
    var previewFontSize = _fontSize;
    var previewHorizontalMargin = _horizontalMargin;
    var previewVerticalMargin = _verticalMargin;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.readingSettings,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.swap_calls),
                  title: Text(context.l10n.pageTurningMode),
                  subtitle: Text(_pageModeSummary(context)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPageModeSettings(
                    () => setSheetState(() {}),
                  ),
                ),
                const Divider(height: 28),
                Text(context.l10n.readerFontSizeValue(previewFontSize.round()),
                    style: Theme.of(context).textTheme.titleMedium),
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
                    style: Theme.of(context).textTheme.titleMedium),
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
                    style: Theme.of(context).textTheme.titleMedium),
                Slider(
                  value: previewVerticalMargin,
                  min: 8,
                  max: 48,
                  divisions: 40,
                  onChanged: (value) =>
                      setSheetState(() => previewVerticalMargin = value),
                  onChangeEnd: (value) => _updateLayout(verticalMargin: value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    }
  }

  void _showPageModeSettings(VoidCallback onSettingsChanged) {
    var previewScrollByChapter = _scrollByChapter;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (menuContext) => StatefulBuilder(
        builder: (context, setMenuState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.pageTurningMode,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                RadioGroup<NativePageMode>(
                  groupValue: _pageMode,
                  onChanged: (mode) {
                    if (mode == null) return;
                    Navigator.of(menuContext).pop();
                    _setPageMode(mode);
                    onSettingsChanged();
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
                          title: Text(context.l10n.readerScrollByChapterTitle),
                          subtitle: Text(previewScrollByChapter
                              ? context.l10n.readerScrollByChapterOnHint
                              : context.l10n.readerScrollByChapterOffHint),
                          onChanged: (value) {
                            setMenuState(() => previewScrollByChapter = value);
                            _setScrollByChapter(value);
                            onSettingsChanged();
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTableOfContents(List<_NativeChapter> chapters) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Text(context.l10n.readerToolbarTOC,
                        style: Theme.of(context).textTheme.titleLarge),
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
    final key = 'v5:$chapterIndex:${size.width.round()}:${size.height.round()}:'
        '$scaleKey:${_fontSize.toStringAsFixed(1)}:'
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
          maxHeight: size.height - _verticalMargin - _effectiveBottomMargin - 6,
          direction: direction,
          textScaler: textScaler,
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
            flex: 5,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          ),
        if (bytes != null && page.text.isNotEmpty) const SizedBox(height: 10),
        if (page.text.isNotEmpty)
          Expanded(
            flex: 6,
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
        itemCount: bookPages.length,
        onPageChanged: (index) =>
            _onBookPageChanged(index, bookPages, chapters),
        itemBuilder: (context, index) {
          final page = bookPages[index];
          return Padding(
            padding: EdgeInsets.fromLTRB(
              _horizontalMargin,
              _verticalMargin,
              _horizontalMargin,
              _effectiveBottomMargin,
            ),
            child: SizedBox.expand(
              child: _buildPage(
                chapters[page.chapterIndex],
                page.content,
              ),
            ),
          );
        },
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

  Widget _buildReaderGlassBar({
    required Widget child,
    required bool isTopBar,
  }) {
    final colors = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(24);
    final blurEnabled = !GlassEffectConfig.shouldDisableBlur;
    final config = GlassEffectHelper.getReadingControlConfig(
      preset: GlassEffectConfig.dreamyMode,
      isTopBar: isTopBar,
    );
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(
          alpha: blurEnabled ? config['opacity']! : 1,
        ),
        border: Border.all(
          color: colors.outline.withValues(alpha: blurEnabled ? 0.28 : 0.34),
          width: 0.8,
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
            color: colors.shadow.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_NativeChapter>>(
      future: _chaptersFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.book.title)),
            body: Center(
                child: Text(
                    context.l10n.readerOpenFailed(snapshot.error.toString()))),
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
        final colors = Theme.of(context).colorScheme;

        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final pages = _pageMode == NativePageMode.verticalScroll
                  ? const <_ReaderPageData>[
                      _ReaderPageData(text: '', startOffset: 0),
                    ]
                  : _pagesFor(
                      chapter,
                      _chapterIndex,
                      size,
                      Directionality.of(context),
                      MediaQuery.textScalerOf(context),
                    );
              final bookPages = _pageMode == NativePageMode.horizontalSlide
                  ? _bookPagesFor(
                      chapters,
                      _horizontalFirstChapter,
                      _horizontalLastChapter,
                      size,
                      Directionality.of(context),
                      MediaQuery.textScalerOf(context),
                    )
                  : const <_BookPageRef>[];
              if (_openPreviousChapterAtLastPage) {
                _pageIndex = pages.length - 1;
                _openPreviousChapterAtLastPage = false;
              }
              _pageIndex = _pageIndex.clamp(0, pages.length - 1);
              if (_pageMode != NativePageMode.verticalScroll &&
                  _restoreAnchorAfterLayout &&
                  _anchorOffset != null) {
                final anchor = _anchorOffset!;
                final restoredIndex = pages.indexWhere(
                  (page) =>
                      anchor >= page.startOffset && anchor < page.endOffset,
                );
                if (restoredIndex >= 0) _pageIndex = restoredIndex;
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
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_pageController.hasClients) return;
                  final current = _pageController.page?.round();
                  if (targetPage >= 0 && current != targetPage) {
                    _pageController.jumpToPage(targetPage);
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
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragEnd:
                            _pageMode == NativePageMode.horizontalSlide
                                ? null
                                : (details) => _handleHorizontalSwipe(
                                      details,
                                      pages,
                                      chapters.length,
                                    ),
                        child: _buildReaderContent(
                          chapters,
                          chapter,
                          pages,
                          bookPages,
                        ),
                      ),
                    ),
                  ),
                  if (_pageMode != NativePageMode.verticalScroll)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: MediaQuery.viewPaddingOf(context).bottom + 3,
                      child: IgnorePointer(
                        child: Text(
                          '${_pageIndex + 1}/${pages.length}',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            height: 1,
                            color:
                                colors.onSurfaceVariant.withValues(alpha: 0.58),
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
                    left: 12,
                    right: 12,
                    top: _controlsVisible ? 8 : -130,
                    child: SafeArea(
                      bottom: false,
                      child: _buildReaderGlassBar(
                        isTopBar: true,
                        child: SizedBox(
                          height: 64,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back),
                              ),
                              Expanded(
                                child: Text(
                                  chapter.title.isEmpty
                                      ? widget.book.title
                                      : chapter.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    left: 16,
                    right: 16,
                    bottom: _controlsVisible ? 12 : -110,
                    child: SafeArea(
                      top: false,
                      child: _buildReaderGlassBar(
                        isTopBar: false,
                        child: SizedBox(
                          height: 68,
                          child: Row(
                            children: [
                              const SizedBox(width: 6),
                              IconButton.filledTonal(
                                onPressed: () => _showTableOfContents(chapters),
                                tooltip: context.l10n.readerToolbarTOC,
                                icon: const Icon(Icons.format_list_bulleted),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              IconButton.filledTonal(
                                onPressed: _showReadingSettings,
                                tooltip: context.l10n.readingSettings,
                                icon: const Icon(Icons.tune),
                              ),
                              const SizedBox(width: 6),
                            ],
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
    );
  }
}

List<String> _paginateText(
  String text, {
  required double maxWidth,
  required double maxHeight,
  required TextDirection direction,
  required TextScaler textScaler,
  TextStyle style = _NativeReaderPageState._textStyle,
  int sourceOffset = 0,
  TextSpan Function(int start, int end)? spanBuilder,
}) {
  if (text.isEmpty || maxWidth <= 0 || maxHeight <= 0) return <String>[''];
  final pages = <String>[];
  var start = 0;

  while (start < text.length) {
    var low = 1;
    final remainingLength = text.length - start;
    final fontSize = style.fontSize ?? 19;
    final lineHeight = fontSize * (style.height ?? 1.2);
    final estimatedLines = (maxHeight / lineHeight).ceil().clamp(1, 10000);
    final estimatedCharsPerLine =
        (maxWidth / (fontSize * 0.9)).ceil().clamp(1, 10000);
    var high =
        (estimatedLines * estimatedCharsPerLine * 2).clamp(1, remainingLength);
    var best = 1;

    bool fits(int length) {
      var end = start + length;
      if (end < text.length &&
          _isLowSurrogate(text.codeUnitAt(end)) &&
          end > start) {
        end--;
      }
      final painter = TextPainter(
        text: spanBuilder?.call(sourceOffset + start, sourceOffset + end) ??
            TextSpan(
              text: text.substring(start, end),
              style: style,
            ),
        textDirection: direction,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      return painter.height <= maxHeight;
    }

    while (high < remainingLength && fits(high)) {
      best = high;
      high = (high * 2).clamp(1, remainingLength);
      low = best + 1;
    }

    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      if (fits(mid)) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    var end = start + best;
    if (end < text.length && _isLowSurrogate(text.codeUnitAt(end))) end--;
    if (end <= start) end = (start + 1).clamp(0, text.length);
    if (end < text.length) {
      final pageText = text.substring(start, end);
      final painter = TextPainter(
        text: spanBuilder?.call(sourceOffset + start, sourceOffset + end) ??
            TextSpan(text: pageText, style: style),
        textDirection: direction,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      final lines = painter.computeLineMetrics();
      if (lines.length > 1 && pageText.isNotEmpty) {
        final lastLine = painter.getLineBoundary(
          TextPosition(offset: pageText.length - 1),
        );
        final visibleTail = pageText
            .substring(lastLine.start, lastLine.end)
            .replaceAll(RegExp(r'\s+'), '');
        if (visibleTail.runes.length <= 2 && lastLine.start > 0) {
          end = start + lastLine.start;
          if (end < text.length && _isLowSurrogate(text.codeUnitAt(end))) {
            end--;
          }
        }
      }
    }
    pages.add(text.substring(start, end));
    start = end;
  }

  assert(
      pages.join() == text, 'Native pagination must preserve every character');
  return pages.isEmpty ? <String>[''] : pages;
}

List<_ReaderPageData> _paginateChapter(
  _NativeChapter chapter, {
  required double maxWidth,
  required double maxHeight,
  required TextDirection direction,
  required TextScaler textScaler,
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
  for (final image in imageOffsets) {
    final offset = image.$1.clamp(cursor, chapter.plainText.length);
    final before = chapter.plainText.substring(cursor, offset);
    pages.addAll(
      _paginateText(
        before,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        direction: direction,
        textScaler: textScaler,
        style: style,
        sourceOffset: cursor,
        spanBuilder: buildSpan,
      ).where((text) => text.isNotEmpty).map(_ReaderPageData.text),
    );

    final nextImageOffset =
        imageOffsets.indexOf(image) + 1 < imageOffsets.length
            ? imageOffsets[imageOffsets.indexOf(image) + 1].$1
            : chapter.plainText.length;
    final available = chapter.plainText.substring(offset, nextImageOffset);
    final inlineChunks = _paginateText(
      available,
      maxWidth: maxWidth,
      maxHeight: maxHeight * 0.48,
      direction: direction,
      textScaler: textScaler,
      style: style,
      sourceOffset: offset,
      spanBuilder: buildSpan,
    );
    final inlineText = inlineChunks.isEmpty ? '' : inlineChunks.first;
    pages.add(
      _ReaderPageData(text: inlineText, imageBlockIndex: image.$2),
    );
    cursor = offset + inlineText.length;
  }

  if (cursor < chapter.plainText.length || pages.isEmpty) {
    pages.addAll(
      _paginateText(
        chapter.plainText.substring(cursor),
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        direction: direction,
        textScaler: textScaler,
        style: style,
        sourceOffset: cursor,
        spanBuilder: buildSpan,
      ).map(_ReaderPageData.text),
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

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

class _NativeChapter {
  const _NativeChapter({
    required this.id,
    required this.title,
    required this.plainText,
    required this.blocks,
    this.depth = 0,
  });

  final String id;
  final String title;
  final String plainText;
  final List<_NativeBlock> blocks;
  final int depth;
}

class _BookPageRef {
  const _BookPageRef({
    required this.chapterIndex,
    required this.pageIndex,
    required this.content,
  });

  final int chapterIndex;
  final int pageIndex;
  final _ReaderPageData content;
}

class _ReaderPageData {
  const _ReaderPageData({
    required this.text,
    this.imageBlockIndex,
    this.startOffset = 0,
    int? endOffset,
  }) : endOffset = endOffset ?? startOffset + text.length;

  const _ReaderPageData.text(String text)
      : this(text: text, imageBlockIndex: null);

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
  final color = _parseCssColor(block.colorHex);
  return base.copyWith(
    fontSize: (base.fontSize ?? 19) * block.fontScale,
    fontWeight: block.bold ? FontWeight.w700 : base.fontWeight,
    fontStyle: block.italic ? FontStyle.italic : base.fontStyle,
    color: color ?? base.color,
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

Color? _parseCssColor(String? value) {
  if (value == null || value.isEmpty) return null;
  final normalized = value.trim().toLowerCase();
  const named = <String, int>{
    'black': 0xFF000000,
    'white': 0xFFFFFFFF,
    'red': 0xFFF44336,
    'blue': 0xFF2196F3,
    'green': 0xFF4CAF50,
    'gray': 0xFF808080,
    'grey': 0xFF808080,
    'orange': 0xFFFF9800,
    'purple': 0xFF9C27B0,
  };
  if (named.containsKey(normalized)) return Color(named[normalized]!);
  final hex = normalized.replaceFirst('#', '');
  if (hex.length == 3) {
    final expanded = hex.split('').map((part) => '$part$part').join();
    return Color(int.parse('FF$expanded', radix: 16));
  }
  if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
  if (hex.length == 8) return Color(int.parse(hex, radix: 16));
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

  void append(List<EpubChapter>? chapters, [int depth = 0]) {
    if (chapters == null) return;
    for (final chapter in chapters) {
      final document = html_parser.parse(chapter.HtmlContent ?? '');
      final blocks = <Map<String, String>>[];
      final plainText = StringBuffer();
      final elements = document.body?.querySelectorAll(
            'h1,h2,h3,h4,h5,h6,p,li,blockquote,pre,img,svg image',
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
        final text = element.text
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

List<Map<String, dynamic>> _parseTxtInBackground(
  Map<String, dynamic> arguments,
) {
  final bytes = arguments['bytes'] as Uint8List;
  final decoded = EnhancedTxtImportService().decodeWithOverride(
    bytes,
    encodingOverride: arguments['encoding'] as String?,
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
    if (title.length <= 80 && heading.hasMatch(title)) {
      matches.add((offset, title));
    }
    offset = lineEnd < 0 ? text.length : lineEnd + 1;
  }
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

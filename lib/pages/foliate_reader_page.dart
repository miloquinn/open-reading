// 文件说明：Foliate 阅读页面 UI 壗委托 EpubPlayer 处理 WebView / JS Bridge，
// 自身仅负责玻璃面板、主题/排版/目录 Sheet、进度保存、系统 UI、
// 批注/书签/搜索/TTS 的上层交互。
// 技术要点：FoliateOpenPayload、ReaderTheme、CanonicalLocator 双轨定位、
// FoliateBridge 事件回调、SharedPreferences 主题持久化。

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/core/reader/canonical_locator.dart';
import 'package:xxread/core/reader/reader_theme.dart';
import 'package:xxread/core/reader/foliate_bridge.dart';
import 'package:xxread/core/reader/txt_manifest_builder.dart';
import 'package:xxread/models/book.dart' as legacy;
import 'package:xxread/models/bookmark.dart';
import 'package:xxread/models/book_note.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/bookmark_dao.dart';
import 'package:xxread/services/books/book_note_dao.dart';
import 'package:xxread/services/reading/local_reader_file_server.dart';
import 'package:xxread/utils/glass_config.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/widgets/epub_player.dart';
import 'package:xxread/widgets/side_toast.dart';

class FoliateReaderPage extends StatefulWidget {
  final legacy.Book book;
  final String? sourceFilePath;

  const FoliateReaderPage({
    super.key,
    required this.book,
    this.sourceFilePath,
  });

  @override
  State<FoliateReaderPage> createState() => _FoliateReaderPageState();
}

class _FoliateReaderPageState extends State<FoliateReaderPage>
    with WidgetsBindingObserver {
  static const String _themeIndexPrefKey = 'reader_theme_index_v2';
  static const String _themeOverridesPrefKey = 'reader_theme_overrides_v1';
  static const String _canonicalLocatorPrefKeyPrefix =
      'reader_canonical_locator_v1_';
  static const String _showSystemStatusBarPrefKey =
      'readerShowSystemStatusBar';
  static const double _floatingPanelRadius = 30;

  final _epubPlayerKey = GlobalKey<EpubPlayerState>();

  bool _configReady = false;
  bool _readerReady = false;
  bool _chromeVisible = false;
  bool _showSystemStatusBarInReader = false;
  bool _hasCurrentBookmark = false;

  int _themeIndex = 0;
  ReaderTheme _currentTheme = ReaderTheme.defaultLight;

  CanonicalLocator? _lastCanonicalLocator;
  String? _lastCfi;
  double _overallProgress = 0.0;
  int _currentPage = 1;
  int _totalPages = 1;
  String _chapterTitle = '';
  List<Map<String, dynamic>> _tocItems = [];

  FoliateOpenPayload? _openPayload;

  final _bookDao = BookDao();
  final _bookmarkDao = BookmarkDao();
  final _bookNoteDao = BookNoteDao();

  // ── 搜索状态 ──
  bool _searchActive = false;
  String _searchQuery = '';
  final _searchResults = <_SearchResultItem>[];
  double _searchProgress = 0.0;

  // ── TTS 状态 ──
  bool _ttsActive = false;

  // ── 选区状态（用于批注 UI） ──
  FoliateSelectionEvent? _pendingSelection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _persistProgressNow();
    _restoreHostSystemUI();
    _progressDebounceTimer?.cancel();
    super.dispose();
  }

  // ── Bootstrap ──

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();

    // 恢复主题
    _themeIndex =
        (prefs.getInt(_themeIndexPrefKey) ?? 0)
            .clamp(0, ReaderTheme.presets.length - 1);
    final overridesRaw = prefs.getString(_themeOverridesPrefKey);
    if (overridesRaw != null) {
      try {
        final overrides = ReaderTheme.fromJsonString(overridesRaw);
        _currentTheme = ReaderTheme.presets[_themeIndex].merge(overrides);
      } catch (_) {
        _currentTheme = ReaderTheme.presets[_themeIndex];
      }
    } else {
      _currentTheme = ReaderTheme.presets[_themeIndex];
    }

    _showSystemStatusBarInReader =
        prefs.getBool(_showSystemStatusBarPrefKey) ?? false;

    // 构建 FoliateOpenPayload
    final path = widget.sourceFilePath ?? widget.book.filePath;
    final format = BookFormat.fromFileExtension(
      widget.book.format.toLowerCase(),
    );

    if (format == BookFormat.txt) {
      // TXT: 需要构建 manifest
      _openPayload = await _buildTXTPayload(path, format);
    } else {
      // EPUB/PDF/MOBI/FB2 等: 使用 LocalReaderFileServer URL
      String? serverUrl;
      try {
        serverUrl =
            await LocalReaderFileServer.instance.registerBookFile(path);
        debugPrint('Foliate Reader URL: $serverUrl');
      } catch (e) {
        debugPrint('Failed to register book file: $e');
      }

      final bookId = widget.book.id?.toString() ?? '0';
      final initialCanonicalLocator =
          widget.book.id != null
              ? prefs.getString(
                  '$_canonicalLocatorPrefKeyPrefix${widget.book.id}',
                )
              : null;

      _openPayload = FoliateOpenPayload(
        manifestURL: serverUrl ?? path,
        bookId: bookId,
        bookTitle: widget.book.title,
        language: 'zh-Hans',
        initialCanonicalLocator: initialCanonicalLocator,
      );
    }

    // 恢复初始进度估算（书架显示用）
    _overallProgress = widget.book.totalPages > 0
        ? widget.book.currentPage / widget.book.totalPages
        : 0.0;

    _applyReaderSystemUI();
    if (mounted) {
      setState(() => _configReady = true);
    }
  }

  Future<FoliateOpenPayload> _buildTXTPayload(
    String path,
    BookFormat format,
  ) async {
    // 读取 TXT 文件内容
    final file = File(path);
    final bytes = await file.readAsBytes();
    final stat = await file.stat();
    final bookId = widget.book.id?.toString() ?? '0';
    final encodingOverride = widget.book.textEncoding;

    // 解码内容
    final content = TXTManifestBuilder.detectAndDecode(
      bytes,
      encodingOverride: encodingOverride == 'auto' ? null : encodingOverride,
    );

    // 检测章节
    final chapters = TXTManifestBuilder.detectChapters(content);
    final sourceChapters = chapters.map((entry) {
      final endOffset = entry.endUTF16Offset.clamp(0, content.length);
      final text = content.substring(
        entry.startUTF16Offset.clamp(0, content.length),
        endOffset,
      );
      return TXTFoliateSourceChapter(
        id: entry.id,
        chapterIndex: entry.chapterIndex,
        title: entry.title,
        level: entry.level,
        startUTF16Offset: entry.startUTF16Offset,
        endUTF16Offset: endOffset,
        text: text,
      );
    }).toList();

    final pkg = await TXTManifestBuilder.buildPackage(
      bookId: bookId,
      bookTitle: widget.book.title,
      language: 'zh-Hans',
      sourceFingerprint: TXTSourceFingerprint(
        path: path,
        fileSize: bytes.length,
        modifiedAt: stat.modified.millisecondsSinceEpoch,
      ),
      sourceChapters: sourceChapters,
      totalUTF16Length: content.length,
    );

    final prefs = await SharedPreferences.getInstance();
    final initialCanonicalLocator =
        widget.book.id != null
            ? prefs.getString(
                '$_canonicalLocatorPrefKeyPrefix${widget.book.id}',
              )
            : null;

    return FoliateOpenPayload(
      manifestURL: pkg.manifestPath,
      bookId: bookId,
      bookTitle: widget.book.title,
      language: 'zh-Hans',
      estimatedTotalPages: pkg.chapterAssets.length,
      initialCanonicalLocator: initialCanonicalLocator,
    );
  }

  // ── System UI ──

  void _applyReaderSystemUI() {
    final isDark = _currentTheme.isDark;
    final baseStyle =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    SystemChrome.setSystemUIOverlayStyle(
      baseStyle.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
    if (_showSystemStatusBarInReader) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [SystemUiOverlay.top],
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _restoreHostSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiHelper.overlayStyleForBrightness(brightness),
    );
  }

  // ── EpubPlayer 事件回调 ──

  void _onRelocate(FoliateRelocateEvent event) {
    setState(() {
      _chapterTitle = event.href ?? '';
      _currentPage = event.currentPage;
      _totalPages = event.totalPages;
      _overallProgress = event.progression;

      if (event.canonicalLocator != null) {
        try {
          _lastCanonicalLocator =
              CanonicalLocator.fromJson(event.canonicalLocator!);
          final fragments = _lastCanonicalLocator!.fragments;
          if (fragments.isNotEmpty) {
            _lastCfi = fragments.first;
          } else if (_lastCanonicalLocator!.href != null) {
            _lastCfi = _lastCanonicalLocator!.href;
          }
        } catch (e) {
          debugPrint('Failed to parse canonicalLocator: $e');
        }
      }
    });

    // 异步检查书签与保存进度
    _checkBookmarkAtCurrentLocation();
    _persistProgressDebounced();
  }

  void _onSelection(FoliateSelectionEvent event) {
    if (event.text.isEmpty) {
      setState(() => _pendingSelection = null);
      return;
    }
    setState(() {
      _pendingSelection = event;
    });
  }

  void _onAnnotationActivated(FoliateAnnotationActivatedEvent event) {
    // 点击已有批注 → 后续迭代补充编辑/查看面板
    debugPrint('Annotation activated: ${event.annotationId}');
  }

  void _onSearchResult(FoliateSearchResultEvent event) {
    setState(() {
      if (event.progress != null) {
        _searchProgress = event.progress!;
      } else if (event.cfi != null) {
        _searchResults.add(_SearchResultItem(
          cfi: event.cfi!,
          text: event.text ?? '',
          contextText: event.contextText ?? '',
        ));
      }
    });
  }

  void _onTTSUtterance(FoliateTTSUtteranceEvent event) {
    // TTS 朗读片段事件 → 后续集成 flutter_tts
    debugPrint('TTS utterance: ${event.text.substring(0, 40)}...');
  }

  void _onToc(FoliateTocEvent event) {
    setState(() {
      _tocItems = event.tocItems;
    });
  }

  void _onOpened() {
    setState(() => _readerReady = true);
  }

  void _onError(FoliateErrorEvent event) {
    debugPrint('Foliate error [${event.code}] ${event.message}');
  }

  // ── 进度保存 ──

  Timer? _progressDebounceTimer;

  void _persistProgressDebounced() {
    _progressDebounceTimer?.cancel();
    _progressDebounceTimer = Timer(const Duration(seconds: 3), () {
      _persistProgressNow();
    });
  }

  Future<void> _persistProgressNow() async {
    final bookId = widget.book.id;
    if (bookId == null) return;
    final player = _epubPlayerKey.currentState;
    if (player == null) return;

    // 从 rendered locator 派生页码（书架显示用）
    final currentPage = player.currentPage;
    final totalPages = player.totalPages;
    await _bookDao.updateBookProgress(bookId, currentPage - 1);
    await _bookDao.updateBookTotalPages(bookId, totalPages);

    // 持久化 canonical locator 到 SharedPreferences
    final canonical = player.lastCanonicalLocator;
    if (canonical != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_canonicalLocatorPrefKeyPrefix$bookId',
        LocatorCodec.encodeCanonicalLocator(canonical),
      );
    }
  }

  // ── 书签 ──

  Future<void> _checkBookmarkAtCurrentLocation() async {
    final bookId = widget.book.id;
    if (bookId == null) return;
    final cfi = _lastCfi;
    if (cfi == null || cfi.isEmpty) {
      setState(() => _hasCurrentBookmark = false);
      return;
    }
    final existing = await _bookmarkDao.getBookmarkByCfi(bookId, cfi);
    setState(() => _hasCurrentBookmark = existing != null);
  }

  Future<void> _toggleCurrentBookmark() async {
    final bookId = widget.book.id;
    if (bookId == null) return;

    if (_hasCurrentBookmark) {
      // 移除书签
      final cfi = _lastCfi;
      if (cfi == null || cfi.isEmpty) return;
      await _bookmarkDao.deleteBookmarkByCfi(bookId, cfi);
      setState(() => _hasCurrentBookmark = false);
      showSideToast(
        context,
        '已移除当前书签',
        icon: Icons.bookmark_remove_rounded,
      );
    } else {
      // 添加书签，绑定 canonical locator
      final cfi = _lastCfi ?? '';
      final canonicalLocatorJson = _lastCanonicalLocator != null
          ? LocatorCodec.encodeCanonicalLocator(_lastCanonicalLocator!)
          : '';
      await _bookmarkDao.insertBookmark(Bookmark(
        bookId: bookId,
        pageNumber: _currentPage,
        cfi: cfi.isNotEmpty ? cfi : canonicalLocatorJson,
      ));
      setState(() => _hasCurrentBookmark = true);
      showSideToast(
        context,
        '已添加当前书签',
        icon: Icons.bookmark_added_rounded,
      );
    }
  }

  // ── 批注 ──

  Future<void> _addHighlight(FoliateSelectionEvent selection) async {
    Navigator.pop(context);
    final bookId = widget.book.id;
    if (bookId == null) return;

    final annotationId =
        'hl-${selection.chapterID ?? 'unknown'}-${selection.canonicalStart ?? 0}';
    final colorHex = '66CCFF'; // 默认浅蓝色

    _epubPlayerKey.currentState?.addAnnotation(AnnotationData(
      id: annotationId,
      type: 'highlight',
      value: selection.text,
      color: colorHex,
      canonicalStart: selection.canonicalStart,
      canonicalEnd: selection.canonicalEnd,
    ));

    final canonicalLocatorJson = _lastCanonicalLocator != null
        ? LocatorCodec.encodeCanonicalLocator(_lastCanonicalLocator!)
        : '';
    await _bookNoteDao.insertBookNote(BookNote(
      bookId: bookId,
      content: selection.text,
      cfi: canonicalLocatorJson.isNotEmpty
          ? canonicalLocatorJson
          : annotationId,
      chapter: selection.chapterID ?? '',
      type: 'highlight',
      color: colorHex,
      pageNumber: _currentPage,
      startOffset: selection.canonicalStart,
      endOffset: selection.canonicalEnd,
    ));
  }

  Future<void> _addNote(FoliateSelectionEvent selection) async {
    Navigator.pop(context);
    final annotationId =
        'note-${selection.chapterID ?? 'unknown'}-${selection.canonicalStart ?? 0}';
    final colorHex = 'EB3BFF'; // 紫色标记笔记

    _epubPlayerKey.currentState?.addAnnotation(AnnotationData(
      id: annotationId,
      type: 'highlight',
      value: selection.text,
      color: colorHex,
      canonicalStart: selection.canonicalStart,
      canonicalEnd: selection.canonicalEnd,
    ));

    final note = await _showNoteInputDialog(selection.text);
    if (note == null || note.isEmpty) return;

    final bookId = widget.book.id;
    if (bookId == null) return;
    final canonicalLocatorJson = _lastCanonicalLocator != null
        ? LocatorCodec.encodeCanonicalLocator(_lastCanonicalLocator!)
        : '';
    await _bookNoteDao.insertBookNote(BookNote(
      bookId: bookId,
      content: selection.text,
      cfi: canonicalLocatorJson.isNotEmpty
          ? canonicalLocatorJson
          : annotationId,
      chapter: selection.chapterID ?? '',
      type: 'note',
      color: colorHex,
      readerNote: note,
      pageNumber: _currentPage,
      startOffset: selection.canonicalStart,
      endOffset: selection.canonicalEnd,
    ));
  }

  Future<String?> _showNoteInputDialog(String selectedText) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _hexToColor(_currentTheme.backgroundColor),
        title: Text(
          '添加笔记',
          style: TextStyle(color: _hexToColor(_currentTheme.textColor)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedText.length > 60
                  ? '${selectedText.substring(0, 60)}...'
                  : selectedText,
              style: TextStyle(
                color: _hexToColor(_currentTheme.textColor).withValues(alpha: 0.6),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              style: TextStyle(color: _hexToColor(_currentTheme.textColor)),
              decoration: InputDecoration(
                hintText: '输入笔记内容...',
                hintStyle: TextStyle(
                  color: _hexToColor(_currentTheme.textColor).withValues(alpha: 0.4),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _hexToColor(_currentTheme.textColor).withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _hexToColor(_currentTheme.selectionColor),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(
                color: _hexToColor(_currentTheme.textColor).withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              '确定',
              style: TextStyle(
                color: _hexToColor(_currentTheme.selectionColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 主题切换 ──

  Future<void> _updateTheme(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeIndexPrefKey, index);

    final newTheme = ReaderTheme.presets[index];
    final merged = newTheme.merge(ReaderTheme(
      name: 'TypographyOverride',
      fontSize: _currentTheme.fontSize,
      lineHeight: _currentTheme.lineHeight,
      pageMargin: _currentTheme.pageMargin,
      topMargin: _currentTheme.topMargin,
      bottomMargin: _currentTheme.bottomMargin,
    ));

    setState(() {
      _themeIndex = index;
      _currentTheme = merged;
    });
    _epubPlayerKey.currentState?.updateTheme(_currentTheme);
    _applyReaderSystemUI();
  }

  // ── 排版调整 ──

  Future<void> _updateTypography({
    double? fontSize,
    double? lineHeight,
    double? pageMargin,
  }) async {
    final newTheme = _currentTheme.copyWith(
      fontSize: fontSize ?? _currentTheme.fontSize,
      lineHeight: lineHeight ?? _currentTheme.lineHeight,
      pageMargin: pageMargin ?? _currentTheme.pageMargin,
    );
    setState(() => _currentTheme = newTheme);
    _epubPlayerKey.currentState?.updateTheme(newTheme);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeOverridesPrefKey, newTheme.toJsonString());
  }

  // ── 搜索 ──

  void _startSearch(String query) {
    setState(() {
      _searchActive = true;
      _searchQuery = query;
      _searchResults.clear();
      _searchProgress = 0.0;
    });
    _epubPlayerKey.currentState?.search(SearchConfig(query: query));
  }

  void _clearSearch() {
    setState(() {
      _searchActive = false;
      _searchQuery = '';
      _searchResults.clear();
      _searchProgress = 0.0;
    });
    _epubPlayerKey.currentState?.clearSearch();
  }

  void _navigateToSearchResult(_SearchResultItem result) {
    if (result.cfi.isNotEmpty) {
      _epubPlayerKey.currentState?.goToCfi(result.cfi);
    } else if (result.canonicalLocator != null) {
      _epubPlayerKey.currentState?.goToCanonical(result.canonicalLocator!);
    }
    setState(() => _chromeVisible = false);
  }

  // ── TTS ──

  void _toggleTTS() {
    if (_ttsActive) {
      _epubPlayerKey.currentState?.ttsStop();
      setState(() => _ttsActive = false);
    } else {
      _epubPlayerKey.currentState?.initTTS();
      setState(() => _ttsActive = true);
    }
  }

  // ── Sheet 面板 ──

  void _showThemeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _hexToColor(_currentTheme.backgroundColor),
      showDragHandle: true,
      builder: (context) => Container(
        height: 180,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text(
              '阅读主题',
              style: TextStyle(
                color: _hexToColor(_currentTheme.textColor),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: ReaderTheme.presets.length,
                itemBuilder: (context, index) {
                  final theme = ReaderTheme.presets[index];
                  final isSelected = index == _themeIndex;
                  final bgColor = _hexToColor(theme.backgroundColor);
                  final fgColor = _hexToColor(theme.textColor);
                  return GestureDetector(
                    onTap: () {
                      _updateTheme(index);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 50,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? _hexToColor(_currentTheme.selectionColor)
                              : fgColor.withValues(alpha: 0.15),
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _hexToColor(
                                    _currentTheme.selectionColor,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: _hexToColor(
                                _currentTheme.selectionColor,
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTocSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _hexToColor(_currentTheme.backgroundColor),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '目录',
                style: TextStyle(
                  color: _hexToColor(_currentTheme.textColor),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            Expanded(
              child: _tocItems.isEmpty
                  ? Center(
                      child: Text(
                        '暂无目录',
                        style: TextStyle(
                          color: _hexToColor(_currentTheme.textColor)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: _tocItems.length,
                      separatorBuilder: (context, index) => Divider(
                        color: _hexToColor(_currentTheme.textColor)
                            .withValues(alpha: 0.1),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final item =
                            Map<String, dynamic>.from(_tocItems[index]);
                        final title =
                            item['label']?.toString() ?? '无标题';
                        final href = item['href']?.toString();
                        return ListTile(
                          title: Text(
                            title,
                            style: TextStyle(
                              color: _hexToColor(_currentTheme.textColor),
                              fontSize: 15,
                            ),
                          ),
                          onTap: href == null
                              ? null
                              : () {
                                  _epubPlayerKey.currentState?.goToCfi(href);
                                  Navigator.pop(context);
                                  setState(() => _chromeVisible = false);
                                },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTypographySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _hexToColor(_currentTheme.backgroundColor),
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '排版设置',
                style: TextStyle(
                  color: _hexToColor(_currentTheme.textColor),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.text_fields, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    '字号',
                    style: TextStyle(
                      color: _hexToColor(_currentTheme.textColor),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _currentTheme.fontSize,
                      min: 0.8,
                      max: 2.5,
                      onChanged: (val) {
                        setSheetState(() {});
                        _updateTypography(fontSize: val);
                      },
                    ),
                  ),
                  Text(
                    _currentTheme.fontSize.toStringAsFixed(2),
                    style: TextStyle(
                      color: _hexToColor(_currentTheme.textColor),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.format_line_spacing, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    '行高',
                    style: TextStyle(
                      color: _hexToColor(_currentTheme.textColor),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _currentTheme.lineHeight,
                      min: 1.0,
                      max: 3.0,
                      onChanged: (val) {
                        setSheetState(() {});
                        _updateTypography(lineHeight: val);
                      },
                    ),
                  ),
                  Text(
                    _currentTheme.lineHeight.toStringAsFixed(2),
                    style: TextStyle(
                      color: _hexToColor(_currentTheme.textColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 构建 UI ──

  @override
  Widget build(BuildContext context) {
    if (!_configReady || _openPayload == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bgColor = _hexToColor(_currentTheme.backgroundColor);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // EpubPlayer 主阅读区
          Positioned.fill(
            child: EpubPlayer(
              key: _epubPlayerKey,
              openPayload: _openPayload!,
              theme: _currentTheme,
              onRelocate: _onRelocate,
              onSelection: _onSelection,
              onAnnotationActivated: _onAnnotationActivated,
              onSearchResult: _onSearchResult,
              onTTSUtterance: _onTTSUtterance,
              onToc: _onToc,
              onError: _onError,
              onOpened: _onOpened,
            ),
          ),

          // 加载指示器
          if (!_readerReady)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.transparent,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          // 中间区域点击切换工具栏（新 EpubPlayer 无 onClick 回调，
          // JS host 的 gestureNavigationMode 处理翻页手势，
          // 此处仅拦截中间区域用于 chrome toggle）
          if (_readerReady && _pendingSelection == null && !_searchActive)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  final xFraction =
                      details.localPosition.dx / context.size!.width;
                  // 只有中间 40% 区域触发 chrome toggle
                  if (xFraction > 0.3 && xFraction < 0.7) {
                    setState(() => _chromeVisible = !_chromeVisible);
                  }
                },
                child: const SizedBox.expand(),
              ),
            ),

          // 选区批注工具栏
          if (_pendingSelection != null && _readerReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: 100,
              child: _buildSelectionToolbar(),
            ),

          // 搜索面板
          if (_searchActive)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildSearchBar(),
            ),

          // 顶部控制栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopControlBarAnimated(),
          ),

          // 底部面板
          Positioned(
            left: 0,
            right: 0,
            bottom: 34,
            child: _buildBottomPanelAnimated(),
          ),

          // 非工具栏模式下的阅读信息
          if (!_chromeVisible && !_searchActive)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: _buildBottomReadingInfoOverlay(),
            ),
        ],
      ),
    );
  }

  // ── 选区批注工具栏 ──

  Widget _buildSelectionToolbar() {
    final fgColor = _hexToColor(_currentTheme.textColor);
    final bgColor = _hexToColor(_currentTheme.backgroundColor);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.highlight_alt, color: fgColor, size: 22),
              onPressed: () =>
                  _addHighlight(_pendingSelection!),
              tooltip: '高亮',
            ),
            IconButton(
              icon: Icon(Icons.note_alt, color: fgColor, size: 22),
              onPressed: () =>
                  _addNote(_pendingSelection!),
              tooltip: '笔记',
            ),
            IconButton(
              icon: Icon(Icons.bookmark_add_outlined, color: fgColor, size: 22),
              onPressed: () {
                _epubPlayerKey.currentState?.clearSelection();
                setState(() => _pendingSelection = null);
                _toggleCurrentBookmark();
              },
              tooltip: '书签',
            ),
            IconButton(
              icon: Icon(Icons.close, color: fgColor, size: 22),
              onPressed: () {
                _epubPlayerKey.currentState?.clearSelection();
                setState(() => _pendingSelection = null);
              },
              tooltip: '关闭',
            ),
          ],
        ),
      ),
    );
  }

  // ── 搜索栏 ──

  Widget _buildSearchBar() {
    final fgColor = _hexToColor(_currentTheme.textColor);
    final bgColor = _hexToColor(_currentTheme.backgroundColor);
    final selColor = _hexToColor(_currentTheme.selectionColor);

    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_floatingPanelRadius),
          child: BackdropFilter(
            enabled: !GlassEffectConfig.shouldDisableBlur,
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_floatingPanelRadius),
                border: Border.all(color: fgColor.withValues(alpha: 0.24)),
                color: bgColor.withValues(
                  alpha: GlassEffectConfig.shouldDisableBlur ? 1.0 : 0.6,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          controller:
                              TextEditingController(text: _searchQuery),
                          style: TextStyle(color: fgColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '搜索...',
                            hintStyle: TextStyle(
                              color: fgColor.withValues(alpha: 0.4),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (val) {
                            if (val.isNotEmpty) _startSearch(val);
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: fgColor, size: 20),
                        onPressed: _clearSearch,
                      ),
                    ],
                  ),
                  if (_searchResults.isNotEmpty || _searchProgress > 0)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchProgress > 0 && _searchProgress < 1.0)
                          LinearProgressIndicator(
                            value: _searchProgress,
                            color: selColor,
                            backgroundColor:
                                fgColor.withValues(alpha: 0.1),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${_searchResults.length} 个结果',
                          style: TextStyle(color: fgColor, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  result.text.length > 40
                                      ? '${result.text.substring(0, 40)}...'
                                      : result.text,
                                  style: TextStyle(
                                    color: fgColor,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: result.contextText.isNotEmpty
                                    ? Text(
                                        result.contextText.length > 60
                                            ? '${result.contextText.substring(0, 60)}...'
                                            : result.contextText,
                                        style: TextStyle(
                                          color:
                                              fgColor.withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                onTap: () =>
                                    _navigateToSearchResult(result),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 顶部控制栏 ──

  Widget _buildTopControlBarAnimated() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      offset: _chromeVisible ? Offset.zero : const Offset(0, -1.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: _chromeVisible ? 1 : 0,
        child: SafeArea(
          bottom: false,
          child: _buildGlassPanel(
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: _hexToColor(_currentTheme.textColor),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    widget.book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _hexToColor(_currentTheme.textColor),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.search,
                    color: _hexToColor(_currentTheme.textColor),
                  ),
                  onPressed: () {
                    setState(() {
                      _searchActive = true;
                      _chromeVisible = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 底部面板 ──

  Widget _buildBottomPanelAnimated() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      offset: _chromeVisible ? Offset.zero : const Offset(0, 1.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: _chromeVisible ? 1 : 0,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              _buildGlassPanel(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${(_overallProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _hexToColor(_currentTheme.textColor),
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _overallProgress.clamp(0.0, 1.0),
                        onChanged: (val) {
                          setState(() => _overallProgress = val);
                          _epubPlayerKey.currentState?.goToPercent(val);
                        },
                      ),
                    ),
                    Text(
                      '全书',
                      style: TextStyle(
                        color: _hexToColor(_currentTheme.textColor),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // 工具按钮
              _buildGlassPanel(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.toc,
                        color: _hexToColor(_currentTheme.textColor),
                      ),
                      onPressed: _showTocSheet,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.palette,
                        color: _hexToColor(_currentTheme.textColor),
                      ),
                      onPressed: _showThemeSheet,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.tune,
                        color: _hexToColor(_currentTheme.textColor),
                      ),
                      onPressed: _showTypographySheet,
                    ),
                    IconButton(
                      icon: Icon(
                        _hasCurrentBookmark
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_add_outlined,
                        color: _hexToColor(_currentTheme.textColor),
                      ),
                      onPressed: _toggleCurrentBookmark,
                    ),
                    IconButton(
                      icon: Icon(
                        _ttsActive
                            ? Icons.stop_circle_rounded
                            : Icons.record_voice_over,
                        color: _hexToColor(_currentTheme.textColor),
                      ),
                      onPressed: _toggleTTS,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 玻璃面板 ──

  Widget _buildGlassPanel({
    required Widget child,
    required EdgeInsets margin,
    required EdgeInsets padding,
  }) {
    final isLowPerformance = GlassEffectConfig.shouldDisableBlur;
    final bgColor = _hexToColor(_currentTheme.backgroundColor);
    final fgColor = _hexToColor(_currentTheme.textColor);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_floatingPanelRadius),
        child: BackdropFilter(
          enabled: !isLowPerformance,
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_floatingPanelRadius),
              border: Border.all(color: fgColor.withValues(alpha: 0.24)),
              color: bgColor.withValues(
                alpha: isLowPerformance ? 1.0 : 0.6,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  // ── 非工具栏模式的阅读信息 ──

  Widget _buildBottomReadingInfoOverlay() {
    final bgColor = _hexToColor(_currentTheme.backgroundColor);
    final fgColor = _hexToColor(_currentTheme.textColor);
    final safeTotalPages = _totalPages > 0 ? _totalPages : 1;

    return SafeArea(
      top: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$chapterTitle · 第 $currentPage/$safeTotalPages 页',
            style: TextStyle(
              color: fgColor.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  String get chapterTitle => _chapterTitle;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages > 0 ? _totalPages : 1;

  // ── 颜色辅助 ──

  Color _hexToColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      return Color(int.parse('0xFF$clean'));
    }
    if (clean.length == 8) {
      final a = int.parse(clean.substring(6, 8), radix: 16) / 255.0;
      final r = int.parse(clean.substring(0, 2), radix: 16);
      final g = int.parse(clean.substring(2, 4), radix: 16);
      final b = int.parse(clean.substring(4, 6), radix: 16);
      return Color.fromARGB((a * 255).round(), r, g, b);
    }
    return const Color(0xFFFFFFFF);
  }
}

// ── 内部辅助类型 ──

/// 搜索结果项。
class _SearchResultItem {
  final String cfi;
  final String text;
  final String contextText;
  final String? _canonicalLocator;

  const _SearchResultItem({
    required this.cfi,
    required this.text,
    required this.contextText,
    String? canonicalLocator,
  }) : _canonicalLocator = canonicalLocator;

  /// 用于导航跳转的 canonical locator（当前搜索结果未填充，保留扩展能力）。
  String? get canonicalLocator => _canonicalLocator;
}

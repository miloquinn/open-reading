// 文件说明：EpubPlayer 组件——封装 Foliate WebView 与 FoliateBridge 双向通信，
// 仅负责 WebView 生命周期与 FoliateBridge 协议的桥接；批注 UI、搜索面板、
// TTS 控制等上层交互由 FoliateReaderPage 承担。
// 技术要点：InAppWebView、FoliateBridgeImpl、CanonicalLocator/RenderedLocator 双轨定位模型、ReaderTheme。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:xxread/core/reader/foliate_bridge.dart';
import 'package:xxread/core/reader/canonical_locator.dart';
import 'package:xxread/core/reader/reader_theme.dart';

// ============================================================================
// EpubPlayer Widget
// ============================================================================

/// EpubPlayer 组件——封装 Foliate WebView 与 FoliateBridge 双向通信。
///
/// 通过 [FoliateBridgeImpl] 将 Dart 方法调用翻译为
/// `window.origoFoliateHost.xxx(...)` JS 调用，并通过
/// `txtFoliate` message handler 接收 JS host 回发的统一事件信封。
///
/// 阅读位置使用 [CanonicalLocator]/[RenderedLocator] 双轨模型：
/// 持久化使用 canonical locator；当前设备显示使用 rendered locator。
/// 任何批注/同步/跳转逻辑必须能从 canonical anchor 重新投影到当前 renderer。
///
/// 上层交互（批注 context menu、搜索面板、TTS 控制栏、书签按钮等）
/// 不在此组件中处理——由 [FoliateReaderPage] 通过公开 API 和事件回调承担。
class EpubPlayer extends StatefulWidget {
  /// 打开文档时传递给 JS host 的载荷。
  final FoliateOpenPayload openPayload;

  /// 初始阅读主题，用于构造 FoliatePreferencesPayload 并注入样式。
  final ReaderTheme theme;

  /// 阅读位置重定位回调（包含 canonical 与 rendered 双轨定位信息）。
  final ValueChanged<FoliateRelocateEvent>? onRelocate;

  /// 文本选中回调。
  final ValueChanged<FoliateSelectionEvent>? onSelection;

  /// 注释被激活（点击）回调。
  final ValueChanged<FoliateAnnotationActivatedEvent>? onAnnotationActivated;

  /// 搜索结果回调。
  final ValueChanged<FoliateSearchResultEvent>? onSearchResult;

  /// TTS 朗读片段回调。
  final ValueChanged<FoliateTTSUtteranceEvent>? onTTSUtterance;

  /// 目录更新回调。
  final ValueChanged<FoliateTocEvent>? onToc;

  /// JS host 错误回调。
  final ValueChanged<FoliateErrorEvent>? onError;

  /// 文档打开完成回调（JS host 已完成渲染首屏）。
  final VoidCallback? onOpened;

  const EpubPlayer({
    super.key,
    required this.openPayload,
    required this.theme,
    this.onRelocate,
    this.onSelection,
    this.onAnnotationActivated,
    this.onSearchResult,
    this.onTTSUtterance,
    this.onToc,
    this.onError,
    this.onOpened,
  });

  @override
  State<EpubPlayer> createState() => EpubPlayerState();
}

// ============================================================================
// EpubPlayerState
// ============================================================================

class EpubPlayerState extends State<EpubPlayer> {
  final FoliateBridgeImpl _bridge = FoliateBridgeImpl();

  // ── 阅读状态（双轨定位模型） ──

  CanonicalLocator? _lastCanonicalLocator;
  RenderedLocator? _lastRenderedLocator;
  String? _lastCfi;
  List<Map<String, dynamic>> _tocItems = [];
  String _chapterTitle = '';
  int _currentPage = 1;
  int _totalPages = 1;
  double _progression = 0.0;

  // ── 公开 API ──

  /// JS host 是否就绪。
  bool get isReady => _bridge.isHostReady;

  /// 文档是否已打开。
  bool get isOpened => _bridge.isHostOpened;

  /// 最近一次 canonical locator（布局无关定位真相源）。
  CanonicalLocator? get lastCanonicalLocator => _lastCanonicalLocator;

  /// 最近一次 rendered locator（当前设备 + 当前排版参数的实际屏幕位置）。
  RenderedLocator? get lastRenderedLocator => _lastRenderedLocator;

  /// 最近一次 CFI（从 canonical locator fragments 或 href 中提取）。
  String? get lastCfi => _lastCfi;

  /// 目录项列表。
  List<Map<String, dynamic>> get tocItems => List.unmodifiable(_tocItems);

  /// 当前章节标题。
  String get chapterTitle => _chapterTitle;

  /// 当前页码（1-based，来自 renderedLocator.position 或 relocate 事件）。
  int get currentPage => _currentPage;

  /// 总页数（来自 renderedLocator.totalPositions 或 relocate 事件）。
  int get totalPages => _totalPages;

  /// 进度百分比（0.0~1.0，来自 canonicalLocator.progression）。
  double get progression => _progression;

  // ── 翻页与跳转 ──

  /// 前进/后退翻页。delta 正数前进、负数后退。
  void step(int delta) => _bridge.step(delta);

  /// 跳转到 EPUB CFI。
  void goToCfi(String cfi) => _bridge.goToCfi(cfi);

  /// 跳转到百分比位置 (0.0 ~ 1.0)。
  void goToPercent(double fraction) => _bridge.goToPercent(fraction);

  /// 跳转到 canonical locator 序列化字符串（持久化真相源）。
  void goToCanonical(String serialized) => _bridge.goToCanonical(serialized);

  /// 跳转到 rendered locator 序列化字符串（当前设备派生定位）。
  void goToRendered(String serialized) => _bridge.goToRendered(serialized);

  // ── 主题与排版 ──

  /// 更新阅读主题，将 [ReaderTheme] 转换为 [FoliatePreferencesPayload]
  /// 并通过 bridge.updatePreferences() 注入到 JS host。
  void updateTheme(ReaderTheme theme) {
    final prefs = _preferencesFromTheme(theme);
    _bridge.updatePreferences(prefs);
  }

  // ── 批注 overlay ──

  /// 添加高亮/批注 overlay 到 JS host。
  void addAnnotation(AnnotationData annotation) =>
      _bridge.addAnnotation(annotation);

  /// 移除指定高亮/批注 overlay。
  void removeAnnotation(String annotationId) =>
      _bridge.removeAnnotation(annotationId);

  /// 向 JS host 渲染一组批注 overlay。
  void renderAnnotations(List<AnnotationData> annotations) =>
      _bridge.renderAnnotations(annotations);

  // ── 搜索 ──

  /// 执行搜索。
  void search(SearchConfig config) => _bridge.search(config);

  /// 清除搜索结果和搜索状态。
  void clearSearch() => _bridge.clearSearch();

  // ── TTS ──

  /// 初始化 TTS 朗读。
  void initTTS() => _bridge.initTTS();

  /// TTS 下一段。
  void ttsNext() => _bridge.ttsNext();

  /// 停止 TTS。
  void ttsStop() => _bridge.ttsStop();

  // ── 其他 ──

  /// 清除文本选中。
  void clearSelection() => _bridge.clearSelection();

  /// 获取当前阅读状态快照（同步 JS 返回值）。
  Future<Map<String, dynamic>?> snapshot() => _bridge.snapshot();

  /// 重新打开文档（更换 payload 与主题）。
  void reopen(FoliateOpenPayload payload, ReaderTheme theme) {
    final prefs = _preferencesFromTheme(theme);
    _bridge.open(payload, prefs);
  }

  // ── 内部：FoliatePreferencesPayload 从 ReaderTheme ──

  /// 从 [ReaderTheme] 构造 [FoliatePreferencesPayload]。
  ///
  /// viewportWidth/viewportHeight 从当前 [MediaQuery] 获取；
  /// fontSize 从 ReaderTheme 的 scale 值转换为像素值（×16）；
  /// 颜色从 hex (#RRGGBB) 格式转换为 rgba(...) 格式。
  FoliatePreferencesPayload _preferencesFromTheme(ReaderTheme theme) {
    final mq = MediaQuery.maybeOf(context);
    final viewportWidth = mq?.size.width ?? 600.0;
    final viewportHeight = mq?.size.height ?? 800.0;
    final fontSizePx = theme.fontSize * 16;

    final gestureMode =
        theme.gestureNavigationMode == GestureNavigationMode.swipe
            ? 'swipe'
            : theme.gestureNavigationMode == GestureNavigationMode.none
                ? 'none'
                : 'native';

    return FoliatePreferencesPayload(
      fontSize: fontSizePx,
      lineHeight: theme.lineHeight,
      pageMargin: theme.pageMargin,
      topSafeAreaInset: theme.topMargin,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      fontFamily: theme.fontFamily,
      backgroundColor: _hexToRgba(theme.backgroundColor),
      textColor: _hexToRgba(theme.textColor),
      selectionColor: _hexToRgba(theme.selectionColor),
      maxInlineSize: theme.maxInlineSize,
      maxBlockSize: theme.maxBlockSize,
      verticalScroll: theme.verticalScroll,
      animated: theme.animated,
      isDark: theme.isDark,
      gestureNavigationMode: gestureMode,
    );
  }

  /// Hex 颜色字符串 (#RRGGBB 或 #RRGGBBAA) -> rgba(...) 格式。
  static String _hexToRgba(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      final r = int.parse(clean.substring(0, 2), radix: 16);
      final g = int.parse(clean.substring(2, 4), radix: 16);
      final b = int.parse(clean.substring(4, 6), radix: 16);
      return 'rgba($r,$g,$b,1)';
    }
    if (clean.length == 8) {
      final r = int.parse(clean.substring(0, 2), radix: 16);
      final g = int.parse(clean.substring(2, 4), radix: 16);
      final b = int.parse(clean.substring(4, 6), radix: 16);
      final a = int.parse(clean.substring(6, 8), radix: 16) / 255.0;
      return 'rgba($r,$g,$b,${a.toStringAsFixed(3)})';
    }
    return hex;
  }

  // ── 内部：事件回调 ──

  void _onHostReady() {
    debugPrint('[EpubPlayer] Host ready, opening book');
    // Host 就绪后立即使用当前 payload 和 theme 打开文档
    final prefs = _preferencesFromTheme(widget.theme);
    _bridge.open(widget.openPayload, prefs);
  }

  void _onHostOpened() {
    debugPrint('[EpubPlayer] Host opened, book rendered');
    widget.onOpened?.call();
  }

  void _onRelocate(FoliateRelocateEvent event) {
    setState(() {
      _chapterTitle = event.href ?? '';
      _currentPage = event.currentPage;
      _totalPages = event.totalPages;
      _progression = event.progression;

      // 解析 canonical 与 rendered locator
      if (event.canonicalLocator != null) {
        try {
          _lastCanonicalLocator =
              CanonicalLocator.fromJson(event.canonicalLocator!);
        } catch (e) {
          debugPrint('[EpubPlayer] Failed to parse canonicalLocator: $e');
        }
      }
      if (event.renderedLocator != null) {
        try {
          _lastRenderedLocator =
              RenderedLocator.fromJson(event.renderedLocator!);
        } catch (e) {
          debugPrint('[EpubPlayer] Failed to parse renderedLocator: $e');
        }
      }

      // CFI 从 canonical locator fragments 或 href 中提取
      if (_lastCanonicalLocator != null) {
        final fragments = _lastCanonicalLocator!.fragments;
        if (fragments.isNotEmpty) {
          _lastCfi = fragments.first;
        } else if (_lastCanonicalLocator!.href != null) {
          _lastCfi = _lastCanonicalLocator!.href;
        }
      }
    });
    widget.onRelocate?.call(event);
  }

  void _onSelection(FoliateSelectionEvent event) {
    widget.onSelection?.call(event);
  }

  void _onAnnotationActivated(FoliateAnnotationActivatedEvent event) {
    widget.onAnnotationActivated?.call(event);
  }

  void _onSearchResult(FoliateSearchResultEvent event) {
    widget.onSearchResult?.call(event);
  }

  void _onTTSUtterance(FoliateTTSUtteranceEvent event) {
    widget.onTTSUtterance?.call(event);
  }

  void _onToc(FoliateTocEvent event) {
    setState(() => _tocItems = event.tocItems);
    widget.onToc?.call(event);
  }

  void _onError(FoliateErrorEvent event) {
    debugPrint(
      '[EpubPlayer] Host error [${event.code}] ${event.message} '
      '${event.details ?? ''}',
    );
    widget.onError?.call(event);
  }

  // ── Lifecycle ──

  @override
  void initState() {
    super.initState();
    _bridge.registerEventHandlers(
      onReady: _onHostReady,
      onOpened: _onHostOpened,
      onRelocate: _onRelocate,
      onSelection: _onSelection,
      onAnnotationActivated: _onAnnotationActivated,
      onSearchResult: _onSearchResult,
      onTTSUtterance: _onTTSUtterance,
      onToc: _onToc,
      onError: _onError,
    );
  }

  @override
  void didUpdateWidget(EpubPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 主题变更时自动更新排版偏好
    if (widget.theme != oldWidget.theme && _bridge.isHostOpened) {
      updateTheme(widget.theme);
    }
  }

  @override
  void dispose() {
    _bridge.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialFile: 'assets/foliate-js/index.html',
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        allowFileAccess: true,
        supportZoom: false,
        useHybridComposition: true,
      ),
      onWebViewCreated: (controller) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          InAppWebViewController.setWebContentsDebuggingEnabled(true);
        }
        _bridge.attach(controller);
      },
    );
  }
}

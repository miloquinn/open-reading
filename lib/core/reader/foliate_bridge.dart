// 文件说明：Foliate JS Bridge 协议与实现——封装 WebView 与 Foliate host 的双向通信。
// 技术要点：InAppWebView、JS Bridge、canonical/rendered 双轨定位模型。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// ============================================================================
// Payload 类型
// ============================================================================

/// 打开文档时传递给 JS host 的载荷。
@immutable
class FoliateOpenPayload {
  final String? manifestURL;
  final String bookId;
  final String bookTitle;
  final String language;
  final String direction;
  final int estimatedTotalPages;
  final String? initialLocator;
  final String? initialCanonicalLocator;
  final String? initialRenderedLocator;
  final bool enableDebugTrace;

  const FoliateOpenPayload({
    this.manifestURL,
    required this.bookId,
    required this.bookTitle,
    required this.language,
    this.direction = 'ltr',
    this.estimatedTotalPages = 1,
    this.initialLocator,
    this.initialCanonicalLocator,
    this.initialRenderedLocator,
    this.enableDebugTrace = false,
  });

  Map<String, dynamic> toJson() => {
    'manifestURL': manifestURL,
    'bookId': bookId,
    'bookTitle': bookTitle,
    'language': language,
    'direction': direction,
    'estimatedTotalPages': estimatedTotalPages,
    'initialLocator': initialLocator,
    'initialCanonicalLocator': initialCanonicalLocator,
    'initialRenderedLocator': initialRenderedLocator,
    'enableDebugTrace': enableDebugTrace,
  };

  factory FoliateOpenPayload.fromJson(Map<String, dynamic> json) =>
      FoliateOpenPayload(
        manifestURL: json['manifestURL'] as String?,
        bookId: json['bookId'] as String,
        bookTitle: json['bookTitle'] as String,
        language: json['language'] as String,
        direction: json['direction'] as String? ?? 'ltr',
        estimatedTotalPages: json['estimatedTotalPages'] as int? ?? 1,
        initialLocator: json['initialLocator'] as String?,
        initialCanonicalLocator: json['initialCanonicalLocator'] as String?,
        initialRenderedLocator: json['initialRenderedLocator'] as String?,
        enableDebugTrace: json['enableDebugTrace'] as bool? ?? false,
      );
}

/// 排版偏好更新时传递给 JS host 的载荷。
@immutable
class FoliatePreferencesPayload {
  final double fontSize;
  final double lineHeight;
  final double pageMargin;
  final double topSafeAreaInset;
  final double viewportWidth;
  final double viewportHeight;
  final String fontFamily;
  final String backgroundColor;
  final String textColor;
  final String selectionColor;
  final double maxInlineSize;
  final double maxBlockSize;
  final bool verticalScroll;
  final bool animated;
  final bool isDark;
  final String gestureNavigationMode;

  const FoliatePreferencesPayload({
    required this.fontSize,
    required this.lineHeight,
    required this.pageMargin,
    this.topSafeAreaInset = 0,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.fontFamily,
    required this.backgroundColor,
    required this.textColor,
    required this.selectionColor,
    required this.maxInlineSize,
    required this.maxBlockSize,
    this.verticalScroll = false,
    this.animated = false,
    this.isDark = false,
    this.gestureNavigationMode = 'native',
  });

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'pageMargin': pageMargin,
    'topSafeAreaInset': topSafeAreaInset,
    'viewportWidth': viewportWidth,
    'viewportHeight': viewportHeight,
    'fontFamily': fontFamily,
    'backgroundColor': backgroundColor,
    'textColor': textColor,
    'selectionColor': selectionColor,
    'maxInlineSize': maxInlineSize,
    'maxBlockSize': maxBlockSize,
    'verticalScroll': verticalScroll,
    'animated': animated,
    'isDark': isDark,
    'gestureNavigationMode': gestureNavigationMode,
  };

  factory FoliatePreferencesPayload.fromJson(Map<String, dynamic> json) =>
      FoliatePreferencesPayload(
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.7,
        pageMargin: (json['pageMargin'] as num?)?.toDouble() ?? 24,
        topSafeAreaInset: (json['topSafeAreaInset'] as num?)?.toDouble() ?? 0,
        viewportWidth: (json['viewportWidth'] as num?)?.toDouble() ?? 280,
        viewportHeight: (json['viewportHeight'] as num?)?.toDouble() ?? 320,
        fontFamily: json['fontFamily'] as String? ?? 'sans-serif',
        backgroundColor: json['backgroundColor'] as String? ?? 'rgba(255,255,255,1)',
        textColor: json['textColor'] as String? ?? 'rgba(0,0,0,1)',
        selectionColor: json['selectionColor'] as String? ?? 'rgba(255,220,0,0.35)',
        maxInlineSize: (json['maxInlineSize'] as num?)?.toDouble() ?? 280,
        maxBlockSize: (json['maxBlockSize'] as num?)?.toDouble() ?? 320,
        verticalScroll: json['verticalScroll'] as bool? ?? false,
        animated: json['animated'] as bool? ?? false,
        isDark: json['isDark'] as bool? ?? false,
        gestureNavigationMode: json['gestureNavigationMode'] as String? ?? 'native',
      );
}

/// 高亮/批注数据，用于 addAnnotation 与 renderAnnotations。
@immutable
class AnnotationData {
  final String id;
  final String type;
  final String value;
  final String color;
  final String? note;
  final int? canonicalStart;
  final int? canonicalEnd;

  const AnnotationData({
    required this.id,
    required this.type,
    required this.value,
    required this.color,
    this.note,
    this.canonicalStart,
    this.canonicalEnd,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'value': value,
    'color': color,
    'note': note,
    'canonicalStart': canonicalStart,
    'canonicalEnd': canonicalEnd,
  };

  factory AnnotationData.fromJson(Map<String, dynamic> json) => AnnotationData(
    id: json['id'] as String,
    type: json['type'] as String,
    value: json['value'] as String,
    color: json['color'] as String,
    note: json['note'] as String?,
    canonicalStart: json['canonicalStart'] as int?,
    canonicalEnd: json['canonicalEnd'] as int?,
  );
}

/// 搜索配置参数。
@immutable
class SearchConfig {
  final String query;
  final String scope;
  final bool matchCase;
  final bool matchDiacritics;
  final bool matchWholeWords;

  const SearchConfig({
    required this.query,
    this.scope = 'book',
    this.matchCase = false,
    this.matchDiacritics = false,
    this.matchWholeWords = false,
  });

  Map<String, dynamic> toJson() => {
    'query': query,
    'scope': scope,
    'matchCase': matchCase,
    'matchDiacritics': matchDiacritics,
    'matchWholeWords': matchWholeWords,
  };

  factory SearchConfig.fromJson(Map<String, dynamic> json) => SearchConfig(
    query: json['query'] as String,
    scope: json['scope'] as String? ?? 'book',
    matchCase: json['matchCase'] as bool? ?? false,
    matchDiacritics: json['matchDiacritics'] as bool? ?? false,
    matchWholeWords: json['matchWholeWords'] as bool? ?? false,
  );
}

// ============================================================================
// 事件类型
// ============================================================================

/// JS host 已就绪事件。
@immutable
class FoliateReadyEvent {
  const FoliateReadyEvent();
}

/// 文档已打开事件。
@immutable
class FoliateOpenedEvent {
  const FoliateOpenedEvent();
}

/// 阅读位置重定位事件，包含 canonical 与 rendered 双轨定位信息。
@immutable
class FoliateRelocateEvent {
  final String rendererType;
  final int currentPage;
  final int totalPages;
  final int windowPageIndex;
  final int windowPageCount;
  final int globalPageIndex;
  final int globalPageCount;
  final String? href;
  final int? syntheticChapterIndex;
  final String? syntheticChapterID;
  final int? sourceChapterIndex;
  final String? sourceChapterID;
  final double progression;
  final Map<String, dynamic>? renderedLocator;
  final Map<String, dynamic>? canonicalLocator;
  final String currentPageText;

  const FoliateRelocateEvent({
    this.rendererType = 'foliate',
    this.currentPage = 0,
    this.totalPages = 1,
    this.windowPageIndex = 0,
    this.windowPageCount = 1,
    this.globalPageIndex = 0,
    this.globalPageCount = 1,
    this.href,
    this.syntheticChapterIndex,
    this.syntheticChapterID,
    this.sourceChapterIndex,
    this.sourceChapterID,
    this.progression = 0,
    this.renderedLocator,
    this.canonicalLocator,
    this.currentPageText = '',
  });

  factory FoliateRelocateEvent.fromJson(Map<String, dynamic> json) =>
      FoliateRelocateEvent(
        rendererType: json['rendererType'] as String? ?? 'foliate',
        currentPage: (json['currentPage'] as num?)?.toInt() ?? 0,
        totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
        windowPageIndex: (json['windowPageIndex'] as num?)?.toInt() ?? 0,
        windowPageCount: (json['windowPageCount'] as num?)?.toInt() ?? 1,
        globalPageIndex: (json['globalPageIndex'] as num?)?.toInt() ?? 0,
        globalPageCount: (json['globalPageCount'] as num?)?.toInt() ?? 1,
        href: json['href'] as String?,
        syntheticChapterIndex: json['syntheticChapterIndex'] as int?,
        syntheticChapterID: json['syntheticChapterID'] as String?,
        sourceChapterIndex: json['sourceChapterIndex'] as int?,
        sourceChapterID: json['sourceChapterID'] as String?,
        progression: (json['progression'] as num?)?.toDouble() ?? 0,
        renderedLocator: json['renderedLocator'] as Map<String, dynamic>?,
        canonicalLocator: json['canonicalLocator'] as Map<String, dynamic>?,
        currentPageText: json['currentPageText'] as String? ?? '',
      );
}

/// 文本选中事件。
@immutable
class FoliateSelectionEvent {
  final String text;
  final String? chapterID;
  final int? canonicalStart;
  final int? canonicalEnd;
  final String? prefix;
  final String? suffix;
  final int pageIndex;
  final Map<String, dynamic>? renderedLocator;

  const FoliateSelectionEvent({
    this.text = '',
    this.chapterID,
    this.canonicalStart,
    this.canonicalEnd,
    this.prefix,
    this.suffix,
    this.pageIndex = 0,
    this.renderedLocator,
  });

  factory FoliateSelectionEvent.fromJson(Map<String, dynamic> json) =>
      FoliateSelectionEvent(
        text: json['text'] as String? ?? '',
        chapterID: json['chapterID'] as String?,
        canonicalStart: json['canonicalStart'] as int?,
        canonicalEnd: json['canonicalEnd'] as int?,
        prefix: json['prefix'] as String?,
        suffix: json['suffix'] as String?,
        pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
        renderedLocator: json['renderedLocator'] as Map<String, dynamic>?,
      );
}

/// 注释被激活（点击）事件。
@immutable
class FoliateAnnotationActivatedEvent {
  final String annotationId;
  final int? pageIndex;

  const FoliateAnnotationActivatedEvent({
    required this.annotationId,
    this.pageIndex,
  });

  factory FoliateAnnotationActivatedEvent.fromJson(Map<String, dynamic> json) =>
      FoliateAnnotationActivatedEvent(
        annotationId: json['annotationId'] as String? ?? '',
        pageIndex: json['pageIndex'] as int?,
      );
}

/// 搜索结果事件。
@immutable
class FoliateSearchResultEvent {
  /// 进度值 (0.0 ~ 1.0)，null 表示这是一条结果而非进度更新。
  final double? progress;

  /// 单条搜索结果；progress != null 时为 null。
  final String? cfi;
  final String? text;
  final String? contextText;

  const FoliateSearchResultEvent({
    this.progress,
    this.cfi,
    this.text,
    this.contextText,
  });

  factory FoliateSearchResultEvent.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('process')) {
      return FoliateSearchResultEvent(
        progress: (json['process'] as num?)?.toDouble(),
      );
    }
    return FoliateSearchResultEvent(
      cfi: json['cfi'] as String?,
      text: json['text'] as String?,
      contextText: json['contextText'] as String?,
    );
  }
}

/// TTS 朗读片段事件。
@immutable
class FoliateTTSUtteranceEvent {
  final String text;
  final Map<String, dynamic>? locator;

  const FoliateTTSUtteranceEvent({
    required this.text,
    this.locator,
  });

  factory FoliateTTSUtteranceEvent.fromJson(Map<String, dynamic> json) =>
      FoliateTTSUtteranceEvent(
        text: json['text'] as String? ?? '',
        locator: json['locator'] as Map<String, dynamic>?,
      );
}

/// 目录更新事件。
@immutable
class FoliateTocEvent {
  final List<Map<String, dynamic>> tocItems;

  const FoliateTocEvent({this.tocItems = const []});

  factory FoliateTocEvent.fromJson(Map<String, dynamic> json) =>
      FoliateTocEvent(
        tocItems: (json['toc'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ?? const [],
      );
}

/// JS host 错误事件。
@immutable
class FoliateErrorEvent {
  final String code;
  final String message;
  final String? details;
  final String? stack;

  const FoliateErrorEvent({
    this.code = 'unknown',
    this.message = 'Unknown Foliate host error',
    this.details,
    this.stack,
  });

  factory FoliateErrorEvent.fromJson(Map<String, dynamic> json) =>
      FoliateErrorEvent(
        code: json['code'] as String? ?? 'unknown',
        message: json['message'] as String? ?? 'Unknown Foliate host error',
        details: json['details'] as String?,
        stack: json['stack'] as String?,
      );
}

// ============================================================================
// Bridge 协议
// ============================================================================

/// FoliateBridge 协议接口，定义所有与 JS host 通信的方法。
///
/// Flutter 侧的消费方只依赖此协议，不依赖具体 WebView 实现；
/// 方便未来切换渲染内核或做测试替身。
abstract class FoliateBridgeProtocol {
  /// 打开文档。JS host 收到后会初始化 Foliate 阅读器并渲染首屏。
  void open(FoliateOpenPayload payload, FoliatePreferencesPayload preferences);

  /// 更新排版偏好（字号、行高、边距等），JS host 会重新排版。
  void updatePreferences(FoliatePreferencesPayload preferences);

  /// 前进/后退翻页。delta 正数前进、负数后退。
  void step(int delta);

  /// 跳转到 canonical locator 字符串（持久化真相源）。
  void goToCanonical(String serialized);

  /// 跳转到 rendered locator 字符串（当前设备派生定位）。
  void goToRendered(String serialized);

  /// 跳转到 EPUB CFI。
  void goToCfi(String cfi);

  /// 跳转到百分比位置 (0.0 ~ 1.0)。
  void goToPercent(double percent);

  /// 获取当前阅读状态快照（同步 JS 返回值）。
  Future<Map<String, dynamic>?> snapshot();

  /// 添加高亮/批注到 JS host overlay。
  void addAnnotation(AnnotationData annotation);

  /// 移除指定高亮/批注。
  void removeAnnotation(String annotationId);

  /// 向 JS host 渲染一组批注 overlay。
  void renderAnnotations(List<AnnotationData> annotations);

  /// 执行搜索。
  void search(SearchConfig config);

  /// 清除搜索结果和搜索状态。
  void clearSearch();

  /// 初始化 TTS 朗读。
  void initTTS();

  /// TTS 下一段。
  void ttsNext();

  /// 停止 TTS。
  void ttsStop();

  /// 清除文本选中。
  void clearSelection();

  /// 注册事件回调。
  void registerEventHandlers({
    VoidCallback? onReady,
    VoidCallback? onOpened,
    ValueChanged<FoliateRelocateEvent>? onRelocate,
    ValueChanged<FoliateSelectionEvent>? onSelection,
    ValueChanged<FoliateAnnotationActivatedEvent>? onAnnotationActivated,
    ValueChanged<FoliateSearchResultEvent>? onSearchResult,
    ValueChanged<FoliateTTSUtteranceEvent>? onTTSUtterance,
    ValueChanged<FoliateTocEvent>? onToc,
    ValueChanged<FoliateErrorEvent>? onError,
  });
}

// ============================================================================
// Bridge 实现
// ============================================================================

/// 基于 InAppWebViewController 的 FoliateBridge 实现。
///
/// 通过 `_callMethod` 模式将 Dart 方法调用翻译为
/// `window.origoFoliateHost.xxx(...)` JS 调用，
/// 并通过 JavaScript Handler 接收 JS host 回发的事件。
class FoliateBridgeImpl implements FoliateBridgeProtocol {
  InAppWebViewController? _controller;

  // 事件回调
  VoidCallback? _onReady;
  VoidCallback? _onOpened;
  ValueChanged<FoliateRelocateEvent>? _onRelocate;
  ValueChanged<FoliateSelectionEvent>? _onSelection;
  ValueChanged<FoliateAnnotationActivatedEvent>? _onAnnotationActivated;
  ValueChanged<FoliateSearchResultEvent>? _onSearchResult;
  ValueChanged<FoliateTTSUtteranceEvent>? _onTTSUtterance;
  ValueChanged<FoliateTocEvent>? _onToc;
  ValueChanged<FoliateErrorEvent>? _onError;

  // JS host 状态跟踪（与 iOS Coordinator 对齐）
  bool _isHostReady = false;
  bool _isHostOpened = false;

  /// JS Bridge handler 名称，与 iOS TXTFoliateReaderView 对齐。
  static const _messageHandlerName = 'txtFoliate';

  /// 将 WebView 控制器绑定到 Bridge，同时注册 JS 事件监听。
  void attach(InAppWebViewController controller) {
    _controller = controller;
    _registerEventHandlersOnController(controller);
  }

  /// 解绑 WebView 控制器。
  void detach() {
    _controller = null;
    _isHostReady = false;
    _isHostOpened = false;
  }

  bool get isHostReady => _isHostReady;
  bool get isHostOpened => _isHostOpened;

  // ---- 协议方法实现 ----

  @override
  void open(FoliateOpenPayload payload, FoliatePreferencesPayload preferences) {
    _callMethod('open', [payload.toJson(), preferences.toJson()]);
  }

  @override
  void updatePreferences(FoliatePreferencesPayload preferences) {
    _callMethod('updatePreferences', preferences.toJson());
  }

  @override
  void step(int delta) {
    _callMethod('step', delta);
  }

  @override
  void goToCanonical(String serialized) {
    _callMethod('goToCanonical', serialized);
  }

  @override
  void goToRendered(String serialized) {
    _callMethod('goToRendered', serialized);
  }

  @override
  void goToCfi(String cfi) {
    _callMethod('goToCfi', cfi);
  }

  @override
  void goToPercent(double percent) {
    _callMethod('goToPercent', percent);
  }

  @override
  Future<Map<String, dynamic>?> snapshot() async {
    final controller = _controller;
    if (controller == null || !_isHostReady || !_isHostOpened) return null;

    final script = '''
      (() => {
        if (!window.origoFoliateHost) { return null; }
        return window.origoFoliateHost.snapshot();
      })();
    ''';

    try {
      final result = await controller.evaluateJavascript(source: script);
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      debugPrint('[FoliateBridge] snapshot request failed: $e');
      return null;
    }
  }

  @override
  void addAnnotation(AnnotationData annotation) {
    _callMethod('addAnnotation', annotation.toJson());
  }

  @override
  void removeAnnotation(String annotationId) {
    _callMethod('removeAnnotation', annotationId);
  }

  @override
  void renderAnnotations(List<AnnotationData> annotations) {
    _callMethod('renderAnnotations', annotations.map((a) => a.toJson()).toList());
  }

  @override
  void search(SearchConfig config) {
    _callMethod('search', [config.toJson()]);
  }

  @override
  void clearSearch() {
    _callMethod('clearSearch');
  }

  @override
  void initTTS() {
    _callMethod('initTTS');
  }

  @override
  void ttsNext() {
    _callMethod('ttsNext');
  }

  @override
  void ttsStop() {
    _callMethod('ttsStop');
  }

  @override
  void clearSelection() {
    _callMethod('clearSelection');
  }

  @override
  void registerEventHandlers({
    VoidCallback? onReady,
    VoidCallback? onOpened,
    ValueChanged<FoliateRelocateEvent>? onRelocate,
    ValueChanged<FoliateSelectionEvent>? onSelection,
    ValueChanged<FoliateAnnotationActivatedEvent>? onAnnotationActivated,
    ValueChanged<FoliateSearchResultEvent>? onSearchResult,
    ValueChanged<FoliateTTSUtteranceEvent>? onTTSUtterance,
    ValueChanged<FoliateTocEvent>? onToc,
    ValueChanged<FoliateErrorEvent>? onError,
  }) {
    _onReady = onReady;
    _onOpened = onOpened;
    _onRelocate = onRelocate;
    _onSelection = onSelection;
    _onAnnotationActivated = onAnnotationActivated;
    _onSearchResult = onSearchResult;
    _onTTSUtterance = onTTSUtterance;
    _onToc = onToc;
    _onError = onError;
  }

  // ---- 内部实现 ----

  /// 调用 JS host 方法，与 iOS evaluate(function:...) 对齐。
  ///
  /// 无参数时调用 `window.origoFoliateHost.xxx()`；
  /// 有参数时调用 `window.origoFoliateHost.xxx(arg1, arg2, ...)`，
  /// 参数通过 jsonEncode 序列化传递。
  void _callMethod(String method, [dynamic argument]) {
    final controller = _controller;
    if (controller == null) return;

    final String source;
    if (argument == null) {
      source = '''
        if (!window.origoFoliateHost) {
          throw new Error('TXTFoliate host unavailable');
        }
        window.origoFoliateHost.$method();
        null;
      ''';
    } else if (argument is List) {
      final argsJson = argument.map((a) => jsonEncode(a)).join(', ');
      source = '''
        if (!window.origoFoliateHost) {
          throw new Error('TXTFoliate host unavailable');
        }
        window.origoFoliateHost.$method($argsJson);
        null;
      ''';
    } else {
      source = '''
        if (!window.origoFoliateHost) {
          throw new Error('TXTFoliate host unavailable');
        }
        window.origoFoliateHost.$method(${jsonEncode(argument)});
        null;
      ''';
    }

    controller.evaluateJavascript(source: source).catchError((error) {
      debugPrint('[FoliateBridge] JS evaluation failed for $method: $error');
      return null;
    });
  }

  /// 在 WebView 控制器上注册 JS 事件 Handler，与 iOS Coordinator.userContentController 对齐。
  void _registerEventHandlersOnController(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: _messageHandlerName,
      callback: _handleJavaScriptMessage,
    );
  }

  /// 处理 JS host 回发的消息信封，与 iOS TXTFoliateMessageEnvelope 解析对齐。
  dynamic _handleJavaScriptMessage(List<dynamic> args) {
    if (args.isEmpty || args.first is! Map) return null;

    final body = Map<String, dynamic>.from(args.first as Map);
    final type = body['type'] as String? ?? '';
    final payload = body['payload'] as Map<String, dynamic>?;

    switch (type) {
      case 'ready':
        _isHostReady = true;
        debugPrint('[FoliateBridge] Host ready');
        _onReady?.call();
        break;

      case 'opened':
        _isHostOpened = true;
        debugPrint('[FoliateBridge] Host opened');
        _onOpened?.call();
        break;

      case 'relocate':
        if (payload != null) {
          final event = FoliateRelocateEvent.fromJson(payload);
          _onRelocate?.call(event);
        }
        break;

      case 'selection':
        if (payload != null) {
          final event = FoliateSelectionEvent.fromJson(payload);
          _onSelection?.call(event);
        }
        break;

      case 'annotation-activated':
        if (payload != null) {
          final event = FoliateAnnotationActivatedEvent.fromJson(payload);
          _onAnnotationActivated?.call(event);
        }
        break;

      case 'search':
        if (payload != null) {
          final event = FoliateSearchResultEvent.fromJson(payload);
          _onSearchResult?.call(event);
        }
        break;

      case 'tts-utterance':
        if (payload != null) {
          final event = FoliateTTSUtteranceEvent.fromJson(payload);
          _onTTSUtterance?.call(event);
        }
        break;

      case 'toc':
        if (payload != null) {
          final event = FoliateTocEvent.fromJson(payload);
          _onToc?.call(event);
        }
        break;

      case 'error':
        if (payload != null) {
          final event = FoliateErrorEvent.fromJson(payload);
          debugPrint(
            '[FoliateBridge] Host error [${event.code}] ${event.message} '
            '${event.details ?? ''} ${event.stack ?? ''}',
          );
          _onError?.call(event);
        }
        break;

      case 'trace':
        final traceMessage = payload?['message'] as String? ?? '';
        final traceDetails = payload?['details'] as String? ?? '';
        debugPrint('[FoliateBridge] Trace $traceMessage $traceDetails');
        break;

      default:
        break;
    }

    return null;
  }
}

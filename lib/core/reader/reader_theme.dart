// 文件说明：阅读器主题模型与 CSS 生成——定义 ReaderTheme 数据类、13 种预设主题、
// CJK 字体栈、缓存签名、JSON 持久化，以及为 foliate-view renderer.setStyles() 生成完整 CSS。
// 技术要点：SHA-256 cacheSignature、layout-affecting 字段筛选、CSS 变量体系对齐 Readest。

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// 将字节列表转为十六进制字符串（纯 Dart 实现，避免引入 convert 包）。
String _bytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// CJK 字体栈预设，用于构建 CSS font-family 声明。
class CjkFontStack {
  final String label;
  final List<String> serifFonts;
  final List<String> sansSerifFonts;
  final List<String> monoFonts;

  const CjkFontStack({
    required this.label,
    required this.serifFonts,
    required this.sansSerifFonts,
    required this.monoFonts,
  });

  /// 生成 CSS font-family 声明值（带引号和 fallback）。
  String serifCss() =>
      serifFonts.map((f) => '"$f"').join(', ') + ', serif';

  String sansSerifCss() =>
      sansSerifFonts.map((f) => '"$f"').join(', ') + ', sans-serif';

  String monoCss() =>
      monoFonts.map((f) => '"$f"').join(', ') + ', monospace';

  static const cjkSerif = CjkFontStack(
    label: 'CJK Serif',
    serifFonts: [
      'LXGW WenKai GB Screen',
      'LXGW WenKai TC',
      'GuanKiapTsingKhai-T',
      'Source Han Serif CN',
      'Huiwen-MinchoGBK',
      'KingHwa_OldSong',
      'Georgia',
      'Times New Roman',
    ],
    sansSerifFonts: [
      'Noto Sans SC',
      'Noto Sans TC',
      'Noto Sans',
      'Helvetica',
    ],
    monoFonts: [
      'Fira Code',
      'Consolas',
      'Courier New',
    ],
  );

  static const cjkSans = CjkFontStack(
    label: 'CJK Sans',
    serifFonts: [
      'LXGW WenKai GB Screen',
      'LXGW WenKai TC',
      'Source Han Serif CN',
      'Georgia',
      'Times New Roman',
    ],
    sansSerifFonts: [
      'Noto Sans SC',
      'Noto Sans TC',
      'Roboto',
      'Noto Sans',
      'Open Sans',
      'PT Sans',
      'Helvetica',
    ],
    monoFonts: [
      'Fira Code',
      'Consolas',
      'Courier New',
    ],
  );

  static const cjkMono = CjkFontStack(
    label: 'CJK Mono',
    serifFonts: [
      'Source Han Serif CN',
      'Georgia',
      'Times New Roman',
    ],
    sansSerifFonts: [
      'Noto Sans SC',
      'Noto Sans TC',
      'Roboto',
      'Helvetica',
    ],
    monoFonts: [
      'Fira Code',
      'Consolas',
      'Courier New',
      'Lucida Console',
      'PT Mono',
    ],
  );

  static const List<CjkFontStack> presets = [cjkSerif, cjkSans, cjkMono];
}

/// 手势导航模式。
enum GestureNavigationMode {
  /// 左右 1/3 区域点击翻页。
  edgeTap,

  /// 左右滑动翻页。
  swipe,

  /// 仅点击中间区域唤出控制栏，不提供翻页手势。
  none,
}

/// 阅读器主题模型，承载全部视觉与排版参数。
///
/// 每个主题包含颜色、字体、排版、布局、导航等完整配置。
/// `cacheSignature()` 对 layout-affecting 字段做 SHA-256 签名，
/// 用于分页/排版缓存失效判定。
/// `toCssString()` 为 foliate-view renderer.setStyles() 生成完整 CSS。
class ReaderTheme {
  final String name;
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double pageMargin;
  final double topMargin;
  final double bottomMargin;
  final String backgroundColor;
  final String textColor;
  final String selectionColor;
  final double textIndent;
  final double wordSpacing;
  final double letterSpacing;
  final bool hyphenation;
  final int columnCount;
  final double maxInlineSize;
  final double maxBlockSize;
  final bool verticalScroll;
  final bool animated;
  final bool isDark;
  final GestureNavigationMode gestureNavigationMode;

  const ReaderTheme({
    required this.name,
    this.fontFamily = 'serif',
    this.fontSize = 1.25,
    this.lineHeight = 1.6,
    this.pageMargin = 24.0,
    this.topMargin = 20.0,
    this.bottomMargin = 20.0,
    this.backgroundColor = '#ffffff',
    this.textColor = '#111111',
    this.selectionColor = '#0066cc',
    this.textIndent = 2.0,
    this.wordSpacing = 0.0,
    this.letterSpacing = 0.0,
    this.hyphenation = false,
    this.columnCount = 1,
    this.maxInlineSize = 600.0,
    this.maxBlockSize = 600.0,
    this.verticalScroll = true,
    this.animated = true,
    this.isDark = false,
    this.gestureNavigationMode = GestureNavigationMode.edgeTap,
  });

  // ── 13 种预设主题 ──

  /// 纯白 (Default Light)
  static const defaultLight = ReaderTheme(
    name: 'Default Light',
    backgroundColor: '#FFFFFF',
    textColor: '#111111',
    selectionColor: '#0066cc',
    isDark: false,
  );

  /// 夜间 (Default Dark)
  static const defaultDark = ReaderTheme(
    name: 'Default Dark',
    backgroundColor: '#171A1F',
    textColor: '#E5E7EC',
    selectionColor: '#77bbee',
    isDark: true,
  );

  /// 纸张 (Sepia)
  static const sepia = ReaderTheme(
    name: 'Sepia',
    backgroundColor: '#F7F2E7',
    textColor: '#2A241C',
    selectionColor: '#008b8b',
    isDark: false,
    fontFamily: 'serif',
  );

  /// 云灰 (Gray)
  static const gray = ReaderTheme(
    name: 'Gray',
    backgroundColor: '#F2F4F8',
    textColor: '#1F2630',
    selectionColor: '#4488cc',
    isDark: false,
  );

  /// 薄荷 (Grass)
  static const grass = ReaderTheme(
    name: 'Grass',
    backgroundColor: '#EDF7F2',
    textColor: '#1E302A',
    selectionColor: '#177b4d',
    isDark: false,
  );

  /// 樱红 (Cherry)
  static const cherry = ReaderTheme(
    name: 'Cherry',
    backgroundColor: '#F0D1D5',
    textColor: '#4E1609',
    selectionColor: '#de3838',
    isDark: false,
  );

  /// 青蓝 (Sky)
  static const sky = ReaderTheme(
    name: 'Sky',
    backgroundColor: '#EAF3FA',
    textColor: '#1D2C39',
    selectionColor: '#2d53e5',
    isDark: false,
  );

  /// Solarized Light
  static const solarizedLight = ReaderTheme(
    name: 'Solarized Light',
    backgroundColor: '#FDF6E3',
    textColor: '#586E75',
    selectionColor: '#268bd2',
    isDark: false,
  );

  /// Solarized Dark
  static const solarizedDark = ReaderTheme(
    name: 'Solarized Dark',
    backgroundColor: '#002B36',
    textColor: '#93A1A1',
    selectionColor: '#268bd2',
    isDark: true,
  );

  /// Gruvbox Dark
  static const gruvboxDark = ReaderTheme(
    name: 'Gruvbox Dark',
    backgroundColor: '#282828',
    textColor: '#EBDBB2',
    selectionColor: '#83a598',
    isDark: true,
  );

  /// Nord
  static const nord = ReaderTheme(
    name: 'Nord',
    backgroundColor: '#2E3440',
    textColor: '#D8DEE9',
    selectionColor: '#88c0d0',
    isDark: true,
  );

  /// 高对比 (Contrast)
  static const contrast = ReaderTheme(
    name: 'Contrast',
    backgroundColor: '#000000',
    textColor: '#FFFFFF',
    selectionColor: '#88ccee',
    isDark: true,
  );

  /// 日暮 (Sunset)
  static const sunset = ReaderTheme(
    name: 'Sunset',
    backgroundColor: '#FFF7F0',
    textColor: '#423126',
    selectionColor: '#fe6b64',
    isDark: false,
  );

  /// 所有预设主题列表（保持顺序，用于 UI 选择器索引）。
  static const List<ReaderTheme> presets = [
    defaultLight,
    defaultDark,
    sepia,
    gray,
    grass,
    cherry,
    sky,
    solarizedLight,
    solarizedDark,
    gruvboxDark,
    nord,
    contrast,
    sunset,
  ];

  // ── 缓存签名 ──

  /// 对 layout-affecting 字段生成 SHA-256 签名，用于分页/排版缓存失效判定。
  ///
  /// 仅包含影响排版结果的字段：字体族、字号、行高、首行缩进、词间距、
  /// 字间距、断字、列数、最大行宽、最大块高、纵向滚动、页边距（四边）。
  /// 颜色、导航模式等不影响排版，因此排除。
  String cacheSignature() {
    final layoutFields = [
      fontFamily,
      fontSize.toStringAsFixed(4),
      lineHeight.toStringAsFixed(4),
      textIndent.toStringAsFixed(4),
      wordSpacing.toStringAsFixed(4),
      letterSpacing.toStringAsFixed(4),
      hyphenation.toString(),
      columnCount.toString(),
      maxInlineSize.toStringAsFixed(2),
      maxBlockSize.toStringAsFixed(2),
      verticalScroll.toString(),
      pageMargin.toStringAsFixed(2),
      topMargin.toStringAsFixed(2),
      bottomMargin.toStringAsFixed(2),
    ];
    final payload = layoutFields.join('|');
    final digest = sha256.convert(utf8.encode(payload));
    return _bytesToHex(digest.bytes);
  }

  // ── CSS 生成 ──

  /// 根据 fontFamily 名称选择对应的 CJK 字体栈。
  CjkFontStack _resolveCjkFontStack() {
    switch (fontFamily) {
      case 'sans-serif':
        return CjkFontStack.cjkSans;
      case 'monospace':
        return CjkFontStack.cjkMono;
      default:
        return CjkFontStack.cjkSerif;
    }
  }

  /// 为 foliate-view renderer.setStyles() 生成完整 CSS 字符串。
  ///
  /// CSS 结构对齐 Readest 的 getStyles() 输出，包含：
  /// 1. 页面布局（边距、滚动模式、列数、视口约束）
  /// 2. 段落排版（行高、缩进、词/字间距、断字、对齐）
  /// 3. 字体声明（serif/sans-serif/monospace CSS 变量、CJK 字体栈）
  /// 4. 颜色与主题（背景色、前景色、选中色、暗色模式适配）
  String toCssString() {
    final cjkStack = _resolveCjkFontStack();
    final defaultFontVar =
        fontFamily == 'sans-serif' ? '--sans-serif' : '--serif';
    final fontSizePx = fontSize * 16; // 1.25 -> 20px, Readest mobile scale

    final sb = StringBuffer();

    // ── 1. 页面布局 ──
    sb.writeln('@namespace epub "http://www.idpf.org/2007/ops";');
    sb.writeln('html {');
    sb.writeln('  --margin-top: ${topMargin}px;');
    sb.writeln('  --margin-right: ${pageMargin}px;');
    sb.writeln('  --margin-bottom: ${bottomMargin}px;');
    sb.writeln('  --margin-left: ${pageMargin}px;');
    sb.writeln('}');
    sb.writeln('html, body {');
    sb.writeln('  max-height: unset;');
    sb.writeln('  -webkit-touch-callout: none;');
    sb.writeln('  -webkit-user-select: text;');
    sb.writeln('}');
    sb.writeln('body {');
    sb.writeln('  overflow: unset;');
    sb.writeln('  padding: unset;');
    sb.writeln('  margin: unset;');
    sb.writeln('}');
    if (columnCount > 1) {
      sb.writeln('body {');
      sb.writeln(
          '  column-count: $columnCount; column-width: ${maxInlineSize}px;');
      sb.writeln('}');
    }
    sb.writeln('pre { white-space: pre-wrap !important; }');
    sb.writeln('a { position: relative !important; }');
    sb.writeln('a::before { content: ""; position: absolute; inset: -10px; }');

    // ── 2. 段落排版 ──
    sb.writeln('html {');
    sb.writeln('  --default-text-align: justify;');
    sb.writeln('  hanging-punctuation: allow-end last;');
    sb.writeln('  orphans: 2; widows: 2;');
    sb.writeln('}');
    sb.writeln('html, body { text-align: var(--default-text-align); }');
    sb.writeln(
        '[align="left"] { text-align: left; } [align="right"] { text-align: right; }');
    sb.writeln(
        '[align="center"] { text-align: center; } [align="justify"] { text-align: justify; }');

    sb.writeln(
        'p, blockquote, dd, div:not(:has(*:not(b, a, em, i, strong, u, span))) {');
    sb.writeln('  line-height: ${lineHeight};');
    sb.writeln('  word-spacing: ${wordSpacing}px;');
    sb.writeln('  letter-spacing: ${letterSpacing}px;');
    sb.writeln('  text-indent: ${textIndent}em;');
    sb.writeln(
        '  -webkit-hyphens: ${hyphenation ? 'auto' : 'manual'}; hyphens: ${hyphenation ? 'auto' : 'manual'};');
    sb.writeln('  hanging-punctuation: allow-end last; widows: 2;');
    sb.writeln('}');
    sb.writeln('li {');
    sb.writeln('  line-height: ${lineHeight};');
    sb.writeln(
        '  -webkit-hyphens: ${hyphenation ? 'auto' : 'manual'}; hyphens: ${hyphenation ? 'auto' : 'manual'};');
    sb.writeln('}');
    // CJK 文本减少 orphans/widows
    sb.writeln(
        ':lang(zh), :lang(ja), :lang(ko) { widows: 1; orphans: 1; }');

    // ── 3. 字体声明 ──
    sb.writeln('html {');
    sb.writeln('  --serif: ${cjkStack.serifCss()};');
    sb.writeln('  --sans-serif: ${cjkStack.sansSerifCss()};');
    sb.writeln('  --monospace: ${cjkStack.monoCss()};');
    sb.writeln('  --font-size: ${fontSizePx}px;');
    sb.writeln('  --min-font-size: 8px;');
    sb.writeln('}');
    sb.writeln('html, body {');
    sb.writeln('  font-size: ${fontSizePx}px !important;');
    sb.writeln('  -webkit-text-size-adjust: none; text-size-adjust: none;');
    sb.writeln('}');
    sb.writeln('html { font-family: var($defaultFontVar); }');
    sb.writeln('html body { font-family: var($defaultFontVar) !important; }');
    sb.writeln('pre, code, kbd { font-family: var(--monospace); }');

    // ── 4. 颜色与主题 ──
    sb.writeln('html {');
    sb.writeln('  --theme-bg-color: $backgroundColor;');
    sb.writeln('  --theme-fg-color: $textColor;');
    sb.writeln('  --theme-primary-color: $selectionColor;');
    sb.writeln('  color-scheme: ${isDark ? 'dark' : 'light'};');
    sb.writeln('}');
    sb.writeln('html, body { color: $textColor; }');
    sb.writeln('html {');
    sb.writeln(
        '  background-color: var(--theme-bg-color, transparent);');
    sb.writeln('}');
    sb.writeln('::selection {');
    sb.writeln('  background: ${selectionColor}40;');
    sb.writeln('}');
    sb.writeln('::-moz-selection {');
    sb.writeln('  background: ${selectionColor}40;');
    sb.writeln('}');
    if (isDark) {
      // 暗色模式额外适配
      sb.writeln('a:any-link { color: lightblue; }');
      sb.writeln(
          'img { filter: invert(100%); }'); // 可在 merge 中由用户关闭
      sb.writeln('blockquote {');
      sb.writeln(
          '  background: color-mix(in srgb, $backgroundColor 80%, #000);');
      sb.writeln('}');
    } else {
      // 亮色模式下 override inline 硬编码黑色
      sb.writeln(
          'font[color="#000000"], font[color="#000"], font[color="black"],');
      sb.writeln(
          '  *[style*="color: rgb(0,0,0)"], *[style*="color: #000"],');
      sb.writeln(
          '  *[style*="color: #000000"], *[style*="color: black"] {');
      sb.writeln('  color: $textColor !important;');
      sb.writeln('}');
    }
    sb.writeln('svg, img { background-color: transparent !important; }');

    return sb.toString();
  }

  // ── 合并 ──

  /// 将另一个 ReaderTheme 的非-null / 非-default 字段覆盖到当前主题上，
  /// 返回合并后的新 ReaderTheme。
  ///
  /// 典型用法：preset 作为底色，用户自定义作为覆盖层。
  ReaderTheme merge(ReaderTheme override) {
    return ReaderTheme(
      name: override.name != 'Default Light' ? override.name : name,
      fontFamily: override.fontFamily,
      fontSize: override.fontSize,
      lineHeight: override.lineHeight,
      pageMargin: override.pageMargin,
      topMargin: override.topMargin,
      bottomMargin: override.bottomMargin,
      backgroundColor: override.backgroundColor,
      textColor: override.textColor,
      selectionColor: override.selectionColor,
      textIndent: override.textIndent,
      wordSpacing: override.wordSpacing,
      letterSpacing: override.letterSpacing,
      hyphenation: override.hyphenation,
      columnCount: override.columnCount,
      maxInlineSize: override.maxInlineSize,
      maxBlockSize: override.maxBlockSize,
      verticalScroll: override.verticalScroll,
      animated: override.animated,
      isDark: override.isDark,
      gestureNavigationMode: override.gestureNavigationMode,
    );
  }

  /// 创建当前主题的副本，仅覆盖传入的非-null 参数。
  ///
  /// 典型用法：排版调整面板修改字号/行高/边距时，
  /// 只需传入需要变更的字段，其余保持不变。
  ReaderTheme copyWith({
    String? name,
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? pageMargin,
    double? topMargin,
    double? bottomMargin,
    String? backgroundColor,
    String? textColor,
    String? selectionColor,
    double? textIndent,
    double? wordSpacing,
    double? letterSpacing,
    bool? hyphenation,
    int? columnCount,
    double? maxInlineSize,
    double? maxBlockSize,
    bool? verticalScroll,
    bool? animated,
    bool? isDark,
    GestureNavigationMode? gestureNavigationMode,
  }) {
    return ReaderTheme(
      name: name ?? this.name,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      pageMargin: pageMargin ?? this.pageMargin,
      topMargin: topMargin ?? this.topMargin,
      bottomMargin: bottomMargin ?? this.bottomMargin,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      selectionColor: selectionColor ?? this.selectionColor,
      textIndent: textIndent ?? this.textIndent,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      hyphenation: hyphenation ?? this.hyphenation,
      columnCount: columnCount ?? this.columnCount,
      maxInlineSize: maxInlineSize ?? this.maxInlineSize,
      maxBlockSize: maxBlockSize ?? this.maxBlockSize,
      verticalScroll: verticalScroll ?? this.verticalScroll,
      animated: animated ?? this.animated,
      isDark: isDark ?? this.isDark,
      gestureNavigationMode: gestureNavigationMode ?? this.gestureNavigationMode,
    );
  }

  // ── JSON 持久化 ──

  /// 序列化为 JSON Map，用于 SharedPreferences 或 Supabase 持久化。
  Map<String, dynamic> toJson() => {
        'name': name,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'pageMargin': pageMargin,
        'topMargin': topMargin,
        'bottomMargin': bottomMargin,
        'backgroundColor': backgroundColor,
        'textColor': textColor,
        'selectionColor': selectionColor,
        'textIndent': textIndent,
        'wordSpacing': wordSpacing,
        'letterSpacing': letterSpacing,
        'hyphenation': hyphenation,
        'columnCount': columnCount,
        'maxInlineSize': maxInlineSize,
        'maxBlockSize': maxBlockSize,
        'verticalScroll': verticalScroll,
        'animated': animated,
        'isDark': isDark,
        'gestureNavigationMode': gestureNavigationMode.name,
      };

  /// 从 JSON Map 反序列化，缺失字段使用默认值。
  static ReaderTheme fromJson(Map<String, dynamic> json) {
    return ReaderTheme(
      name: json['name'] as String? ?? 'Default Light',
      fontFamily: json['fontFamily'] as String? ?? 'serif',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 1.25,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
      pageMargin: (json['pageMargin'] as num?)?.toDouble() ?? 24.0,
      topMargin: (json['topMargin'] as num?)?.toDouble() ?? 20.0,
      bottomMargin: (json['bottomMargin'] as num?)?.toDouble() ?? 20.0,
      backgroundColor: json['backgroundColor'] as String? ?? '#ffffff',
      textColor: json['textColor'] as String? ?? '#111111',
      selectionColor: json['selectionColor'] as String? ?? '#0066cc',
      textIndent: (json['textIndent'] as num?)?.toDouble() ?? 2.0,
      wordSpacing: (json['wordSpacing'] as num?)?.toDouble() ?? 0.0,
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0.0,
      hyphenation: json['hyphenation'] as bool? ?? false,
      columnCount: json['columnCount'] as int? ?? 1,
      maxInlineSize: (json['maxInlineSize'] as num?)?.toDouble() ?? 600.0,
      maxBlockSize: (json['maxBlockSize'] as num?)?.toDouble() ?? 600.0,
      verticalScroll: json['verticalScroll'] as bool? ?? true,
      animated: json['animated'] as bool? ?? true,
      isDark: json['isDark'] as bool? ?? false,
      gestureNavigationMode: _parseGestureMode(
          json['gestureNavigationMode'] as String? ?? 'edgeTap'),
    );
  }

  static GestureNavigationMode _parseGestureMode(String value) {
    switch (value) {
      case 'swipe':
        return GestureNavigationMode.swipe;
      case 'none':
        return GestureNavigationMode.none;
      default:
        return GestureNavigationMode.edgeTap;
    }
  }

  /// 从 JSON 字符串反序列化。
  static ReaderTheme fromJsonString(String jsonStr) {
    return fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  /// 序列化为 JSON 字符串。
  String toJsonString() => jsonEncode(toJson());

  // ── 便捷 ──

  /// 亮色/暗色模式判断（供 SystemUI overlay 选择）。
  bool get shouldUseLightOverlay => !isDark;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderTheme &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          fontFamily == other.fontFamily &&
          fontSize == other.fontSize &&
          lineHeight == other.lineHeight &&
          pageMargin == other.pageMargin &&
          topMargin == other.topMargin &&
          bottomMargin == other.bottomMargin &&
          backgroundColor == other.backgroundColor &&
          textColor == other.textColor &&
          selectionColor == other.selectionColor &&
          textIndent == other.textIndent &&
          wordSpacing == other.wordSpacing &&
          letterSpacing == other.letterSpacing &&
          hyphenation == other.hyphenation &&
          columnCount == other.columnCount &&
          maxInlineSize == other.maxInlineSize &&
          maxBlockSize == other.maxBlockSize &&
          verticalScroll == other.verticalScroll &&
          animated == other.animated &&
          isDark == other.isDark &&
          gestureNavigationMode == other.gestureNavigationMode;

  @override
  int get hashCode => Object.hashAll([
        name,
        fontFamily,
        fontSize,
        lineHeight,
        pageMargin,
        topMargin,
        bottomMargin,
        backgroundColor,
        textColor,
        selectionColor,
        textIndent,
        wordSpacing,
        letterSpacing,
        hyphenation,
        columnCount,
        maxInlineSize,
        maxBlockSize,
        verticalScroll,
        animated,
        isDark,
        gestureNavigationMode,
      ]);

  @override
  String toString() => 'ReaderTheme(name: $name, '
      'backgroundColor: $backgroundColor, textColor: $textColor, '
      'fontSize: $fontSize, lineHeight: $lineHeight, isDark: $isDark)';
}

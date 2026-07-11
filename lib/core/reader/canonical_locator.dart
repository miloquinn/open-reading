// 文件说明：阅读内核定位真相模型，定义 CanonicalLocator、RenderedLocator、TextAnchor、AnnotationAnchor、ReaderSelection 与 LocatorCodec。
// 技术要点：与 iOS ReaderKernelModels.swift 对齐的 Dart 眉值模型，覆盖布局无关定位、布局依赖定位、文本锚点、批注锚点与选区上下文。

import 'dart:convert' show jsonEncode, jsonDecode;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// 书籍格式枚举，与 iOS BookFormat 对齐。
enum BookFormat implements Comparable<BookFormat> {
  epub,
  pdf,
  txt,
  fb2,
  rtf,
  doc,
  docx,
  html,
  htm,
  md,
  mobi,
  azw,
  azw3,
  cbz,
  divina,
  cbr,
  unknown;

  factory BookFormat.fromFileExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'epub':
        return epub;
      case 'pdf':
        return pdf;
      case 'txt':
        return txt;
      case 'fb2':
        return fb2;
      case 'rtf':
        return rtf;
      case 'doc':
        return doc;
      case 'docx':
        return docx;
      case 'html':
      case 'xhtml':
        return html;
      case 'htm':
        return htm;
      case 'md':
      case 'markdown':
        return md;
      case 'mobi':
        return mobi;
      case 'azw':
        return azw;
      case 'azw3':
        return azw3;
      case 'cbz':
        return cbz;
      case 'divina':
        return divina;
      case 'cbr':
        return cbr;
      default:
        return unknown;
    }
  }

  factory BookFormat.fromMimeType(String mimeType) {
    final normalized = mimeType.trim().toLowerCase();
    if (normalized.contains('epub')) return epub;
    if (normalized.contains('pdf')) return pdf;
    if (normalized.contains('markdown')) return md;
    if (normalized.contains('xhtml') || normalized.contains('html')) {
      return html;
    }
    if (normalized.contains('fictionbook') || normalized.contains('fb2')) {
      return fb2;
    }
    if (normalized.contains('rtf')) return rtf;
    if (normalized.contains('officedocument.wordprocessingml') ||
        normalized.contains('openxmlformats-officedocument.wordprocessingml') ||
        normalized.contains('wordprocessingml')) {
      return docx;
    }
    if (normalized.contains('msword') || normalized.contains('vnd.ms-word')) {
      return doc;
    }
    if (normalized.contains('azw3') ||
        normalized.contains('mobi8-ebook') ||
        normalized.contains('kf8')) {
      return azw3;
    }
    if (normalized.contains('mobi8') ||
        normalized.contains('mobipocket') ||
        normalized.contains('x-mobi') ||
        normalized.contains('/mobi')) {
      return mobi;
    }
    if (normalized.contains('vnd.amazon.ebook') || normalized.contains('azw')) {
      return azw;
    }
    if (normalized.contains('text/plain') || normalized.contains('plain')) {
      return txt;
    }
    if (normalized.contains('comicbook+zip') || normalized.contains('x-cbz')) {
      return cbz;
    }
    if (normalized.contains('application/divina') ||
        normalized.contains('divina+json')) {
      return divina;
    }
    if (normalized.contains('comicbook-rar') || normalized.contains('x-cbr')) {
      return cbr;
    }
    return unknown;
  }

  String fileExtension() {
    switch (this) {
      case epub:
        return 'epub';
      case pdf:
        return 'pdf';
      case txt:
        return 'txt';
      case fb2:
        return 'fb2';
      case rtf:
        return 'rtf';
      case doc:
        return 'doc';
      case docx:
        return 'docx';
      case html:
        return 'html';
      case htm:
        return 'htm';
      case md:
        return 'md';
      case mobi:
        return 'mobi';
      case azw:
        return 'azw';
      case azw3:
        return 'azw3';
      case cbz:
        return 'cbz';
      case divina:
        return 'divina';
      case cbr:
        return 'cbr';
      case unknown:
        return '';
    }
  }

  bool get isReadiumPreferred =>
      this == epub || this == pdf || this == cbz || this == divina;

  bool get isImportEnabled => this != cbr && this != unknown;

  bool get supportsTextFallback =>
      this == txt ||
      this == fb2 ||
      this == rtf ||
      this == doc ||
      this == docx ||
      this == html ||
      this == htm ||
      this == md ||
      this == mobi ||
      this == azw ||
      this == azw3;

  bool get supportsCanonicalTextAnchors => this == txt;

  @override
  int compareTo(BookFormat other) => index.compareTo(other.index);
}

/// 阅读器渲染类型枚举，与 iOS ReaderRendererType 对齐。
enum ReaderRendererType implements Comparable<ReaderRendererType> {
  readium,
  pdfKit,
  textKit,
  webKit,
  foliate,
  nativeCPlusPlus;

  @override
  int compareTo(ReaderRendererType other) => index.compareTo(other.index);
}

/// 批注目标类型枚举。
enum AnnotationTargetKind implements Comparable<AnnotationTargetKind> {
  bookmark,
  note,
  highlight;

  @override
  int compareTo(AnnotationTargetKind other) => index.compareTo(other.index);
}

/// 批注定位解析状态枚举。
enum AnnotationResolutionStatus
    implements Comparable<AnnotationResolutionStatus> {
  exact,
  quoteContext,
  rendererHint,
  progressionFallback,
  unresolved;

  @override
  int compareTo(AnnotationResolutionStatus other) =>
      index.compareTo(other.index);
}

// ---------------------------------------------------------------------------
// TextAnchor
// ---------------------------------------------------------------------------

/// 文本位置锚点：保存引用文本、前后上下文与 UTF-16 偏移信息。
/// 所有文本字段在构造时自动规范化（换行统一、空白压缩、首尾裁剪）。
@immutable
class TextAnchor {
  final String quote;
  final String? prefix;
  final String? suffix;
  final String? chapterId;
  final String? resourceHref;
  final int? startOffsetUtf16;
  final int? lengthUtf16;
  final int? offsetHint;

  const TextAnchor({
    required this.quote,
    this.prefix,
    this.suffix,
    this.chapterId,
    this.resourceHref,
    this.startOffsetUtf16,
    this.lengthUtf16,
    this.offsetHint,
  });

  /// 构造时对字段做规范化处理，与 iOS TextAnchor.init 语义一致。
  factory TextAnchor.create({
    required String quote,
    String? prefix,
    String? suffix,
    String? chapterId,
    String? resourceHref,
    int? startOffsetUtf16,
    int? lengthUtf16,
    int? offsetHint,
  }) {
    return TextAnchor(
      quote: _normalizedSnippet(quote) ?? '',
      prefix: _normalizedSnippet(prefix),
      suffix: _normalizedSnippet(suffix),
      chapterId: _normalizedSnippet(chapterId),
      resourceHref: _normalizedSnippet(resourceHref),
      startOffsetUtf16:
          startOffsetUtf16 != null ? math.max(startOffsetUtf16, 0) : null,
      lengthUtf16: lengthUtf16 != null ? math.max(lengthUtf16, 0) : null,
      offsetHint: offsetHint != null ? math.max(offsetHint, 0) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'quote': quote,
    };
    if (prefix != null) map['prefix'] = prefix;
    if (suffix != null) map['suffix'] = suffix;
    if (chapterId != null) map['chapterId'] = chapterId;
    if (resourceHref != null) map['resourceHref'] = resourceHref;
    if (startOffsetUtf16 != null) map['startOffsetUtf16'] = startOffsetUtf16;
    if (lengthUtf16 != null) map['lengthUtf16'] = lengthUtf16;
    if (offsetHint != null) map['offsetHint'] = offsetHint;
    return map;
  }

  factory TextAnchor.fromJson(Map<String, dynamic> json) {
    return TextAnchor.create(
      quote: (json['quote'] as String?) ?? '',
      prefix: json['prefix'] as String?,
      suffix: json['suffix'] as String?,
      chapterId: json['chapterId'] as String?,
      resourceHref: json['resourceHref'] as String?,
      startOffsetUtf16: json['startOffsetUtf16'] as int?,
      lengthUtf16: json['lengthUtf16'] as int?,
      offsetHint: json['offsetHint'] as int?,
    );
  }

  @override
  int get hashCode => Object.hash(
        quote,
        prefix,
        suffix,
        chapterId,
        resourceHref,
        startOffsetUtf16,
        lengthUtf16,
        offsetHint,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextAnchor &&
          quote == other.quote &&
          prefix == other.prefix &&
          suffix == other.suffix &&
          chapterId == other.chapterId &&
          resourceHref == other.resourceHref &&
          startOffsetUtf16 == other.startOffsetUtf16 &&
          lengthUtf16 == other.lengthUtf16 &&
          offsetHint == other.offsetHint;

  @override
  String toString() => 'TextAnchor(quote: "${_truncate(quote, 40)}", '
      'chapterId: $chapterId, startOffsetUtf16: $startOffsetUtf16)';
}

// ---------------------------------------------------------------------------
// CanonicalLocator
// ---------------------------------------------------------------------------

/// 布局无关定位：跨设备、跨排版参数可稳定恢复的阅读位置真相源。
/// href 遵循 URI 方案 text://chapter/{id}/offset/{n}/excerpt/{text}。
@immutable
class CanonicalLocator {
  final int version;
  final BookFormat format;
  final String? href;
  final String? chapterId;
  final String? resourceHref;
  final double? progression;
  final int? positionHint;
  final int? totalPositionsHint;
  final List<String> fragments;
  final TextAnchor? textAnchor;
  final String? contentSignature;

  const CanonicalLocator({
    this.version = 1,
    required this.format,
    this.href,
    this.chapterId,
    this.resourceHref,
    this.progression,
    this.positionHint,
    this.totalPositionsHint,
    this.fragments = const [],
    this.textAnchor,
    this.contentSignature,
  });

  /// 构造时做规范化处理，与 iOS CanonicalLocator.init 语义一致。
  factory CanonicalLocator.create({
    int version = 1,
    required BookFormat format,
    String? href,
    String? chapterId,
    String? resourceHref,
    double? progression,
    int? positionHint,
    int? totalPositionsHint,
    List<String> fragments = const [],
    TextAnchor? textAnchor,
    String? contentSignature,
  }) {
    return CanonicalLocator(
      version: version,
      format: format,
      href: _normalizedSnippet(href),
      chapterId: _normalizedSnippet(chapterId),
      resourceHref: _normalizedSnippet(resourceHref),
      progression: progression != null
          ? math.min(math.max(progression, 0.0), 1.0)
          : null,
      positionHint: positionHint,
      totalPositionsHint: totalPositionsHint,
      fragments: fragments,
      textAnchor: textAnchor,
      contentSignature: _normalizedSnippet(contentSignature),
    );
  }

  // -- Factory methods -----------------------------------------------------

  /// 从 href URI 直接构造 CanonicalLocator，解析内置的 chapterId、offset 与 excerpt。
  factory CanonicalLocator.fromHref({
    required BookFormat format,
    required String href,
    double? progression,
    int? positionHint,
    int? totalPositionsHint,
    List<String> fragments = const [],
  }) {
    final chapterId = CanonicalLocator.chapterIdFromHref(href);
    final offset = CanonicalLocator.offsetFromHref(href);
    final excerpt = CanonicalLocator.excerptFromHref(href);
    final textAnchor = excerpt != null
        ? TextAnchor.create(
            quote: excerpt,
            chapterId: chapterId,
            startOffsetUtf16: offset,
            offsetHint: offset ??
                (positionHint != null ? math.max(positionHint - 1, 0) : null),
          )
        : null;
    return CanonicalLocator.create(
      format: format,
      href: href,
      chapterId: chapterId,
      progression: progression,
      positionHint: positionHint,
      totalPositionsHint: totalPositionsHint,
      fragments: fragments,
      textAnchor: textAnchor,
    );
  }

  /// 从各组成部分直接构造。
  factory CanonicalLocator.fromComponents({
    required BookFormat format,
    String? chapterId,
    int? offset,
    String? excerpt,
    double? progression,
    int? positionHint,
    int? totalPositionsHint,
    List<String> fragments = const [],
  }) {
    final href = _buildTextAnchorHref(
      chapterId: chapterId,
      absoluteOffset: offset,
      excerpt: excerpt,
    );
    final textAnchor = excerpt != null || offset != null
        ? TextAnchor.create(
            quote: excerpt ?? '',
            chapterId: chapterId,
            startOffsetUtf16: offset,
            offsetHint: offset ??
                (positionHint != null ? math.max(positionHint - 1, 0) : null),
          )
        : null;
    return CanonicalLocator.create(
      format: format,
      href: href,
      chapterId: chapterId,
      progression: progression,
      positionHint: positionHint,
      totalPositionsHint: totalPositionsHint,
      fragments: fragments,
      textAnchor: textAnchor,
    );
  }

  /// 从 CFI（EPUB Canonical Fragment Identifier）构造。
  /// 当前保留占位；EPUB CFI 解析将在后续集成 Readium 时补齐。
  factory CanonicalLocator.fromCfi({
    required BookFormat format,
    required String cfi,
    double? progression,
    int? positionHint,
    int? totalPositionsHint,
  }) {
    return CanonicalLocator.create(
      format: format,
      href: cfi,
      progression: progression,
      positionHint: positionHint,
      totalPositionsHint: totalPositionsHint,
      fragments: [cfi],
    );
  }

  /// 从 progression（0.0~1.0）构造，用于仅有进度百分比可用时的降级定位。
  factory CanonicalLocator.fromProgression({
    required BookFormat format,
    required double progression,
    String? chapterId,
    int? positionHint,
    int? totalPositionsHint,
  }) {
    return CanonicalLocator.create(
      format: format,
      chapterId: chapterId,
      progression: progression,
      positionHint: positionHint,
      totalPositionsHint: totalPositionsHint,
    );
  }

  // -- Static parsers (mirroring iOS ReaderDocument static methods) ----------

  /// 从 href 中提取 chapterId：text://chapter/{id}/...
  static String? chapterIdFromHref(String href) {
    const prefix = 'text://chapter/';
    if (!href.startsWith(prefix)) return null;
    final suffix = href.substring(prefix.length);
    final slashIndex = suffix.indexOf('/');
    if (slashIndex < 0) return _decodeUrl(suffix.trim());
    return _decodeUrl(suffix.substring(0, slashIndex).trim());
  }

  /// 从 href 中提取 UTF-16 偏移量：
  /// text://chapter/{id}/offset/{n}/...  或  text://offset/{n}/...
  static int? offsetFromHref(String href) {
    const chapterPrefix = 'text://chapter/';
    if (href.startsWith(chapterPrefix)) {
      final suffix = href.substring(chapterPrefix.length);
      final parts = _splitHrefPath(suffix);
      if (parts.length >= 3 && parts[1] == 'offset') {
        return int.tryParse(parts[2]);
      }
      return null;
    }
    const offsetPrefix = 'text://offset/';
    if (href.startsWith(offsetPrefix)) {
      final suffix = href.substring(offsetPrefix.length);
      final parts = _splitHrefPath(suffix);
      if (parts.isNotEmpty) return int.tryParse(parts[0]);
    }
    return null;
  }

  /// 从 href 中提取 excerpt 文本：
  /// text://chapter/{id}/offset/{n}/excerpt/{text}
  /// text://chapter/{id}/excerpt/{text}
  /// text://offset/{n}/excerpt/{text}
  /// text://excerpt/{text}
  static String? excerptFromHref(String href) {
    const chapterPrefix = 'text://chapter/';
    if (href.startsWith(chapterPrefix)) {
      final suffix = href.substring(chapterPrefix.length);
      final parts = _splitHrefPath(suffix);
      // chapter/{id}/offset/{n}/excerpt/{text...}
      if (parts.length >= 5 && parts[1] == 'offset' && parts[3] == 'excerpt') {
        final encoded = parts.sublist(4).join('/');
        return _decodeUrl(encoded.trim());
      }
      // chapter/{id}/excerpt/{text...}
      if (parts.length >= 3 && parts[1] == 'excerpt') {
        final encoded = parts.sublist(2).join('/');
        return _decodeUrl(encoded.trim());
      }
      return null;
    }

    const offsetPrefix = 'text://offset/';
    if (href.startsWith(offsetPrefix)) {
      final suffix = href.substring(offsetPrefix.length);
      final parts = _splitHrefPath(suffix);
      if (parts.length >= 3 && parts[1] == 'excerpt') {
        final encoded = parts.sublist(2).join('/');
        return _decodeUrl(encoded.trim());
      }
      return null;
    }

    const excerptPrefix = 'text://excerpt/';
    if (!href.startsWith(excerptPrefix)) return null;
    final encoded = href.substring(excerptPrefix.length);
    return _decodeUrl(encoded.trim());
  }

  // -- Serialization --------------------------------------------------------

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'version': version,
      'format': format.name,
    };
    if (href != null) map['href'] = href;
    if (chapterId != null) map['chapterId'] = chapterId;
    if (resourceHref != null) map['resourceHref'] = resourceHref;
    if (progression != null) map['progression'] = progression;
    if (positionHint != null) map['positionHint'] = positionHint;
    if (totalPositionsHint != null) {
      map['totalPositionsHint'] = totalPositionsHint;
    }
    if (fragments.isNotEmpty) map['fragments'] = fragments;
    if (textAnchor != null) map['textAnchor'] = textAnchor!.toJson();
    if (contentSignature != null) map['contentSignature'] = contentSignature;
    return map;
  }

  factory CanonicalLocator.fromJson(Map<String, dynamic> json) {
    final formatRaw = json['format'] as String?;
    final format = formatRaw != null
        ? BookFormat.values.firstWhere(
            (e) => e.name == formatRaw,
            orElse: () => BookFormat.unknown,
          )
        : BookFormat.unknown;
    final textAnchorJson = json['textAnchor'] as Map<String, dynamic>?;
    return CanonicalLocator.create(
      version: (json['version'] as int?) ?? 1,
      format: format,
      href: json['href'] as String?,
      chapterId: json['chapterId'] as String?,
      resourceHref: json['resourceHref'] as String?,
      progression: (json['progression'] as num?)?.toDouble(),
      positionHint: json['positionHint'] as int?,
      totalPositionsHint: json['totalPositionsHint'] as int?,
      fragments:
          (json['fragments'] as List<dynamic>?)?.cast<String>().toList() ??
              const [],
      textAnchor:
          textAnchorJson != null ? TextAnchor.fromJson(textAnchorJson) : null,
      contentSignature: json['contentSignature'] as String?,
    );
  }

  @override
  int get hashCode => Object.hash(
        version,
        format,
        href,
        chapterId,
        resourceHref,
        progression,
        positionHint,
        totalPositionsHint,
        Object.hashAll(fragments),
        textAnchor,
        contentSignature,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanonicalLocator &&
          version == other.version &&
          format == other.format &&
          href == other.href &&
          chapterId == other.chapterId &&
          resourceHref == other.resourceHref &&
          progression == other.progression &&
          positionHint == other.positionHint &&
          totalPositionsHint == other.totalPositionsHint &&
          _listEq(fragments, other.fragments) &&
          textAnchor == other.textAnchor &&
          contentSignature == other.contentSignature;

  @override
  String toString() => 'CanonicalLocator(format: ${format.name}, '
      'href: $href, chapterId: $chapterId, progression: $progression)';
}

// ---------------------------------------------------------------------------
// RenderedLocator
// ---------------------------------------------------------------------------

/// 布局依赖定位：当前设备 + 当前排版参数 + 当前渲染器的实际屏幕位置。
/// 仅用于 UI 显示与短期缓存；持久化必须使用 CanonicalLocator。
@immutable
class RenderedLocator {
  final int version;
  final BookFormat format;
  final ReaderRendererType renderer;
  final String href;
  final double progression;
  final int position;
  final int totalPositions;
  final String? mediaType;
  final String? title;
  final double? resourceProgression;
  final double? totalProgression;
  final List<String>? fragments;
  final String? textBefore;
  final String? textAfter;

  const RenderedLocator({
    this.version = 1,
    required this.format,
    required this.renderer,
    required this.href,
    required this.progression,
    required this.position,
    required this.totalPositions,
    this.mediaType,
    this.title,
    this.resourceProgression,
    this.totalProgression,
    this.fragments,
    this.textBefore,
    this.textAfter,
  });

  /// 构造时做规范化处理，与 iOS RenderedLocator.init 语义一致。
  factory RenderedLocator.create({
    int version = 1,
    required BookFormat format,
    required ReaderRendererType renderer,
    required String href,
    required double progression,
    required int position,
    required int totalPositions,
    String? mediaType,
    String? title,
    double? resourceProgression,
    double? totalProgression,
    List<String>? fragments,
    String? textBefore,
    String? textAfter,
  }) {
    return RenderedLocator(
      version: version,
      format: format,
      renderer: renderer,
      href: href,
      progression: math.min(math.max(progression, 0.0), 1.0),
      position: math.max(position, 1),
      totalPositions: math.max(totalPositions, 1),
      mediaType: mediaType,
      title: title,
      resourceProgression: resourceProgression,
      totalProgression: totalProgression,
      fragments: fragments,
      textBefore: _normalizedSnippet(textBefore),
      textAfter: _normalizedSnippet(textAfter),
    );
  }

  /// 当前页码（1-based），等同于 position。
  int page() => position;

  /// 总页数，等同于 totalPositions。
  int totalPages() => totalPositions;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'version': version,
      'format': format.name,
      'renderer': renderer.name,
      'href': href,
      'progression': progression,
      'position': position,
      'totalPositions': totalPositions,
    };
    if (mediaType != null) map['mediaType'] = mediaType;
    if (title != null) map['title'] = title;
    if (resourceProgression != null) {
      map['resourceProgression'] = resourceProgression;
    }
    if (totalProgression != null) map['totalProgression'] = totalProgression;
    if (fragments != null) map['fragments'] = fragments;
    if (textBefore != null) map['textBefore'] = textBefore;
    if (textAfter != null) map['textAfter'] = textAfter;
    return map;
  }

  factory RenderedLocator.fromJson(Map<String, dynamic> json) {
    final formatRaw = json['format'] as String?;
    final format = formatRaw != null
        ? BookFormat.values.firstWhere(
            (e) => e.name == formatRaw,
            orElse: () => BookFormat.unknown,
          )
        : BookFormat.unknown;
    final rendererRaw = json['renderer'] as String?;
    final renderer = rendererRaw != null
        ? ReaderRendererType.values.firstWhere(
            (e) => e.name == rendererRaw,
            orElse: () => ReaderRendererType.foliate,
          )
        : ReaderRendererType.foliate;
    return RenderedLocator.create(
      version: (json['version'] as int?) ?? 1,
      format: format,
      renderer: renderer,
      href: (json['href'] as String?) ?? '',
      progression: (json['progression'] as num?)?.toDouble() ?? 0.0,
      position: (json['position'] as int?) ?? 1,
      totalPositions: (json['totalPositions'] as int?) ?? 1,
      mediaType: json['mediaType'] as String?,
      title: json['title'] as String?,
      resourceProgression: (json['resourceProgression'] as num?)?.toDouble(),
      totalProgression: (json['totalProgression'] as num?)?.toDouble(),
      fragments: (json['fragments'] as List<dynamic>?)?.cast<String>().toList(),
      textBefore: json['textBefore'] as String?,
      textAfter: json['textAfter'] as String?,
    );
  }

  @override
  int get hashCode => Object.hash(
        version,
        format,
        renderer,
        href,
        progression,
        position,
        totalPositions,
        mediaType,
        title,
        resourceProgression,
        totalProgression,
        fragments != null ? Object.hashAll(fragments!) : 0,
        textBefore,
        textAfter,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenderedLocator &&
          version == other.version &&
          format == other.format &&
          renderer == other.renderer &&
          href == other.href &&
          progression == other.progression &&
          position == other.position &&
          totalPositions == other.totalPositions &&
          mediaType == other.mediaType &&
          title == other.title &&
          resourceProgression == other.resourceProgression &&
          totalProgression == other.totalProgression &&
          _nullableListEq(fragments, other.fragments) &&
          textBefore == other.textBefore &&
          textAfter == other.textAfter;

  @override
  String toString() => 'RenderedLocator(format: ${format.name}, '
      'renderer: ${renderer.name}, position: $position/$totalPositions)';
}

// ---------------------------------------------------------------------------
// AnnotationAnchor
// ---------------------------------------------------------------------------

/// 批注锚点：绑定批注类型 + CanonicalLocator + TextAnchor + 选区文本 + 解析状态。
@immutable
class AnnotationAnchor {
  final int version;
  final AnnotationTargetKind kind;
  final CanonicalLocator locator;
  final TextAnchor textAnchor;
  final String selectedText;
  final String? styleRaw;
  final String? note;
  final AnnotationResolutionStatus? resolutionStatus;

  const AnnotationAnchor({
    this.version = 1,
    required this.kind,
    required this.locator,
    required this.textAnchor,
    required this.selectedText,
    this.styleRaw,
    this.note,
    this.resolutionStatus,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'version': version,
      'kind': kind.name,
      'locator': locator.toJson(),
      'textAnchor': textAnchor.toJson(),
      'selectedText': selectedText,
    };
    if (styleRaw != null) map['styleRaw'] = styleRaw;
    if (note != null) map['note'] = note;
    if (resolutionStatus != null) {
      map['resolutionStatus'] = resolutionStatus!.name;
    }
    return map;
  }

  factory AnnotationAnchor.fromJson(Map<String, dynamic> json) {
    final kindRaw = json['kind'] as String?;
    final kind = kindRaw != null
        ? AnnotationTargetKind.values.firstWhere(
            (e) => e.name == kindRaw,
            orElse: () => AnnotationTargetKind.highlight,
          )
        : AnnotationTargetKind.highlight;
    final resolutionRaw = json['resolutionStatus'] as String?;
    final resolution = resolutionRaw != null
        ? AnnotationResolutionStatus.values.firstWhere(
            (e) => e.name == resolutionRaw,
            orElse: () => AnnotationResolutionStatus.unresolved,
          )
        : null;
    return AnnotationAnchor(
      version: (json['version'] as int?) ?? 1,
      kind: kind,
      locator: CanonicalLocator.fromJson(
        json['locator'] as Map<String, dynamic>,
      ),
      textAnchor: TextAnchor.fromJson(
        json['textAnchor'] as Map<String, dynamic>,
      ),
      selectedText: (json['selectedText'] as String?) ?? '',
      styleRaw: json['styleRaw'] as String?,
      note: json['note'] as String?,
      resolutionStatus: resolution,
    );
  }

  @override
  int get hashCode => Object.hash(
        version,
        kind,
        locator,
        textAnchor,
        selectedText,
        styleRaw,
        note,
        resolutionStatus,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnotationAnchor &&
          version == other.version &&
          kind == other.kind &&
          locator == other.locator &&
          textAnchor == other.textAnchor &&
          selectedText == other.selectedText &&
          styleRaw == other.styleRaw &&
          note == other.note &&
          resolutionStatus == other.resolutionStatus;

  @override
  String toString() => 'AnnotationAnchor(kind: ${kind.name}, '
      'selectedText: "${_truncate(selectedText, 40)}", '
      'resolution: ${resolutionStatus?.name})';
}

// ---------------------------------------------------------------------------
// ReaderSelection
// ---------------------------------------------------------------------------

/// 用户文本选区上下文：捕获选区文本、章节 ID、偏移量、前后文与渲染器定位。
@immutable
class ReaderSelection {
  final String bookId;
  final BookFormat format;
  final ReaderRendererType renderer;
  final String selectedText;
  final String? chapterId;
  final String? resourceHref;
  final int? startOffsetUtf16;
  final int? lengthUtf16;
  final String? prefix;
  final String? suffix;
  final double? progression;
  final int? positionHint;
  final int? totalPositionsHint;
  final String? rendererLocatorJson;

  const ReaderSelection({
    required this.bookId,
    required this.format,
    required this.renderer,
    required this.selectedText,
    this.chapterId,
    this.resourceHref,
    this.startOffsetUtf16,
    this.lengthUtf16,
    this.prefix,
    this.suffix,
    this.progression,
    this.positionHint,
    this.totalPositionsHint,
    this.rendererLocatorJson,
  });

  /// 构造时做规范化处理，与 iOS ReaderSelection.init 语义一致。
  factory ReaderSelection.create({
    required String bookId,
    required BookFormat format,
    required ReaderRendererType renderer,
    required String selectedText,
    String? chapterId,
    String? resourceHref,
    int? startOffsetUtf16,
    int? lengthUtf16,
    String? prefix,
    String? suffix,
    double? progression,
    int? positionHint,
    int? totalPositionsHint,
    String? rendererLocatorJson,
  }) {
    return ReaderSelection(
      bookId: bookId,
      format: format,
      renderer: renderer,
      selectedText: _normalizedSnippet(selectedText) ?? '',
      chapterId: _normalizedSnippet(chapterId),
      resourceHref: _normalizedSnippet(resourceHref),
      startOffsetUtf16:
          startOffsetUtf16 != null ? math.max(startOffsetUtf16, 0) : null,
      lengthUtf16: lengthUtf16 != null ? math.max(lengthUtf16, 0) : null,
      prefix: _normalizedSnippet(prefix),
      suffix: _normalizedSnippet(suffix),
      progression: progression != null
          ? math.min(math.max(progression, 0.0), 1.0)
          : null,
      positionHint: positionHint != null ? math.max(positionHint, 1) : null,
      totalPositionsHint:
          totalPositionsHint != null ? math.max(totalPositionsHint, 1) : null,
      rendererLocatorJson: _normalizedSnippet(rendererLocatorJson),
    );
  }

  /// 从 CanonicalLocator + RenderedLocator 构造选区，
  /// 与 iOS ReaderSelection.init(bookId:canonicalLocator:renderedLocator:...) 对齐。
  factory ReaderSelection.fromLocators({
    required String bookId,
    required CanonicalLocator canonicalLocator,
    RenderedLocator? renderedLocator,
    String? selectedText,
  }) {
    final anchor = canonicalLocator.textAnchor;
    final normalizedSelected = _normalizedSnippet(selectedText) ??
        _normalizedSnippet(anchor?.quote) ??
        _normalizedSnippet(
            CanonicalLocator.excerptFromHref(canonicalLocator.href ?? '')) ??
        _normalizedSnippet(renderedLocator?.textAfter) ??
        _normalizedSnippet(renderedLocator?.textBefore) ??
        '';
    final resolvedFormat = canonicalLocator.format;
    final resolvedRenderer =
        renderedLocator?.renderer ?? _defaultRenderer(resolvedFormat);
    final resourceHref = canonicalLocator.resourceHref ??
        canonicalLocator.href ??
        renderedLocator?.href;
    final startOffset = anchor?.startOffsetUtf16 ??
        anchor?.offsetHint ??
        (resourceHref != null
            ? CanonicalLocator.offsetFromHref(resourceHref)
            : null);
    final startOffsetUtf16Val =
        startOffset != null ? math.max(startOffset, 0) : null;
    final lengthUtf16Val = anchor?.lengthUtf16 ??
        (normalizedSelected.isEmpty ? 0 : normalizedSelected.length);

    return ReaderSelection.create(
      bookId: bookId,
      format: resolvedFormat,
      renderer: resolvedRenderer,
      selectedText: normalizedSelected,
      chapterId: canonicalLocator.chapterId ??
          anchor?.chapterId ??
          (resourceHref != null
              ? CanonicalLocator.chapterIdFromHref(resourceHref)
              : null),
      resourceHref: resourceHref,
      startOffsetUtf16: startOffsetUtf16Val,
      lengthUtf16: lengthUtf16Val,
      prefix: anchor?.prefix ?? renderedLocator?.textBefore,
      suffix: anchor?.suffix ?? renderedLocator?.textAfter,
      progression: canonicalLocator.progression ??
          renderedLocator?.totalProgression ??
          renderedLocator?.progression,
      positionHint: canonicalLocator.positionHint ?? renderedLocator?.position,
      totalPositionsHint: canonicalLocator.totalPositionsHint ??
          renderedLocator?.totalPositions,
      rendererLocatorJson: renderedLocator != null
          ? LocatorCodec.encodeRenderedLocator(renderedLocator)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'bookId': bookId,
      'format': format.name,
      'renderer': renderer.name,
      'selectedText': selectedText,
    };
    if (chapterId != null) map['chapterId'] = chapterId;
    if (resourceHref != null) map['resourceHref'] = resourceHref;
    if (startOffsetUtf16 != null) map['startOffsetUtf16'] = startOffsetUtf16;
    if (lengthUtf16 != null) map['lengthUtf16'] = lengthUtf16;
    if (prefix != null) map['prefix'] = prefix;
    if (suffix != null) map['suffix'] = suffix;
    if (progression != null) map['progression'] = progression;
    if (positionHint != null) map['positionHint'] = positionHint;
    if (totalPositionsHint != null) {
      map['totalPositionsHint'] = totalPositionsHint;
    }
    if (rendererLocatorJson != null) {
      map['rendererLocatorJson'] = rendererLocatorJson;
    }
    return map;
  }

  factory ReaderSelection.fromJson(Map<String, dynamic> json) {
    final formatRaw = json['format'] as String?;
    final format = formatRaw != null
        ? BookFormat.values.firstWhere(
            (e) => e.name == formatRaw,
            orElse: () => BookFormat.unknown,
          )
        : BookFormat.unknown;
    final rendererRaw = json['renderer'] as String?;
    final renderer = rendererRaw != null
        ? ReaderRendererType.values.firstWhere(
            (e) => e.name == rendererRaw,
            orElse: () => ReaderRendererType.foliate,
          )
        : ReaderRendererType.foliate;
    return ReaderSelection.create(
      bookId: (json['bookId'] as String?) ?? '',
      format: format,
      renderer: renderer,
      selectedText: (json['selectedText'] as String?) ?? '',
      chapterId: json['chapterId'] as String?,
      resourceHref: json['resourceHref'] as String?,
      startOffsetUtf16: json['startOffsetUtf16'] as int?,
      lengthUtf16: json['lengthUtf16'] as int?,
      prefix: json['prefix'] as String?,
      suffix: json['suffix'] as String?,
      progression: (json['progression'] as num?)?.toDouble(),
      positionHint: json['positionHint'] as int?,
      totalPositionsHint: json['totalPositionsHint'] as int?,
      rendererLocatorJson: json['rendererLocatorJson'] as String?,
    );
  }

  @override
  int get hashCode => Object.hash(
        bookId,
        format,
        renderer,
        selectedText,
        chapterId,
        resourceHref,
        startOffsetUtf16,
        lengthUtf16,
        prefix,
        suffix,
        progression,
        positionHint,
        totalPositionsHint,
        rendererLocatorJson,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderSelection &&
          bookId == other.bookId &&
          format == other.format &&
          renderer == other.renderer &&
          selectedText == other.selectedText &&
          chapterId == other.chapterId &&
          resourceHref == other.resourceHref &&
          startOffsetUtf16 == other.startOffsetUtf16 &&
          lengthUtf16 == other.lengthUtf16 &&
          prefix == other.prefix &&
          suffix == other.suffix &&
          progression == other.progression &&
          positionHint == other.positionHint &&
          totalPositionsHint == other.totalPositionsHint &&
          rendererLocatorJson == other.rendererLocatorJson;

  @override
  String toString() => 'ReaderSelection(bookId: $bookId, '
      'format: ${format.name}, selectedText: "${_truncate(selectedText, 40)}")';
}

// ---------------------------------------------------------------------------
// LocatorCodec
// ---------------------------------------------------------------------------

/// JSON 编解码器：对所有定位类型提供统一的序列化/反序列化能力。
/// 与 iOS ReaderKernelJSONCodec 对齐。
class LocatorCodec {
  // -- TextAnchor -----------------------------------------------------------

  static String encodeTextAnchor(TextAnchor anchor) {
    return _jsonEncode(anchor.toJson());
  }

  static TextAnchor? decodeTextAnchor(String raw) {
    final map = _jsonDecode(raw);
    if (map == null) return null;
    return TextAnchor.fromJson(map);
  }

  // -- CanonicalLocator -----------------------------------------------------

  static String encodeCanonicalLocator(CanonicalLocator locator) {
    return _jsonEncode(locator.toJson());
  }

  static CanonicalLocator? decodeCanonicalLocator(String raw) {
    final map = _jsonDecode(raw);
    if (map == null) return null;
    return CanonicalLocator.fromJson(map);
  }

  // -- RenderedLocator ------------------------------------------------------

  static String encodeRenderedLocator(RenderedLocator locator) {
    return _jsonEncode(locator.toJson());
  }

  static RenderedLocator? decodeRenderedLocator(String raw) {
    final map = _jsonDecode(raw);
    if (map == null) return null;
    return RenderedLocator.fromJson(map);
  }

  // -- AnnotationAnchor -----------------------------------------------------

  static String encodeAnnotationAnchor(AnnotationAnchor anchor) {
    return _jsonEncode(anchor.toJson());
  }

  static AnnotationAnchor? decodeAnnotationAnchor(String raw) {
    final map = _jsonDecode(raw);
    if (map == null) return null;
    return AnnotationAnchor.fromJson(map);
  }

  // -- ReaderSelection ------------------------------------------------------

  static String encodeReaderSelection(ReaderSelection selection) {
    return _jsonEncode(selection.toJson());
  }

  static ReaderSelection? decodeReaderSelection(String raw) {
    final map = _jsonDecode(raw);
    if (map == null) return null;
    return ReaderSelection.fromJson(map);
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// 规范化文本片段：统一换行、压缩空白、裁剪首尾空白。
/// 与 iOS TextAnchor.normalizedSnippet 语义一致。
String? _normalizedSnippet(String? raw) {
  if (raw == null) return null;
  final normalized = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[^\S\n]+'), ' ')
      .trim();
  return normalized.isEmpty ? null : normalized;
}

/// 构建 text:// URI 方案的 href。
/// 与 iOS ReaderDocument.textAnchorHref 语义一致。
String? _buildTextAnchorHref({
  String? chapterId,
  int? absoluteOffset,
  String? excerpt,
}) {
  final normalizedExcerpt = _textAnchorExcerpt(excerpt ?? '');
  final encodedExcerpt =
      normalizedExcerpt.isEmpty ? null : Uri.encodeComponent(normalizedExcerpt);

  if (chapterId != null && chapterId.isNotEmpty) {
    final encodedChapterId = Uri.encodeComponent(chapterId);
    if (absoluteOffset != null && absoluteOffset >= 0) {
      if (encodedExcerpt != null) {
        return 'text://chapter/$encodedChapterId/offset/$absoluteOffset/excerpt/$encodedExcerpt';
      }
      return 'text://chapter/$encodedChapterId/offset/$absoluteOffset';
    }
    if (encodedExcerpt != null) {
      return 'text://chapter/$encodedChapterId/excerpt/$encodedExcerpt';
    }
  }

  if (absoluteOffset != null && absoluteOffset >= 0) {
    if (encodedExcerpt != null) {
      return 'text://offset/$absoluteOffset/excerpt/$encodedExcerpt';
    }
    return 'text://offset/$absoluteOffset';
  }

  if (encodedExcerpt != null) return 'text://excerpt/$encodedExcerpt';
  return null;
}

/// 截取文本锚点 excerpt：规范化后截取前 limit 个字符。
/// 与 iOS ReaderDocument.textAnchorExcerpt 语义一致。
String _textAnchorExcerpt(String text, {int limit = 72}) {
  final normalized = _normalizedSnippet(text) ?? '';
  if (normalized.isEmpty) return '';
  return normalized.length <= limit
      ? normalized
      : normalized.substring(0, limit);
}

/// URL 路径解码，处理可能包含 % 编码的字符串。
String? _decodeUrl(String encoded) {
  try {
    return Uri.decodeComponent(encoded.trim());
  } catch (_) {
    // Uri.decodeComponent throws on malformed input; fall back to raw string.
    return encoded.trim();
  }
}

/// 拆分 href 路径段（保留空段，与 iOS split(separator:omittingEmptySubsequences:false) 一致）。
List<String> _splitHrefPath(String path) {
  return path.split('/');
}

/// 列表相等判断。
bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// nullable 列表相等判断。
bool _nullableListEq(List<String>? a, List<String>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return _listEq(a, b);
}

/// JSON 编码。
String _jsonEncode(Map<String, dynamic> map) {
  return jsonEncode(map);
}

/// JSON 解码。
Map<String, dynamic>? _jsonDecode(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  } catch (_) {
    return null;
  }
}

/// 默认渲染器回退，与 iOS ReaderBackendPlanner.legacyCompatibleRenderer 对齐。
ReaderRendererType _defaultRenderer(BookFormat format) {
  if (format == BookFormat.txt) return ReaderRendererType.foliate;
  if (format.supportsTextFallback) return ReaderRendererType.textKit;
  return ReaderRendererType.readium;
}

/// String 截断辅助，用于 toString 中的长文本摘要。
String _truncate(String value, int maxLen) =>
    value.length <= maxLen ? value : '${value.substring(0, maxLen)}...';

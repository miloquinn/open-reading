// 文件说明：本地书籍格式能力注册表（导入过滤 + 阅读管线目标）。
// 技术要点：单一事实来源；对齐 Lightink 逆向结论与 Open Reading 扩展目标。
// 详见 docs/book-format-support.md

/// 本地阅读 / 导入对某种格式的能力级别。
enum BookFormatCapability {
  /// 可完整导入并阅读（统一文本分页或专用渲染器）。
  fullReader,

  /// 解析为章节纯文本后进入统一分页（如 EPUB）。
  convertThenLayout,

  /// 容器：解压/展开后按内层格式再路由。
  container,

  /// 可导入书架、抽元数据/封面；正文阅读引擎仍弱或未完成。
  metadataImport,

  /// 产品目标已确定，实现尚未完成（勿当已可用）。
  planned,

  /// 明确不做或极低优先级。
  unsupported,
}

/// 导入后进入阅读器的推荐管线（目标架构）。
enum BookReaderPipeline {
  /// 编码探测 → 切章 → NativeTextPaginator。
  plainTextChapters,

  /// 解析结构 → 章节纯文本 → NativeTextPaginator。
  structuredToPlainText,

  /// 解压 → 检测内层 → 再路由。
  extractThenReroute,

  /// 专用渲染（PDF 页、漫画页等），不走文本行盒。
  dedicatedRenderer,

  /// 尚未接线。
  none,
}

/// 单一格式描述。
class BookFormatSpec {
  const BookFormatSpec({
    required this.id,
    required this.extensions,
    required this.displayName,
    required this.capability,
    required this.pipeline,
    required this.acceptInFilePicker,
    this.notes = '',
    this.lightinkNote = '',
  });

  /// 稳定标识，如 `txt`、`epub`、`kindle`。
  final String id;

  /// 小写扩展名，不含点。
  final List<String> extensions;

  final String displayName;
  final BookFormatCapability capability;
  final BookReaderPipeline pipeline;

  /// 是否出现在系统文件选择器允许列表中。
  final bool acceptInFilePicker;

  final String notes;

  /// Lightink 1.22 静态逆向对照（给移植与对齐用）。
  final String lightinkNote;

  bool matchesExtension(String extension) {
    final ext = BookFormatRegistry.normalizeExtension(extension);
    return extensions.contains(ext);
  }
}

/// Open Reading 本地书籍格式注册表。
///
/// **目标架构（与 Lightink 对齐）：**
/// 所有「文字书」最终进入同一套文本分页（`NativeTextPaginator`），
/// 差异只在进口：TXT 直接切章，EPUB/FB2/… 先抽纯文本，ZIP/RAR 先解压再分流。
class BookFormatRegistry {
  BookFormatRegistry._();

  static const List<BookFormatSpec> all = <BookFormatSpec>[
    BookFormatSpec(
      id: 'txt',
      extensions: <String>['txt'],
      displayName: 'TXT',
      capability: BookFormatCapability.fullReader,
      pipeline: BookReaderPipeline.plainTextChapters,
      acceptInFilePicker: true,
      notes: '编码探测 + 章节规则 + NativeTextPaginator。',
      lightinkNote: 'TxtImporter → ChapterRules → TxtLayout（完整主路径）。',
    ),
    BookFormatSpec(
      id: 'epub',
      extensions: <String>['epub'],
      displayName: 'EPUB',
      capability: BookFormatCapability.convertThenLayout,
      pipeline: BookReaderPipeline.structuredToPlainText,
      acceptInFilePicker: true,
      notes: 'epubx 解析；章节文本进入统一分页。非 WebView 排版。',
      lightinkNote:
          'EpubImporter → EpubParser → HtmlParser 抽文本 → 同一 TxtLayout。',
    ),
    BookFormatSpec(
      id: 'pdf',
      extensions: <String>['pdf'],
      displayName: 'PDF',
      capability: BookFormatCapability.fullReader,
      pipeline: BookReaderPipeline.dedicatedRenderer,
      acceptInFilePicker: true,
      notes:
          'PdfReaderPage 按页位图渲染（pdfx，串行渲染 + LRU 缓存）。'
          'pdfx 无 Linux 实现，Linux 端仅导入并提示不可读。',
      lightinkNote: '仅 MIME；无应用内 PDF 排版引擎。OR 能力已超出 Lightink。',
    ),
    BookFormatSpec(
      id: 'kindle',
      extensions: <String>['mobi', 'azw', 'azw3'],
      displayName: 'MOBI / AZW / AZW3',
      capability: BookFormatCapability.convertThenLayout,
      pipeline: BookReaderPipeline.structuredToPlainText,
      acceptInFilePicker: true,
      notes:
          'kindle_unpack 解析（KF8 skeleton 分段 / MOBI7 按 pagebreak 切章），'
          'XHTML 走 EPUB 同款章节转换；DRM 书籍仅元数据与封面，正文提示不可读。'
          'Web 端无解析器，不放行阅读。',
      lightinkNote: '有图标与 MIME，无本地 mobi 解析模块；OR 能力已超出 Lightink。',
    ),
    BookFormatSpec(
      id: 'fb2',
      extensions: <String>['fb2'],
      displayName: 'FB2',
      capability: BookFormatCapability.convertThenLayout,
      pipeline: BookReaderPipeline.structuredToPlainText,
      acceptInFilePicker: true,
      notes: 'section 切章 + XML 抽文本 → 统一分页（Lightink 未做，OR 扩展）。',
      lightinkNote: '未支持。',
    ),
    BookFormatSpec(
      id: 'rtf',
      extensions: <String>['rtf'],
      displayName: 'RTF',
      capability: BookFormatCapability.convertThenLayout,
      pipeline: BookReaderPipeline.structuredToPlainText,
      acceptInFilePicker: true,
      notes: '去 RTF 控制字 → 纯文本分页。',
      lightinkNote: '未支持。',
    ),
    BookFormatSpec(
      id: 'docx',
      extensions: <String>['docx'],
      displayName: 'Word (DOCX)',
      capability: BookFormatCapability.convertThenLayout,
      pipeline: BookReaderPipeline.structuredToPlainText,
      acceptInFilePicker: true,
      notes: 'document.xml 抽正文 → 统一分页；复杂版式不保证。',
      lightinkNote: '未支持。',
    ),
    BookFormatSpec(
      id: 'doc',
      extensions: <String>['doc'],
      displayName: 'Word (DOC)',
      capability: BookFormatCapability.metadataImport,
      pipeline: BookReaderPipeline.none,
      acceptInFilePicker: true,
      notes: '旧版二进制 Word，仅可导入书架；正文解析无纯 Dart 方案，暂不做。',
      lightinkNote: '未支持。',
    ),
    BookFormatSpec(
      id: 'html',
      extensions: <String>['html', 'htm', 'xhtml'],
      displayName: 'HTML',
      capability: BookFormatCapability.convertThenLayout,
      pipeline: BookReaderPipeline.structuredToPlainText,
      acceptInFilePicker: true,
      notes: '按标题切章 → 统一分页。',
      lightinkNote: '未支持。',
    ),
    BookFormatSpec(
      id: 'markdown',
      extensions: <String>['md', 'markdown'],
      displayName: 'Markdown',
      capability: BookFormatCapability.convertThenLayout,
      pipeline: BookReaderPipeline.structuredToPlainText,
      acceptInFilePicker: true,
      notes: '去 Markdown 标记 → TXT 章节规则分页。',
      lightinkNote: '未支持。',
    ),
    BookFormatSpec(
      id: 'cbz',
      extensions: <String>['cbz'],
      displayName: 'Comic (CBZ)',
      capability: BookFormatCapability.fullReader,
      pipeline: BookReaderPipeline.dedicatedRenderer,
      acceptInFilePicker: true,
      notes: 'ComicReaderPage 按页图阅读（isolate 解 ZIP + LRU 页缓存），不走文本行盒。',
      lightinkNote: '无漫画引擎。OR 扩展能力。',
    ),
    BookFormatSpec(
      id: 'cbt',
      extensions: <String>['cbt'],
      displayName: 'Comic (CBT)',
      capability: BookFormatCapability.fullReader,
      pipeline: BookReaderPipeline.dedicatedRenderer,
      acceptInFilePicker: true,
      notes: 'TAR 容器漫画；与 CBZ 共用 ComicReaderPage 与页解压管线。',
      lightinkNote: '未支持。',
    ),
    BookFormatSpec(
      id: 'cbr',
      extensions: <String>['cbr'],
      displayName: 'Comic (CBR)',
      capability: BookFormatCapability.metadataImport,
      pipeline: BookReaderPipeline.dedicatedRenderer,
      acceptInFilePicker: true,
      notes:
          'RAR 无纯 Dart 解码；打开时按文件头识别真实容器，'
          '大量改名自 ZIP/TAR 的 CBR 可直接阅读，真 RAR 提示转 CBZ。',
      lightinkNote: 'CBR 仅 MIME 级；无漫画引擎。',
    ),
    BookFormatSpec(
      id: 'cb7',
      extensions: <String>['cb7'],
      displayName: 'Comic (CB7)',
      capability: BookFormatCapability.metadataImport,
      pipeline: BookReaderPipeline.dedicatedRenderer,
      acceptInFilePicker: true,
      notes:
          '7z 无纯 Dart 解码；打开时按文件头识别真实容器，'
          '实为 ZIP/TAR 的文件可直接阅读，真 7z 提示转 CBZ。',
      lightinkNote: '未支持。',
    ),
    BookFormatSpec(
      id: 'zip',
      extensions: <String>['zip'],
      displayName: 'ZIP',
      capability: BookFormatCapability.planned,
      pipeline: BookReaderPipeline.extractThenReroute,
      acceptInFilePicker: false,
      notes: '计划：解压后扫描内层 txt/epub 等再导入；实现前不进选择器。',
      lightinkNote: 'archive ZipDecoder 容器；内层分流。',
    ),
    BookFormatSpec(
      id: 'rar',
      extensions: <String>['rar'],
      displayName: 'RAR',
      capability: BookFormatCapability.planned,
      pipeline: BookReaderPipeline.extractThenReroute,
      acceptInFilePicker: false,
      notes: '计划：解压后内层分流；实现前不进选择器。',
      lightinkNote: 'package:unrar_file 可解压；阅读看内层。',
    ),
  ];

  /// 文件选择器 / 扫描允许的扩展名（当前已接导入）。
  static Set<String> get pickerExtensions => <String>{
    for (final spec in all)
      if (spec.acceptInFilePicker) ...spec.extensions,
  };

  /// 有明确阅读管线目标的扩展名（含 planned 容器，便于文档与后续实现）。
  static Set<String> get allKnownExtensions => <String>{
    for (final spec in all) ...spec.extensions,
  };

  static String normalizeExtension(String raw) {
    var ext = raw.trim().toLowerCase();
    if (ext.startsWith('.')) {
      ext = ext.substring(1);
    }
    return ext;
  }

  static BookFormatSpec? specForExtension(String extension) {
    final ext = normalizeExtension(extension);
    for (final spec in all) {
      if (spec.extensions.contains(ext)) {
        return spec;
      }
    }
    return null;
  }

  static bool isAcceptedByPicker(String extension) =>
      pickerExtensions.contains(normalizeExtension(extension));

  /// 是否应以「统一文本分页」作为最终阅读目标。
  static bool targetsUnifiedTextLayout(String extension) {
    final spec = specForExtension(extension);
    if (spec == null) return false;
    return spec.pipeline == BookReaderPipeline.plainTextChapters ||
        spec.pipeline == BookReaderPipeline.structuredToPlainText;
  }

  /// 当前能力是否已达到可读正文（完整或转文本后）。
  static bool hasReadableTextPipeline(String extension) {
    final spec = specForExtension(extension);
    if (spec == null) return false;
    return spec.capability == BookFormatCapability.fullReader ||
        spec.capability == BookFormatCapability.convertThenLayout;
  }
}

// 文件说明：书籍数据模型，定义书籍元数据、阅读进度、缓存字段和 CanonicalLocator 双轨定位字段。
// 技术要点：Dart 数据模型、CanonicalLocator JSON 序列化、nullable 新字段兼容旧数据。

import 'package:xxread/core/reader/canonical_locator.dart';

class Book {
  final int? id;
  final String title;
  final String author;
  final String filePath; // 存储书籍文件的路径，而不是内容
  final String format;
  final int currentPage;
  final int totalPages; // 添加总页数字段
  final DateTime importDate;
  // 缓存相关字段
  final String? cachedContent;
  final String? cachedPages;
  final int? fileModifiedTime;
  final String? contentHash;
  final String? tableOfContents;
  final String? coverImagePath; // 书籍封面图片路径
  final String? textEncoding; // TXT编码（导入时自动检测的结果）

  // ---- CanonicalLocator 双轨定位字段 ----

  /// 上次阅读位置的 CanonicalLocator JSON 序列化。
  ///
  /// 布局无关定位真相源，跨设备、跨排版参数可稳定恢复。
  /// null 表示该书籍尚无 canonical 进度记录（旧数据兼容）。
  final String? lastCanonicalLocator;

  /// 上次阅读位置的 RenderedLocator JSON 序列化。
  ///
  /// 当前设备 + 当前排版参数下的屏幕位置，仅用于 UI 快速恢复。
  /// null 表示该书籍尚无 rendered 进度记录。
  final String? lastRenderedLocator;

  /// 排版参数指纹。
  ///
  /// 由字号/行高/边距/视口/翻页模式等排版参数决定。
  /// 任何影响分页结果的设置变更都会导致 layoutSignature 变化，
  /// 旧分页缓存和 rendered locator 失效。
  /// null 表示尚未计算或旧数据兼容。
  final String? layoutSignature;

  Book({
    this.id,
    required this.title,
    this.author = '未知',
    required this.filePath,
    required this.format,
    this.currentPage = 0,
    this.totalPages = 1, // 默认总页数为1
    DateTime? importDate,
    this.cachedContent,
    this.cachedPages,
    this.fileModifiedTime,
    this.contentHash,
    this.tableOfContents,
    this.coverImagePath,
    this.textEncoding,
    this.lastCanonicalLocator,
    this.lastRenderedLocator,
    this.layoutSignature,
  }) : importDate = importDate ?? DateTime.now();

  // content 字段已被移除

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'format': format,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'importDate': importDate.millisecondsSinceEpoch,
      'cached_content': cachedContent,
      'cached_pages': cachedPages,
      'file_modified_time': fileModifiedTime,
      'content_hash': contentHash,
      'table_of_contents': tableOfContents,
      'cover_image_path': coverImagePath,
      'text_encoding': textEncoding,
      'last_canonical_locator': lastCanonicalLocator,
      'last_rendered_locator': lastRenderedLocator,
      'layout_signature': layoutSignature,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      author: map['author'] ?? '未知',
      filePath: map['filePath'],
      format: map['format'],
      currentPage: map['currentPage'] ?? 0,
      totalPages: map['totalPages'] ?? 1,
      importDate: DateTime.fromMillisecondsSinceEpoch(map['importDate']),
      cachedContent: map['cached_content'],
      cachedPages: map['cached_pages'],
      fileModifiedTime: map['file_modified_time'],
      contentHash: map['content_hash'],
      tableOfContents: map['table_of_contents'],
      coverImagePath: map['cover_image_path'],
      textEncoding: map['text_encoding'],
      lastCanonicalLocator: map['last_canonical_locator'],
      lastRenderedLocator: map['last_rendered_locator'],
      layoutSignature: map['layout_signature'],
    );
  }

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? filePath,
    String? format,
    int? currentPage,
    int? totalPages,
    DateTime? importDate,
    String? cachedContent,
    String? cachedPages,
    int? fileModifiedTime,
    String? contentHash,
    String? tableOfContents,
    String? coverImagePath,
    String? textEncoding,
    String? lastCanonicalLocator,
    String? lastRenderedLocator,
    String? layoutSignature,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      importDate: importDate ?? this.importDate,
      cachedContent: cachedContent ?? this.cachedContent,
      cachedPages: cachedPages ?? this.cachedPages,
      fileModifiedTime: fileModifiedTime ?? this.fileModifiedTime,
      contentHash: contentHash ?? this.contentHash,
      tableOfContents: tableOfContents ?? this.tableOfContents,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      textEncoding: textEncoding ?? this.textEncoding,
      lastCanonicalLocator: lastCanonicalLocator ?? this.lastCanonicalLocator,
      lastRenderedLocator: lastRenderedLocator ?? this.lastRenderedLocator,
      layoutSignature: layoutSignature ?? this.layoutSignature,
    );
  }

  /// 从 lastCanonicalLocator JSON 解析为 CanonicalLocator 对象。
  ///
  /// 返回 null 表示该书籍尚无 canonical 进度记录，
  /// 或 JSON 解析失败（旧数据格式损坏）。
  CanonicalLocator? toCanonicalLocator() {
    if (lastCanonicalLocator == null || lastCanonicalLocator!.trim().isEmpty) {
      return null;
    }
    return LocatorCodec.decodeCanonicalLocator(lastCanonicalLocator!);
  }

  /// 从 lastRenderedLocator JSON 解析为 RenderedLocator 对象。
  ///
  /// 返回 null 表示该书籍尚无 rendered 进度记录，
  /// 或 JSON 解析失败。
  RenderedLocator? toRenderedLocator() {
    if (lastRenderedLocator == null || lastRenderedLocator!.trim().isEmpty) {
      return null;
    }
    return LocatorCodec.decodeRenderedLocator(lastRenderedLocator!);
  }
}

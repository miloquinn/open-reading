// 文件说明：Kindle（MOBI/AZW/AZW3）解析结果模型与异常类型。
// 技术要点：与平台实现解耦的纯数据结构；DRM 与解析失败使用独立异常，
// 便于导入侧回退元数据、阅读侧展示明确提示。
// 详见 docs/book-format-support.md

import 'dart:typed_data';

/// Kindle 书籍的头部元数据（EXTH + MOBI header），不含正文。
///
/// 即使正文被 DRM 加密，头部元数据与封面图通常仍可读取。
class KindleBookMetadata {
  const KindleBookMetadata({
    required this.title,
    required this.authors,
    required this.textLength,
    required this.hasDrm,
    this.description,
    this.language,
    this.publisher,
    this.isbn,
    this.publishedDate,
    this.subjects = const <String>[],
    this.coverImage,
  });

  final String title;
  final List<String> authors;
  final String? description;
  final String? language;
  final String? publisher;
  final String? isbn;
  final String? publishedDate;
  final List<String> subjects;

  /// EXTH 201 指向的封面原始字节；没有内嵌封面时为 null。
  final Uint8List? coverImage;

  /// 正文未压缩字节总长（PalmDOC header），用于估算页数。
  final int textLength;

  /// 正文是否被 DRM 加密（此时无法解出正文，元数据仍可用）。
  final bool hasDrm;
}

/// Kindle 书籍的可读内容：元数据 + 已解码为字符串的 XHTML 分段。
///
/// KF8 按 skeleton 拆分为多段；老 MOBI7 通常只有一段完整 HTML。
class KindleBookContent {
  const KindleBookContent({
    required this.metadata,
    required this.htmlParts,
    this.imagesByName = const <String, Uint8List>{},
    this.imageNameByBlockIndex = const <int, String>{},
    this.cssParts = const <String>[],
  });

  final KindleBookMetadata metadata;
  final List<String> htmlParts;

  /// KindleUnpack 命名（image00007.jpg）→ 原始图片字节。
  final Map<String, Uint8List> imagesByName;

  /// 图片块索引 → 文件名，用于把正文里的 `recindex`/`kindle:embed`
  /// （均为 1-based 块索引）重写成可查表的文件名。
  final Map<int, String> imageNameByBlockIndex;

  /// KF8 CSS flow 文本（MOBI7 无独立 CSS，恒为空）。
  final List<String> cssParts;
}

/// 把正文里的 Kindle 图片引用重写成 `image00007.jpg` 形式的文件名，
/// 供阅读器章节转换按 basename 查 [KindleBookContent.imagesByName]。
///
/// 两种引用形态（KindleUnpack 逆向约定，值都是 1-based 图片块索引）：
/// - MOBI7：`<img recindex="00007">`
/// - KF8：`src="kindle:embed:0007?mime=image/jpg"`（索引为 base32，
///   字母表 0-9A-V，与 `int.parse(radix: 32)` 一致）
String rewriteKindleImageRefs(String html, Map<int, String> nameByBlockIndex) {
  if (nameByBlockIndex.isEmpty) return html;
  var output = html.replaceAllMapped(
    RegExp(
      r'''(src|href|xlink:href)\s*=\s*["']kindle:embed:([0-9A-Va-v]+)[^"']*["']''',
      caseSensitive: false,
    ),
    (match) {
      final index = int.tryParse(match.group(2)!, radix: 32);
      final name = index == null ? null : nameByBlockIndex[index - 1];
      return name == null ? match.group(0)! : 'src="$name"';
    },
  );
  output = output.replaceAllMapped(
    RegExp(r'''recindex\s*=\s*["']?(\d+)["']?''', caseSensitive: false),
    (match) {
      final index = int.tryParse(match.group(1)!);
      final name = index == null ? null : nameByBlockIndex[index - 1];
      return name == null ? match.group(0)! : 'src="$name"';
    },
  );
  return output;
}

/// 正文被 DRM 加密，无法解压。携带尽力提取的元数据供导入侧使用。
class KindleDrmException implements Exception {
  const KindleDrmException(this.metadata);

  final KindleBookMetadata metadata;

  @override
  String toString() => 'KindleDrmException: ${metadata.title}';
}

/// 文件不是有效的 Kindle 容器或头部/正文解析失败。
class KindleParseException implements Exception {
  const KindleParseException(this.message);

  final String message;

  @override
  String toString() => 'KindleParseException: $message';
}

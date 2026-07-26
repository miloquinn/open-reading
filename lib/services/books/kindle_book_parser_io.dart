// 文件说明：Kindle（MOBI/AZW/AZW3）解析的原生平台实现。
// 技术要点：基于 kindle_unpack（PalmDB → MOBI/EXTH → PalmDOC/HUFF-CDIC 解压 →
// KF8 XHTML 拼接）；先查头部 DRM 标志再解正文；按 MOBI textEncoding
// 以 UTF-8 或 CP1252 解码分段。仅头部解析开销极小，可在主 isolate 调用；
// 全文解析应放入 compute。
// 详见 docs/book-format-support.md

import 'dart:convert';
import 'dart:typed_data';

import 'package:kindle_unpack/kindle_unpack.dart';

import 'package:xxread/services/books/kindle_book_parser_types.dart';

/// CP1252 与 Latin-1 仅在 0x80-0x9F 区间不同；老 MOBI 的智能引号、
/// 破折号等常落在该区间，按 CP1252 映射避免出现控制字符。
const Map<int, int> _cp1252HighRange = <int, int>{
  0x80: 0x20AC,
  0x82: 0x201A,
  0x83: 0x0192,
  0x84: 0x201E,
  0x85: 0x2026,
  0x86: 0x2020,
  0x87: 0x2021,
  0x88: 0x02C6,
  0x89: 0x2030,
  0x8A: 0x0160,
  0x8B: 0x2039,
  0x8C: 0x0152,
  0x8E: 0x017D,
  0x91: 0x2018,
  0x92: 0x2019,
  0x93: 0x201C,
  0x94: 0x201D,
  0x95: 0x2022,
  0x96: 0x2013,
  0x97: 0x2014,
  0x98: 0x02DC,
  0x99: 0x2122,
  0x9A: 0x0161,
  0x9B: 0x203A,
  0x9C: 0x0153,
  0x9E: 0x017E,
  0x9F: 0x0178,
};

String _decodeKindleText(Uint8List bytes, int textEncoding) {
  if (textEncoding == 65001) {
    return utf8.decode(bytes, allowMalformed: true);
  }
  final units = List<int>.generate(bytes.length, (index) {
    final byte = bytes[index];
    return _cp1252HighRange[byte] ?? byte;
  }, growable: false);
  return String.fromCharCodes(units);
}

KindleBookMetadata _metadataFromSection(PdbFile pdb, KindleSection section) {
  final exth = section.exth;
  final mobi = section.mobi;
  final record0 = pdb.records[section.recordOffset].data;

  var title = exth?.title ?? '';
  if (title.trim().isEmpty) {
    try {
      title = mobi.fullName(record0);
    } on Exception {
      title = '';
    }
  }
  if (title.trim().isEmpty) {
    title = pdb.header.name;
  }

  Uint8List? cover;
  try {
    // 封面图片记录不参与正文加密，DRM 书籍通常也能取到。
    cover = BookImages.extract(pdb: pdb, mobi: mobi, exth: exth).cover?.data;
  } on Exception {
    cover = null;
  }

  return KindleBookMetadata(
    title: title.trim(),
    authors: exth?.authors ?? const <String>[],
    description: exth?.description,
    language: exth?.language,
    publisher: exth?.publisher,
    isbn: exth?.isbn,
    publishedDate: exth?.publishedDate,
    subjects: exth?.subjects ?? const <String>[],
    coverImage: cover,
    textLength: section.palmDoc.textLength,
    hasDrm: section.palmDoc.isEncrypted || mobi.hasDrm,
  );
}

KindleSection _inspectSection(Uint8List bytes) {
  final pdb = PdbFile.parse(bytes);
  final kindleFile = KindleFile.inspect(pdb);
  final section = kindleFile.kf8 ?? kindleFile.mobi7;
  if (section == null) {
    throw const KindleParseException('no readable MOBI/KF8 section');
  }
  return section;
}

/// 只解析头部（PalmDB/MOBI/EXTH）与封面，不解压正文。
///
/// DRM 书籍不抛异常，通过 [KindleBookMetadata.hasDrm] 标记。
KindleBookMetadata parseKindleMetadata(Uint8List bytes) {
  try {
    final pdb = PdbFile.parse(bytes);
    final kindleFile = KindleFile.inspect(pdb);
    final section = kindleFile.kf8 ?? kindleFile.mobi7;
    if (section == null) {
      throw const KindleParseException('no readable MOBI/KF8 section');
    }
    return _metadataFromSection(pdb, section);
  } on KindleParseException {
    rethrow;
  } on KindleUnpackException catch (error) {
    throw KindleParseException(error.message);
  } catch (error) {
    // 非 Kindle 文件常触发越界等底层错误，统一归一为解析异常。
    throw KindleParseException(error.toString());
  }
}

/// 仅检查正文是否被 DRM 加密；头部解析失败时抛 [KindleParseException]。
bool kindleBookHasDrm(Uint8List bytes) {
  try {
    final section = _inspectSection(bytes);
    return section.palmDoc.isEncrypted || section.mobi.hasDrm;
  } on KindleParseException {
    rethrow;
  } on KindleUnpackException catch (error) {
    throw KindleParseException(error.message);
  } catch (error) {
    throw KindleParseException(error.toString());
  }
}

/// 解析完整正文：元数据 + 解码后的 XHTML 分段。
///
/// DRM 书籍抛 [KindleDrmException]（携带可读的头部元数据）；
/// 其余解析失败抛 [KindleParseException]。
KindleBookContent parseKindleContent(Uint8List bytes) {
  try {
    final pdb = PdbFile.parse(bytes);
    final kindleFile = KindleFile.inspect(pdb);
    final section = kindleFile.kf8 ?? kindleFile.mobi7;
    if (section == null) {
      throw const KindleParseException('no readable MOBI/KF8 section');
    }
    final metadata = _metadataFromSection(pdb, section);
    if (metadata.hasDrm) {
      throw KindleDrmException(metadata);
    }
    final book = KindleBook.fromBytes(bytes);
    final textEncoding = book.mobi.textEncoding;
    final htmlParts = <String>[
      for (final part in book.parts)
        if (part.bytes.isNotEmpty) _decodeKindleText(part.bytes, textEncoding),
    ];
    final imagesByName = book.images.toMap();
    final imageNameByBlockIndex = <int, String>{
      for (final image in book.images.all) image.blockIndex: image.name,
    };
    // KF8 的 CSS 独立成 flow；MOBI7 样式内联在 HTML 里，无需单独收集。
    final cssParts = <String>[
      for (final flow in book.flows?.flows ?? const <FlowSection>[])
        if (flow.kind == FlowKind.css && flow.bytes.isNotEmpty)
          _decodeKindleText(flow.bytes, textEncoding),
    ];
    return KindleBookContent(
      metadata: metadata,
      htmlParts: htmlParts,
      imagesByName: imagesByName,
      imageNameByBlockIndex: imageNameByBlockIndex,
      cssParts: cssParts,
    );
  } on KindleDrmException {
    rethrow;
  } on KindleParseException {
    rethrow;
  } on KindleUnpackException catch (error) {
    throw KindleParseException(error.message);
  } catch (error) {
    throw KindleParseException(error.toString());
  }
}

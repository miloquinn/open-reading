// 文件说明：CBZ 漫画解析（页索引 + 单页解压），供 ComicReaderPage 使用。
// 技术要点：ZIP 目录扫描过滤图片条目、数字感知排序；IO 端走
// InputFileStream 流式读盘避免整包驻留内存，Web 端走内存字节。
// 详见 docs/book-format-support.md

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

const comicImageExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
};

Archive _decodeComicArchive({String? filePath, Uint8List? bytes}) {
  if (bytes != null) {
    return ZipDecoder().decodeBytes(bytes);
  }
  return ZipDecoder().decodeBuffer(InputFileStream(filePath!));
}

/// [name] 是否为漫画页图片条目（排除目录、隐藏文件与 __MACOSX 垃圾）。
bool isComicPageEntry(String name) {
  if (name.contains('__MACOSX')) return false;
  final base = name.split('/').last;
  if (base.isEmpty || base.startsWith('.')) return false;
  final dot = base.lastIndexOf('.');
  if (dot < 0) return false;
  return comicImageExtensions.contains(base.substring(dot + 1).toLowerCase());
}

/// 数字感知的文件名排序：`page2` 排在 `page10` 前，忽略大小写。
int compareComicEntries(String a, String b) {
  final tokens = RegExp(r'\d+|\D+');
  final tokensA = tokens.allMatches(a.toLowerCase()).map((m) => m.group(0)!);
  final tokensB = tokens.allMatches(b.toLowerCase()).map((m) => m.group(0)!);
  final iterA = tokensA.iterator;
  final iterB = tokensB.iterator;
  while (true) {
    final hasA = iterA.moveNext();
    final hasB = iterB.moveNext();
    if (!hasA || !hasB) return (hasA ? 1 : 0) - (hasB ? 1 : 0);
    final tokenA = iterA.current;
    final tokenB = iterB.current;
    final numA = int.tryParse(tokenA);
    final numB = int.tryParse(tokenB);
    int result;
    if (numA != null && numB != null) {
      result = numA.compareTo(numB);
    } else {
      result = tokenA.compareTo(tokenB);
    }
    if (result != 0) return result;
  }
}

/// 解 ZIP 目录，返回排序后的漫画页条目名列表（compute 入口）。
///
/// args：`path`（IO 文件路径）或 `bytes`（Web 内存字节），二选一。
List<String> indexComicPages(Map<String, dynamic> args) {
  final archive = _decodeComicArchive(
    filePath: args['path'] as String?,
    bytes: args['bytes'] as Uint8List?,
  );
  final names = <String>[
    for (final file in archive.files)
      if (file.isFile && isComicPageEntry(file.name)) file.name,
  ];
  names.sort(compareComicEntries);
  return names;
}

/// 按条目名 `name` 解压单页图片（compute 入口）。
///
/// 每次重解 ZIP 目录（开销远小于解压页本体），换取不在 isolate 间
/// 反复拷贝整本压缩包。
Uint8List extractComicPage(Map<String, dynamic> args) {
  final archive = _decodeComicArchive(
    filePath: args['path'] as String?,
    bytes: args['bytes'] as Uint8List?,
  );
  final target = args['name'] as String;
  for (final file in archive.files) {
    if (file.isFile && file.name == target) {
      final content = file.content as List<int>;
      return content is Uint8List ? content : Uint8List.fromList(content);
    }
  }
  throw StateError('comic page not found: $target');
}

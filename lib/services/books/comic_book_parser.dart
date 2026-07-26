// 文件说明：漫画压缩包解析（容器嗅探 + 页索引 + 单页解压），供 ComicReaderPage 使用。
// 技术要点：按文件头识别真实容器而非扩展名——大量 CBR/CB7 实为 ZIP 改名，可直接读；
// ZIP/TAR（CBZ/CBT）走 archive 解码，真 RAR/7z 抛类型化异常交给 UI 提示转 CBZ。
// IO 端走 InputFileStream 流式读盘避免整包驻留内存，Web 端走内存字节。
// 详见 docs/book-format-support.md

import 'dart:io';
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

/// 漫画压缩包的真实容器格式（按文件头识别，与扩展名无关）。
enum ComicContainerFormat { zip, tar, rar, sevenZip, unknown }

/// 真实容器无法解压（真 RAR / 7z / 未知文件头）时抛出；跨 compute isolate
/// 传回 UI 后据 [container] 展示对应的本地化提示。
class ComicArchiveUnsupportedException implements Exception {
  ComicArchiveUnsupportedException(this.container);

  final ComicContainerFormat container;

  @override
  String toString() => 'ComicArchiveUnsupportedException(${container.name})';
}

/// 头部嗅探窗口：覆盖 ZIP/RAR/7z 的前缀魔数与 TAR offset 257 的 ustar。
const _headerProbeLength = 262;

/// 按文件头识别容器；旧式 V7 TAR 无 ustar 魔数，返回 [ComicContainerFormat.unknown]，
/// 由解码入口按声明扩展名兜底。
ComicContainerFormat detectComicContainer(Uint8List header) {
  bool startsWith(List<int> magic) {
    if (header.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (header[i] != magic[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0x50, 0x4B, 0x03, 0x04]) ||
      startsWith(const [0x50, 0x4B, 0x05, 0x06]) ||
      startsWith(const [0x50, 0x4B, 0x07, 0x08])) {
    return ComicContainerFormat.zip;
  }
  if (startsWith(const [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07])) {
    return ComicContainerFormat.rar;
  }
  if (startsWith(const [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])) {
    return ComicContainerFormat.sevenZip;
  }
  const ustar = <int>[0x75, 0x73, 0x74, 0x61, 0x72];
  if (header.length >= _headerProbeLength) {
    var isTar = true;
    for (var i = 0; i < ustar.length; i++) {
      if (header[257 + i] != ustar[i]) {
        isTar = false;
        break;
      }
    }
    if (isTar) return ComicContainerFormat.tar;
  }
  return ComicContainerFormat.unknown;
}

Uint8List _readFileHeader(String filePath) {
  final file = File(filePath).openSync();
  try {
    return Uint8List.fromList(file.readSync(_headerProbeLength));
  } finally {
    file.closeSync();
  }
}

String _extensionOf(String? filePath) {
  if (filePath == null) return '';
  final base = filePath.split(RegExp(r'[/\\]')).last;
  final dot = base.lastIndexOf('.');
  if (dot < 0) return '';
  return base.substring(dot + 1).toLowerCase();
}

Archive _decodeComicArchive({
  String? filePath,
  Uint8List? bytes,
  String? extension,
}) {
  Archive decodeZip() => bytes != null
      ? ZipDecoder().decodeBytes(bytes)
      : ZipDecoder().decodeBuffer(InputFileStream(filePath!));
  Archive decodeTar() => bytes != null
      ? TarDecoder().decodeBytes(bytes)
      : TarDecoder().decodeBuffer(InputFileStream(filePath!));

  final header = bytes ?? _readFileHeader(filePath!);
  final container = detectComicContainer(header);
  switch (container) {
    case ComicContainerFormat.zip:
      return decodeZip();
    case ComicContainerFormat.tar:
      return decodeTar();
    case ComicContainerFormat.rar:
    case ComicContainerFormat.sevenZip:
      throw ComicArchiveUnsupportedException(container);
    case ComicContainerFormat.unknown:
      var ext = extension?.toLowerCase() ?? '';
      if (ext.isEmpty) ext = _extensionOf(filePath);
      // 旧式 V7 TAR 无 ustar 魔数，按声明扩展名兜底再试一次。
      if (ext == 'cbt') return decodeTar();
      // CBZ 交给 ZipDecoder 抛原始错误，避免把损坏包误报成「格式不支持」。
      if (ext == 'cbz' || ext == 'zip') return decodeZip();
      throw ComicArchiveUnsupportedException(container);
  }
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

/// 解容器目录，返回排序后的漫画页条目名列表（compute 入口）。
///
/// args：`path`（IO 文件路径）或 `bytes`（Web 内存字节）二选一；
/// 可选 `ext` 为书籍声明扩展名，供无魔数容器兜底。
List<String> indexComicPages(Map<String, dynamic> args) {
  final archive = _decodeComicArchive(
    filePath: args['path'] as String?,
    bytes: args['bytes'] as Uint8List?,
    extension: args['ext'] as String?,
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
/// 每次重解容器目录（开销远小于解压页本体），换取不在 isolate 间
/// 反复拷贝整本压缩包。
Uint8List extractComicPage(Map<String, dynamic> args) {
  final archive = _decodeComicArchive(
    filePath: args['path'] as String?,
    bytes: args['bytes'] as Uint8List?,
    extension: args['ext'] as String?,
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

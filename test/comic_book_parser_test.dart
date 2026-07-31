import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/books/comic_book_parser.dart';

Uint8List _buildCbz(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

Uint8List _buildCbt(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(TarEncoder().encode(archive));
}

void main() {
  test('页索引：过滤非图片与垃圾条目，按数字感知顺序排序', () {
    final bytes = _buildCbz({
      'vol1/page10.jpg': [1],
      'vol1/page2.jpg': [2],
      'vol1/Page1.PNG': [3],
      'vol1/info.txt': utf8.encode('not a page'),
      '__MACOSX/vol1/page2.jpg': [9],
      'vol1/.hidden.jpg': [9],
      'cover.webp': [4],
    });

    final pages = indexComicPages(<String, dynamic>{'bytes': bytes});

    expect(pages, [
      'cover.webp',
      'vol1/Page1.PNG',
      'vol1/page2.jpg',
      'vol1/page10.jpg',
    ]);
  });

  test('单页解压返回原始字节；缺页抛错', () {
    final bytes = _buildCbz({
      'a.jpg': [10, 20, 30],
      'b.jpg': [40],
    });

    expect(
      extractComicPage(<String, dynamic>{'bytes': bytes, 'name': 'a.jpg'}),
      Uint8List.fromList([10, 20, 30]),
    );
    expect(
      () => extractComicPage(<String, dynamic>{
        'bytes': bytes,
        'name': 'missing.jpg',
      }),
      throwsStateError,
    );
  });

  test('条目过滤规则', () {
    expect(isComicPageEntry('01.jpeg'), isTrue);
    expect(isComicPageEntry('dir/02.WEBP'), isTrue);
    expect(isComicPageEntry('readme.md'), isFalse);
    expect(isComicPageEntry('noextension'), isFalse);
    expect(isComicPageEntry('__MACOSX/01.jpg'), isFalse);
    expect(isComicPageEntry('dir/.DS_Store'), isFalse);
  });

  test('数字感知排序把 page2 排在 page10 之前', () {
    final names = ['p10.jpg', 'p2.jpg', 'p1.jpg', 'a.jpg'];
    names.sort(compareComicEntries);
    expect(names, ['a.jpg', 'p1.jpg', 'p2.jpg', 'p10.jpg']);
  });

  test('CBT（TAR 容器）可建页索引并解出单页', () {
    final bytes = _buildCbt({
      'b2.jpg': [7, 8],
      'b1.png': [9],
      'notes.txt': utf8.encode('not a page'),
    });

    final pages = indexComicPages(<String, dynamic>{
      'bytes': bytes,
      'ext': 'cbt',
    });
    expect(pages, ['b1.png', 'b2.jpg']);
    expect(
      extractComicPage(<String, dynamic>{
        'bytes': bytes,
        'ext': 'cbt',
        'name': 'b2.jpg',
      }),
      Uint8List.fromList([7, 8]),
    );
  });

  test('改名为 CBR/CB7 的 ZIP 按文件头识别后仍可读', () {
    final bytes = _buildCbz({
      '01.jpg': [1],
      '02.jpg': [2],
    });
    for (final ext in ['cbr', 'cb7']) {
      final pages = indexComicPages(<String, dynamic>{
        'bytes': bytes,
        'ext': ext,
      });
      expect(pages, ['01.jpg', '02.jpg'], reason: 'ext=$ext');
    }
  });

  test('真 RAR / 7z 抛类型化不支持异常', () {
    final rar = Uint8List.fromList([
      0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00, // RAR5 魔数
      ...List<int>.filled(64, 0),
    ]);
    expect(
      () => indexComicPages(<String, dynamic>{'bytes': rar, 'ext': 'cbr'}),
      throwsA(
        isA<ComicArchiveUnsupportedException>().having(
          (e) => e.container,
          'container',
          ComicContainerFormat.rar,
        ),
      ),
    );

    final sevenZip = Uint8List.fromList([
      0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, // 7z 魔数
      ...List<int>.filled(64, 0),
    ]);
    expect(
      () => indexComicPages(<String, dynamic>{'bytes': sevenZip, 'ext': 'cb7'}),
      throwsA(
        isA<ComicArchiveUnsupportedException>().having(
          (e) => e.container,
          'container',
          ComicContainerFormat.sevenZip,
        ),
      ),
    );
  });

  test('容器文件头识别', () {
    expect(
      detectComicContainer(
        _buildCbz({
          'a.jpg': [1],
        }),
      ),
      ComicContainerFormat.zip,
    );
    expect(
      detectComicContainer(
        Uint8List.fromList([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]),
      ),
      ComicContainerFormat.rar,
    );
    expect(
      detectComicContainer(
        Uint8List.fromList([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]),
      ),
      ComicContainerFormat.sevenZip,
    );
    final tarHeader = Uint8List(262);
    tarHeader.setRange(257, 262, 'ustar'.codeUnits);
    expect(detectComicContainer(tarHeader), ComicContainerFormat.tar);
    expect(
      detectComicContainer(Uint8List.fromList([1, 2, 3])),
      ComicContainerFormat.unknown,
    );
  });

  test('未知文件头的 CBZ 交给 ZIP 解码抛原始错误，而非「格式不支持」', () {
    expect(
      () => indexComicPages(<String, dynamic>{
        'bytes': Uint8List.fromList([0, 1, 2, 3]),
        'ext': 'cbz',
      }),
      throwsA(isNot(isA<ComicArchiveUnsupportedException>())),
    );
  });
}

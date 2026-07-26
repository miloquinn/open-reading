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
}

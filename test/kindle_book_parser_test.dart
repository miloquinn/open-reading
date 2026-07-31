import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/books/kindle_book_parser.dart';

void main() {
  group('rewriteKindleImageRefs', () {
    const names = <int, String>{
      0: 'image00000.jpg',
      9: 'image00009.png',
      31: 'image00031.gif',
    };

    test('MOBI7 recindex 重写为 src（1-based → 0-based）', () {
      expect(
        rewriteKindleImageRefs('<img recindex="00001" />', names),
        '<img src="image00000.jpg" />',
      );
      expect(
        rewriteKindleImageRefs('<img recindex="10">', names),
        '<img src="image00009.png">',
      );
    });

    test('KF8 kindle:embed 按 base32 解析（0-9A-V）', () {
      expect(
        rewriteKindleImageRefs(
          '<img src="kindle:embed:000A?mime=image/png"/>',
          names,
        ),
        '<img src="image00009.png"/>',
      );
      // base32 '10' = 32 → blockIndex 31。
      expect(
        rewriteKindleImageRefs('<img src="kindle:embed:0010"/>', names),
        '<img src="image00031.gif"/>',
      );
    });

    test('查不到的索引保持原样，不产生坏引用', () {
      const html = '<img recindex="99999">';
      expect(rewriteKindleImageRefs(html, names), html);
      expect(rewriteKindleImageRefs(html, const {}), html);
    });
  });

  test('非 Kindle 字节抛 KindleParseException', () {
    final garbage = Uint8List.fromList(List<int>.filled(4096, 0x41));
    expect(() => parseKindleMetadata(garbage), throwsA(isA<Exception>()));
    expect(() => parseKindleContent(garbage), throwsA(isA<Exception>()));
  });
}

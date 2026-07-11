import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/books/enhanced_txt_import_service.dart';

void main() {
  group('EnhancedTxtImportService encoding detection', () {
    test('accepts UTF-8 when the detection sample cuts a character', () {
      const sampleSize = 256 * 1024;
      final bytes = Uint8List(sampleSize + 5);

      for (var i = 0; i < sampleSize - 1; i += 3) {
        bytes[i] = 0xE4;
        bytes[i + 1] = 0xB8;
        bytes[i + 2] = 0x89; // U+4E09
      }
      bytes[sampleSize - 1] = 0xE6;
      bytes[sampleSize] = 0xB1;
      bytes[sampleSize + 1] = 0x9F; // U+6C5F
      bytes[sampleSize + 2] = 0xE6;
      bytes[sampleSize + 3] = 0x84;
      bytes[sampleSize + 4] = 0x9F; // U+611F

      final service = EnhancedTxtImportService();
      final result = service.decodeWithResult(bytes);

      expect(service.detectEncoding(bytes), 'utf8');
      expect(result.encoding, 'utf8');
      expect(result.content.endsWith('江感'), isTrue);
    });

    test('recovers from a legacy GBK value persisted for UTF-8 text', () {
      final bytes = Uint8List.fromList(utf8.encode('# 三江感言\n正文'));

      final result = EnhancedTxtImportService().decodeWithResult(
        bytes,
        encodingOverride: 'gbk',
        verifyEncodingOverride: true,
      );

      expect(result.encoding, 'utf8');
      expect(result.content, '# 三江感言\n正文');
    });
  });
}

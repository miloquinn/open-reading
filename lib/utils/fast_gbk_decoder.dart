// 文件说明：GBK 快速解码工具，为中文 TXT 导入提供高性能解码能力。
// 技术要点：工具方法、GBK 编解码。

// ignore_for_file: implementation_imports

import 'dart:typed_data';

import 'package:gbk_codec/src/gbk_maps.dart' show json_gbk_to_char;

final Map<int, String> _gbkCodeToChar = () {
  final mapped = <int, String>{};
  json_gbk_to_char.forEach((hex, value) {
    mapped[int.parse(hex, radix: 16)] = value;
  });
  return mapped;
}();

bool isLikelyValidGbkByteStream(Uint8List bytes) {
  int i = 0;
  while (i < bytes.length) {
    final b1 = bytes[i];
    if (b1 <= 0x7f) {
      i += 1;
      continue;
    }
    if (i + 1 >= bytes.length) {
      return false;
    }
    final b2 = bytes[i + 1];
    if (!(b2 >= 0x40 && b2 <= 0xFE && b2 != 0x7F)) {
      return false;
    }
    i += 2;
  }
  return true;
}

String decodeGbkFast(
  Uint8List bytes, {
  bool lenient = true,
}) {
  if (bytes.isEmpty) return '';
  final output = StringBuffer();

  int i = 0;
  while (i < bytes.length) {
    final b1 = bytes[i];
    if (b1 <= 0x7f) {
      output.writeCharCode(b1);
      i += 1;
      continue;
    }

    if (i + 1 < bytes.length) {
      final b2 = bytes[i + 1];
      if (b2 >= 0x40 && b2 <= 0xFE && b2 != 0x7F) {
        final pairCode = (b1 << 8) | b2;
        final mapped = _gbkCodeToChar[pairCode];
        if (mapped != null) {
          output.write(mapped);
        } else if (lenient) {
          output.writeCharCode(b1);
          output.writeCharCode(b2);
        } else {
          output.write('\uFFFD');
        }
        i += 2;
        continue;
      }
    }

    if (lenient) {
      output.writeCharCode(b1);
    } else {
      output.write('\uFFFD');
    }
    i += 1;
  }

  return output.toString();
}

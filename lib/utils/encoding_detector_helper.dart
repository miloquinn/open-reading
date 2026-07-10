// 文件说明：编码检测辅助工具，帮助 TXT 导入阶段判断文本编码。
// 技术要点：工具方法、Flutter。

import 'package:flutter/foundation.dart';

/// 编码检测辅助工具
///
/// 提供编码信息分析和调试功能
class EncodingDetectorHelper {
  /// 分析文件字节并返回详细的编码信息
  ///
  /// [bytes] 文件字节数据
  /// Returns: 包含编码信息的Map
  static Map<String, dynamic> analyzeEncoding(Uint8List bytes) {
    final result = <String, dynamic>{
      'fileSize': bytes.length,
      'hexPreview': _getHexPreview(bytes),
      'bomDetected': _detectBOM(bytes),
      'characteristics': _analyzeCharacteristics(bytes),
      'recommendations': <String>[],
    };

    // 添加建议
    final recommendations = <String>[];
    final bom = result['bomDetected'] as Map<String, dynamic>;

    if (bom['type'] != null) {
      recommendations.add('检测到${bom['type']} BOM标记，建议使用${bom['type']}编码');
    } else {
      final characteristics = result['characteristics'] as Map<String, dynamic>;
      if (characteristics['gbkScore'] > 0.5) {
        recommendations.add('检测到GBK/GB2312特征，建议使用GBK编码（简体中文）');
      }
      if (characteristics['big5Score'] > 0.5) {
        recommendations.add('检测到Big5特征，建议使用Big5编码（繁体中文）');
      }
      if (characteristics['shiftJisScore'] > 0.5) {
        recommendations.add('检测到Shift-JIS特征，建议使用Shift-JIS编码（日文）');
      }
      if (characteristics['utf8Score'] > 0.5) {
        recommendations.add('可能是UTF-8编码（无BOM）');
      }

      if (recommendations.isEmpty) {
        recommendations.add('无法确定编码类型，建议尝试将文件转换为UTF-8编码');
      }
    }

    result['recommendations'] = recommendations;
    return result;
  }

  /// 获取文件头部十六进制预览
  static String _getHexPreview(Uint8List bytes, {int length = 16}) {
    final previewBytes = bytes.take(length);
    return previewBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  /// 检测BOM标记
  static Map<String, dynamic> _detectBOM(Uint8List bytes) {
    if (bytes.length >= 4) {
      // UTF-32 LE
      if (bytes[0] == 0xFF &&
          bytes[1] == 0xFE &&
          bytes[2] == 0x00 &&
          bytes[3] == 0x00) {
        return {
          'type': 'UTF-32 LE',
          'bytes': 'FF FE 00 00',
          'description': 'UTF-32 Little-Endian with BOM',
        };
      }
      // UTF-32 BE
      if (bytes[0] == 0x00 &&
          bytes[1] == 0x00 &&
          bytes[2] == 0xFE &&
          bytes[3] == 0xFF) {
        return {
          'type': 'UTF-32 BE',
          'bytes': '00 00 FE FF',
          'description': 'UTF-32 Big-Endian with BOM',
        };
      }
    }

    if (bytes.length >= 3) {
      // UTF-8 BOM
      if (bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        return {
          'type': 'UTF-8',
          'bytes': 'EF BB BF',
          'description': 'UTF-8 with BOM',
        };
      }
    }

    if (bytes.length >= 2) {
      // UTF-16 LE
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        return {
          'type': 'UTF-16 LE',
          'bytes': 'FF FE',
          'description': 'UTF-16 Little-Endian with BOM',
        };
      }
      // UTF-16 BE
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        return {
          'type': 'UTF-16 BE',
          'bytes': 'FE FF',
          'description': 'UTF-16 Big-Endian with BOM',
        };
      }
    }

    return {
      'type': null,
      'bytes': null,
      'description': '未检测到BOM标记',
    };
  }

  /// 分析字节特征
  static Map<String, dynamic> _analyzeCharacteristics(Uint8List bytes) {
    final checkLength = bytes.length < 2000 ? bytes.length : 2000;

    // GBK特征统计
    int gbkPairCount = 0;
    int gbkTotalPairs = 0;

    // Big5特征统计
    int big5PairCount = 0;
    int big5TotalPairs = 0;

    // Shift-JIS特征统计
    int sjisPairCount = 0;
    int sjisTotalPairs = 0;

    // ASCII统计
    int asciiCount = 0;
    int controlCharCount = 0;

    for (int i = 0; i < checkLength - 1; i++) {
      final byte1 = bytes[i];
      final byte2 = bytes[i + 1];

      // ASCII字符
      if (byte1 >= 0x20 && byte1 <= 0x7E) {
        asciiCount++;
      } else if (byte1 < 0x20 &&
          byte1 != 0x09 &&
          byte1 != 0x0A &&
          byte1 != 0x0D) {
        controlCharCount++;
      }

      // GBK检测
      if (byte1 >= 0x81 && byte1 <= 0xFE) {
        gbkTotalPairs++;
        if (byte2 >= 0x40 && byte2 <= 0xFE && byte2 != 0x7F) {
          gbkPairCount++;
        }
      }

      // Big5检测
      if (byte1 >= 0x81 && byte1 <= 0xFE) {
        big5TotalPairs++;
        if ((byte2 >= 0x40 && byte2 <= 0x7E) ||
            (byte2 >= 0x80 && byte2 <= 0xFE)) {
          big5PairCount++;
        }
      }

      // Shift-JIS检测
      if ((byte1 >= 0x81 && byte1 <= 0x9F) ||
          (byte1 >= 0xE0 && byte1 <= 0xFC)) {
        sjisTotalPairs++;
        if ((byte2 >= 0x40 && byte2 <= 0x7E) ||
            (byte2 >= 0x80 && byte2 <= 0xFC)) {
          sjisPairCount++;
        }
      }
    }

    // 计算各种编码的可能性评分（0.0-1.0）
    final gbkScore = gbkTotalPairs > 0 ? gbkPairCount / gbkTotalPairs : 0.0;
    final big5Score = big5TotalPairs > 0 ? big5PairCount / big5TotalPairs : 0.0;
    final sjisScore = sjisTotalPairs > 0 ? sjisPairCount / sjisTotalPairs : 0.0;

    // UTF-8评分基于控制字符少+ASCII多
    final utf8Score =
        asciiCount > checkLength * 0.3 && controlCharCount < checkLength * 0.05
            ? 0.7
            : 0.3;

    return {
      'gbkScore': gbkScore,
      'gbkPairs': '$gbkPairCount/$gbkTotalPairs',
      'big5Score': big5Score,
      'big5Pairs': '$big5PairCount/$big5TotalPairs',
      'shiftJisScore': sjisScore,
      'shiftJisPairs': '$sjisPairCount/$sjisTotalPairs',
      'utf8Score': utf8Score,
      'asciiCount': asciiCount,
      'asciiRatio':
          '${(asciiCount / checkLength * 100).toStringAsFixed(1)}%',
      'controlCharCount': controlCharCount,
    };
  }

  /// 生成编码分析报告（适合调试输出）
  static String generateReport(Map<String, dynamic> analysis) {
    final buffer = StringBuffer();

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📊 编码检测分析报告');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();

    // 文件信息
    buffer.writeln('📁 文件信息:');
    buffer.writeln('   大小: ${analysis['fileSize']} 字节');
    buffer.writeln('   头部: ${analysis['hexPreview']}');
    buffer.writeln();

    // BOM检测
    final bom = analysis['bomDetected'] as Map<String, dynamic>;
    buffer.writeln('🔖 BOM检测:');
    if (bom['type'] != null) {
      buffer.writeln('   ✅ ${bom['description']}');
      buffer.writeln('   标记: ${bom['bytes']}');
    } else {
      buffer.writeln('   ❌ ${bom['description']}');
    }
    buffer.writeln();

    // 字符特征
    final characteristics = analysis['characteristics'] as Map<String, dynamic>;
    buffer.writeln('📈 字符特征分析:');
    buffer.writeln(
      '   GBK/GB2312:   ${(characteristics['gbkScore'] * 100).toStringAsFixed(1)}% (${characteristics['gbkPairs']})',
    );
    buffer.writeln(
      '   Big5:         ${(characteristics['big5Score'] * 100).toStringAsFixed(1)}% (${characteristics['big5Pairs']})',
    );
    buffer.writeln(
      '   Shift-JIS:    ${(characteristics['shiftJisScore'] * 100).toStringAsFixed(1)}% (${characteristics['shiftJisPairs']})',
    );
    buffer.writeln(
      '   UTF-8可能性:  ${(characteristics['utf8Score'] * 100).toStringAsFixed(1)}%',
    );
    buffer.writeln(
      '   ASCII字符:    ${characteristics['asciiCount']} (${characteristics['asciiRatio']})',
    );
    buffer.writeln();

    // 建议
    buffer.writeln('💡 编码建议:');
    final recommendations = analysis['recommendations'] as List<String>;
    for (final recommendation in recommendations) {
      buffer.writeln('   • $recommendation');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    return buffer.toString();
  }

  /// 简化版报告（用于UI显示）
  static String generateSimpleReport(Map<String, dynamic> analysis) {
    final buffer = StringBuffer();
    final bom = analysis['bomDetected'] as Map<String, dynamic>;
    final recommendations = analysis['recommendations'] as List<String>;

    if (bom['type'] != null) {
      buffer.writeln('检测到 ${bom['type']} 编码');
    } else {
      buffer.writeln('未检测到BOM标记');
    }

    buffer.writeln();
    buffer.writeln('建议:');
    for (final recommendation in recommendations) {
      buffer.writeln('• $recommendation');
    }

    return buffer.toString();
  }

  /// 检测文件是否可能是文本文件
  static bool isProbablyTextFile(Uint8List bytes) {
    if (bytes.isEmpty) return false;

    // 检查BOM
    final bom = _detectBOM(bytes);
    if (bom['type'] != null) return true;

    // 检查前1000字节
    final checkLength = bytes.length < 1000 ? bytes.length : 1000;
    int nullByteCount = 0;
    int controlCharCount = 0;
    int printableCount = 0;

    for (int i = 0; i < checkLength; i++) {
      final byte = bytes[i];

      if (byte == 0x00) {
        nullByteCount++;
      } else if (byte < 0x20 && byte != 0x09 && byte != 0x0A && byte != 0x0D) {
        controlCharCount++;
      } else if ((byte >= 0x20 && byte <= 0x7E) || byte >= 0x80) {
        printableCount++;
      }
    }

    // 如果有太多null字节或控制字符，可能是二进制文件
    if (nullByteCount > checkLength * 0.05) return false;
    if (controlCharCount > checkLength * 0.1) return false;

    // 如果大部分是可打印字符，可能是文本文件
    return printableCount > checkLength * 0.7;
  }

  /// 打印调试信息到控制台
  static void debugPrint(Uint8List bytes) {
    final analysis = analyzeEncoding(bytes);
    final report = generateReport(analysis);
    debugPrintReport(report);
  }

  /// 打印报告到控制台（使用debugPrint避免生产环境输出）
  static void debugPrintReport(String report) {
    // 分行打印，避免单行过长被截断
    for (final line in report.split('\n')) {
      if (kDebugMode) {
        print(line);
      }
    }
  }
}

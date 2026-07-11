// 文件说明：导入隔离线程服务，把哈希计算和元数据提取放到 isolate 执行。
// 技术要点：服务层、Crypto 哈希、文件系统、JSON、Flutter。

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:xxread/utils/fast_gbk_decoder.dart';

/// Isolate工作参数
class HashCalculationParams {
  final String filePath;
  final int chunkSize;

  HashCalculationParams({
    required this.filePath,
    this.chunkSize = 1024 * 1024, // 1MB chunks
  });
}

/// 文件哈希计算结果
class HashCalculationResult {
  final String hash;
  final int fileSize;

  HashCalculationResult({
    required this.hash,
    required this.fileSize,
  });
}

/// 元数据提取参数
///
/// [bytes] 只需传文件头部切片（isolate 消息是拷贝语义，传整文件
/// 会白白复制上百 MB）；[totalByteLength] 传原始文件完整长度，
/// 用于页数估算。
class MetadataExtractionParams {
  final Uint8List bytes;
  final String fileName;
  final String extension;
  final String? encodingOverride;
  final int? totalByteLength;

  MetadataExtractionParams({
    required this.bytes,
    required this.fileName,
    required this.extension,
    this.encodingOverride,
    this.totalByteLength,
  });

  int get effectiveTotalLength => totalByteLength ?? bytes.length;
}

/// 简化的元数据结果（用于isolate传输）
class SimpleMetadata {
  final String title;
  final String author;
  final int estimatedPages;
  final String? description;
  final String? language;

  SimpleMetadata({
    required this.title,
    required this.author,
    required this.estimatedPages,
    this.description,
    this.language,
  });
}

/// 在isolate中分块计算文件哈希
///
/// 参数 [params] 包含文件路径和分块大小
/// 返回包含哈希值和文件大小的结果
Future<HashCalculationResult> calculateFileHashInIsolate(
  HashCalculationParams params,
) async {
  final file = File(params.filePath);
  if (!await file.exists()) {
    throw Exception('File does not exist: ${params.filePath}');
  }

  final fileSize = await file.length();

  // 使用流式计算hash以支持大文件
  final hash = await md5.bind(file.openRead()).first;

  return HashCalculationResult(
    hash: hash.toString(),
    fileSize: fileSize,
  );
}

/// 在isolate中提取TXT元数据
///
/// 参数 [params] 包含文件字节数据、文件名和扩展名
/// 返回简化的元数据对象
Future<SimpleMetadata> extractTxtMetadataInIsolate(
  MetadataExtractionParams params,
) async {
  try {
    // 只读取文件的前100KB用于元数据提取
    const int maxBytesForMetadata = 100 * 1024; // 100KB
    final bytesToAnalyze = params.bytes.length > maxBytesForMetadata
        ? params.bytes.sublist(0, maxBytesForMetadata)
        : params.bytes;

    // 智能检测编码（支持 GB2312/GBK/UTF-8）
    String content = _detectAndDecodeText(
      bytesToAnalyze,
      encodingOverride: params.encodingOverride,
    );

    // 提取标题（从前几行）
    final lines = content
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(20)
        .toList();

    String title = params.fileName
        .replaceAll(RegExp(r'\.(txt)$', caseSensitive: false), '');
    if (lines.isNotEmpty) {
      // 查找合适的标题行
      for (var line in lines) {
        if (line.length >= 2 && line.length <= 50 && !line.contains('http')) {
          title = line.substring(0, line.length.clamp(0, 50));
          break;
        }
      }
    }
    if (_looksGarbled(title) && params.encodingOverride != null) {
      title = params.fileName
          .replaceAll(RegExp(r'\.(txt)$', caseSensitive: false), '');
    }

    // 估算页数（基于文件大小，避免完全解析）
    final estimatedPages =
        (params.effectiveTotalLength / 1500).ceil().clamp(1, 9999);

    // 提取描述（前200字符）
    String? description;
    if (content.length > 100) {
      description = content.substring(0, content.length.clamp(0, 200)).trim();
    }

    return SimpleMetadata(
      title: title,
      author: 'Unknown',
      estimatedPages: estimatedPages,
      description: description,
      language: 'zh',
    );
  } catch (e) {
    debugPrint('TXT元数据提取失败: $e');
    // 返回基础元数据
    return SimpleMetadata(
      title: params.fileName
          .replaceAll(RegExp(r'\.(txt)$', caseSensitive: false), ''),
      author: 'Unknown',
      estimatedPages:
          (params.effectiveTotalLength / 10000).ceil().clamp(1, 9999),
    );
  }
}

bool _looksGarbled(String text) {
  final value = text.trim();
  if (value.isEmpty) {
    return true;
  }

  int total = 0;
  int cjk = 0;
  int asciiLetters = 0;
  int digits = 0;
  int latinExtended = 0;
  int otherNonAscii = 0;
  int replacement = 0;

  for (final rune in value.runes) {
    if (rune <= 0x20) {
      continue;
    }
    total++;
    if (rune == 0xfffd) {
      replacement++;
      continue;
    }
    if ((rune >= 0x4e00 && rune <= 0x9fff) ||
        (rune >= 0x3400 && rune <= 0x4dbf) ||
        (rune >= 0xf900 && rune <= 0xfaff)) {
      cjk++;
      continue;
    }
    if ((rune >= 0x41 && rune <= 0x5a) || (rune >= 0x61 && rune <= 0x7a)) {
      asciiLetters++;
      continue;
    }
    if (rune >= 0x30 && rune <= 0x39) {
      digits++;
      continue;
    }
    if (rune >= 0x00c0 && rune <= 0x024f) {
      latinExtended++;
      continue;
    }
    if (rune > 0x7e) {
      otherNonAscii++;
    }
  }

  if (total == 0 || replacement > 0) {
    return true;
  }

  final asciiRatio = (asciiLetters + digits) / total;
  final cjkRatio = cjk / total;
  final nonAsciiRatio = (latinExtended + otherNonAscii) / total;

  if (cjkRatio >= 0.2) {
    return false;
  }
  if (asciiRatio >= 0.6) {
    return false;
  }
  return nonAsciiRatio >= 0.3;
}

/// 在isolate中提取MOBI元数据
///
/// 参数 [params] 包含文件字节数据、文件名和扩展名
/// 返回简化的元数据对象
Future<SimpleMetadata> extractMobiMetadataInIsolate(
  MetadataExtractionParams params,
) async {
  try {
    String title = params.fileName.replaceAll(
      RegExp(r'\.(mobi|azw|azw3)$', caseSensitive: false),
      '',
    );

    int estimatedPages = 100;

    // 只读取文件头部和部分内容
    if (params.bytes.length >= 68) {
      final identifier = String.fromCharCodes(params.bytes.sublist(60, 68));

      if (identifier.contains('BOOKMOBI') || identifier.contains('TEXTREAD')) {
        // 只分析文件的前500KB
        const int maxBytesForAnalysis = 500 * 1024;
        final bytesToAnalyze = params.bytes.length > maxBytesForAnalysis
            ? params.bytes.sublist(0, maxBytesForAnalysis)
            : params.bytes;

        try {
          // 使用智能编码检测
          String content = _detectAndDecodeText(bytesToAnalyze);
          content = content.replaceAll(RegExp(r'<[^>]*>'), ' ');
          content = content.replaceAll(RegExp(r'\s+'), ' ').trim();

          // 提取标题
          final lines = content.split(' ').take(100).toList();
          for (var line in lines) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty &&
                trimmed.length > 3 &&
                trimmed.length < 100) {
              title = trimmed;
              break;
            }
          }
        } catch (e) {
          debugPrint('MOBI内容分析失败: $e');
        }
      }
    }

    // 基于文件大小估算页数
    estimatedPages =
        (params.effectiveTotalLength / 3000).ceil().clamp(50, 1000);

    return SimpleMetadata(
      title: title,
      author: 'Unknown',
      estimatedPages: estimatedPages,
    );
  } catch (e) {
    debugPrint('MOBI元数据提取失败: $e');
    return SimpleMetadata(
      title: params.fileName.replaceAll(
        RegExp(r'\.(mobi|azw|azw3)$', caseSensitive: false),
        '',
      ),
      author: 'Unknown',
      estimatedPages:
          (params.effectiveTotalLength / 3000).ceil().clamp(50, 1000),
    );
  }
}

/// 智能检测并解码文本（支持 GB2312/GBK/UTF-8）
///
/// 在 isolate 中使用的简化版编码检测
/// 参数 [bytes] 要解码的字节数组
/// 返回解码后的文本内容
String _detectAndDecodeText(Uint8List bytes, {String? encodingOverride}) {
  if (bytes.isEmpty) {
    return '';
  }

  final normalizedOverride = _normalizeEncoding(encodingOverride);
  if (normalizedOverride != 'auto') {
    return _decodeWithEncodingOverride(bytes, normalizedOverride) ??
        utf8.decode(bytes, allowMalformed: true);
  }

  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16LE(bytes.sublist(2));
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16BE(bytes.sublist(2));
  }

  const sampleSize = 256 * 1024;
  final sample =
      bytes.length > sampleSize ? bytes.sublist(0, sampleSize) : bytes;
  const candidates = <String>['utf8', 'gbk', 'utf16le', 'utf16be'];

  String bestEncoding = 'utf8';
  double bestScore = -1e9;

  for (final encoding in candidates) {
    final decoded = _decodeWithEncodingOverride(sample, encoding);
    if (decoded == null || decoded.isEmpty) {
      continue;
    }
    final score = _quickContentScore(decoded, encoding);
    if (score > bestScore) {
      bestScore = score;
      bestEncoding = encoding;
    }
  }

  return _decodeWithEncodingOverride(bytes, bestEncoding) ??
      utf8.decode(bytes, allowMalformed: true);
}

double _quickContentScore(String text, String encoding) {
  if (text.isEmpty) return -1e9;
  final sample = text.length > 6000 ? text.substring(0, 6000) : text;

  int total = 0;
  int replacement = 0;
  int control = 0;
  int cjk = 0;
  int ascii = 0;
  int zero = 0;

  for (final rune in sample.runes) {
    total++;
    if (rune == 0xfffd) replacement++;
    if (rune == 0) zero++;
    if (rune < 32 && rune != 9 && rune != 10 && rune != 13) control++;
    if ((rune >= 0x4e00 && rune <= 0x9fff) ||
        (rune >= 0x3400 && rune <= 0x4dbf)) {
      cjk++;
    }
    if (rune >= 0x20 && rune <= 0x7e) {
      ascii++;
    }
  }

  if (total == 0) return -1e9;
  final replacementRatio = replacement / total;
  final controlRatio = control / total;
  final cjkRatio = cjk / total;
  final asciiRatio = ascii / total;
  final zeroRatio = zero / total;

  var score = cjkRatio * 1.4 +
      asciiRatio * 0.45 -
      replacementRatio * 6.0 -
      controlRatio * 2.2 -
      zeroRatio * 3.0;
  if (encoding == 'gbk') {
    score += 0.15;
  } else if (encoding.startsWith('utf16') && zeroRatio > 0.06) {
    score -= 0.6;
  }
  return score;
}

/// UTF-16 LE 解码
String _decodeUtf16LE(Uint8List bytes) {
  final buffer = StringBuffer();
  for (int i = 0; i < bytes.length - 1; i += 2) {
    final codeUnit = bytes[i] | (bytes[i + 1] << 8);
    buffer.writeCharCode(codeUnit);
  }
  return buffer.toString();
}

/// UTF-16 BE 解码
String _decodeUtf16BE(Uint8List bytes) {
  final buffer = StringBuffer();
  for (int i = 0; i < bytes.length - 1; i += 2) {
    final codeUnit = (bytes[i] << 8) | bytes[i + 1];
    buffer.writeCharCode(codeUnit);
  }
  return buffer.toString();
}

String _normalizeEncoding(String? encoding) {
  if (encoding == null) return 'auto';
  final normalized = encoding.toLowerCase().replaceAll('-', '').trim();
  if (normalized.isEmpty) return 'auto';
  if (normalized == 'gb2312' ||
      normalized == 'gbk' ||
      normalized == 'gb18030' ||
      normalized == 'gb') {
    return 'gbk';
  }
  if (normalized == 'utf8') return 'utf8';
  if (normalized == 'utf16le') return 'utf16le';
  if (normalized == 'utf16be') return 'utf16be';
  return 'auto';
}

String? _decodeWithEncodingOverride(Uint8List bytes, String encoding) {
  switch (encoding) {
    case 'gbk':
      return _decodeGbkBestEffort(bytes);
    case 'utf8':
      return utf8.decode(bytes, allowMalformed: true);
    case 'utf16le':
      return _decodeUtf16LE(bytes);
    case 'utf16be':
      return _decodeUtf16BE(bytes);
    default:
      return null;
  }
}

String _decodeGbkBestEffort(Uint8List bytes) {
  return decodeGbkFast(
    bytes,
    lenient: !isLikelyValidGbkByteStream(bytes),
  );
}

// 文件说明：增强 TXT 导入服务，负责解码检测、文本预处理与章节提取。
// 技术要点：服务层、JSON、Flutter。

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:xxread/services/books/text_preprocessor_helper.dart';
import 'package:xxread/utils/fast_gbk_decoder.dart';

class TxtDecodeResult {
  final String content;
  final String encoding;

  const TxtDecodeResult({required this.content, required this.encoding});
}

/// 增强的TXT文件导入服务
///
/// 提供智能编码检测、元数据提取和分页优化功能
///
/// 核心功能：
/// - [detectTextEncoding] 智能检测文本编码
/// - [extractTxtMetadata] 增强元数据提取
/// - [detectEncoding] 编码检测（返回编码名）
/// - [decodeWithResult] 指定编码解码
class EnhancedTxtImportService {
  final _preprocessor = TextPreprocessor();
  static const int _encodingSampleSize = 256 * 1024;

  static String normalizeEncoding(String? encoding) {
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

  String detectEncoding(Uint8List bytes, {String? encodingOverride}) {
    final normalized = normalizeEncoding(encodingOverride);
    if (normalized != 'auto') {
      return normalized;
    }
    final sample = bytes.length > _encodingSampleSize
        ? bytes.sublist(0, _encodingSampleSize)
        : bytes;
    return _detectTextEncodingWithResult(
      sample,
      sampleMayEndMidCharacter: sample.length < bytes.length,
    ).encoding;
  }

  TxtDecodeResult decodeWithResult(
    Uint8List bytes, {
    String? encodingOverride,
    bool verifyEncodingOverride = false,
  }) {
    final encoding = normalizeEncoding(encodingOverride);
    if (encoding == 'auto') {
      return _detectTextEncodingWithResult(bytes);
    }

    // Older app versions could persist GBK after a UTF-8 sample happened to
    // end in the middle of a multi-byte character. Treat that stored value as
    // a hint and re-detect it so existing books can recover without re-import.
    if (verifyEncodingOverride && encoding == 'gbk') {
      return _detectTextEncodingWithResult(bytes);
    }
    return _decodeWithSpecifiedEncoding(bytes, encoding);
  }

  String decodeWithOverride(
    Uint8List bytes, {
    String? encodingOverride,
    bool verifyEncodingOverride = false,
  }) {
    return decodeWithResult(
      bytes,
      encodingOverride: encodingOverride,
      verifyEncodingOverride: verifyEncodingOverride,
    ).content;
  }

  TxtDecodeResult _decodeWithSpecifiedEncoding(
    Uint8List bytes,
    String encoding,
  ) {
    switch (encoding) {
      case 'gbk':
        return TxtDecodeResult(
          content: _decodeGbkBestEffort(bytes),
          encoding: 'gbk',
        );
      case 'utf16le':
        return TxtDecodeResult(
          content: _decodeUtf16LE(bytes),
          encoding: 'utf16le',
        );
      case 'utf16be':
        return TxtDecodeResult(
          content: _decodeUtf16BE(bytes),
          encoding: 'utf16be',
        );
      case 'utf8':
      default:
        return TxtDecodeResult(
          content: utf8.decode(bytes, allowMalformed: true),
          encoding: 'utf8',
        );
    }
  }

  /// 智能检测文本编码
  ///
  /// 支持主流中文编码格式：UTF-8、GBK/GB2312、UTF-16
  ///
  /// [bytes] 原始文件字节数据
  /// Returns: 解码后的文本内容
  ///
  /// 编码检测策略：
  /// 1. BOM检测（最可靠）
  /// 2. UTF-8严格模式（现代标准）
  /// 3. GBK/GB2312特征检测（中文旧文件）
  /// 4. UTF-8宽松模式（降级方案）
  String detectTextEncoding(Uint8List bytes) {
    return _detectTextEncodingWithResult(bytes).content;
  }

  TxtDecodeResult _detectTextEncodingWithResult(
    Uint8List bytes, {
    bool sampleMayEndMidCharacter = false,
  }) {
    if (bytes.isEmpty) {
      return const TxtDecodeResult(content: '', encoding: 'utf8');
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return TxtDecodeResult(
        content: utf8.decode(bytes.sublist(3), allowMalformed: true),
        encoding: 'utf8',
      );
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return TxtDecodeResult(
        content: _decodeUtf16LE(bytes.sublist(2)),
        encoding: 'utf16le',
      );
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return TxtDecodeResult(
        content: _decodeUtf16BE(bytes.sublist(2)),
        encoding: 'utf16be',
      );
    }

    final sample = bytes.length > _encodingSampleSize
        ? bytes.sublist(0, _encodingSampleSize)
        : bytes;
    final sampleIsTruncated =
        sampleMayEndMidCharacter || sample.length < bytes.length;

    final utf8Valid = _isValidUtf8Bytes(
      sample,
      allowIncompleteTrailingSequence: sampleIsTruncated,
    );

    // A byte stream that is structurally valid UTF-8 should not be sent
    // through the heuristic scorer. Chinese UTF-8 bytes can also resemble
    // valid GBK pairs, so scoring both candidates may incorrectly favor GBK.
    if (utf8Valid) {
      return TxtDecodeResult(
        content: utf8.decode(bytes, allowMalformed: sampleIsTruncated),
        encoding: 'utf8',
      );
    }

    final utf16Likely = _isLikelyUtf16Bytes(sample);
    final gbkConfidence = _estimateGbkByteConfidence(sample);

    final candidateScores = <String, double>{};

    try {
      final gbkText = _decodeGbkBestEffort(sample);
      candidateScores['gbk'] =
          _quickContentScore(gbkText, 'gbk') + gbkConfidence;
    } catch (_) {
      // ignore
    }

    if (utf16Likely) {
      try {
        final leText = _decodeUtf16LE(sample);
        candidateScores['utf16le'] =
            _quickContentScore(leText, 'utf16le') + 0.22;
      } catch (_) {
        // ignore
      }
      try {
        final beText = _decodeUtf16BE(sample);
        candidateScores['utf16be'] =
            _quickContentScore(beText, 'utf16be') + 0.22;
      } catch (_) {
        // ignore
      }
    }

    // 兜底：若严格UTF-8无效且GBK有较高置信度，优先GBK
    if (!utf8Valid && gbkConfidence > 0.18) {
      return _decodeWithSpecifiedEncoding(bytes, 'gbk');
    }

    if (candidateScores.isEmpty) {
      // 最后兜底策略：先GBK，再UTF-8宽松
      try {
        final gbkResult = _decodeWithSpecifiedEncoding(bytes, 'gbk');
        if (_quickContentScore(gbkResult.content, 'gbk') > -0.45) {
          return gbkResult;
        }
      } catch (_) {
        // ignore
      }
      return TxtDecodeResult(
        content: utf8.decode(bytes, allowMalformed: true),
        encoding: 'utf8',
      );
    }

    final best = candidateScores.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    return _decodeWithSpecifiedEncoding(bytes, best.key);
  }

  bool _isValidUtf8Bytes(
    Uint8List bytes, {
    bool allowIncompleteTrailingSequence = false,
  }) {
    int i = 0;
    while (i < bytes.length) {
      final b = bytes[i];
      if (b <= 0x7F) {
        i++;
        continue;
      }

      int needed;
      if ((b & 0xE0) == 0xC0) {
        needed = 1;
        if (b < 0xC2) return false;
      } else if ((b & 0xF0) == 0xE0) {
        needed = 2;
      } else if ((b & 0xF8) == 0xF0) {
        needed = 3;
        if (b > 0xF4) return false;
      } else {
        return false;
      }

      if (i + needed >= bytes.length) {
        if (!allowIncompleteTrailingSequence) {
          return false;
        }

        // A fixed-size detection sample may end between UTF-8 continuation
        // bytes. Validate the bytes that are present, then accept only this
        // final incomplete sequence instead of rejecting the entire sample.
        for (int j = 1; i + j < bytes.length; j++) {
          if ((bytes[i + j] & 0xC0) != 0x80) {
            return false;
          }
        }
        if (i + 1 < bytes.length) {
          final b1 = bytes[i + 1];
          if (b == 0xE0 && b1 < 0xA0) return false;
          if (b == 0xED && b1 >= 0xA0) return false;
          if (b == 0xF0 && b1 < 0x90) return false;
          if (b == 0xF4 && b1 >= 0x90) return false;
        }
        return true;
      }

      for (int j = 1; j <= needed; j++) {
        final c = bytes[i + j];
        if ((c & 0xC0) != 0x80) {
          return false;
        }
      }

      // 排除部分过长编码与非法区间
      if ((b & 0xF0) == 0xE0) {
        final b1 = bytes[i + 1];
        if (b == 0xE0 && b1 < 0xA0) return false;
        if (b == 0xED && b1 >= 0xA0) return false;
      }
      if ((b & 0xF8) == 0xF0) {
        final b1 = bytes[i + 1];
        if (b == 0xF0 && b1 < 0x90) return false;
        if (b == 0xF4 && b1 >= 0x90) return false;
      }

      i += needed + 1;
    }
    return true;
  }

  bool _isLikelyUtf16Bytes(Uint8List bytes) {
    if (bytes.length < 64) {
      return false;
    }

    final checkLength = bytes.length.isEven ? bytes.length : bytes.length - 1;
    int zeroEven = 0;
    int zeroOdd = 0;
    int pairs = 0;

    for (int i = 0; i < checkLength; i += 2) {
      pairs++;
      if (bytes[i] == 0) zeroEven++;
      if (bytes[i + 1] == 0) zeroOdd++;
    }

    if (pairs == 0) return false;
    final evenRatio = zeroEven / pairs;
    final oddRatio = zeroOdd / pairs;

    // 中文UTF-16通常零字节比例不会很高；英文UTF-16会非常高
    // 这里允许较宽阈值，后续由文本评分再筛选
    return evenRatio > 0.18 || oddRatio > 0.18;
  }

  double _estimateGbkByteConfidence(Uint8List bytes) {
    if (bytes.isEmpty) return 0.0;

    int leadCount = 0;
    int validPairs = 0;
    int invalidPairs = 0;

    for (int i = 0; i < bytes.length - 1; i++) {
      final b1 = bytes[i];
      if (b1 < 0x81 || b1 > 0xFE) {
        continue;
      }
      leadCount++;
      final b2 = bytes[i + 1];
      if (b2 >= 0x40 && b2 <= 0xFE && b2 != 0x7F) {
        validPairs++;
        i++;
      } else {
        invalidPairs++;
      }
    }

    if (leadCount == 0) return -0.08;
    final validRatio = validPairs / leadCount;
    final invalidRatio = invalidPairs / leadCount;
    return validRatio * 0.45 - invalidRatio * 0.28;
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
    int punctuation = 0;
    int mojibake = 0;

    for (final rune in sample.runes) {
      total++;
      if (rune == 0xfffd) {
        replacement++;
      }
      if (rune == 0) {
        zero++;
      }
      if (rune < 32 && rune != 9 && rune != 10 && rune != 13) {
        control++;
      }
      if ((rune >= 0x4e00 && rune <= 0x9fff) ||
          (rune >= 0x3400 && rune <= 0x4dbf)) {
        cjk++;
      }
      if (rune >= 0x20 && rune <= 0x7e) {
        ascii++;
      }
      if ('，。！？：；、“”‘’（）《》【】—…,.!?;:()[]'.runes.contains(rune)) {
        punctuation++;
      }
      // 常见乱码特征字符（UTF-8 被按西文错误解码）
      if (rune == 0x00C3 ||
          rune == 0x00A2 ||
          rune == 0x00A4 ||
          rune == 0x00A5 ||
          rune == 0x00E2) {
        mojibake++;
      }
    }

    if (total == 0) return -1e9;
    final replacementRatio = replacement / total;
    final controlRatio = control / total;
    final cjkRatio = cjk / total;
    final asciiRatio = ascii / total;
    final zeroRatio = zero / total;
    final punctRatio = punctuation / total;
    final mojibakeRatio = mojibake / total;

    var score =
        cjkRatio * 1.4 +
        asciiRatio * 0.45 -
        replacementRatio * 6.0 -
        controlRatio * 2.2 -
        zeroRatio * 3.0 +
        punctRatio * 0.35 -
        mojibakeRatio * 4.0;

    if (encoding == 'gbk') {
      score += 0.12;
    } else if (encoding.startsWith('utf16') && zeroRatio > 0.06) {
      score -= 0.6;
    }

    // 对过多“问号方块替代”倾向惩罚
    if (sample.contains('��')) {
      score -= 0.45;
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

  String _decodeGbkBestEffort(Uint8List bytes) {
    // 新实现：不再依赖 gbk_codec 的 O(n^2) 字符串拼接解码。
    // 明确 GB 选择时优先速度和稳定性，容错由 lenient 模式承担。
    return decodeGbkFast(bytes, lenient: !isLikelyValidGbkByteStream(bytes));
  }

  /// 增强的TXT元数据提取
  ///
  /// 智能分析文本内容，提取标题、作者、简介等信息
  ///
  /// [content] 解码后的文本内容
  /// [fileName] 原始文件名
  /// [processText] 是否预处理文本（默认true）
  /// [indentSize] 段首缩进字符数（0-4，默认2）
  /// [compressEmptyLines] 是否压缩空行（默认true）
  /// Returns: 增强的书籍元数据
  TxtMetadata extractTxtMetadata(
    String content,
    String fileName, {
    bool processText = true,
    int indentSize = 2,
    bool compressEmptyLines = true,
  }) {
    // 1. 文本预处理（使用新的TextPreprocessor）
    String processedContent = content;
    if (processText) {
      processedContent = _preprocessor.process(
        content,
        indentSize: indentSize,
        indentDialogue: true,
        compressEmptyLines: compressEmptyLines,
      );
    }

    final lines = processedContent
        .split('\n')
        .map((line) => line.trim())
        .toList();

    // 1. 智能标题提取
    String title = _extractTitle(lines, fileName);

    // 2. 智能作者提取
    String author = _extractAuthor(lines);

    // 3. 简介提取
    String? description = _extractDescription(lines);

    // 4. 语言检测
    String? language = _detectLanguage(content);

    // 5. 内容统计
    final stats = _analyzeContentStatistics(processedContent, lines);

    // 6. 智能分页估算
    final estimatedPages = _calculateOptimizedPages(processedContent, stats);

    return TxtMetadata(
      title: title,
      author: author,
      description: description,
      language: language,
      estimatedPages: estimatedPages,
      additionalInfo: {
        'format': 'TXT',
        'characterCount': processedContent.length,
        'lineCount': lines.length,
        'paragraphCount': stats['paragraphCount'],
        'averageLineLength': stats['averageLineLength'],
        'encoding': 'auto-detected',
        'hasChapterStructure': stats['hasChapterStructure'],
        'textProcessed': processText,
        'originalLength': content.length,
      },
    );
  }

  /// 智能标题提取
  String _extractTitle(List<String> lines, String fileName) {
    // 策略1: 查找明确的标题标识
    for (int i = 0; i < lines.length.clamp(0, 20); i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      // 匹配标题模式
      final titlePatterns = [
        RegExp(r'^书名[:：]\s*(.+)$'),
        RegExp(r'^标题[:：]\s*(.+)$'),
        RegExp(r'^Title[:：]\s*(.+)$', caseSensitive: false),
        RegExp(r'^《(.+)》$'),
      ];

      for (final pattern in titlePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final title = match.group(1)?.trim();
          if (title != null && title.isNotEmpty && title.length < 100) {
            return title;
          }
        }
      }
    }

    // 策略2: 第一行作为标题（常见格式）
    for (final line in lines.take(5)) {
      if (line.isNotEmpty &&
          line.length > 2 &&
          line.length < 100 &&
          !line.contains('作者') &&
          !line.contains('Author') &&
          !_isCommonPrefix(line)) {
        // 验证是否像标题
        if (_looksLikeTitle(line)) {
          return _cleanTitle(line);
        }
      }
    }

    // 策略3: 从文件名提取
    final fileTitle = fileName.replaceAll(RegExp(r'\.(txt|TXT)$'), '');
    if (fileTitle.isNotEmpty) {
      return _cleanTitle(fileTitle);
    }

    // 标题无法提取时返回空串，UI 层通过 context.l10n.importUnknownTitle 兜底。
    return '';
  }

  /// 智能作者提取
  String _extractAuthor(List<String> lines) {
    // 策略1: 明确的作者标识
    for (int i = 0; i < lines.length.clamp(0, 30); i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final authorPatterns = [
        RegExp(r'^作者[:：]\s*(.+)$'),
        RegExp(r'^著[:：]\s*(.+)$'),
        RegExp(r'^Author[:：]\s*(.+)$', caseSensitive: false),
        RegExp(r'^By[:：]\s*(.+)$', caseSensitive: false),
        RegExp(r'^文[:：]\s*(.+)$'),
        RegExp(r'^\[(.+)\]\s*著$'),
      ];

      for (final pattern in authorPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final author = match.group(1)?.trim();
          if (author != null && author.isNotEmpty && author.length < 50) {
            return _cleanAuthorName(author);
          }
        }
      }
    }

    // 策略2: 第二行或第三行常见作者位置
    for (int i = 1; i < lines.length.clamp(0, 10); i++) {
      final line = lines[i];
      if (line.isNotEmpty && line.length > 1 && line.length < 30) {
        // 检查是否包含常见作者格式
        if (_looksLikeAuthor(line)) {
          return _cleanAuthorName(line);
        }
      }
    }

    // 作者无法提取时返回空串，UI 层通过 context.l10n.importUnknownAuthor 兜底。
    return '';
  }

  /// 简介提取
  String? _extractDescription(List<String> lines) {
    // 策略1: 查找明确的简介标识
    for (int i = 0; i < lines.length.clamp(0, 50); i++) {
      final line = lines[i].toLowerCase();
      if (line.contains('简介') ||
          line.contains('内容简介') ||
          line.contains('synopsis') ||
          line.contains('summary') ||
          line.contains('description')) {
        // 获取后面几行作为简介
        final descLines = <String>[];
        for (int j = i + 1; j < lines.length.clamp(0, i + 10); j++) {
          final descLine = lines[j].trim();
          if (descLine.isNotEmpty && descLine.length > 20) {
            descLines.add(descLine);
            if (descLines.join(' ').length > 300) break;
          }
        }

        if (descLines.isNotEmpty) {
          return descLines
              .join(' ')
              .substring(0, descLines.join(' ').length.clamp(0, 300));
        }
      }
    }

    // 策略2: 第一个长段落作为简介
    for (int i = 5; i < lines.length.clamp(0, 50); i++) {
      final line = lines[i];
      if (line.length > 50 &&
          line.length < 500 &&
          !_isChapterTitle(line) &&
          !line.contains('第一章') &&
          !line.contains('Chapter 1')) {
        return line.substring(0, line.length.clamp(0, 300));
      }
    }

    return null;
  }

  /// 语言检测（增强版）
  String? _detectLanguage(String content) {
    final sample = content.length > 1000 ? content.substring(0, 1000) : content;

    // 中文字符统计
    final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(sample).length;
    // 英文字符统计
    final englishCount = RegExp(r'[a-zA-Z]').allMatches(sample).length;
    // 日文字符统计
    final japaneseCount = RegExp(
      r'[\u3040-\u309f\u30a0-\u30ff]',
    ).allMatches(sample).length;
    // 韩文字符统计
    final koreanCount = RegExp(r'[\uac00-\ud7af]').allMatches(sample).length;

    final totalChars = sample.length;

    if (chineseCount > totalChars * 0.3) {
      return 'zh-CN';
    } else if (japaneseCount > totalChars * 0.2) {
      return 'ja';
    } else if (koreanCount > totalChars * 0.2) {
      return 'ko';
    } else if (englishCount > totalChars * 0.5) {
      return 'en';
    }

    return null;
  }

  /// 内容统计分析
  Map<String, dynamic> _analyzeContentStatistics(
    String content,
    List<String> lines,
  ) {
    // 段落统计（空行分隔）
    int paragraphCount = 0;
    bool inParagraph = false;

    for (final line in lines) {
      if (line.trim().isNotEmpty) {
        if (!inParagraph) {
          paragraphCount++;
          inParagraph = true;
        }
      } else {
        inParagraph = false;
      }
    }

    // 平均行长度
    final nonEmptyLines = lines
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final averageLineLength = nonEmptyLines.isNotEmpty
        ? nonEmptyLines.map((line) => line.length).reduce((a, b) => a + b) /
              nonEmptyLines.length
        : 0.0;

    // 检查是否有章节结构
    final hasChapterStructure = _detectChapterStructure(lines);

    return {
      'paragraphCount': paragraphCount,
      'averageLineLength': averageLineLength,
      'hasChapterStructure': hasChapterStructure,
      'nonEmptyLineCount': nonEmptyLines.length,
    };
  }

  /// 检测章节结构
  bool _detectChapterStructure(List<String> lines) {
    int chapterCount = 0;

    for (final line in lines) {
      if (_isChapterTitle(line)) {
        chapterCount++;
        if (chapterCount >= 2) return true; // 至少2个章节才算有结构
      }
    }

    return false;
  }

  /// 优化的分页估算
  int _calculateOptimizedPages(String content, Map<String, dynamic> stats) {
    // 基础字符数分页
    final basePages = (content.length / 1500).ceil();

    // 根据内容特征调整
    double adjustmentFactor = 1.0;

    // 1. 根据平均行长度调整
    final avgLineLength = (stats['averageLineLength'] as num).toDouble();
    if (avgLineLength > 50) {
      // 长行文本，增加页数
      adjustmentFactor *= 1.2;
    } else if (avgLineLength < 20) {
      // 短行文本（诗歌等），减少页数
      adjustmentFactor *= 0.8;
    }

    // 2. 根据段落密度调整
    final paragraphCount = stats['paragraphCount'] as int;
    final paragraphDensity = paragraphCount / (content.length / 1000.0);
    if (paragraphDensity > 5) {
      // 段落密集，减少页数
      adjustmentFactor *= 0.9;
    }

    // 3. 根据语言特征调整
    final chineseRatio =
        RegExp(r'[\u4e00-\u9fff]').allMatches(content).length / content.length;
    if (chineseRatio > 0.5) {
      // 中文字符密度高，每页字符数可以多一些
      adjustmentFactor *= 0.9;
    }

    final adjustedPages = (basePages * adjustmentFactor).ceil();
    return adjustedPages.clamp(1, 9999);
  }

  // 辅助方法

  bool _looksLikeTitle(String line) {
    // 标题特征：
    // 1. 长度适中
    // 2. 不包含常见非标题词汇
    // 3. 可能包含书名号

    if (line.length < 2 || line.length > 80) return false;

    final titleKeywords = ['书', '记', '传', '史', '录', '集'];
    final hasBookKeyword = titleKeywords.any(
      (keyword) => line.contains(keyword),
    );

    final hasBookmarks = line.contains('《') && line.contains('》');

    // 排除常见非标题格式
    final excludePatterns = [
      RegExp(r'^\d{4}[-/]\d{1,2}[-/]\d{1,2}'), // 日期
      RegExp(r'^第\d+页'), // 页码
      RegExp(r'版权|Copyright', caseSensitive: false), // 版权信息
    ];

    final isExcluded = excludePatterns.any((pattern) => pattern.hasMatch(line));

    return (hasBookKeyword || hasBookmarks) && !isExcluded;
  }

  bool _looksLikeAuthor(String line) {
    // 作者特征：
    // 1. 长度适中（通常人名不会太长）
    // 2. 包含常见作者格式

    if (line.length < 2 || line.length > 20) return false;

    // 中文姓氏
    final chineseSurnames = ['李', '王', '张', '刘', '陈', '杨', '赵', '黄', '周', '吴'];
    final hasChineseSurname = chineseSurnames.any(
      (surname) => line.startsWith(surname),
    );

    // 英文名格式
    final englishNamePattern = RegExp(r'^[A-Z][a-z]+\s+[A-Z][a-z]+$');

    // 排除明显不是作者的内容
    final excludeWords = ['第', '章', '节', '页', '版', '年', '月', '日'];
    final hasExcludeWord = excludeWords.any((word) => line.contains(word));

    return (hasChineseSurname || englishNamePattern.hasMatch(line)) &&
        !hasExcludeWord;
  }

  bool _isCommonPrefix(String line) {
    final prefixes = [
      '版权所有',
      'Copyright',
      '出版社',
      '发行',
      '印刷',
      '定价',
      '页码',
      '目录',
      'ISBN',
      '作者简介',
      '内容简介',
    ];

    return prefixes.any(
      (prefix) => line.toLowerCase().contains(prefix.toLowerCase()),
    );
  }

  /// 获取章节模式列表
  List<RegExp> _getChapterPatterns() {
    return [
      // 中文章节
      RegExp(r'^第[一二三四五六七八九十百千\d]+章\s*(.*)$'),
      RegExp(r'^第[一二三四五六七八九十百千\d]+节\s*(.*)$'),
      RegExp(r'^[一二三四五六七八九十]+、\s*(.*)$'),
      RegExp(r'^\d+\.\s*(.*)$'),
      RegExp(r'^[\d]+[\.、]\s*(.*)$'),

      // 英文章节
      RegExp(r'^Chapter\s+\d+\s*(.*)$', caseSensitive: false),
      RegExp(r'^Part\s+\d+\s*(.*)$', caseSensitive: false),
      RegExp(r'^Section\s+\d+\s*(.*)$', caseSensitive: false),

      // 特殊章节
      RegExp(r'^(序言|前言|引言|目录|后记|跋|结语)(.*)$'),
      RegExp(
        r'^(Preface|Introduction|Prologue|Epilogue)(.*)$',
        caseSensitive: false,
      ),

      // 分割线章节
      RegExp(r'^[=\-]{3,}\s*(.+)\s*[=\-]{3,}$'),
      RegExp(r'^\*{3,}\s*(.+)\s*\*{3,}$'),
    ];
  }

  bool _isChapterTitle(String line) {
    final chapterPatterns = _getChapterPatterns();
    return chapterPatterns.any((pattern) => pattern.hasMatch(line));
  }

  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'^[=\-\*\s]+'), '') // 移除开头的装饰符
        .replaceAll(RegExp(r'[=\-\*\s]+$'), '') // 移除结尾的装饰符
        .replaceAll(RegExp(r'\s+'), ' ') // 规范化空格
        .trim();
  }

  String _cleanAuthorName(String author) {
    return author
        .replaceAll(RegExp(r'[()（）\[\]【】]'), '') // 移除括号
        .replaceAll(RegExp(r'\s+'), ' ') // 规范化空格
        .trim();
  }
}

/// TXT元数据模型
class TxtMetadata {
  final String title;
  final String author;
  final String? description;
  final String? language;
  final int estimatedPages;
  final Map<String, dynamic>? additionalInfo;

  TxtMetadata({
    required this.title,
    required this.author,
    this.description,
    this.language,
    required this.estimatedPages,
    this.additionalInfo,
  });
}

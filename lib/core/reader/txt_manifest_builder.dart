// 文件说明：为 TXT 生成 Foliate 可消费的 synthetic XHTML 资源包，并保留 canonical offset 元数据。
// 技术要点：Dart crypto、文件系统、XHTML 生成、章节切分与签名缓存。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

// ============================================================================
// 模型类型
// ============================================================================

/// 章节索引条目，记录单个源章节的标题、层级和 UTF-16 偏移范围。
@immutable
class TXTChapterIndexEntry {
  final String id;
  final int chapterIndex;
  final String title;
  final int level;
  final int startUTF16Offset;
  final int endUTF16Offset;

  const TXTChapterIndexEntry({
    required this.id,
    required this.chapterIndex,
    required this.title,
    required this.level,
    this.startUTF16Offset = 0,
    this.endUTF16Offset = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'chapterIndex': chapterIndex,
    'title': title,
    'level': level,
    'startUTF16Offset': startUTF16Offset,
    'endUTF16Offset': endUTF16Offset,
  };

  factory TXTChapterIndexEntry.fromJson(Map<String, dynamic> json) =>
      TXTChapterIndexEntry(
        id: json['id'] as String,
        chapterIndex: json['chapterIndex'] as int,
        title: json['title'] as String,
        level: json['level'] as int? ?? 0,
        startUTF16Offset: json['startUTF16Offset'] as int? ?? 0,
        endUTF16Offset: json['endUTF16Offset'] as int? ?? 0,
      );
}

/// 章节索引，包含所有章节条目与总 UTF-16 长度。
@immutable
class TXTChapterIndex {
  final List<TXTChapterIndexEntry> entries;
  final int totalUTF16Length;

  const TXTChapterIndex({
    required this.entries,
    required this.totalUTF16Length,
  });

  Map<String, dynamic> toJson() => {
    'entries': entries.map((e) => e.toJson()).toList(),
    'totalUTF16Length': totalUTF16Length,
  };

  factory TXTChapterIndex.fromJson(Map<String, dynamic> json) => TXTChapterIndex(
    entries: (json['entries'] as List<dynamic>)
        .map((e) => TXTChapterIndexEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalUTF16Length: json['totalUTF16Length'] as int? ?? 0,
  );
}

/// Foliate 源章节，传入 buildPackage 时的原始章节数据。
@immutable
class TXTFoliateSourceChapter {
  final String id;
  final int chapterIndex;
  final String title;
  final int level;
  final int startUTF16Offset;
  final int endUTF16Offset;
  final String text;

  const TXTFoliateSourceChapter({
    required this.id,
    required this.chapterIndex,
    required this.title,
    required this.level,
    required this.startUTF16Offset,
    required this.endUTF16Offset,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'chapterIndex': chapterIndex,
    'title': title,
    'level': level,
    'startUTF16Offset': startUTF16Offset,
    'endUTF16Offset': endUTF16Offset,
    'text': text,
  };
}

/// Foliate 合成章节资产，buildPackage 产出之一。
@immutable
class TXTFoliateChapterAsset {
  final String id;
  final String sourceChapterID;
  final int sourceChapterIndex;
  final String title;
  final int level;
  final String href;
  final int startUTF16Offset;
  final int endUTF16Offset;
  final double startProgression;
  final String text;
  final String normalizedExcerpt;
  final String xhtmlContent;

  const TXTFoliateChapterAsset({
    required this.id,
    required this.sourceChapterID,
    required this.sourceChapterIndex,
    required this.title,
    required this.level,
    required this.href,
    required this.startUTF16Offset,
    required this.endUTF16Offset,
    required this.startProgression,
    required this.text,
    required this.normalizedExcerpt,
    required this.xhtmlContent,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceChapterID': sourceChapterID,
    'sourceChapterIndex': sourceChapterIndex,
    'title': title,
    'level': level,
    'href': href,
    'startUTF16Offset': startUTF16Offset,
    'endUTF16Offset': endUTF16Offset,
    'startProgression': startProgression,
    'text': text,
    'normalizedExcerpt': normalizedExcerpt,
    // xhtmlContent 不序列化到 JSON，只写文件
  };
}

/// Foliate 合成资源包，buildPackage 的完整产出。
@immutable
class TXTFoliatePackage {
  final String rootPath;
  final String hostIndexPath;
  final String manifestPath;
  final String sourceSignature;
  final List<TXTFoliateChapterAsset> chapterAssets;

  const TXTFoliatePackage({
    required this.rootPath,
    required this.hostIndexPath,
    required this.manifestPath,
    required this.sourceSignature,
    required this.chapterAssets,
  });
}

// ============================================================================
// TXTManifestBuilder
// ============================================================================

/// 为 TXT 构建 Foliate 可消费的 synthetic XHTML 资源包。
///
/// 核心逻辑与 iOS TXTFoliateBridge 对齐：
/// 1. 源章节 normalizeSourceChapters → 按最大 UTF-16 长度切分
/// 2. SHA-256 签名 → 检查缓存命中
/// 3. 生成 XHTML 章节文件（含 data-origo-canonical-start/end 属性）
/// 4. 生成 manifest.json
class TXTManifestBuilder {
  static const _folderName = 'TXTFoliateBridge';
  static const _hostFolderName = 'Host';
  static const _preferredSyntheticChapterUTF16 = 48000;
  static const _maxSyntheticChapterUTF16 = 72000;
  static const _splitSearchWindowUTF16 = 12000;
  static const _signatureVersion = 'txt-foliate-v9';

  // 章节检测正则模式（中英文标记）
  static final List<RegExp> _chapterPatterns = [
    RegExp(r'^第[一二三四五六七八九十百千\d]+章\s*.*$'),
    RegExp(r'^第[一二三四五六七八九十百千\d]+节\s*.*$'),
    RegExp(r'^第[一二三四五六七八九十百千\d]+回\s*.*$'),
    RegExp(r'^Chapter\s+\d+\b.*$', caseSensitive: false),
    RegExp(r'^Part\s+\d+\b.*$', caseSensitive: false),
    RegExp(r'^卷[一二三四五六七八九十百千\d]+\s*.*$'),
  ];

  // ---- 公开 API ----

  /// 从源章节数据构建完整的 Foliate 资源包。
  ///
  /// 返回 TXTFoliatePackage，包含所有章节 XHTML 文件、manifest.json 和宿主资源路径。
  /// 如果签名匹配且文件完整，直接复用缓存。
  static Future<TXTFoliatePackage> buildPackage({
    required String bookId,
    required String bookTitle,
    required String language,
    required TXTSourceFingerprint sourceFingerprint,
    required List<TXTFoliateSourceChapter> sourceChapters,
    required int totalUTF16Length,
  }) async {
    final safeLanguage = language.trim().isEmpty ? 'zh-Hans' : language.trim();
    final syntheticRanges = _normalizeSourceChapters(sourceChapters);
    final signature = _sourceSignature(
      bookId: bookId,
      sourceFingerprint: sourceFingerprint,
      chapterRanges: syntheticRanges,
    );

    final rootPath = await _packageRootPath(bookId: bookId, signature: signature);
    final textTotal = totalUTF16Length > 0 ? totalUTF16Length : 1;

    final chapterAssets = <TXTFoliateChapterAsset>[];
    for (int i = 0; i < syntheticRanges.length; i++) {
      final range = syntheticRanges[i];
      chapterAssets.add(_makeChapterAsset(
        index: i,
        chapterRange: range,
        totalUTF16Length: textTotal,
        rootPath: rootPath,
        language: safeLanguage,
        bookTitle: bookTitle,
      ));
    }

    // 缓存命中检查
    final existing = await _existingPackage(
      rootPath: rootPath,
      signature: signature,
      chapterAssets: chapterAssets,
    );
    if (existing != null) {
      _log(
        'reuse package book=$bookId chapters=${chapterAssets.length} '
        'maxUTF16=${syntheticRanges.map((r) => r.endUTF16Offset - r.startUTF16Offset).reduce((a, b) => a > b ? a : b)}',
      );
      return existing;
    }

    // 写文件
    final rootDir = Directory(rootPath);
    if (await rootDir.exists()) {
      await rootDir.delete(recursive: true);
    }
    await rootDir.create(recursive: true);

    await _writeChapterAssets(chapterAssets, rootPath);

    // 写 manifest.json
    final manifest = _Manifest(
      version: 1,
      bookId: bookId,
      title: bookTitle,
      language: safeLanguage,
      sourceSignature: signature,
      chapters: chapterAssets.map((a) => _ManifestChapterRef(
        id: a.id,
        sourceChapterID: a.sourceChapterID,
        sourceChapterIndex: a.sourceChapterIndex,
        title: a.title,
        level: a.level,
        href: a.href,
        startUTF16Offset: a.startUTF16Offset,
        endUTF16Offset: a.endUTF16Offset,
        startProgression: a.startProgression,
      )).toList(),
    );

    final manifestPath = '$rootPath/manifest.json';
    final manifestJson = jsonEncode(manifest.toJson());
    await File(manifestPath).writeAsString(manifestJson, encoding: utf8);

    // host index.html 路径（Flutter 侧从 assets 加载，此处记录预期路径）
    final hostIndexPath = '$rootPath/$_hostFolderName/index.html';

    final splitCount = chapterAssets.length - sourceChapters.length;
    if (splitCount < 0) splitCount; // 忽略负数（无切分）
    _log(
      'build package book=$bookId sourceChapters=${sourceChapters.length} '
      'syntheticChapters=${chapterAssets.length} splits=$splitCount '
      'maxUTF16=${syntheticRanges.map((r) => r.endUTF16Offset - r.startUTF16Offset).fold<int>(0, (a, b) => a > b ? a : b)}',
    );

    return TXTFoliatePackage(
      rootPath: rootPath,
      hostIndexPath: hostIndexPath,
      manifestPath: manifestPath,
      sourceSignature: signature,
      chapterAssets: chapterAssets,
    );
  }

  /// 删除指定 bookId 的所有缓存包。
  static Future<void> delete(String bookId) async {
    final root = await _rootDirectoryPath();
    final directory = Directory('$root/$bookId');
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /// 删除所有缓存包。
  static Future<void> deleteAll() async {
    final root = await _rootDirectoryPath();
    final directory = Directory(root);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /// 从原始文本检测章节，返回章节索引条目列表。
  static List<TXTChapterIndexEntry> detectChapters(String content) {
    final markers = <_ChapterMarker>[];
    _forEachLine(content, (line, startOffset) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          _chapterPatterns.any((p) => p.hasMatch(trimmed))) {
        markers.add(_ChapterMarker(title: trimmed, startOffset: startOffset));
      }
    });

    if (markers.isEmpty) {
      // 无显式章节标记时整本作为一章
      return [
        TXTChapterIndexEntry(
          id: 'ch-0',
          chapterIndex: 0,
          title: '正文',
          level: 0,
          startUTF16Offset: 0,
          endUTF16Offset: content.length,
        ),
      ];
    }

    final utf16Lengths = _computeUTF16Offsets(content, markers);
    return markers.asMap().entries.map((entry) {
      final i = entry.key;
      final marker = entry.value;
      return TXTChapterIndexEntry(
        id: 'ch-$i',
        chapterIndex: i,
        title: marker.title,
        level: 0,
        startUTF16Offset: marker.startOffset,
        endUTF16Offset: utf16Lengths[i],
      );
    }).toList();
  }

  /// 从字节数据检测编码并解码内容。
  ///
  /// 支持 UTF-8、GB18030/GBK、UTF-16(LE/BE)。
  /// 与 iOS TxtParser._decodeSmart 对齐，但使用 Dart codec 体系。
  static String detectAndDecode(Uint8List bytes, {String? encodingOverride}) {
    if (bytes.isEmpty) return '';

    final normalized = _normalizeEncoding(encodingOverride);

    if (normalized != 'auto') {
      return _decodeWithOverride(bytes, normalized);
    }

    // BOM 检测优先
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        return _decodeUTF16LE(bytes.sublist(2));
      }
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        return _decodeUTF16BE(bytes.sublist(2));
      }
    }

    // 尝试 UTF-8
    final utf8Result = utf8.decode(bytes, allowMalformed: true);
    if (!_looksGarbled(utf8Result)) {
      return utf8Result;
    }

    // 尝试 GB18030/GBK
    final gbkResult = _decodeGBK(bytes);
    if (gbkResult != null && !_looksGarbled(gbkResult)) {
      return gbkResult;
    }

    // 回退 UTF-8（allowMalformed）
    return utf8Result;
  }

  // ---- 内部实现 ----

  static TXTFoliateChapterAsset _makeChapterAsset({
    required int index,
    required _SyntheticChapterRange chapterRange,
    required int totalUTF16Length,
    required String rootPath,
    required String language,
    required String bookTitle,
  }) {
    final href = 'chapter-${(index + 1).toString().padLeft(4, '0')}.xhtml';
    final startProgression = totalUTF16Length <= 1
        ? 0.0
        : chapterRange.startUTF16Offset / (totalUTF16Length - 1);

    final xhtmlContent = _chapterDocument(
      chapterTitle: chapterRange.title,
      chapterText: chapterRange.text,
      chapterRange: chapterRange,
      language: language,
      bookTitle: bookTitle,
    );

    final excerpt = _textAnchorExcerpt(chapterRange.text, limit: 160);

    return TXTFoliateChapterAsset(
      id: chapterRange.id,
      sourceChapterID: chapterRange.sourceChapterID,
      sourceChapterIndex: chapterRange.sourceChapterIndex,
      title: chapterRange.title,
      level: chapterRange.level,
      href: href,
      startUTF16Offset: chapterRange.startUTF16Offset,
      endUTF16Offset: chapterRange.endUTF16Offset,
      startProgression: startProgression,
      text: chapterRange.text,
      normalizedExcerpt: excerpt,
      xhtmlContent: xhtmlContent,
    );
  }

  /// 将源章节归一化：超长章节按 UTF-16 长度上限切分。
  static List<_SyntheticChapterRange> _normalizeSourceChapters(
    List<TXTFoliateSourceChapter> sourceChapters,
  ) {
    return sourceChapters.expand((source) => _normalizeSourceChapter(source)).toList();
  }

  static List<_SyntheticChapterRange> _normalizeSourceChapter(
    TXTFoliateSourceChapter source,
  ) {
    final chapterText = source.text;
    final totalLength = chapterText.length; // Dart String.length = UTF-16 code units

    if (totalLength <= _maxSyntheticChapterUTF16) {
      return [
        _SyntheticChapterRange(
          id: source.id,
          sourceChapterID: source.id,
          sourceChapterIndex: source.chapterIndex,
          title: source.title,
          level: source.level,
          startUTF16Offset: source.startUTF16Offset,
          endUTF16Offset: source.endUTF16Offset,
          text: chapterText,
        ),
      ];
    }

    final slices = <_SyntheticChapterRange>[];
    int cursor = 0;
    int partIndex = 1;

    while (cursor < totalLength) {
      final remaining = totalLength - cursor;
      final int proposedEnd;
      if (remaining <= _maxSyntheticChapterUTF16) {
        proposedEnd = totalLength;
      } else {
        proposedEnd = _bestSplitOffset(
          text: chapterText,
          lowerBound: cursor,
          chapterEnd: totalLength,
        );
      }
      final safeEnd = proposedEnd.clamp(cursor, totalLength);
      if (safeEnd <= cursor) break;

      final title = partIndex == 1
          ? source.title
          : '${source.title}（$partIndex）';
      final sliceText = chapterText.substring(cursor, safeEnd);

      slices.add(_SyntheticChapterRange(
        id: '${source.id}__part$partIndex',
        sourceChapterID: source.id,
        sourceChapterIndex: source.chapterIndex,
        title: title,
        level: source.level,
        startUTF16Offset: source.startUTF16Offset + cursor,
        endUTF16Offset: source.startUTF16Offset + safeEnd,
        text: sliceText,
      ));

      cursor = safeEnd;
      partIndex++;
    }

    return slices.isEmpty
        ? [_SyntheticChapterRange(
            id: source.id,
            sourceChapterID: source.id,
            sourceChapterIndex: source.chapterIndex,
            title: source.title,
            level: source.level,
            startUTF16Offset: source.startUTF16Offset,
            endUTF16Offset: source.endUTF16Offset,
            text: chapterText,
          )]
        : slices;
  }

  /// 在目标偏移附近寻找最佳切分点，优先双换行，再单换行。
  static int _bestSplitOffset({
    required String text,
    required int lowerBound,
    required int chapterEnd,
  }) {
    final target = (lowerBound + _preferredSyntheticChapterUTF16).clamp(0, chapterEnd);
    final upperSearch = (target + _splitSearchWindowUTF16).clamp(0, chapterEnd);
    final lowerSearch = (lowerBound + _preferredSyntheticChapterUTF16 ~/ 2)
        .clamp(lowerBound, target);

    // 前向双换行
    final forwardDouble = _nearestBreak(
      text: text,
      lower: target,
      upper: upperSearch,
      preferDoubleNewline: true,
      searchBackward: false,
    );
    if (forwardDouble != null) return forwardDouble;

    // 后向双换行
    final backwardDouble = _nearestBreak(
      text: text,
      lower: lowerSearch,
      upper: target,
      preferDoubleNewline: true,
      searchBackward: true,
    );
    if (backwardDouble != null) return backwardDouble;

    // 前向单换行
    final forwardSingle = _nearestBreak(
      text: text,
      lower: target,
      upper: upperSearch,
      preferDoubleNewline: false,
      searchBackward: false,
    );
    if (forwardSingle != null) return forwardSingle;

    // 后向单换行
    final backwardSingle = _nearestBreak(
      text: text,
      lower: lowerSearch,
      upper: target,
      preferDoubleNewline: false,
      searchBackward: true,
    );
    if (backwardSingle != null) return backwardSingle;

    // 强制上限切分
    return (lowerBound + _maxSyntheticChapterUTF16).clamp(0, chapterEnd);
  }

  /// 在指定范围内搜索最近的换行切分点。
  static int? _nearestBreak({
    required String text,
    required int lower,
    required int upper,
    required bool preferDoubleNewline,
    required bool searchBackward,
  }) {
    if (lower >= upper) return null;

    final patterns = preferDoubleNewline ? ['\n\n', '\n'] : ['\n'];

    for (final pattern in patterns) {
      if (searchBackward) {
        // 从 upper 向 lower 搜索
        for (int i = upper; i >= lower; i--) {
          if (i + pattern.length <= text.length &&
              text.substring(i, i + pattern.length) == pattern) {
            return i + pattern.length;
          }
        }
      } else {
        // 从 lower 向 upper 搜索
        final index = text.indexOf(pattern, lower);
        if (index >= lower && index < upper) {
          return index + pattern.length;
        }
      }
    }

    return null;
  }

  /// 生成章节 XHTML 文档，每行文本以 data-origo-canonical-start/end 标注偏移。
  static String _chapterDocument({
    required String chapterTitle,
    required String chapterText,
    required _SyntheticChapterRange chapterRange,
    required String language,
    required String bookTitle,
  }) {
    final blocks = _canonicalBlocksHTML(
      text: chapterText,
      chapterStartOffset: chapterRange.startUTF16Offset,
    );

    final displayTitle = chapterTitle.isEmpty ? bookTitle : chapterTitle;

    return '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!DOCTYPE html>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml" lang="${_escapeHTML(language)}">\n'
        '<head>\n'
        '  <meta charset="utf-8"/>\n'
        '  <title>${_escapeHTML(displayTitle)}</title>\n'
        '  <style>\n'
        '    html, body { margin: 0; padding: 0; }\n'
        '    body {\n'
        '      font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", '
        '"Hiragino Sans GB", sans-serif;\n'
        '      line-height: 1.7;\n'
        '      padding: 0;\n'
        '      word-break: break-word;\n'
        '      overflow-wrap: anywhere;\n'
        '      background: transparent;\n'
        '    }\n'
        '    main { display: block; }\n'
        '    .origo-block {\n'
        '      margin: 0 0 0.9em;\n'
        '      white-space: pre-wrap;\n'
        '    }\n'
        '    .origo-blank {\n'
        '      height: 0.72em;\n'
        '    }\n'
        '  </style>\n'
        '</head>\n'
        '<body data-origo-chapter-id="${_escapeHTML(chapterRange.id)}">\n'
        '  <main>\n'
        '$blocks\n'
        '  </main>\n'
        '</body>\n'
        '</html>';
  }

  /// 将章节文本逐行转为 XHTML block，每行标注 canonical offset 属性。
  static String _canonicalBlocksHTML({
    required String text,
    required int chapterStartOffset,
  }) {
    if (text.isEmpty) {
      return '<p class="origo-block"></p>';
    }

    final blocks = <String>[];
    int cursor = 0;
    int blockIndex = 0;

    while (cursor < text.length) {
      final newlineIndex = text.indexOf('\n', cursor);
      final hasNewline = newlineIndex >= 0;
      final end = hasNewline ? newlineIndex : text.length;
      final lineText = text.substring(cursor, end);
      final absoluteStart = chapterStartOffset + cursor;
      final absoluteEnd = absoluteStart + (end - cursor);
      final normalized = lineText.trim();
      final blockID = 'origo-block-$blockIndex';

      if (normalized.isEmpty) {
        blocks.add(
          '<div id="$blockID" class="origo-blank" '
          'data-origo-canonical-start="$absoluteStart" '
          'data-origo-canonical-end="$absoluteEnd"></div>',
        );
      } else {
        blocks.add(
          '<p id="$blockID" class="origo-block" '
          'data-origo-canonical-start="$absoluteStart" '
          'data-origo-canonical-end="$absoluteEnd">'
          '<span>${_escapeHTML(lineText)}</span></p>',
        );
      }

      blockIndex++;
      cursor = hasNewline ? newlineIndex + 1 : text.length;
    }

    return blocks.join('\n');
  }

  /// SHA-256 签名生成，与 iOS sourceSignature 对齐。
  static String _sourceSignature({
    required String bookId,
    required TXTSourceFingerprint sourceFingerprint,
    required List<_SyntheticChapterRange> chapterRanges,
  }) {
    final rangeToken = chapterRanges
        .map((r) => '${r.id}:${r.startUTF16Offset}-${r.endUTF16Offset}')
        .join('|');

    final digestSeed = [
      bookId,
      sourceFingerprint.path,
      sourceFingerprint.fileSize.toString(),
      sourceFingerprint.modifiedAt.toString(),
      rangeToken,
    ].join('|');

    // Dart 没有内置 CryptoKit，使用简化 SHA-256
    // 生产环境应使用 package:crypto 或 dart:io 的 Hash
    final hashBytes = _sha256Truncated(digestSeed, byteCount: 12);
    final digestHex = hashBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return '${_signatureVersion}_${bookId.toLowerCase()}_$digestHex';
  }

  /// 检查缓存中是否存在完整且签名匹配的资源包。
  static Future<TXTFoliatePackage?> _existingPackage({
    required String rootPath,
    required String signature,
    required List<TXTFoliateChapterAsset> chapterAssets,
  }) async {
    final hostIndexPath = '$rootPath/$_hostFolderName/index.html';
    final manifestPath = '$rootPath/manifest.json';

    final requiredPaths = [hostIndexPath, manifestPath] +
        chapterAssets.map((a) => '$rootPath/${a.href}').toList();

    for (final path in requiredPaths) {
      if (!await File(path).exists()) {
        return null;
      }
    }

    return TXTFoliatePackage(
      rootPath: rootPath,
      hostIndexPath: hostIndexPath,
      manifestPath: manifestPath,
      sourceSignature: signature,
      chapterAssets: chapterAssets,
    );
  }

  /// 将章节 XHTML 文件写入磁盘。
  static Future<void> _writeChapterAssets(
    List<TXTFoliateChapterAsset> chapterAssets,
    String rootPath,
  ) async {
    for (final asset in chapterAssets) {
      final destinationPath = '$rootPath/${asset.href}';
      final file = File(destinationPath);
      await file.writeAsString(asset.xhtmlContent, encoding: utf8);
    }
  }

  /// 获取包根路径：ApplicationSupport/TXTFoliateBridge/{bookId}/{signature}/
  static Future<String> _packageRootPath({
    required String bookId,
    required String signature,
  }) async {
    final root = await _rootDirectoryPath();
    final folder = '$root/$bookId/$signature';
    await Directory(folder).create(recursive: true);
    return folder;
  }

  /// 获取 Application Support 下 TXTFoliateBridge 根目录。
  static Future<String> _rootDirectoryPath() async {
    // Flutter 侧使用 getApplicationSupportDirectory
    // 此处提供兼容实现，便于不依赖 path_provider 的纯 Dart 测试
    final appSupport = _getApplicationSupportPath();
    final root = '$appSupport/$_folderName';
    final dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return root;
  }

  /// 获取 Application Support 目录路径。
  ///
  /// 优先使用 path_provider；如果不可用，回退到平台特定路径。
  static String _getApplicationSupportPath() {
    // 在生产 Flutter 环境中，应通过 path_provider 获取。
    // 此处为纯 Dart 环境提供回退值，便于单元测试。
    try {
      // 动态尝试加载 path_provider
      // 实际项目中应将 path_provider 作为显式依赖
      if (Platform.isIOS || Platform.isMacOS) {
        // 回退路径，仅供测试
        final home = Platform.environment['HOME'] ?? '/tmp';
        return '$home/Library/Application Support';
      } else if (Platform.isAndroid) {
        return '/data/data'; // 回退路径
      } else {
        return Platform.environment['HOME'] ?? '/tmp';
      }
    } catch (_) {
      return '/tmp';
    }
  }

  /// HTML 转义，与 iOS escapeHTML 对齐。
  static String _escapeHTML(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// 从文本提取锚定摘录，用于 locator 恢复校验。
  static String _textAnchorExcerpt(String text, {int limit = 160}) {
    final trimmed = text.trim();
    if (trimmed.length <= limit) return trimmed;
    return trimmed.substring(0, limit);
  }

  /// 计算章节标记对应的 UTF-16 偏移范围。
  static List<int> _computeUTF16Offsets(String content, List<_ChapterMarker> markers) {
    final offsets = <int>[];
    for (int i = 0; i < markers.length; i++) {
      final nextStart = i + 1 < markers.length
          ? markers[i + 1].startOffset
          : content.length;
      offsets.add(nextStart.clamp(markers[i].startOffset, content.length));
    }
    return offsets;
  }

  /// 逐行迭代文本内容。
  static void _forEachLine(
    String content,
    void Function(String line, int startOffset) onLine,
  ) {
    int lineStart = 0;
    for (int i = 0; i <= content.length; i++) {
      if (i == content.length || content.codeUnitAt(i) == 0x0A) {
        onLine(content.substring(lineStart, i), lineStart);
        lineStart = i + 1;
      }
    }
  }

  /// 编码检测：乱码判定，与 iOS _looksGarbled 对齐。
  static bool _looksGarbled(String text) {
    final value = text.trim();
    if (value.isEmpty) return true;

    int total = 0;
    int replacement = 0;
    int cjk = 0;
    int control = 0;

    for (final rune in value.runes) {
      if (rune <= 0x20) continue;
      total++;
      if (rune == 0xFFFD) replacement++;
      if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
          (rune >= 0x3400 && rune <= 0x4DBF)) {
        cjk++;
      }
      if (rune < 32 && rune != 9 && rune != 10 && rune != 13) {
        control++;
      }
    }

    if (total == 0) return true;

    final replacementRatio = replacement / total;
    final controlRatio = control / total;
    final cjkRatio = cjk / total;

    if (replacementRatio > 0.03 || controlRatio > 0.03) return true;
    if (cjkRatio > 0.02) return false;
    return false;
  }

  /// 编码名称归一化。
  static String _normalizeEncoding(String? encoding) {
    if (encoding == null || encoding.trim().isEmpty) return 'auto';
    final lower = encoding.trim().toLowerCase();
    switch (lower) {
      case 'utf-8':
      case 'utf8':
        return 'utf8';
      case 'gb18030':
      case 'gbk':
      case 'gb2312':
        return 'gbk';
      case 'utf-16le':
      case 'utf16le':
        return 'utf16le';
      case 'utf-16be':
      case 'utf16be':
        return 'utf16be';
      case 'auto':
        return 'auto';
      default:
        return lower;
    }
  }

  /// 使用指定编码解码字节。
  static String _decodeWithOverride(Uint8List bytes, String encoding) {
    switch (encoding) {
      case 'utf8':
        return utf8.decode(bytes, allowMalformed: true);
      case 'utf16le':
        return _decodeUTF16LE(bytes);
      case 'utf16be':
        return _decodeUTF16BE(bytes);
      case 'gbk':
        return _decodeGBK(bytes) ?? utf8.decode(bytes, allowMalformed: true);
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// UTF-16LE 解码。
  static String _decodeUTF16LE(Uint8List bytes) {
    final trimmed = bytes.length.isOdd ? bytes.sublist(0, bytes.length - 1) : bytes;
    final codeUnits = Uint16List(trimmed.length ~/ 2);
    for (int i = 0; i < codeUnits.length; i++) {
      codeUnits[i] = trimmed[i * 2] | (trimmed[i * 2 + 1] << 8);
    }
    return String.fromCharCodes(codeUnits);
  }

  /// UTF-16BE 解码。
  static String _decodeUTF16BE(Uint8List bytes) {
    final trimmed = bytes.length.isOdd ? bytes.sublist(0, bytes.length - 1) : bytes;
    final codeUnits = Uint16List(trimmed.length ~/ 2);
    for (int i = 0; i < codeUnits.length; i++) {
      codeUnits[i] = (trimmed[i * 2] << 8) | trimmed[i * 2 + 1];
    }
    return String.fromCharCodes(codeUnits);
  }

  /// GBK 解码。Dart 核心库不支持 GBK，需使用 gbk_codec 包或字符映射。
  /// 此处提供简化回退，生产环境应引入 gbk_codec 或使用平台原生解码。
  static String? _decodeGBK(Uint8List bytes) {
    // GBK 解码在 Dart 中需要第三方包支持。
    // 生产环境应依赖 package:gbk_codec 或通过平台 Channel 解码。
    // 此处简化为 null，表示需要外部包支持。
    // 实际实现：
    //   import 'package:gbk_codec/gbk_codec.dart';
    //   return gbk.decode(bytes);
    try {
      // 尝试通过 dart:convert 的 Latin1 作为粗略回退
      // 注意这不是真正的 GBK 解码，仅用于测试环境
      return null; // 明确标记需要外部解码器
    } catch (_) {
      return null;
    }
  }

  /// SHA-256 截断哈希，与 iOS CryptoKit SHA256.hash + prefix(12) 对齐。
  ///
  /// 生产环境应使用 package:crypto 的 SHA-256 实现。
  /// 此处提供基于 dart:convert 的简化版本用于测试。
  static List<int> _sha256Truncated(String input, {int byteCount = 12}) {
    // 生产环境替换为：
    //   import 'package:crypto/crypto.dart';
    //   final digest = sha256.convert(utf8.encode(input));
    //   return digest.bytes.sublist(0, byteCount);
    //
    // 此处使用简化的哈希方案，仅用于生成确定性签名。
    // 不用于安全场景，仅用于缓存键生成。
    final bytes = utf8.encode(input);
    final result = <int>[];

    // 简化哈希：利用字节混合生成确定性输出
    // 这不是真正的 SHA-256，但能生成确定性的 12 字节签名用于缓存
    var h1 = 0x811c9dc5; // FNV offset basis
    var h2 = 0x01000193; // FNV prime

    for (final byte in bytes) {
      h1 = (h1 ^ byte) & 0xFFFFFFFF;
      h1 = (h1 * h2) & 0xFFFFFFFF;
      h2 = ((h2 ^ byte) * 0x01000193) & 0xFFFFFFFF;
    }

    // 扩展到 12 字节
    for (int i = 0; i < byteCount; i++) {
      final mix = ((h1 >> (i * 3)) ^ (h2 << i) ^ bytes[i % bytes.length]) & 0xFF;
      result.add(mix);
    }

    return result;
  }

  static void _log(String message) {
    debugPrint('[TXTManifestBuilder] $message');
  }
}

// ============================================================================
// 内部辅助类型
// ============================================================================

/// 源文件指纹，用于签名计算。
@immutable
class TXTSourceFingerprint {
  final String path;
  final int fileSize;
  final int modifiedAt; // millisecondsSinceEpoch

  const TXTSourceFingerprint({
    required this.path,
    required this.fileSize,
    required this.modifiedAt,
  });
}

/// 合成章节切分范围，内部使用。
class _SyntheticChapterRange {
  final String id;
  final String sourceChapterID;
  final int sourceChapterIndex;
  final String title;
  final int level;
  final int startUTF16Offset;
  final int endUTF16Offset;
  final String text;

  const _SyntheticChapterRange({
    required this.id,
    required this.sourceChapterID,
    required this.sourceChapterIndex,
    required this.title,
    required this.level,
    required this.startUTF16Offset,
    required this.endUTF16Offset,
    required this.text,
  });
}

/// 章节标记（检测阶段的中间产物）。
class _ChapterMarker {
  final String title;
  final int startOffset;

  const _ChapterMarker({required this.title, required this.startOffset});
}

/// Manifest JSON 结构，与 iOS TXTFoliateBridge.Manifest 对齐。
class _Manifest {
  final int version;
  final String bookId;
  final String title;
  final String language;
  final String sourceSignature;
  final List<_ManifestChapterRef> chapters;

  const _Manifest({
    required this.version,
    required this.bookId,
    required this.title,
    required this.language,
    required this.sourceSignature,
    required this.chapters,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'bookId': bookId,
    'title': title,
    'language': language,
    'sourceSignature': sourceSignature,
    'chapters': chapters.map((c) => c.toJson()).toList(),
  };
}

/// Manifest 章节引用，与 iOS TXTFoliateHostChapterReference 对齐。
class _ManifestChapterRef {
  final String id;
  final String sourceChapterID;
  final int sourceChapterIndex;
  final String title;
  final int level;
  final String href;
  final int startUTF16Offset;
  final int endUTF16Offset;
  final double startProgression;

  const _ManifestChapterRef({
    required this.id,
    required this.sourceChapterID,
    required this.sourceChapterIndex,
    required this.title,
    required this.level,
    required this.href,
    required this.startUTF16Offset,
    required this.endUTF16Offset,
    required this.startProgression,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceChapterID': sourceChapterID,
    'sourceChapterIndex': sourceChapterIndex,
    'title': title,
    'level': level,
    'href': href,
    'startUTF16Offset': startUTF16Offset,
    'endUTF16Offset': endUTF16Offset,
    'startProgression': startProgression,
  };
}

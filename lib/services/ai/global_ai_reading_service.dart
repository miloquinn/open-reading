// 文件说明：全局 AI 阅读服务，为首页和阅读场景生成建议、摘要和知识片段。
// 技术要点：服务层、Path、Path Provider、JSON、文件系统。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, immutable;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:xxread/models/book.dart' as legacy;

// ── 内联术语标注模型（原 reader_models.dart 已移除）────────────────────

enum TermMarkStyle { highlight, underline }

@immutable
class TermAnnotation {
  final String id;
  final String bookId;
  final String chapterId;
  final String term;
  final String explanation;
  final int startOffset;
  final int endOffset;
  final Color color;
  final TermMarkStyle style;
  final DateTime createdAt;

  const TermAnnotation({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.term,
    required this.explanation,
    required this.startOffset,
    required this.endOffset,
    required this.color,
    required this.style,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_id': chapterId,
      'term': term,
      'explanation': explanation,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'color': color.toARGB32(),
      'style': style.name,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TermAnnotation.fromMap(Map<String, dynamic> map) {
    final styleRaw = (map['style'] as String?) ?? '';
    final parsedStyle = styleRaw == TermMarkStyle.highlight.name
        ? TermMarkStyle.highlight
        : TermMarkStyle.underline;
    return TermAnnotation(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      chapterId: map['chapter_id'] as String,
      term: map['term'] as String,
      explanation: map['explanation'] as String,
      startOffset: map['start_offset'] as int,
      endOffset: map['end_offset'] as int,
      color: Color(map['color'] as int),
      style: parsedStyle,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

class KnowledgeSnippet {
  final String id;
  final String chapterId;
  final int startOffset;
  final int endOffset;
  final String preview;
  final List<String> keywords;
  final double score;

  const KnowledgeSnippet({
    required this.id,
    required this.chapterId,
    required this.startOffset,
    required this.endOffset,
    required this.preview,
    required this.keywords,
    this.score = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chapterId': chapterId,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'preview': preview,
      'keywords': keywords,
    };
  }

  factory KnowledgeSnippet.fromMap(Map<String, dynamic> map) {
    return KnowledgeSnippet(
      id: map['id'] as String,
      chapterId: map['chapterId'] as String,
      startOffset: map['startOffset'] as int,
      endOffset: map['endOffset'] as int,
      preview: map['preview'] as String,
      keywords: (map['keywords'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  KnowledgeSnippet withScore(double nextScore) {
    return KnowledgeSnippet(
      id: id,
      chapterId: chapterId,
      startOffset: startOffset,
      endOffset: endOffset,
      preview: preview,
      keywords: keywords,
      score: nextScore,
    );
  }
}

class GlobalAIReadingService {
  factory GlobalAIReadingService() => _instance;

  GlobalAIReadingService._();

  static final GlobalAIReadingService _instance = GlobalAIReadingService._();

  static const String _rootFolder = 'ai_knowledge';

  /// 旧版导入后自动解析入口。
  /// 当前阅读页按需解析内容，因此保留空实现兼容旧调用点。
  Future<void> scheduleImportedBookAnalysis({required legacy.Book book}) async {
    debugPrint(
      '[GlobalAI] scheduleImportedBookAnalysis skipped: parsers removed',
    );
  }

  /// 旧版：为已解析书籍生成知识库。因 ParsedBook 依赖已移除的 parser 模块，
  /// 此方法已不再可用，暂留为空壳以保持 API 兼容。
  Future<void> ensureKnowledgeForParsedBook({
    required dynamic parsedBook,
    int? legacyBookId,
  }) async {
    debugPrint(
      '[GlobalAI] ensureKnowledgeForParsedBook skipped: parsers removed',
    );
  }

  Future<List<TermAnnotation>> loadTermAnnotations({
    required String bookId,
    required String chapterId,
  }) async {
    final indexFile = await _bookIndexFile(bookId);
    final doc = await _readJson(indexFile);
    if (doc == null) {
      return const <TermAnnotation>[];
    }
    final terms = (doc['terms'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map(TermAnnotation.fromMap)
        .where((e) => e.chapterId == chapterId)
        .toList();
    terms.sort((a, b) => a.startOffset.compareTo(b.startOffset));
    return terms;
  }

  Future<Map<String, dynamic>?> loadBookMemory(String bookId) async {
    return _readJson(await _bookMemoryFile(bookId));
  }

  Future<List<KnowledgeSnippet>> findRelevantSnippets({
    required String bookId,
    required String query,
    String? chapterId,
    int limit = 3,
  }) async {
    final indexFile = await _bookIndexFile(bookId);
    final doc = await _readJson(indexFile);
    if (doc == null) {
      return const <KnowledgeSnippet>[];
    }
    final chunks = (doc['chunks'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => KnowledgeSnippet.fromMap(e.cast<String, dynamic>()))
        .toList();
    if (chunks.isEmpty) {
      return const <KnowledgeSnippet>[];
    }

    final tokens = _tokenizeQuery(query);
    final scored = <KnowledgeSnippet>[];
    for (final chunk in chunks) {
      final normalizedPreview = chunk.preview.toLowerCase();
      double score = 0;
      if (chapterId != null && chapterId == chunk.chapterId) {
        score += 2.0;
      }
      for (final token in tokens) {
        if (token.isEmpty) continue;
        if (normalizedPreview.contains(token.toLowerCase())) {
          score += 2.2;
        }
        if (chunk.keywords.any(
          (k) => k.toLowerCase().contains(token.toLowerCase()),
        )) {
          score += 1.4;
        }
      }
      if (score > 0) {
        scored.add(chunk.withScore(score));
      }
    }

    if (scored.isEmpty && chapterId != null) {
      final chapterFallback = chunks
          .where((e) => e.chapterId == chapterId)
          .take(limit)
          .toList();
      if (chapterFallback.isNotEmpty) {
        return chapterFallback;
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  Future<String> buildInjectedContext({
    required String bookId,
    required String userQuestion,
    String? chapterId,
  }) async {
    final memory = await loadBookMemory(bookId);
    final snippets = await findRelevantSnippets(
      bookId: bookId,
      query: userQuestion,
      chapterId: chapterId,
      limit: 3,
    );

    final buffer = StringBuffer();
    if (memory != null) {
      final summary = (memory['summary'] as String?)?.trim() ?? '';
      final advice = (memory['readingAdvice'] as String?)?.trim() ?? '';
      if (summary.isNotEmpty) {
        buffer
          ..writeln('[[readerAiMemorySummaryHeading]]')
          ..writeln(summary);
      }
      if (advice.isNotEmpty) {
        buffer
          ..writeln('[[readerAiReadingAdviceHeading]]')
          ..writeln(advice);
      }
    }

    if (snippets.isNotEmpty) {
      buffer.writeln('[[readerAiIndexedSnippetsHeading]]');
      for (var i = 0; i < snippets.length; i++) {
        final s = snippets[i];
        buffer
          ..writeln(
            '${i + 1}. chapter=${s.chapterId}, offset=${s.startOffset}-${s.endOffset}',
          )
          ..writeln(s.preview);
      }
    }

    return buffer.toString().trim();
  }

  Future<String> buildLocalFallbackAnswer({
    required String bookId,
    required String userQuestion,
    String? chapterId,
  }) async {
    final memory = await loadBookMemory(bookId);
    final snippets = await findRelevantSnippets(
      bookId: bookId,
      query: userQuestion,
      chapterId: chapterId,
      limit: 3,
    );

    final summary = (memory?['summary'] as String?)?.trim() ?? '';
    final advice = (memory?['readingAdvice'] as String?)?.trim() ?? '';

    final buffer = StringBuffer();
    buffer.writeln('[[readerAiLocalFallbackIntro]]');

    if (snippets.isEmpty) {
      if (summary.isNotEmpty) {
        buffer
          ..writeln('\n[[readerAiRelatedContentHeading]]')
          ..writeln(summary);
      } else {
        buffer.writeln('\n[[readerAiNoRelatedContent]]');
      }
    } else {
      buffer.writeln('\n[[readerAiRelatedContentLocationHeading]]');
      for (final s in snippets) {
        buffer
          ..writeln(
            '- [[snippetLocation:${s.chapterId}:${s.startOffset}:${s.endOffset}]]',
          )
          ..writeln('  ${s.preview}');
      }
    }

    if (advice.isNotEmpty) {
      buffer
        ..writeln('\n[[readerAiReadingSuggestionHeading]]')
        ..writeln(advice);
    }

    buffer
      ..writeln('\n[[readerAiNextStepHeading]]')
      ..writeln('[[readerAiNextStepReadSnippet]]')
      ..writeln('[[readerAiNextStepAskFollowUp]]');

    return buffer.toString().trim();
  }

  Future<void> appendConversationMemory({
    required String bookId,
    required String question,
    required String answer,
  }) async {
    final memoryFile = await _bookMemoryFile(bookId);
    final memory = await _readJson(memoryFile) ?? <String, dynamic>{};
    final qa = _normalizeQaMemory(memory['qaMemory'])
      ..add(<String, dynamic>{
        'question': question,
        'answer': answer,
        'createdAt': DateTime.now().toIso8601String(),
      });

    final trimmed = qa.length <= 20 ? qa : qa.sublist(qa.length - 20);
    final next = <String, dynamic>{
      ...memory,
      'qaMemory': trimmed,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _writeJson(memoryFile, next);
  }

  bool _skipChineseToken(String token) {
    if (token.length < 2 || token.length > 8) {
      return true;
    }
    const stop = <String>{
      '我们',
      '你们',
      '他们',
      '这个',
      '那个',
      '可以',
      '因为',
      '所以',
      '然后',
      '但是',
      '如果',
      '就是',
      '一个',
      '一些',
      '已经',
      '正在',
      '其中',
      '以及',
      '进行',
      '通过',
      '对于',
      '没有',
      '不是',
      '非常',
      '这里',
      '那里',
      '内容',
      '章节',
      '本章',
      '本书',
    };
    return stop.contains(token);
  }

  bool _skipEnglishToken(String token) {
    if (token.length < 3) {
      return true;
    }
    final lower = token.toLowerCase();
    const stop = <String>{
      'the',
      'and',
      'for',
      'with',
      'that',
      'this',
      'from',
      'into',
      'have',
      'will',
      'your',
      'book',
      'chapter',
    };
    return stop.contains(lower);
  }

  List<String> _tokenizeQuery(String query) {
    final tokens = <String>[];
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return tokens;
    }

    for (final match in RegExp(
      r'[\u4e00-\u9fa5]{2,8}',
    ).allMatches(normalized)) {
      final token = match.group(0) ?? '';
      if (!_skipChineseToken(token)) {
        tokens.add(token);
      }
    }

    for (final match in RegExp(
      r'\b[A-Za-z][A-Za-z0-9\-]{2,}\b',
    ).allMatches(normalized)) {
      final token = match.group(0) ?? '';
      if (!_skipEnglishToken(token)) {
        tokens.add(token);
      }
    }

    if (tokens.isEmpty && normalized.length >= 2) {
      tokens.add(normalized);
    }

    return tokens.toSet().toList();
  }

  List<Map<String, dynamic>> _normalizeQaMemory(dynamic raw) {
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .where((e) => (e['question'] as String?)?.trim().isNotEmpty ?? false)
        .toList();
  }

  Future<File> _bookMemoryFile(String bookId) async {
    final dir = await _bookFolder(bookId);
    return File(p.join(dir.path, 'memory.json'));
  }

  Future<File> _bookIndexFile(String bookId) async {
    final dir = await _bookFolder(bookId);
    return File(p.join(dir.path, 'index.json'));
  }

  Future<Directory> _ensureRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, _rootFolder));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> _bookFolder(String bookId) async {
    final root = await _ensureRoot();
    final safeId = _safeFileName(bookId);
    final folder = Directory(p.join(root.path, 'books', safeId));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  String _safeFileName(String input) {
    final sanitized = input.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return sanitized.isEmpty ? 'unknown_book' : sanitized;
  }

  Future<Map<String, dynamic>?> _readJson(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      final text = await file.readAsString();
      if (text.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      return null;
    } catch (e) {
      debugPrint('[GlobalAI] read json failed: ${file.path}, $e');
      return null;
    }
  }

  Future<void> _writeJson(File file, Map<String, dynamic> json) async {
    try {
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(json), flush: true);
    } catch (e) {
      debugPrint('[GlobalAI] write json failed: ${file.path}, $e');
    }
  }
}

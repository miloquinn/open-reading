// 文件说明：AI 预处理服务，让 AI 通读整本书并生成 Markdown 摘要知识库。
// 技术要点：章节分块、逐块总结、合并成文、GlobalAIReadingService 落盘。

import '../../models/book.dart';
import '../../reader_core/ai/ai_service.dart';
import '../books/book_text_extraction_service.dart';
import 'ai_request_coordinator.dart';
import 'global_ai_reading_service.dart';

/// “AI 预处理书籍”总开关的持久化键；默认关闭。
const String aiPreprocessBooksPrefsKey = 'reader_ai_preprocess_books_v1';

class BookPreprocessCancelled implements Exception {
  const BookPreprocessCancelled();
}

class BookPreprocessCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

class _BookChunk {
  const _BookChunk({required this.label, required this.text});

  final String label;
  final String text;
}

/// 把整本书分块交给 AI 总结，再合并为一份 Markdown 知识库文档。
///
/// 消耗大量 token：每块一次请求 + 最终合并一次请求。
class BookPreprocessService {
  BookPreprocessService({
    AIService? ai,
    BookTextExtractionService? extractor,
    GlobalAIReadingService? knowledge,
    AiRequestCoordinator? coordinator,
  }) : _ai = ai ?? ReaderHttpAIService(),
       _extractor = extractor ?? const BookTextExtractionService(),
       _knowledge = knowledge ?? GlobalAIReadingService(),
       _coordinator = coordinator ?? AiRequestCoordinator();

  final AIService _ai;
  final BookTextExtractionService _extractor;
  final GlobalAIReadingService _knowledge;
  final AiRequestCoordinator _coordinator;

  static const int chunkChars = 6000;
  static const int maxChunks = 24;

  /// 返回生成的 Markdown 摘要；同时写入该书的本地知识库。
  ///
  /// [onProgress] 以 (已完成请求数, 总请求数) 回调；总数含最终合并请求。
  Future<String> preprocessBook({
    required Book book,
    void Function(int done, int total)? onProgress,
    BookPreprocessCancelToken? cancelToken,
  }) async {
    final chapters = await _extractor.extractChapters(book);
    final chunks = _buildChunks(chapters);
    final sampled = _sampleChunks(chunks);
    final total = sampled.length + 1;
    onProgress?.call(0, total);

    final bookId = book.id?.toString() ?? '';
    final partSummaries = <String>[];
    for (var index = 0; index < sampled.length; index++) {
      if (cancelToken?.isCancelled ?? false) {
        throw const BookPreprocessCancelled();
      }
      // 交互式对话优先：等对话请求结束再发下一块，避免挤占服务商并发额度。
      await _coordinator.waitUntilInteractiveIdle();
      if (cancelToken?.isCancelled ?? false) {
        throw const BookPreprocessCancelled();
      }
      final chunk = sampled[index];
      final answer = await _ai.chat(
        history: [
          AIChatMessage(
            role: 'user',
            content:
                '下面是书籍《${book.title}》的一段正文（${chunk.label}）。'
                '请用简洁的要点总结这一段的核心内容、出场人物/概念与关键情节，'
                '直接输出要点，不要客套话。\n\n${chunk.text}',
          ),
        ],
        pageText: '',
        meta: AIRequestMeta(bookId: bookId, chapterId: chunk.label),
      );
      partSummaries.add('### ${chunk.label}\n${answer.trim()}');
      onProgress?.call(index + 1, total);
    }

    if (cancelToken?.isCancelled ?? false) {
      throw const BookPreprocessCancelled();
    }
    await _coordinator.waitUntilInteractiveIdle();
    if (cancelToken?.isCancelled ?? false) {
      throw const BookPreprocessCancelled();
    }
    final omitted = chunks.length - sampled.length;
    final mergePrompt = StringBuffer()
      ..writeln(
        '以下是书籍《${book.title}》（作者：${book.author}）各部分的分段总结。'
        '请把它们整理成一份结构化的 Markdown 知识库文档，包含：'
        '一段总体梗概、主要人物或核心概念列表、按顺序的分章要点。'
        '直接输出 Markdown 正文，以“# ${book.title}”开头。',
      );
    if (omitted > 0) {
      mergePrompt.writeln('（注意：因篇幅限制，另有 $omitted 段正文未纳入总结，请在文末注明。）');
    }
    mergePrompt
      ..writeln()
      ..writeln(partSummaries.join('\n\n'));

    final markdown = await _ai.chat(
      history: [AIChatMessage(role: 'user', content: mergePrompt.toString())],
      pageText: '',
      meta: AIRequestMeta(bookId: bookId, chapterId: 'preprocess-merge'),
    );
    onProgress?.call(total, total);

    final document = markdown.trim();
    await _knowledge.saveBookSummary(bookId: bookId, summary: document);
    return document;
  }

  List<_BookChunk> _buildChunks(List<BookChapterText> chapters) {
    final chunks = <_BookChunk>[];
    final buffer = StringBuffer();
    String? bufferLabel;

    void flush() {
      if (buffer.isEmpty || bufferLabel == null) return;
      chunks.add(_BookChunk(label: bufferLabel!, text: buffer.toString()));
      buffer.clear();
      bufferLabel = null;
    }

    for (final chapter in chapters) {
      final text = chapter.text.trim();
      if (text.isEmpty) continue;
      if (text.length >= chunkChars) {
        flush();
        var start = 0;
        var part = 1;
        while (start < text.length) {
          final end = (start + chunkChars).clamp(0, text.length);
          chunks.add(
            _BookChunk(
              label: part == 1 ? chapter.title : '${chapter.title}（$part）',
              text: text.substring(start, end),
            ),
          );
          start = end;
          part += 1;
        }
        continue;
      }
      if (buffer.length + text.length > chunkChars) flush();
      if (buffer.isEmpty) {
        bufferLabel = chapter.title;
      } else {
        buffer.writeln();
      }
      buffer.writeln(text);
    }
    flush();
    return chunks;
  }

  /// 超长书籍均匀抽样，控制 token 消耗上限。
  List<_BookChunk> _sampleChunks(List<_BookChunk> chunks) {
    if (chunks.length <= maxChunks) return chunks;
    final sampled = <_BookChunk>[];
    for (var index = 0; index < maxChunks; index++) {
      final position = (index * (chunks.length - 1) / (maxChunks - 1)).round();
      sampled.add(chunks[position]);
    }
    return sampled;
  }
}

// 文件说明：本地书籍全文抽取服务，为 AI 预处理提供章节纯文本。
// 技术要点：TXT 章节切分、epubx 章节遍历、Kindle HTML 提取、isolate 抽取。

import 'dart:async';
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/reader/txt_chapter_parser.dart';
import '../../models/book.dart';
import 'enhanced_txt_import_service.dart';
import 'kindle_book_parser.dart';

class BookChapterText {
  const BookChapterText({
    required this.chapterId,
    required this.title,
    required this.text,
  });

  final String chapterId;
  final String title;
  final String text;
}

class BookTextExtractionException implements Exception {
  const BookTextExtractionException(this.code);

  /// `web_unsupported` | `format_unsupported` | `file_missing` | `empty_book`
  final String code;

  @override
  String toString() => code;
}

/// isolate 载荷参数：TXT 抽取所需的最小字段（不整体传 Book）。
class TxtChapterExtractionArgs {
  const TxtChapterExtractionArgs({
    required this.bytes,
    required this.title,
    this.encodingOverride,
  });

  final Uint8List bytes;
  final String title;
  final String? encodingOverride;
}

/// 顶层函数：在 isolate 中解码 TXT 并切分章节纯文本。
List<BookChapterText> extractTxtChapterTexts(TxtChapterExtractionArgs args) {
  final decoded = EnhancedTxtImportService().decodeWithOverride(
    args.bytes,
    encodingOverride: args.encodingOverride,
    verifyEncodingOverride: true,
  );
  final sections = splitOversizedTxtSections(
    decoded,
    parseTxtChapterSections(
      decoded,
      fallbackTitle: args.title,
      prefaceTitle: args.title,
    ),
  );
  return [
    for (final section in sections)
      BookChapterText(
        chapterId: section.id,
        title: section.title,
        text: section.bodyIn(decoded),
      ),
  ];
}

/// 顶层函数：在 isolate 中解析 EPUB（zip 解压 + XML/HTML 解析）并
/// 抽取章节纯文本。
Future<List<BookChapterText>> extractEpubChapterTexts(Uint8List bytes) async {
  final epub = await EpubReader.readBook(bytes);
  final chapters = <BookChapterText>[];

  void addChapter(EpubChapter chapter, int depth) {
    final html = chapter.HtmlContent ?? '';
    final text = html.isEmpty ? '' : _htmlToPlainText(html);
    chapters.add(
      BookChapterText(
        chapterId: chapter.ContentFileName ?? 'chapter-${chapters.length + 1}',
        title: chapter.Title?.trim().isNotEmpty == true
            ? chapter.Title!.trim()
            : 'Chapter ${chapters.length + 1}',
        text: text,
      ),
    );
    for (final sub in chapter.SubChapters ?? const <EpubChapter>[]) {
      addChapter(sub, depth + 1);
    }
  }

  for (final chapter in epub.Chapters ?? const <EpubChapter>[]) {
    addChapter(chapter, 0);
  }

  // 无目录章节的 EPUB 回退为逐个内容文档抽取。
  if (chapters.every((chapter) => chapter.text.trim().isEmpty)) {
    chapters.clear();
    final htmlFiles = epub.Content?.Html?.values;
    if (htmlFiles != null) {
      var index = 0;
      for (final htmlFile in htmlFiles) {
        index += 1;
        final content = htmlFile.Content ?? '';
        if (content.isEmpty) continue;
        chapters.add(
          BookChapterText(
            chapterId: htmlFile.FileName ?? 'content-$index',
            title: 'Section $index',
            text: _htmlToPlainText(content),
          ),
        );
      }
    }
  }
  return chapters;
}

/// 顶层函数：在 isolate 中解析 Kindle 记录并抽取章节纯文本。
List<BookChapterText> extractKindleChapterTexts(Uint8List bytes) {
  final content = parseKindleContent(bytes);
  final chapters = <BookChapterText>[];
  var index = 0;
  for (final part in content.htmlParts) {
    index += 1;
    final text = _htmlToPlainText(part);
    chapters.add(
      BookChapterText(
        chapterId: 'kindle-$index',
        title: 'Part $index',
        text: text,
      ),
    );
  }
  return chapters;
}

String _htmlToPlainText(String html) {
  try {
    final document = html_parser.parse(html);
    final text = document.body?.text ?? document.documentElement?.text ?? '';
    return text
        .replaceAll(' ', ' ')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  } catch (_) {
    return '';
  }
}

/// 不经阅读器 UI 直接抽取本地书籍的章节纯文本。
///
/// 仅覆盖 AI 预处理需要的主流格式：TXT、EPUB 与 Kindle（mobi/azw/azw3）。
/// 其余格式（漫画、PDF、DRM 书等）抛出 `format_unsupported`。
/// 解码与解析是 CPU 密集操作，统一放 isolate 执行，预处理启动时
/// 不再冻结 UI（AI 对话等界面保持可用）。
class BookTextExtractionService {
  const BookTextExtractionService();

  static const Set<String> supportedFormats = {
    'txt',
    'epub',
    'mobi',
    'azw',
    'azw3',
  };

  static bool supports(Book book) =>
      !kIsWeb &&
      !book.isOnline &&
      book.filePath.isNotEmpty &&
      supportedFormats.contains(book.format.toLowerCase());

  Future<List<BookChapterText>> extractChapters(Book book) async {
    if (kIsWeb) throw const BookTextExtractionException('web_unsupported');
    if (!supportedFormats.contains(book.format.toLowerCase())) {
      throw const BookTextExtractionException('format_unsupported');
    }
    final file = File(book.filePath);
    if (!await file.exists()) {
      throw const BookTextExtractionException('file_missing');
    }
    final bytes = await file.readAsBytes();
    final chapters = switch (book.format.toLowerCase()) {
      'txt' => await _runExtraction(
        extractTxtChapterTexts,
        TxtChapterExtractionArgs(
          bytes: bytes,
          title: book.title,
          encodingOverride: book.textEncoding,
        ),
      ),
      'epub' => await _runExtraction(extractEpubChapterTexts, bytes),
      _ => await _runExtraction(extractKindleChapterTexts, bytes),
    };
    final nonEmpty = chapters
        .where((chapter) => chapter.text.trim().isNotEmpty)
        .toList(growable: false);
    if (nonEmpty.isEmpty) throw const BookTextExtractionException('empty_book');
    return nonEmpty;
  }

  /// isolate 优先执行抽取载荷；isolate 启动或结果传输失败时回退主线程，
  /// 与导入链路的 EPUB 解析兜底策略一致。
  Future<List<BookChapterText>> _runExtraction<A>(
    FutureOr<List<BookChapterText>> Function(A) payload,
    A args,
  ) async {
    try {
      return await compute(payload, args);
    } catch (error) {
      debugPrint('⚠️ 章节抽取 isolate 失败，回退主线程: $error');
      return await payload(args);
    }
  }
}

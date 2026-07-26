import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/canonical_locator.dart';
import 'package:xxread/core/reader/reader_aloud_controller.dart';
import 'package:xxread/core/reader/reader_annotation.dart';
import 'package:xxread/core/reader/reader_text_layout.dart';
import 'package:xxread/core/reader/reader_text_pagination.dart';
import 'package:xxread/models/book_note.dart';
import 'package:xxread/utils/reader_themes.dart';

void main() {
  test('selection snapshots preserve quote context and canonical offsets', () {
    const source = '前文内容。需要高亮的句子。后文内容。';
    final start = source.indexOf('需要');
    final end = source.indexOf('。后文') + 1;
    final selection = ReaderSelectionSnapshot(
      bookId: 7,
      format: BookFormat.txt,
      renderer: ReaderRendererType.flutterNative,
      chapterId: 'chapter-1',
      chapterTitle: '第一章',
      chapterIndex: 0,
      pageIndex: 2,
      sourceText: source,
      startOffset: start,
      endOffset: end,
    );

    final locator = selection.toCanonicalLocator();

    expect(selection.selectedText, '需要高亮的句子。');
    expect(locator.chapterId, 'chapter-1');
    expect(locator.textAnchor?.startOffsetUtf16, start);
    expect(locator.textAnchor?.lengthUtf16, end - start);
    expect(locator.textAnchor?.quote, selection.selectedText);
  });

  test('page selection offsets map through generated indentation', () {
    const source = '\u3000\u3000正文内容';
    final layout = ReaderTextLayout.build(source, firstLineIndent: 2);
    final page = ReaderTextPage(
      text: layout.text,
      startOffset: 0,
      endOffset: source.length,
      layout: layout,
      displayEnd: layout.text.length,
    );

    expect(page.sourceOffsetForTextOffset(0), 0);
    expect(page.sourceOffsetForTextOffset(2), 2);
    expect(page.sourceOffsetForTextOffset(layout.text.length), source.length);
  });

  test('page selections skip source indentation hidden by zero indent', () {
    const source = '\u3000\u3000正文内容';
    final layout = ReaderTextLayout.build(source, firstLineIndent: 0);
    final page = ReaderTextPage(
      text: layout.text,
      startOffset: 0,
      endOffset: source.length,
      layout: layout,
      displayEnd: layout.text.length,
    );

    expect(layout.text, '正文内容');
    expect(page.sourceOffsetForTextOffset(0), 0);
    expect(page.sourceOffsetForTextOffset(0, preferVisibleStart: true), 2);
    expect(page.sourceOffsetForTextOffset(1), 3);
  });

  test('highlight spans add decoration without replacing EPUB typography', () {
    final annotation = BookNote(
      bookId: 1,
      content: '重点',
      cfi: 'or-annotation:highlight:chapter-1:2:4',
      canonicalLocator: LocatorCodec.encodeCanonicalLocator(
        CanonicalLocator.fromComponents(
          format: BookFormat.epub,
          chapterId: 'chapter-1',
          offset: 2,
          excerpt: '重点',
        ),
      ),
      chapter: '第一章',
      type: readerAnnotationTypeHighlight,
      color: 'FFD54F',
      startOffset: 2,
      endOffset: 4,
      createTime: DateTime(2026),
    );

    final span = buildReaderAnnotatedSpan(
      sourceText: '前文重点后文',
      start: 0,
      end: 6,
      baseStyle: const TextStyle(fontSize: 18),
      palette: ReaderThemes.night,
      annotations: [annotation],
      baseSpanBuilder: (start, end) => TextSpan(
        text: '前文重点后文'.substring(start, end),
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
    );
    final highlighted = span.children![1] as TextSpan;

    expect(highlighted.style?.fontStyle, FontStyle.italic);
    expect(highlighted.style?.backgroundColor, isNotNull);
  });

  test('spoken sentence highlight merges with a persistent note', () {
    final note = BookNote(
      bookId: 1,
      content: '重点',
      cfi: 'or-annotation:note:chapter-1:2:4',
      chapter: '第一章',
      type: readerAnnotationTypeNote,
      color: '7DD3FC',
      readerNote: '批注',
      startOffset: 2,
      endOffset: 4,
      createTime: DateTime(2026),
    );

    final span = buildReaderAnnotatedSpan(
      sourceText: '前文重点后文',
      start: 0,
      end: 6,
      baseStyle: const TextStyle(fontSize: 18),
      palette: ReaderThemes.day,
      annotations: [note],
      spokenHighlight: const ReaderAloudHighlight(
        chapterIndex: 0,
        chapterId: 'chapter-1',
        startOffset: 0,
        endOffset: 6,
      ),
    );
    final noted = span.children![1] as TextSpan;

    expect(noted.style?.backgroundColor, isNotNull);
    expect(noted.style?.decoration, TextDecoration.underline);
  });
}

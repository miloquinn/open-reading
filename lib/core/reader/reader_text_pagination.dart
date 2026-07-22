import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'native_text_paginator.dart';
import 'reader_text_layout.dart';

/// The maximum width of a single flowing-text leaf.
///
/// Local files and book-source chapters must resolve their content box through
/// this same rule so an identical chapter produces identical line breaks.
const double readerMaxTextContentWidth = 760;

double readerTextContentWidth(double viewportWidth, double horizontalMargin) =>
    (viewportWidth - horizontalMargin * 2).clamp(
      0.0,
      readerMaxTextContentWidth,
    );

double readerTextContentHeight(
  double viewportHeight,
  double topInset,
  double bottomInset,
) => (viewportHeight - topInset - bottomInset).clamp(0.0, double.infinity);

@immutable
class ReaderTextPage {
  const ReaderTextPage({
    required this.text,
    this.startOffset = 0,
    int? endOffset,
    this.layout,
    this.displayStart = 0,
    int? displayEnd,
    this.isChapterTitle = false,
  }) : endOffset = endOffset ?? startOffset + text.length,
       displayEnd = displayEnd ?? displayStart + text.length;

  const ReaderTextPage.chapterTitle({int sourceOffset = 0})
    : text = '',
      startOffset = sourceOffset,
      endOffset = sourceOffset,
      layout = null,
      displayStart = 0,
      displayEnd = 0,
      isChapterTitle = true;

  final String text;
  final int startOffset;
  final int endOffset;
  final ReaderTextLayout? layout;
  final int displayStart;
  final int displayEnd;
  final bool isChapterTitle;

  /// Compatibility name for the former book-source-only page model.
  bool get showsChapterTitle => isChapterTitle;

  TextSpan buildSpan({
    required TextStyle style,
    ReaderSourceSpanBuilder? sourceSpanBuilder,
  }) {
    final textLayout = layout;
    if (textLayout == null) return TextSpan(text: text, style: style);
    return textLayout.buildSpan(
      displayStart,
      displayEnd,
      sourceSpanBuilder:
          sourceSpanBuilder ??
          (sourceStart, sourceEnd) {
            final localStart = sourceStart - textLayout.sourceOffset;
            final localEnd = sourceEnd - textLayout.sourceOffset;
            return TextSpan(
              text: textLayout.sourceText.substring(localStart, localEnd),
              style: style,
            );
          },
      generatedStyle: style,
    );
  }
}

/// Projects and paginates one canonical text range.
///
/// This is the single entry point used by local text chapters and online
/// source chapters. Source adapters may produce different canonical text, but
/// indentation, paragraph spacing, visual-line measurement, offsets and title
/// page semantics are owned here.
List<ReaderTextPage> paginateReaderText({
  required String text,
  required double maxWidth,
  required double maxHeight,
  required NativeTextFlowStyle flowStyle,
  required TextStyle style,
  int sourceOffset = 0,
  double? firstPageHeight,
  int firstLineIndent = 0,
  int paragraphSpacing = 0,
  bool indentFirstParagraph = true,
  bool normalizeParagraphBreaks = false,
  bool includeChapterTitlePage = false,
  ReaderSourceSpanBuilder? sourceSpanBuilder,
}) {
  final pages = <ReaderTextPage>[
    if (includeChapterTitlePage)
      ReaderTextPage.chapterTitle(sourceOffset: sourceOffset),
  ];
  final layout = ReaderTextLayout.build(
    text,
    sourceOffset: sourceOffset,
    firstLineIndent: firstLineIndent,
    paragraphSpacing: paragraphSpacing,
    indentFirstParagraph: indentFirstParagraph,
    normalizeParagraphBreaks: normalizeParagraphBreaks,
  );

  if (layout.text.isEmpty) {
    if (pages.isEmpty || text.isNotEmpty) {
      pages.add(
        ReaderTextPage(
          text: '',
          startOffset: sourceOffset,
          endOffset: sourceOffset + text.length,
          layout: layout,
        ),
      );
    }
    return pages;
  }

  if (maxWidth <= 0 || maxHeight <= 0 || (firstPageHeight ?? maxHeight) <= 0) {
    pages.add(
      ReaderTextPage(
        text: layout.text,
        startOffset: sourceOffset,
        endOffset: sourceOffset + text.length,
        layout: layout,
        displayEnd: layout.text.length,
      ),
    );
    return pages;
  }

  TextSpan buildSpan(int start, int end) => layout.buildSpan(
    start,
    end,
    sourceSpanBuilder:
        sourceSpanBuilder ??
        (sourceStart, sourceEnd) {
          final localStart = sourceStart - layout.sourceOffset;
          final localEnd = sourceEnd - layout.sourceOffset;
          return TextSpan(
            text: layout.sourceText.substring(localStart, localEnd),
            style: style,
          );
        },
    generatedStyle: style,
  );

  final ranges =
      NativeTextPaginator(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        flowStyle: flowStyle,
      ).paginate(
        text: layout.text,
        spanBuilder: buildSpan,
        firstPageHeight: firstPageHeight,
      );
  pages.addAll(
    ranges.map(
      (range) => ReaderTextPage(
        text: layout.text.substring(range.start, range.end),
        startOffset: layout.sourceOffsetForDisplayOffset(range.start),
        endOffset: layout.sourceOffsetForDisplayOffset(range.end),
        layout: layout,
        displayStart: range.start,
        displayEnd: range.end,
      ),
    ),
  );

  assert(pages.isNotEmpty);
  assert(pages.first.startOffset == sourceOffset);
  assert(pages.last.endOffset == sourceOffset + text.length);
  for (var index = 1; index < pages.length; index++) {
    assert(pages[index - 1].endOffset == pages[index].startOffset);
  }
  return pages;
}

int readerTextPageIndexForOffset(List<ReaderTextPage> pages, int offset) {
  if (pages.isEmpty) return 0;
  final minOffset = pages.first.startOffset;
  final maxOffset = pages.last.endOffset;
  final safeOffset = offset.clamp(minOffset, maxOffset);
  final index = pages.indexWhere(
    (page) =>
        !page.isChapterTitle &&
        safeOffset >= page.startOffset &&
        safeOffset < page.endOffset,
  );
  return index >= 0 ? index : pages.length - 1;
}

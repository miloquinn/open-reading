import 'package:flutter/material.dart';
import 'package:xxread/core/reader/native_text_paginator.dart';

class BookSourceTextPage {
  const BookSourceTextPage({
    required this.text,
    required this.showsChapterTitle,
    required this.startOffset,
    required this.endOffset,
  });

  final String text;
  final bool showsChapterTitle;
  final int startOffset;
  final int endOffset;
}

List<String> removeRepeatedSourcePageMarkers(Iterable<String> paragraphs) {
  final values = paragraphs.toList(growable: false);
  final markersByTotal = <int, List<(int index, int page)>>{};
  final markerPattern = RegExp(r'^\s*(\d{1,4})\s*/\s*(\d{1,4})\s*$');
  for (var index = 0; index < values.length; index++) {
    final match = markerPattern.firstMatch(values[index]);
    if (match == null) continue;
    final page = int.parse(match.group(1)!);
    final total = int.parse(match.group(2)!);
    if (total < 3 || page < 1 || page > total) continue;
    markersByTotal.putIfAbsent(total, () => []).add((index, page));
  }

  final markerIndexes = <int>{};
  for (final markers in markersByTotal.values) {
    final distinctPages = markers.map((marker) => marker.$2).toSet();
    if (distinctPages.length < 3) continue;
    markerIndexes.addAll(markers.map((marker) => marker.$1));
  }
  if (markerIndexes.isEmpty) return values;
  return <String>[
    for (var index = 0; index < values.length; index++)
      if (!markerIndexes.contains(index)) values[index],
  ];
}

List<BookSourceTextPage> paginateBookSourceText(
  String text, {
  required double width,
  required double firstPageHeight,
  required double pageHeight,
  required TextStyle style,
  required TextDirection textDirection,
  TextScaler textScaler = TextScaler.noScaling,
  Locale? locale,
}) {
  if (text.isEmpty) {
    return const [
      BookSourceTextPage(
        text: '',
        showsChapterTitle: true,
        startOffset: 0,
        endOffset: 0,
      ),
    ];
  }

  final flowStyle = NativeTextFlowStyle(
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    strutStyle: null,
    textHeightBehavior: null,
  );
  TextSpan buildSpan(int start, int end) => TextSpan(
        text: text.substring(start, end),
        style: style,
      );

  final firstRange = NativeTextPaginator(
    maxWidth: width,
    maxHeight: firstPageHeight,
    flowStyle: flowStyle,
  ).paginate(text: text, spanBuilder: buildSpan).first;
  final pages = <BookSourceTextPage>[
    BookSourceTextPage(
      text: text.substring(firstRange.start, firstRange.end),
      showsChapterTitle: true,
      startOffset: firstRange.start,
      endOffset: firstRange.end,
    ),
  ];
  if (firstRange.end == text.length) return pages;

  final remaining = text.substring(firstRange.end);
  final remainingRanges = NativeTextPaginator(
    maxWidth: width,
    maxHeight: pageHeight,
    flowStyle: flowStyle,
  ).paginate(
    text: remaining,
    sourceOffset: firstRange.end,
    spanBuilder: buildSpan,
  );
  pages.addAll(
    remainingRanges.map(
      (range) => BookSourceTextPage(
        text: remaining.substring(range.start, range.end),
        showsChapterTitle: false,
        startOffset: firstRange.end + range.start,
        endOffset: firstRange.end + range.end,
      ),
    ),
  );
  assert(pages.map((page) => page.text).join() == text);
  return pages;
}

int bookSourcePageIndexForOffset(
  List<BookSourceTextPage> pages,
  int offset,
) {
  if (pages.isEmpty) return 0;
  final safeOffset = offset.clamp(0, pages.last.endOffset);
  final index = pages.indexWhere(
    (page) => safeOffset >= page.startOffset && safeOffset < page.endOffset,
  );
  return index >= 0 ? index : pages.length - 1;
}

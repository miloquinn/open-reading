import 'package:flutter/material.dart';
import 'package:xxread/core/reader/native_text_paginator.dart';
import 'package:xxread/core/reader/reader_text_pagination.dart';

typedef BookSourceTextPage = ReaderTextPage;

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
  int firstLineIndent = 0,
  int paragraphSpacing = 0,
  bool includeChapterTitlePage = true,
}) {
  final flowStyle = NativeTextFlowStyle(
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    strutStyle: readerStrutStyle(style),
    textHeightBehavior: readerTextHeightBehavior,
  );
  return paginateReaderText(
    text: text,
    maxWidth: width,
    maxHeight: pageHeight,
    firstPageHeight: firstPageHeight,
    flowStyle: flowStyle,
    style: style,
    firstLineIndent: firstLineIndent,
    paragraphSpacing: paragraphSpacing,
    includeChapterTitlePage: includeChapterTitlePage,
  );
}

int bookSourcePageIndexForOffset(List<BookSourceTextPage> pages, int offset) {
  return readerTextPageIndexForOffset(pages, offset);
}

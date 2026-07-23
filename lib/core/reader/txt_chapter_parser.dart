import 'package:flutter/foundation.dart';

import 'reader_text_characters.dart';

/// A TXT chapter whose heading and body occupy separate source ranges.
///
/// [bodyStart] always points past the matched heading line and any empty lines
/// immediately following it. [bodyEnd] excludes whitespace before the next
/// chapter heading. This keeps the heading out of body pagination without
/// copying the complete book while indexing large TXT files.
@immutable
class TxtChapterSection {
  const TxtChapterSection({
    required this.id,
    required this.title,
    required this.bodyStart,
    required this.bodyEnd,
    required this.isNeedSplitTitle,
    this.sourceChapterId,
    this.sourceBodyStart = 0,
  });

  final String id;
  final String title;
  final int bodyStart;
  final int bodyEnd;
  final bool isNeedSplitTitle;
  final String? sourceChapterId;
  final int sourceBodyStart;

  String bodyIn(String source) => source.substring(bodyStart, bodyEnd);
}

/// Splits a TXT document into chapter metadata and body ranges.
///
/// A dedicated title page is requested only for chapters backed by an actual
/// heading in the source. Unstructured TXT files keep their normal single body
/// flow instead of turning the book filename into an artificial title page.
List<TxtChapterSection> parseTxtChapterSections(
  String text, {
  required String fallbackTitle,
  required String prefaceTitle,
}) {
  final matches = _findTxtChapterMatches(text);
  if (matches.isEmpty) {
    return <TxtChapterSection>[
      TxtChapterSection(
        id: 'txt-0',
        title: fallbackTitle,
        bodyStart: 0,
        bodyEnd: text.length,
        isNeedSplitTitle: false,
      ),
    ];
  }

  final chapters = <TxtChapterSection>[];
  final prefaceEnd = _trimBodyEnd(text, 0, matches.first.headingStart);
  if (prefaceEnd > 0 && text.substring(0, prefaceEnd).trim().isNotEmpty) {
    chapters.add(
      TxtChapterSection(
        id: 'txt-preface',
        title: prefaceTitle,
        bodyStart: _skipEmptyLines(text, 0, prefaceEnd),
        bodyEnd: prefaceEnd,
        isNeedSplitTitle: false,
      ),
    );
  }

  for (var index = 0; index < matches.length; index++) {
    final match = matches[index];
    final sectionEnd = index + 1 < matches.length
        ? matches[index + 1].headingStart
        : text.length;
    final bodyStart = _skipEmptyLines(text, match.bodyStart, sectionEnd);
    final bodyEnd = _trimBodyEnd(text, bodyStart, sectionEnd);
    chapters.add(
      TxtChapterSection(
        id: 'txt-$index',
        title: match.title,
        bodyStart: bodyStart.clamp(0, bodyEnd),
        bodyEnd: bodyEnd,
        isNeedSplitTitle: true,
      ),
    );
  }
  return chapters;
}

/// Breaks every oversized TXT chapter into bounded lazy-load sections.
///
/// Without this guard, either a heading-less 70 MB document or one unusually
/// large recognized chapter can still be synchronously decoded and paginated
/// on the UI isolate. The indexer persists these ranges so the reader only
/// loads the current small part.
List<TxtChapterSection> splitOversizedTxtSections(
  String text,
  List<TxtChapterSection> sections, {
  int maxCharsPerSection = 32 * 1024,
}) {
  assert(maxCharsPerSection > 0);
  final result = <TxtChapterSection>[];
  for (final source in sections) {
    if (source.bodyEnd - source.bodyStart <= maxCharsPerSection) {
      result.add(source);
      continue;
    }
    final ranges = <(int, int)>[];
    var start = source.bodyStart;
    while (start < source.bodyEnd) {
      final targetEnd = (start + maxCharsPerSection).clamp(
        start,
        source.bodyEnd,
      );
      final end = targetEnd == source.bodyEnd
          ? source.bodyEnd
          : _nearbyLineBoundary(text, start: start, targetEnd: targetEnd);
      ranges.add((start, end));
      start = end;
    }
    for (var index = 0; index < ranges.length; index++) {
      final range = ranges[index];
      result.add(
        TxtChapterSection(
          id: index == 0 ? source.id : '${source.id}-part-$index',
          title: index == 0
              ? source.title
              : '${source.title} · ${index + 1}/${ranges.length}',
          bodyStart: range.$1,
          bodyEnd: range.$2,
          isNeedSplitTitle: index == 0 && source.isNeedSplitTitle,
          sourceChapterId: source.id,
          sourceBodyStart: range.$1 - source.bodyStart,
        ),
      );
    }
  }
  return result;
}

int _nearbyLineBoundary(
  String text, {
  required int start,
  required int targetEnd,
}) {
  final searchStart = (targetEnd - 16 * 1024).clamp(start + 1, targetEnd);
  for (var cursor = targetEnd; cursor > searchStart; cursor--) {
    final candidate = cursor - 1;
    if (!isReaderLineBreakCodeUnit(text.codeUnitAt(candidate))) continue;
    return candidate + readerLineBreakLengthAt(text, candidate);
  }
  return targetEnd;
}

List<_TxtChapterMatch> _findTxtChapterMatches(String text) {
  final heading = RegExp(
    r'^(?:第[0-9零〇一二三四五六七八九十百千万两]+[章节卷部篇回]|chapter\s+\d+|part\s+\d+|序章|序言|前言|引言|楔子|后记|尾声|番外)(?:[\s　:：.-]+.*)?$',
    caseSensitive: false,
  );
  final matches = <_TxtChapterMatch>[];
  var offset = 0;
  while (offset < text.length) {
    final lineBreak = _findLineBreak(text, offset);
    final lineEnd = lineBreak < 0 ? text.length : lineBreak;
    final title = text.substring(offset, lineEnd).trim();
    final normalizedTitle = title
        .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
        .trim();
    if (normalizedTitle.length <= 80 && heading.hasMatch(normalizedTitle)) {
      matches.add(
        _TxtChapterMatch(
          headingStart: offset,
          bodyStart: lineBreak < 0
              ? text.length
              : lineBreak + readerLineBreakLengthAt(text, lineBreak),
          title: normalizedTitle,
        ),
      );
    }
    offset = lineBreak < 0
        ? text.length
        : lineBreak + readerLineBreakLengthAt(text, lineBreak);
  }
  return matches;
}

int _skipEmptyLines(String text, int start, int end) {
  var cursor = start;
  while (cursor < end) {
    final lineBreak = _findLineBreak(text, cursor, end: end);
    final lineEnd = lineBreak < 0 ? end : lineBreak;
    if (text.substring(cursor, lineEnd).trim().isNotEmpty) return cursor;
    cursor = lineBreak < 0
        ? end
        : lineBreak + readerLineBreakLengthAt(text, lineBreak);
  }
  return cursor;
}

int _trimBodyEnd(String text, int start, int end) {
  var cursor = end;
  while (cursor > start) {
    final codeUnit = text.codeUnitAt(cursor - 1);
    if (!isReaderIndentCodeUnit(codeUnit) &&
        !isReaderLineBreakCodeUnit(codeUnit)) {
      break;
    }
    cursor--;
  }
  return cursor;
}

int _findLineBreak(String text, int start, {int? end}) {
  final limit = (end ?? text.length).clamp(0, text.length);
  for (var offset = start.clamp(0, limit); offset < limit; offset++) {
    if (isReaderLineBreakCodeUnit(text.codeUnitAt(offset))) return offset;
  }
  return -1;
}

@immutable
class _TxtChapterMatch {
  const _TxtChapterMatch({
    required this.headingStart,
    required this.bodyStart,
    required this.title,
  });

  final int headingStart;
  final int bodyStart;
  final String title;
}

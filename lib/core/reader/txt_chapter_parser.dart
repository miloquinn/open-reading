import 'package:flutter/foundation.dart';

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
  });

  final String id;
  final String title;
  final int bodyStart;
  final int bodyEnd;
  final bool isNeedSplitTitle;

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

List<_TxtChapterMatch> _findTxtChapterMatches(String text) {
  final heading = RegExp(
    r'^(?:第[0-9零〇一二三四五六七八九十百千万两]+[章节卷部篇回]|chapter\s+\d+|part\s+\d+|序章|序言|前言|引言|楔子|后记|尾声|番外)(?:[\s　:：.-]+.*)?$',
    caseSensitive: false,
  );
  final matches = <_TxtChapterMatch>[];
  var offset = 0;
  while (offset < text.length) {
    final lineBreak = text.indexOf('\n', offset);
    final lineEnd = lineBreak < 0 ? text.length : lineBreak;
    final title = text.substring(offset, lineEnd).trim();
    final normalizedTitle =
        title.replaceFirst(RegExp(r'^#{1,6}\s*'), '').trim();
    if (normalizedTitle.length <= 80 && heading.hasMatch(normalizedTitle)) {
      matches.add(
        _TxtChapterMatch(
          headingStart: offset,
          bodyStart: lineBreak < 0 ? text.length : lineBreak + 1,
          title: normalizedTitle,
        ),
      );
    }
    offset = lineBreak < 0 ? text.length : lineBreak + 1;
  }
  return matches;
}

int _skipEmptyLines(String text, int start, int end) {
  var cursor = start;
  while (cursor < end) {
    final lineBreak = text.indexOf('\n', cursor);
    final lineEnd = lineBreak < 0 || lineBreak >= end ? end : lineBreak;
    if (text.substring(cursor, lineEnd).trim().isNotEmpty) return cursor;
    cursor = lineBreak < 0 || lineBreak >= end ? end : lineBreak + 1;
  }
  return cursor;
}

int _trimBodyEnd(String text, int start, int end) {
  var cursor = end;
  while (cursor > start) {
    final codeUnit = text.codeUnitAt(cursor - 1);
    if (codeUnit != 0x20 &&
        codeUnit != 0x09 &&
        codeUnit != 0x0A &&
        codeUnit != 0x0D &&
        codeUnit != 0x3000) {
      break;
    }
    cursor--;
  }
  return cursor;
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

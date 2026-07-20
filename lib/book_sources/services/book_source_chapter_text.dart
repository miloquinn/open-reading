import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../protocol/book_source_protocol.dart';
import 'book_source_text_paginator.dart';

const _bookSourceBlockTags = {'p', 'div', 'li', 'blockquote'};

/// Converts a source payload into canonical chapter text.
///
/// This adapter owns source-specific HTML extraction and repeated remote page
/// marker cleanup. It deliberately does not inject indentation or paragraph
/// spacing; those are display settings applied later by the shared reader text
/// pipeline.
String readableBookSourceChapterText(
  BookSourceChapterContent content, {
  String fallbackTitle = '',
}) {
  final chapterTitles = <String>{
    if (content.title.trim().isNotEmpty) content.title,
    if (fallbackTitle.trim().isNotEmpty) fallbackTitle,
  };
  if (content.contentType != 'text/html') {
    final normalized = content.content
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = removeRepeatedSourcePageMarkers(normalized.split('\n'));
    return _removeRepeatedLeadingChapterTitle(lines, chapterTitles).join('\n');
  }

  final paragraphs = <String>[];
  final fragment = html_parser.parseFragment(content.content);
  final segment = StringBuffer();

  void flush() {
    final text = segment.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isNotEmpty) paragraphs.add(text);
    segment.clear();
  }

  void walk(Iterable<dom.Node> nodes) {
    for (final child in nodes) {
      if (child is dom.Element) {
        if (_bookSourceBlockTags.contains(child.localName)) {
          flush();
          walk(child.nodes);
          flush();
          continue;
        }
        if (child.localName == 'br') {
          flush();
          continue;
        }
        walk(child.nodes);
      } else if (child is dom.Text) {
        segment.write(child.data);
      }
    }
  }

  walk(fragment.nodes);
  flush();
  final extracted = paragraphs.isEmpty
      ? <String>[fragment.text?.trim() ?? '']
      : removeRepeatedSourcePageMarkers(paragraphs);
  return _removeRepeatedLeadingChapterTitle(extracted, chapterTitles)
      .join('\n');
}

List<String> _removeRepeatedLeadingChapterTitle(
  List<String> values,
  Set<String> chapterTitles,
) {
  final titleKeys = chapterTitles
      .map(_chapterTitleKey)
      .where((value) => value.isNotEmpty)
      .toSet();
  if (values.isEmpty || titleKeys.isEmpty) return values;
  final firstContentIndex =
      values.indexWhere((value) => value.trim().isNotEmpty);
  if (firstContentIndex < 0 ||
      !titleKeys.contains(_chapterTitleKey(values[firstContentIndex]))) {
    return values;
  }
  var bodyStart = firstContentIndex + 1;
  while (bodyStart < values.length && values[bodyStart].trim().isEmpty) {
    bodyStart++;
  }
  return values.sublist(bodyStart);
}

String _chapterTitleKey(String value) => value
    .replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

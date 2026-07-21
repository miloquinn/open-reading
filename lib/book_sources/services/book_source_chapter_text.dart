import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../protocol/book_source_protocol.dart';
import '../../core/reader/reader_text_characters.dart';
import 'book_source_text_paginator.dart';

const _bookSourceBlockTags = {'p', 'div', 'li', 'blockquote'};

/// Matches the opening of any HTML tag (`<p`, `</br`, `<img`, …) without
/// requiring a closing `>`. Plain-text bodies never legitimately contain this
/// sequence, so the presence of a tag opener is enough to route the payload
/// through the HTML extraction path.
final _htmlTagOpener = RegExp(r'</?[a-z][a-z0-9]*', caseSensitive: false);

/// Converts a source payload into canonical chapter text.
///
/// This adapter owns source-specific HTML extraction and repeated remote page
/// marker cleanup. It deliberately does not inject indentation or paragraph
/// spacing; those are display settings applied later by the shared reader
/// text pipeline.
///
/// The parsing path is chosen by inspecting the content itself, not the
/// declared `contentType`. Source declarations are unreliable in the wild:
/// plain text is frequently labelled `text/html` and well-formed HTML
/// occasionally arrives as `text/plain`. Probing the content routes each
/// payload through the semantically correct path so the shared layout layer
/// always receives properly paragraph-separated text, which is the only
/// signal it can use to apply first-line indentation.
String readableBookSourceChapterText(
  BookSourceChapterContent content, {
  String fallbackTitle = '',
}) {
  final chapterTitles = <String>{
    if (content.title.trim().isNotEmpty) content.title,
    if (fallbackTitle.trim().isNotEmpty) fallbackTitle,
  };

  final paragraphs = _looksLikeHtml(content.content)
      ? _extractHtmlParagraphs(content.content)
      : _extractPlainTextParagraphs(content.content);

  final cleaned = removeRepeatedSourcePageMarkers(paragraphs);
  return _removeRepeatedLeadingChapterTitle(cleaned, chapterTitles).join('\n');
}

bool _looksLikeHtml(String content) => _htmlTagOpener.hasMatch(content);

/// Preserves the source's own line structure: BOM is stripped and every hard
/// Unicode line break is folded to a canonical paragraph boundary, while
/// leading whitespace and blank lines remain available to downstream logic.
List<String> _extractPlainTextParagraphs(String raw) {
  final normalized = raw.replaceFirst('\uFEFF', '');
  return splitReaderTextLines(normalized);
}

/// Walks the parsed fragment and emits one canonical paragraph per block
/// boundary, `<br>`, or literal newline found inside a text node. Runs of
/// non-newline whitespace inside a segment are collapsed into a single
/// space.
List<String> _extractHtmlParagraphs(String raw) {
  final fragment = html_parser.parseFragment(raw.replaceFirst('\uFEFF', ''));
  final paragraphs = <String>[];
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
        // A literal newline inside a text node is the common shape for
        // sources that dump mostly-plain paragraphs inside a wrapping tag
        // (e.g. a chapter with one stray inline `<img>`/`<b>` and every
        // other paragraph separated only by `\n`). Treat it like an
        // implicit `<br>` so those paragraphs still get split instead of
        // being silently glued together by the `\s+` collapse in flush().
        final lines = splitReaderTextLines(child.data);
        for (var i = 0; i < lines.length; i++) {
          if (i > 0) flush();
          segment.write(lines[i]);
        }
      }
    }
  }

  walk(fragment.nodes);
  flush();
  // Degenerate payloads (image-only chapters, unclosed tags, comments) may
  // yield no extractable text; fall back to whatever the fragment exposes as
  // plain text so the reader never renders a blank page.
  if (paragraphs.isEmpty) {
    final fallback = fragment.text?.trim() ?? '';
    if (fallback.isNotEmpty) return [fallback];
  }
  return paragraphs;
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

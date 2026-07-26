import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:xxread/core/reader/canonical_locator.dart';
import 'package:xxread/core/reader/reader_aloud_controller.dart';
import 'package:xxread/models/book_note.dart';
import 'package:xxread/utils/reader_themes.dart';

const String readerAnnotationTypeHighlight = 'highlight';
const String readerAnnotationTypeUnderline = 'underline';
const String readerAnnotationTypeNote = 'note';
const String readerAnnotationTypeInk = 'ink';

@immutable
class ReaderSelectionSnapshot {
  const ReaderSelectionSnapshot({
    required this.bookId,
    required this.format,
    required this.renderer,
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.pageIndex,
    required this.sourceText,
    required this.startOffset,
    required this.endOffset,
  });

  final int? bookId;
  final BookFormat format;
  final ReaderRendererType renderer;
  final String chapterId;
  final String chapterTitle;
  final int chapterIndex;
  final int pageIndex;
  final String sourceText;
  final int startOffset;
  final int endOffset;

  String get selectedText {
    final start = startOffset.clamp(0, sourceText.length);
    final end = endOffset.clamp(start, sourceText.length);
    return sourceText.substring(start, end);
  }

  String get prefix {
    final start = startOffset.clamp(0, sourceText.length);
    return sourceText.substring((start - 48).clamp(0, start), start);
  }

  String get suffix {
    final end = endOffset.clamp(0, sourceText.length);
    return sourceText.substring(end, (end + 48).clamp(end, sourceText.length));
  }

  double get progression => sourceText.isEmpty
      ? 0
      : (startOffset / sourceText.length).clamp(0.0, 1.0);

  ReaderSelection toReaderSelection() => ReaderSelection.create(
    bookId: bookId?.toString() ?? '',
    format: format,
    renderer: renderer,
    selectedText: selectedText,
    chapterId: chapterId,
    startOffsetUtf16: startOffset,
    lengthUtf16: endOffset - startOffset,
    prefix: prefix,
    suffix: suffix,
    progression: progression,
    positionHint: pageIndex + 1,
  );

  CanonicalLocator toCanonicalLocator() => CanonicalLocator.create(
    format: format,
    chapterId: chapterId,
    progression: progression,
    positionHint: pageIndex + 1,
    textAnchor: TextAnchor.create(
      quote: selectedText,
      prefix: prefix,
      suffix: suffix,
      chapterId: chapterId,
      startOffsetUtf16: startOffset,
      lengthUtf16: endOffset - startOffset,
      offsetHint: startOffset,
    ),
  );

  String get canonicalLocatorJson =>
      LocatorCodec.encodeCanonicalLocator(toCanonicalLocator());

  String cfiFor(String type) =>
      'or-annotation:$type:${Uri.encodeComponent(chapterId)}:'
      '$startOffset:$endOffset';
}

@immutable
class ReaderAnnotationEditorResult {
  const ReaderAnnotationEditorResult({
    required this.type,
    required this.colorHex,
    this.note,
  });

  final String type;
  final String colorHex;
  final String? note;
}

String? readerAnnotationChapterId(BookNote annotation) {
  final raw = annotation.canonicalLocator;
  if (raw != null && raw.trim().isNotEmpty) {
    final locator = LocatorCodec.decodeCanonicalLocator(raw);
    final chapterId = locator?.chapterId ?? locator?.textAnchor?.chapterId;
    if (chapterId != null && chapterId.isNotEmpty) return chapterId;
  }
  final parts = annotation.cfi.split(':');
  if (parts.length >= 5 && parts.first == 'or-annotation') {
    return Uri.decodeComponent(parts[2]);
  }
  return null;
}

bool readerAnnotationMatchesChapter(BookNote annotation, String chapterId) =>
    readerAnnotationChapterId(annotation) == chapterId;

bool readerAnnotationOverlaps(
  BookNote annotation,
  String chapterId,
  int start,
  int end,
) {
  if (!readerAnnotationMatchesChapter(annotation, chapterId)) return false;
  final annotationStart = annotation.startOffset;
  final annotationEnd = annotation.endOffset;
  if (annotationStart == null || annotationEnd == null) return false;
  return annotationEnd > start && annotationStart < end;
}

List<BookNote> readerTextAnnotationsForChapter(
  Iterable<BookNote> annotations,
  String chapterId,
) => annotations
    .where(
      (annotation) =>
          annotation.type != readerAnnotationTypeInk &&
          readerAnnotationMatchesChapter(annotation, chapterId) &&
          annotation.startOffset != null &&
          annotation.endOffset != null,
    )
    .toList(growable: false);

TextSpan buildReaderAnnotatedSpan({
  required String sourceText,
  required int start,
  required int end,
  required TextStyle baseStyle,
  required ReaderThemePalette palette,
  required Iterable<BookNote> annotations,
  ReaderAloudHighlight? spokenHighlight,
  TextSpan Function(int start, int end)? baseSpanBuilder,
  GestureRecognizer? Function(BookNote annotation)? recognizerBuilder,
}) {
  if (start >= end) return TextSpan(style: baseStyle, text: '');
  final relevant = annotations
      .where(
        (annotation) =>
            annotation.type != readerAnnotationTypeInk &&
            annotation.startOffset != null &&
            annotation.endOffset != null &&
            annotation.endOffset! > start &&
            annotation.startOffset! < end,
      )
      .toList(growable: false);
  final activeSpokenHighlight =
      spokenHighlight != null &&
          spokenHighlight.endOffset > start &&
          spokenHighlight.startOffset < end
      ? spokenHighlight
      : null;
  if (relevant.isEmpty && activeSpokenHighlight == null) {
    return baseSpanBuilder?.call(start, end) ??
        TextSpan(text: sourceText.substring(start, end), style: baseStyle);
  }

  final boundaries = <int>{start, end};
  for (final annotation in relevant) {
    boundaries
      ..add(annotation.startOffset!.clamp(start, end))
      ..add(annotation.endOffset!.clamp(start, end));
  }
  if (activeSpokenHighlight != null) {
    boundaries
      ..add(activeSpokenHighlight.startOffset.clamp(start, end))
      ..add(activeSpokenHighlight.endOffset.clamp(start, end));
  }
  final sorted = boundaries.toList()..sort();
  final children = <InlineSpan>[];
  for (var index = 0; index < sorted.length - 1; index++) {
    final segmentStart = sorted[index];
    final segmentEnd = sorted[index + 1];
    if (segmentStart >= segmentEnd) continue;
    final active =
        relevant
            .where(
              (annotation) =>
                  annotation.startOffset! < segmentEnd &&
                  annotation.endOffset! > segmentStart,
            )
            .toList(growable: false)
          ..sort((a, b) => b.updateTime.compareTo(a.updateTime));
    final baseSpan =
        baseSpanBuilder?.call(segmentStart, segmentEnd) ??
        TextSpan(
          text: sourceText.substring(segmentStart, segmentEnd),
          style: baseStyle,
        );
    final isSpoken =
        activeSpokenHighlight != null &&
        activeSpokenHighlight.startOffset < segmentEnd &&
        activeSpokenHighlight.endOffset > segmentStart;
    if (active.isEmpty && !isSpoken) {
      children.add(baseSpan);
      continue;
    }
    final note = active
        .where((annotation) => annotation.type == readerAnnotationTypeNote)
        .firstOrNull;
    var decorated = baseSpan;
    if (active.isNotEmpty) {
      final primary = note ?? active.first;
      decorated = _mergeTextSpanStyle(
        decorated,
        _annotationTextStyle(primary, palette),
        recognizer: note == null ? null : recognizerBuilder?.call(note),
      );
    }
    if (isSpoken) {
      decorated = _mergeTextSpanStyle(
        decorated,
        _spokenHighlightTextStyle(palette),
      );
    }
    children.add(decorated);
  }
  return TextSpan(style: baseStyle, children: children);
}

TextStyle _spokenHighlightTextStyle(ReaderThemePalette palette) => TextStyle(
  backgroundColor: palette.accent.withValues(
    alpha: palette.brightness == Brightness.dark ? 0.34 : 0.22,
  ),
  fontWeight: FontWeight.w600,
);

TextSpan _mergeTextSpanStyle(
  TextSpan span,
  TextStyle overlay, {
  GestureRecognizer? recognizer,
}) => TextSpan(
  text: span.text,
  children: span.children == null
      ? null
      : <InlineSpan>[
          for (final child in span.children!)
            if (child is TextSpan)
              _mergeTextSpanStyle(child, overlay, recognizer: recognizer)
            else
              child,
        ],
  style: (span.style ?? const TextStyle()).merge(overlay),
  recognizer: span.recognizer ?? recognizer,
  mouseCursor: span.recognizer == null && recognizer != null
      ? SystemMouseCursors.click
      : span.mouseCursor,
  onEnter: span.onEnter,
  onExit: span.onExit,
  semanticsLabel: span.semanticsLabel,
  semanticsIdentifier: span.semanticsIdentifier,
  locale: span.locale,
  spellOut: span.spellOut,
);

TextStyle _annotationTextStyle(
  BookNote annotation,
  ReaderThemePalette palette,
) {
  final color = readerAnnotationColor(annotation.color, palette);
  final isDark = palette.brightness == Brightness.dark;
  return switch (annotation.type) {
    readerAnnotationTypeUnderline => TextStyle(
      decoration: TextDecoration.underline,
      decorationColor: color.withValues(alpha: isDark ? 0.94 : 0.86),
      decorationThickness: 2.2,
    ),
    readerAnnotationTypeNote => TextStyle(
      backgroundColor: color.withValues(alpha: isDark ? 0.22 : 0.18),
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: color.withValues(alpha: 0.95),
      decorationThickness: 1.8,
    ),
    _ => TextStyle(
      backgroundColor: color.withValues(alpha: isDark ? 0.32 : 0.28),
    ),
  };
}

Color readerAnnotationColor(String colorHex, ReaderThemePalette palette) {
  final normalized = _normalizedColorHex(colorHex);
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return palette.accent;
  return Color(0xFF000000 | parsed);
}

String readerColorHex(Color color) => color
    .toARGB32()
    .toRadixString(16)
    .padLeft(8, '0')
    .substring(2)
    .toUpperCase();

String _normalizedColorHex(String value) {
  final normalized = value.replaceAll('#', '').trim().toUpperCase();
  if (normalized.length == 8) return normalized.substring(2);
  if (normalized.length == 6) return normalized;
  return '3F63B8';
}

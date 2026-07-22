import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'reader_text_characters.dart';

typedef ReaderSourceSpanBuilder = InlineSpan Function(
  int sourceStart,
  int sourceEnd,
);

// SkParagraph discards leading whitespace when a justified paragraph wraps.
// HANGUL FILLER is visually blank and full-width, but Unicode classifies it as
// a letter, so Android and desktop paragraph engines cannot trim it as space.
const _readerIndentCharacter = '\u3164';

/// A display-only typography projection of canonical reader text.
///
/// First-line indentation and paragraph spacing add or replace visual code
/// units. Canonical locations must continue to use offsets in [sourceText], so
/// every display boundary keeps a monotonic mapping back to the original UTF-16
/// boundary. Pagination still runs through [NativeTextPaginator]; this class is
/// only the projection shared by its measurement span and the rendered span.
///
/// When `normalizeParagraphBreaks` is enabled, runs of two or more source line
/// breaks are treated as paragraph separators and projected to exactly one
/// structural line break plus the configured additional spacing. This lets
/// EPUB rendering remove parser-generated blank rows without changing canonical
/// source offsets.
@immutable
class ReaderTextLayout {
  const ReaderTextLayout._({
    required this.sourceText,
    required this.sourceOffset,
    required this.text,
    required List<_ReaderTextRun> runs,
    required List<int> sourceBoundaries,
  })  : _runs = runs,
        _sourceBoundaries = sourceBoundaries;

  factory ReaderTextLayout.build(
    String sourceText, {
    int sourceOffset = 0,
    int firstLineIndent = 0,
    int paragraphSpacing = 0,
    bool indentFirstParagraph = true,
    bool normalizeParagraphBreaks = false,
  }) {
    final indent = firstLineIndent.clamp(0, 4);
    final spacing = paragraphSpacing.clamp(0, 2);
    final output = StringBuffer();
    final runs = <_ReaderTextRun>[];
    final boundaries = <int>[sourceOffset];
    var displayOffset = 0;
    var sourceCursor = 0;
    var atParagraphStart = indentFirstParagraph;

    void appendSource(int start, int end) {
      if (end <= start) return;
      final value = sourceText.substring(start, end);
      output.write(value);
      runs.add(
        _ReaderTextRun.source(
          displayStart: displayOffset,
          displayEnd: displayOffset + value.length,
          sourceStart: sourceOffset + start,
          sourceEnd: sourceOffset + end,
        ),
      );
      for (var index = start; index < end; index++) {
        boundaries.add(sourceOffset + index + 1);
      }
      displayOffset += value.length;
      sourceCursor = end;
    }

    void appendGenerated(
      String value, {
      required int replacedSourceStart,
      required int replacedSourceEnd,
    }) {
      if (value.isEmpty) return;
      output.write(value);
      runs.add(
        _ReaderTextRun.generated(
          displayStart: displayOffset,
          displayEnd: displayOffset + value.length,
          text: value,
        ),
      );
      final globalStart = sourceOffset + replacedSourceStart;
      final replacedLength = replacedSourceEnd - replacedSourceStart;
      for (var index = 1; index <= value.length; index++) {
        final consumed = replacedLength == 0
            ? 0
            : (replacedLength * index / value.length).round();
        boundaries.add(globalStart + consumed);
      }
      displayOffset += value.length;
      sourceCursor = replacedSourceEnd;
    }

    while (sourceCursor < sourceText.length) {
      if (atParagraphStart) {
        final existingIndentStart = sourceCursor;
        while (sourceCursor < sourceText.length &&
            isReaderIndentCodeUnit(sourceText.codeUnitAt(sourceCursor))) {
          sourceCursor++;
        }
        if (sourceCursor < sourceText.length &&
            !isReaderLineBreakCodeUnit(sourceText.codeUnitAt(sourceCursor))) {
          appendGenerated(
            List.filled(indent, _readerIndentCharacter).join(),
            replacedSourceStart: existingIndentStart,
            replacedSourceEnd: sourceCursor,
          );
          atParagraphStart = false;
        }
      }

      final textStart = sourceCursor;
      while (sourceCursor < sourceText.length &&
          !isReaderLineBreakCodeUnit(sourceText.codeUnitAt(sourceCursor))) {
        sourceCursor++;
      }
      appendSource(textStart, sourceCursor);
      if (sourceCursor >= sourceText.length) break;

      final breakStart = sourceCursor;
      var logicalBreakCount = 0;
      while (sourceCursor < sourceText.length &&
          isReaderLineBreakCodeUnit(sourceText.codeUnitAt(sourceCursor))) {
        sourceCursor += readerLineBreakLengthAt(sourceText, sourceCursor);
        logicalBreakCount++;
      }
      if (normalizeParagraphBreaks && logicalBreakCount > 1) {
        // A paragraph separator at the beginning of a projection commonly
        // follows an inline EPUB image. The image/text gap already separates
        // the blocks, so rendering a leading newline would create a blank row.
        if (displayOffset > 0) {
          appendGenerated(
            List.filled(spacing + 1, '\n').join(),
            replacedSourceStart: breakStart,
            replacedSourceEnd: sourceCursor,
          );
        }
      } else {
        appendSource(breakStart, sourceCursor);
        if (sourceCursor < sourceText.length && spacing > 0) {
          appendGenerated(
            List.filled(spacing, '\n').join(),
            replacedSourceStart: sourceCursor,
            replacedSourceEnd: sourceCursor,
          );
        }
      }
      atParagraphStart = true;
    }

    if (sourceCursor == sourceText.length && boundaries.isNotEmpty) {
      boundaries[boundaries.length - 1] = sourceOffset + sourceText.length;
    }
    assert(boundaries.length == output.length + 1);
    return ReaderTextLayout._(
      sourceText: sourceText,
      sourceOffset: sourceOffset,
      text: output.toString(),
      runs: List.unmodifiable(runs),
      sourceBoundaries: List.unmodifiable(boundaries),
    );
  }

  final String sourceText;
  final int sourceOffset;
  final String text;
  final List<_ReaderTextRun> _runs;
  final List<int> _sourceBoundaries;

  int sourceOffsetForDisplayOffset(int displayOffset) {
    if (_sourceBoundaries.isEmpty) return sourceOffset;
    final safeOffset = displayOffset.clamp(0, text.length);
    return _sourceBoundaries[safeOffset];
  }

  TextSpan buildSpan(
    int displayStart,
    int displayEnd, {
    required ReaderSourceSpanBuilder sourceSpanBuilder,
    required TextStyle generatedStyle,
  }) {
    final safeStart = displayStart.clamp(0, text.length);
    final safeEnd = displayEnd.clamp(safeStart, text.length);
    if (safeStart == safeEnd) {
      return TextSpan(style: generatedStyle, text: '');
    }

    final children = <InlineSpan>[];
    for (final run in _runs) {
      if (run.displayEnd <= safeStart || run.displayStart >= safeEnd) {
        continue;
      }
      final overlapStart = run.displayStart.clamp(safeStart, safeEnd);
      final overlapEnd = run.displayEnd.clamp(safeStart, safeEnd);
      if (overlapEnd <= overlapStart) continue;
      final localStart = overlapStart - run.displayStart;
      final localEnd = overlapEnd - run.displayStart;
      if (run.isGenerated) {
        children.add(
          TextSpan(
            text: run.generatedText!.substring(localStart, localEnd),
            style: generatedStyle,
          ),
        );
      } else {
        children.add(
          sourceSpanBuilder(
            run.sourceStart! + localStart,
            run.sourceStart! + localEnd,
          ),
        );
      }
    }
    return TextSpan(style: generatedStyle, children: children);
  }
}

@immutable
class _ReaderTextRun {
  const _ReaderTextRun._({
    required this.displayStart,
    required this.displayEnd,
    this.sourceStart,
    this.sourceEnd,
    this.generatedText,
  });

  const _ReaderTextRun.source({
    required int displayStart,
    required int displayEnd,
    required int sourceStart,
    required int sourceEnd,
  }) : this._(
          displayStart: displayStart,
          displayEnd: displayEnd,
          sourceStart: sourceStart,
          sourceEnd: sourceEnd,
        );

  const _ReaderTextRun.generated({
    required int displayStart,
    required int displayEnd,
    required String text,
  }) : this._(
          displayStart: displayStart,
          displayEnd: displayEnd,
          generatedText: text,
        );

  final int displayStart;
  final int displayEnd;
  final int? sourceStart;
  final int? sourceEnd;
  final String? generatedText;

  bool get isGenerated => generatedText != null;
}

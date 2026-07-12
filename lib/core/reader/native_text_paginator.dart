import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

typedef NativeTextSpanBuilder = TextSpan Function(int start, int end);

@immutable
class NativeTextFlowStyle {
  const NativeTextFlowStyle({
    required this.textDirection,
    required this.textScaler,
    required this.locale,
    required this.strutStyle,
    required this.textHeightBehavior,
    this.textAlign = TextAlign.start,
    this.textWidthBasis = TextWidthBasis.parent,
  });

  final TextDirection textDirection;
  final TextScaler textScaler;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextHeightBehavior? textHeightBehavior;
  final TextAlign textAlign;
  final TextWidthBasis textWidthBasis;

  TextPainter createPainter(
    InlineSpan text, {
    int? maxLines,
  }) {
    return TextPainter(
      text: text,
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: maxLines,
      locale: locale,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    );
  }
}

@immutable
class NativeTextPageRange {
  const NativeTextPageRange({
    required this.start,
    required this.end,
    required this.lineCount,
  });

  final int start;
  final int end;
  final int lineCount;
}

/// Paginates only at visual line boundaries produced by Flutter's paragraph
/// engine. Measurement and rendering must use the same [flowStyle].
class NativeTextPaginator {
  const NativeTextPaginator({
    required this.maxWidth,
    required this.maxHeight,
    required this.flowStyle,
    this.initialProbeLength = 2048,
    this.avoidShortContinuingLine = true,
  });

  final double maxWidth;
  final double maxHeight;
  final NativeTextFlowStyle flowStyle;
  final int initialProbeLength;
  final bool avoidShortContinuingLine;

  List<NativeTextPageRange> paginate({
    required String text,
    required NativeTextSpanBuilder spanBuilder,
    int sourceOffset = 0,
  }) {
    if (text.isEmpty || maxWidth <= 0 || maxHeight <= 0) {
      return const <NativeTextPageRange>[];
    }

    final pages = <NativeTextPageRange>[];
    var pageStart = 0;
    while (pageStart < text.length) {
      final candidates = _lineEndCandidates(
        text: text,
        pageStart: pageStart,
        sourceOffset: sourceOffset,
        spanBuilder: spanBuilder,
      );
      var selected = _selectVerifiedCandidate(
        candidates: candidates,
        pageStart: pageStart,
        sourceOffset: sourceOffset,
        spanBuilder: spanBuilder,
      );

      if (avoidShortContinuingLine &&
          selected.lineCount > 1 &&
          selected.end < text.length &&
          !_endsParagraph(text, selected.end)) {
        final selectedIndex = candidates.indexOf(selected.end);
        final previousEnd =
            selectedIndex > 0 ? candidates[selectedIndex - 1] : -1;
        if (previousEnd >= pageStart) {
          final finalLine = text.substring(previousEnd, selected.end).trim();
          if (finalLine.isNotEmpty && finalLine.runes.length <= 2) {
            selected = _verifiedRange(
                  pageStart: pageStart,
                  pageEnd: previousEnd,
                  sourceOffset: sourceOffset,
                  spanBuilder: spanBuilder,
                ) ??
                selected;
          }
        }
      }

      assert(selected.end > pageStart);
      pages.add(selected);
      pageStart = selected.end;
    }

    assert(pages.first.start == 0);
    assert(pages.last.end == text.length);
    for (var i = 1; i < pages.length; i++) {
      assert(pages[i - 1].end == pages[i].start);
    }
    return pages;
  }

  List<int> _lineEndCandidates({
    required String text,
    required int pageStart,
    required int sourceOffset,
    required NativeTextSpanBuilder spanBuilder,
  }) {
    var probeLength = math.min(initialProbeLength, text.length - pageStart);
    while (true) {
      var probeEnd = pageStart + probeLength;
      probeEnd = _safeCodeUnitBoundary(text, pageStart, probeEnd);
      final painter = flowStyle.createPainter(
        spanBuilder(sourceOffset + pageStart, sourceOffset + probeEnd),
      )..layout(maxWidth: maxWidth);
      final metrics = painter.computeLineMetrics();
      final reachedTextEnd = probeEnd == text.length;
      final candidates = <int>[];
      var observedOverflowLine = false;

      for (var index = 0; index < metrics.length; index++) {
        final metric = metrics[index];
        final isArtificialProbeTail =
            !reachedTextEnd && index == metrics.length - 1;
        if (isArtificialProbeTail) break;
        final lineBottom = metric.baseline - metric.ascent + metric.height;
        if (lineBottom > maxHeight) {
          observedOverflowLine = true;
          break;
        }
        final samplePosition = painter.getPositionForOffset(
          Offset(
            metric.left + (metric.width / 2),
            metric.baseline - (metric.ascent / 2),
          ),
        );
        final boundary = painter.getLineBoundary(samplePosition);
        final end = pageStart + boundary.end;
        if (end > pageStart && (candidates.isEmpty || end > candidates.last)) {
          candidates.add(end);
        }
      }
      painter.dispose();

      if (candidates.isNotEmpty && (reachedTextEnd || observedOverflowLine)) {
        return candidates;
      }
      if (reachedTextEnd) {
        return candidates.isNotEmpty
            ? candidates
            : <int>[_nextCodePointBoundary(text, pageStart)];
      }
      probeLength = math.min(probeLength * 2, text.length - pageStart);
    }
  }

  NativeTextPageRange _selectVerifiedCandidate({
    required List<int> candidates,
    required int pageStart,
    required int sourceOffset,
    required NativeTextSpanBuilder spanBuilder,
  }) {
    for (var index = candidates.length - 1; index >= 0; index--) {
      final verified = _verifiedRange(
        pageStart: pageStart,
        pageEnd: candidates[index],
        sourceOffset: sourceOffset,
        spanBuilder: spanBuilder,
      );
      if (verified != null) return verified;
    }
    final fallbackEnd = candidates.isEmpty ? pageStart + 1 : candidates.first;
    return NativeTextPageRange(
      start: pageStart,
      end: fallbackEnd,
      lineCount: 1,
    );
  }

  NativeTextPageRange? _verifiedRange({
    required int pageStart,
    required int pageEnd,
    required int sourceOffset,
    required NativeTextSpanBuilder spanBuilder,
  }) {
    if (pageEnd <= pageStart) return null;
    final painter = flowStyle.createPainter(
      spanBuilder(sourceOffset + pageStart, sourceOffset + pageEnd),
    )..layout(maxWidth: maxWidth);
    final fits = painter.height <= maxHeight;
    final actualLineCount = painter.computeLineMetrics().length;
    painter.dispose();
    if (!fits) return null;
    return NativeTextPageRange(
      start: pageStart,
      end: pageEnd,
      lineCount: actualLineCount,
    );
  }
}

int _safeCodeUnitBoundary(String text, int start, int end) {
  if (end >= text.length) return text.length;
  if (end > start && _isLowSurrogate(text.codeUnitAt(end))) return end - 1;
  return end;
}

int _nextCodePointBoundary(String text, int start) {
  if (start >= text.length) return text.length;
  if (_isHighSurrogate(text.codeUnitAt(start)) && start + 1 < text.length) {
    return start + 2;
  }
  return start + 1;
}

bool _endsParagraph(String text, int end) {
  if (end <= 0) return true;
  final previous = text.codeUnitAt(end - 1);
  return previous == 0x0A || previous == 0x0D;
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

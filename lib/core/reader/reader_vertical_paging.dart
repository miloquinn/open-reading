import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'reader_safe_area.dart';

/// Fixed viewport chrome used by vertical paging.
///
/// The chapter label and page status belong to the viewport rather than to an
/// individual page. Text pagination must therefore use [contentTop] and
/// [contentBottom], so text never slides underneath either fixed slot.
@immutable
class ReaderViewportChromeMetrics {
  const ReaderViewportChromeMetrics({
    required this.safeArea,
    this.titleTopGap = 7,
    this.titleHeight = 16,
    this.titleContentGap = 9,
    this.statusContentGap = 6,
  });

  final ReaderSafeAreaMetrics safeArea;
  final double titleTopGap;
  final double titleHeight;
  final double titleContentGap;
  final double statusContentGap;

  double get titleTop => safeArea.viewPadding.top + titleTopGap;

  double get contentTop => math.max(
        safeArea.contentTop,
        titleTop + titleHeight + titleContentGap,
      );

  double get contentBottom => math.max(
        safeArea.contentBottom,
        safeArea.pageNumberBottom +
            ReaderSafeAreaMetrics.pageNumberReserve +
            statusContentGap,
      );

  double contentHeight(double viewportHeight) =>
      (viewportHeight - contentTop - contentBottom).clamp(1, viewportHeight);

  String get paginationSignature =>
      '${contentTop.toStringAsFixed(2)}:${contentBottom.toStringAsFixed(2)}';
}

/// Package-independent projection of an ItemPositionsListener entry.
@immutable
class ReaderVisibleItemPosition {
  const ReaderVisibleItemPosition({
    required this.index,
    required this.leadingEdge,
    required this.trailingEdge,
  });

  final int index;
  final double leadingEdge;
  final double trailingEdge;

  bool get containsViewportCenter => leadingEdge <= 0.5 && trailingEdge > 0.5;

  double get visibleFraction {
    final leading = leadingEdge.clamp(0.0, 1.0);
    final trailing = trailingEdge.clamp(0.0, 1.0);
    return math.max(0, trailing - leading);
  }

  double get centerDistance => (((leadingEdge + trailingEdge) / 2) - 0.5).abs();
}

/// Chooses the item that owns the viewport center. If the center lies in a
/// gap, the closest and then most-visible item wins.
ReaderVisibleItemPosition? pickPrimaryReaderItem(
  Iterable<ReaderVisibleItemPosition> positions,
) {
  final items = positions.toList(growable: false);
  if (items.isEmpty) return null;
  items.sort((a, b) {
    if (a.containsViewportCenter != b.containsViewportCenter) {
      return a.containsViewportCenter ? -1 : 1;
    }
    final distance = a.centerDistance.compareTo(b.centerDistance);
    if (distance != 0) return distance;
    return b.visibleFraction.compareTo(a.visibleFraction);
  });
  return items.first;
}

/// Resolves the page at the viewport center inside a chapter-sized list item.
///
/// A chapter item is composed of equal-height page cells. Item position edges
/// are expressed in viewport units, so dividing the item span by page count
/// yields the normalized extent of one page.
int readerPageIndexWithinItem(
  ReaderVisibleItemPosition position,
  int pageCount,
) {
  if (pageCount <= 1) return 0;
  final itemExtent = position.trailingEdge - position.leadingEdge;
  if (itemExtent <= 0) return 0;
  final pageExtent = itemExtent / pageCount;
  return ((0.5 - position.leadingEdge) / pageExtent)
      .floor()
      .clamp(0, pageCount - 1);
}

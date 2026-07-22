import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 阅读正文相对系统安全区的统一布局指标。
///
/// 系统 inset 与用户选择的阅读边距各司其职：顶部确保正文落在刘海/灵动岛
/// 下方。页码可以落在系统底部安全区内、但保持在 Home Indicator 上方；
/// 正文上下边距可以分别调整，且不会带动页码位置。
class ReaderSafeAreaMetrics {
  static const double pageNumberReserve = 12.0;
  static const double pageNumberGap = 4.0;
  static const double readerTopBarHeight = 16.0;
  static const double readerTopBarGap = 8.0;
  static const double readerTopBarReserve =
      readerTopBarHeight + readerTopBarGap;
  static const double _pageNumberSafeAreaOverlap = 20.0;
  static const double _minimumPageNumberBottom = 8.0;

  final EdgeInsets viewPadding;
  final double topMargin;
  final double bottomMargin;
  final double topChromeReserve;

  const ReaderSafeAreaMetrics({
    required this.viewPadding,
    required this.topMargin,
    required this.bottomMargin,
    this.topChromeReserve = 0,
  });

  double get contentTop => viewPadding.top + topChromeReserve + topMargin;

  double get readerTopBarTop => viewPadding.top + 4;

  double get pageNumberBottom => math.max(
    _minimumPageNumberBottom,
    viewPadding.bottom - _pageNumberSafeAreaOverlap,
  );

  double get contentBottom => math.max(
    viewPadding.bottom + bottomMargin,
    pageNumberBottom + pageNumberReserve + pageNumberGap,
  );

  String get paginationSignature =>
      '${contentTop.toStringAsFixed(2)}:${contentBottom.toStringAsFixed(2)}:'
      '${topChromeReserve.toStringAsFixed(2)}';
}

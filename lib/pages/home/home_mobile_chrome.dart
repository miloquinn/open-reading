// 文件说明：首页响应式布局常量文件，统一定义间距、断点和尺寸策略。
// 技术要点：Flutter UI。

import 'package:flutter/widgets.dart';

/// 首页布局公共常量。
///
/// 目的：
/// 1) 避免魔法数字散落在多个页面文件
/// 2) 让 HomeShell 与移动端首页内容页共享同一套尺寸基准
/// 3) 后续改动时只改这一处
const double kHomeMobileTopBarContentHeight = 60.0;
const double kHomeMobileFloatingNavHeight = 56.0;
const double kHomeMobileFloatingNavBottomGap = 10.0;
const double kHomeMobileFloatingNavScreenGap = 36.0;
const double kHomeMobileFloatingNavHorizontalPadding = 4.0;
const double kHomeMobileFloatingNavDesiredItemWidth = 90.0;
const double kHomeMobileFloatingNavExtraWidth = 8.0;
const double kHomeMobileContentTopExtra = 8.0;
const double kHomeMobileContentBottomExtra = 10.0;
const double kHomeMobileFloatingActionExtra = 15.0;

double homeMobileFloatingNavWidthFor({
  required double screenWidth,
  required int itemCount,
}) {
  if (screenWidth <= 0 || itemCount <= 0) return 0;
  final desiredWidth =
      itemCount * kHomeMobileFloatingNavDesiredItemWidth +
      kHomeMobileFloatingNavExtraWidth;
  final maxWidth = (screenWidth - kHomeMobileFloatingNavScreenGap)
      .clamp(0.0, double.infinity)
      .toDouble();
  final minWidth = itemCount >= 4 ? 280.0 : 220.0;
  if (maxWidth <= minWidth) return maxWidth;
  return desiredWidth.clamp(minWidth, maxWidth).toDouble();
}

double homeMobileFloatingNavItemWidthFor({
  required double screenWidth,
  required int itemCount,
}) {
  if (itemCount <= 0) return 0;
  final contentWidth =
      homeMobileFloatingNavWidthFor(
        screenWidth: screenWidth,
        itemCount: itemCount,
      ) -
      (kHomeMobileFloatingNavHorizontalPadding * 2);
  return (contentWidth / itemCount).clamp(0.0, double.infinity).toDouble();
}

/// 手机壳层的统一安全区与浮动控件尺寸。
///
/// 系统安全区始终来自 [MediaQueryData.viewPadding]，这样键盘弹出时不会
/// 改变 Home Indicator / Dynamic Island 的真实占位，也不需要按平台或机型分支。
class HomeMobileChromeMetrics {
  final double systemTopInset;
  final double systemBottomInset;
  final double topBarContentHeight;
  final double floatingNavHeight;

  const HomeMobileChromeMetrics({
    required this.systemTopInset,
    required this.systemBottomInset,
    this.topBarContentHeight = kHomeMobileTopBarContentHeight,
    this.floatingNavHeight = kHomeMobileFloatingNavHeight,
  });

  factory HomeMobileChromeMetrics.fromMediaQuery(
    MediaQueryData mediaQuery, {
    EdgeInsets? systemInsets,
  }) {
    final resolvedInsets = systemInsets ?? mediaQuery.viewPadding;
    return HomeMobileChromeMetrics(
      systemTopInset: resolvedInsets.top,
      systemBottomInset: resolvedInsets.bottom,
    );
  }

  double get topBarHeight => systemTopInset + topBarContentHeight;

  double get pageTopPadding => topBarHeight + kHomeMobileContentTopExtra;

  double get navBottomInset =>
      systemBottomInset + kHomeMobileFloatingNavBottomGap;

  double get navContainerHeight => floatingNavHeight + navBottomInset;

  double get pageBottomPadding =>
      navContainerHeight + kHomeMobileContentBottomExtra;

  double get floatingActionBottomMargin =>
      navContainerHeight + kHomeMobileFloatingActionExtra;
}

/// 阅读器沉浸模式会暂时隐藏 Android 系统栏；预测性返回起步后，系统又可能
/// 把手势提示区域作为新的 viewPadding 突然上报。首页此时正在底层参与转场，
/// 如果直接采用这次变化，悬浮导航会在回弹途中整体跳高。
///
/// 因此阅读活动存活期间沿用进入阅读器前最后一次稳定的系统安全区，等阅读
/// 活动释放后再接受新的真实值；普通首页状态仍会实时响应系统配置变化。
class HomeMobileSystemInsetsStabilizer {
  EdgeInsets? _stableInsets;

  EdgeInsets resolve(
    MediaQueryData mediaQuery, {
    required bool lockForReaderTransition,
  }) {
    final observedInsets = EdgeInsets.only(
      top: mediaQuery.viewPadding.top,
      bottom: mediaQuery.viewPadding.bottom,
    );
    if (!lockForReaderTransition || _stableInsets == null) {
      _stableInsets = observedInsets;
    }
    return _stableInsets!;
  }
}

/// 将 HomeShell 计算出的同一份安全区指标提供给所有手机 tab 页面。
class HomeMobileChromeScope extends InheritedWidget {
  final HomeMobileChromeMetrics metrics;

  const HomeMobileChromeScope({
    super.key,
    required this.metrics,
    required super.child,
  });

  static HomeMobileChromeMetrics of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<HomeMobileChromeScope>()
            ?.metrics ??
        HomeMobileChromeMetrics.fromMediaQuery(MediaQuery.of(context));
  }

  @override
  bool updateShouldNotify(HomeMobileChromeScope oldWidget) {
    return oldWidget.metrics.systemTopInset != metrics.systemTopInset ||
        oldWidget.metrics.systemBottomInset != metrics.systemBottomInset ||
        oldWidget.metrics.topBarContentHeight != metrics.topBarContentHeight ||
        oldWidget.metrics.floatingNavHeight != metrics.floatingNavHeight;
  }
}

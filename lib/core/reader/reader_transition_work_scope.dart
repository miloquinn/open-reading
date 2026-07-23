// 文件说明：向阅读器子树传递路由转场期间是否允许执行高成本工作。
// 技术要点：独立于 Flutter 路由内部的 TickerMode，避免嵌套作用域覆盖暂停信号。

import 'package:flutter/widgets.dart';

class ReaderTransitionWorkScope extends InheritedWidget {
  const ReaderTransitionWorkScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool enabledOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ReaderTransitionWorkScope>()
            ?.enabled ??
        true;
  }

  @override
  bool updateShouldNotify(ReaderTransitionWorkScope oldWidget) {
    return enabled != oldWidget.enabled;
  }
}

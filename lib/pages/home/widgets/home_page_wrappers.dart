// 文件说明：首页相关页面包装组件，统一处理 KeepAlive、样式和系统栏。
// 技术要点：Flutter UI。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:xxread/models/home_navigation_destination.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/utils/system_ui_helper.dart';

import 'home_mobile_top_bar.dart';

/// 通用背景包装器：给普通页面加统一首页背景。
class HomeGenericPageWrapper extends StatelessWidget {
  final Widget child;

  const HomeGenericPageWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: PageStyleHelper.backgroundGradient(context),
      ),
      child: child,
    );
  }
}

/// 设置页专用包装器：负责系统栏样式和顶栏叠加。
class HomeSettingsPageWrapper extends StatefulWidget {
  final Widget child;
  final String topBarTitle;

  const HomeSettingsPageWrapper({
    super.key,
    required this.child,
    required this.topBarTitle,
  });

  @override
  State<HomeSettingsPageWrapper> createState() =>
      _HomeSettingsPageWrapperState();
}

class _HomeSettingsPageWrapperState extends State<HomeSettingsPageWrapper> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applySettingsPageSystemUI();
  }

  bool _shouldApplySystemUI() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  void _applySettingsPageSystemUI() {
    if (!_shouldApplySystemUI()) {
      return;
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    final overlayStyle = SystemUiHelper.overlayStyleForBrightness(
      Theme.of(context).brightness,
    );
    Future.microtask(() {
      if (!mounted) return;
      SystemChrome.setSystemUIOverlayStyle(overlayStyle);
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _shouldApplySystemUI()) {
        _applySettingsPageSystemUI();
      }
    });

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: HomeMobileTopBar(title: widget.topBarTitle),
        ),
      ],
    );
  }
}

/// 向 PageView 子树广播当前激活的导航目的地，供 [HomeTabFocusGate] 判断。
class HomeTabFocusScope extends InheritedWidget {
  final HomeNavigationDestination activeDestination;

  const HomeTabFocusScope({
    super.key,
    required this.activeDestination,
    required super.child,
  });

  static HomeNavigationDestination? maybeActiveOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HomeTabFocusScope>()
        ?.activeDestination;
  }

  @override
  bool updateShouldNotify(HomeTabFocusScope oldWidget) =>
      activeDestination != oldWidget.activeDestination;
}

/// 首页 tab 焦点闸门：非当前 tab 的页面子树不允许持有焦点。
///
/// PageView 预构建 + KeepAlive 的相邻页里若有输入框残留焦点（如 AI 聊天
/// 输入框），上层路由（阅读器、对话框）关闭时框架会把焦点还给它；输入框
/// 随后的 showCaretOnScreen 会顺着视口链把整个 PageView 拽向那个 tab，
/// 表现为返回动画在别的 tab 上来回抽搐。切走 tab 即释放焦点、收起键盘。
class HomeTabFocusGate extends StatelessWidget {
  final HomeNavigationDestination destination;
  final Widget child;

  const HomeTabFocusGate({
    super.key,
    required this.destination,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final active = HomeTabFocusScope.maybeActiveOf(context);
    return ExcludeFocus(
      key: ValueKey('home-tab-focus-gate-${destination.storageId}'),
      excluding: active != null && active != destination,
      child: child,
    );
  }
}

/// 保持页面状态，避免 tab 切换导致页面重建。
class HomeKeepAlivePageWrapper extends StatefulWidget {
  final Widget child;

  const HomeKeepAlivePageWrapper({super.key, required this.child});

  @override
  State<HomeKeepAlivePageWrapper> createState() =>
      _HomeKeepAlivePageWrapperState();
}

class _HomeKeepAlivePageWrapperState extends State<HomeKeepAlivePageWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// 文件说明：首页相关页面包装组件，统一处理 KeepAlive、样式和系统栏。
// 技术要点：Flutter UI。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

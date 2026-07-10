// 文件说明：首页壳层页面，负责底部导航、页面装配和桌面/移动端切换。
// 技术要点：Flutter UI、渲染层。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import 'home_dashboard_page.dart';
import 'home_layout_constants.dart';
import 'home_mobile_dashboard_page.dart';
import 'home_widgets/home_bounce_navigation_item.dart';
import 'home_widgets/home_navigation_item.dart';
import 'home_widgets/home_page_wrappers.dart';
import 'home_widgets/home_mobile_top_bar_widget.dart';
import 'library_page.dart';
import 'settings_page.dart';
import 'import_book_page.dart';
import '../utils/layout_helper.dart';
import '../utils/glass_config.dart';
import '../utils/page_style_helper.dart';
import '../utils/system_ui_helper.dart';
import '../utils/localization_extension.dart';
import '../utils/ui_style.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_brand_icon.dart';

part 'home_shell_layout_part.dart';

/// ============================================================================
/// 首页容器架构说明（先看这里，再读代码）
///
/// 1) HomeShellPage 只负责「导航壳」：
///    - 手机：底部药丸导航 + PageView
///    - 平板/桌面：NavigationRail + 内容区
///
/// 2) 真正的手机首页内容由 HomeMobileDashboardPage 渲染：
///    - 顶部毛玻璃标题栏
///    - 统计卡片 / 图表 / 最近阅读
///
/// 3) _buildPageWrapper 是关键路由：
///    - 首页 -> HomeMobileDashboardPage
///    - 设置页 -> HomeSettingsPageWrapper
///    - 其他页 -> HomeGenericPageWrapper
///
/// 4) 这个文件优先保证“结构稳定”：
///    - 统一布局常量
///    - 统一安全区计算
///    - 统一顶栏构建逻辑
/// ============================================================================

/// 手机底部导航布局计算结果。
/// 把原来散落的公式收口在一个结构里，后续改尺寸更安全。
class _BottomNavMetrics {
  final double safeBottom;
  final double navBottomInset;
  final double navContainerHeight;

  const _BottomNavMetrics({
    required this.safeBottom,
    required this.navBottomInset,
    required this.navContainerHeight,
  });
}

/// 导航上下文 - 用于通知子页面是否在侧边导航栏模式下
class NavigationContext extends InheritedWidget {
  final bool useRailNavigation;

  const NavigationContext({
    super.key,
    required this.useRailNavigation,
    required super.child,
  });

  static NavigationContext? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NavigationContext>();
  }

  @override
  bool updateShouldNotify(NavigationContext oldWidget) =>
      useRailNavigation != oldWidget.useRailNavigation;
}

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  // 当前选中的导航索引（首页=0，书库=1，...）。
  // 所有导航点击、PageView 切换，最终都更新这个值。
  int _selectedIndex = 0;
  late PageController _pageController;
  AppLocalizations? _l10n;

  // 导航项单一数据源：
  // - 底部导航（手机）和侧边栏（平板/桌面）都读这里。
  List<HomeNavigationItem> _navigationItems = [];

  @override
  void initState() {
    super.initState();
    _initializeNavigationItems();
    // 优化PageController，设置合适的视窗比例
    _pageController = PageController(
      viewportFraction: 1.0, // 保持全屏显示
      keepPage: true, // 保持页面状态
    );
  }

  /// 组装导航项列表（可看作“首页路由表”）。
  ///
  /// 规则：
  /// 1) 首页、书库固定在前。
  /// 2) 设置固定在最后。
  void _initializeNavigationItems() {
    final l10n = _l10n;
    final items = <HomeNavigationItem>[
      HomeNavigationItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l10n?.home ?? 'Home',
        page: const HomeDashboardPage(),
      ),
      HomeNavigationItem(
        icon: Icons.library_books_outlined,
        selectedIcon: Icons.library_books,
        label: l10n?.library ?? 'Library',
        page: const LibraryPage(),
      ),
      HomeNavigationItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: l10n?.settings ?? 'Settings',
        page: const SettingsPage(),
      ),
    ];

    setState(() {
      _navigationItems = items;
      // 如果当前选中的索引超出范围，重置为首页
      if (_selectedIndex >= _navigationItems.length) {
        _selectedIndex = 0;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context);
    // 每次依赖变化时重新应用沉浸式设置
    _setupPageImmersiveMode();
    // 应用基于主题的设置
    _setupThemeBasedImmersiveMode();
    _initializeNavigationItems();
  }

  void _updateSelectedIndex(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigationType = LayoutHelper.getNavigationType(context);
    final overlayStyle = SystemUiHelper.overlayStyleForBrightness(
      Theme.of(context).brightness,
    );

    // 某些页面(如阅读器)会临时修改系统栏样式，返回后这里强制恢复当前主题对应的样式。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setupThemeBasedImmersiveMode();
    });

    Widget content;
    switch (navigationType) {
      case NavigationType.rail:
        content = _buildNavigationRail();
        break;
      case NavigationType.bottom:
        content = _buildBottomNavigation();
        break;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: content,
    );
  }
}

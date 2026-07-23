// 文件说明：首页壳层页面，负责底部导航、页面装配和桌面/移动端切换。
// 技术要点：Flutter UI、渲染层。

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_registry.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/home_navigation_destination.dart';
import 'package:xxread/pages/book_sources/book_source_management_page.dart';
import 'package:xxread/pages/book_sources/book_sources_page.dart';
import 'package:xxread/pages/book_sources/source_search_page.dart';
import 'package:xxread/pages/library/import_book/import_book_page.dart';
import 'package:xxread/pages/library/library_page.dart';
import 'package:xxread/pages/library/download_tasks_page.dart';
import 'package:xxread/pages/settings/settings_page.dart';
import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/services/core/first_home_support_intro_service.dart';
import 'package:xxread/services/library/download_task_controller.dart';
import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/glass_config.dart';
import 'package:xxread/utils/layout_helper.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/utils/ui_style.dart';
import 'package:xxread/widgets/app_brand_icon.dart';
import 'package:xxread/widgets/first_home_support_overlay.dart';

import 'home_dashboard_page.dart';
import 'home_mobile_chrome.dart';
import 'home_mobile_dashboard_page.dart';
import 'widgets/home_bounce_navigation_item.dart';
import 'widgets/home_mobile_top_bar.dart';
import 'widgets/home_navigation_item.dart';
import 'widgets/home_page_wrappers.dart';

part 'parts/home_shell_layout_part.dart';

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
  const HomeShellPage({super.key, this.showFirstHomeSupport = false});

  final bool showFirstHomeSupport;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  // 当前选中的导航索引（首页=0，书库=1，...）。
  // 所有导航点击、PageView 切换，最终都更新这个值。
  int _selectedIndex = 0;
  int? _targetTabIndex;
  int _tabTransitionToken = 0;
  late PageController _pageController;
  final HomeDashboardController _homeDashboardController =
      HomeDashboardController();
  final SettingsPageController _settingsController = SettingsPageController();
  AppLocalizations? _l10n;
  final LibraryPageController _libraryController = LibraryPageController();

  // 导航项单一数据源：
  // - 底部导航（手机）和侧边栏（平板/桌面）都读这里。
  List<HomeNavigationItem> _navigationItems = [];
  List<HomeNavigationDestination> _navigationOrder = defaultHomeNavigationOrder;
  List<Widget> _mobilePages = const [];
  int? _pendingPageControllerIndex;
  bool _pageControllerSyncScheduled = false;
  bool _supportIntroCheckStarted = false;
  bool _showSupportIntro = false;
  final HomeMobileSystemInsetsStabilizer _mobileSystemInsets =
      HomeMobileSystemInsetsStabilizer();

  @override
  void initState() {
    super.initState();
    // 优化PageController，设置合适的视窗比例
    _pageController = PageController(
      viewportFraction: 1.0, // 保持全屏显示
      keepPage: true, // 保持页面状态
    );
    unawaited(_maybeShowFirstHomeSupport());
  }

  @override
  void didUpdateWidget(covariant HomeShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.showFirstHomeSupport && widget.showFirstHomeSupport) {
      unawaited(_maybeShowFirstHomeSupport());
    }
  }

  Future<void> _maybeShowFirstHomeSupport() async {
    if (_supportIntroCheckStarted || !widget.showFirstHomeSupport) return;
    _supportIntroCheckStarted = true;
    final shouldShow = await const FirstHomeSupportIntroService()
        .claimIfUnseen();
    if (!shouldShow) return;
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() => _showSupportIntro = true);
  }

  /// 组装导航项列表（可看作“首页路由表”）。
  ///
  /// 规则：
  /// 1) 稳定目的地 ID 决定页面身份，本地化标题不参与持久化。
  /// 2) 用户顺序同时驱动手机 PageView、悬浮栏和宽屏 NavigationRail。
  /// 3) 重排后按目的地恢复当前页，不能沿用旧索引跳到其他页面。
  void _initializeNavigationItems(
    List<HomeNavigationDestination> navigationOrder,
  ) {
    final l10n = _l10n;
    if (l10n == null) return;
    final selectedDestination = _navigationItems.isEmpty
        ? HomeNavigationDestination.home
        : _navigationItems[(_targetTabIndex ?? _selectedIndex).clamp(
                0,
                _navigationItems.length - 1,
              )]
              .destination;
    final itemsByDestination = <HomeNavigationDestination, HomeNavigationItem>{
      HomeNavigationDestination.home: HomeNavigationItem(
        destination: HomeNavigationDestination.home,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l10n.home,
        page: HomeDashboardPage(controller: _homeDashboardController),
      ),
      HomeNavigationDestination.library: HomeNavigationItem(
        destination: HomeNavigationDestination.library,
        icon: Icons.library_books_outlined,
        selectedIcon: Icons.library_books,
        label: l10n.library,
        page: LibraryPage(controller: _libraryController),
      ),
      HomeNavigationDestination.discover: HomeNavigationItem(
        destination: HomeNavigationDestination.discover,
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
        label: l10n.discover,
        page: const BookSourcesPage(),
      ),
      HomeNavigationDestination.settings: HomeNavigationItem(
        destination: HomeNavigationDestination.settings,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: l10n.settings,
        page: SettingsPage(controller: _settingsController),
      ),
    };
    final items = navigationOrder
        .map((destination) => itemsByDestination[destination]!)
        .toList(growable: false);

    _navigationItems = items;
    _navigationOrder = List<HomeNavigationDestination>.unmodifiable(
      navigationOrder,
    );
    _mobilePages = items
        .map(
          (item) => RepaintBoundary(
            key: ValueKey('home-page-${item.destination.storageId}'),
            child: _buildPageWrapper(item.page),
          ),
        )
        .toList(growable: false);
    _selectedIndex = items.indexWhere(
      (item) => item.destination == selectedDestination,
    );
    if (_selectedIndex < 0) _selectedIndex = 0;
    _targetTabIndex = null;
    _tabTransitionToken += 1;
    _queuePageControllerSync(_selectedIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextL10n = AppLocalizations.of(context);
    final nextNavigationOrder = context
        .watch<AppSettingsNotifier>()
        .homeNavigationOrder;
    // 每次依赖变化时重新应用沉浸式设置
    _setupPageImmersiveMode();
    // 应用基于主题的设置
    _setupThemeBasedImmersiveMode();
    // 仅在本地化实例变化时重建页面表。普通 tab setState 不再重新创建
    // PageView 的整组子节点，避免切页动画开始前产生额外布局工作。
    if (_l10n != nextL10n ||
        _navigationItems.isEmpty ||
        !listEquals(_navigationOrder, nextNavigationOrder)) {
      _l10n = nextL10n;
      _initializeNavigationItems(nextNavigationOrder);
    }
  }

  void _updateSelectedIndex(int index) {
    if (!mounted) return;
    final destinationChanged = _selectedIndex != index;
    final pageControllerDetached = !_pageController.hasClients;
    if (pageControllerDetached) {
      _pendingPageControllerIndex = index;
      _tabTransitionToken += 1;
    }
    setState(() {
      _selectedIndex = index;
      if (pageControllerDetached) _targetTabIndex = null;
    });
    if (destinationChanged) _scheduleHomeRefresh(index);
  }

  void _queuePageControllerSync(int index) {
    _pendingPageControllerIndex = index;
    _schedulePageControllerSync();
  }

  void _schedulePageControllerSync() {
    if (_pageControllerSyncScheduled || _pendingPageControllerIndex == null) {
      return;
    }
    _pageControllerSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageControllerSyncScheduled = false;
      if (!mounted || !_pageController.hasClients) return;
      final targetIndex = _pendingPageControllerIndex;
      if (targetIndex == null ||
          targetIndex < 0 ||
          targetIndex >= _navigationItems.length) {
        _pendingPageControllerIndex = null;
        return;
      }
      final currentPage = _pageController.page;
      if (currentPage == null || (currentPage - targetIndex).abs() > 0.001) {
        _pageController.jumpToPage(targetIndex);
      }
      if (_pendingPageControllerIndex == targetIndex) {
        _pendingPageControllerIndex = null;
      }
    });
  }

  void _beginTabTransition(int index) {
    if (!mounted) return;
    setState(() => _targetTabIndex = index);
  }

  void _completeTabTransition(int index) {
    if (!mounted) return;
    final destinationChanged =
        _selectedIndex != index || _targetTabIndex != null;
    setState(() {
      _selectedIndex = index;
      _targetTabIndex = null;
    });
    if (destinationChanged) _scheduleHomeRefresh(index);
  }

  void _scheduleHomeRefresh(int index) {
    if (index < 0 || index >= _navigationItems.length) return;
    if (_navigationItems[index].destination != HomeNavigationDestination.home) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navigationItems.isEmpty) return;
      final selectedIndex = _selectedIndex.clamp(
        0,
        _navigationItems.length - 1,
      );
      if (_navigationItems[selectedIndex].destination ==
          HomeNavigationDestination.home) {
        _homeDashboardController.refresh();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _homeDashboardController.dispose();
    _settingsController.dispose();
    _libraryController.dispose();
    super.dispose();
  }

  void _dismissFirstHomeSupport() {
    if (!mounted) return;
    setState(() => _showSupportIntro = false);
  }

  Future<void> _openSupportSettings() async {
    _dismissFirstHomeSupport();
    final settingsIndex = _navigationItems.indexWhere(
      (item) => item.page is SettingsPage,
    );
    if (settingsIndex < 0) return;

    if (LayoutHelper.getNavigationType(context) == NavigationType.rail) {
      _updateSelectedIndex(settingsIndex);
      await _waitForNextFrame();
    } else {
      await _switchToTab(settingsIndex);
    }
    if (!mounted) return;
    _settingsController.revealSupportSection();
  }

  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final navigationType = LayoutHelper.getNavigationType(context);
    final hideNavigationLabels = context.select<AppSettingsNotifier, bool>(
      (settings) => settings.hideNavigationLabels,
    );
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
        _schedulePageControllerSync();
        content = _buildBottomNavigation(
          showNavigationLabels: !hideNavigationLabels,
        );
        break;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Stack(
        children: [
          Positioned.fill(child: content),
          if (_showSupportIntro)
            Positioned.fill(
              child: FirstHomeSupportOverlay(
                supportLabel: context.l10n.firstHomeSupportNow,
                laterLabel: context.l10n.firstHomeSupportLater,
                paperSemanticLabel:
                    context.l10n.firstHomeSupportPaperSemanticLabel,
                onSupport: () => unawaited(_openSupportSettings()),
                onLater: _dismissFirstHomeSupport,
              ),
            ),
        ],
      ),
    );
  }
}

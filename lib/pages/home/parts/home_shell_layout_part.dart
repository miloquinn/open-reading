// 文件说明：首页壳层的 part 拆分文件，承载导航布局和系统栏相关实现。
// 技术要点：Flutter UI、Dart part。

part of '../home_shell_page.dart';

/// 首页壳层的大块布局方法拆分到这里：
/// - 系统栏沉浸式设置
/// - Rail 布局
/// - 手机底部导航布局
/// - 页面包装与导入跳转
extension _HomeShellLayoutPart on _HomeShellPageState {
  bool _shouldApplySystemUI() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  bool get _isMaterial3Style {
    return Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
  }

  bool get _disableShellBlur =>
      _isMaterial3Style || GlassEffectConfig.shouldDisableBlur;

  // 页面级沉浸式设置
  void _setupPageImmersiveMode() {
    if (!_shouldApplySystemUI()) {
      return;
    }
    // 强制启用边到边模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // 初始样式跟随当前主题亮度
    final overlayStyle = SystemUiHelper.overlayStyleForBrightness(
      Theme.of(context).brightness,
    );
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);
  }

  // 基于主题的沉浸式设置 (在didChangeDependencies中调用)
  void _setupThemeBasedImmersiveMode() {
    if (!_shouldApplySystemUI()) {
      return;
    }
    final overlayStyle = SystemUiHelper.overlayStyleForBrightness(
      Theme.of(context).brightness,
    );

    // 使用 microtask 确保在当前帧渲染后执行
    Future.microtask(() {
      if (!mounted) return;
      SystemChrome.setSystemUIOverlayStyle(overlayStyle);
    });
  }

  /// 平板/桌面布局：左侧 NavigationRail + 右侧页面内容。
  ///
  /// 说明：
  /// - 这里不走 PageView，因为宽屏更适合“立刻切页”的应用范式。
  /// - 右侧直接渲染当前 index 对应页面，结构更直观。
  Widget _buildNavigationRail() {
    final scheme = Theme.of(context).colorScheme;
    final palette = PageStyleHelper.palette(context);
    final currentPage = _navigationItems[_selectedIndex].page;
    final showImportAction =
        currentPage is HomeDashboardPage || currentPage is LibraryPage;
    final railPanel = Container(
      width: LayoutHelper.getValue(
        context,
        mobile: 80, // 不会用到，但保持一致性
        tablet: 200, // 平板使用中等宽度
        desktop: 250, // 桌面使用最大宽度
      ),
      decoration: BoxDecoration(
        color: _isMaterial3Style
            ? scheme.surfaceContainerLow
            : GlassEffectConfig.surfaceColor(
                context,
                opacity: 0.8,
              ),
        border: Border(
          right: BorderSide(
            color: scheme.outline
                .withValues(alpha: _isMaterial3Style ? 0.24 : 0.2),
            width: 1,
          ),
        ),
      ),
      child: NavigationRail(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _updateSelectedIndex,
        extended: LayoutHelper.getValue(
          context,
          mobile: false,
          tablet: true, // 平板显示扩展导航，方便使用
          desktop: true, // 桌面也显示扩展导航
        ),
        labelType: LayoutHelper.getValue(
          context,
          mobile: NavigationRailLabelType.all,
          tablet: NavigationRailLabelType.none, // 平板使用扩展模式，不需要额外标签
          desktop: NavigationRailLabelType.none, // 桌面同样
        ),
        leading: LayoutHelper.isWideScreen(context)
            ? _buildNavigationHeader()
            : null,
        minWidth: 60,
        minExtendedWidth: LayoutHelper.getValue(
          context,
          mobile: 200,
          tablet: 200,
          desktop: 250,
        ),
        backgroundColor: Colors.transparent,
        indicatorColor:
            scheme.primary.withValues(alpha: _isMaterial3Style ? 0.18 : 0.2),
        selectedIconTheme: IconThemeData(
          color: scheme.primary,
        ),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurface.withValues(alpha: 0.6),
        ),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w500,
        ),
        destinations: _navigationItems
            .map(
              (item) => NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: Text(item.label),
              ),
            )
            .toList(),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: Row(
          children: [
            ClipRRect(
              child: _disableShellBlur
                  ? railPanel
                  : BackdropFilter(
                      enabled: !_disableShellBlur,
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: railPanel,
                    ),
            ),
            Expanded(
              child: NavigationContext(
                useRailNavigation: true,
                child: _resolveRailPage(_navigationItems[_selectedIndex].page),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: showImportAction
          ? (_isMaterial3Style
              ? FloatingActionButton.extended(
                  onPressed: () => _navigateToImport(),
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  elevation: 2,
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.importBooks),
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: palette.backgroundStart.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      enabled: !_disableShellBlur,
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: FloatingActionButton.extended(
                        onPressed: () => _navigateToImport(),
                        backgroundColor: scheme.primary.withValues(
                          alpha: GlassEffectConfig.effectiveOpacity(0.9),
                        ),
                        foregroundColor: scheme.onPrimary,
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.importBooks),
                      ),
                    ),
                  ),
                ))
          : null,
    );
  }

  /// 手机布局：PageView + 底部悬浮药丸导航。
  ///
  /// 说明：
  /// - PageView 负责横向切页手势。
  /// - 药丸导航负责显式点击切页。
  /// - 两者通过 `_selectedIndex` + `_pageController` 保持同步。
  Widget _buildBottomNavigation({required bool showNavigationLabels}) {
    final mediaQuery = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isLightTheme = scheme.brightness == Brightness.light;
    final metrics = HomeMobileChromeMetrics.fromMediaQuery(mediaQuery);
    final navigationCount = _navigationItems.length;
    final navWidth = homeMobileFloatingNavWidthFor(
      screenWidth: mediaQuery.size.width,
      itemCount: navigationCount,
    );
    final visualSelectedIndex = _targetTabIndex ?? _selectedIndex;
    final navBorderRadius = BorderRadius.circular(
      metrics.floatingNavHeight / 2,
    );

    return Scaffold(
      extendBody: true, // 让body延伸到底部导航栏后面
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // 使用与书库页面完全相同的设置 - 完全透明且高度为0
        backgroundColor:
            _isMaterial3Style ? scheme.surface : Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // 设置高度为0，让毛玻璃标题栏在body中实现
        surfaceTintColor:
            _isMaterial3Style ? scheme.surface : Colors.transparent,
        systemOverlayStyle: SystemUiHelper.overlayStyleForBrightness(
          Theme.of(context).brightness,
        ),
      ),
      body: HomeMobileChromeScope(
        metrics: metrics,
        child: Stack(
          children: [
            // 主内容 - 优化的PageView，减少卡顿
            PageView(
              controller: _pageController,
              // 预构建相邻页面，避免首次滑动时页面构建/数据加载挤在动画帧里造成掉帧
              allowImplicitScrolling: true,
              onPageChanged: (index) {
                // animateToPage 跨两页时会先经过中间页。程序化切换期间忽略
                // 这个中间回调，避免底部导航出现“首页 -> 书库 -> 设置”的闪跳。
                final targetIndex = _targetTabIndex;
                if (targetIndex != null && index != targetIndex) {
                  return;
                }
                if (targetIndex == index) {
                  _completeTabTransition(index);
                  return;
                }
                if (mounted && _selectedIndex != index) {
                  _updateSelectedIndex(index);
                }
              },
              // PageScrollPhysics 保留整页吸附，同时减少 Bouncing 在页面落位时
              // 额外的回弹帧，让三页之间的切换更干净。
              physics: const PageScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              // 禁用页面捕捉以减少卡顿
              pageSnapping: true,
              children: _mobilePages,
            ),
            _buildMobileTopBarOverlay(),
            // 悬浮药丸导航栏（RepaintBoundary 隔离：避免 PageView 滑动时
            // 连带重绘毛玻璃导航栏，降低切页动画的每帧绘制成本）
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RepaintBoundary(
                child: SizedBox(
                  height: metrics.navContainerHeight,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: metrics.navBottomInset),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: navBorderRadius,
                          boxShadow: [
                            BoxShadow(
                              color: _isMaterial3Style
                                  ? scheme.shadow.withValues(alpha: 0.1)
                                  : GlassEffectConfig.chromeShadowColor(
                                      source: scheme.shadow,
                                      brightness: scheme.brightness,
                                      darkOpacity: 0.16,
                                    ),
                              blurRadius: _isMaterial3Style
                                  ? 18
                                  : (isLightTheme ? 24 : 32),
                              offset: const Offset(0, 9),
                            ),
                            if (!_isMaterial3Style && !isLightTheme)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 48,
                                offset: const Offset(0, 16),
                              ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: navBorderRadius,
                          child: (() {
                            final navBar = Container(
                              width: navWidth,
                              height: metrics.floatingNavHeight,
                              padding: const EdgeInsets.symmetric(
                                horizontal:
                                    kHomeMobileFloatingNavHorizontalPadding,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _isMaterial3Style
                                    ? scheme.surfaceContainerHigh
                                    : GlassEffectConfig.chromeSurfaceColor(
                                        context),
                                borderRadius: navBorderRadius,
                                border: Border.all(
                                  color: scheme.outline.withValues(
                                    alpha: _isMaterial3Style
                                        ? 0.18
                                        : (isLightTheme ? 0.08 : 0.14),
                                  ),
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: _navigationItems.asMap().entries.map(
                                  (entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    final isSelected =
                                        visualSelectedIndex == index;

                                    return Expanded(
                                      child: HomeBounceNavigationItem(
                                        item: item,
                                        isSelected: isSelected,
                                        showLabel: showNavigationLabels,
                                        onTap: () => _switchToTab(index),
                                      ),
                                    );
                                  },
                                ).toList(),
                              ),
                            );

                            if (_disableShellBlur) {
                              return navBar;
                            }
                            return BackdropFilter(
                              enabled: !_disableShellBlur,
                              filter: ImageFilter.blur(
                                sigmaX: GlassEffectConfig.navigationBarBlur,
                                sigmaY: GlassEffectConfig.navigationBarBlur,
                              ),
                              child: navBar,
                            );
                          })(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTopBarOverlay() {
    if (_navigationItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentItem = _navigationItems[_selectedIndex];
    final currentPage = currentItem.page;
    final title = currentItem.label;
    Widget? trailing;

    if (currentPage is HomeDashboardPage) {
      final settingsIndex = _navigationItems.indexWhere(
        (item) => item.page is SettingsPage,
      );
      if (settingsIndex >= 0) {
        trailing = _buildTopBarActionButton(
          icon: Icons.settings_outlined,
          onTap: () => _switchToTab(settingsIndex),
        );
      }
    } else if (currentPage is LibraryPage) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopBarActionButton(
            icon: Icons.search_rounded,
            tooltip: context.l10n.bookSourcesSearch,
            onTap: _libraryController.toggleSearch,
          ),
          const SizedBox(width: 8),
          _buildTopBarActionButton(
            icon: Icons.downloading_rounded,
            tooltip: context.l10n.downloadTasksTitle,
            highlighted:
                context.watch<DownloadTaskController?>()?.hasActiveTasks ??
                    false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DownloadTasksPage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: _libraryController.filterActive,
            builder: (context, active, _) => _LibraryTopBarFilterButton(
              active: active,
              buildButton: ({
                required IconData icon,
                required VoidCallback onTap,
                String? tooltip,
                bool highlighted = false,
              }) =>
                  _buildTopBarActionButton(
                icon: icon,
                onTap: onTap,
                tooltip: tooltip,
                highlighted: highlighted,
              ),
              onTapWithRect: _libraryController.showFilterMenu,
            ),
          ),
          const SizedBox(width: 8),
          _buildTopBarActionButton(
            icon: Icons.add_rounded,
            onTap: _navigateToImport,
          ),
        ],
      );
    } else if (currentPage is BookSourcesPage) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopBarActionButton(
            icon: Icons.search_rounded,
            tooltip: context.l10n.bookSourcesSearch,
            onTap: _navigateToBookSourceSearch,
          ),
          const SizedBox(width: 8),
          _buildTopBarActionButton(
            icon: Icons.tune_rounded,
            tooltip: context.l10n.bookSourceManagementTitle,
            onTap: _navigateToBookSourceManagement,
          ),
        ],
      );
    } else if (currentPage is SettingsPage) {
      trailing = null;
    } else {
      // 其他自定义页不强行覆盖标题，避免和页面自身顶部冲突。
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: RepaintBoundary(
        child: HomeMobileTopBar(
          title: title,
          trailing: trailing,
        ),
      ),
    );
  }

  Future<void> _navigateToBookSourceManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BookSourceManagementPage(),
      ),
    );
  }

  Future<void> _navigateToBookSourceSearch() async {
    final sources = await BookSourceRegistry().load();
    if (!mounted) return;
    final client = BookSourceClient();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SourceSearchPage(
          sources: sources,
          client: client,
          shelfService: BookSourceShelfService(client: client),
        ),
      ),
    );
  }

  Widget _buildTopBarActionButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    bool highlighted = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final palette = PageStyleHelper.palette(context);
    final button = InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: highlighted
              ? scheme.primaryContainer
              : (_isMaterial3Style
                  ? scheme.surfaceContainer
                  : palette.cardStrong),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: highlighted
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.outline
                    .withValues(alpha: _isMaterial3Style ? 0.22 : 0.12),
            width: 0.6,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: highlighted
              ? scheme.onPrimaryContainer
              : scheme.onSurface.withValues(alpha: 0.78),
        ),
      ),
    );
    if (tooltip == null || tooltip.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip, child: button);
  }

  Future<void> _switchToTab(int index) async {
    if (index < 0 || index >= _navigationItems.length) return;
    if (_targetTabIndex == index) return;
    if (_targetTabIndex == null && _selectedIndex == index) return;

    if (!_pageController.hasClients) {
      _updateSelectedIndex(index);
      return;
    }

    final currentPage =
        (_pageController.page ?? _selectedIndex.toDouble()).round();
    final pageDistance = (index - currentPage).abs();
    final transitionToken = ++_tabTransitionToken;

    // 底栏用 target 立即启动选中/未选中动画；真正的 selectedIndex 等页面
    // 到达后再提交，避免顶部标题和操作按钮在旧页面尚可见时提前跳变。
    _beginTabTransition(index);

    await _pageController.animateToPage(
      index,
      // 距离越远，适度增加时长；正向和反向使用同一条对称曲线，避免
      // 往返切换时出现一边过快、一边拖沓的体感。
      duration: Duration(
        milliseconds: 300 + ((pageDistance - 1).clamp(0, 2) * 60).toInt(),
      ),
      curve: Curves.easeInOutCubic,
    );

    if (!mounted || transitionToken != _tabTransitionToken) return;

    final settledIndex = _pageController.hasClients
        ? (_pageController.page ?? index.toDouble()).round()
        : index;
    _completeTabTransition(
      settledIndex.clamp(0, _navigationItems.length - 1).toInt(),
    );
  }

  /// 宽屏下的页面解析：
  /// 让首页和手机端保持一致视觉来源，避免“改了首页但宽屏不生效”。
  Widget _resolveRailPage(Widget page) {
    if (page is HomeDashboardPage) {
      return const HomeMobileDashboardPage();
    }
    return page;
  }

  Widget _buildPageWrapper(Widget page) {
    // 这里是“页面装配中心”：
    // 不同页面统一在这里包壳（顶栏、背景、系统UI处理）。
    // 这样以后你要替换某个页面的外壳，只改这里。
    Widget wrappedPage;

    // 手机端针对不同页面应用不同包装策略。
    if (page is HomeDashboardPage) {
      wrappedPage = const HomeMobileDashboardPage();
    } else {
      // 其余页面统一背景包装。
      wrappedPage = HomeGenericPageWrapper(child: page);
    }

    // KeepAlive 能让 tab 切换时保留页面状态（滚动位置/已加载数据）。
    return HomeKeepAlivePageWrapper(child: wrappedPage);
  }

  void _navigateToImport() {
    // 导入页使用标准 Material 路由，避免透明叠加时出现黑底观感。
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportBookPage()),
    );
  }

  // 导航头部组件 - 专为平板和桌面优化
  Widget _buildNavigationHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary
                      .withValues(alpha: _isMaterial3Style ? 0.16 : 0.3),
                  blurRadius: _isMaterial3Style ? 5 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const AppBrandIcon(
              size: 40,
              borderRadius: 12,
            ),
          ),
          if (LayoutHelper.getValue(
            context,
            mobile: false,
            tablet: true,
            desktop: true,
          )) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.appTitle,
              style: TextStyle(
                fontSize: LayoutHelper.getValue(
                  context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.homeTagline,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 0.3,
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 书库筛选按钮：把按钮的屏幕位置传给筛选菜单，菜单贴着按钮弹出。
class _LibraryTopBarFilterButton extends StatelessWidget {
  final bool active;
  final Widget Function({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    bool highlighted,
  }) buildButton;
  final Future<void> Function(Rect anchor) onTapWithRect;

  const _LibraryTopBarFilterButton({
    required this.active,
    required this.buildButton,
    required this.onTapWithRect,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) => buildButton(
        icon: active ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
        tooltip: buttonContext.l10n.libraryFilterTooltip,
        highlighted: active,
        onTap: () {
          final box = buttonContext.findRenderObject()! as RenderBox;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          unawaited(onTapWithRect(rect));
        },
      ),
    );
  }
}

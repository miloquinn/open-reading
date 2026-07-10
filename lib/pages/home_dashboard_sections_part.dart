// 文件说明：首页仪表盘的 part 拆分文件，承载统计区块与局部构建方法。
// 技术要点：Flutter UI、Dart part。

part of 'home_dashboard_page.dart';

/// 首页大量 UI 区块方法拆分到这里：
/// - 欢迎卡片
/// - 指标卡片
/// - 周趋势图表
/// - 成就区块
///
/// 这样主文件更聚焦在：数据加载 + 页面入口。
extension _HomeDashboardSections on _HomeDashboardPageState {
  Widget _buildAiAdviceCard({
    required String advice,
    String? sourceBookTitle,
    bool isTablet = false,
  }) {
    final theme = Theme.of(context);
    final radius = isTablet ? 22.0 : 20.0;
    final horizontalPadding = isTablet ? 20.0 : 18.0;
    final verticalPadding = isTablet ? 18.0 : 16.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        enabled: !GlassEffectConfig.shouldDisableBlur,
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            verticalPadding,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.tertiaryContainer.withValues(alpha: 0.32),
                theme.colorScheme.primaryContainer.withValues(alpha: 0.22),
                theme.colorScheme.surface.withValues(alpha: 0.82),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: theme.colorScheme.primary,
                      size: isTablet ? 20 : 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AI 阅读建议',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if ((sourceBookTitle ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '基于《${sourceBookTitle!.trim()}》',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                advice,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.86),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final totalMinutes = (_summaryStats['total'] ?? 0) ~/ 60;
    final todayMinutes = (_summaryStats['today'] ?? 0) ~/ 60;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        enabled: !GlassEffectConfig.shouldDisableBlur,
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GlassEffectConfig.surfaceColor(context, opacity: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AppBrandIcon(
                      size: 28,
                      borderRadius: 8,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.homeTodayReadingMoment,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          todayMinutes > 0
                              ? context.l10n.homeReadMinutesKeepGoing(
                                  todayMinutes,
                                )
                              : context.l10n.homeTodayReadingJourneyStart,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (totalMinutes > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                        Theme.of(
                          context,
                        ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.emoji_events,
                          color: Theme.of(context).colorScheme.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.homeTotalReadingHours(
                          (totalMinutes / 60).toStringAsFixed(1),
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletHeroCard() {
    final totalMinutes = (_summaryStats['total'] ?? 0) ~/ 60;
    final todayMinutes = (_summaryStats['today'] ?? 0) ~/ 60;
    final weekMinutes = (_summaryStats['week'] ?? 0) ~/ 60;
    final totalHours = totalMinutes / 60;
    final totalValue =
        totalHours >= 1 ? totalHours.toStringAsFixed(1) : '$totalMinutes';
    final totalUnit =
        totalHours >= 1 ? context.l10n.unitHour : context.l10n.unitMinute;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        enabled: !GlassEffectConfig.shouldDisableBlur,
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.10),
                Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AppBrandIcon(
                            size: 22,
                            borderRadius: 6,
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.homeTodayReadingMoment,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$todayMinutes',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            context.l10n.unitMinute,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      todayMinutes > 0
                          ? context.l10n.homeTodayReadingKeepRhythm
                          : context.l10n.homeTodayReadingPrompt,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildTabletMetricChip(
                          label: context.l10n.homeWeeklyReading,
                          value: '$weekMinutes',
                          unit: context.l10n.unitMinute,
                          icon: Icons.calendar_view_week,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        _buildTabletMetricChip(
                          label: context.l10n.homeTotalReading,
                          value: totalValue,
                          unit: totalUnit,
                          icon: Icons.emoji_events,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.library_books,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_bookCount',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    Text(
                      context.l10n.homeCollectionCount,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletMetricChip({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '$value $unit',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabletSummaryPanel() {
    final totalMinutes = (_summaryStats['total'] ?? 0) ~/ 60;
    final todayMinutes = (_summaryStats['today'] ?? 0) ~/ 60;
    final weekMinutes = (_summaryStats['week'] ?? 0) ~/ 60;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        enabled: !GlassEffectConfig.shouldDisableBlur,
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: GlassEffectConfig.surfaceColor(context, opacity: 0.8),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.insights,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.homeKeyMetrics,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildWideLayout(todayMinutes, weekMinutes, totalMinutes),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletFocusCard() {
    final weekMinutes = (_summaryStats['week'] ?? 0) ~/ 60;
    final todayMinutes = (_summaryStats['today'] ?? 0) ~/ 60;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        enabled: !GlassEffectConfig.shouldDisableBlur,
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.25),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .tertiary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.bolt,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.homeReadingRhythm,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildFocusMetric(
                      label: context.l10n.todayReading,
                      value: '$todayMinutes',
                      unit: context.l10n.unitMinute,
                      icon: Icons.timer,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFocusMetric(
                      label: context.l10n.homeWeeklyTotal,
                      value: '$weekMinutes',
                      unit: context.l10n.unitMinute,
                      icon: Icons.trending_up,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFocusMetric({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '$value $unit',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalMinutes = (_summaryStats['total'] ?? 0) ~/ 60;
    final todayMinutes = (_summaryStats['today'] ?? 0) ~/ 60;
    final weekMinutes = (_summaryStats['week'] ?? 0) ~/ 60;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 针对iOS设备优化布局断点 - 考虑不同iPhone尺寸和像素密度
        final screenWidth = MediaQuery.of(context).size.width;
        final pixelRatio = MediaQuery.of(context).devicePixelRatio;

        // 动态调整断点 - 考虑高像素密度的iOS设备
        double breakPoint = 380.0;
        if (pixelRatio > 2.5) {
          // iPhone Pro/Pro Max等高密度设备
          breakPoint = 390.0;
        } else if (pixelRatio > 2.0) {
          // 标准Retina显示设备
          breakPoint = 380.0;
        }

        final isNarrow = screenWidth < breakPoint;
        return isNarrow
            ? _buildNarrowLayout(todayMinutes, weekMinutes, totalMinutes)
            : _buildWideLayout(todayMinutes, weekMinutes, totalMinutes);
      },
    );
  }

  Widget _buildNarrowLayout(
    int todayMinutes,
    int weekMinutes,
    int totalMinutes,
  ) {
    // 获取iOS设备优化的响应式间距
    final screenWidth = MediaQuery.of(context).size.width;

    // 动态调整间距 - 考虑iOS设备尺寸差异，为iPhone 16 Pro优化
    double cardSpacing, rowSpacing;

    if (screenWidth >= 428) {
      // iPhone 14 Pro Max, 15 Pro Max, 16 Pro Max等大屏设备
      cardSpacing = 18.0;
      rowSpacing = 24.0;
    } else if (screenWidth >= 414) {
      // iPhone 14 Plus, 15 Plus等Plus设备
      cardSpacing = 16.0;
      rowSpacing = 22.0;
    } else if (screenWidth >= 390) {
      // iPhone 14 Pro, 15 Pro, 16 Pro等标准Pro设备 - 增加间距
      cardSpacing = 16.0;
      rowSpacing = 20.0;
    } else {
      // iPhone SE, Mini等小屏设备 - 也适当增加间距
      cardSpacing = 12.0;
      rowSpacing = 16.0;
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: context.l10n.todayReading,
                value: '$todayMinutes',
                unit: context.l10n.unitMinute,
                icon: Icons.today,
                color: Colors.blue,
                onTap: () => _navigateToDetailedStats(context), // 跳转到详细统计
              ),
            ),
            SizedBox(width: cardSpacing),
            Expanded(
              child: _StatCard(
                title: context.l10n.homeWeeklyReading,
                value: '$weekMinutes',
                unit: context.l10n.unitMinute,
                icon: Icons.calendar_view_week,
                color: Colors.orange,
                onTap: () => _navigateToDetailedStats(context),
              ),
            ),
          ],
        ),
        SizedBox(height: rowSpacing),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: context.l10n.homeTotalReading,
                value: '$totalMinutes',
                unit: context.l10n.unitMinute,
                icon: Icons.history,
                color: Colors.green,
                onTap: () => _navigateToDetailedStats(context),
              ),
            ),
            SizedBox(width: cardSpacing),
            Expanded(
              child: _StatCard(
                title: context.l10n.homeLibraryCount,
                value: '$_bookCount',
                unit: context.l10n.unitBook,
                icon: Icons.book,
                color: Colors.purple,
                onTap: () => _navigateToDetailedStats(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWideLayout(int todayMinutes, int weekMinutes, int totalMinutes) {
    // 检查是否为平板或桌面设备
    final isTablet = LayoutHelper.isTablet(context);
    final isDesktop = LayoutHelper.isDesktop(context);

    // 平板和桌面使用 Row 布局，确保卡片高度一致
    if (isTablet || isDesktop) {
      final cardSpacing = LayoutHelper.getValue(
        context,
        mobile: 12.0,
        tablet: 16.0,
        desktop: 20.0,
      );
      final rowSpacing = LayoutHelper.getValue(
        context,
        mobile: 12.0,
        tablet: 16.0,
        desktop: 20.0,
      );

      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: context.l10n.todayReading,
                  value: '$todayMinutes',
                  unit: context.l10n.unitMinute,
                  icon: Icons.today,
                  color: Colors.blue,
                  onTap: () => _navigateToDetailedStats(context),
                ),
              ),
              SizedBox(width: cardSpacing),
              Expanded(
                child: _StatCard(
                  title: context.l10n.homeWeeklyReading,
                  value: '$weekMinutes',
                  unit: context.l10n.unitMinute,
                  icon: Icons.calendar_view_week,
                  color: Colors.orange,
                  onTap: () => _navigateToDetailedStats(context),
                ),
              ),
            ],
          ),
          SizedBox(height: rowSpacing),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: context.l10n.homeTotalReading,
                  value: '$totalMinutes',
                  unit: context.l10n.unitMinute,
                  icon: Icons.history,
                  color: Colors.green,
                  onTap: () => _navigateToDetailedStats(context),
                ),
              ),
              SizedBox(width: cardSpacing),
              Expanded(
                child: _StatCard(
                  title: context.l10n.homeLibraryCount,
                  value: '$_bookCount',
                  unit: context.l10n.unitBook,
                  icon: Icons.book,
                  color: Colors.purple,
                  onTap: () => _navigateToDetailedStats(context),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // 手机端使用 GridView，优化不同屏幕尺寸的间距和纵横比
    final screenWidth = MediaQuery.of(context).size.width;

    // 根据iOS设备屏幕尺寸优化间距和纵横比 - 为iPhone 16 Pro优化
    double gridSpacing, aspectRatio;

    if (screenWidth >= 428) {
      // iPhone Pro Max等大屏设备
      gridSpacing = 22.0;
      aspectRatio = 1.5;
    } else if (screenWidth >= 414) {
      // iPhone Plus等设备
      gridSpacing = 20.0;
      aspectRatio = 1.4;
    } else if (screenWidth >= 390) {
      // iPhone Pro等设备 - 增加间距，调整纵横比
      gridSpacing = 18.0;
      aspectRatio = 1.35;
    } else {
      // iPhone SE, Mini等小屏设备 - 也适当增加间距
      gridSpacing = 16.0;
      aspectRatio = 1.25;
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: gridSpacing,
      mainAxisSpacing: gridSpacing,
      childAspectRatio: aspectRatio,
      children: [
        _StatCard(
          title: context.l10n.todayReading,
          value: '$todayMinutes',
          unit: context.l10n.unitMinute,
          icon: Icons.today,
          color: Colors.blue,
          onTap: () => _navigateToDetailedStats(context),
        ),
        _StatCard(
          title: context.l10n.homeWeeklyReading,
          value: '$weekMinutes',
          unit: context.l10n.unitMinute,
          icon: Icons.calendar_view_week,
          color: Colors.orange,
          onTap: () => _navigateToDetailedStats(context),
        ),
        _StatCard(
          title: context.l10n.homeTotalReading,
          value: '$totalMinutes',
          unit: context.l10n.unitMinute,
          icon: Icons.history,
          color: Colors.green,
          onTap: () => _navigateToDetailedStats(context),
        ),
        _StatCard(
          title: context.l10n.homeLibraryCount,
          value: '$_bookCount',
          unit: context.l10n.unitBook,
          icon: Icons.book,
          color: Colors.purple,
          onTap: () => _navigateToDetailedStats(context),
        ),
      ],
    );
  }

  Widget _buildWeeklyChartCard({double? chartHeight}) {
    if (_weeklyData.isEmpty) {
      return Container();
    }

    final maxY = (_weeklyData
                .map((d) => d['duration'] as int)
                .reduce((a, b) => a > b ? a : b) /
            60) +
        10;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        enabled: !GlassEffectConfig.shouldDisableBlur,
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: GlassEffectConfig.surfaceColor(context, opacity: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.analytics_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.homeWeeklyTrend,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: chartHeight ?? 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY > 10 ? maxY : 10,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) =>
                            Theme.of(context).colorScheme.inverseSurface,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            context.l10n.homeBarTooltipMinutes(
                              rod.toY.toInt(),
                            ),
                            TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onInverseSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: _getBottomTitles,
                          reservedSize: 22,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}',
                              style: Theme.of(context).textTheme.bodySmall,
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 10,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: _weeklyData.map((data) {
                      return BarChartGroupData(
                        x: data['day'],
                        barRods: [
                          BarChartRodData(
                            toY: (data['duration'] as int) / 60,
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.8),
                                Theme.of(context).colorScheme.primary,
                              ],
                            ),
                            width: 20,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        enabled: !GlassEffectConfig.shouldDisableBlur,
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: GlassEffectConfig.surfaceColor(context, opacity: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.schedule,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.homeAchievements,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAchievementItem(
                icon: Icons.local_fire_department,
                title: context.l10n.homeConsecutiveReading,
                description: context.l10n.homeConsecutiveReadingDesc,
                value:
                    '${_achievementStats['consecutiveDays'] ?? 0} ${context.l10n.unitDay}',
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildAchievementItem(
                icon: Icons.timer,
                title: context.l10n.homeFocusDuration,
                description: context.l10n.homeFocusDurationDesc,
                value:
                    '${_achievementStats['maxSessionMinutes'] ?? 0} ${context.l10n.unitMinute}',
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _buildAchievementItem(
                icon: Icons.trending_up,
                title: context.l10n.homeWeeklyTotal,
                description: context.l10n.homeWeeklyTotalDesc,
                value:
                    '${((_summaryStats['week'] ?? 0) / 60).round()} ${context.l10n.unitMinute}',
                color: Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementItem({
    required IconData icon,
    required String title,
    required String description,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _getBottomTitles(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 10);
    String text;
    switch (value.toInt()) {
      case 1:
        text = context.l10n.weekdayMonShort;
        break;
      case 2:
        text = context.l10n.weekdayTueShort;
        break;
      case 3:
        text = context.l10n.weekdayWedShort;
        break;
      case 4:
        text = context.l10n.weekdayThuShort;
        break;
      case 5:
        text = context.l10n.weekdayFriShort;
        break;
      case 6:
        text = context.l10n.weekdaySatShort;
        break;
      case 7:
        text = context.l10n.weekdaySunShort;
        break;
      default:
        text = '';
    }
    return SideTitleWidget(
      axisSide: AxisSide.bottom,
      space: 4.0,
      child: Text(text, style: style),
    );
  }

  // iOS设备优化的统计卡片
  Widget _buildOptimizedSummaryCards() {
    if (!kIsWeb && Platform.isIOS) {
      final screenWidth = MediaQuery.of(context).size.width;
      double offset;

      if (screenWidth >= 428) {
        // iPhone 14 Pro Max, 15 Pro Max, 16 Pro Max等大屏设备
        offset = -50.0;
      } else if (screenWidth >= 414) {
        // iPhone 14 Plus, 15 Plus等Plus设备
        offset = -40.0;
      } else if (screenWidth >= 390) {
        // iPhone 14 Pro, 15 Pro, 16 Pro等标准Pro设备 - 减小偏移量
        offset = -25.0;
      } else {
        // iPhone SE, Mini等小屏设备 - 最小偏移量
        offset = -15.0;
      }

      return Transform.translate(
        offset: Offset(0, offset),
        transformHitTests: false,
        child: _buildSummaryCards(),
      );
    } else {
      return _buildSummaryCards();
    }
  }

  // iOS设备优化的图表卡片
  Widget _buildOptimizedWeeklyChartCard() {
    if (!kIsWeb && Platform.isIOS) {
      final screenWidth = MediaQuery.of(context).size.width;
      double offset;

      if (screenWidth >= 428) {
        // iPhone 14 Pro Max, 15 Pro Max, 16 Pro Max等大屏设备
        offset = -65.0;
      } else if (screenWidth >= 414) {
        // iPhone 14 Plus, 15 Plus等Plus设备
        offset = -55.0;
      } else if (screenWidth >= 390) {
        // iPhone 14 Pro, 15 Pro, 16 Pro等标准Pro设备 - 减小偏移量
        offset = -35.0;
      } else {
        // iPhone SE, Mini等小屏设备 - 最小偏移量
        offset = -25.0;
      }

      return Transform.translate(
        offset: Offset(0, offset),
        transformHitTests: false,
        child: _buildWeeklyChartCard(),
      );
    } else {
      return _buildWeeklyChartCard();
    }
  }

  // iOS设备优化的活动卡片
  Widget _buildOptimizedRecentActivity() {
    if (!kIsWeb && Platform.isIOS) {
      final screenWidth = MediaQuery.of(context).size.width;
      double offset;

      if (screenWidth >= 428) {
        // iPhone 14 Pro Max, 15 Pro Max, 16 Pro Max等大屏设备
        offset = -30.0;
      } else if (screenWidth >= 414) {
        // iPhone 14 Plus, 15 Plus等Plus设备
        offset = -25.0;
      } else if (screenWidth >= 390) {
        // iPhone 14 Pro, 15 Pro, 16 Pro等标准Pro设备 - 减小偏移量
        offset = -15.0;
      } else {
        // iPhone SE, Mini等小屏设备 - 最小偏移量
        offset = -10.0;
      }

      return Transform.translate(
        offset: Offset(0, offset),
        transformHitTests: false,
        child: _buildRecentActivity(),
      );
    } else {
      return _buildRecentActivity();
    }
  }
}

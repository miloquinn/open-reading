// 文件说明：大屏首页仪表盘页面，聚合统计卡片、最近阅读和可视化内容。
// 技术要点：Flutter UI、FL Chart、渲染层、文件系统。

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';
import 'dart:io';
import '../models/book.dart';
import '../services/ai/global_ai_reading_service.dart';
import '../services/books/book_services.dart';
import '../services/reading/reading_stats_dao.dart';
import '../utils/glass_config.dart';
import '../utils/layout_helper.dart';
import '../utils/localization_extension.dart';
import '../widgets/app_brand_icon.dart';
import 'detailed_stats_page.dart';
import 'home_shell_page.dart';

part 'home_dashboard_sections_part.dart';

/// 首页统计内容页（可独立展示）。
///
/// 新手阅读提示：
/// 1) 在当前项目里，手机端首页主路径优先使用 `home_shell_page.dart` 里的
///    `HomeMobileDashboardPage`（文件：`home_mobile_dashboard_page.dart`）。
/// 2) 这个页面仍然保留，是为了支持独立渲染和 Rail 布局复用。
/// 3) 如果你修改了这里，手机首页不一定会立刻变化，请先确认运行路径。
class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final _statsDao = ReadingStatsDao();
  final _bookDao = BookDao();
  final _aiService = GlobalAIReadingService();
  Map<String, int> _summaryStats = {};
  List<Map<String, dynamic>> _weeklyData = [];
  Map<String, dynamic> _achievementStats = {};
  String? _aiReadingAdvice;
  String? _aiAdviceBookTitle;
  int _bookCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    setState(() => _isLoading = true);
    try {
      final summaryFuture = _statsDao.getSummaryStats();
      final weeklyFuture = _statsDao.getWeeklyChartData();
      final achievementsFuture = _statsDao.getAchievementStats();
      final bookCountFuture = _bookDao.getBooksCount();
      final aiAdviceFuture = _loadAiAdvice();

      final summary = await summaryFuture;
      final weekly = await weeklyFuture;
      final achievements = await achievementsFuture;
      final bookCount = await bookCountFuture;
      final aiAdvice = await aiAdviceFuture;

      setState(() {
        _summaryStats = summary;
        _weeklyData = weekly;
        _achievementStats = achievements;
        _aiReadingAdvice = aiAdvice.$1;
        _aiAdviceBookTitle = aiAdvice.$2;
        _bookCount = bookCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // 错误处理 - 静默处理，不影响用户体验
      debugPrint('Error loading stats: $e');
    }
  }

  Future<(String?, String?)> _loadAiAdvice() async {
    try {
      final recentIds = await _statsDao.getRecentBookIds(limit: 6);
      final candidates = <Book>[];
      for (final id in recentIds) {
        final book = await _bookDao.getBookById(id);
        if (book != null) {
          candidates.add(book);
        }
      }

      if (candidates.isEmpty) {
        final allBooks = await _bookDao.getAllBooks();
        allBooks.sort((a, b) {
          final progressCmp = b.currentPage.compareTo(a.currentPage);
          if (progressCmp != 0) {
            return progressCmp;
          }
          return b.importDate.compareTo(a.importDate);
        });
        candidates.addAll(allBooks.take(10));
      }

      for (final book in candidates) {
        final bookId = book.id;
        if (bookId == null) {
          continue;
        }
        final memory = await _aiService.loadBookMemory(bookId.toString());
        final advice = (memory?['readingAdvice'] as String?)?.trim();
        if (advice != null && advice.isNotEmpty) {
          return (advice, book.title);
        }
        final summary = (memory?['summary'] as String?)?.trim();
        if (summary != null && summary.isNotEmpty) {
          return (summary, book.title);
        }
      }
    } catch (e) {
      debugPrint('load ai advice failed: $e');
    }
    return (null, null);
  }

  // 导航到详细统计页面
  void _navigateToDetailedStats(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DetailedStatsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否在侧边导航栏模式下
    final navContext = NavigationContext.of(context);
    final useRailNavigation = navContext?.useRailNavigation ?? false;

    // 在侧边导航栏模式下，不显示 Scaffold 和 AppBar
    if (useRailNavigation) {
      return _buildContent(context);
    }

    // 手机模式：显示完整的 Scaffold + AppBar
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          context.l10n.homeReadingStatsTitle,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: GlassEffectConfig.createProgressiveAppBar(
          context: context,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildContent(context),
    );
  }

  // 提取页面内容部分，在两种模式下共用
  Widget _buildContent(BuildContext context) {
    final navContext = NavigationContext.of(context);
    final useRailNavigation = navContext?.useRailNavigation ?? false;
    final isTablet = useRailNavigation || LayoutHelper.isTablet(context);
    if (isTablet) {
      return _buildTabletContent(context);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          colors: [
            // 使用主题的主色调创建更丰富的渐变
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.06),
            Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.15),
            Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.10),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllStats,
              child: SafeArea(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    LayoutHelper.getHorizontalPadding(context),
                    LayoutHelper.getValue(
                      context,
                      mobile: 20.0,
                      tablet: 24.0,
                      desktop: 28.0,
                    ),
                    LayoutHelper.getHorizontalPadding(context),
                    LayoutHelper.getValue(
                      context,
                      mobile: 24.0 + MediaQuery.of(context).padding.bottom,
                      tablet: 32.0 + MediaQuery.of(context).padding.bottom,
                      desktop: 40.0 + MediaQuery.of(context).padding.bottom,
                    ),
                  ),
                  children: [
                    _buildWelcomeCard(),
                    if ((_aiReadingAdvice ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildAiAdviceCard(
                        advice: _aiReadingAdvice!,
                        sourceBookTitle: _aiAdviceBookTitle,
                      ),
                    ],
                    // iOS端使用Transform.translate抵消系统默认间距，Android端添加间距
                    if (!kIsWeb && !Platform.isIOS) const SizedBox(height: 28),
                    _buildOptimizedSummaryCards(),
                    // iOS端使用Transform.translate抵消系统默认间距，Android端添加间距
                    if (!kIsWeb && !Platform.isIOS) const SizedBox(height: 32),
                    _buildOptimizedWeeklyChartCard(),
                    // iOS端使用Transform.translate抵消系统默认间距，Android端添加间距
                    if (!kIsWeb && !Platform.isIOS) const SizedBox(height: 32),
                    _buildOptimizedRecentActivity(),
                    SizedBox(
                      height: LayoutHelper.getValue(
                        context,
                        mobile: 48.0,
                        largeMobile: 56.0,
                        tablet: 64.0,
                        desktop: 72.0,
                      ),
                    ), // 底部留白
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTabletContent(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final horizontalPadding = LayoutHelper.getHorizontalPadding(context);
    final topPadding = mediaQuery.padding.top +
        LayoutHelper.getValue(
          context,
          mobile: 20.0,
          tablet: 28.0,
          desktop: 32.0,
        );
    final bottomPadding = mediaQuery.padding.bottom + 36.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.10),
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.05),
            Theme.of(context).colorScheme.primaryContainer.withValues(
                  alpha: 0.12,
                ),
            Theme.of(context).colorScheme.secondaryContainer.withValues(
                  alpha: 0.08,
                ),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllStats,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                ),
                children: [
                  _buildTabletHeroCard(),
                  if ((_aiReadingAdvice ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildAiAdviceCard(
                      advice: _aiReadingAdvice!,
                      sourceBookTitle: _aiAdviceBookTitle,
                      isTablet: true,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          children: [
                            _buildTabletSummaryPanel(),
                            const SizedBox(height: 20),
                            _buildRecentActivity(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _buildWeeklyChartCard(chartHeight: 260),
                            const SizedBox(height: 20),
                            _buildTabletFocusCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap; // 新增点击回调

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.onTap, // 可选的点击事件
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // 添加点击事件
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          enabled: !GlassEffectConfig.shouldDisableBlur,
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.all(
              LayoutHelper.getValue(
                context,
                mobile: 16.0,
                tablet: 18.0,
                desktop: 20.0,
              ),
            ),
            decoration: BoxDecoration(
              color: GlassEffectConfig.surfaceColor(context, opacity: 0.8),
              borderRadius: BorderRadius.circular(
                LayoutHelper.getValue(
                  context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
              ),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(
                    LayoutHelper.getValue(
                      context,
                      mobile: 6.0,
                      tablet: 7.0,
                      desktop: 8.0,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      LayoutHelper.getValue(
                        context,
                        mobile: 8.0,
                        tablet: 9.0,
                        desktop: 10.0,
                      ),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: LayoutHelper.getValue(
                      context,
                      mobile: 22.0,
                      tablet: 24.0,
                      desktop: 26.0,
                    ),
                    color: color,
                  ),
                ),
                SizedBox(
                  height: LayoutHelper.getValue(
                    context,
                    mobile: 12.0,
                    tablet: 14.0,
                    desktop: 16.0,
                  ),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(
                        height: LayoutHelper.getValue(
                          context,
                          mobile: 6.0,
                          tablet: 7.0,
                          desktop: 8.0,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              value,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                            ),
                            SizedBox(
                              width: LayoutHelper.getValue(
                                context,
                                mobile: 3.0,
                                tablet: 4.0,
                                desktop: 5.0,
                              ),
                            ),
                            Text(
                              unit,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 10,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ), // GestureDetector
    );
  }
}

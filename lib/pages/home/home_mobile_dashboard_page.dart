// 文件说明：移动端首页页面，负责最近阅读、周统计、专注计时与 AI 建议。
// 技术要点：Flutter UI、文件系统。

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:xxread/core/reader/native_reader_service.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/reading_stats/detailed_stats_page.dart';
import 'package:xxread/services/ai/global_ai_reading_service.dart';
import 'package:xxread/services/books/book_services.dart';
import 'package:xxread/services/core/core_services.dart';
import 'package:xxread/services/library/library_event_bus_service.dart';
import 'package:xxread/services/reading/reading_plan_service.dart';
import 'package:xxread/services/reading/reading_plan_translator.dart';
import 'package:xxread/services/reading/reading_stats_dao.dart';
import 'package:xxread/utils/layout_helper.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_transitions.dart';
import 'package:xxread/utils/ui_style.dart';
import 'package:xxread/widgets/app_brand_icon.dart';
import 'package:xxread/widgets/generated_book_cover.dart';
import 'package:xxread/widgets/side_toast.dart';

import 'home_mobile_chrome.dart';

class _HomeContentMetrics {
  final double refreshEdgeOffset;
  final double horizontalPadding;
  final double contentTopPadding;
  final double contentBottomPadding;
  final double sectionSpacing;

  const _HomeContentMetrics({
    required this.refreshEdgeOffset,
    required this.horizontalPadding,
    required this.contentTopPadding,
    required this.contentBottomPadding,
    required this.sectionSpacing,
  });
}

class _HomePalette {
  final bool isMaterial3Style;
  final Color pageGradientStart;
  final Color pageGradientMiddle;
  final Color pageGradientEnd;
  final Color cardColor;
  final Color heroColor;
  final Color topActionColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color sectionLabelColor;
  final Color accentColor;
  final Color softAccentColor;
  final Color inactiveDotColor;
  final Color coverPlaceholderColor;
  final Color refreshBackgroundColor;

  const _HomePalette({
    required this.isMaterial3Style,
    required this.pageGradientStart,
    required this.pageGradientMiddle,
    required this.pageGradientEnd,
    required this.cardColor,
    required this.heroColor,
    required this.topActionColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.sectionLabelColor,
    required this.accentColor,
    required this.softAccentColor,
    required this.inactiveDotColor,
    required this.coverPlaceholderColor,
    required this.refreshBackgroundColor,
  });

  factory _HomePalette.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isMaterial3Style =
        theme.extension<UiStyleThemeExtension>()?.isMaterial3Style ?? false;

    return _HomePalette(
      isMaterial3Style: isMaterial3Style,
      pageGradientStart: isMaterial3Style
          ? Color.alphaBlend(
              scheme.surfaceContainerHigh
                  .withValues(alpha: isDark ? 0.86 : 0.94),
              scheme.surface,
            )
          : Color.alphaBlend(
              scheme.primary.withValues(alpha: isDark ? 0.26 : 0.10),
              scheme.surface,
            ),
      pageGradientMiddle: isMaterial3Style
          ? Color.alphaBlend(
              scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.8 : 0.9),
              scheme.surface,
            )
          : Color.alphaBlend(
              scheme.secondary.withValues(alpha: isDark ? 0.18 : 0.08),
              scheme.surface,
            ),
      pageGradientEnd: scheme.surface,
      cardColor: isMaterial3Style
          ? scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.98 : 1.0)
          : scheme.surface.withValues(alpha: isDark ? 0.72 : 0.88),
      heroColor: isMaterial3Style
          ? Color.alphaBlend(
              scheme.primary.withValues(alpha: isDark ? 0.20 : 0.12),
              scheme.surfaceContainerHigh,
            )
          : Color.alphaBlend(
              scheme.primary.withValues(alpha: isDark ? 0.25 : 0.14),
              scheme.primaryContainer.withValues(alpha: isDark ? 0.40 : 0.56),
            ),
      topActionColor: isMaterial3Style
          ? scheme.surfaceContainer
          : scheme.surface.withValues(alpha: isDark ? 0.76 : 0.84),
      primaryTextColor: scheme.onSurface,
      secondaryTextColor: scheme.onSurfaceVariant.withValues(
        alpha: isDark ? 0.92 : 0.84,
      ),
      sectionLabelColor: scheme.onSurfaceVariant.withValues(
        alpha:
            isMaterial3Style ? (isDark ? 0.9 : 0.82) : (isDark ? 0.82 : 0.76),
      ),
      accentColor: scheme.primary,
      softAccentColor: isMaterial3Style
          ? scheme.tertiary.withValues(alpha: isDark ? 0.7 : 0.58)
          : scheme.primary.withValues(alpha: isDark ? 0.76 : 0.62),
      inactiveDotColor: scheme.outline.withValues(
        alpha:
            isMaterial3Style ? (isDark ? 0.46 : 0.36) : (isDark ? 0.38 : 0.30),
      ),
      coverPlaceholderColor: scheme.primary.withValues(
          alpha: isMaterial3Style
              ? (isDark ? 0.52 : 0.4)
              : (isDark ? 0.66 : 0.56)),
      refreshBackgroundColor:
          isMaterial3Style ? scheme.surfaceContainerHigh : scheme.surface,
    );
  }
}

class HomeMobileDashboardPage extends StatefulWidget {
  const HomeMobileDashboardPage({super.key});

  @override
  State<HomeMobileDashboardPage> createState() =>
      _HomeMobileDashboardPageState();
}

class _HomeMobileDashboardPageState extends State<HomeMobileDashboardPage> {
  final _statsDao = ReadingStatsDao();
  final _bookDao = BookDao();
  final _planService = ReadingPlanService();
  final _appStateService = AppStateService();
  final _aiService = GlobalAIReadingService();
  StreamSubscription<void>? _libraryChangedSubscription;

  _HomePalette get _palette => _HomePalette.fromTheme(Theme.of(context));

  Map<String, int> _summaryStats = {};
  List<Map<String, dynamic>> _weeklyData = [];
  List<Book> _recentBooks = [];
  ReadingPlanSnapshot? _readingPlan;
  Book? _recommendedPlanBook;
  String? _aiReadingAdvice;
  String? _aiAdviceBookTitle;
  bool _isInitialLoading = true;
  Timer? _focusTimer;
  DateTime? _focusEndTime;
  Duration _focusRemaining = Duration.zero;
  static const int _focusMinutes = 25;

  @override
  void initState() {
    super.initState();
    _loadAllStats();
    _libraryChangedSubscription = LibraryEventBus().stream.listen((_) {
      if (!mounted) return;
      _loadAllStats();
    });
  }

  @override
  void dispose() {
    _libraryChangedSubscription?.cancel();
    _focusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllStats() async {
    try {
      final summaryFuture = _statsDao.getSummaryStats();
      final weeklyFuture = _statsDao.getWeeklyChartData();
      final recentBooksFuture = _loadRecentBooks();
      final planFuture = _planService.loadSnapshot();

      final summary = await summaryFuture;
      final weekly = await weeklyFuture;
      final recentBooks = await recentBooksFuture;
      final plan = await planFuture;

      Book? recommendedBook;
      final planBookId = plan.recommendedBookId;
      if (planBookId != null) {
        recommendedBook = await _bookDao.getBookById(planBookId);
      }
      recommendedBook ??= recentBooks.isNotEmpty ? recentBooks.first : null;
      final aiAdviceData = await _loadAiAdviceForBook(recommendedBook);

      if (!mounted) return;
      setState(() {
        _summaryStats = summary;
        _weeklyData = weekly;
        _recentBooks = recentBooks;
        _readingPlan = plan;
        _recommendedPlanBook = recommendedBook;
        _aiReadingAdvice = aiAdviceData.$1;
        _aiAdviceBookTitle = aiAdviceData.$2;
        _isInitialLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<(String?, String?)> _loadAiAdviceForBook(Book? book) async {
    if (book == null || book.id == null) {
      return (null, null);
    }

    try {
      final memory = await _aiService.loadBookMemory(book.id!.toString());
      final advice = (memory?['readingAdvice'] as String?)?.trim();
      if (advice != null && advice.isNotEmpty) {
        return (advice, book.title);
      }
      final summary = (memory?['summary'] as String?)?.trim();
      if (summary != null && summary.isNotEmpty) {
        return (summary, book.title);
      }
    } catch (_) {
      return (null, null);
    }
    return (null, null);
  }

  Future<List<Book>> _loadRecentBooks() async {
    try {
      final orderedBookIds = await _statsDao.getRecentBookIds(limit: 5);
      final books = <Book>[];
      final seen = <int>{};

      for (final id in orderedBookIds) {
        final book = await _bookDao.getBookById(id);
        if (book != null) {
          books.add(book);
          seen.add(id);
        }
      }

      if (!_appStateService.isInitialized) {
        await _appStateService.initialize();
      }
      final appState = _appStateService.currentState;
      final recentBooksList = appState.readingState.recentBooks;

      for (final recentBook in recentBooksList.take(5)) {
        if (seen.contains(recentBook.bookId)) continue;
        final book = await _bookDao.getBookById(recentBook.bookId);
        if (book != null) {
          books.add(book);
          seen.add(recentBook.bookId);
        }
        if (books.length >= 5) break;
      }

      if (books.isNotEmpty) {
        return books.take(5).toList(growable: false);
      }

      final allBooks = await _bookDao.getAllBooks();
      final fallback = allBooks.where((book) => book.currentPage > 0).toList()
        ..sort((a, b) => b.importDate.compareTo(a.importDate));
      if (fallback.isNotEmpty) {
        return fallback.take(5).toList(growable: false);
      }
      return const [];
    } catch (_) {
      return [];
    }
  }

  _HomeContentMetrics _computeMetrics(
    MediaQueryData mediaQuery, {
    required bool useRailNavigation,
  }) {
    final horizontalPadding = useRailNavigation
        ? (mediaQuery.size.width >= 1440 ? 34.0 : 24.0)
        : 16.0;
    final mobileChrome = HomeMobileChromeScope.of(context);
    final contentBottomPadding = useRailNavigation
        ? mediaQuery.viewPadding.bottom + 24
        : mobileChrome.pageBottomPadding;

    final refreshEdgeOffset = useRailNavigation
        ? mediaQuery.viewPadding.top
        : mobileChrome.topBarHeight;

    return _HomeContentMetrics(
      refreshEdgeOffset: refreshEdgeOffset,
      horizontalPadding: horizontalPadding,
      contentTopPadding: useRailNavigation
          ? mediaQuery.viewPadding.top + 8
          : mobileChrome.pageTopPadding,
      contentBottomPadding: contentBottomPadding,
      sectionSpacing: useRailNavigation ? 12 : 10,
    );
  }

  int get _todayMinutes => (_summaryStats['today'] ?? 0) ~/ 60;
  int get _totalMinutes => (_summaryStats['total'] ?? 0) ~/ 60;

  String _formatThousand(int number) {
    final raw = number.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return raw.replaceAll(reg, ',');
  }

  List<double> _normalizedWeekDots() {
    if (_weeklyData.isEmpty) {
      return const [0, 0, 0, 0, 0, 0, 0];
    }

    final values = _weeklyData.take(7).map((item) {
      final raw = item['readingTime'] ??
          item['duration'] ??
          item['minutes'] ??
          item['value'] ??
          0;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString()) ?? 0;
    }).toList(growable: false);

    while (values.length < 7) {
      values.add(0);
    }

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    if (maxValue <= 0) return const [0, 0, 0, 0, 0, 0, 0];

    return values
        .map((v) => (v / maxValue).clamp(0.0, 1.0))
        .toList(growable: false);
  }

  int _weekPercent(List<double> dots) {
    final active = dots.where((v) => v > 0).length;
    return ((active / 7) * 100).round();
  }

  void _openStats() {
    Navigator.of(context).pushWithSlideScale(const DetailedStatsPage());
  }

  Future<void> _openBook(Book book) async {
    await NativeReaderService.openBook(context, book);
    if (!mounted) return;
    await _loadAllStats();
  }

  void _startFocusTimer() {
    _focusTimer?.cancel();
    final end = DateTime.now().add(const Duration(minutes: _focusMinutes));

    setState(() {
      _focusEndTime = end;
      _focusRemaining = end.difference(DateTime.now());
    });

    _focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = end.difference(DateTime.now());
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (remaining.inSeconds <= 0) {
        timer.cancel();
        setState(() {
          _focusEndTime = null;
          _focusRemaining = Duration.zero;
        });
        showSideToast(context, context.l10n.homeFocusCompleted(_focusMinutes),
            icon: Icons.emoji_events_rounded);
        _loadAllStats();
      } else {
        setState(() {
          _focusRemaining = remaining;
        });
      }
    });
  }

  void _cancelFocusTimer() {
    _focusTimer?.cancel();
    setState(() {
      _focusEndTime = null;
      _focusRemaining = Duration.zero;
    });
  }

  Future<void> _showGoalPicker() async {
    final currentGoal = _readingPlan?.dailyGoalMinutes ??
        await _planService.getDailyGoalMinutes();
    if (!mounted) return;
    final isMaterial3Style = Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;

    const options = [15, 20, 30, 45, 60, 90, 120, 150, 180];
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: isMaterial3Style
          ? Theme.of(context).colorScheme.surfaceContainerHigh
          : Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.flag_circle_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.homeDailyReadingGoal,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((value) {
                    final isSelected = value == currentGoal;
                    return ChoiceChip(
                      label: Text(context.l10n.statsMinutes(value)),
                      selected: isSelected,
                      onSelected: (_) => Navigator.pop(context, value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }
    await _planService.setDailyGoalMinutes(selected);
    await _loadAllStats();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final useRailNavigation =
        LayoutHelper.getNavigationType(context) == NavigationType.rail;
    final metrics = _computeMetrics(
      mediaQuery,
      useRailNavigation: useRailNavigation,
    );
    final dots = _normalizedWeekDots();
    final weekPercent = _weekPercent(dots);
    final planDone = _readingPlan?.completedTasks ?? 0;
    final planTotal = _readingPlan?.totalTasks ?? 3;
    final contentMaxWidth = useRailNavigation
        ? (mediaQuery.size.width >= 1600 ? 1140.0 : 980.0)
        : double.infinity;
    final palette = _palette;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.pageGradientStart,
            palette.pageGradientMiddle,
            palette.pageGradientEnd,
          ],
        ),
      ),
      child: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllStats,
              strokeWidth: 2.5,
              displacement: 40,
              color: palette.accentColor,
              backgroundColor: palette.refreshBackgroundColor,
              edgeOffset: metrics.refreshEdgeOffset,
              child: ListView(
                scrollCacheExtent: const ScrollCacheExtent.pixels(900),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  metrics.horizontalPadding,
                  metrics.contentTopPadding,
                  metrics.horizontalPadding,
                  metrics.contentBottomPadding,
                ),
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (useRailNavigation) ...[
                            RepaintBoundary(child: _buildTopRow()),
                            SizedBox(height: metrics.sectionSpacing),
                          ],
                          RepaintBoundary(child: _buildHeroCard()),
                          SizedBox(height: metrics.sectionSpacing),
                          if ((_aiReadingAdvice ?? '').trim().isNotEmpty) ...[
                            RepaintBoundary(
                              child: _buildSectionLabel(
                                  context.l10n.homeAiAdviceSection),
                            ),
                            SizedBox(height: metrics.sectionSpacing),
                            RepaintBoundary(child: _buildAiAdviceCard()),
                            SizedBox(height: metrics.sectionSpacing),
                          ],
                          RepaintBoundary(
                              child: _buildSectionLabel(
                                  context.l10n.homeTodayGlance)),
                          SizedBox(height: metrics.sectionSpacing),
                          RepaintBoundary(child: _buildSummaryRow()),
                          SizedBox(height: metrics.sectionSpacing),
                          RepaintBoundary(
                            child: _buildHeaderRow(
                              context.l10n.homeTodayReadingPlan,
                              '$planDone / $planTotal',
                            ),
                          ),
                          SizedBox(height: metrics.sectionSpacing),
                          RepaintBoundary(child: _buildPlanCard()),
                          SizedBox(height: metrics.sectionSpacing),
                          RepaintBoundary(
                              child: _buildSectionLabel(
                                  context.l10n.readingProgress)),
                          SizedBox(height: metrics.sectionSpacing),
                          RepaintBoundary(
                            child: _buildWeekCard(dots, weekPercent),
                          ),
                          SizedBox(height: metrics.sectionSpacing),
                          RepaintBoundary(
                            child: _buildHeaderRow(
                              context.l10n.homeRecentReading,
                              context.l10n.homeViewAll,
                              action: _openStats,
                            ),
                          ),
                          SizedBox(height: metrics.sectionSpacing),
                          RepaintBoundary(
                            child: _buildRecentCard(
                              _recentBooks.take(3).toList(growable: false),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTopRow() {
    final palette = _palette;
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Text(
            context.l10n.home,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: palette.primaryTextColor,
            ),
          ),
          const Spacer(),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.topActionColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.settings_outlined,
              size: 20,
              color: palette.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final palette = _palette;
    final plan = _readingPlan;
    final weekMinutes = (_summaryStats['week'] ?? 0) ~/ 60;
    final streak = plan?.streakDays ?? (_summaryStats['streak'] ?? 0);
    final title = plan == null
        ? context.l10n.homeSyncingReadingPlan
        : plan.isGoalCompleted
            ? context.l10n.homeGoalDoneSuggestReview
            : context.l10n.homeRemainingToGoal(plan.remainingMinutes);
    final recommendedBookTitle = _recommendedPlanBook?.title;
    final recommendationText = recommendedBookTitle == null
        ? context.l10n.homePickBookHint
        : context.l10n.homeContinueBookHint(recommendedBookTitle);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _frostedCardDecoration(
        radius: 20,
        stronger: true,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.heroColor.withValues(alpha: 0.92),
            palette.heroColor.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_rounded,
                size: 20,
                color: palette.accentColor,
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.homeTodayActionAdvice,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.primaryTextColor,
                ),
              ),
              const Spacer(),
              if (plan != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: palette.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.l10n.homeProgressPercent(
                        (plan.completionRate * 100).round()),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.accentColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: palette.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.primaryTextColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AppBrandIcon(
                  size: 18,
                  borderRadius: 5,
                  border: Border.all(
                    color: palette.accentColor.withValues(alpha: 0.24),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendationText,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroChip(
                icon: Icons.local_fire_department_outlined,
                text: context.l10n.homeStreakDays(streak),
              ),
              _buildHeroChip(
                icon: Icons.calendar_view_week_outlined,
                text: context.l10n.homeWeekMinutes(weekMinutes),
              ),
              _buildHeroChip(
                icon: Icons.flag_outlined,
                text: plan == null
                    ? context.l10n.homePlanLoading
                    : context.l10n.homeGoalMinutesPerDay(plan.dailyGoalMinutes),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiAdviceCard() {
    final palette = _palette;
    final advice = (_aiReadingAdvice ?? '').trim();
    final fromBook = (_aiAdviceBookTitle ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _frostedCardDecoration(
        radius: 18,
        stronger: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: palette.accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.homeAiAdviceForYou,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.primaryTextColor,
                ),
              ),
            ],
          ),
          if (fromBook.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.homeBasedOnBook(fromBook),
              style: TextStyle(
                fontSize: 12,
                color: palette.secondaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            advice,
            style: TextStyle(
              fontSize: 13,
              color: palette.secondaryTextColor,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip({
    required IconData icon,
    required String text,
  }) {
    final palette = _palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.primaryTextColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.secondaryTextColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    final palette = _palette;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: palette.sectionLabelColor,
      ),
    );
  }

  BoxDecoration _frostedCardDecoration({
    Gradient? gradient,
    double radius = 18,
    bool stronger = false,
  }) {
    final palette = _palette;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (palette.isMaterial3Style) {
      return BoxDecoration(
        color: gradient == null
            ? (stronger ? scheme.surfaceContainer : scheme.surfaceContainerLow)
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: scheme.outline.withValues(alpha: stronger ? 0.24 : 0.18),
          width: 0.9,
        ),
        boxShadow: stronger
            ? [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: isDark ? 0.20 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      );
    }

    return BoxDecoration(
      color: gradient == null ? palette.cardColor : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: stronger ? 0.14 : 0.10)
            : Colors.white.withValues(alpha: stronger ? 0.68 : 0.55),
        width: 1.1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
          blurRadius: stronger ? 24 : 16,
          offset: Offset(0, stronger ? 12 : 8),
        ),
      ],
    );
  }

  String _formatDurationShort(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Widget _buildSummaryRow() {
    final palette = _palette;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openStats,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: _frostedCardDecoration(
                radius: 18,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.cardColor,
                    palette.cardColor.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_todayMinutes',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: palette.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.homeTodayReadingMinutesLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openStats,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: _frostedCardDecoration(
                radius: 18,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.cardColor,
                    palette.cardColor.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatThousand(_totalMinutes),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: palette.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.homeTotalReadingMinutesLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(String title, String trailing,
      {VoidCallback? action}) {
    final palette = _palette;
    final trailingColor =
        action == null ? palette.secondaryTextColor : palette.accentColor;

    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: palette.primaryTextColor,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: action,
          child: Text(
            trailing,
            style: TextStyle(
              fontSize: 14,
              fontWeight: action == null ? FontWeight.w400 : FontWeight.w600,
              color: trailingColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard() {
    final palette = _palette;
    final plan = _readingPlan;

    if (plan == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _frostedCardDecoration(radius: 20),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: palette.accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              context.l10n.homeGeneratingPlan,
              style: TextStyle(
                fontSize: 14,
                color: palette.secondaryTextColor,
              ),
            ),
          ],
        ),
      );
    }

    final progress = plan.completionRate.clamp(0.0, 1.0);
    final progressPercent = (progress * 100).round();
    final isFocusActive = _focusEndTime != null;
    final focusProgress = isFocusActive
        ? ((_focusMinutes * 60 - _focusRemaining.inSeconds) /
                (_focusMinutes * 60))
            .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _frostedCardDecoration(
        radius: 20,
        stronger: true,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.cardColor,
            palette.cardColor.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor:
                            palette.inactiveDotColor.withValues(alpha: 0.55),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(palette.accentColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$progressPercent%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: palette.primaryTextColor,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.homeCompletedLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.isGoalCompleted
                          ? context.l10n.homeTodayGoalAchieved
                          : context.l10n
                              .homeMinutesRemaining(plan.remainingMinutes),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: palette.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.homeReadOfGoalMinutes(
                        plan.todayReadMinutes,
                        plan.dailyGoalMinutes,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.secondaryTextColor,
                      ),
                    ),
                    if (!plan.isGoalCompleted) ...[
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.homeSessionsToFinishGoal(
                            plan.suggestedSessionsToFinish),
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPlanMetricBadge(
                icon: Icons.local_fire_department_outlined,
                label: context.l10n.homeStreakLabel,
                value: context.l10n.homeDaysCount(plan.streakDays),
              ),
              _buildPlanMetricBadge(
                icon: Icons.calendar_view_week_outlined,
                label: context.l10n.homeWeekAchievedLabel,
                value: context.l10n.homeDaysCount(plan.weekAchievedDays),
              ),
              _buildPlanMetricBadge(
                icon: Icons.timer_outlined,
                label: context.l10n.homeFocusLabel,
                value: context.l10n.homeTimesCount(plan.focusSessionsToday),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...plan.tasks.map((task) => _buildPlanTaskRow(task)),
          if (isFocusActive) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.accentColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: palette.accentColor.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.homeFocusCountdown(
                        _formatDurationShort(_focusRemaining)),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.accentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: focusProgress,
                      backgroundColor:
                          palette.accentColor.withValues(alpha: 0.2),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(palette.accentColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _recommendedPlanBook == null
                      ? null
                      : () => _openBook(_recommendedPlanBook!),
                  icon: const AppBrandIcon(size: 18, borderRadius: 5),
                  label: Text(_recommendedPlanBook == null
                      ? context.l10n.homeGoLibraryRead
                      : context.l10n.continueReading),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isFocusActive ? _cancelFocusTimer : _startFocusTimer,
                  icon: Icon(
                    isFocusActive ? Icons.stop_circle_outlined : Icons.timer,
                    size: 18,
                  ),
                  label: Text(isFocusActive
                      ? context.l10n.homeEndFocus
                      : context.l10n.homeFocusMinutesButton(_focusMinutes)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _showGoalPicker,
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: Text(
                  context.l10n.homeAdjustGoalMinutes(plan.dailyGoalMinutes)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanMetricBadge({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final palette = _palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.primaryTextColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.secondaryTextColor),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTaskRow(ReadingPlanTask task) {
    final palette = _palette;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            task.completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color:
                task.completed ? scheme.tertiary : palette.secondaryTextColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translatePlanTaskTitle(context, task.title),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.primaryTextColor,
                  ),
                ),
                Text(
                  translatePlanTaskDetail(
                      context, task.detail, task.detailParams),
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCard(List<double> dots, int weekPercent) {
    final palette = _palette;
    final colors = dots.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      if (value <= 0.15) return palette.inactiveDotColor;
      if (index <= 2) return palette.accentColor;
      return palette.softAccentColor;
    }).toList(growable: false);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _openStats,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _frostedCardDecoration(
          radius: 18,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.cardColor,
              palette.cardColor.withValues(alpha: 0.72),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  context.l10n.homeWeeklyTrend,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: palette.primaryTextColor,
                    height: 0.95,
                  ),
                ),
                const Spacer(),
                Text(
                  '$weekPercent%',
                  style: TextStyle(
                    fontSize: 14,
                    color: palette.secondaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(7, (index) {
                return Container(
                  width: 24,
                  height: 24,
                  margin: EdgeInsets.only(right: index == 6 ? 0 : 10),
                  decoration: BoxDecoration(
                    color: colors[index],
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCard(List<Book> books) {
    final palette = _palette;
    if (books.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: _frostedCardDecoration(
          radius: 18,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.cardColor,
              palette.cardColor.withValues(alpha: 0.72),
            ],
          ),
        ),
        child: Text(
          context.l10n.homeNoRecentReading,
          style: TextStyle(
            fontSize: 14,
            color: palette.secondaryTextColor,
          ),
        ),
      );
    }

    return Column(
      children: books.map((book) {
        final progress = book.totalPages > 0
            ? ((book.currentPage / book.totalPages) * 100)
                .clamp(0, 100)
                .toStringAsFixed(0)
            : '0';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openBook(book),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: _frostedCardDecoration(
                  radius: 18,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.cardColor,
                      palette.cardColor.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: (book.coverImagePath != null &&
                                book.coverImagePath!.isNotEmpty)
                            ? Image.file(
                                File(book.coverImagePath!),
                                fit: Platform.isAndroid
                                    ? BoxFit.contain
                                    : BoxFit.cover,
                                cacheWidth: (44 *
                                        MediaQuery.of(context).devicePixelRatio)
                                    .round(),
                                errorBuilder: (context, error, stackTrace) {
                                  return GeneratedBookCover(
                                    title: book.title,
                                    author: book.author,
                                  );
                                },
                              )
                            : GeneratedBookCover(
                                title: book.title,
                                author: book.author,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: palette.primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.homeReadingProgressPercent(progress),
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

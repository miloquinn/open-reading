// 文件说明：阅读统计详情页入口，负责数据加载、页面状态与顶层导航。
// 视觉模块按总览、图表、书籍、成就拆分在 detailed_stats/ 目录中。

import 'dart:io';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_services.dart';
import 'package:xxread/services/reading/reading_stats_dao.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/widgets/generated_book_cover.dart';

part 'parts/detailed_stats_achievements_part.dart';
part 'parts/detailed_stats_books_part.dart';
part 'parts/detailed_stats_charts_part.dart';
part 'parts/detailed_stats_heatmap_part.dart';
part 'parts/detailed_stats_overview_part.dart';
part 'parts/detailed_stats_style_part.dart';

class DetailedStatsPage extends StatefulWidget {
  const DetailedStatsPage({super.key});

  @override
  State<DetailedStatsPage> createState() => _DetailedStatsPageState();
}

class _DetailedStatsPageState extends State<DetailedStatsPage>
    with TickerProviderStateMixin {
  final _statsDao = ReadingStatsDao();
  final _bookDao = BookDao();

  late final TabController _tabController;
  late final PageController _pageController;
  bool _isAnimatingFromTabTap = false;

  Map<String, int> _overallStats = {};
  List<Map<String, dynamic>> _dailyStats = [];
  List<Map<String, dynamic>> _bookStats = [];
  Map<int, Map<String, dynamic>> _bookReadingStats = {};
  List<Book> _recentBooks = [];
  Map<int, int> _hourlyDistribution = {};
  Map<String, double> _heatmapData = {};
  Map<String, int> _sessionSummary = {};

  bool _isLoading = true;
  String _selectedTimeRange = '7d';
  int _selectedStatType = 0;

  _StatsPalette get _palette => _StatsPalette.fromTheme(Theme.of(context));

  List<Map<String, dynamic>> get _windowedDailyStats {
    final days = switch (_selectedTimeRange) {
      '7d' => 7,
      '30d' => 30,
      '90d' => 90,
      '1y' => 365,
      _ => _dailyStats.length,
    };
    if (_dailyStats.isEmpty) return const [];
    return _dailyStats.length <= days
        ? _dailyStats
        : _dailyStats.sublist(_dailyStats.length - days);
  }

  String _timeRangeLabel(String range) {
    final l10n = context.l10n;
    return switch (range) {
      '7d' => l10n.statsRange7Days,
      '30d' => l10n.statsRange30Days,
      '90d' => l10n.statsRange90Days,
      '1y' => l10n.statsRange1Year,
      _ => l10n.statsRangeAll,
    };
  }

  double get _averagePagesPerMinute {
    final data = _windowedDailyStats;
    final totalPages = data.fold<int>(
      0,
      (sum, item) => sum + ((item['pagesRead'] as int?) ?? 0),
    );
    final totalMinutes = data.fold<int>(
      0,
      (sum, item) => sum + ((item['readingTime'] as int?) ?? 0),
    );
    return totalMinutes == 0 ? 0 : totalPages / totalMinutes;
  }

  String get _avgSessionDurationLabel {
    final average = _sessionSummary['avgSessionMinutes'] ?? 0;
    return context.l10n.statsMinutes(average);
  }

  String get _maxStreakLabel {
    final persisted = _overallStats['streak'] ?? 0;
    if (persisted > 0) return context.l10n.statsDaysCount(persisted);

    var best = 0;
    var current = 0;
    for (final item in _windowedDailyStats) {
      if (((item['readingTime'] as int?) ?? 0) > 0) {
        current++;
        best = math.max(best, current);
      } else {
        current = 0;
      }
    }
    return context.l10n.statsDaysCount(best);
  }

  String get _focusScoreLabel {
    final data = _windowedDailyStats;
    if (data.isEmpty) return '0%';
    final minutes = data.fold<int>(
      0,
      (sum, item) => sum + ((item['readingTime'] as int?) ?? 0),
    );
    final score = ((minutes / data.length) / 60).clamp(0.0, 1.0) * 100;
    return '${score.round()}%';
  }

  String _inferBestReadingPeriod() {
    final l10n = context.l10n;
    if (_hourlyDistribution.isEmpty ||
        _hourlyDistribution.values.every((value) => value <= 0)) {
      return l10n.statsNoData;
    }

    int sumRange(int start, int end) {
      var total = 0;
      for (var hour = start; hour <= end; hour++) {
        total += _hourlyDistribution[hour] ?? 0;
      }
      return total;
    }

    final ranges = <MapEntry<String, int>>[
      MapEntry(l10n.statsPeriodEarlyMorning, sumRange(5, 8)),
      MapEntry(l10n.statsPeriodMorning, sumRange(9, 11)),
      MapEntry(l10n.statsPeriodAfternoon, sumRange(12, 17)),
      MapEntry(l10n.statsPeriodEvening, sumRange(18, 21)),
      MapEntry(
        l10n.statsPeriodLateNight,
        sumRange(22, 23) + sumRange(0, 4),
      ),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return ranges.first.value <= 0 ? l10n.statsNoData : ranges.first.key;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _pageController = PageController();
    _loadAllStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleTabTap(int index) async {
    if (_isAnimatingFromTabTap || !_pageController.hasClients) return;
    final current =
        (_pageController.page ?? _tabController.index.toDouble()).round();
    if (current == index) return;

    _isAnimatingFromTabTap = true;
    try {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isAnimatingFromTabTap = false;
    }
  }

  void _selectStatType(int index) {
    if (_selectedStatType == index) return;
    setState(() => _selectedStatType = index);
  }

  Future<void> _loadAllStats() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadOverallStats(),
        _loadDailyStats(),
        _loadBookStats(),
        _loadRecentBooks(),
        _loadHourlyDistribution(),
        _loadHeatmapData(),
      ]);
    } catch (_) {
      // 单项统计读取失败时仍展示其余已加载内容与安全空状态。
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHourlyDistribution() async {
    final distribution = await _statsDao.getHourlyReadingDistribution();
    if (mounted) setState(() => _hourlyDistribution = distribution);
  }

  Future<void> _loadHeatmapData() async {
    final heatmap = await _statsDao.getReadingIntensityHeatmap();
    if (mounted) setState(() => _heatmapData = heatmap);
  }

  Future<void> _loadOverallStats() async {
    final summary = await _statsDao.getSummaryStats();
    final achievements = await _statsDao.getAchievementStats();
    final sessions = await _statsDao.getSessionSummary(recentDays: 3650);
    final perBook = await _statsDao.getBookReadingStats();
    final bookCount = await _bookDao.getBooksCount();
    final books = await _bookDao.getAllBooks();

    final sessionPages = perBook.values.fold<int>(
      0,
      (sum, item) => sum + ((item['pagesRead'] as int?) ?? 0),
    );
    final fallbackPages = books.fold<int>(
      0,
      (sum, book) => sum + book.currentPage,
    );

    if (!mounted) return;
    setState(() {
      _overallStats = {
        'totalReadingTime': (summary['total'] ?? 0) ~/ 60,
        'totalPages': sessionPages > 0 ? sessionPages : fallbackPages,
        'totalBooks': bookCount,
        'streak': achievements['consecutiveDays'] ?? 0,
        'maxSessionMinutes': achievements['maxSessionMinutes'] ?? 0,
      };
      _sessionSummary = sessions;
    });
  }

  Future<void> _loadDailyStats() async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 365));
    final raw = await _statsDao.getDailyStatsRange(start, end);
    final byDate = <String, Map<String, dynamic>>{};
    for (final item in raw) {
      final date = item['date'] as String;
      byDate[date] = {
        'date': date,
        'readingTime': (item['duration'] ?? 0) ~/ 60,
        'pagesRead': item['pages'] ?? 0,
        'booksRead': item['books_read'] ?? 0,
      };
    }

    final complete = <Map<String, dynamic>>[];
    for (var offset = 364; offset >= 0; offset--) {
      final date = end.subtract(Duration(days: offset));
      final key = date.toIso8601String().split('T').first;
      complete.add(
        byDate[key] ??
            {
              'date': key,
              'readingTime': 0,
              'pagesRead': 0,
              'booksRead': 0,
            },
      );
    }
    if (mounted) setState(() => _dailyStats = complete);
  }

  Future<void> _loadBookStats() async {
    final perBook = await _statsDao.getBookReadingStats();
    final books = await _bookDao.getAllBooks();
    final result = <Map<String, dynamic>>[];
    for (final book in books) {
      final real = book.id == null ? null : perBook[book.id!];
      final sessionPages = (real?['pagesRead'] as int?) ?? 0;
      result.add({
        'book': book,
        'readingTime': (real?['durationMinutes'] as int?) ?? 0,
        'progress': book.totalPages > 0
            ? (book.currentPage / book.totalPages).clamp(0.0, 1.0)
            : 0.0,
        'pagesRead': sessionPages > 0 ? sessionPages : book.currentPage,
        'totalPages': book.totalPages,
        'sessionCount': (real?['sessionCount'] as int?) ?? 0,
        'lastReadMs': (real?['lastReadMs'] as int?) ?? 0,
      });
    }
    result.sort((a, b) {
      final duration =
          (b['readingTime'] as int).compareTo(a['readingTime'] as int);
      return duration != 0
          ? duration
          : (b['pagesRead'] as int).compareTo(a['pagesRead'] as int);
    });
    if (!mounted) return;
    setState(() {
      _bookReadingStats = perBook;
      _bookStats = result;
    });
  }

  Future<void> _loadRecentBooks() async {
    final books = await _bookDao.getAllBooks();
    final perBook = _bookReadingStats.isNotEmpty
        ? _bookReadingStats
        : await _statsDao.getBookReadingStats();
    final sorted = [...books]..sort((a, b) {
        final aLast =
            a.id == null ? 0 : (perBook[a.id!]?['lastReadMs'] as int?) ?? 0;
        final bLast =
            b.id == null ? 0 : (perBook[b.id!]?['lastReadMs'] as int?) ?? 0;
        return aLast == bLast
            ? b.currentPage.compareTo(a.currentPage)
            : bLast.compareTo(aLast);
      });
    if (mounted) setState(() => _recentBooks = sorted.take(5).toList());
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return Scaffold(
      backgroundColor: palette.pageEnd,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.34, 1],
            colors: [palette.pageStart, palette.pageMiddle, palette.pageEnd],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 12),
              _buildTabBar(),
              const SizedBox(height: 4),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: palette.accent,
                          strokeWidth: 2.5,
                        ),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        physics: const PageScrollPhysics(),
                        itemCount: 4,
                        onPageChanged: (index) {
                          if (_tabController.index != index) {
                            _tabController.index = index;
                          }
                        },
                        itemBuilder: (context, index) => switch (index) {
                          0 => _buildOverviewTab(),
                          1 => _buildChartsTab(),
                          2 => _buildBooksTab(),
                          3 => _buildAchievementsTab(),
                          _ => const SizedBox.shrink(),
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final palette = _palette;
    final compact = MediaQuery.sizeOf(context).width < 390;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                Material(
                  color: palette.cardStrong,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: palette.ink,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.l10n.statsDetailedTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 27 : 32,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildTimeRangeSelector(compact: compact),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector({required bool compact}) {
    final palette = _palette;
    return PopupMenuButton<String>(
      initialValue: _selectedTimeRange,
      tooltip: _timeRangeLabel(_selectedTimeRange),
      onSelected: (value) => setState(() => _selectedTimeRange = value),
      itemBuilder: (context) => ['7d', '30d', '90d', '1y', 'all']
          .map(
            (range) => PopupMenuItem(
              value: range,
              child: Text(_timeRangeLabel(range)),
            ),
          )
          .toList(),
      child: Container(
        height: 42,
        padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 13),
        decoration: BoxDecoration(
          color: palette.softAccent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: palette.accent,
              size: 16,
            ),
            if (!compact) ...[
              const SizedBox(width: 7),
              Text(
                _timeRangeLabel(_selectedTimeRange),
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              color: palette.accent,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final palette = _palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (index) => _handleTabTap(index),
              dividerColor: Colors.transparent,
              splashBorderRadius: BorderRadius.circular(14),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: palette.softAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              labelColor: palette.accent,
              unselectedLabelColor: palette.mutedInk,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: [
                Tab(text: context.l10n.statsTabOverview),
                Tab(text: context.l10n.statsTabCharts),
                Tab(text: context.l10n.statsTabBooks),
                Tab(text: context.l10n.statsTabAchievements),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabScrollBody({required Widget child}) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.viewPaddingOf(context).bottom + 28,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: child,
        ),
      ),
    );
  }
}

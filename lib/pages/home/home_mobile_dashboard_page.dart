// 文件说明：响应式首页，聚焦继续阅读、阅读节奏与最近阅读。
// 技术要点：Flutter UI、本地阅读统计、文件封面渲染。

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/core/reader/native_reader_service.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/reader/book_source_reader_page.dart';
import 'package:xxread/pages/reading_stats/detailed_stats_page.dart';
import 'package:xxread/services/books/book_services.dart';
import 'package:xxread/services/library/library_event_bus_service.dart';
import 'package:xxread/services/reading/reading_stats_dao.dart';
import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/layout_helper.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_transitions.dart';
import 'package:xxread/widgets/generated_book_cover.dart';
import 'package:xxread/widgets/side_toast.dart';

import 'home_mobile_chrome.dart';

class _HomeContentMetrics {
  final double refreshEdgeOffset;
  final double horizontalPadding;
  final double contentTopPadding;
  final double contentBottomPadding;

  const _HomeContentMetrics({
    required this.refreshEdgeOffset,
    required this.horizontalPadding,
    required this.contentTopPadding,
    required this.contentBottomPadding,
  });
}

class _HomePalette {
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color cardColor;
  final Color heroColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color accentColor;
  final Color outlineColor;
  final Color mutedColor;
  final Color shadowColor;

  const _HomePalette({
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.cardColor,
    required this.heroColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.outlineColor,
    required this.mutedColor,
    required this.shadowColor,
  });

  factory _HomePalette.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return _HomePalette(
      backgroundStart: Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.10 : 0.045),
        scheme.surface,
      ),
      backgroundEnd: scheme.surface,
      cardColor: scheme.surfaceContainerLow,
      heroColor: Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.16 : 0.085),
        scheme.surfaceContainerLow,
      ),
      primaryTextColor: scheme.onSurface,
      secondaryTextColor: scheme.onSurfaceVariant,
      accentColor: scheme.primary,
      outlineColor: scheme.outlineVariant.withValues(
        alpha: isDark ? 0.56 : 0.7,
      ),
      mutedColor: scheme.surfaceContainerHighest,
      shadowColor: scheme.shadow.withValues(alpha: isDark ? 0.18 : 0.055),
    );
  }
}

class HomeDashboardController extends ChangeNotifier {
  void refresh() => notifyListeners();
}

class HomeMobileDashboardPage extends StatefulWidget {
  const HomeMobileDashboardPage({super.key, this.controller});

  final HomeDashboardController? controller;

  @visibleForTesting
  static Widget? buildOnlineReader({
    required Book book,
    required BookSourceClient client,
    required BookSourceShelfService shelfService,
  }) {
    if (!book.isOnline) return null;
    return BookSourceReaderPage(
      source: shelfService.sourceFrom(book),
      book: shelfService.sourceBookFrom(book),
      client: client,
      shelfService: shelfService,
    );
  }

  @override
  State<HomeMobileDashboardPage> createState() =>
      _HomeMobileDashboardPageState();
}

class _HomeMobileDashboardPageState extends State<HomeMobileDashboardPage>
    with WidgetsBindingObserver {
  final _statsDao = ReadingStatsDao();
  final _bookDao = BookDao();
  late final BookSourceClient _sourceClient;
  late final BookSourceShelfService _sourceShelfService;
  StreamSubscription<void>? _libraryChangedSubscription;

  Map<String, int> _summaryStats = {};
  List<Map<String, dynamic>> _weeklyData = [];
  List<Book> _recentBooks = [];
  bool _isInitialLoading = true;
  int _loadGeneration = 0;

  _HomePalette get _palette => _HomePalette.fromTheme(Theme.of(context));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sourceClient = BookSourceClient();
    _sourceShelfService = BookSourceShelfService(client: _sourceClient);
    widget.controller?.addListener(_handleRefreshRequest);
    _loadAllStats();
    _libraryChangedSubscription = LibraryEventBus().stream.listen((_) {
      if (mounted) _loadAllStats();
    });
  }

  @override
  void didUpdateWidget(covariant HomeMobileDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller?.removeListener(_handleRefreshRequest);
    widget.controller?.addListener(_handleRefreshRequest);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAllStats();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?.removeListener(_handleRefreshRequest);
    _libraryChangedSubscription?.cancel();
    super.dispose();
  }

  void _handleRefreshRequest() {
    if (mounted) _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    final loadGeneration = ++_loadGeneration;
    try {
      final summaryFuture = _statsDao.getSummaryStats();
      final weeklyFuture = _statsDao.getWeeklyChartData();
      final recentBooksFuture = _loadRecentBooks();

      final summary = await summaryFuture;
      final weekly = await weeklyFuture;
      final recentBooks = await recentBooksFuture;

      if (!mounted || loadGeneration != _loadGeneration) return;
      setState(() {
        _summaryStats = summary;
        _weeklyData = weekly;
        _recentBooks = recentBooks;
        _isInitialLoading = false;
      });
    } catch (_) {
      if (!mounted || loadGeneration != _loadGeneration) return;
      setState(() => _isInitialLoading = false);
    }
  }

  Future<List<Book>> _loadRecentBooks() async {
    try {
      final orderedBookIds = await _statsDao.getRecentBookIds(limit: 6);
      final books = <Book>[];
      final seen = <int>{};

      for (final id in orderedBookIds) {
        final book = await _bookDao.getBookById(id);
        if (book == null) continue;
        books.add(book);
        seen.add(id);
      }

      if (books.isNotEmpty) {
        return books.take(6).toList(growable: false);
      }

      final allBooks = await _bookDao.getAllBooks();
      final fallback = allBooks.where((book) => book.currentPage > 0).toList()
        ..sort((a, b) {
          final progressComparison = b.currentPage.compareTo(a.currentPage);
          return progressComparison != 0
              ? progressComparison
              : b.importDate.compareTo(a.importDate);
        });
      return fallback.take(6).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  _HomeContentMetrics _computeMetrics(
    MediaQueryData mediaQuery, {
    required bool useRailNavigation,
  }) {
    final mobileChrome = HomeMobileChromeScope.of(context);
    return _HomeContentMetrics(
      refreshEdgeOffset: useRailNavigation
          ? mediaQuery.viewPadding.top
          : mobileChrome.topBarHeight,
      horizontalPadding: useRailNavigation
          ? (mediaQuery.size.width >= 1440 ? 36 : 28)
          : 18,
      contentTopPadding: useRailNavigation
          ? mediaQuery.viewPadding.top + 28
          : mobileChrome.pageTopPadding + 6,
      contentBottomPadding: useRailNavigation
          ? mediaQuery.viewPadding.bottom + 36
          : mobileChrome.pageBottomPadding + 12,
    );
  }

  int get _todayMinutes => (_summaryStats['today'] ?? 0) ~/ 60;
  int get _weekMinutes => (_summaryStats['week'] ?? 0) ~/ 60;
  int get _totalMinutes => (_summaryStats['total'] ?? 0) ~/ 60;

  String _formatNumber(int number) {
    final raw = number.toString();
    return raw.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  List<double> _normalizedWeekBars() {
    final values = _weeklyData.take(7).map((item) {
      final raw =
          item['readingTime'] ??
          item['duration'] ??
          item['minutes'] ??
          item['value'] ??
          0;
      return raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
    }).toList();

    while (values.length < 7) {
      values.add(0);
    }
    if (values.isEmpty) return List<double>.filled(7, 0);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    if (maxValue <= 0) return List<double>.filled(7, 0);
    return values.map((value) => value / maxValue).toList(growable: false);
  }

  List<String> _weekDayLabels() {
    String labelFor(int weekday) => switch (weekday) {
      DateTime.monday => context.l10n.weekdayMonShort,
      DateTime.tuesday => context.l10n.weekdayTueShort,
      DateTime.wednesday => context.l10n.weekdayWedShort,
      DateTime.thursday => context.l10n.weekdayThuShort,
      DateTime.friday => context.l10n.weekdayFriShort,
      DateTime.saturday => context.l10n.weekdaySatShort,
      _ => context.l10n.weekdaySunShort,
    };

    return List.generate(7, (index) {
      final dataDay = index < _weeklyData.length
          ? _weeklyData[index]['day']
          : null;
      final weekday = dataDay is int
          ? dataDay
          : DateTime.now().subtract(Duration(days: 6 - index)).weekday;
      return labelFor(weekday);
    }, growable: false);
  }

  void _openStats() {
    Navigator.of(context).pushWithSlideScale(const DetailedStatsPage());
  }

  Future<void> _openBook(Book book) async {
    final openingActivity = BookOpenTransition.beginActivity();
    try {
      final fullBook = book.id == null
          ? book
          : await _bookDao.getBookById(book.id!);
      if (fullBook == null || !mounted) return;

      if (fullBook.isOnline) {
        try {
          final reader = HomeMobileDashboardPage.buildOnlineReader(
            book: fullBook,
            client: _sourceClient,
            shelfService: _sourceShelfService,
          )!;
          final route = BookOpenTransition.createRoute<void>(
            reader,
            origin: ReaderPageTransitionOrigin.home,
            waitForReaderReady: true,
          );
          await BookOpenTransition.push<void>(context, route);
        } catch (error) {
          if (mounted) {
            showSideToast(
              context,
              context.l10n.bookSourceOnlineDataBroken('$error'),
              kind: SideToastKind.error,
            );
          }
        }
      } else {
        await NativeReaderService.openBook(
          context,
          fullBook,
          origin: ReaderPageTransitionOrigin.home,
        );
      }
      if (mounted) await _loadAllStats();
    } finally {
      openingActivity.dispose();
    }
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
    final palette = _palette;
    final maxWidth = useRailNavigation
        ? (mediaQuery.size.width >= 1600 ? 1080.0 : 920.0)
        : double.infinity;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.backgroundStart, palette.backgroundEnd],
          stops: const [0, 0.58],
        ),
      ),
      child: _isInitialLoading
          ? Center(child: CircularProgressIndicator(color: palette.accentColor))
          : RefreshIndicator(
              onRefresh: _loadAllStats,
              edgeOffset: metrics.refreshEdgeOffset,
              color: palette.accentColor,
              backgroundColor: palette.cardColor,
              child: ListView(
                scrollCacheExtent: const ScrollCacheExtent.pixels(720),
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
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (useRailNavigation) ...[
                            _buildPageHeading(),
                            const SizedBox(height: 28),
                          ],
                          _buildContinueReadingCard(
                            _recentBooks.isEmpty ? null : _recentBooks.first,
                            spacious: useRailNavigation,
                          ),
                          const SizedBox(height: 18),
                          _buildReadingRhythmCard(_normalizedWeekBars()),
                          if (_recentBooks.length > 1) ...[
                            const SizedBox(height: 28),
                            _buildSectionHeading(
                              context.l10n.homeRecentReading,
                            ),
                            const SizedBox(height: 14),
                            _buildRecentBooks(
                              _recentBooks.skip(1).toList(growable: false),
                              useGrid: useRailNavigation,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPageHeading() {
    final palette = _palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.home,
          style: TextStyle(
            color: palette.primaryTextColor,
            fontSize: 34,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _todayMinutes > 0
              ? context.l10n.homeTodayReadingKeepRhythm
              : context.l10n.homeTodayReadingPrompt,
          style: TextStyle(color: palette.secondaryTextColor, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildContinueReadingCard(Book? book, {required bool spacious}) {
    final palette = _palette;
    final radius = BorderRadius.circular(26);
    if (book == null) {
      return Container(
        key: const ValueKey('home-continue-reading-empty-card'),
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(color: palette.heroColor, radius: 26),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 72,
              decoration: BoxDecoration(
                color: palette.accentColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: palette.accentColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.homeTodayReadingJourneyStart,
                    style: TextStyle(
                      color: palette.primaryTextColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.homeNoRecentReading,
                    style: TextStyle(
                      color: palette.secondaryTextColor,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final progress = book.totalPages <= 0
        ? 0.0
        : (book.currentPage / book.totalPages).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final coverWidth = spacious ? 118.0 : 102.0;
    final coverHeight = spacious ? 164.0 : 142.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openBook(book),
        borderRadius: radius,
        child: Ink(
          key: const ValueKey('home-continue-reading-card'),
          padding: EdgeInsets.all(spacious ? 24 : 18),
          decoration: _cardDecoration(color: palette.heroColor, radius: 26),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildBookCover(
                book,
                width: coverWidth,
                height: coverHeight,
                radius: 14,
                elevated: true,
              ),
              SizedBox(width: spacious ? 28 : 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: palette.accentColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          context.l10n.continueReading,
                          style: TextStyle(
                            color: palette.accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacious ? 22 : 16),
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryTextColor,
                        fontSize: spacious ? 28 : 23,
                        height: 1.16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: spacious ? 24 : 18),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: palette.mutedColor,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                palette.accentColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$percent%',
                          style: TextStyle(
                            color: palette.secondaryTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacious ? 18 : 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.continueReading,
                          style: TextStyle(
                            color: palette.primaryTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: palette.accentColor,
                        ),
                      ],
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

  Widget _buildReadingRhythmCard(List<double> bars) {
    final palette = _palette;
    final weekdays = _weekDayLabels();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openStats,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          key: const ValueKey('home-reading-rhythm-card'),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: _cardDecoration(color: palette.cardColor, radius: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.homeReadingRhythm,
                    style: TextStyle(
                      color: palette.primaryTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: palette.secondaryTextColor,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _buildMetric(
                    value: _formatNumber(_todayMinutes),
                    label: context.l10n.statsToday,
                  ),
                  _buildMetricDivider(),
                  _buildMetric(
                    value: _formatNumber(_weekMinutes),
                    label: context.l10n.homeWeeklyTotal,
                  ),
                  _buildMetricDivider(),
                  _buildMetric(
                    value: _formatNumber(_totalMinutes),
                    label: context.l10n.homeTotalReading,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 62,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final value = bars[index];
                    final height = value <= 0 ? 5.0 : 8 + (value * 28);
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: 7,
                            height: height,
                            decoration: BoxDecoration(
                              color: value <= 0
                                  ? palette.mutedColor
                                  : palette.accentColor.withValues(
                                      alpha: 0.48 + value * 0.52,
                                    ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            weekdays[index],
                            style: TextStyle(
                              color: palette.secondaryTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric({required String value, required String label}) {
    final palette = _palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: palette.primaryTextColor,
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  context.l10n.unitMinute,
                  style: TextStyle(
                    color: palette.secondaryTextColor,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.secondaryTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    final palette = _palette;
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: palette.outlineColor,
    );
  }

  Widget _buildSectionHeading(String title) {
    final palette = _palette;
    return Text(
      title,
      style: TextStyle(
        color: palette.primaryTextColor,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
    );
  }

  Widget _buildRecentBooks(List<Book> books, {required bool useGrid}) {
    if (useGrid) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 14.0;
          final columns = constraints.maxWidth >= 900 ? 5 : 4;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: 18,
            children: books
                .map(
                  (book) =>
                      SizedBox(width: width, child: _buildRecentBookItem(book)),
                )
                .toList(growable: false),
          );
        },
      );
    }

    return SizedBox(
      height: 206,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) =>
            SizedBox(width: 112, child: _buildRecentBookItem(books[index])),
      ),
    );
  }

  Widget _buildRecentBookItem(Book book) {
    final palette = _palette;
    final progress = book.totalPages <= 0
        ? 0
        : ((book.currentPage / book.totalPages) * 100).clamp(0, 100).round();
    return Semantics(
      button: true,
      label:
          '${book.title}，${context.l10n.homeReadingProgressPercent('$progress')}',
      child: InkWell(
        onTap: () => _openBook(book),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 0.72,
              child: _buildBookCover(
                book,
                width: double.infinity,
                height: double.infinity,
                radius: 12,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.primaryTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$progress%',
              style: TextStyle(color: palette.secondaryTextColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCover(
    Book book, {
    required double width,
    required double height,
    required double radius,
    bool elevated = false,
  }) {
    final fallback = GeneratedBookCover(title: book.title, author: book.author);
    final coverPath = book.coverImagePath?.trim() ?? '';
    final cover = !kIsWeb && coverPath.isNotEmpty
        ? Image.file(
            File(coverPath),
            fit: LayoutHelper.bookCoverFit,
            cacheWidth: width.isFinite
                ? (width * MediaQuery.devicePixelRatioOf(context)).round()
                : null,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;

    return Container(
      width: width,
      height: height,
      decoration: elevated
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: _palette.shadowColor.withValues(alpha: 0.9),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: cover,
      ),
    );
  }

  BoxDecoration _cardDecoration({
    required Color color,
    required double radius,
  }) {
    final palette = _palette;
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: palette.outlineColor, width: 0.8),
      boxShadow: [
        BoxShadow(
          color: palette.shadowColor,
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

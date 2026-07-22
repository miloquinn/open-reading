part of '../detailed_stats_page.dart';

extension _DetailedStatsOverviewView on _DetailedStatsPageState {
  Widget _buildOverviewTab() {
    return _buildTabScrollBody(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 900;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOverviewHero(),
              const SizedBox(height: 20),
              _buildStatsGrid(),
              const SizedBox(height: 20),
              if (twoColumns) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTodayProgress()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildReadingHabits()),
                  ],
                ),
                const SizedBox(height: 20),
                _buildRecentBooks(),
              ] else ...[
                _buildTodayProgress(),
                const SizedBox(height: 20),
                _buildRecentBooks(),
                const SizedBox(height: 20),
                _buildReadingHabits(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewHero() {
    final palette = _palette;
    final l10n = context.l10n;
    final totalMinutes = _overallStats['totalReadingTime'] ?? 0;
    final totalHours = (totalMinutes / 60).toStringAsFixed(1);
    final streak = _overallStats['streak'] ?? 0;
    final todayMinutes = _dailyStats.isEmpty
        ? 0
        : (_dailyStats.last['readingTime'] as int?) ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: palette.hero,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.card.withValues(alpha: 0.64),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: palette.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  l10n.statsReadingOverview,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
              ),
              Text(
                _timeRangeLabel(_selectedTimeRange),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.mutedInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            l10n.statsCumulativeHours(totalHours),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: palette.ink,
              height: 1.08,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.statsStreakEncouragement(streak),
            style: TextStyle(
              fontSize: 14,
              color: palette.mutedInk,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _buildOverviewChip(
                Icons.today_rounded,
                l10n.todayReading,
                l10n.statsMinutes(todayMinutes),
              ),
              _buildOverviewChip(
                Icons.timer_outlined,
                l10n.statsAvgSession,
                _avgSessionDurationLabel,
              ),
              _buildOverviewChip(
                Icons.local_fire_department_outlined,
                l10n.statsConsecutiveDays,
                l10n.statsDaysCount(streak),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewChip(IconData icon, String label, String value) {
    final palette = _palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: palette.ink.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.mutedInk),
          const SizedBox(width: 6),
          Text(
            '$label · $value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.mutedInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final l10n = context.l10n;
    final palette = _palette;
    final stats = [
      (
        l10n.statsTotalReadingTime,
        '${_overallStats['totalReadingTime'] ?? 0}',
        l10n.unitMinute,
        Icons.schedule_rounded,
        palette.accent,
      ),
      (
        l10n.statsTotalPagesRead,
        '${_overallStats['totalPages'] ?? 0}',
        l10n.statsUnitPage,
        Icons.menu_book_rounded,
        const Color(0xFF5E7893),
      ),
      (
        l10n.statsBooksReadCount,
        '${_overallStats['totalBooks'] ?? 0}',
        l10n.unitBook,
        Icons.library_books_rounded,
        const Color(0xFF748C72),
      ),
      (
        l10n.statsConsecutiveDays,
        '${_overallStats['streak'] ?? 0}',
        l10n.unitDay,
        Icons.local_fire_department_rounded,
        const Color(0xFFAA7A55),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: columns == 4 ? 1.12 : 1.26,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            return _buildStatCard(
              title: stat.$1,
              value: stat.$2,
              unit: stat.$3,
              icon: stat.$4,
              accent: stat.$5,
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color accent,
  }) {
    final palette = _palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardStrong,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const Spacer(),
              Container(
                width: 22,
                height: 3,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                      letterSpacing: -0.8,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: palette.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayProgress() {
    final palette = _palette;
    final today = _dailyStats.isEmpty
        ? <String, dynamic>{'readingTime': 0, 'pagesRead': 0}
        : _dailyStats.last;
    final minutes = (today['readingTime'] as int?) ?? 0;
    final pages = (today['pagesRead'] as int?) ?? 0;
    const minuteTarget = 60;
    const pageTarget = 20;
    final progress = (minutes / minuteTarget).clamp(0.0, 1.0);

    return _buildPaperSection(
      title: context.l10n.statsTodayProgress,
      icon: Icons.today_rounded,
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        color: palette.accent,
                        backgroundColor: palette.softAccent,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            color: palette.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.statsCompleted,
                          style: TextStyle(
                            color: palette.mutedInk,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.statsMinutes(minutes),
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.statsMinutesOfTarget(minutes, minuteTarget),
                      style: TextStyle(color: palette.mutedInk, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildProgressLine(
            context.l10n.readingTime,
            context.l10n.statsMinutesOfTarget(minutes, minuteTarget),
            progress,
            palette.accent,
          ),
          const SizedBox(height: 15),
          _buildProgressLine(
            context.l10n.statsPagesRead,
            context.l10n.statsPagesOfTarget(pages, pageTarget),
            (pages / pageTarget).clamp(0.0, 1.0),
            const Color(0xFF748C72),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBooks() {
    final palette = _palette;
    return _buildPaperSection(
      title: context.l10n.recentBooks,
      icon: Icons.bookmarks_rounded,
      child: _recentBooks.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  context.l10n.statsNoData,
                  style: TextStyle(color: palette.mutedInk),
                ),
              ),
            )
          : Column(
              children: _recentBooks.asMap().entries.map((entry) {
                final book = entry.value;
                final progress = book.totalPages > 0
                    ? (book.currentPage / book.totalPages).clamp(0.0, 1.0)
                    : 0.0;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == _recentBooks.length - 1 ? 0 : 14,
                  ),
                  child: Row(
                    children: [
                      _buildBookCover(book, 44, 62),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              book.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.mutedInk,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 9),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                color: palette.accent,
                                backgroundColor: palette.softAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: palette.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildReadingHabits() {
    final l10n = context.l10n;
    return _buildPaperSection(
      title: l10n.statsReadingHabits,
      icon: Icons.psychology_alt_rounded,
      child: Column(
        children: [
          _buildHabitItem(
            l10n.statsBestReadingPeriod,
            _inferBestReadingPeriod(),
            Icons.wb_twilight_rounded,
          ),
          _buildHabitItem(
            l10n.statsAvgSessionReading,
            _avgSessionDurationLabel,
            Icons.hourglass_bottom_rounded,
          ),
          _buildHabitItem(
            l10n.statsMaxStreakDays,
            _maxStreakLabel,
            Icons.local_fire_department_rounded,
          ),
          _buildHabitItem(
            l10n.statsFocusScore,
            _focusScoreLabel,
            Icons.center_focus_strong_rounded,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHabitItem(
    String title,
    String value,
    IconData icon, {
    bool isLast = false,
  }) {
    final palette = _palette;
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 15),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 15),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.ink.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: palette.mutedInk, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: palette.mutedInk,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: palette.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

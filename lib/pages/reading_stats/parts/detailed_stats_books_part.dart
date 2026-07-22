part of '../detailed_stats_page.dart';

extension _DetailedStatsBooksView on _DetailedStatsPageState {
  Widget _buildBooksTab() {
    return _buildTabScrollBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBooksSummary(),
          const SizedBox(height: 20),
          _buildBooksRanking(),
        ],
      ),
    );
  }

  Widget _buildBooksSummary() {
    final palette = _palette;
    final completed = _bookStats
        .where((item) => (item['progress'] as double) >= 1)
        .length;
    final inProgress = _bookStats.where((item) {
      final progress = item['progress'] as double;
      return progress > 0 && progress < 1;
    }).length;
    final totalMinutes = _bookStats.fold<int>(
      0,
      (sum, item) => sum + ((item['readingTime'] as int?) ?? 0),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.hero,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 24,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.library_books_rounded,
                color: palette.accent,
                size: 21,
              ),
              const SizedBox(width: 9),
              Text(
                context.l10n.statsBookCount,
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildSummaryMetric(
                context.l10n.statsTotal,
                '${_bookStats.length}',
              ),
              _buildSummaryMetric(context.l10n.statsCompleted, '$completed'),
              _buildSummaryMetric(context.l10n.statsInProgress, '$inProgress'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: palette.ink.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, color: palette.mutedInk, size: 16),
                const SizedBox(width: 7),
                Text(
                  context.l10n.statsMinutes(totalMinutes),
                  style: TextStyle(
                    color: palette.mutedInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value) {
    final palette = _palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: palette.ink,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              color: palette.mutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksRanking() {
    final palette = _palette;
    final hasDuration = _bookStats.any(
      (item) => (item['readingTime'] as int) > 0,
    );
    final title = hasDuration
        ? context.l10n.statsDurationRanking
        : context.l10n.statsProgressRanking;

    return _buildPaperSection(
      title: title,
      icon: Icons.format_list_numbered_rounded,
      child: _bookStats.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  context.l10n.statsNoData,
                  style: TextStyle(color: palette.mutedInk),
                ),
              ),
            )
          : Column(
              children: _bookStats.take(10).toList().asMap().entries.map((e) {
                final item = e.value;
                final book = item['book'] as Book;
                return _buildRankingItem(
                  book: book,
                  rank: e.key + 1,
                  readingTime: item['readingTime'] as int,
                  pagesRead: item['pagesRead'] as int,
                  sessionCount: item['sessionCount'] as int,
                  progress: (item['progress'] as double).clamp(0.0, 1.0),
                  isLast: e.key == math.min(9, _bookStats.length - 1),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRankingItem({
    required Book book,
    required int rank,
    required int readingTime,
    required int pagesRead,
    required int sessionCount,
    required double progress,
    required bool isLast,
  }) {
    final palette = _palette;
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 27,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: TextStyle(
                color: rank <= 3 ? palette.accent : palette.mutedInk,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _buildBookCover(book, 46, 64),
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
                  readingTime > 0
                      ? '${context.l10n.statsMinutes(readingTime)} · ${context.l10n.statsSessionCount(sessionCount)}'
                      : context.l10n.statsPagesCount(pagesRead),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.mutedInk, fontSize: 11),
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

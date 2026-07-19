part of '../detailed_stats_page.dart';

extension _DetailedStatsHeatmapView on _DetailedStatsPageState {
  Widget _buildReadingHeatmap() {
    final palette = _palette;
    return _buildPaperSection(
      title: context.l10n.statsReadingContinuity,
      icon: Icons.grid_view_rounded,
      trailing: Text(
        context.l10n.statsCurrentStreak(_overallStats['streak'] ?? 0),
        style: TextStyle(
          color: palette.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Column(
        children: [
          _buildHeatmapGrid(),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                context.l10n.statsHeatmapLess,
                style: TextStyle(color: palette.mutedInk, fontSize: 10),
              ),
              const SizedBox(width: 7),
              ...List.generate(5, (index) {
                return Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color:
                        palette.accent.withValues(alpha: 0.12 + (index * 0.2)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
              const SizedBox(width: 3),
              Text(
                context.l10n.statsHeatmapMore,
                style: TextStyle(color: palette.mutedInk, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    final palette = _palette;
    final l10n = context.l10n;
    final weekDays = [
      l10n.weekdaySunShort,
      l10n.weekdayMonShort,
      l10n.weekdayTueShort,
      l10n.weekdayWedShort,
      l10n.weekdayThuShort,
      l10n.weekdayFriShort,
      l10n.weekdaySatShort,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final weeks = constraints.maxWidth < 330 ? 10 : 13;
        return Column(
          children: List.generate(7, (day) {
            return Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    weekDays[day],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.mutedInk,
                      fontSize: 9,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ...List.generate(weeks, (week) {
                  final intensity = _readingIntensity(
                    week,
                    day,
                    weeks: weeks,
                  );
                  return Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: intensity > 0
                              ? palette.accent.withValues(alpha: intensity)
                              : palette.ink.withValues(alpha: 0.055),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        );
      },
    );
  }

  double _readingIntensity(
    int week,
    int day, {
    required int weeks,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentSunday = today.subtract(Duration(days: today.weekday % 7));
    final firstSunday = currentSunday.subtract(Duration(days: (weeks - 1) * 7));
    final target = firstSunday.add(Duration(days: (week * 7) + day));
    if (target.isAfter(today) || today.difference(target).inDays > 90) {
      return 0;
    }
    final key = target.toIso8601String().split('T').first;
    return (_heatmapData[key] ?? 0).clamp(0.0, 1.0);
  }
}

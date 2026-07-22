part of '../detailed_stats_page.dart';

extension _DetailedStatsAchievementsView on _DetailedStatsPageState {
  Widget _buildAchievementsTab() {
    return _buildTabScrollBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAchievementsOverview(),
          const SizedBox(height: 20),
          _buildAchievementsList(),
        ],
      ),
    );
  }

  Widget _buildAchievementsOverview() {
    final palette = _palette;
    final achievements = _achievementItems();
    final achieved = achievements.where((item) => item.achieved).length;
    final progress = achievements.isEmpty
        ? 0.0
        : achieved / achievements.length;

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
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    color: palette.accent,
                    backgroundColor: palette.ink.withValues(alpha: 0.08),
                  ),
                ),
                Icon(
                  Icons.emoji_events_rounded,
                  color: palette.accent,
                  size: 31,
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
                  context.l10n.statsAchievements,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  context.l10n.statsAchievementsSummary(
                    achieved,
                    achievements.length - achieved,
                  ),
                  style: TextStyle(
                    color: palette.mutedInk,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_AchievementItem> _achievementItems() {
    final l10n = context.l10n;
    final totalMinutes = _overallStats['totalReadingTime'] ?? 0;
    final totalPages = _overallStats['totalPages'] ?? 0;
    final totalBooks = _overallStats['totalBooks'] ?? 0;
    final streak = _overallStats['streak'] ?? 0;

    return [
      _AchievementItem(
        title: l10n.statsAchievementFirstReadTitle,
        description: l10n.statsAchievementFirstReadDesc,
        icon: Icons.auto_stories_rounded,
        color: _palette.accent,
        achieved: totalMinutes > 0,
        progress: totalMinutes > 0 ? 1 : 0,
      ),
      _AchievementItem(
        title: l10n.statsAchievementNoviceTitle,
        description: l10n.statsAchievementNoviceDesc,
        icon: Icons.timer_rounded,
        color: const Color(0xFF748C72),
        achieved: totalMinutes >= 600,
        progress: (totalMinutes / 600).clamp(0.0, 1.0),
      ),
      _AchievementItem(
        title: l10n.statsAchievementBookwormTitle,
        description: l10n.statsAchievementBookwormDesc,
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFAA7A55),
        achieved: totalMinutes >= 6000,
        progress: (totalMinutes / 6000).clamp(0.0, 1.0),
      ),
      _AchievementItem(
        title: l10n.statsAchievementExpertTitle,
        description: l10n.statsAchievementExpertDesc,
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF6C8298),
        achieved: streak >= 7,
        progress: (streak / 7).clamp(0.0, 1.0),
      ),
      _AchievementItem(
        title: l10n.statsAchievementOceanTitle,
        description: l10n.statsAchievementOceanDesc,
        icon: Icons.waves_rounded,
        color: const Color(0xFF5A8993),
        achieved: totalPages >= 10000,
        progress: (totalPages / 10000).clamp(0.0, 1.0),
      ),
      _AchievementItem(
        title: l10n.statsAchievementScholarTitle,
        description: l10n.statsAchievementScholarDesc,
        icon: Icons.school_rounded,
        color: const Color(0xFF817A70),
        achieved: totalBooks >= 10,
        progress: (totalBooks / 10).clamp(0.0, 1.0),
      ),
      _AchievementItem(
        title: l10n.statsAchievementMarathonTitle,
        description: l10n.statsAchievementMarathonDesc,
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF667A9A),
        achieved: streak >= 30,
        progress: (streak / 30).clamp(0.0, 1.0),
      ),
      _AchievementItem(
        title: l10n.statsAchievementFocusTitle,
        description: l10n.statsAchievementFocusDesc,
        icon: Icons.center_focus_strong_rounded,
        color: const Color(0xFF9A6F68),
        achieved: totalMinutes >= 30000,
        progress: (totalMinutes / 30000).clamp(0.0, 1.0),
      ),
    ];
  }

  Widget _buildAchievementsList() {
    final items = _achievementItems();
    return Column(
      children: items.asMap().entries.map((entry) {
        final item = entry.value;
        return Padding(
          padding: EdgeInsets.only(
            bottom: entry.key == items.length - 1 ? 0 : 14,
          ),
          child: _buildAchievementCard(item),
        );
      }).toList(),
    );
  }

  Widget _buildAchievementCard(_AchievementItem item) {
    final palette = _palette;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: palette.cardStrong,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: item.achieved
              ? item.color.withValues(alpha: 0.26)
              : palette.border,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: item.achieved ? 0.15 : 0.07),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              item.icon,
              color: item.achieved
                  ? item.color
                  : palette.mutedInk.withValues(alpha: 0.55),
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.achieved)
                      Icon(
                        Icons.check_circle_rounded,
                        color: item.color,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.description,
                  style: TextStyle(
                    color: palette.mutedInk,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (!item.achieved) ...[
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: item.progress,
                            minHeight: 6,
                            color: item.color,
                            backgroundColor: item.color.withValues(alpha: 0.10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.statsProgressPercent(
                          (item.progress * 100).round(),
                        ),
                        style: TextStyle(
                          color: item.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool achieved;
  final double progress;

  const _AchievementItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.achieved,
    required this.progress,
  });
}

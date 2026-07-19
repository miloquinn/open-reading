part of '../detailed_stats_page.dart';

extension _DetailedStatsChartsView on _DetailedStatsPageState {
  Widget _buildChartsTab() {
    return _buildTabScrollBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatTypeSelector(),
          const SizedBox(height: 20),
          _buildTrendChart(),
          const SizedBox(height: 20),
          _buildTimeDistributionChart(),
          const SizedBox(height: 20),
          _buildFormatDistribution(),
          const SizedBox(height: 20),
          _buildReadingInsights(),
          const SizedBox(height: 20),
          _buildReadingSpeedChart(),
          const SizedBox(height: 20),
          _buildReadingHeatmap(),
        ],
      ),
    );
  }

  Widget _buildStatTypeSelector() {
    final palette = _palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.cardStrong,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTypeButton(context.l10n.readingTime, 0),
          _buildTypeButton(context.l10n.statsPagesRead, 1),
          _buildTypeButton(context.l10n.statsBookCount, 2),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String title, int index) {
    final palette = _palette;
    final selected = _selectedStatType == index;
    return Expanded(
      child: Material(
        color: selected ? palette.softAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _selectStatType(index),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? palette.accent : palette.mutedInk,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    final data = _windowedDailyStats;
    final total = data.fold<int>(0, (sum, item) {
      return sum +
          switch (_selectedStatType) {
            1 => (item['pagesRead'] as int?) ?? 0,
            2 => (item['booksRead'] as int?) ?? 0,
            _ => (item['readingTime'] as int?) ?? 0,
          };
    });
    final totalLabel = switch (_selectedStatType) {
      0 => context.l10n.statsMinutes(total),
      1 => context.l10n.statsPagesCount(total),
      _ => '$total ${context.l10n.unitBook}',
    };

    return _buildPaperSection(
      title: context.l10n.statsTrendAnalysis,
      icon: Icons.show_chart_rounded,
      trailing: Text(
        totalLabel,
        style: TextStyle(
          color: _palette.accent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: SizedBox(
        height: 230,
        child: LineChart(_lineChartData()),
      ),
    );
  }

  LineChartData _lineChartData() {
    final palette = _palette;
    final data = _windowedDailyStats;
    if (data.isEmpty) {
      return LineChartData(
        lineBarsData: const [],
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
      );
    }

    final spots = data.asMap().entries.map((entry) {
      final item = entry.value;
      final value = switch (_selectedStatType) {
        1 => ((item['pagesRead'] as int?) ?? 0).toDouble(),
        2 => ((item['booksRead'] as int?) ?? 0).toDouble(),
        _ => ((item['readingTime'] as int?) ?? 0).toDouble(),
      };
      return FlSpot(entry.key.toDouble(), value);
    }).toList(growable: false);
    final rawMax = spots.fold<double>(
      0,
      (current, spot) => math.max(current, spot.y),
    );
    final maxY = math.max(5.0, rawMax * 1.18);
    final interval = data.length <= 7
        ? 1
        : data.length <= 30
            ? 5
            : data.length <= 90
                ? 15
                : 45;

    return LineChartData(
      minX: 0,
      maxX: math.max(1, data.length - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      lineTouchData: const LineTouchData(enabled: true),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: palette.border,
          strokeWidth: 1,
          dashArray: [4, 5],
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            getTitlesWidget: (value, meta) {
              if (value == 0 || value == meta.max) {
                return const SizedBox.shrink();
              }
              return Text(
                value.round().toString(),
                style: TextStyle(color: palette.mutedInk, fontSize: 10),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: interval.toDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 || index >= data.length) {
                return const SizedBox.shrink();
              }
              final parts = (data[index]['date'] as String).split('-');
              final label = parts.length >= 3
                  ? '${int.parse(parts[1])}/${int.parse(parts[2])}'
                  : '';
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  label,
                  style: TextStyle(color: palette.mutedInk, fontSize: 10),
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.28,
          color: palette.accent,
          barWidth: 3.2,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: data.length <= 14,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 3,
              color: palette.cardStrong,
              strokeWidth: 2,
              strokeColor: palette.accent,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                palette.accent.withValues(alpha: 0.22),
                palette.accent.withValues(alpha: 0.01),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeDistributionChart() {
    final palette = _palette;
    final hourly = List<double>.generate(
      24,
      (hour) => (_hourlyDistribution[hour] ?? 0).toDouble(),
    );
    final rawMax = hourly.fold<double>(
      0,
      (current, value) => math.max(current, value),
    );

    return _buildPaperSection(
      title: context.l10n.statsTimeDistribution,
      icon: Icons.schedule_rounded,
      trailing: Text(
        _inferBestReadingPeriod(),
        style: TextStyle(
          color: palette.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: SizedBox(
        height: 210,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: math.max(5, rawMax * 1.18).toDouble(),
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: palette.border,
                strokeWidth: 1,
                dashArray: [4, 5],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final hour = value.toInt();
                    if (hour % 6 != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        context.l10n.statsAxisHour(hour),
                        style: TextStyle(
                          color: palette.mutedInk,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(24, (hour) {
              return BarChartGroupData(
                x: hour,
                barRods: [
                  BarChartRodData(
                    toY: hourly[hour],
                    width: 7,
                    color: palette.accent.withValues(
                      alpha: hour % 6 == 0 ? 0.95 : 0.54,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatDistribution() {
    final palette = _palette;
    final counts = <String, int>{};
    for (final item in _bookStats) {
      final book = item['book'] as Book;
      final format = book.format.trim().isEmpty
          ? 'OTHER'
          : book.format.trim().toUpperCase();
      counts[format] = (counts[format] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, item) => sum + item.value);
    final colors = [
      palette.accent,
      const Color(0xFF6C8298),
      const Color(0xFF7E9178),
      const Color(0xFFB18A67),
      const Color(0xFF8A7C92),
    ];

    return _buildPaperSection(
      title: context.l10n.statsFormatDistribution,
      icon: Icons.donut_large_rounded,
      child: entries.isEmpty
          ? SizedBox(
              height: 130,
              child: Center(
                child: Text(
                  context.l10n.statsNoData,
                  style: TextStyle(color: palette.mutedInk),
                ),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 170,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 48,
                      sectionsSpace: 3,
                      borderData: FlBorderData(show: false),
                      pieTouchData: PieTouchData(enabled: false),
                      sections: entries.asMap().entries.map((entry) {
                        return PieChartSectionData(
                          value: entry.value.value.toDouble(),
                          color: colors[entry.key % colors.length],
                          radius: 30,
                          showTitle: false,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 14,
                  runSpacing: 9,
                  children: entries.asMap().entries.map((entry) {
                    final item = entry.value;
                    final percent = total == 0 ? 0 : item.value / total * 100;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors[entry.key % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${item.key} ${percent.round()}%',
                          style: TextStyle(
                            color: palette.mutedInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  Widget _buildReadingInsights() {
    final l10n = context.l10n;
    final insights = [
      (
        l10n.statsBestReadingPeriod,
        _inferBestReadingPeriod(),
        Icons.wb_twilight_rounded,
      ),
      (
        l10n.statsAvgSessionReading,
        _avgSessionDurationLabel,
        Icons.hourglass_bottom_rounded,
      ),
      (
        l10n.statsMaxStreakDays,
        _maxStreakLabel,
        Icons.local_fire_department_rounded,
      ),
      (
        l10n.statsFocusScore,
        _focusScoreLabel,
        Icons.center_focus_strong_rounded,
      ),
    ];
    return _buildPaperSection(
      title: l10n.statsReadingHabits,
      icon: Icons.lightbulb_outline_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: insights
                .map(
                  (item) => SizedBox(
                    width: itemWidth,
                    child: _buildInsightTile(item.$1, item.$2, item.$3),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildInsightTile(String label, String value, IconData icon) {
    final palette = _palette;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.ink.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.accent, size: 19),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedInk,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingSpeedChart() {
    final palette = _palette;
    final values = _windowedDailyStats.map((item) {
      final minutes = (item['readingTime'] as int?) ?? 0;
      final pages = (item['pagesRead'] as int?) ?? 0;
      return minutes <= 0 ? 0.0 : pages / minutes;
    }).toList(growable: false);
    final spots = values
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList(growable: false);
    final rawMax = values.fold<double>(
      0,
      (current, value) => math.max(current, value),
    );

    return _buildPaperSection(
      title: context.l10n.statsSpeedTrend,
      icon: Icons.speed_rounded,
      trailing: Text(
        context.l10n.statsAvgSpeed(_averagePagesPerMinute.toStringAsFixed(2)),
        style: TextStyle(
          color: palette.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: SizedBox(
        height: 150,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: math.max(1, values.length - 1).toDouble(),
            minY: 0,
            maxY: math.max(1, rawMax * 1.2).toDouble(),
            lineTouchData: const LineTouchData(enabled: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: palette.border,
                strokeWidth: 1,
                dashArray: [4, 5],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.28,
                color: palette.accent,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.accent.withValues(alpha: 0.18),
                      palette.accent.withValues(alpha: 0.01),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

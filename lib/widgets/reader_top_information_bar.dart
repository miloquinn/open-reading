import 'package:flutter/material.dart';

import '../core/reader/reader_leaf_status.dart';
import '../utils/reader_themes.dart';

enum ReaderTopInformationLayout {
  full,
  spreadLeft,
  spreadRight,
}

class ReaderTopInformationBar extends StatelessWidget {
  const ReaderTopInformationBar({
    super.key,
    required this.palette,
    required this.title,
    required this.status,
    this.layout = ReaderTopInformationLayout.full,
  });

  final ReaderThemePalette palette;
  final String title;
  final ReaderLeafStatusData? status;
  final ReaderTopInformationLayout layout;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          height: 1,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.08,
          color: palette.secondaryText.withValues(alpha: 0.66),
          fontFeatures: const [FontFeature.tabularFigures()],
        ) ??
        TextStyle(
          height: 1,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: palette.secondaryText.withValues(alpha: 0.66),
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final time = status == null
        ? ''
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(status!.time),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
    final battery = status?.battery;

    final batteryIndicator = battery == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                battery.charging
                    ? Icons.battery_charging_full_rounded
                    : _batteryIcon(battery.level),
                size: 11,
                color: style.color,
              ),
              const SizedBox(width: 1),
              Text('${battery.level}%', style: style),
            ],
          );
    final semanticsParts = switch (layout) {
      ReaderTopInformationLayout.full => [
          if (time.isNotEmpty) time,
          title,
          if (battery != null) '${battery.level}%',
        ],
      ReaderTopInformationLayout.spreadLeft => [title],
      ReaderTopInformationLayout.spreadRight => [
          if (time.isNotEmpty) time,
          if (battery != null) '${battery.level}%',
        ],
    };

    return Semantics(
      container: true,
      label: semanticsParts.where((part) => part.isNotEmpty).join(', '),
      child: SizedBox(
        height: 16,
        child: switch (layout) {
          ReaderTopInformationLayout.full => Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(time, style: style),
                ),
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.54,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.14,
                      ),
                    ),
                  ),
                ),
                if (batteryIndicator != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: batteryIndicator,
                  ),
              ],
            ),
          ReaderTopInformationLayout.spreadLeft => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.14,
                ),
              ),
            ),
          ReaderTopInformationLayout.spreadRight => Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (time.isNotEmpty) Text(time, style: style),
                  if (time.isNotEmpty && batteryIndicator != null)
                    const SizedBox(width: 8),
                  if (batteryIndicator != null) batteryIndicator,
                ],
              ),
            ),
        },
      ),
    );
  }
}

IconData _batteryIcon(int level) {
  if (level <= 15) return Icons.battery_1_bar_rounded;
  if (level <= 35) return Icons.battery_2_bar_rounded;
  if (level <= 55) return Icons.battery_3_bar_rounded;
  if (level <= 75) return Icons.battery_5_bar_rounded;
  if (level <= 90) return Icons.battery_6_bar_rounded;
  return Icons.battery_full_rounded;
}

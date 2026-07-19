import 'package:flutter/material.dart';

import '../core/reader/reader_leaf_status.dart';
import '../utils/reader_themes.dart';

class ReaderTopInformationBar extends StatelessWidget {
  const ReaderTopInformationBar({
    super.key,
    required this.palette,
    required this.title,
    required this.status,
  });

  final ReaderThemePalette palette;
  final String title;
  final ReaderLeafStatusData? status;

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

    return Semantics(
      container: true,
      label: [
        if (time.isNotEmpty) time,
        title,
        if (battery != null) '${battery.level}%',
      ].join(', '),
      child: SizedBox(
        height: 16,
        child: Stack(
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
            if (battery != null)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
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
                ),
              ),
          ],
        ),
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

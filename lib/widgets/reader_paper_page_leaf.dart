import 'package:flutter/material.dart';

import '../core/reader/reader_leaf_status.dart';
import '../core/reader/reader_safe_area.dart';
import '../utils/reader_themes.dart';

@immutable
class ReaderPageSnapshotKey {
  const ReaderPageSnapshotKey({
    required this.pageIdentity,
    required this.layoutFingerprint,
    required this.themeId,
  });

  final String pageIdentity;
  final String layoutFingerprint;
  final String themeId;

  @override
  bool operator ==(Object other) =>
      other is ReaderPageSnapshotKey &&
      other.pageIdentity == pageIdentity &&
      other.layoutFingerprint == layoutFingerprint &&
      other.themeId == themeId;

  @override
  int get hashCode => Object.hash(pageIdentity, layoutFingerprint, themeId);

  @override
  String toString() => '$pageIdentity@$layoutFingerprint#$themeId';
}

@immutable
class ReaderPaperPageMetadata {
  const ReaderPaperPageMetadata({
    required this.pageIdentity,
    required this.layoutFingerprint,
    required this.themeId,
    required this.chapterTitle,
    required this.pageNumber,
    required this.pageCount,
  });

  final String pageIdentity;
  final String layoutFingerprint;
  final String themeId;
  final String chapterTitle;
  final int pageNumber;
  final int pageCount;

  ReaderPageSnapshotKey get snapshotKey => ReaderPageSnapshotKey(
        pageIdentity: pageIdentity,
        layoutFingerprint: layoutFingerprint,
        themeId: themeId,
      );

  String get pageLabel => '$pageNumber / $pageCount';
}

/// A complete sheet of reader paper: body and quiet editorial footer.
///
/// The footer is deliberately inside the leaf so PageView, cylinder curl and
/// classic fold all move the same pixels. Floating reader controls remain a
/// separate HUD.
class ReaderPaperPageLeaf extends StatelessWidget {
  const ReaderPaperPageLeaf({
    super.key,
    required this.palette,
    required this.safeArea,
    required this.metadata,
    required this.status,
    required this.child,
    this.showDeviceStatus = true,
    this.horizontalPadding = 14,
  });

  final ReaderThemePalette palette;
  final ReaderSafeAreaMetrics safeArea;
  final ReaderPaperPageMetadata metadata;
  final ReaderLeafStatusData status;
  final Widget child;
  final bool showDeviceStatus;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final footerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: palette.secondaryText.withValues(alpha: 0.66),
          fontSize: 10,
          height: 1,
          letterSpacing: 0.08,
          fontFeatures: const [FontFeature.tabularFigures()],
        ) ??
        TextStyle(
          color: palette.secondaryText.withValues(alpha: 0.66),
          fontSize: 10,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final semanticsLabel = metadata.chapterTitle.isEmpty
        ? metadata.pageLabel
        : '${metadata.chapterTitle}, ${metadata.pageLabel}';

    return Semantics(
      label: semanticsLabel,
      container: true,
      child: ColoredBox(
        color: palette.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              bottom: safeArea.pageNumberBottom,
              height: ReaderSafeAreaMetrics.pageNumberReserve,
              child: DefaultTextStyle(
                style: footerStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: Stack(
                  key: ValueKey(
                    'reader-leaf-footer:${metadata.pageIdentity}',
                  ),
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.38,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          metadata.chapterTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        metadata.pageLabel,
                        key: ValueKey(
                          'reader-leaf-page:${metadata.pageIdentity}',
                        ),
                      ),
                    ),
                    if (showDeviceStatus)
                      Align(
                        alignment: Alignment.centerRight,
                        child: _ReaderLeafDeviceStatus(
                          status: status,
                          style: footerStyle,
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
}

class _ReaderLeafDeviceStatus extends StatelessWidget {
  const _ReaderLeafDeviceStatus({
    required this.status,
    required this.style,
  });

  final ReaderLeafStatusData status;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(status.time),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final battery = status.battery;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(time, style: style),
        if (battery != null) ...[
          const SizedBox(width: 6),
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
      ],
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

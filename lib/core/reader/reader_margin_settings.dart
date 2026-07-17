import 'package:flutter/foundation.dart';

@immutable
class ReaderMarginSettings {
  static const double min = 0;
  static const double max = 40;
  static const double defaultTop = 4;
  static const double defaultBottom = 0;
  static const double legacyDefault = 28;

  const ReaderMarginSettings({required this.top, required this.bottom});

  factory ReaderMarginSettings.fromStored({
    double? top,
    double? bottom,
    double? legacyVertical,
  }) {
    final legacyExtra =
        ((legacyVertical ?? legacyDefault) - legacyDefault).clamp(min, max);
    return ReaderMarginSettings(
      top: (top ?? defaultTop + legacyExtra).clamp(min, max),
      bottom: (bottom ?? defaultBottom + legacyExtra).clamp(min, max),
    );
  }

  final double top;
  final double bottom;
}

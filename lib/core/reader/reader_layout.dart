import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum ReaderPageMode {
  verticalScroll,
  instantPage,
  horizontalSlide,
  pageCurl,
}

ReaderPageMode readerPageModeFromName(
  String? name, {
  required ReaderPageMode fallback,
}) {
  if (name == 'horizontalPage') return ReaderPageMode.instantPage;
  return ReaderPageMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => fallback,
  );
}

@immutable
class ReaderLayoutFingerprint {
  const ReaderLayoutFingerprint({
    required this.contentKey,
    required this.viewport,
    required this.fontSize,
    required this.lineHeight,
    required this.horizontalMargin,
    required this.verticalMargin,
    required this.textScaler,
    required this.locale,
    required this.pageMode,
    this.extra = '',
  });

  final String contentKey;
  final Size viewport;
  final double fontSize;
  final double lineHeight;
  final double horizontalMargin;
  final double verticalMargin;
  final TextScaler textScaler;
  final Locale? locale;
  final ReaderPageMode pageMode;
  final String extra;

  String cacheKey(String version) {
    final scalerKey = <double>[12, 24, 48]
        .map((size) => textScaler.scale(size).toStringAsFixed(3))
        .join(',');
    return '$version:$contentKey:${viewport.width.toStringAsFixed(2)}:'
        '${viewport.height.toStringAsFixed(2)}:'
        '${fontSize.toStringAsFixed(2)}:${lineHeight.toStringAsFixed(3)}:'
        '${horizontalMargin.toStringAsFixed(2)}:'
        '${verticalMargin.toStringAsFixed(2)}:$scalerKey:'
        '${locale?.toLanguageTag()}:${pageMode.name}:$extra';
  }
}

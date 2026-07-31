import 'package:flutter/material.dart';

/// The dedicated first page for a chapter whose title was split from its body.
class ReaderChapterTitlePage extends StatelessWidget {
  const ReaderChapterTitlePage({
    super.key,
    required this.title,
    required this.bodyStyle,
  });

  static const contentKey = ValueKey('native-chapter-title-page');

  final String title;
  final TextStyle bodyStyle;

  static double titleFontSizeFor(double bodyFontSize) =>
      (bodyFontSize * 1.8).clamp(28, 34);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.16),
      child: FractionallySizedBox(
        widthFactor: 0.84,
        child: Text(
          title,
          key: contentKey,
          textAlign: TextAlign.center,
          style: bodyStyle.copyWith(
            fontSize: titleFontSizeFor(bodyStyle.fontSize ?? 19),
            fontWeight: FontWeight.w600,
            height: 1.35,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// A compact chapter heading placed above the first body page.
class ReaderInlineChapterTitle extends StatelessWidget {
  const ReaderInlineChapterTitle({
    super.key,
    required this.title,
    required this.bodyStyle,
  });

  static const contentKey = ValueKey('native-inline-chapter-title');
  static const double spacingAfter = 24;

  final String title;
  final TextStyle bodyStyle;

  static TextStyle titleStyleFor(TextStyle bodyStyle) => bodyStyle.copyWith(
    fontSize: ((bodyStyle.fontSize ?? 19) * 1.45).clamp(24, 30),
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static double extentFor({
    required String title,
    required double maxWidth,
    required TextStyle bodyStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
    Locale? locale,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: title, style: titleStyleFor(bodyStyle)),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      maxLines: 3,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    return painter.height + spacingAfter;
  }

  @override
  Widget build(BuildContext context) => Text(
    title,
    key: contentKey,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
    style: titleStyleFor(bodyStyle),
  );
}

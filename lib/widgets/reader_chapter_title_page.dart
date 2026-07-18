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

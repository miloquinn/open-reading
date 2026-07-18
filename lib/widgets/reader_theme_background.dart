import 'package:flutter/material.dart';

import '../utils/reader_themes.dart';
import 'reader_theme_background_image.dart';

class ReaderThemeBackground extends StatelessWidget {
  const ReaderThemeBackground({
    super.key,
    required this.palette,
    required this.child,
    this.borderRadius,
  });

  final ReaderThemePalette palette;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget result = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: ColoredBox(color: palette.background)),
        if (palette.hasBackgroundImage)
          Positioned.fill(
            child: Opacity(
              opacity: palette.backgroundImageOpacity.clamp(0.0, 0.75),
              child: buildReaderThemeBackgroundImage(
                palette.backgroundImagePath!,
              ),
            ),
          ),
        child,
      ],
    );
    if (borderRadius != null) {
      result = ClipRRect(borderRadius: borderRadius!, child: result);
    }
    return result;
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/glass_config.dart';
import '../utils/reader_themes.dart';

class ReaderControlBar extends StatelessWidget {
  const ReaderControlBar({
    super.key,
    required this.palette,
    required this.isTopBar,
    required this.child,
  });

  final ReaderThemePalette palette;
  final bool isTopBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(999);
    final blurEnabled = !GlassEffectConfig.shouldDisableBlur;
    final config = GlassEffectHelper.getReadingControlConfig(
      preset: GlassEffectConfig.dreamyMode,
      isTopBar: isTopBar,
    );
    final highlight = Color.lerp(
      palette.controlBar,
      Colors.white,
      palette.brightness == Brightness.dark ? 0.06 : 0.18,
    )!;
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            highlight.withValues(alpha: blurEnabled ? 0.92 : 1),
            palette.controlBar.withValues(alpha: blurEnabled ? 0.88 : 1),
          ],
        ),
        border: Border.all(
          color: Color.lerp(
            colors.outline,
            Colors.white,
            palette.brightness == Brightness.dark ? 0.16 : 0.38,
          )!
              .withValues(alpha: blurEnabled ? 0.54 : 0.68),
          width: 1,
        ),
      ),
      child: Material(color: Colors.transparent, child: child),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(
              alpha: palette.brightness == Brightness.dark ? 0.46 : 0.22,
            ),
            blurRadius: 32,
            spreadRadius: -5,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: blurEnabled
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: config['blur']!,
                  sigmaY: config['blur']!,
                ),
                child: panel,
              )
            : panel,
      ),
    );
  }
}

class ReaderControlIconButton extends StatelessWidget {
  const ReaderControlIconButton({
    super.key,
    required this.palette,
    required this.onPressed,
    required this.tooltip,
    required this.icon,
  });

  final ReaderThemePalette palette;
  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        foregroundColor: palette.text,
        backgroundColor: palette.controlFill.withValues(alpha: 0.78),
        minimumSize: const Size.square(44),
        maximumSize: const Size.square(44),
        padding: EdgeInsets.zero,
        side: BorderSide(
          color: palette.border.withValues(alpha: 0.42),
          width: 0.8,
        ),
        shape: const CircleBorder(),
      ),
    );
  }
}

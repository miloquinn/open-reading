// 文件说明：页面样式辅助工具，统一包装页面的背景、间距和视觉风格。
// 技术要点：工具方法、Flutter。

import 'package:flutter/material.dart';
import 'ui_style.dart';

class PageVisualPalette {
  final Color backgroundStart;
  final Color backgroundMiddle;
  final Color backgroundEnd;
  final Color card;
  final Color cardStrong;
  final Color hero;
  final Color border;
  final Color iconMuted;
  final Color textMuted;

  const PageVisualPalette({
    required this.backgroundStart,
    required this.backgroundMiddle,
    required this.backgroundEnd,
    required this.card,
    required this.cardStrong,
    required this.hero,
    required this.border,
    required this.iconMuted,
    required this.textMuted,
  });
}

class PageStyleHelper {
  static PageVisualPalette palette(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final uiStyle =
        theme.extension<UiStyleThemeExtension>()?.style ?? AppUiStyle.material3;
    final isMaterial3Style = uiStyle == AppUiStyle.material3;

    return PageVisualPalette(
      backgroundStart: isMaterial3Style
          ? Color.alphaBlend(
              scheme.surfaceContainer.withValues(alpha: isDark ? 0.82 : 0.92),
              scheme.surface,
            )
          : Color.alphaBlend(
              scheme.primary.withValues(alpha: isDark ? 0.17 : 0.09),
              scheme.surface,
            ),
      backgroundMiddle: isMaterial3Style
          ? Color.alphaBlend(
              scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.78 : 0.9),
              scheme.surface,
            )
          : Color.alphaBlend(
              scheme.secondary.withValues(alpha: isDark ? 0.13 : 0.06),
              scheme.surface,
            ),
      backgroundEnd: scheme.surface,
      card: isMaterial3Style
          ? scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.96 : 0.98)
          : scheme.surface.withValues(alpha: isDark ? 0.78 : 0.88),
      cardStrong: isMaterial3Style
          ? scheme.surfaceContainer.withValues(alpha: isDark ? 0.98 : 1.0)
          : scheme.surface.withValues(alpha: isDark ? 0.84 : 0.93),
      hero: isMaterial3Style
          ? Color.alphaBlend(
              scheme.primary.withValues(alpha: isDark ? 0.18 : 0.1),
              scheme.surfaceContainerHigh,
            )
          : Color.alphaBlend(
              scheme.primary.withValues(alpha: isDark ? 0.24 : 0.14),
              scheme.primaryContainer.withValues(alpha: isDark ? 0.40 : 0.56),
            ),
      border: scheme.outline.withValues(
        alpha: isMaterial3Style
            ? (isDark ? 0.36 : 0.24)
            : (isDark ? 0.24 : 0.12),
      ),
      iconMuted: scheme.onSurface.withValues(alpha: isDark ? 0.82 : 0.74),
      textMuted: scheme.onSurfaceVariant.withValues(
        alpha: isDark ? 0.84 : 0.72,
      ),
    );
  }

  static LinearGradient backgroundGradient(BuildContext context) {
    final p = palette(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomCenter,
      colors: [p.backgroundStart, p.backgroundMiddle, p.backgroundEnd],
    );
  }
}

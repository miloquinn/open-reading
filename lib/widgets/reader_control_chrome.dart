import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/glass_config.dart';
import '../utils/reader_themes.dart';

typedef ReaderStatusBuilder = Widget Function(
  BuildContext context,
  TextStyle? style,
  Key? key,
);

class ReaderChromeOverlay extends StatelessWidget {
  const ReaderChromeOverlay({
    super.key,
    required this.palette,
    required this.visible,
    required this.title,
    required this.statusBottom,
    required this.statusBuilder,
    required this.onBack,
    required this.onBookmark,
    required this.onTableOfContents,
    required this.onSettings,
    required this.backTooltip,
    required this.bookmarkTooltip,
    required this.tableOfContentsTooltip,
    required this.settingsTooltip,
    required this.bookmarked,
    this.bookmarkBusy = false,
    this.topKey,
    this.bottomKey,
    this.statusKey,
  });

  final ReaderThemePalette palette;
  final bool visible;
  final String title;
  final double statusBottom;
  final ReaderStatusBuilder statusBuilder;
  final VoidCallback onBack;
  final VoidCallback? onBookmark;
  final VoidCallback? onTableOfContents;
  final VoidCallback onSettings;
  final String backTooltip;
  final String bookmarkTooltip;
  final String tableOfContentsTooltip;
  final String settingsTooltip;
  final bool bookmarked;
  final bool bookmarkBusy;
  final Key? topKey;
  final Key? bottomKey;
  final Key? statusKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: statusBottom,
          child: IgnorePointer(
            child: statusBuilder(
              context,
              textTheme.labelSmall?.copyWith(
                fontSize: 10,
                height: 1,
                color: colors.onSurfaceVariant.withValues(
                  alpha: visible ? 0 : 0.58,
                ),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              statusKey,
            ),
          ),
        ),
        AnimatedPositioned(
          key: topKey,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          left: 20,
          right: 20,
          top: visible ? 10 : -130,
          child: SafeArea(
            bottom: false,
            child: ReaderControlBar(
              palette: palette,
              isTopBar: true,
              child: SizedBox(
                height: 58,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                  child: Row(
                    children: [
                      ReaderControlIconButton(
                        palette: palette,
                        onPressed: onBack,
                        tooltip: backTooltip,
                        icon: Icons.arrow_back_rounded,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      ReaderControlIconButton(
                        palette: palette,
                        onPressed: bookmarkBusy ? null : onBookmark,
                        tooltip: bookmarkTooltip,
                        icon: bookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          key: bottomKey,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          left: 22,
          right: 22,
          bottom: visible ? 16 : -110,
          child: SafeArea(
            top: false,
            child: ReaderControlBar(
              palette: palette,
              isTopBar: false,
              child: SizedBox(
                height: 64,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                  child: Row(
                    children: [
                      ReaderControlIconButton(
                        palette: palette,
                        onPressed: onTableOfContents,
                        tooltip: tableOfContentsTooltip,
                        icon: Icons.format_list_bulleted_rounded,
                      ),
                      Expanded(
                        child: statusBuilder(
                          context,
                          textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.15,
                          ),
                          null,
                        ),
                      ),
                      ReaderControlIconButton(
                        palette: palette,
                        onPressed: onSettings,
                        tooltip: settingsTooltip,
                        icon: Icons.tune_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
    final surfaceOpacity = blurEnabled ? config['opacity']! : 1.0;
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
            highlight.withValues(
              alpha:
                  (surfaceOpacity + (blurEnabled ? 0.08 : 0.0)).clamp(0.0, 1.0),
            ),
            palette.controlBar.withValues(
              alpha:
                  (surfaceOpacity - (blurEnabled ? 0.02 : 0.0)).clamp(0.0, 1.0),
            ),
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
    final glassEnabled = !GlassEffectConfig.shouldDisableBlur;
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        foregroundColor: palette.text,
        backgroundColor: palette.controlFill.withValues(
          alpha: glassEnabled ? 0.58 : 1.0,
        ),
        minimumSize: const Size.square(44),
        maximumSize: const Size.square(44),
        padding: EdgeInsets.zero,
        side: BorderSide(
          color: Color.lerp(
            palette.border,
            Colors.white,
            palette.brightness == Brightness.dark ? 0.12 : 0.32,
          )!
              .withValues(alpha: glassEnabled ? 0.48 : 0.42),
          width: 0.8,
        ),
        shape: const CircleBorder(),
      ),
    );
  }
}

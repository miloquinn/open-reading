// 文件说明：阅读器打开期间的主题化书本加载动画。
// 技术要点：单 ticker 驱动旋转细环、书本呼吸和三点波浪，并尊重减少动态效果。

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/reader_themes.dart';

class ReaderOpeningLoader extends StatefulWidget {
  const ReaderOpeningLoader({super.key, required this.palette});

  final ReaderThemePalette palette;

  @override
  State<ReaderOpeningLoader> createState() => _ReaderOpeningLoaderState();
}

class _ReaderOpeningLoaderState extends State<ReaderOpeningLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) return _buildLoader(0.18, animate: false);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _buildLoader(_controller.value, animate: true),
    );
  }

  Widget _buildLoader(double progress, {required bool animate}) {
    final palette = widget.palette;
    final wave = animate ? (math.sin(progress * math.pi * 2) + 1) / 2 : 0.5;
    return Center(
      child: RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 86,
              height: 86,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: animate ? progress * math.pi * 2 : 0,
                    child: SizedBox(
                      width: 78,
                      height: 78,
                      child: CircularProgressIndicator(
                        value: 0.68,
                        strokeWidth: 2.6,
                        strokeCap: StrokeCap.round,
                        color: palette.accent.withValues(alpha: 0.82),
                        backgroundColor: palette.border.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.97 + wave * 0.05,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          palette.surface,
                          palette.controlFill,
                          0.34,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: palette.border.withValues(alpha: 0.42),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.shadow.withValues(
                              alpha: 0.08 + wave * 0.08,
                            ),
                            blurRadius: 18 + wave * 6,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: Icon(
                          Icons.auto_stories_rounded,
                          size: 30,
                          color: palette.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final phase = animate ? (progress + index * 0.16) % 1.0 : 0.5;
                final lift = (math.sin(phase * math.pi * 2) + 1) / 2;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.translate(
                    offset: Offset(0, -2.5 * lift),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(
                          alpha: 0.28 + lift * 0.58,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(width: 6, height: 6),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

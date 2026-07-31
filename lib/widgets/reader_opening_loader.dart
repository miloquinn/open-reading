// 文件说明：阅读器打开期间的轻量三点加载动画。
// 技术要点：单 ticker 驱动三个固定占位圆点依次呼吸，并尊重减少动态效果。

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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

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
    return Center(
      child: RepaintBoundary(
        child: SizedBox(
          key: const ValueKey('reader-opening-dots'),
          width: 54,
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              final phase = animate ? (progress - index * 0.18) % 1.0 : 0.5;
              final pulse = (math.cos(phase * math.pi * 2) + 1) / 2;
              final scale = 0.72 + pulse * 0.38;
              return SizedBox.square(
                dimension: 16,
                child: Center(
                  child: Transform.scale(
                    key: ValueKey('reader-opening-dot-$index'),
                    scale: scale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(
                          alpha: 0.18 + pulse * 0.36,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.square(dimension: 12),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

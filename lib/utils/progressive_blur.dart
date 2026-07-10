// 文件说明：渐进式模糊组件与算法，提供多层次背景模糊效果。
// 技术要点：工具方法、渲染层、Flutter。

// 渐进模糊效果工具类
// Progressive Blur Effects Helper

import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_config.dart';

class ProgressiveBlur extends StatelessWidget {
  final Widget child;
  final double startBlur;
  final double endBlur;
  final List<Color> gradientColors;
  final AlignmentGeometry beginAlignment;
  final AlignmentGeometry endAlignment;
  final List<double>? stops;
  final BorderRadius? borderRadius;

  const ProgressiveBlur({
    super.key,
    required this.child,
    this.startBlur = 0.0,
    this.endBlur = 20.0,
    this.gradientColors = const [],
    this.beginAlignment = Alignment.topCenter,
    this.endAlignment = Alignment.bottomCenter,
    this.stops,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (borderRadius != null) {
      content = ClipRRect(borderRadius: borderRadius!, child: content);
    }

    return Stack(
      children: [
        content,
        // 渐进模糊层（忽略指针，避免遮挡交互）
        Positioned.fill(
          child: IgnorePointer(child: _buildProgressiveBlurOverlay(context)),
        ),
      ],
    );
  }

  Widget _buildProgressiveBlurOverlay(BuildContext context) {
    Widget overlay = BackdropFilter(
      enabled: !GlassEffectConfig.shouldDisableBlur,
      filter: ImageFilter.blur(
        sigmaX: (startBlur + endBlur) / 2,
        sigmaY: (startBlur + endBlur) / 2,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: beginAlignment,
            end: endAlignment,
            colors: gradientColors.isNotEmpty
                ? gradientColors
                : [
                    Colors.transparent,
                    // 降低默认覆盖层不透明度，减少内容发灰
                    Theme.of(context).colorScheme.surface.withValues(
                          alpha: GlassEffectConfig.effectiveOpacity(0.06),
                        ),
                    Theme.of(context).colorScheme.surface.withValues(
                          alpha: GlassEffectConfig.effectiveOpacity(0.12),
                        ),
                  ],
            stops: stops ?? [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );

    if (borderRadius != null) {
      overlay = ClipRRect(borderRadius: borderRadius!, child: overlay);
    }

    // 统一裁剪模糊区域，避免不同图层混合造成的竖向接缝
    overlay = ClipRect(child: overlay);

    return overlay;
  }
}

// 预制的渐进模糊效果
class ProgressiveBlurPresets {
  // 从上到下的渐进模糊 - 适用于AppBar
  static Widget topToBottomBlur({
    required Widget child,
    required BuildContext context,
    double maxBlur = 25.0,
    BorderRadius? borderRadius,
  }) {
    return ProgressiveBlur(
      startBlur: 5.0,
      endBlur: maxBlur,
      beginAlignment: Alignment.topCenter,
      endAlignment: Alignment.bottomCenter,
      gradientColors: [
        // 以透明开始，减少整体发灰，解决顶栏下方发暗问题
        Colors.transparent,
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
      ],
      stops: const [0.0, 0.6, 1.0],
      borderRadius: borderRadius,
      child: child,
    );
  }

  // 从中心向外的渐进模糊 - 适用于卡片
  static Widget radialBlur({
    required Widget child,
    required BuildContext context,
    double maxBlur = 20.0,
    BorderRadius? borderRadius,
  }) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: IgnorePointer(
              // 覆盖层忽略指针，防止遮挡按钮点击
              child: BackdropFilter(
                enabled: !GlassEffectConfig.shouldDisableBlur,
                // 降低模糊强度，避免内容变糊
                filter: ImageFilter.blur(
                  sigmaX: maxBlur * 0.4,
                  sigmaY: maxBlur * 0.4,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.85,
                      colors: [
                        Colors.transparent,
                        // 明显降低覆盖层不透明度
                        Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.04),
                        Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.08),
                      ],
                      stops: const [0.0, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 边缘渐进模糊 - 适用于对话框和弹窗
  static Widget edgeBlur({
    required Widget child,
    required BuildContext context,
    double maxBlur = 30.0,
    BorderRadius? borderRadius,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: BackdropFilter(
            enabled: !GlassEffectConfig.shouldDisableBlur,
            filter: ImageFilter.blur(sigmaX: maxBlur, sigmaY: maxBlur),
            child: child,
          ),
        ),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.85),
                      Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.65),
                      Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.7),
                      Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.9),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 底部导航栏的渐进模糊
  static Widget bottomNavigationBlur({
    required Widget child,
    required BuildContext context,
    double maxBlur = 25.0,
    BorderRadius? borderRadius,
  }) {
    return ProgressiveBlur(
      startBlur: maxBlur,
      endBlur: 5.0,
      beginAlignment: Alignment.bottomCenter,
      endAlignment: Alignment.topCenter,
      gradientColors: [
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        Colors.transparent,
      ],
      stops: const [0.0, 0.6, 1.0],
      borderRadius: borderRadius,
      child: child,
    );
  }
}

// 高级渐进模糊效果
class AdvancedProgressiveBlur extends StatelessWidget {
  final Widget child;
  final List<BlurLayer> layers;
  final BorderRadius? borderRadius;

  const AdvancedProgressiveBlur({
    super.key,
    required this.child,
    required this.layers,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (borderRadius != null) {
      content = ClipRRect(borderRadius: borderRadius!, child: content);
    }

    return Stack(
      children: [
        content,
        ...layers.map(
          (layer) => Positioned.fill(child: _buildLayer(context, layer)),
        ),
      ],
    );
  }

  Widget _buildLayer(BuildContext context, BlurLayer layer) {
    Widget layerWidget = BackdropFilter(
      enabled: !GlassEffectConfig.shouldDisableBlur,
      filter: ImageFilter.blur(sigmaX: layer.blur, sigmaY: layer.blur),
      child: Container(
        decoration: BoxDecoration(
          gradient: layer.gradient ??
              LinearGradient(colors: [Colors.transparent, layer.color]),
        ),
      ),
    );

    if (borderRadius != null) {
      layerWidget = ClipRRect(borderRadius: borderRadius!, child: layerWidget);
    }

    // 增加裁剪，避免多层混合时出现分割线
    layerWidget = ClipRect(child: layerWidget);

    return layerWidget;
  }
}

// 模糊层配置
class BlurLayer {
  final double blur;
  final Color color;
  final Gradient? gradient;

  const BlurLayer({required this.blur, required this.color, this.gradient});
}

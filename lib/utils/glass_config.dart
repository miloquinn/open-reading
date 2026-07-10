// 文件说明：毛玻璃效果配置文件，统一管理玻璃态 UI 的参数和预设。
// 技术要点：工具方法、Flutter。

// 毛玻璃效果配置管理器
// 集中管理所有界面的毛玻璃效果和透明度设置

import 'package:flutter/material.dart';
import 'progressive_blur.dart';

class GlassEffectConfig {
  // ============ 模糊强度配置 (sigmaX/sigmaY) ============
  static const double _appBarBlurBase = 15.0; // 首页、书库、设置页顶栏
  static const double _navigationBarBlurBase = 15.0; // 底部悬浮式导航栏
  static const double _readingTopBarBlurBase = 15.0; // 阅读页顶部控制栏
  static const double _readingBottomBarBlurBase = 15.0; // 阅读页底部控制栏
  static const double _cardBlurBase = 20.0; // 一般卡片容器
  static const double _lightCardBlurBase = 8.0; // 轻量级容器（图标背景等）
  static const double _dialogBlurBase = 30.0; // 对话框和弹窗
  static const double _modalBlurBase = 25.0; // 底部弹出菜单

  // 全局模糊缩放（性能优化：降低 GPU 压力）
  static double _blurScale = 0.85;
  static bool _reduceEffects = false;
  static bool _disableAllGlassEffects = false;

  static bool get disableAllGlassEffects => _disableAllGlassEffects;
  static bool get lowPerformanceMode => _disableAllGlassEffects;

  static void applyPerformanceMode({required bool reduceEffects}) {
    _reduceEffects = reduceEffects;
    _syncBlurScale();
  }

  static void setDisableAllGlassEffects(bool disabled) {
    _disableAllGlassEffects = disabled;
    _syncBlurScale();
  }

  static void _syncBlurScale() {
    if (_disableAllGlassEffects) {
      _blurScale = 0.0;
      return;
    }
    _blurScale = _reduceEffects ? 0.65 : 0.85;
  }

  static double _scaled(double value) => value * _blurScale;

  // 顶部应用栏 (AppBar)
  static double get appBarBlur => _scaled(_appBarBlurBase);

  // 导航栏
  static double get navigationBarBlur => _scaled(_navigationBarBlurBase);

  // 阅读页面控制栏
  static double get readingTopBarBlur => _scaled(_readingTopBarBlurBase);
  static double get readingBottomBarBlur => _scaled(_readingBottomBarBlurBase);

  // 卡片和容器
  static double get cardBlur => _scaled(_cardBlurBase);
  static double get lightCardBlur => _scaled(_lightCardBlurBase);
  static double get dialogBlur => _scaled(_dialogBlurBase);
  static double get modalBlur => _scaled(_modalBlurBase);

  // ============ 透明度配置 (alpha值: 0.0-1.0) ============

  // 顶部应用栏透明度
  static const double _appBarOpacityBase = 0.3;
  static double get appBarOpacity => effectiveOpacity(_appBarOpacityBase);

  // 导航栏透明度
  static const double _navigationBarOpacityBase = 0.3;
  static double get navigationBarOpacity =>
      effectiveOpacity(_navigationBarOpacityBase);

  // 阅读页面控制栏透明度
  static const double _readingTopBarOpacityBase = 0.9;
  static const double _readingBottomBarOpacityBase = 0.9;
  static double get readingTopBarOpacity =>
      effectiveOpacity(_readingTopBarOpacityBase);
  static double get readingBottomBarOpacity =>
      effectiveOpacity(_readingBottomBarOpacityBase);

  // 卡片透明度
  static const double _cardOpacityBase = 0.8;
  static const double _lightCardOpacityBase = 0.15;
  static const double _dialogOpacityBase = 0.95;
  static const double _modalOpacityBase = 0.9;
  static double get cardOpacity => effectiveOpacity(_cardOpacityBase);
  static double get lightCardOpacity => effectiveOpacity(_lightCardOpacityBase);
  static double get dialogOpacity => effectiveOpacity(_dialogOpacityBase);
  static double get modalOpacity => effectiveOpacity(_modalOpacityBase);

  static bool get shouldDisableBlur => _disableAllGlassEffects;

  static double effectiveOpacity(double opacity) {
    if (_disableAllGlassEffects) return 1.0;
    return opacity.clamp(0.0, 1.0);
  }

  static Color surfaceColor(BuildContext context, {double opacity = 1.0}) {
    return Theme.of(context).colorScheme.surface.withValues(
          alpha: effectiveOpacity(opacity),
        );
  }

  // ============ 快速配置预设 ============

  // 预设1: 清晰模式 (透明度偏高，模糊偏低)
  static const GlassPreset clearMode = GlassPreset(
    name: '清晰模式',
    blurReduction: 0.6, // 模糊强度 × 0.6
    opacityIncrease: 0.2, // 透明度 + 0.2
  );

  // 预设2: 毛玻璃模式 (标准设置)
  static const GlassPreset standardMode = GlassPreset(
    name: '标准模式',
    blurReduction: 1.0, // 标准模糊
    opacityIncrease: 0.0, // 标准透明度
  );

  // 预设3: 朦胧模式 (透明度偏低，模糊偏高)
  static const GlassPreset dreamyMode = GlassPreset(
    name: '朦胧模式',
    blurReduction: 1.4, // 模糊强度 × 1.4
    opacityIncrease: -0.15, // 透明度 - 0.15
  );

  // ============ 对外静态转发（兼容旧调用） ============
  static Widget createProgressiveAppBar({
    required BuildContext context,
    required Widget child,
    GlassPreset? preset,
    bool enableBlur = true, // 新增
    double? opacityScale, // 新增：调整透明度强度
  }) {
    return ClipRect(
      child: GlassEffectHelper._progressiveAppBarInternal(
        context: context,
        child: child,
        preset: preset,
        enableBlur: enableBlur && !shouldDisableBlur,
        opacityScale: opacityScale,
      ),
    );
  }

  static Widget createProgressiveCard({
    required BuildContext context,
    required Widget child,
    BorderRadius? borderRadius,
    GlassPreset? preset,
    bool enableBlur = true, // 新增：可关闭毛玻璃
  }) {
    return GlassEffectHelper.createProgressiveCard(
      context: context,
      child: child,
      borderRadius: borderRadius,
      preset: preset,
      enableBlur: enableBlur && !shouldDisableBlur,
    );
  }
}

// 毛玻璃预设配置
class GlassPreset {
  final String name;
  final double blurReduction; // 模糊强度倍数
  final double opacityIncrease; // 透明度增减值

  const GlassPreset({
    required this.name,
    required this.blurReduction,
    required this.opacityIncrease,
  });
}

// 毛玻璃效果辅助工具
class GlassEffectHelper {
  // 获取应用栏配置
  static Map<String, double> getAppBarConfig({GlassPreset? preset}) {
    preset ??= GlassEffectConfig.standardMode;
    return {
      'blur': GlassEffectConfig.appBarBlur * preset.blurReduction,
      'opacity': (GlassEffectConfig.appBarOpacity + preset.opacityIncrease)
          .clamp(0.0, 1.0),
    };
  }

  // 获取导航栏配置
  static Map<String, double> getNavigationConfig({GlassPreset? preset}) {
    preset ??= GlassEffectConfig.standardMode;
    return {
      'blur': GlassEffectConfig.navigationBarBlur * preset.blurReduction,
      'opacity':
          (GlassEffectConfig.navigationBarOpacity + preset.opacityIncrease)
              .clamp(0.0, 1.0),
    };
  }

  // 获取阅读页控制栏配置
  static Map<String, double> getReadingControlConfig({
    GlassPreset? preset,
    bool isTopBar = true,
  }) {
    preset ??= GlassEffectConfig.standardMode;
    final blur = isTopBar
        ? GlassEffectConfig.readingTopBarBlur
        : GlassEffectConfig.readingBottomBarBlur;
    final opacity = isTopBar
        ? GlassEffectConfig.readingTopBarOpacity
        : GlassEffectConfig.readingBottomBarOpacity;

    return {
      'blur': blur * preset.blurReduction,
      'opacity': (opacity + preset.opacityIncrease).clamp(0.0, 1.0),
    };
  }

  // ============ 渐进模糊效果配置 ============

  // 创建渐进模糊的AppBar（内部实现，外部通过 ClipRect 包裹后调用）
  static Widget _progressiveAppBarInternal({
    required BuildContext context,
    required Widget child,
    GlassPreset? preset,
    bool enableBlur = true,
    double? opacityScale,
  }) {
    preset ??= GlassEffectConfig.standardMode;
    final config = getAppBarConfig(preset: preset);
    final scaledOpacity = (opacityScale != null)
        ? (config['opacity']! * opacityScale).clamp(0.0, 1.0)
        : config['opacity']!;

    if (!enableBlur) {
      return Container(
        decoration: BoxDecoration(
          color:
              GlassEffectConfig.surfaceColor(context, opacity: scaledOpacity),
          border: Border(
            bottom: BorderSide(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
              width: 0.5,
            ),
          ),
        ),
        child: child,
      );
    }

    // 使用单层底色 + 轻覆层模糊，避免双重渐变导致的发暗与割裂
    return ProgressiveBlurPresets.topToBottomBlur(
      child: Container(
        decoration: BoxDecoration(
          color:
              GlassEffectConfig.surfaceColor(context, opacity: scaledOpacity),
        ),
        child: child,
      ),
      context: context,
      maxBlur: config['blur']!,
    );
  }

  // 创建渐进模糊的卡片
  static Widget createProgressiveCard({
    required BuildContext context,
    required Widget child,
    BorderRadius? borderRadius,
    GlassPreset? preset,
    bool enableBlur = true, // 新增
  }) {
    preset ??= GlassEffectConfig.standardMode;

    if (!enableBlur) {
      // 使用更清晰的实体卡片样式
      return Container(
        decoration: BoxDecoration(
          color: GlassEffectConfig.surfaceColor(context, opacity: 0.98),
          borderRadius: borderRadius,
          border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
    }

    return ProgressiveBlurPresets.radialBlur(
      child: Container(
        decoration: BoxDecoration(
          color: GlassEffectConfig.surfaceColor(
            context,
            opacity: GlassEffectConfig.cardOpacity,
          ),
          borderRadius: borderRadius,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: child,
      ),
      context: context,
      maxBlur: GlassEffectConfig.cardBlur * preset.blurReduction,
      borderRadius: borderRadius,
    );
  }

  // 创建渐进模糊的对话框
  static Widget createProgressiveDialog({
    required BuildContext context,
    required Widget child,
    BorderRadius? borderRadius,
    GlassPreset? preset,
  }) {
    preset ??= GlassEffectConfig.standardMode;

    return ProgressiveBlurPresets.edgeBlur(
      child: child,
      context: context,
      maxBlur: GlassEffectConfig.dialogBlur * preset.blurReduction,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
    );
  }

  // 创建渐进模糊的底部导航栏
  static Widget createProgressiveBottomNav({
    required BuildContext context,
    required Widget child,
    BorderRadius? borderRadius,
    GlassPreset? preset,
  }) {
    preset ??= GlassEffectConfig.standardMode;
    final config = getNavigationConfig(preset: preset);

    return ProgressiveBlurPresets.bottomNavigationBlur(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              GlassEffectConfig.surfaceColor(
                context,
                opacity: (config['opacity']! + 0.1).clamp(0.0, 1.0),
              ),
              GlassEffectConfig.surfaceColor(
                context,
                opacity: config['opacity']!,
              ),
              GlassEffectConfig.disableAllGlassEffects
                  ? GlassEffectConfig.surfaceColor(context, opacity: 1.0)
                  : Colors.transparent,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: child,
      ),
      context: context,
      maxBlur: GlassEffectConfig.shouldDisableBlur ? 0 : config['blur']!,
      borderRadius: borderRadius,
    );
  }
}

// ============ 使用示例 ============
/*
// 1. 直接使用配置值
BackdropFilter(
  filter: ImageFilter.blur(
    sigmaX: GlassEffectConfig.appBarBlur,
    sigmaY: GlassEffectConfig.appBarBlur,
  ),
  child: Container(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 
      GlassEffectConfig.appBarOpacity
    ),
  ),
)

// 2. 使用预设配置
final config = GlassEffectHelper.getAppBarConfig(preset: GlassEffectConfig.clearMode);
BackdropFilter(
  filter: ImageFilter.blur(
    sigmaX: config['blur']!,
    sigmaY: config['blur']!,
  ),
  child: Container(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 
      config['opacity']!
    ),
  ),
)

// 3. 快速调整透明度
// 要让应用栏更透明: 把 appBarOpacity 从 0.6 改为 0.4
// 要让应用栏更不透明: 把 appBarOpacity 从 0.6 改为 0.8
// 要让模糊效果更强: 把 appBarBlur 从 20.0 改为 30.0
// 要让模糊效果更弱: 把 appBarBlur 从 20.0 改为 10.0
*/

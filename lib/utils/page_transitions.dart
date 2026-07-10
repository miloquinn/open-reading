// 文件说明：页面转场工具，封装自定义路由动画与导航扩展。
// 技术要点：工具方法。

import 'package:flutter/material.dart';

/// 自定义页面过渡动画
/// 提供流畅的页面进入和退出动画效果
class CustomPageTransitions {
  /// 创建滑动缩放过渡路由
  /// 用于阅读页面的进入和退出，提供流畅的视觉体验
  static Route<T> createSlideScaleRoute<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 350),
    Duration reverseDuration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
    Curve reverseCurve = Curves.easeInCubic,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 进入动画：从右滑入并逐渐放大
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final slideTween = Tween<Offset>(begin: begin, end: end);
        final slideAnimation = animation.drive(
          slideTween.chain(CurveTween(curve: curve)),
        );

        // 缩放动画：从0.9倍逐渐放大到1.0倍
        final scaleTween = Tween<double>(begin: 0.95, end: 1.0);
        final scaleAnimation = animation.drive(
          scaleTween.chain(CurveTween(curve: curve)),
        );

        // 退出动画：当前页面逐渐缩小和左移
        final exitSlideTween = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.3, 0.0),
        );
        final exitSlideAnimation = secondaryAnimation.drive(
          exitSlideTween.chain(CurveTween(curve: reverseCurve)),
        );

        final exitScaleTween = Tween<double>(begin: 1.0, end: 0.95);
        final exitScaleAnimation = secondaryAnimation.drive(
          exitScaleTween.chain(CurveTween(curve: reverseCurve)),
        );

        return SlideTransition(
          position: exitSlideAnimation,
          child: ScaleTransition(
            scale: exitScaleAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: ScaleTransition(scale: scaleAnimation, child: child),
            ),
          ),
        );
      },
    );
  }

  /// 创建淡入缩放过渡路由
  /// 适用于模态页面或设置页面
  static Route<T> createFadeScaleRoute<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 250),
    Duration reverseDuration = const Duration(milliseconds: 200),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 淡入动画
        final fadeAnimation = animation.drive(
          CurveTween(curve: Curves.easeOutQuart),
        );

        // 缩放动画
        final scaleAnimation = animation.drive(
          Tween<double>(
            begin: 0.9,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(scale: scaleAnimation, child: child),
        );
      },
    );
  }

  /// 创建向上滑动过渡路由
  /// 适用于底部弹出的页面
  static Route<T> createSlideUpRoute<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final offsetAnimation = animation.drive(
          tween.chain(CurveTween(curve: Curves.easeOutCubic)),
        );

        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }

  /// 创建无动画过渡路由
  /// 用于需要立即显示的页面
  static Route<T> createInstantRoute<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  /// 创建优化的阅读页面过渡动画
  /// 专门为阅读页面设计，提供最佳的用户体验
  static Route<T> createReaderPageRoute<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 进入动画：从右侧滑入
        const enterBegin = Offset(1.0, 0.0);
        const enterEnd = Offset.zero;
        final enterTween = Tween<Offset>(begin: enterBegin, end: enterEnd);
        final enterAnimation = animation.drive(
          enterTween.chain(CurveTween(curve: Curves.easeOutCubic)),
        );

        // 退出动画：向左滑出，同时缩小
        final exitSlideTween = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-1.0, 0.0),
        );
        final exitSlideAnimation = secondaryAnimation.drive(
          exitSlideTween.chain(CurveTween(curve: Curves.easeInCubic)),
        );

        final exitScaleTween = Tween<double>(begin: 1.0, end: 0.9);
        final exitScaleAnimation = secondaryAnimation.drive(
          exitScaleTween.chain(CurveTween(curve: Curves.easeInCubic)),
        );

        // 阴影效果
        final shadowTween = Tween<double>(begin: 0.0, end: 0.5);
        final shadowAnimation = secondaryAnimation.drive(
          shadowTween.chain(CurveTween(curve: Curves.easeInCubic)),
        );

        return Stack(
          children: [
            // 背景阴影层
            if (secondaryAnimation.value > 0)
              Container(
                color: Colors.black.withValues(alpha: 
                  shadowAnimation.value * 0.3,
                ),
              ),
            // 退出的页面
            SlideTransition(
              position: exitSlideAnimation,
              child: ScaleTransition(
                scale: exitScaleAnimation,
                child: Container(), // 占位，实际页面由系统管理
              ),
            ),
            // 进入的页面
            SlideTransition(position: enterAnimation, child: child),
          ],
        );
      },
    );
  }
}

/// 扩展Navigator类，提供便捷的过渡动画方法
extension NavigatorExtensions on NavigatorState {
  /// 使用滑动缩放动画推入新页面
  Future<T?> pushWithSlideScale<T extends Object?>(
    Widget page, {
    Duration? duration,
    Duration? reverseDuration,
  }) {
    return push<T>(
      CustomPageTransitions.createSlideScaleRoute<T>(
        page,
        duration: duration ?? const Duration(milliseconds: 350),
        reverseDuration: reverseDuration ?? const Duration(milliseconds: 300),
      ),
    );
  }

  /// 使用淡入缩放动画推入新页面
  Future<T?> pushWithFadeScale<T extends Object?>(Widget page) {
    return push<T>(CustomPageTransitions.createFadeScaleRoute<T>(page));
  }

  /// 使用阅读页面专用动画推入新页面
  Future<T?> pushReaderPage<T extends Object?>(Widget page) {
    return push<T>(CustomPageTransitions.createReaderPageRoute<T>(page));
  }

  /// 使用向上滑动动画推入新页面
  Future<T?> pushWithSlideUp<T extends Object?>(Widget page) {
    return push<T>(CustomPageTransitions.createSlideUpRoute<T>(page));
  }
}

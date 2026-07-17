// 文件说明：打开/退出书籍的"封面展开"转场。
// 技术要点：封面从书架格子放大至全屏，中途渐变为纸张底色，正文延迟淡入；
// 退出时反向缩回原格子（实时重新解析格子位置，失效则退化为淡出）。

import 'package:flutter/material.dart';

import 'package:xxread/utils/page_transitions.dart';

/// 一次"打开书籍"动画所需的上下文：封面在屏幕上的位置与外观。
///
/// 由入口页面在点击瞬间捕获。拿不到位置的入口（如弹窗按钮）传 null，
/// 路由会退化为原有的平滑淡入转场。
class BookOpenAnimation {
  const BookOpenAnimation({
    required this.sourceRect,
    required this.sourceRadius,
    required this.sourceScreenSize,
    required this.coverBuilder,
    this.rectResolver,
  });

  /// 点击时封面的全局矩形。
  final Rect sourceRect;

  /// 封面卡片的圆角，飞行中渐变为 0。
  final BorderRadius sourceRadius;

  /// 捕获时的屏幕尺寸；退出时若屏幕已变（旋转）且格子不可见则走兜底。
  final Size sourceScreenSize;

  /// 飞行图层里渲染的封面，需与格子里的封面视觉一致。
  final WidgetBuilder coverBuilder;

  /// 退出时重新解析格子位置（书架可能已滚动）；返回 null 表示格子不可见。
  final Rect? Function()? rectResolver;

  /// 从挂在封面组件上的 [key] 捕获动画上下文；组件未挂载时返回 null。
  static BookOpenAnimation? fromCoverKey(
    GlobalKey key, {
    required BorderRadius radius,
    required WidgetBuilder coverBuilder,
  }) {
    final context = key.currentContext;
    final rect = _rectOfKey(key);
    if (context == null || rect == null) return null;
    return BookOpenAnimation(
      sourceRect: rect,
      sourceRadius: radius,
      sourceScreenSize: MediaQuery.sizeOf(context),
      coverBuilder: coverBuilder,
      rectResolver: () => _rectOfKey(key),
    );
  }

  static Rect? _rectOfKey(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }
}

/// 阅读器统一入口路由：有 [animation] 时封面展开，否则平滑淡入。
class BookOpenTransition {
  BookOpenTransition._();

  static Route<T> createRoute<T extends Object?>(
    Widget page, {
    BookOpenAnimation? animation,
  }) {
    if (animation == null) {
      return CustomPageTransitions.createSmoothReaderPageRoute<T>(page);
    }
    return PageRouteBuilder<T>(
      pageBuilder: (context, _, __) => page,
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      opaque: true,
      barrierColor: Colors.transparent,
      // 与 createSmoothReaderPageRoute 相同：飞行只动合成器友好的属性，
      // 让书籍加载的 future 在转场期间保持响应。
      allowSnapshotting: false,
      transitionsBuilder: (context, routeAnimation, secondaryAnimation, child) {
        return _BookOpenFlight(
          animation: routeAnimation,
          data: animation,
          child: child,
        );
      },
    );
  }
}

class _BookOpenFlight extends StatelessWidget {
  const _BookOpenFlight({
    required this.animation,
    required this.data,
    required this.child,
  });

  final Animation<double> animation;
  final BookOpenAnimation data;
  final Widget child;

  // 三条时间轨：封面先飞、纸色中途化开、正文最后浮现。
  // 展开用 M3 emphasized 曲线：前段快、长尾落定；反向播放即为退出的加速归位。
  static const _expand = Interval(0.0, 0.72, curve: Cubic(0.05, 0.7, 0.1, 1.0));
  static const _paper = Interval(0.28, 0.68, curve: Curves.easeInOut);
  static const _content = Interval(0.5, 0.92, curve: Curves.easeOutCubic);
  static const _flightFade = Interval(0.85, 1.0, curve: Curves.easeOut);
  static const _fallbackFade = Interval(0.25, 1.0, curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final page = RepaintBoundary(child: child);
    final cover = data.coverBuilder(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        if (t >= 1.0) return page;

        final screenSize = MediaQuery.sizeOf(context);
        Rect? source = data.sourceRect;
        if (animation.status == AnimationStatus.reverse) {
          source = data.rectResolver?.call() ??
              (screenSize == data.sourceScreenSize ? data.sourceRect : null);
        }
        if (source == null) {
          // 兜底：格子已不可见且屏幕尺寸变了（如阅读中旋转），仅淡出。
          final fade = _fallbackFade.transform(t);
          return Opacity(
            opacity: fade,
            child: Transform.scale(
              scale: 0.96 + 0.04 * fade,
              child: page,
            ),
          );
        }

        final expandT = _expand.transform(t);
        final paperT = _paper.transform(t);
        final contentT = _content.transform(t);
        final flightOpacity = 1.0 - _flightFade.transform(t);
        final rect = Rect.lerp(source, Offset.zero & screenSize, expandT)!;
        final radius =
            BorderRadius.lerp(data.sourceRadius, BorderRadius.zero, expandT)!;

        return Stack(
          children: [
            // 正文全程参与布局（异步加载不受阻），只在后段淡入。
            Opacity(opacity: contentT, child: page),
            if (flightOpacity > 0)
              Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: flightOpacity,
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 纸色打底：contain 适配的封面两侧不露出书架。
                          ColoredBox(color: surface),
                          cover,
                          Opacity(
                            opacity: paperT,
                            child: ColoredBox(color: surface),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

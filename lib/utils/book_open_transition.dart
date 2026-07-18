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
      reverseTransitionDuration: const Duration(milliseconds: 360),
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

  // 打开：封面先飞、纸色中途化开、正文最后浮现。
  static const _expand = Interval(0.0, 0.72, curve: Cubic(0.05, 0.7, 0.1, 1.0));
  static const _paper = Interval(0.28, 0.68, curve: Curves.easeInOut);
  static const _content = Interval(0.5, 0.92, curve: Curves.easeOutCubic);
  static const _flightFade = Interval(0.85, 1.0, curve: Curves.easeOut);

  // 退出使用独立时间轴，不直接倒放打开动画：阅读页先缓慢离开全屏，
  // 中后段再加速归位；纸色负责在正文与封面之间做无闪烁的交接。
  static const _exitContentFade = Interval(
    0.18,
    0.56,
    curve: Curves.easeInOutCubic,
  );
  static const _exitPaperFade = Interval(
    0.38,
    0.72,
    curve: Curves.easeInOutCubic,
  );
  static const _fallbackExitFade = Interval(
    0.12,
    0.88,
    curve: Curves.easeInCubic,
  );

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final page = RepaintBoundary(child: child);
    final cover = data.coverBuilder(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final screenSize = MediaQuery.sizeOf(context);
        final screenRect = Offset.zero & screenSize;
        final isExiting = animation.status == AnimationStatus.reverse;
        Rect? source = data.sourceRect;
        if (isExiting) {
          source = data.rectResolver?.call() ??
              (screenSize == data.sourceScreenSize ? data.sourceRect : null);
        }
        if (source == null) {
          // 兜底：格子已不可见且屏幕尺寸变了（如阅读中旋转），
          // 仍沿用缓起快收的节奏，只在屏幕中央轻微缩小、淡出。
          final exitT = 1.0 - t;
          final motionT = Curves.easeInCubic.transform(exitT);
          final scale = 1.0 - 0.04 * motionT;
          final fallbackRect = Rect.fromCenter(
            center: screenRect.center,
            width: screenRect.width * scale,
            height: screenRect.height * scale,
          );
          return _buildFlightStack(
            screenSize: screenSize,
            page: page,
            pageRect: fallbackRect,
            pageRadius: BorderRadius.zero,
            pageOpacity: 1.0 - _fallbackExitFade.transform(exitT),
            ignorePagePointer: true,
          );
        }

        if (isExiting) {
          final exitT = 1.0 - t;
          final motionT = Curves.easeInCubic.transform(exitT);
          final rect = Rect.lerp(screenRect, source, motionT)!;
          final radius =
              BorderRadius.lerp(BorderRadius.zero, data.sourceRadius, motionT)!;
          return _buildFlightStack(
            screenSize: screenSize,
            page: page,
            pageRect: rect,
            pageRadius: radius,
            pageOpacity: 1.0 - _exitContentFade.transform(exitT),
            ignorePagePointer: true,
            cover: cover,
            coverRect: rect,
            coverRadius: radius,
            coverOpacity: 1.0,
            paperOpacity: 1.0 - _exitPaperFade.transform(exitT),
            surface: surface,
          );
        }

        final expandT = _expand.transform(t);
        final paperT = _paper.transform(t);
        final contentT = _content.transform(t);
        final flightOpacity = 1.0 - _flightFade.transform(t);
        final rect = Rect.lerp(source, screenRect, expandT)!;
        final radius =
            BorderRadius.lerp(data.sourceRadius, BorderRadius.zero, expandT)!;

        return _buildFlightStack(
          screenSize: screenSize,
          page: page,
          pageRect: screenRect,
          pageRadius: BorderRadius.zero,
          pageOpacity: contentT,
          ignorePagePointer: t < 1.0,
          cover: cover,
          coverRect: rect,
          coverRadius: radius,
          coverOpacity: flightOpacity,
          paperOpacity: paperT,
          surface: surface,
        );
      },
    );
  }

  Widget _buildFlightStack({
    required Size screenSize,
    required Widget page,
    required Rect pageRect,
    required BorderRadius pageRadius,
    required double pageOpacity,
    required bool ignorePagePointer,
    Widget? cover,
    Rect? coverRect,
    BorderRadius? coverRadius,
    double coverOpacity = 0.0,
    double paperOpacity = 0.0,
    Color? surface,
  }) {
    return Stack(
      children: [
        if (cover != null && coverOpacity > 0.0)
          KeyedSubtree(
            key: const ValueKey('book-open-transition-cover-layer'),
            child: Positioned.fromRect(
              rect: coverRect!,
              child: IgnorePointer(
                child: Opacity(
                  opacity: coverOpacity,
                  child: ClipRRect(
                    key: const ValueKey('book-open-transition-cover-flight'),
                    borderRadius: coverRadius!,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 纸色打底：contain 适配的封面两侧不露出书架。
                        ColoredBox(color: surface!),
                        cover,
                        Opacity(
                          opacity: paperOpacity,
                          child: ColoredBox(color: surface),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        // 阅读页始终留在同一个 keyed 子树中，退出首帧不会因重新挂载而闪烁。
        KeyedSubtree(
          key: const ValueKey('book-open-transition-reader-layer'),
          child: Positioned.fromRect(
            rect: pageRect,
            child: IgnorePointer(
              ignoring: ignorePagePointer,
              child: ClipRRect(
                key: const ValueKey('book-open-transition-reader-flight'),
                borderRadius: pageRadius,
                child: Opacity(
                  key: const ValueKey('book-open-transition-reader-opacity'),
                  opacity: pageOpacity,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: screenSize.width,
                      height: screenSize.height,
                      child: page,
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
}

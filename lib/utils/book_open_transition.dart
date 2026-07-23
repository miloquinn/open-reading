// 文件说明：打开/退出书籍的"封面展开"转场。
// 技术要点：封面从书架格子放大至全屏，中途渐变为纸张底色，正文同步预热并淡入；
// 退出时反向缩回原格子（实时重新解析格子位置，失效则退化为淡出）。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:xxread/core/reader/reader_transition_work_scope.dart';
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
    try {
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;
      if (!topLeft.isFinite || !size.isFinite || size.isEmpty) return null;
      return topLeft & size;
    } catch (_) {
      // 书架可能正在刷新或切换布局；祖先 RenderTransform 尚未 layout
      // 时 localToGlobal 会在 debug 模式抛断言。该帧交给路由安全降级。
      return null;
    }
  }
}

/// 阅读器统一入口路由：有 [animation] 时封面展开，否则平滑淡入。
class BookOpenTransition {
  BookOpenTransition._();

  static const double _readerWorkExitCutoff = 0.40;
  static const _slowLoadingRevealDelay = Duration(milliseconds: 850);
  static final ValueNotifier<bool> _navigationHiddenListenable = ValueNotifier(
    false,
  );
  static int _activeRouteCount = 0;
  static bool _exitInProgress = false;

  /// 手机首页壳层用它在阅读路由存活期间收起悬浮导航。
  static ValueListenable<bool> get navigationHiddenListenable =>
      _navigationHiddenListenable;

  /// 包含点击后的异步准备期、阅读路由存活期和退出动画；首页用它锁住进入
  /// 阅读器前的系统安全区，避免 Android 侧滑时临时手势栏改变底部布局。
  static bool get hasActiveReaderActivity => _activeRouteCount > 0;

  static void _updateNavigationVisibility() {
    final shouldHide = _activeRouteCount > 0 && !_exitInProgress;
    if (_navigationHiddenListenable.value != shouldHide) {
      _navigationHiddenListenable.value = shouldHide;
    }
  }

  static void _registerActiveRoute() {
    if (_activeRouteCount == 0) _exitInProgress = false;
    _activeRouteCount += 1;
    _updateNavigationVisibility();
  }

  static void _unregisterActiveRoute() {
    if (_activeRouteCount > 0) _activeRouteCount -= 1;
    if (_activeRouteCount == 0) _exitInProgress = false;
    _updateNavigationVisibility();
  }

  /// 在点击回调的第一个同步阶段收起首页悬浮导航。
  static BookOpenTransitionActivity beginActivity() {
    return BookOpenTransitionActivity._();
  }

  /// 阅读器在正文首帧完成绘制后调用；封面层随后才真正渐隐。
  static void markReaderContentReady(BuildContext context) {
    context
        .getInheritedWidgetOfExactType<_BookOpenTransitionScope>()
        ?.activity
        .markContentReady();
  }

  /// 退出动作开始时立即让首页悬浮导航从下方回弹。
  static void beginExit() {
    if (_activeRouteCount == 0 || _exitInProgress) return;
    _exitInProgress = true;
    _updateNavigationVisibility();
  }

  /// Android 预测性返回取消时，阅读页和悬浮导航一起恢复。
  static void cancelExit() {
    if (!_exitInProgress) return;
    _exitInProgress = false;
    _updateNavigationVisibility();
  }

  static PageRoute<T> createRoute<T extends Object?>(
    Widget page, {
    BookOpenAnimation? animation,
    Color? readerBackgroundColor,
    ReaderPageTransitionOrigin origin = ReaderPageTransitionOrigin.standard,
    bool waitForReaderReady = false,
  }) {
    final activity = BookOpenTransitionActivity._(
      holdOpeningCover: animation != null && waitForReaderReady,
    );
    if (animation == null) {
      return CustomPageTransitions.createSmoothReaderPageRoute<T>(
        page,
        origin: origin,
        backgroundColor: readerBackgroundColor,
        routeWrapper: (route, routeAnimation, child) =>
            _AndroidPredictiveBackDriver(
              route: route,
              child: _BookOpenActivityScope(
                activity: activity,
                transitionAnimation: routeAnimation,
                predictiveBackInProgress: () => route.popGestureInProgress,
                child: child,
              ),
            ),
      );
    }
    late final PageRouteBuilder<T> route;
    route = PageRouteBuilder<T>(
      pageBuilder: (context, pageAnimation, _) => _AndroidPredictiveBackDriver(
        route: route,
        child: _BookOpenActivityScope(
          activity: activity,
          transitionAnimation: pageAnimation,
          predictiveBackInProgress: () => route.popGestureInProgress,
          child: page,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 360),
      opaque: true,
      barrierColor: Colors.transparent,
      // Keep the live destination mounted behind the cover flight so parsing
      // and pagination can finish before the reader becomes visible. Reader
      // pages still defer system-bar changes until the route settles.
      allowSnapshotting: false,
      transitionsBuilder: (context, routeAnimation, secondaryAnimation, child) {
        return _BookOpenFlight(
          animation: routeAnimation,
          data: animation,
          activity: activity,
          readerBackgroundColor: readerBackgroundColor,
          predictiveBackInProgress: () => route.popGestureInProgress,
          child: child,
        );
      },
    );
    return route;
  }

  /// 等到反向转场真正移出 Overlay 后再恢复书架数据。
  /// Navigator.push 的 Future 在 pop 起步时就会完成，不能代表动画已结束。
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    PageRoute<T> route,
  ) async {
    final result = await Navigator.of(context).push<T>(route);
    await route.completed;
    return result;
  }
}

class BookOpenTransitionActivity {
  BookOpenTransitionActivity._({bool holdOpeningCover = false})
    : _openingPhase = ValueNotifier(
        holdOpeningCover
            ? _BookOpeningPhase.waiting
            : _BookOpeningPhase.content,
      ) {
    BookOpenTransition._registerActiveRoute();
    if (holdOpeningCover) {
      _slowLoadingTimer = Timer(BookOpenTransition._slowLoadingRevealDelay, () {
        if (!_disposed && _openingPhase.value == _BookOpeningPhase.waiting) {
          _openingPhase.value = _BookOpeningPhase.loading;
        }
      });
    }
  }

  final ValueNotifier<_BookOpeningPhase> _openingPhase;
  Timer? _slowLoadingTimer;
  bool _disposed = false;

  void markContentReady() {
    if (_disposed || _openingPhase.value == _BookOpeningPhase.content) return;
    _slowLoadingTimer?.cancel();
    _openingPhase.value = _BookOpeningPhase.content;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _slowLoadingTimer?.cancel();
    BookOpenTransition._unregisterActiveRoute();
  }
}

enum _BookOpeningPhase { waiting, loading, content }

class _BookOpenTransitionScope extends InheritedWidget {
  const _BookOpenTransitionScope({
    required this.activity,
    required super.child,
  });

  final BookOpenTransitionActivity activity;

  @override
  bool updateShouldNotify(_BookOpenTransitionScope oldWidget) {
    return !identical(activity, oldWidget.activity);
  }
}

class _BookOpenActivityScope extends StatefulWidget {
  const _BookOpenActivityScope({
    required this.activity,
    required this.child,
    this.transitionAnimation,
    this.predictiveBackInProgress,
  });

  final BookOpenTransitionActivity activity;
  final Animation<double>? transitionAnimation;
  final ValueGetter<bool>? predictiveBackInProgress;
  final Widget child;

  @override
  State<_BookOpenActivityScope> createState() => _BookOpenActivityScopeState();
}

class _BookOpenActivityScopeState extends State<_BookOpenActivityScope> {
  bool _sawEntranceMotion = false;
  bool _entranceCompleted = false;

  @override
  void initState() {
    super.initState();
    _attachTransitionAnimation();
  }

  @override
  void didUpdateWidget(covariant _BookOpenActivityScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.transitionAnimation, widget.transitionAnimation)) {
      return;
    }
    oldWidget.transitionAnimation?.removeStatusListener(
      _onTransitionStatusChanged,
    );
    _sawEntranceMotion = false;
    _entranceCompleted = false;
    _attachTransitionAnimation();
  }

  void _attachTransitionAnimation() {
    final transitionAnimation = widget.transitionAnimation;
    if (transitionAnimation == null) {
      _entranceCompleted = true;
      return;
    }
    _sawEntranceMotion = transitionAnimation.status == AnimationStatus.forward;
    transitionAnimation.addStatusListener(_onTransitionStatusChanged);
  }

  void _onTransitionStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      _sawEntranceMotion = true;
      return;
    }
    if (status != AnimationStatus.completed ||
        !_sawEntranceMotion ||
        _entranceCompleted) {
      return;
    }
    setState(() => _entranceCompleted = true);
  }

  @override
  void dispose() {
    widget.transitionAnimation?.removeStatusListener(
      _onTransitionStatusChanged,
    );
    // 路由子树在 frame finalize 阶段卸载，延后通知底层首页。
    scheduleMicrotask(widget.activity.dispose);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transitionAnimation = widget.transitionAnimation;
    if (transitionAnimation == null) return widget.child;
    return AnimatedBuilder(
      animation: transitionAnimation,
      child: widget.child,
      builder: (context, child) {
        final isExiting =
            transitionAnimation.status == AnimationStatus.reverse ||
            (widget.predictiveBackInProgress?.call() ?? false);
        final workEnabled =
            _entranceCompleted &&
            (isExiting
                ? 1.0 - transitionAnimation.value <
                      BookOpenTransition._readerWorkExitCutoff
                : transitionAnimation.status == AnimationStatus.completed);
        return _BookOpenTransitionScope(
          activity: widget.activity,
          child: ReaderTransitionWorkScope(
            enabled: workEnabled,
            child: TickerMode(
              key: const ValueKey('book-open-transition-reader-work-mode'),
              enabled: workEnabled,
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

class _AndroidPredictiveBackDriver extends StatefulWidget {
  const _AndroidPredictiveBackDriver({
    required this.route,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<_AndroidPredictiveBackDriver> createState() =>
      _AndroidPredictiveBackDriverState();
}

class _AndroidPredictiveBackDriverState
    extends State<_AndroidPredictiveBackDriver>
    with WidgetsBindingObserver {
  bool _handlingGesture = false;

  bool get _gestureEnabled =>
      defaultTargetPlatform == TargetPlatform.android &&
      widget.route.isCurrent &&
      widget.route.popGestureEnabled;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_gestureEnabled) return false;
    _handlingGesture = true;
    BookOpenTransition.beginExit();
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (!_handlingGesture) return;
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
  }

  @override
  void handleCancelBackGesture() {
    if (!_handlingGesture) return;
    _handlingGesture = false;
    widget.route.handleCancelBackGesture();
    BookOpenTransition.cancelExit();
  }

  @override
  void handleCommitBackGesture() {
    if (!_handlingGesture) return;
    _handlingGesture = false;
    final navigator = widget.route.navigator;
    if (widget.route.isCurrent) navigator?.pop();

    final animation = widget.route.animation;
    if (animation?.isAnimating ?? false) {
      late final AnimationStatusListener stopGesture;
      stopGesture = (status) {
        if (status != AnimationStatus.dismissed &&
            status != AnimationStatus.completed) {
          return;
        }
        animation!.removeStatusListener(stopGesture);
        navigator?.didStopUserGesture();
      };
      animation!.addStatusListener(stopGesture);
    } else {
      navigator?.didStopUserGesture();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BookOpenFlight extends StatefulWidget {
  const _BookOpenFlight({
    required this.animation,
    required this.data,
    required this.activity,
    required this.readerBackgroundColor,
    required this.predictiveBackInProgress,
    required this.child,
  });

  final Animation<double> animation;
  final BookOpenAnimation data;
  final BookOpenTransitionActivity activity;
  final Color? readerBackgroundColor;
  final ValueGetter<bool> predictiveBackInProgress;
  final Widget child;

  @override
  State<_BookOpenFlight> createState() => _BookOpenFlightState();
}

class _BookOpenFlightState extends State<_BookOpenFlight>
    with SingleTickerProviderStateMixin {
  static const _openingHold = 0.52;
  static const _expand = Interval(0.0, 0.72, curve: Cubic(0.16, 1.0, 0.3, 1.0));
  static const _openingHandoff = Interval(
    _openingHold,
    1.0,
    curve: Curves.easeInOutCubic,
  );

  // 退出使用独立时间轴，不直接倒放打开动画：阅读页快速响应缩回，
  // 后段逐渐减速落入封面。封面在正文下方提前就绪，正文透明度直接
  // 映射手势进度：轻微侧滑就开始交接，约四成返回距离时完整露出封面。
  static const _exitCoverHandoff = Interval(
    0.02,
    BookOpenTransition._readerWorkExitCutoff,
  );
  static const _fallbackExitFade = Interval(
    0.12,
    0.88,
    curve: Curves.easeInCubic,
  );
  static const _exitMotionCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  Animation<double> get animation => widget.animation;
  BookOpenAnimation get data => widget.data;
  Color? get readerBackgroundColor => widget.readerBackgroundColor;
  ValueGetter<bool> get predictiveBackInProgress =>
      widget.predictiveBackInProgress;
  Widget get child => widget.child;

  late final AnimationController _openingRevealController;
  final SnapshotController _exitSnapshotController = SnapshotController();

  @override
  void initState() {
    super.initState();
    _openingRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: widget.activity._openingPhase.value == _BookOpeningPhase.waiting
          ? 0
          : 1,
    );
    widget.activity._openingPhase.addListener(_onOpeningPhaseChanged);
    widget.animation
      ..addListener(_syncExitSnapshotState)
      ..addStatusListener(_onRouteAnimationStatusChanged);
    BookOpenTransition._navigationHiddenListenable.addListener(
      _syncExitSnapshotState,
    );
    _syncExitSnapshotState();
  }

  @override
  void didUpdateWidget(covariant _BookOpenFlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.animation, widget.animation)) {
      oldWidget.animation
        ..removeListener(_syncExitSnapshotState)
        ..removeStatusListener(_onRouteAnimationStatusChanged);
      widget.animation
        ..addListener(_syncExitSnapshotState)
        ..addStatusListener(_onRouteAnimationStatusChanged);
      _syncExitSnapshotState();
    }
    if (identical(oldWidget.activity, widget.activity)) return;
    oldWidget.activity._openingPhase.removeListener(_onOpeningPhaseChanged);
    widget.activity._openingPhase.addListener(_onOpeningPhaseChanged);
    _openingRevealController.value =
        widget.activity._openingPhase.value == _BookOpeningPhase.waiting
        ? 0
        : 1;
  }

  void _onOpeningPhaseChanged() {
    if (widget.activity._openingPhase.value == _BookOpeningPhase.waiting ||
        _openingRevealController.isCompleted) {
      return;
    }
    _openingRevealController.forward();
  }

  void _onRouteAnimationStatusChanged(AnimationStatus _) {
    _syncExitSnapshotState();
  }

  void _syncExitSnapshotState() {
    if (animation.status == AnimationStatus.completed &&
        !BookOpenTransition._exitInProgress) {
      if (_exitSnapshotController.allowSnapshotting) {
        _exitSnapshotController.allowSnapshotting = false;
      }
      return;
    }
    final recoveringCancelledExit =
        _exitSnapshotController.allowSnapshotting &&
        animation.status == AnimationStatus.forward &&
        animation.value < 1.0;
    final freezeReader =
        BookOpenTransition._exitInProgress ||
        animation.status == AnimationStatus.reverse ||
        predictiveBackInProgress() ||
        recoveringCancelledExit;
    if (_exitSnapshotController.allowSnapshotting != freezeReader) {
      _exitSnapshotController.allowSnapshotting = freezeReader;
    }
  }

  double _openingVisualProgress(double routeProgress) {
    if (routeProgress <= _openingHold) return routeProgress;
    final reveal = Curves.easeInOutCubic.transform(
      _openingRevealController.value,
    );
    return _openingHold + (routeProgress - _openingHold) * reveal;
  }

  @override
  void dispose() {
    widget.activity._openingPhase.removeListener(_onOpeningPhaseChanged);
    widget.animation
      ..removeListener(_syncExitSnapshotState)
      ..removeStatusListener(_onRouteAnimationStatusChanged);
    BookOpenTransition._navigationHiddenListenable.removeListener(
      _syncExitSnapshotState,
    );
    _exitSnapshotController.dispose();
    _openingRevealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appSurface = Theme.of(context).colorScheme.surface;
    final page = SnapshotWidget(
      key: const ValueKey('book-open-transition-reader-snapshot'),
      controller: _exitSnapshotController,
      mode: SnapshotMode.permissive,
      autoresize: true,
      child: RepaintBoundary(child: child),
    );
    final cover = data.coverBuilder(context);
    return AnimatedBuilder(
      animation: Listenable.merge([animation, _openingRevealController]),
      builder: (context, _) {
        final routeT = animation.value;
        final screenSize = MediaQuery.sizeOf(context);
        final screenRect = Offset.zero & screenSize;
        final isExiting =
            animation.status == AnimationStatus.reverse ||
            predictiveBackInProgress();
        final t = isExiting ? routeT : _openingVisualProgress(routeT);
        final surface = isExiting
            ? appSurface
            : readerBackgroundColor ?? appSurface;
        Rect? source = data.sourceRect;
        if (isExiting) {
          Rect? resolvedSource;
          try {
            resolvedSource = data.rectResolver?.call();
          } catch (_) {
            resolvedSource = null;
          }
          source =
              resolvedSource ??
              (screenSize == data.sourceScreenSize ? data.sourceRect : null);
        }
        if (source == null) {
          // 兜底：格子已不可见且屏幕尺寸变了（如阅读中旋转），
          // 仍沿用先快后慢的节奏，只在屏幕中央轻微缩小、淡出。
          final exitT = 1.0 - t;
          final motionT = _exitMotionCurve.transform(exitT);
          final pageOpacity = 1.0 - _fallbackExitFade.transform(exitT);
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
            pageOpacity: pageOpacity,
            ignorePagePointer: true,
          );
        }

        if (isExiting) {
          final exitT = 1.0 - t;
          final motionT = _exitMotionCurve.transform(exitT);
          final coverHandoffT = _exitCoverHandoff.transform(exitT);
          final rect = Rect.lerp(screenRect, source, motionT)!;
          final radius = BorderRadius.lerp(
            BorderRadius.zero,
            data.sourceRadius,
            motionT,
          )!;
          return _buildFlightStack(
            screenSize: screenSize,
            page: page,
            pageRect: rect,
            pageRadius: radius,
            pageOpacity: 1.0 - coverHandoffT,
            ignorePagePointer: true,
            cover: cover,
            coverRect: rect,
            coverRadius: radius,
            coverOpacity: 1.0,
            paperOpacity: 0.0,
            surface: surface,
          );
        }

        final expandT = _expand.transform(t);
        final handoffT = _openingHandoff.transform(t);
        final rect = Rect.lerp(source, screenRect, expandT)!;
        final radius = BorderRadius.lerp(
          data.sourceRadius,
          BorderRadius.zero,
          expandT,
        )!;

        final openingInteractive =
            routeT >= 1.0 &&
            widget.activity._openingPhase.value != _BookOpeningPhase.waiting;
        return _buildFlightStack(
          screenSize: screenSize,
          page: page,
          pageRect: screenRect,
          pageRadius: BorderRadius.zero,
          pageOpacity: handoffT,
          ignorePagePointer: !openingInteractive,
          cover: cover,
          coverRect: rect,
          coverRadius: radius,
          coverOpacity: 1.0 - handoffT,
          paperOpacity: 0.0,
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
                  key: const ValueKey('book-open-transition-cover-opacity'),
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
                          key: const ValueKey(
                            'book-open-transition-paper-opacity',
                          ),
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

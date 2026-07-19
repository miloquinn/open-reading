import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../core/reader/reader_page_turn_geometry.dart';
import 'reader_paper_page_leaf.dart';

typedef ReaderPageTurnCallback = FutureOr<void> Function();

enum ReaderPageBindingEdge { left, right }

@immutable
class ReaderPageSnapshot {
  const ReaderPageSnapshot({
    required this.key,
    required this.contentRevision,
    required this.child,
  });

  final ReaderPageSnapshotKey key;
  final int contentRevision;
  final Widget child;
}

class ReaderPageCurlController {
  _ReaderShaderPageCurlState? _state;

  Future<void> turnForward() =>
      _state?._requestProgrammaticTurn(ReaderPageTurnDirection.forward) ??
      Future<void>.value();

  Future<void> turnBackward() =>
      _state?._requestProgrammaticTurn(ReaderPageTurnDirection.backward) ??
      Future<void>.value();

  @visibleForTesting
  Offset? get debugTouchPosition {
    final geometry = _state?._geometry;
    if (geometry == null) return null;
    return geometry.motion == ReaderPageTurnMotion.incoming
        ? geometry.foldPoint
        : geometry.reflectedCorner;
  }

  @visibleForTesting
  bool get debugIsCatchingUp => _state?._catchUpStartPointer != null;

  @visibleForTesting
  Offset? get debugFoldStart => _state?._geometry?.foldStart;

  @visibleForTesting
  Offset? get debugFoldEnd => _state?._geometry?.foldEnd;

  @visibleForTesting
  ReaderPageTurnMotion? get debugMotion => _state?._geometry?.motion;

  @visibleForTesting
  bool get debugActiveSourceIsCurrent {
    final state = _state;
    final source = state?._activeSourcePage;
    return state != null &&
        source != null &&
        _sameSnapshot(source, state.widget.currentPage);
  }

  @visibleForTesting
  bool get debugAnimationReady => _state?._animationReady ?? false;

  @visibleForTesting
  Offset? get debugShaderLineA => _state?._geometry?.lineA;

  @visibleForTesting
  Offset? get debugShaderLineB => _state?._geometry?.lineB;

  @visibleForTesting
  bool get debugUsesProvisionalSnapshot {
    final state = _state;
    final source = state?._activeSourcePage;
    return state != null &&
        source != null &&
        state._syncSnapshotKeys.contains(source.key);
  }

  void _attach(_ReaderShaderPageCurlState state) => _state = state;

  void _detach(_ReaderShaderPageCurlState state) {
    if (identical(_state, state)) _state = null;
  }
}

/// Serializes page turns across the two independently rendered leaves of a
/// tablet spread.
///
/// Each leaf keeps its own directional spring and queue, while this shared
/// coordinator guarantees that only one leaf can animate or commit at a time.
/// A released slot becomes available after the next frame so the host has a
/// chance to rebuild both leaves with the newly committed spread first.
class ReaderPageCurlCoordinator extends ChangeNotifier {
  Object? _owner;
  bool _availableAfterFrame = true;
  bool _notificationScheduled = false;
  bool _disposed = false;

  bool _tryAcquire(Object owner) {
    if (_disposed) return false;
    if (identical(_owner, owner)) return true;
    if (_owner != null || !_availableAfterFrame) return false;
    _owner = owner;
    return true;
  }

  void _release(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _availableAfterFrame = false;
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (_disposed) return;
      _availableAfterFrame = true;
      notifyListeners();
    });
  }

  @visibleForTesting
  bool get debugIsBusy => _owner != null || !_availableAfterFrame;

  @override
  void dispose() {
    _disposed = true;
    _owner = null;
    super.dispose();
  }
}

/// A shader-backed classic paper-fold page-turn surface.
///
/// Gesture geometry and spring physics live outside either renderer. Page
/// snapshots use a bounded, byte-aware session cache keyed by page identity,
/// layout fingerprint and theme. The first frame always paints the live leaf;
/// GPU readback starts only after that frame.
class ReaderShaderPageCurl extends StatefulWidget {
  const ReaderShaderPageCurl({
    super.key,
    required this.currentPage,
    required this.onTurnForward,
    required this.onTurnBackward,
    required this.paperColor,
    this.forwardPage,
    this.backwardPage,
    this.controller,
    this.preparePages,
    this.coordinator,
    this.edgeDragOnly = false,
    this.bindingEdge = ReaderPageBindingEdge.left,
  });

  final ReaderPageSnapshot currentPage;
  final ReaderPageSnapshot? forwardPage;
  final ReaderPageSnapshot? backwardPage;
  final ReaderPageTurnCallback onTurnForward;
  final ReaderPageTurnCallback onTurnBackward;
  final Color paperColor;
  final ReaderPageCurlController? controller;
  final ReaderPageCurlCoordinator? coordinator;
  final Future<void> Function()? preparePages;

  /// The physical spine edge of this leaf in screen coordinates.
  ///
  /// Turn direction and binding placement are intentionally independent:
  /// phone leaves remain bound on the left for both directions, while the
  /// left leaf of a two-page spread is bound on the right.
  final ReaderPageBindingEdge bindingEdge;

  /// Restricts interactive turns to the free outer edge.
  ///
  /// A two-page spread enables this on each half so the center spine cannot
  /// start a page turn. Programmatic turns remain available for taps and keys.
  final bool edgeDragOnly;

  @override
  State<ReaderShaderPageCurl> createState() => _ReaderShaderPageCurlState();
}

enum _PageTurnPhase {
  idle,
  pointerPending,
  dragging,
  settlingBack,
  settlingCommit,
  awaitingPageUpdate,
}

class _ReaderShaderPageCurlState extends State<ReaderShaderPageCurl>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const int _snapshotBudgetBytes = 48 * 1024 * 1024;
  static const int _perSnapshotBudgetBytes = 8 * 1024 * 1024;
  static const int _maxQueuedProgrammaticTurns = 2;
  static const double _edgeStartFraction = 0.30;
  static const double _intentSlop = 4;
  static const double _horizontalIntentRatio = 1.12;
  static const double _predictionHorizonSeconds = 0.14;
  static const double _commitProjection = 0.28;
  static const Duration _middleDragCatchUpDuration =
      Duration(milliseconds: 120);
  static const double _middleDragTiltStart = 0.55;

  final GlobalKey _currentKey = GlobalKey(debugLabel: 'curl-current');
  final GlobalKey _forwardKey = GlobalKey(debugLabel: 'curl-forward');
  final GlobalKey _backwardKey = GlobalKey(debugLabel: 'curl-backward');
  final _ReaderSnapshotCache _snapshotCache = _ReaderSnapshotCache(
    maxBytes: _snapshotBudgetBytes,
    maxEntries: 7,
  );
  final Map<_SnapshotRequestKey, Future<ui.Image?>> _inFlightCaptures = {};
  final Queue<_QueuedProgrammaticTurn> _programmaticTurns = Queue();
  final Set<ReaderPageSnapshotKey> _syncSnapshotKeys = {};
  final List<ui.Image> _retiredSnapshotImages = [];

  late final Ticker _forwardSpringTicker;
  late final Ticker _backwardSpringTicker;
  late final Ticker _catchUpTicker;
  ui.FragmentShader? _classicFoldShader;
  final _forwardSpring = _ReaderSpringChannel();
  final _backwardSpring = _ReaderSpringChannel();
  Completer<void>? _turnCompleter;

  Size _viewportSize = Size.zero;
  Offset? _pointerDown;
  Offset? _dragOrigin;
  Offset? _catchUpStartPointer;
  Offset? _latestDragPointer;
  ReaderPageTurnDirection? _direction;
  ReaderPageTurnGeometry? _geometry;
  ReaderPageSnapshot? _activeSourcePage;
  ReaderPageSnapshot? _activeTargetPage;
  GlobalKey? _activeSourceKey;
  GlobalKey? _activeTargetKey;
  _PageTurnPhase _phase = _PageTurnPhase.idle;
  bool _warmScheduled = false;
  bool _warmAfterTurn = false;
  int _captureGeneration = 0;
  int _preparedGeneration = -1;
  int _preparingGeneration = -1;
  Future<void>? _preparingPages;
  ReaderPageCurlCoordinator? _ownedCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _forwardSpringTicker = createTicker(
      (elapsed) => _onSpringTick(ReaderPageTurnDirection.forward, elapsed),
    );
    _backwardSpringTicker = createTicker(
      (elapsed) => _onSpringTick(ReaderPageTurnDirection.backward, elapsed),
    );
    _catchUpTicker = createTicker(_onCatchUpTick);
    widget.controller?._attach(this);
    widget.coordinator?.addListener(_onCoordinatorAvailable);
    unawaited(_loadClassicFoldShader());
    _scheduleWarmSnapshots();
  }

  @override
  void didUpdateWidget(covariant ReaderShaderPageCurl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (!identical(oldWidget.coordinator, widget.coordinator)) {
      oldWidget.coordinator?.removeListener(_onCoordinatorAvailable);
      if (identical(_ownedCoordinator, oldWidget.coordinator)) {
        oldWidget.coordinator?._release(this);
        _ownedCoordinator = null;
      }
      widget.coordinator?.addListener(_onCoordinatorAvailable);
    }
    final pagesChanged = !_sameSnapshot(
          oldWidget.currentPage,
          widget.currentPage,
        ) ||
        !_sameOptionalSnapshot(oldWidget.forwardPage, widget.forwardPage) ||
        !_sameOptionalSnapshot(oldWidget.backwardPage, widget.backwardPage);
    if (pagesChanged) {
      _captureGeneration++;
      _preparedGeneration = -1;
      if (_phase == _PageTurnPhase.idle) {
        _scheduleWarmSnapshots();
      } else {
        _warmAfterTurn = true;
      }
    }
  }

  @override
  void didHaveMemoryPressure() {
    _snapshotCache.clearExcept(_protectedSnapshotKeys);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?._detach(this);
    widget.coordinator?.removeListener(_onCoordinatorAvailable);
    _ownedCoordinator?._release(this);
    _ownedCoordinator = null;
    final completer = _turnCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    for (final turn in _programmaticTurns) {
      if (!turn.completer.isCompleted) turn.completer.complete();
    }
    _programmaticTurns.clear();
    _catchUpTicker.dispose();
    _forwardSpringTicker.dispose();
    _backwardSpringTicker.dispose();
    _snapshotCache.dispose();
    for (final image in _retiredSnapshotImages) {
      image.dispose();
    }
    _retiredSnapshotImages.clear();
    _classicFoldShader?.dispose();
    super.dispose();
  }

  Future<void> _loadClassicFoldShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/reader_classic_page_fold.frag',
      );
      if (!mounted) return;
      setState(() => _classicFoldShader = program.fragmentShader());
    } catch (error, stackTrace) {
      debugPrint('Reader classic page fold shader failed to load: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _scheduleWarmSnapshots() {
    if (_warmScheduled) return;
    _warmScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmScheduled = false;
      if (!mounted || _viewportSize.isEmpty) return;
      final generation = _captureGeneration;
      unawaited(_warmSnapshots(generation));
    });
  }

  Future<void> _warmSnapshots(int generation) async {
    await _ensureSnapshot(
      widget.currentPage,
      _currentKey,
      generation,
    );
    if (!mounted || generation != _captureGeneration) return;
    final adjacentCaptures = <Future<ui.Image?>>[];
    final forward = widget.forwardPage;
    if (forward != null) {
      adjacentCaptures.add(
        _ensureSnapshot(forward, _forwardKey, generation),
      );
    }
    final backward = widget.backwardPage;
    if (backward != null) {
      adjacentCaptures.add(
        _ensureSnapshot(backward, _backwardKey, generation),
      );
    }
    if (adjacentCaptures.isNotEmpty) {
      await Future.wait(adjacentCaptures);
    }
  }

  Future<void> _preparePages(int generation) async {
    if (_preparedGeneration == generation) return;
    if (_preparingGeneration == generation) {
      final preparing = _preparingPages;
      if (preparing != null) await preparing;
      return;
    }
    _preparingGeneration = generation;
    final preparing = _runPreparePages(generation);
    _preparingPages = preparing;
    try {
      await preparing;
      if (mounted && generation == _captureGeneration) {
        _preparedGeneration = generation;
      }
    } finally {
      if (_preparingGeneration == generation) {
        _preparingGeneration = -1;
        _preparingPages = null;
      }
    }
  }

  Future<void> _runPreparePages(int generation) async {
    final preparePages = widget.preparePages;
    if (preparePages != null) {
      try {
        await preparePages();
      } catch (error, stackTrace) {
        debugPrint('Reader page turn preparation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (mounted && generation == _captureGeneration) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<ui.Image?> _ensureSnapshot(
    ReaderPageSnapshot page,
    GlobalKey boundaryKey,
    int generation,
  ) async {
    if (!mounted || _viewportSize.isEmpty) return null;
    final ratio = readerPageSnapshotPixelRatio(
      logicalSize: _viewportSize,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      perEntryByteBudget: _perSnapshotBudgetBytes,
    );
    final cached = _snapshotCache.lookup(
      page.key,
      contentRevision: page.contentRevision,
      logicalSize: _viewportSize,
      pixelRatio: ratio,
    );
    if (cached != null && !_syncSnapshotKeys.contains(page.key)) return cached;

    final requestKey = _SnapshotRequestKey(
      pageKey: page.key,
      contentRevision: page.contentRevision,
      logicalSize: _viewportSize,
      pixelRatio: ratio,
      generation: generation,
    );
    final existing = _inFlightCaptures[requestKey];
    if (existing != null) return existing;
    final future = _captureSnapshot(
      page: page,
      boundaryKey: boundaryKey,
      generation: generation,
      pixelRatio: ratio,
    );
    _inFlightCaptures[requestKey] = future;
    try {
      return await future;
    } finally {
      _inFlightCaptures.remove(requestKey);
    }
  }

  Future<ui.Image?> _captureSnapshot({
    required ReaderPageSnapshot page,
    required GlobalKey boundaryKey,
    required int generation,
    required double pixelRatio,
  }) async {
    await _preparePages(generation);
    if (!mounted || generation != _captureGeneration) return null;
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) return null;
    ui.Image? image;
    try {
      image = await boundary.toImage(pixelRatio: pixelRatio);
    } catch (error, stackTrace) {
      debugPrint('Reader page turn capture failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
    if (!mounted || generation != _captureGeneration) {
      image.dispose();
      return null;
    }
    final existing = _snapshotCache.lookup(
      page.key,
      contentRevision: page.contentRevision,
      logicalSize: _viewportSize,
      pixelRatio: pixelRatio,
    );
    final replacesProvisional = _syncSnapshotKeys.contains(page.key);
    if (existing != null && !replacesProvisional) {
      image.dispose();
      return existing;
    }
    final retired = _snapshotCache.store(
      page.key,
      image: image,
      contentRevision: page.contentRevision,
      logicalSize: _viewportSize,
      pixelRatio: pixelRatio,
      protectedKeys: _protectedSnapshotKeys,
      retainPrevious: replacesProvisional,
    );
    if (retired != null) _retiredSnapshotImages.add(retired);
    if (replacesProvisional) _syncSnapshotKeys.remove(page.key);
    if (mounted) setState(() {});
    return image;
  }

  Set<ReaderPageSnapshotKey> get _protectedSnapshotKeys => {
        widget.currentPage.key,
        if (widget.forwardPage case final page?) page.key,
        if (widget.backwardPage case final page?) page.key,
        if (_activeSourcePage case final page?) page.key,
        if (_activeTargetPage case final page?) page.key,
      };

  void _onPointerDown(PointerDownEvent event) {
    if (_phase != _PageTurnPhase.idle) return;
    _pointerDown = event.localPosition;
  }

  void _onPanStart(DragStartDetails details) {
    if (_phase != _PageTurnPhase.idle || _viewportSize.isEmpty) return;
    final origin = _pointerDown ?? details.localPosition;
    _dragOrigin = origin;
    final fraction = origin.dx / _viewportSize.width;
    if (fraction >= 1 - _edgeStartFraction && widget.forwardPage != null) {
      final started = _beginDrag(
        ReaderPageTurnDirection.forward,
        pointer: details.localPosition,
        origin: origin,
      );
      if (!started) {
        _pointerDown = null;
        _dragOrigin = null;
      }
    } else if (fraction <= _edgeStartFraction && widget.backwardPage != null) {
      final started = _beginDrag(
        ReaderPageTurnDirection.backward,
        pointer: details.localPosition,
        origin: origin,
      );
      if (!started) {
        _pointerDown = null;
        _dragOrigin = null;
      }
    } else if (!widget.edgeDragOnly) {
      setState(() => _phase = _PageTurnPhase.pointerPending);
    } else {
      _pointerDown = null;
      _dragOrigin = null;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_phase == _PageTurnPhase.pointerPending) {
      final origin = _dragOrigin;
      if (origin == null) return;
      final delta = details.localPosition - origin;
      if (delta.distance < _intentSlop ||
          delta.dx.abs() < delta.dy.abs() * _horizontalIntentRatio) {
        return;
      }
      final direction = delta.dx < 0
          ? ReaderPageTurnDirection.forward
          : ReaderPageTurnDirection.backward;
      if (!_hasPage(direction)) {
        _resetToIdle();
        return;
      }
      final started = _beginDrag(
        direction,
        pointer: details.localPosition,
        origin: origin,
        catchUpFromEdge: _motionFor(direction) == ReaderPageTurnMotion.outgoing,
      );
      if (!started) _resetToIdle();
      return;
    }
    if (_phase != _PageTurnPhase.dragging || _direction == null) return;
    if (_catchUpStartPointer != null) {
      _latestDragPointer = details.localPosition;
      return;
    }
    setState(() {
      _geometry = _geometryFromPointer(
        direction: _direction!,
        pointer: details.localPosition,
        origin: _dragOrigin!,
      );
    });
  }

  bool _beginDrag(
    ReaderPageTurnDirection direction, {
    required Offset pointer,
    required Offset origin,
    bool catchUpFromEdge = false,
  }) {
    final layers = _turnLayers(direction);
    if (layers == null || !_acquireTurnSlot()) return false;
    final source = layers.source;
    final target = layers.target;
    _direction = direction;
    _dragOrigin = origin;
    _latestDragPointer = pointer;
    _activeSourcePage = source;
    _activeTargetPage = target;
    _activeSourceKey = layers.sourceKey;
    _activeTargetKey = layers.targetKey;
    _captureActiveSourceSync(
      source,
      layers.sourceKey,
      refreshAfterPreparation: !_sameSnapshot(source, widget.currentPage),
    );
    final initialPointer = catchUpFromEdge
        ? Offset(
            direction == ReaderPageTurnDirection.forward
                ? _viewportSize.width
                : 0,
            origin.dy,
          )
        : pointer;
    _catchUpStartPointer = catchUpFromEdge ? initialPointer : null;
    setState(() {
      _geometry = _geometryFromPointer(
        direction: direction,
        pointer: initialPointer,
        origin: origin,
      );
      _phase = _PageTurnPhase.dragging;
    });
    unawaited(_ensureActiveSourceSnapshot(direction));
    unawaited(_ensureActiveSnapshots(direction));
    if (catchUpFromEdge) {
      _startCatchUp();
    }
    return true;
  }

  bool _acquireTurnSlot() {
    final coordinator = widget.coordinator;
    if (coordinator == null) return true;
    if (!coordinator._tryAcquire(this)) return false;
    _ownedCoordinator = coordinator;
    return true;
  }

  void _onCoordinatorAvailable() {
    if (mounted && _phase == _PageTurnPhase.idle) {
      _drainProgrammaticTurns();
    }
  }

  void _startCatchUp() {
    if (!mounted ||
        _phase != _PageTurnPhase.dragging ||
        _catchUpStartPointer == null) {
      return;
    }
    if (_catchUpTicker.isActive) _catchUpTicker.stop();
    _catchUpTicker.start();
  }

  void _onCatchUpTick(Duration elapsed) {
    final start = _catchUpStartPointer;
    final target = _latestDragPointer;
    final direction = _direction;
    final origin = _dragOrigin;
    if (_phase != _PageTurnPhase.dragging ||
        start == null ||
        target == null ||
        direction == null ||
        origin == null) {
      _stopCatchUp();
      return;
    }
    final linearProgress =
        (elapsed.inMicroseconds / _middleDragCatchUpDuration.inMicroseconds)
            .clamp(0.0, 1.0);
    // A front-loaded ease-out made the first painted fold jump most of the
    // distance in one or two frames. Ease-in-out keeps the edge origin visible
    // before accelerating into the live pointer, while remaining short enough
    // to feel like catch-up rather than a separate animation.
    final horizontalProgress = Curves.easeInOutCubic.transform(linearProgress);
    // Keep the first part of a middle-origin catch-up as a flat vertical roll.
    // Feeding small pointer-Y jitter into the almost-collapsed right-edge curl
    // rotates a very thin polygon and can produce one or two malformed frames.
    // Once the fold is well clear of the edge, blend the live Y back in so the
    // page finishes the catch-up at the actual finger position.
    final tiltLinearProgress =
        ((linearProgress - _middleDragTiltStart) / (1 - _middleDragTiltStart))
            .clamp(0.0, 1.0);
    final tiltProgress = Curves.easeInOutCubic.transform(tiltLinearProgress);
    final pointer = Offset(
      start.dx + (target.dx - start.dx) * horizontalProgress,
      origin.dy + (target.dy - origin.dy) * tiltProgress,
    );
    if (mounted) {
      setState(() {
        _geometry = _geometryFromPointer(
          direction: direction,
          pointer: pointer,
          origin: origin,
        );
      });
    }
    if (linearProgress >= 1) _stopCatchUp();
  }

  void _stopCatchUp() {
    if (_catchUpTicker.isActive) _catchUpTicker.stop();
    _catchUpStartPointer = null;
  }

  void _finishCatchUpAtLatestPointer() {
    if (_catchUpStartPointer == null) return;
    final pointer = _latestDragPointer;
    final direction = _direction;
    final origin = _dragOrigin;
    _stopCatchUp();
    if (pointer == null || direction == null || origin == null) return;
    _geometry = _geometryFromPointer(
      direction: direction,
      pointer: pointer,
      origin: origin,
    );
  }

  Future<void> _ensureActiveSnapshots(
    ReaderPageTurnDirection direction,
  ) async {
    final generation = _captureGeneration;
    final layers = _turnLayers(direction);
    if (layers == null) return;
    final source = _direction == direction && _activeSourcePage != null
        ? _activeSourcePage!
        : layers.source;
    final sourceKey = _direction == direction && _activeSourceKey != null
        ? _activeSourceKey!
        : layers.sourceKey;
    final target = _direction == direction && _activeTargetPage != null
        ? _activeTargetPage!
        : layers.target;
    final targetKey = _direction == direction && _activeTargetKey != null
        ? _activeTargetKey!
        : layers.targetKey;
    await _ensureSnapshot(
      source,
      sourceKey,
      generation,
    );
    if (!mounted || generation != _captureGeneration) return;
    await _ensureSnapshot(
      target,
      targetKey,
      generation,
    );
  }

  Future<ui.Image?> _ensureActiveSourceSnapshot(
    ReaderPageTurnDirection direction,
  ) {
    final layers = _turnLayers(direction);
    if (layers == null) return Future<ui.Image?>.value();
    final source = _direction == direction && _activeSourcePage != null
        ? _activeSourcePage!
        : layers.source;
    final sourceKey = _direction == direction && _activeSourceKey != null
        ? _activeSourceKey!
        : layers.sourceKey;
    return _ensureSnapshot(
      source,
      sourceKey,
      _captureGeneration,
    );
  }

  void _onPanEnd(DragEndDetails details) {
    _pointerDown = null;
    if (_phase == _PageTurnPhase.pointerPending) {
      _resetToIdle();
      return;
    }
    if (_phase != _PageTurnPhase.dragging ||
        _geometry == null ||
        _direction == null) {
      return;
    }
    _finishCatchUpAtLatestPointer();
    final canonicalVelocity = ReaderPageTurnGeometry.velocityToBindingSpace(
      details.velocity.pixelsPerSecond,
      bindingOnRight: _bindingOnRight,
    );
    final motion = _geometry!.motion;
    final velocityTowardCommit = motion == ReaderPageTurnMotion.outgoing
        ? -canonicalVelocity.dx
        : canonicalVelocity.dx;
    final projected = _geometry!.progress +
        (velocityTowardCommit / math.max(_viewportSize.width, 1)) *
            _predictionHorizonSeconds;
    final springVelocity = motion == ReaderPageTurnMotion.incoming
        ? canonicalVelocity * 2
        : canonicalVelocity;
    _startSpring(
      commit: projected >= _commitProjection,
      canonicalVelocity: springVelocity,
    );
  }

  void _onPanCancel() {
    _pointerDown = null;
    if (_phase == _PageTurnPhase.pointerPending) {
      _resetToIdle();
    } else if (_phase == _PageTurnPhase.dragging && _geometry != null) {
      _stopCatchUp();
      _startSpring(commit: false, canonicalVelocity: Offset.zero);
    }
  }

  Future<void> _requestProgrammaticTurn(
    ReaderPageTurnDirection direction,
  ) {
    if (_programmaticTurns.length >= _maxQueuedProgrammaticTurns) {
      final latest = _programmaticTurns.last;
      if (latest.direction == direction) return latest.completer.future;
      final replaced = _programmaticTurns.removeLast();
      if (!replaced.completer.isCompleted) replaced.completer.complete();
    }
    final request = _QueuedProgrammaticTurn(direction);
    _programmaticTurns.add(request);
    _drainProgrammaticTurns();
    return request.completer.future;
  }

  void _drainProgrammaticTurns() {
    if (!mounted ||
        _phase != _PageTurnPhase.idle ||
        _programmaticTurns.isEmpty) {
      return;
    }
    final request = _programmaticTurns.removeFirst();
    unawaited(
      request.direction == ReaderPageTurnDirection.forward
          ? _runForwardAnimation(request)
          : _runBackwardAnimation(request),
    );
  }

  Future<void> _runForwardAnimation(_QueuedProgrammaticTurn request) =>
      _runDirectionalProgrammaticTurn(
        request,
        ReaderPageTurnDirection.forward,
      );

  Future<void> _runBackwardAnimation(_QueuedProgrammaticTurn request) =>
      _runDirectionalProgrammaticTurn(
        request,
        ReaderPageTurnDirection.backward,
      );

  Future<void> _runDirectionalProgrammaticTurn(
    _QueuedProgrammaticTurn request,
    ReaderPageTurnDirection direction,
  ) async {
    if (_viewportSize.isEmpty || !_hasPage(direction)) {
      if (!request.completer.isCompleted) request.completer.complete();
      _scheduleProgrammaticDrain();
      return;
    }
    final startsOnLeft = direction == ReaderPageTurnDirection.backward;
    final origin = Offset(
      startsOnLeft ? 0 : _viewportSize.width,
      _viewportSize.height * 0.72,
    );
    final pointer = Offset(
      startsOnLeft ? 1 : _viewportSize.width - 1,
      origin.dy,
    );
    if (!_beginDrag(direction, pointer: pointer, origin: origin)) {
      _programmaticTurns.addFirst(request);
      return;
    }
    await _ensureActiveSourceSnapshot(direction);
    if (!mounted || _phase != _PageTurnPhase.dragging) {
      if (!request.completer.isCompleted) request.completer.complete();
      _scheduleProgrammaticDrain();
      return;
    }
    final completer = Completer<void>();
    _turnCompleter = completer;
    _startSpring(
      commit: true,
      canonicalVelocity: Offset(
        _motionFor(direction) == ReaderPageTurnMotion.outgoing
            ? -_viewportSize.width * 3.2
            : _viewportSize.width * 3.2,
        0,
      ),
    );
    await completer.future;
    if (!request.completer.isCompleted) request.completer.complete();
  }

  void _scheduleProgrammaticDrain() {
    if (_programmaticTurns.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _drainProgrammaticTurns();
    });
  }

  bool _hasPage(ReaderPageTurnDirection direction) =>
      direction == ReaderPageTurnDirection.forward
          ? widget.forwardPage != null
          : widget.backwardPage != null;

  _ReaderTurnLayers? _turnLayers(ReaderPageTurnDirection direction) {
    final adjacent = direction == ReaderPageTurnDirection.forward
        ? widget.forwardPage
        : widget.backwardPage;
    if (adjacent == null) return null;
    final adjacentKey = direction == ReaderPageTurnDirection.forward
        ? _forwardKey
        : _backwardKey;
    return _motionFor(direction) == ReaderPageTurnMotion.outgoing
        ? _ReaderTurnLayers(
            source: widget.currentPage,
            sourceKey: _currentKey,
            target: adjacent,
            targetKey: adjacentKey,
          )
        : _ReaderTurnLayers(
            source: adjacent,
            sourceKey: adjacentKey,
            target: widget.currentPage,
            targetKey: _currentKey,
          );
  }

  void _captureActiveSourceSync(
    ReaderPageSnapshot page,
    GlobalKey boundaryKey, {
    required bool refreshAfterPreparation,
  }) {
    if (!mounted || _viewportSize.isEmpty) return;
    final ratio = readerPageSnapshotPixelRatio(
      logicalSize: _viewportSize,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      perEntryByteBudget: _perSnapshotBudgetBytes,
    );
    final cached = _snapshotCache.lookup(
      page.key,
      contentRevision: page.contentRevision,
      logicalSize: _viewportSize,
      pixelRatio: ratio,
    );
    if (cached != null) return;
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) return;
    var needsPaint = false;
    assert(() {
      needsPaint = boundary.debugNeedsPaint;
      return true;
    }());
    if (needsPaint) return;
    try {
      final image = boundary.toImageSync(pixelRatio: ratio);
      _snapshotCache.store(
        page.key,
        image: image,
        contentRevision: page.contentRevision,
        logicalSize: _viewportSize,
        pixelRatio: ratio,
        protectedKeys: _protectedSnapshotKeys,
      );
      if (refreshAfterPreparation) _syncSnapshotKeys.add(page.key);
    } catch (error, stackTrace) {
      debugPrint('Reader page turn sync capture failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool get _bindingOnRight => widget.bindingEdge == ReaderPageBindingEdge.right;

  ReaderPageTurnMotion _motionFor(ReaderPageTurnDirection direction) {
    final turnsCurrentPageOut = direction == ReaderPageTurnDirection.forward
        ? !_bindingOnRight
        : _bindingOnRight;
    return turnsCurrentPageOut
        ? ReaderPageTurnMotion.outgoing
        : ReaderPageTurnMotion.incoming;
  }

  ReaderPageTurnGeometry _geometryFromPointer({
    required ReaderPageTurnDirection direction,
    required Offset pointer,
    required Offset origin,
  }) =>
      ReaderPageTurnGeometry.fromPointer(
        size: _viewportSize,
        direction: direction,
        motion: _motionFor(direction),
        pointer: pointer,
        dragOrigin: origin,
        anchorMode: ReaderPageTurnAnchorMode.followEdge,
        bindingOnRight: _bindingOnRight,
      );

  _ReaderSpringChannel _springFor(ReaderPageTurnDirection direction) =>
      direction == ReaderPageTurnDirection.forward
          ? _forwardSpring
          : _backwardSpring;

  Ticker _springTickerFor(ReaderPageTurnDirection direction) =>
      direction == ReaderPageTurnDirection.forward
          ? _forwardSpringTicker
          : _backwardSpringTicker;

  ReaderPageTurnDirection _opposite(ReaderPageTurnDirection direction) =>
      direction == ReaderPageTurnDirection.forward
          ? ReaderPageTurnDirection.backward
          : ReaderPageTurnDirection.forward;

  void _stopSpringTicker(ReaderPageTurnDirection direction) {
    final ticker = _springTickerFor(direction);
    if (ticker.isActive) ticker.stop();
  }

  void _startSpring({
    required bool commit,
    required Offset canonicalVelocity,
  }) {
    final geometry = _geometry;
    final direction = _direction;
    if (geometry == null || direction == null) return;
    _stopCatchUp();
    final anchor = geometry.canonicalAnchor;
    final target = switch ((geometry.motion, commit)) {
      (ReaderPageTurnMotion.outgoing, true) =>
        Offset(-_viewportSize.width, anchor.dy),
      (ReaderPageTurnMotion.outgoing, false) => anchor,
      (ReaderPageTurnMotion.incoming, true) => anchor,
      (ReaderPageTurnMotion.incoming, false) =>
        Offset(-_viewportSize.width, anchor.dy),
    };
    final spring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: commit ? 420 : 400,
      ratio: commit ? 0.96 : 0.90,
    );
    const tolerance = Tolerance(distance: 0.75, velocity: 9);
    final channel = _springFor(direction);
    channel.simulationX = SpringSimulation(
      spring,
      geometry.canonicalTouch.dx,
      target.dx,
      canonicalVelocity.dx,
      tolerance: tolerance,
    );
    channel.simulationY = SpringSimulation(
      spring,
      geometry.canonicalTouch.dy,
      target.dy,
      canonicalVelocity.dy,
      tolerance: tolerance,
    );
    channel
      ..commits = commit
      ..target = target
      ..startedAt = Duration.zero;
    setState(() {
      _phase =
          commit ? _PageTurnPhase.settlingCommit : _PageTurnPhase.settlingBack;
    });
    _stopSpringTicker(_opposite(direction));
    final ticker = _springTickerFor(direction);
    if (ticker.isActive) ticker.stop();
    ticker.start();
  }

  void _onSpringTick(
    ReaderPageTurnDirection channelDirection,
    Duration elapsed,
  ) {
    final channel = _springFor(channelDirection);
    final simulationX = channel.simulationX;
    final simulationY = channel.simulationY;
    final direction = _direction;
    final geometry = _geometry;
    if (simulationX == null ||
        simulationY == null ||
        direction != channelDirection ||
        geometry == null) {
      _stopSpringTicker(channelDirection);
      return;
    }
    if (channel.startedAt == Duration.zero) channel.startedAt = elapsed;
    final seconds = (elapsed - channel.startedAt).inMicroseconds / 1000000;
    final touch = Offset(simulationX.x(seconds), simulationY.x(seconds));
    final target = channel.target;
    final terminalSnapDistance = math.max(
      2.0,
      math.min(8.0, _viewportSize.width * 0.012),
    );
    final snapsToExactTerminal = channel.commits &&
        target != null &&
        (touch - target).distance <= terminalSnapDistance;
    final renderedTouch = snapsToExactTerminal ? target : touch;
    if (mounted) {
      setState(() {
        _geometry = ReaderPageTurnGeometry.fromCanonicalTouch(
          size: _viewportSize,
          direction: channelDirection,
          motion: geometry.motion,
          corner: geometry.corner,
          canonicalAnchorY: geometry.canonicalAnchor.dy,
          canonicalTouch: renderedTouch,
          bindingOnRight: _bindingOnRight,
        );
      });
    }
    final visuallySettled = snapsToExactTerminal ||
        (simulationX.isDone(seconds) && simulationY.isDone(seconds));
    if (visuallySettled) {
      _stopSpringTicker(channelDirection);
      if (target != null && mounted) {
        setState(() {
          _geometry = ReaderPageTurnGeometry.fromCanonicalTouch(
            size: _viewportSize,
            direction: channelDirection,
            motion: geometry.motion,
            corner: geometry.corner,
            canonicalAnchorY: geometry.canonicalAnchor.dy,
            canonicalTouch: target,
            bindingOnRight: _bindingOnRight,
          );
        });
      }
      if (channel.commits) {
        setState(() => _phase = _PageTurnPhase.awaitingPageUpdate);
        unawaited(_commitTurn());
      } else {
        _completeTurn();
      }
    }
  }

  Future<void> _commitTurn() async {
    try {
      final callback = _direction == ReaderPageTurnDirection.backward
          ? widget.onTurnBackward
          : widget.onTurnForward;
      await Future<void>.sync(callback);
    } catch (error, stackTrace) {
      debugPrint('Reader page turn callback failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) _completeTurn();
    }
  }

  void _completeTurn() {
    final completer = _turnCompleter;
    _turnCompleter = null;
    final syncSnapshotKeys = _syncSnapshotKeys.toSet();
    _syncSnapshotKeys.clear();
    final retiredSnapshotImages = _retiredSnapshotImages.toList();
    _retiredSnapshotImages.clear();
    _resetToIdle();
    if (_warmAfterTurn) {
      _warmAfterTurn = false;
    }
    if (syncSnapshotKeys.isEmpty && retiredSnapshotImages.isEmpty) {
      _scheduleWarmSnapshots();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final image in retiredSnapshotImages) {
          image.dispose();
        }
        if (!mounted) return;
        for (final key in syncSnapshotKeys) {
          _snapshotCache.remove(key);
        }
        _scheduleWarmSnapshots();
      });
    }
    if (completer != null && !completer.isCompleted) completer.complete();
    _scheduleProgrammaticDrain();
  }

  void _resetToIdle() {
    _stopCatchUp();
    _stopSpringTicker(ReaderPageTurnDirection.forward);
    _stopSpringTicker(ReaderPageTurnDirection.backward);
    if (!mounted) return;
    final coordinator = _ownedCoordinator;
    _ownedCoordinator = null;
    setState(() {
      _phase = _PageTurnPhase.idle;
      _direction = null;
      _geometry = null;
      _activeSourcePage = null;
      _activeTargetPage = null;
      _activeSourceKey = null;
      _activeTargetKey = null;
      _dragOrigin = null;
      _pointerDown = null;
      _latestDragPointer = null;
      _forwardSpring.clear();
      _backwardSpring.clear();
    });
    coordinator?._release(this);
  }

  ui.Image? _cachedImage(ReaderPageSnapshot? page) {
    if (page == null || _viewportSize.isEmpty) return null;
    final ratio = readerPageSnapshotPixelRatio(
      logicalSize: _viewportSize,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      perEntryByteBudget: _perSnapshotBudgetBytes,
    );
    return _snapshotCache.lookup(
      page.key,
      contentRevision: page.contentRevision,
      logicalSize: _viewportSize,
      pixelRatio: ratio,
    );
  }

  bool get _animationReady =>
      _geometry != null &&
      _cachedImage(_activeSourcePage) != null &&
      _activeTargetPage != null &&
      _phase != _PageTurnPhase.idle &&
      _phase != _PageTurnPhase.pointerPending;

  Widget _paper(
    GlobalKey key,
    ReaderPageSnapshot page, {
    required bool hidden,
  }) {
    final paper = RepaintBoundary(
      key: key,
      child: ColoredBox(color: widget.paperColor, child: page.child),
    );
    if (!hidden) return paper;
    return ExcludeSemantics(child: IgnorePointer(child: paper));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final nextSize = constraints.biggest;
        if (nextSize != _viewportSize && !nextSize.isEmpty) {
          _viewportSize = nextSize;
          _captureGeneration++;
          _preparedGeneration = -1;
          _scheduleWarmSnapshots();
        }
        final geometry = _geometry;
        final sourceImage = _cachedImage(_activeSourcePage);
        final animationReady = _animationReady;
        final boundaryPages = <GlobalKey, ReaderPageSnapshot>{
          _currentKey: widget.currentPage,
          if (widget.backwardPage case final page?) _backwardKey: page,
          if (widget.forwardPage case final page?) _forwardKey: page,
        };
        if (_activeSourcePage != null && _activeSourceKey != null) {
          boundaryPages[_activeSourceKey!] = _activeSourcePage!;
        }
        if (_activeTargetPage != null && _activeTargetKey != null) {
          boundaryPages[_activeTargetKey!] = _activeTargetPage!;
        }
        final visibleKey = animationReady && _activeTargetKey != null
            ? _activeTargetKey!
            : _currentKey;
        final visiblePage = boundaryPages[visibleKey]!;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onPanCancel: _onPanCancel,
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final entry in boundaryPages.entries)
                  if (!identical(entry.key, visibleKey))
                    _paper(entry.key, entry.value, hidden: true),
                _paper(visibleKey, visiblePage, hidden: false),
                if (animationReady)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _pageTurnPainter(
                        geometry: geometry!,
                        sourceImage: sourceImage!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  CustomPainter _pageTurnPainter({
    required ReaderPageTurnGeometry geometry,
    required ui.Image sourceImage,
  }) {
    if (_classicFoldShader != null) {
      return _ReaderClassicFoldPainter(
        shader: _classicFoldShader!,
        sourcePage: sourceImage,
        geometry: geometry,
        bindingEdge: widget.bindingEdge,
      );
    }
    return _ReaderFallbackTurnPainter(
      sourcePage: sourceImage,
      geometry: geometry,
    );
  }
}

double readerPageSnapshotPixelRatio({
  required Size logicalSize,
  required double devicePixelRatio,
  int perEntryByteBudget = 8 * 1024 * 1024,
}) {
  final area = logicalSize.width * logicalSize.height;
  if (area <= 0 || !area.isFinite || perEntryByteBudget <= 0) return 1;
  final budgetRatio = math.sqrt(perEntryByteBudget / (area * 4));
  final safeDeviceRatio = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 1.0;
  return math.min(safeDeviceRatio, math.min(2.5, budgetRatio));
}

bool _sameSnapshot(ReaderPageSnapshot left, ReaderPageSnapshot right) =>
    left.key == right.key && left.contentRevision == right.contentRevision;

bool _sameOptionalSnapshot(
  ReaderPageSnapshot? left,
  ReaderPageSnapshot? right,
) {
  if (left == null || right == null) return left == right;
  return _sameSnapshot(left, right);
}

class _ReaderSnapshotCache {
  _ReaderSnapshotCache({required this.maxBytes, required this.maxEntries});

  final int maxBytes;
  final int maxEntries;
  final LinkedHashMap<ReaderPageSnapshotKey, _ReaderSnapshotEntry> _entries =
      LinkedHashMap();
  int _bytes = 0;

  ui.Image? lookup(
    ReaderPageSnapshotKey key, {
    required int contentRevision,
    required Size logicalSize,
    required double pixelRatio,
  }) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (entry.contentRevision != contentRevision ||
        entry.logicalSize != logicalSize ||
        entry.pixelRatio != pixelRatio) {
      _bytes -= entry.byteSize;
      entry.image.dispose();
      return null;
    }
    _entries[key] = entry;
    return entry.image;
  }

  ui.Image? store(
    ReaderPageSnapshotKey key, {
    required ui.Image image,
    required int contentRevision,
    required Size logicalSize,
    required double pixelRatio,
    required Set<ReaderPageSnapshotKey> protectedKeys,
    bool retainPrevious = false,
  }) {
    final previous = _entries.remove(key);
    ui.Image? retainedImage;
    if (previous != null) {
      _bytes -= previous.byteSize;
      if (retainPrevious) {
        retainedImage = previous.image;
      } else {
        previous.image.dispose();
      }
    }
    final entry = _ReaderSnapshotEntry(
      image: image,
      contentRevision: contentRevision,
      logicalSize: logicalSize,
      pixelRatio: pixelRatio,
    );
    _entries[key] = entry;
    _bytes += entry.byteSize;
    _trim(protectedKeys);
    return retainedImage;
  }

  void _trim(Set<ReaderPageSnapshotKey> protectedKeys) {
    while (_entries.length > maxEntries || _bytes > maxBytes) {
      ReaderPageSnapshotKey? candidate;
      for (final key in _entries.keys) {
        if (!protectedKeys.contains(key)) {
          candidate = key;
          break;
        }
      }
      if (candidate == null) return;
      final entry = _entries.remove(candidate)!;
      _bytes -= entry.byteSize;
      entry.image.dispose();
    }
  }

  void clearExcept(Set<ReaderPageSnapshotKey> protectedKeys) {
    final keys = _entries.keys
        .where((key) => !protectedKeys.contains(key))
        .toList(growable: false);
    for (final key in keys) {
      final entry = _entries.remove(key)!;
      _bytes -= entry.byteSize;
      entry.image.dispose();
    }
  }

  void remove(ReaderPageSnapshotKey key) {
    final entry = _entries.remove(key);
    if (entry == null) return;
    _bytes -= entry.byteSize;
    entry.image.dispose();
  }

  void dispose() {
    for (final entry in _entries.values) {
      entry.image.dispose();
    }
    _entries.clear();
    _bytes = 0;
  }
}

class _ReaderSnapshotEntry {
  const _ReaderSnapshotEntry({
    required this.image,
    required this.contentRevision,
    required this.logicalSize,
    required this.pixelRatio,
  });

  final ui.Image image;
  final int contentRevision;
  final Size logicalSize;
  final double pixelRatio;

  int get byteSize => image.width * image.height * 4;
}

class _ReaderSpringChannel {
  SpringSimulation? simulationX;
  SpringSimulation? simulationY;
  Duration startedAt = Duration.zero;
  bool commits = false;
  Offset? target;

  void clear() {
    simulationX = null;
    simulationY = null;
    startedAt = Duration.zero;
    commits = false;
    target = null;
  }
}

class _QueuedProgrammaticTurn {
  _QueuedProgrammaticTurn(this.direction);

  final ReaderPageTurnDirection direction;
  final Completer<void> completer = Completer<void>();
}

@immutable
class _SnapshotRequestKey {
  const _SnapshotRequestKey({
    required this.pageKey,
    required this.contentRevision,
    required this.logicalSize,
    required this.pixelRatio,
    required this.generation,
  });

  final ReaderPageSnapshotKey pageKey;
  final int contentRevision;
  final Size logicalSize;
  final double pixelRatio;
  final int generation;

  @override
  bool operator ==(Object other) =>
      other is _SnapshotRequestKey &&
      other.pageKey == pageKey &&
      other.contentRevision == contentRevision &&
      other.logicalSize == logicalSize &&
      other.pixelRatio == pixelRatio &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(
        pageKey,
        contentRevision,
        logicalSize,
        pixelRatio,
        generation,
      );
}

class _ReaderTurnLayers {
  const _ReaderTurnLayers({
    required this.source,
    required this.sourceKey,
    required this.target,
    required this.targetKey,
  });

  final ReaderPageSnapshot source;
  final GlobalKey sourceKey;
  final ReaderPageSnapshot target;
  final GlobalKey targetKey;
}

class _ReaderClassicFoldPainter extends CustomPainter {
  const _ReaderClassicFoldPainter({
    required this.shader,
    required this.sourcePage,
    required this.geometry,
    required this.bindingEdge,
  });

  final ui.FragmentShader shader;
  final ui.Image sourcePage;
  final ReaderPageTurnGeometry geometry;
  final ReaderPageBindingEdge bindingEdge;

  @override
  void paint(Canvas canvas, Size size) {
    var index = 0;
    shader
      ..setFloat(index++, size.width)
      ..setFloat(index++, size.height)
      ..setFloat(index++, geometry.canonicalLineA.dx)
      ..setFloat(index++, geometry.canonicalLineA.dy)
      ..setFloat(index++, geometry.canonicalLineB.dx)
      ..setFloat(index++, geometry.canonicalLineB.dy)
      ..setFloat(
        index++,
        bindingEdge == ReaderPageBindingEdge.right ? 1 : 0,
      )
      ..setImageSampler(0, sourcePage);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _ReaderClassicFoldPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.bindingEdge != bindingEdge ||
      !identical(oldDelegate.sourcePage, sourcePage);
}

class _ReaderFallbackTurnPainter extends CustomPainter {
  const _ReaderFallbackTurnPainter({
    required this.sourcePage,
    required this.geometry,
  });

  final ui.Image sourcePage;
  final ReaderPageTurnGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final canonicalOffset = switch (geometry.motion) {
      ReaderPageTurnMotion.outgoing => -size.width * geometry.progress,
      ReaderPageTurnMotion.incoming => -size.width * (1 - geometry.progress),
    };
    final offset = geometry.bindingOnRight ? -canonicalOffset : canonicalOffset;
    canvas.translate(offset, 0);
    _drawPageImage(canvas, sourcePage, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReaderFallbackTurnPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      !identical(oldDelegate.sourcePage, sourcePage);
}

void _drawPageImage(Canvas canvas, ui.Image image, Size size) {
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.medium,
  );
}

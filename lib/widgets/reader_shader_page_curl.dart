import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../core/reader/reader_layout.dart';
import '../core/reader/reader_page_turn_geometry.dart';
import 'reader_paper_page_leaf.dart';

typedef ReaderPageTurnCallback = FutureOr<void> Function();

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

  Future<void> turnForward() async => _state?._turnProgrammatically(
        ReaderPageTurnDirection.forward,
      );

  Future<void> turnBackward() async => _state?._turnProgrammatically(
        ReaderPageTurnDirection.backward,
      );

  void _attach(_ReaderShaderPageCurlState state) => _state = state;

  void _detach(_ReaderShaderPageCurlState state) {
    if (identical(_state, state)) _state = null;
  }
}

/// A reader page-turn surface shared by the cylinder and classic fold styles.
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
    this.turnStyle = ReaderPageTurnStyle.cylinder,
  });

  final ReaderPageSnapshot currentPage;
  final ReaderPageSnapshot? forwardPage;
  final ReaderPageSnapshot? backwardPage;
  final ReaderPageTurnCallback onTurnForward;
  final ReaderPageTurnCallback onTurnBackward;
  final Color paperColor;
  final ReaderPageCurlController? controller;
  final Future<void> Function()? preparePages;
  final ReaderPageTurnStyle turnStyle;

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _snapshotBudgetBytes = 48 * 1024 * 1024;
  static const int _perSnapshotBudgetBytes = 8 * 1024 * 1024;
  static const double _edgeStartFraction = 0.30;
  static const double _intentSlop = 7;
  static const double _horizontalIntentRatio = 1.24;
  static const double _predictionHorizonSeconds = 0.12;
  static const double _commitProjection = 0.32;

  final GlobalKey _currentKey = GlobalKey(debugLabel: 'curl-current');
  final GlobalKey _forwardKey = GlobalKey(debugLabel: 'curl-forward');
  final GlobalKey _backwardKey = GlobalKey(debugLabel: 'curl-backward');
  final _ReaderSnapshotCache _snapshotCache = _ReaderSnapshotCache(
    maxBytes: _snapshotBudgetBytes,
    maxEntries: 7,
  );
  final Map<_SnapshotRequestKey, Future<ui.Image?>> _inFlightCaptures = {};

  late final Ticker _springTicker;
  ui.FragmentShader? _cylinderShader;
  ui.FragmentShader? _classicFoldShader;
  SpringSimulation? _springX;
  SpringSimulation? _springY;
  Duration _springStartedAt = Duration.zero;
  Completer<void>? _turnCompleter;

  Size _viewportSize = Size.zero;
  Offset? _pointerDown;
  Offset? _dragOrigin;
  ReaderPageTurnDirection? _direction;
  ReaderPageTurnGeometry? _geometry;
  ReaderPageSnapshot? _activeSourcePage;
  ReaderPageSnapshot? _activeTargetPage;
  _PageTurnPhase _phase = _PageTurnPhase.idle;
  bool _springCommits = false;
  bool _warmScheduled = false;
  bool _warmAfterTurn = false;
  Timer? _backwardWarmTimer;
  int _captureGeneration = 0;
  int _preparedGeneration = -1;
  int _preparingGeneration = -1;
  Future<void>? _preparingPages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _springTicker = createTicker(_onSpringTick);
    widget.controller?._attach(this);
    unawaited(_loadCylinderShader());
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
    _backwardWarmTimer?.cancel();
    final completer = _turnCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    _springTicker.dispose();
    _snapshotCache.dispose();
    _cylinderShader?.dispose();
    _classicFoldShader?.dispose();
    super.dispose();
  }

  Future<void> _loadCylinderShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/reader_page_curl.frag',
      );
      if (!mounted) return;
      setState(() => _cylinderShader = program.fragmentShader());
    } catch (error, stackTrace) {
      debugPrint('Reader cylinder page curl shader failed to load: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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
    await WidgetsBinding.instance.endOfFrame;
    final forward = widget.forwardPage;
    if (forward != null) {
      await _ensureSnapshot(forward, _forwardKey, generation);
    }
    if (!mounted || generation != _captureGeneration) return;
    _backwardWarmTimer?.cancel();
    final backward = widget.backwardPage;
    if (backward != null) {
      _backwardWarmTimer = Timer(const Duration(milliseconds: 140), () {
        if (!mounted || generation != _captureGeneration) return;
        unawaited(_ensureSnapshot(backward, _backwardKey, generation));
      });
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
    if (cached != null) return cached;

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
    _snapshotCache.store(
      page.key,
      image: image,
      contentRevision: page.contentRevision,
      logicalSize: _viewportSize,
      pixelRatio: pixelRatio,
      protectedKeys: _protectedSnapshotKeys,
    );
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
      _beginDrag(
        ReaderPageTurnDirection.forward,
        pointer: details.localPosition,
        origin: origin,
      );
    } else if (fraction <= _edgeStartFraction && widget.backwardPage != null) {
      _beginDrag(
        ReaderPageTurnDirection.backward,
        pointer: details.localPosition,
        origin: origin,
      );
    } else {
      setState(() => _phase = _PageTurnPhase.pointerPending);
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
      _beginDrag(
        direction,
        pointer: details.localPosition,
        origin: origin,
      );
      return;
    }
    if (_phase != _PageTurnPhase.dragging || _direction == null) return;
    setState(() {
      _geometry = ReaderPageTurnGeometry.fromPointer(
        size: _viewportSize,
        direction: _direction!,
        pointer: details.localPosition,
        dragOrigin: _dragOrigin!,
      );
    });
  }

  void _beginDrag(
    ReaderPageTurnDirection direction, {
    required Offset pointer,
    required Offset origin,
  }) {
    final source = direction == ReaderPageTurnDirection.forward
        ? widget.currentPage
        : widget.backwardPage;
    final target = direction == ReaderPageTurnDirection.forward
        ? widget.forwardPage
        : widget.currentPage;
    if (source == null || target == null) return;
    _direction = direction;
    _dragOrigin = origin;
    _activeSourcePage = source;
    _activeTargetPage = target;
    setState(() {
      _geometry = ReaderPageTurnGeometry.fromPointer(
        size: _viewportSize,
        direction: direction,
        pointer: pointer,
        dragOrigin: origin,
      );
      _phase = _PageTurnPhase.dragging;
    });
    unawaited(_ensureActiveSnapshots(direction));
  }

  Future<void> _ensureActiveSnapshots(
    ReaderPageTurnDirection direction,
  ) async {
    final generation = _captureGeneration;
    if (direction == ReaderPageTurnDirection.forward) {
      await _ensureSnapshot(widget.currentPage, _currentKey, generation);
      final target = widget.forwardPage;
      if (target != null) {
        await _ensureSnapshot(target, _forwardKey, generation);
      }
    } else {
      final source = widget.backwardPage;
      if (source != null) {
        await _ensureSnapshot(source, _backwardKey, generation);
      }
      await _ensureSnapshot(widget.currentPage, _currentKey, generation);
    }
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
    final canonicalVelocity = ReaderPageTurnGeometry.canonicalVelocity(
      details.velocity.pixelsPerSecond,
      _direction!,
    );
    final projected = _geometry!.progress +
        (-canonicalVelocity.dx / math.max(_viewportSize.width, 1)) *
            _predictionHorizonSeconds;
    _startSpring(
      commit: projected >= _commitProjection,
      canonicalVelocity: canonicalVelocity,
    );
  }

  void _onPanCancel() {
    _pointerDown = null;
    if (_phase == _PageTurnPhase.pointerPending) {
      _resetToIdle();
    } else if (_phase == _PageTurnPhase.dragging && _geometry != null) {
      _startSpring(commit: false, canonicalVelocity: Offset.zero);
    }
  }

  Future<void> _turnProgrammatically(
    ReaderPageTurnDirection direction,
  ) async {
    if (_phase != _PageTurnPhase.idle ||
        _viewportSize.isEmpty ||
        !_hasPage(direction)) {
      return;
    }
    final reverse = direction == ReaderPageTurnDirection.backward;
    final origin = Offset(
      reverse ? 0 : _viewportSize.width,
      _viewportSize.height * 0.72,
    );
    final pointer = Offset(
      reverse ? 1 : _viewportSize.width - 1,
      origin.dy,
    );
    _beginDrag(direction, pointer: pointer, origin: origin);
    await _ensureActiveSnapshots(direction);
    if (!mounted || _phase != _PageTurnPhase.dragging) return;
    final completer = Completer<void>();
    _turnCompleter = completer;
    _startSpring(
      commit: true,
      canonicalVelocity: Offset(-_viewportSize.width * 3.2, 0),
    );
    await completer.future;
  }

  bool _hasPage(ReaderPageTurnDirection direction) =>
      direction == ReaderPageTurnDirection.forward
          ? widget.forwardPage != null
          : widget.backwardPage != null;

  void _startSpring({
    required bool commit,
    required Offset canonicalVelocity,
  }) {
    final geometry = _geometry;
    final direction = _direction;
    if (geometry == null || direction == null) return;
    final anchor = Offset(
      _viewportSize.width,
      geometry.corner == ReaderPageTurnCorner.top ? 0 : _viewportSize.height,
    );
    final target = commit
        ? widget.turnStyle == ReaderPageTurnStyle.classicFold
            ? Offset(-_viewportSize.width, anchor.dy)
            : Offset(
                -_viewportSize.width * 0.18,
                geometry.corner == ReaderPageTurnCorner.top
                    ? _viewportSize.height * 0.18
                    : _viewportSize.height * 0.82,
              )
        : anchor;
    final spring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: commit ? 310 : 360,
      ratio: commit ? 0.90 : 0.86,
    );
    const tolerance = Tolerance(distance: 0.35, velocity: 5);
    _springX = SpringSimulation(
      spring,
      geometry.canonicalTouch.dx,
      target.dx,
      canonicalVelocity.dx,
      tolerance: tolerance,
    );
    _springY = SpringSimulation(
      spring,
      geometry.canonicalTouch.dy,
      target.dy,
      canonicalVelocity.dy,
      tolerance: tolerance,
    );
    _springCommits = commit;
    _springStartedAt = Duration.zero;
    setState(() {
      _phase =
          commit ? _PageTurnPhase.settlingCommit : _PageTurnPhase.settlingBack;
    });
    _springTicker.start();
  }

  void _onSpringTick(Duration elapsed) {
    final simulationX = _springX;
    final simulationY = _springY;
    final direction = _direction;
    final geometry = _geometry;
    if (simulationX == null ||
        simulationY == null ||
        direction == null ||
        geometry == null) {
      _springTicker.stop();
      return;
    }
    if (_springStartedAt == Duration.zero) _springStartedAt = elapsed;
    final seconds = (elapsed - _springStartedAt).inMicroseconds / 1000000;
    final touch = Offset(simulationX.x(seconds), simulationY.x(seconds));
    if (mounted) {
      setState(() {
        _geometry = ReaderPageTurnGeometry.fromCanonicalTouch(
          size: _viewportSize,
          direction: direction,
          corner: geometry.corner,
          canonicalTouch: touch,
        );
      });
    }
    if (simulationX.isDone(seconds) && simulationY.isDone(seconds)) {
      _springTicker.stop();
      if (_springCommits) {
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
      if (mounted) await WidgetsBinding.instance.endOfFrame;
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
    _resetToIdle();
    if (_warmAfterTurn) {
      _warmAfterTurn = false;
    }
    _scheduleWarmSnapshots();
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _resetToIdle() {
    if (_springTicker.isActive) _springTicker.stop();
    if (!mounted) return;
    setState(() {
      _phase = _PageTurnPhase.idle;
      _direction = null;
      _geometry = null;
      _activeSourcePage = null;
      _activeTargetPage = null;
      _dragOrigin = null;
      _pointerDown = null;
      _springX = null;
      _springY = null;
    });
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
        final targetImage = _cachedImage(_activeTargetPage);
        final animationReady = geometry != null &&
            sourceImage != null &&
            targetImage != null &&
            _phase != _PageTurnPhase.idle &&
            _phase != _PageTurnPhase.pointerPending;
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
                if (widget.backwardPage case final page?)
                  _paper(_backwardKey, page, hidden: true),
                if (widget.forwardPage case final page?)
                  _paper(_forwardKey, page, hidden: true),
                _paper(_currentKey, widget.currentPage, hidden: false),
                if (animationReady)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _pageTurnPainter(
                        geometry: geometry,
                        sourceImage: sourceImage,
                        targetImage: targetImage,
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
    required ui.Image targetImage,
  }) {
    if (widget.turnStyle == ReaderPageTurnStyle.classicFold &&
        _classicFoldShader != null) {
      return _ReaderClassicFoldPainter(
        shader: _classicFoldShader!,
        currentPage: sourceImage,
        targetPage: targetImage,
        geometry: geometry,
        paperColor: widget.paperColor,
      );
    }
    if (widget.turnStyle == ReaderPageTurnStyle.cylinder &&
        _cylinderShader != null) {
      return _ReaderCylinderCurlPainter(
        shader: _cylinderShader!,
        currentPage: sourceImage,
        targetPage: targetImage,
        geometry: geometry,
        paperColor: widget.paperColor,
      );
    }
    return _ReaderFallbackTurnPainter(
      currentPage: sourceImage,
      targetPage: targetImage,
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

  void store(
    ReaderPageSnapshotKey key, {
    required ui.Image image,
    required int contentRevision,
    required Size logicalSize,
    required double pixelRatio,
    required Set<ReaderPageSnapshotKey> protectedKeys,
  }) {
    final previous = _entries.remove(key);
    if (previous != null) {
      _bytes -= previous.byteSize;
      previous.image.dispose();
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

class _ReaderCylinderCurlPainter extends CustomPainter {
  const _ReaderCylinderCurlPainter({
    required this.shader,
    required this.currentPage,
    required this.targetPage,
    required this.geometry,
    required this.paperColor,
  });

  final ui.FragmentShader shader;
  final ui.Image currentPage;
  final ui.Image targetPage;
  final ReaderPageTurnGeometry geometry;
  final Color paperColor;

  @override
  void paint(Canvas canvas, Size size) {
    final touch = geometry.screenPoint(geometry.canonicalTouch);
    final curlPosition = Offset(touch.dx / size.width, touch.dy / size.height);
    final direction = geometry.turnAxis;
    var index = 0;
    shader
      ..setFloat(index++, size.width)
      ..setFloat(index++, size.height)
      ..setFloat(index++, curlPosition.dx)
      ..setFloat(index++, curlPosition.dy)
      ..setFloat(index++, direction.dx)
      ..setFloat(index++, direction.dy)
      ..setFloat(index++, 0.07)
      ..setFloat(index++, 0.065)
      ..setFloat(index++, 0.30)
      ..setFloat(index++, paperColor.r)
      ..setFloat(index++, paperColor.g)
      ..setFloat(index++, paperColor.b)
      ..setFloat(index++, paperColor.a)
      ..setImageSampler(0, currentPage)
      ..setImageSampler(1, targetPage);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _ReaderCylinderCurlPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.paperColor != paperColor ||
      !identical(oldDelegate.currentPage, currentPage) ||
      !identical(oldDelegate.targetPage, targetPage);
}

class _ReaderClassicFoldPainter extends CustomPainter {
  const _ReaderClassicFoldPainter({
    required this.shader,
    required this.currentPage,
    required this.targetPage,
    required this.geometry,
    required this.paperColor,
  });

  final ui.FragmentShader shader;
  final ui.Image currentPage;
  final ui.Image targetPage;
  final ReaderPageTurnGeometry geometry;
  final Color paperColor;

  @override
  void paint(Canvas canvas, Size size) {
    _drawPageImage(canvas, targetPage, size);
    final foldPoint = geometry.foldPoint;
    final normal = geometry.turnAxis;
    var index = 0;
    shader
      ..setFloat(index++, size.width)
      ..setFloat(index++, size.height)
      ..setFloat(index++, foldPoint.dx)
      ..setFloat(index++, foldPoint.dy)
      ..setFloat(index++, normal.dx)
      ..setFloat(index++, normal.dy)
      ..setFloat(index++, math.min(28, size.shortestSide * 0.045))
      ..setFloat(index++, 0.34)
      ..setFloat(index++, paperColor.r)
      ..setFloat(index++, paperColor.g)
      ..setFloat(index++, paperColor.b)
      ..setFloat(index++, paperColor.a)
      ..setImageSampler(0, currentPage);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _ReaderClassicFoldPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.paperColor != paperColor ||
      !identical(oldDelegate.currentPage, currentPage) ||
      !identical(oldDelegate.targetPage, targetPage);
}

class _ReaderFallbackTurnPainter extends CustomPainter {
  const _ReaderFallbackTurnPainter({
    required this.currentPage,
    required this.targetPage,
    required this.geometry,
  });

  final ui.Image currentPage;
  final ui.Image targetPage;
  final ReaderPageTurnGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    _drawPageImage(canvas, targetPage, size);
    canvas.save();
    final offset = geometry.reverse
        ? -size.width * (1 - geometry.progress)
        : -size.width * geometry.progress;
    canvas.translate(offset, 0);
    _drawPageImage(canvas, currentPage, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReaderFallbackTurnPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      !identical(oldDelegate.currentPage, currentPage) ||
      !identical(oldDelegate.targetPage, targetPage);
}

void _drawPageImage(Canvas canvas, ui.Image image, Size size) {
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.medium,
  );
}

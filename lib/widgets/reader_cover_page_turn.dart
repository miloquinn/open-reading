import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import '../core/reader/reader_page_turn_geometry.dart';
import 'reader_shader_page_curl.dart'
    show ReaderPageSnapshot, ReaderPageTurnCallback;

enum _CoverTurnPhase { idle, dragging, settling, awaitingPageUpdate }

class _QueuedCoverTurn {
  _QueuedCoverTurn(this.direction);

  final ReaderPageTurnDirection direction;
  final Completer<void> completer = Completer<void>();
}

class ReaderCoverPageTurnController {
  _ReaderCoverPageTurnState? _state;

  Future<void> turnForward() =>
      _state?._enqueueProgrammaticTurn(ReaderPageTurnDirection.forward) ??
      Future<void>.value();

  Future<void> turnBackward() =>
      _state?._enqueueProgrammaticTurn(ReaderPageTurnDirection.backward) ??
      Future<void>.value();

  @visibleForTesting
  double? get debugTopSheetOffset => _state?._offset.value;

  @visibleForTesting
  bool get debugIsIdle => _state?._phase == _CoverTurnPhase.idle;

  @visibleForTesting
  ReaderPageTurnDirection? get debugDirection => _state?._direction;

  void _attach(_ReaderCoverPageTurnState state) => _state = state;

  void _detach(_ReaderCoverPageTurnState state) {
    if (identical(_state, state)) _state = null;
  }
}

/// A cover-style page turn surface.
///
/// Sheets stack in reading order: the earlier page always lies on top of its
/// successor. Turning forward drags the current sheet off to the left and the
/// next page is revealed beneath it; turning backward slides the previous
/// sheet back in from the left edge until it covers the current page again.
/// The moving sheet carries a soft shadow on its right edge and the sheet
/// beneath brightens as it is uncovered.
///
/// Pages are live widgets rather than GPU snapshots: both neighbours stay
/// mounted offstage so their layout cost is paid on page change, not on the
/// first gesture frame. Drags hand their release velocity to the same spring
/// family as the shader page curl, so both animated modes settle with one
/// shared feel.
class ReaderCoverPageTurn extends StatefulWidget {
  const ReaderCoverPageTurn({
    super.key,
    required this.currentPage,
    required this.onTurnForward,
    required this.onTurnBackward,
    required this.paperColor,
    this.forwardPage,
    this.backwardPage,
    this.controller,
  });

  final ReaderPageSnapshot currentPage;
  final ReaderPageSnapshot? forwardPage;
  final ReaderPageSnapshot? backwardPage;
  final ReaderPageTurnCallback onTurnForward;
  final ReaderPageTurnCallback onTurnBackward;
  final Color paperColor;
  final ReaderCoverPageTurnController? controller;

  @override
  State<ReaderCoverPageTurn> createState() => _ReaderCoverPageTurnState();
}

class _ReaderCoverPageTurnState extends State<ReaderCoverPageTurn>
    with SingleTickerProviderStateMixin {
  static const double _minFlingVelocity = 320;
  static const double _maxSettleVelocity = 4000;
  static const double _commitDragFraction = 0.3;
  static const double _shadowWidth = 28;
  static const double _maxRevealDim = 0.22;

  /// Left edge of the moving top sheet. The sheet it refers to depends on
  /// [_direction]: the current page while turning forward (0 → -width), the
  /// previous page while turning backward (-width → 0), or the current page
  /// again for the rubber-band stretch when the required neighbour is
  /// missing.
  final ValueNotifier<double> _offset = ValueNotifier(0);

  late final Ticker _ticker;
  final List<_QueuedCoverTurn> _queuedTurns = [];
  _QueuedCoverTurn? _activeTurn;
  _CoverTurnPhase _phase = _CoverTurnPhase.idle;
  ReaderPageTurnDirection? _direction;
  SpringSimulation? _settleSimulation;
  double _settleTarget = 0;
  bool _settleCommits = false;
  double _viewportWidth = 0;

  int? _activePointer;
  Offset? _downPosition;
  double? _gestureOriginDx;
  bool _dragStarted = false;
  bool _gestureAbandoned = false;
  VelocityTracker? _velocityTracker;
  Timer? _selectionHoldTimer;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onSettleTick);
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant ReaderCoverPageTurn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (_phase == _CoverTurnPhase.dragging &&
        _pagesChangedUnderGesture(oldWidget)) {
      _abortInteraction();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _selectionHoldTimer?.cancel();
    _ticker.dispose();
    final active = _activeTurn;
    if (active != null && !active.completer.isCompleted) {
      active.completer.complete();
    }
    for (final turn in _queuedTurns) {
      if (!turn.completer.isCompleted) turn.completer.complete();
    }
    _queuedTurns.clear();
    _offset.dispose();
    super.dispose();
  }

  bool _pagesChangedUnderGesture(ReaderCoverPageTurn oldWidget) {
    if (oldWidget.currentPage.key.pageIdentity !=
        widget.currentPage.key.pageIdentity) {
      return true;
    }
    final oldNeighbour = _direction == ReaderPageTurnDirection.backward
        ? oldWidget.backwardPage
        : oldWidget.forwardPage;
    final neighbour = _direction == ReaderPageTurnDirection.backward
        ? widget.backwardPage
        : widget.forwardPage;
    return oldNeighbour?.key.pageIdentity != neighbour?.key.pageIdentity;
  }

  /// Sheet that moves with [_offset]: the previous page while a backward turn
  /// is pulling it in over the current page, the current page otherwise.
  bool get _backwardSheetActive =>
      _phase != _CoverTurnPhase.idle &&
      _direction == ReaderPageTurnDirection.backward &&
      widget.backwardPage != null;

  bool get _forwardSheetRevealed =>
      _phase != _CoverTurnPhase.idle &&
      _direction == ReaderPageTurnDirection.forward &&
      widget.forwardPage != null;

  double get _rubberLimit => math.max(24, _viewportWidth * 0.07);

  double _rubberStretch(double distance) {
    final limit = _rubberLimit;
    return limit * (1 - math.exp(-math.max(0, distance) / (limit * 2.2)));
  }

  double _rubberStretchInverse(double stretch) {
    final limit = _rubberLimit;
    final ratio = (stretch / limit).clamp(0.0, 0.999);
    return -math.log(1 - ratio) * limit * 2.2;
  }

  /// Total horizontal gesture delta that would produce the current [_offset],
  /// so a finger catching a settling sheet continues it without a jump.
  double _gestureDeltaForOffset() {
    final offset = _offset.value;
    if (_direction == ReaderPageTurnDirection.backward) {
      if (widget.backwardPage != null) return offset + _viewportWidth;
      return _rubberStretchInverse(offset);
    }
    if (widget.forwardPage != null) return offset;
    return -_rubberStretchInverse(-offset);
  }

  Future<void> _enqueueProgrammaticTurn(ReaderPageTurnDirection direction) {
    if (_phase == _CoverTurnPhase.dragging) return Future<void>.value();
    final turn = _QueuedCoverTurn(direction);
    _queuedTurns.add(turn);
    _pumpQueue();
    return turn.completer.future;
  }

  void _pumpQueue() {
    while (_phase == _CoverTurnPhase.idle && _queuedTurns.isNotEmpty) {
      final turn = _queuedTurns.removeAt(0);
      final neighbour = turn.direction == ReaderPageTurnDirection.forward
          ? widget.forwardPage
          : widget.backwardPage;
      if (neighbour == null || _viewportWidth <= 0) {
        turn.completer.complete();
        continue;
      }
      _activeTurn = turn;
      _direction = turn.direction;
      _offset.value = turn.direction == ReaderPageTurnDirection.forward
          ? 0
          : -_viewportWidth;
      _startSettle(commit: true, velocityDx: 0);
      return;
    }
  }

  void _schedulePumpQueue() {
    if (_queuedTurns.isEmpty) return;
    // The commit callback has just changed the host's page state; wait one
    // frame so this widget is rebuilt with the shifted neighbours before the
    // next queued turn reads them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pumpQueue();
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null ||
        _phase == _CoverTurnPhase.awaitingPageUpdate) {
      return;
    }
    _activePointer = event.pointer;
    _downPosition = event.position;
    _dragStarted = false;
    _gestureAbandoned = false;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    if (_phase == _CoverTurnPhase.settling) {
      _ticker.stop();
      _settleSimulation = null;
      final superseded = _activeTurn;
      _activeTurn = null;
      if (superseded != null && !superseded.completer.isCompleted) {
        superseded.completer.complete();
      }
      _dragStarted = true;
      _gestureOriginDx = event.position.dx - _gestureDeltaForOffset();
      setState(() => _phase = _CoverTurnPhase.dragging);
      return;
    }
    _selectionHoldTimer?.cancel();
    _selectionHoldTimer = Timer(kLongPressTimeout, () {
      if (!_dragStarted) _gestureAbandoned = true;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    if (_gestureAbandoned) return;
    if (!_dragStarted) {
      final down = _downPosition;
      if (down == null) return;
      final delta = event.position - down;
      if (delta.distance < kTouchSlop) return;
      if (delta.dx.abs() <= delta.dy.abs()) {
        // Vertical intent: leave the gesture to pull-to-bookmark and friends.
        _gestureAbandoned = true;
        return;
      }
      _selectionHoldTimer?.cancel();
      _selectionHoldTimer = null;
      _dragStarted = true;
      _gestureOriginDx = event.position.dx;
      setState(() => _phase = _CoverTurnPhase.dragging);
      return;
    }
    final originDx = _gestureOriginDx;
    if (originDx == null) return;
    _applyDragDelta(event.position.dx - originDx);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    final tracker = _velocityTracker
      ?..addPosition(event.timeStamp, event.position);
    final velocityDx =
        tracker
            ?.getVelocity()
            .pixelsPerSecond
            .dx
            .clamp(-_maxSettleVelocity, _maxSettleVelocity)
            .toDouble() ??
        0.0;
    final dragStarted = _dragStarted;
    _clearPointerTracking();
    if (dragStarted && _phase == _CoverTurnPhase.dragging) {
      _endDrag(velocityDx);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    final dragStarted = _dragStarted;
    _clearPointerTracking();
    if (dragStarted && _phase == _CoverTurnPhase.dragging) {
      _startSettle(commit: false, velocityDx: 0);
    }
  }

  void _clearPointerTracking() {
    _activePointer = null;
    _downPosition = null;
    _gestureOriginDx = null;
    _dragStarted = false;
    _gestureAbandoned = false;
    _velocityTracker = null;
    _selectionHoldTimer?.cancel();
    _selectionHoldTimer = null;
  }

  void _applyDragDelta(double delta) {
    if (_viewportWidth <= 0) return;
    final direction = delta < 0
        ? ReaderPageTurnDirection.forward
        : delta > 0
        ? ReaderPageTurnDirection.backward
        : (_direction ?? ReaderPageTurnDirection.forward);
    if (direction != _direction) {
      setState(() => _direction = direction);
    }
    if (direction == ReaderPageTurnDirection.forward) {
      _offset.value = widget.forwardPage != null
          ? math.max(delta, -_viewportWidth)
          : -_rubberStretch(-delta);
    } else {
      _offset.value = widget.backwardPage != null
          ? -_viewportWidth + math.min(delta, _viewportWidth)
          : _rubberStretch(delta);
    }
  }

  void _endDrag(double velocityDx) {
    final width = _viewportWidth;
    final direction = _direction;
    if (width <= 0 || direction == null) {
      _resetToIdle();
      return;
    }
    final bool commit;
    if (direction == ReaderPageTurnDirection.forward &&
        widget.forwardPage != null) {
      commit =
          velocityDx <= -_minFlingVelocity ||
          (velocityDx < _minFlingVelocity &&
              _offset.value <= -width * _commitDragFraction);
    } else if (direction == ReaderPageTurnDirection.backward &&
        widget.backwardPage != null) {
      commit =
          velocityDx >= _minFlingVelocity ||
          (velocityDx > -_minFlingVelocity &&
              _offset.value >= -width * (1 - _commitDragFraction));
    } else {
      commit = false;
    }
    _startSettle(commit: commit, velocityDx: velocityDx);
  }

  void _startSettle({required bool commit, required double velocityDx}) {
    final direction = _direction;
    if (direction == null || _viewportWidth <= 0) {
      _resetToIdle();
      return;
    }
    final hasNeighbour = direction == ReaderPageTurnDirection.forward
        ? widget.forwardPage != null
        : widget.backwardPage != null;
    final double target;
    if (!hasNeighbour) {
      target = 0;
    } else if (direction == ReaderPageTurnDirection.forward) {
      target = commit ? -_viewportWidth : 0;
    } else {
      target = commit ? 0 : -_viewportWidth;
    }
    final spring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: commit ? 420 : 400,
      ratio: commit ? 0.96 : 0.90,
    );
    _settleSimulation = SpringSimulation(
      spring,
      _offset.value,
      target,
      velocityDx,
      tolerance: const Tolerance(distance: 0.5, velocity: 12),
    );
    _settleTarget = target;
    _settleCommits = commit && hasNeighbour;
    setState(() => _phase = _CoverTurnPhase.settling);
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
  }

  void _onSettleTick(Duration elapsed) {
    final simulation = _settleSimulation;
    if (simulation == null) {
      _ticker.stop();
      return;
    }
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final position = simulation.x(seconds);
    final snapsToTarget = (position - _settleTarget).abs() <= 0.75;
    _offset.value = snapsToTarget ? _settleTarget : position;
    if (!snapsToTarget && !simulation.isDone(seconds)) return;
    _ticker.stop();
    _settleSimulation = null;
    _offset.value = _settleTarget;
    if (_settleCommits) {
      setState(() => _phase = _CoverTurnPhase.awaitingPageUpdate);
      unawaited(_commitTurn());
    } else {
      _finishTurn();
    }
  }

  Future<void> _commitTurn() async {
    try {
      final callback = _direction == ReaderPageTurnDirection.backward
          ? widget.onTurnBackward
          : widget.onTurnForward;
      await Future<void>.sync(callback);
    } catch (error, stackTrace) {
      debugPrint('Reader cover page turn callback failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) _finishTurn();
    }
  }

  void _finishTurn() {
    final active = _activeTurn;
    _activeTurn = null;
    if (active != null && !active.completer.isCompleted) {
      active.completer.complete();
    }
    _resetToIdle();
    _schedulePumpQueue();
  }

  void _abortInteraction() {
    _ticker.stop();
    _settleSimulation = null;
    _clearPointerTracking();
    _finishTurn();
  }

  void _resetToIdle() {
    _offset.value = 0;
    if (!mounted) {
      _phase = _CoverTurnPhase.idle;
      _direction = null;
      return;
    }
    setState(() {
      _phase = _CoverTurnPhase.idle;
      _direction = null;
    });
  }

  Widget _sheet(ReaderPageSnapshot page) => RepaintBoundary(
    child: ColoredBox(color: widget.paperColor, child: page.child),
  );

  Widget _hiddenSheet(ReaderPageSnapshot? page, {required bool visible}) {
    if (page == null) return const SizedBox.shrink();
    final sheet = _sheet(page);
    if (visible) return sheet;
    return Offstage(
      offstage: true,
      child: ExcludeSemantics(child: IgnorePointer(child: sheet)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width > 0 && width != _viewportWidth) {
          if (_viewportWidth > 0 && _phase != _CoverTurnPhase.idle) {
            // The viewport was resized mid-turn (rotation, window resize):
            // drop the interaction instead of animating against stale
            // geometry.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _phase != _CoverTurnPhase.idle) {
                _abortInteraction();
              }
            });
          }
          _viewportWidth = width;
        }
        final backwardSheetActive = _backwardSheetActive;
        final forwardSheetRevealed = _forwardSheetRevealed;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: ListenableBuilder(
            listenable: _offset,
            builder: (context, _) {
              final offset = _offset.value;
              final coveredFraction = width <= 0
                  ? 1.0
                  : ((offset + width) / width).clamp(0.0, 1.0);
              final revealDim = _maxRevealDim * coveredFraction;
              final shadowOpacity = width <= 0
                  ? 0.0
                  : (0.28 * ((offset + width) / 48).clamp(0.0, 1.0));
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    key: const ValueKey('reader-cover-base'),
                    child: ColoredBox(color: widget.paperColor),
                  ),
                  // The next page, revealed beneath a forward turn.
                  Positioned.fill(
                    key: const ValueKey('reader-cover-forward-sheet'),
                    child: _hiddenSheet(
                      widget.forwardPage,
                      visible: forwardSheetRevealed,
                    ),
                  ),
                  Positioned.fill(
                    key: const ValueKey('reader-cover-forward-dim'),
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: forwardSheetRevealed ? revealDim : 0,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    key: const ValueKey('reader-cover-current-sheet'),
                    left: backwardSheetActive ? 0 : offset,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: _sheet(widget.currentPage),
                  ),
                  Positioned(
                    key: const ValueKey('reader-cover-current-dim'),
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: backwardSheetActive ? revealDim : 0,
                        ),
                      ),
                    ),
                  ),
                  // The previous page, sliding back in over the current one.
                  Positioned(
                    key: const ValueKey('reader-cover-backward-sheet'),
                    left: backwardSheetActive ? offset : 0,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: _hiddenSheet(
                      widget.backwardPage,
                      visible: backwardSheetActive,
                    ),
                  ),
                  Positioned(
                    key: const ValueKey('reader-cover-shadow'),
                    left: width + offset,
                    top: 0,
                    bottom: 0,
                    width: _shadowWidth,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: shadowOpacity),
                              Colors.black.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

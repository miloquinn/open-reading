part of '../../reader_shader_page_curl.dart';

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

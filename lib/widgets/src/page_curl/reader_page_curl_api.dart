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
  String? get debugActiveBackPageIdentity =>
      _state?._activeBackPage?.key.pageIdentity;

  @visibleForTesting
  bool get debugUsesClassicFoldShader => _state?._classicFoldShader != null;

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
  ReaderPageCurlCoordinator({this.gutterWidth = 0})
    : assert(gutterWidth >= 0 && gutterWidth.isFinite);

  /// The fixed visual gap between the two leaves in a tablet spread.
  ///
  /// A coordinated leaf uses this together with its own width when painting
  /// the folded sheet across the binding and onto the opposite leaf.
  final double gutterWidth;

  Object? _owner;
  final ValueNotifier<ReaderPageBindingEdge?> _activeBindingEdge =
      ValueNotifier(null);
  bool _availableAfterFrame = true;
  bool _notificationScheduled = false;
  bool _disposed = false;

  bool _tryAcquire(Object owner, ReaderPageBindingEdge bindingEdge) {
    if (_disposed) return false;
    if (identical(_owner, owner)) return true;
    if (_owner != null || !_availableAfterFrame) return false;
    _owner = owner;
    _activeBindingEdge.value = bindingEdge;
    return true;
  }

  void _release(Object owner) {
    if (_disposed) return;
    if (!identical(_owner, owner)) return;
    _owner = null;
    _activeBindingEdge.value = null;
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

  /// Binding edge of the leaf that currently owns the spread turn.
  ///
  /// The right-hand leaf is bound on the left; the left-hand leaf is bound on
  /// the right. Hosts use this to paint the active leaf after its sibling.
  ReaderPageBindingEdge? get activeBindingEdge => _activeBindingEdge.value;

  /// Emits immediately when the active spread leaf changes.
  ValueListenable<ReaderPageBindingEdge?> get activeBindingEdgeListenable =>
      _activeBindingEdge;

  @visibleForTesting
  bool get debugIsBusy => _owner != null || !_availableAfterFrame;

  @override
  void dispose() {
    _disposed = true;
    _owner = null;
    _activeBindingEdge.dispose();
    super.dispose();
  }
}

/// Paint-order-aware layout for the two independently rendered leaves of a
/// tablet page-curl spread.
///
/// The leaves keep fixed physical positions while the leaf that owns the
/// shared [coordinator] is moved to the final paint slot. Stable layer keys
/// preserve each curl state when the order changes mid-gesture.
class ReaderPageCurlSpread extends StatelessWidget {
  const ReaderPageCurlSpread({
    super.key,
    required this.coordinator,
    required this.left,
    required this.gutter,
    this.right,
  });

  final ReaderPageCurlCoordinator coordinator;
  final Widget left;
  final Widget? right;
  final Widget gutter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final leafWidth = math.max(
          0.0,
          (constraints.maxWidth - coordinator.gutterWidth) / 2,
        );
        return AnimatedBuilder(
          animation: coordinator.activeBindingEdgeListenable,
          builder: (context, _) {
            final leftLayer = Positioned(
              key: const ValueKey('reader-page-curl-spread-left-layer'),
              left: 0,
              top: 0,
              bottom: 0,
              width: leafWidth,
              child: left,
            );
            final rightLayer = Positioned(
              key: const ValueKey('reader-page-curl-spread-right-layer'),
              left: leafWidth + coordinator.gutterWidth,
              top: 0,
              bottom: 0,
              width: leafWidth,
              child: right ?? const SizedBox.expand(),
            );
            final leftIsActive =
                coordinator.activeBindingEdge == ReaderPageBindingEdge.right;
            return Stack(
              key: const ValueKey('reader-page-curl-spread-layer-stack'),
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  key: const ValueKey('reader-page-curl-spread-gutter-layer'),
                  left: leafWidth,
                  top: 0,
                  bottom: 0,
                  width: coordinator.gutterWidth,
                  child: IgnorePointer(child: gutter),
                ),
                if (leftIsActive) rightLayer else leftLayer,
                if (leftIsActive) leftLayer else rightLayer,
              ],
            );
          },
        );
      },
    );
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
    this.outgoingBackPage,
    this.controller,
    this.preparePages,
    this.coordinator,
    this.edgeDragOnly = false,
    this.bindingEdge = ReaderPageBindingEdge.left,
  });

  final ReaderPageSnapshot currentPage;
  final ReaderPageSnapshot? forwardPage;
  final ReaderPageSnapshot? backwardPage;

  /// Optional content printed on the reverse of the current physical sheet.
  ///
  /// This is used only while the current page is turning out. A tablet spread
  /// supplies the page that will land on the opposite side of the spine. When
  /// omitted, the folded back keeps the legacy mirrored-source appearance used
  /// by the single-page phone reader.
  final ReaderPageSnapshot? outgoingBackPage;
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

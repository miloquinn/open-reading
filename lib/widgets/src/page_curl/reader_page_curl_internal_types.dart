part of '../../reader_shader_page_curl.dart';

enum _PageTurnPhase {
  idle,
  pointerPending,
  dragging,
  settlingBack,
  settlingCommit,
  awaitingPageUpdate,
}

class _ReaderSpringChannel {
  SpringSimulation? simulationX;
  SpringSimulation? simulationY;
  Duration startedAt = Duration.zero;
  bool commits = false;
  Offset? startTouch;
  Offset? target;

  void clear() {
    simulationX = null;
    simulationY = null;
    startedAt = Duration.zero;
    commits = false;
    startTouch = null;
    target = null;
  }
}

class _QueuedProgrammaticTurn {
  _QueuedProgrammaticTurn(this.direction);

  final ReaderPageTurnDirection direction;
  final Completer<void> completer = Completer<void>();
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

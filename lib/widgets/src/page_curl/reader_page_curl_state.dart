part of '../../reader_shader_page_curl.dart';

class _ReaderShaderPageCurlState extends State<ReaderShaderPageCurl>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const int _snapshotBudgetBytes = 48 * 1024 * 1024;
  static const int _perSnapshotBudgetBytes = 8 * 1024 * 1024;
  static const int _maxQueuedProgrammaticTurns = 2;
  static const double _edgeStartFraction = 0.30;
  static const double _activationDistance = 18;
  static const double _edgeHorizontalIntentRatio = 0.5;
  static const double _horizontalIntentRatio = 1.12;
  static const double _predictionHorizonSeconds = 0.14;
  static const double _commitProjection = 0.28;
  static const Duration _middleDragCatchUpDuration =
      Duration(milliseconds: 120);
  static const double _middleDragTiltStart = 0.55;

  final GlobalKey _currentKey = GlobalKey(debugLabel: 'curl-current');
  final GlobalKey _forwardKey = GlobalKey(debugLabel: 'curl-forward');
  final GlobalKey _backwardKey = GlobalKey(debugLabel: 'curl-backward');
  final GlobalKey _outgoingBackKey =
      GlobalKey(debugLabel: 'curl-outgoing-back');
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
  ReaderPageTurnDirection? _pendingDirection;
  ReaderPageTurnGeometry? _geometry;
  ReaderPageSnapshot? _activeSourcePage;
  ReaderPageSnapshot? _activeTargetPage;
  ReaderPageSnapshot? _activeBackPage;
  GlobalKey? _activeSourceKey;
  GlobalKey? _activeTargetKey;
  GlobalKey? _activeBackKey;
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
        !_sameOptionalSnapshot(oldWidget.backwardPage, widget.backwardPage) ||
        !_sameOptionalSnapshot(
          oldWidget.outgoingBackPage,
          widget.outgoingBackPage,
        );
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
    final outgoingBack = widget.outgoingBackPage;
    if (outgoingBack != null) {
      adjacentCaptures.add(
        _ensureSnapshot(outgoingBack, _outgoingBackKey, generation),
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
        if (widget.outgoingBackPage case final page?) page.key,
        if (_activeSourcePage case final page?) page.key,
        if (_activeTargetPage case final page?) page.key,
        if (_activeBackPage case final page?) page.key,
      };

  void _onPointerDown(PointerDownEvent event) {
    if (_phase != _PageTurnPhase.idle) return;
    _pointerDown = event.localPosition;
  }

  void _onPanStart(DragStartDetails details) {
    if (_phase != _PageTurnPhase.idle || _viewportSize.isEmpty) return;
    final pointerDown = _pointerDown ?? details.localPosition;
    final fraction = pointerDown.dx / _viewportSize.width;
    if (fraction >= 1 - _edgeStartFraction && widget.forwardPage != null) {
      _pendingDirection = ReaderPageTurnDirection.forward;
    } else if (fraction <= _edgeStartFraction && widget.backwardPage != null) {
      _pendingDirection = ReaderPageTurnDirection.backward;
    } else if (!widget.edgeDragOnly) {
      _pendingDirection = null;
    } else {
      _pointerDown = null;
      _dragOrigin = null;
      _pendingDirection = null;
      return;
    }
    setState(() => _phase = _PageTurnPhase.pointerPending);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_phase == _PageTurnPhase.pointerPending) {
      final pointerDown = _pointerDown;
      if (pointerDown == null) return;
      final delta = details.localPosition - pointerDown;
      if (delta.distance < _activationDistance) {
        return;
      }
      final pendingDirection = _pendingDirection;
      final startedFromEdge = pendingDirection != null;
      final ReaderPageTurnDirection direction;
      if (pendingDirection != null) {
        final movesTowardTurn =
            pendingDirection == ReaderPageTurnDirection.forward
                ? delta.dx < 0
                : delta.dx > 0;
        if (!movesTowardTurn ||
            delta.dx.abs() < delta.dy.abs() * _edgeHorizontalIntentRatio) {
          return;
        }
        direction = pendingDirection;
      } else {
        if (delta.dx.abs() < delta.dy.abs() * _horizontalIntentRatio) return;
        direction = delta.dx < 0
            ? ReaderPageTurnDirection.forward
            : ReaderPageTurnDirection.backward;
      }
      if (!_hasPage(direction)) {
        _resetToIdle();
        return;
      }
      final activationPoint = details.localPosition;
      final started = _beginDrag(
        direction,
        pointer: activationPoint,
        origin: activationPoint,
        catchUpFromEdge: !startedFromEdge &&
            _motionFor(direction) == ReaderPageTurnMotion.outgoing,
      );
      if (!started) _resetToIdle();
      return;
    }
    if (_phase != _PageTurnPhase.dragging || _direction == null) return;
    _latestDragPointer = details.localPosition;
    if (_catchUpStartPointer != null) {
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
    _pendingDirection = null;
    _dragOrigin = origin;
    _latestDragPointer = pointer;
    _activeSourcePage = source;
    _activeTargetPage = target;
    _activeBackPage = layers.back;
    _activeSourceKey = layers.sourceKey;
    _activeTargetKey = layers.targetKey;
    _activeBackKey = layers.backKey;
    _captureActiveSnapshotSync(
      source,
      layers.sourceKey,
      refreshAfterPreparation: !_sameSnapshot(source, widget.currentPage),
    );
    if (layers.back case final back?) {
      _captureActiveSnapshotSync(
        back,
        layers.backKey!,
        refreshAfterPreparation: !_sameSnapshot(back, widget.currentPage),
      );
    }
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
    unawaited(_ensureActivePaintSnapshots(direction));
    unawaited(_ensureActiveSnapshots(direction));
    if (catchUpFromEdge) {
      _startCatchUp();
    }
    return true;
  }

  bool _acquireTurnSlot() {
    final coordinator = widget.coordinator;
    if (coordinator == null) return true;
    if (!coordinator._tryAcquire(this, widget.bindingEdge)) return false;
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
    if (!mounted || generation != _captureGeneration) return;
    final back = _direction == direction && _activeBackPage != null
        ? _activeBackPage
        : layers.back;
    final backKey = _direction == direction && _activeBackKey != null
        ? _activeBackKey
        : layers.backKey;
    if (back != null && backKey != null) {
      await _ensureSnapshot(back, backKey, generation);
    }
  }

  Future<void> _ensureActivePaintSnapshots(
    ReaderPageTurnDirection direction,
  ) async {
    final layers = _turnLayers(direction);
    if (layers == null) return;
    final source = _direction == direction && _activeSourcePage != null
        ? _activeSourcePage!
        : layers.source;
    final sourceKey = _direction == direction && _activeSourceKey != null
        ? _activeSourceKey!
        : layers.sourceKey;
    await _ensureSnapshot(
      source,
      sourceKey,
      _captureGeneration,
    );
    if (!mounted) return;
    final back = _direction == direction && _activeBackPage != null
        ? _activeBackPage
        : layers.back;
    final backKey = _direction == direction && _activeBackKey != null
        ? _activeBackKey
        : layers.backKey;
    if (back != null && backKey != null) {
      await _ensureSnapshot(back, backKey, _captureGeneration);
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
    _finishCatchUpAtLatestPointer();
    if (_direction == ReaderPageTurnDirection.backward) {
      final origin = _dragOrigin;
      final pointer = _latestDragPointer;
      _startSpring(
        commit: origin != null && pointer != null && pointer.dx > origin.dx,
        canonicalVelocity: Offset.zero,
      );
      return;
    }
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
    await _ensureActivePaintSnapshots(direction);
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
            back: widget.outgoingBackPage,
            backKey: widget.outgoingBackPage == null ? null : _outgoingBackKey,
          )
        : _ReaderTurnLayers(
            source: adjacent,
            sourceKey: adjacentKey,
            target: widget.currentPage,
            targetKey: _currentKey,
          );
  }

  void _captureActiveSnapshotSync(
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
    final springVelocity = geometry.motion == ReaderPageTurnMotion.incoming
        ? Offset(canonicalVelocity.dx, 0)
        : canonicalVelocity;
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
      springVelocity.dx,
      tolerance: tolerance,
    );
    channel.simulationY = SpringSimulation(
      spring,
      geometry.canonicalTouch.dy,
      target.dy,
      springVelocity.dy,
      tolerance: tolerance,
    );
    channel
      ..commits = commit
      ..startTouch = geometry.canonicalTouch
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
    final startTouch = channel.startTouch;
    final target = channel.target;
    var renderedTouch = touch;
    final isIncoming = geometry.motion == ReaderPageTurnMotion.incoming;
    if (startTouch != null && target != null && isIncoming) {
      renderedTouch = _IncomingPageTurnSettle.renderedTouch(
        start: startTouch,
        current: touch,
        target: target,
      );
    }
    final terminalSnapDistance = math.max(
      2.0,
      math.min(8.0, _viewportSize.width * 0.012),
    );
    final snapsToExactTerminal = target != null &&
        (isIncoming
            ? (touch.dx - target.dx).abs() <= terminalSnapDistance
            : channel.commits &&
                (touch - target).distance <= terminalSnapDistance);
    if (snapsToExactTerminal) renderedTouch = target;
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
        (isIncoming
            ? simulationX.isDone(seconds)
            : simulationX.isDone(seconds) && simulationY.isDone(seconds));
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
      _pendingDirection = null;
      _geometry = null;
      _activeSourcePage = null;
      _activeTargetPage = null;
      _activeBackPage = null;
      _activeSourceKey = null;
      _activeTargetKey = null;
      _activeBackKey = null;
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
      (_activeBackPage == null || _cachedImage(_activeBackPage) != null) &&
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
        final backImage = _cachedImage(_activeBackPage);
        final animationReady = _animationReady;
        final boundaryPages = <GlobalKey, ReaderPageSnapshot>{
          _currentKey: widget.currentPage,
          if (widget.backwardPage case final page?) _backwardKey: page,
          if (widget.forwardPage case final page?) _forwardKey: page,
          if (widget.outgoingBackPage case final page?) _outgoingBackKey: page,
        };
        if (_activeSourcePage != null && _activeSourceKey != null) {
          boundaryPages[_activeSourceKey!] = _activeSourcePage!;
        }
        if (_activeTargetPage != null && _activeTargetKey != null) {
          boundaryPages[_activeTargetKey!] = _activeTargetPage!;
        }
        if (_activeBackPage != null && _activeBackKey != null) {
          boundaryPages[_activeBackKey!] = _activeBackPage!;
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
              clipBehavior:
                  widget.coordinator == null ? Clip.hardEdge : Clip.none,
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
                        backImage: backImage,
                        bindingOverflow: widget.coordinator == null
                            ? 0
                            : geometry.size.width +
                                widget.coordinator!.gutterWidth,
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
    required ui.Image? backImage,
    required double bindingOverflow,
  }) {
    if (_classicFoldShader != null) {
      return _ReaderClassicFoldPainter(
        shader: _classicFoldShader!,
        sourcePage: sourceImage,
        backPage: backImage,
        geometry: geometry,
        bindingEdge: widget.bindingEdge,
        bindingOverflow: bindingOverflow,
      );
    }
    return _ReaderFallbackTurnPainter(
      sourcePage: sourceImage,
      backPage: backImage,
      geometry: geometry,
      bindingOverflow: bindingOverflow,
    );
  }
}

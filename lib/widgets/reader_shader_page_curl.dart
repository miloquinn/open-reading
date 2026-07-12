import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ReaderPageCurlController {
  _ReaderShaderPageCurlState? _state;

  Future<void> turnForward() async => _state?._turnForward();

  Future<void> turnBackward() async => _state?._turnBackward();

  void _attach(_ReaderShaderPageCurlState state) => _state = state;

  void _detach(_ReaderShaderPageCurlState state) {
    if (identical(_state, state)) _state = null;
  }
}

/// Reader-specific page curl based on the MIT-licensed cylinder shader from
/// `flutter_page_curl`, adapted for high-density text and bounded page caching.
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
  });

  final Widget currentPage;
  final Widget? forwardPage;
  final Widget? backwardPage;
  final VoidCallback onTurnForward;
  final VoidCallback onTurnBackward;
  final Color paperColor;
  final ReaderPageCurlController? controller;
  final Future<void> Function()? preparePages;

  @override
  State<ReaderShaderPageCurl> createState() => _ReaderShaderPageCurlState();
}

class _ReaderShaderPageCurlState extends State<ReaderShaderPageCurl>
    with SingleTickerProviderStateMixin {
  final GlobalKey _currentKey = GlobalKey(debugLabel: 'curl-current');
  final GlobalKey _forwardKey = GlobalKey(debugLabel: 'curl-forward');
  final GlobalKey _backwardKey = GlobalKey(debugLabel: 'curl-backward');

  late final AnimationController _settleController;

  ui.FragmentShader? _shader;
  ui.Image? _currentImage;
  ui.Image? _forwardImage;
  ui.Image? _backwardImage;

  Size _viewportSize = Size.zero;
  Offset? _dragStartPosition;
  Offset _startPosition = Offset.zero;
  Offset _curlPosition = Offset.zero;
  Offset _settleFrom = Offset.zero;
  Offset _settleTo = Offset.zero;
  bool _reverse = false;
  bool _curling = false;
  bool _settling = false;
  bool _reportedTurn = false;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
    )..addListener(_onSettleTick);
    widget.controller?._attach(this);
    unawaited(_loadShader());
    WidgetsBinding.instance.addPostFrameCallback((_) => _capturePages());
  }

  @override
  void didUpdateWidget(covariant ReaderShaderPageCurl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _settleController
      ..removeListener(_onSettleTick)
      ..dispose();
    _disposeImages();
    _shader?.dispose();
    super.dispose();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/reader_page_curl.frag',
      );
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    } catch (error, stackTrace) {
      debugPrint('Reader page curl shader failed to load: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<ui.Image?> _capture(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) return null;
    final deviceRatio = MediaQuery.devicePixelRatioOf(context);
    final captureRatio = deviceRatio.clamp(1.0, 2.5);
    try {
      return await boundary.toImage(pixelRatio: captureRatio);
    } catch (error, stackTrace) {
      debugPrint('Reader page curl capture failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _capturePages() async {
    if (!mounted) return;
    final preparePages = widget.preparePages;
    if (preparePages != null) {
      try {
        await preparePages();
        if (!mounted) return;
        await WidgetsBinding.instance.endOfFrame;
      } catch (error, stackTrace) {
        debugPrint('Reader page curl preparation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (!mounted) return;
    final current = await _capture(_currentKey);
    final forward =
        widget.forwardPage == null ? null : await _capture(_forwardKey);
    final backward =
        widget.backwardPage == null ? null : await _capture(_backwardKey);
    if (!mounted) {
      current?.dispose();
      forward?.dispose();
      backward?.dispose();
      return;
    }
    setState(() {
      _currentImage?.dispose();
      _forwardImage?.dispose();
      _backwardImage?.dispose();
      _currentImage = current;
      _forwardImage = forward;
      _backwardImage = backward;
    });
  }

  void _disposeImages() {
    _currentImage?.dispose();
    _forwardImage?.dispose();
    _backwardImage?.dispose();
    _currentImage = null;
    _forwardImage = null;
    _backwardImage = null;
  }

  Offset _normalize(Offset position) => Offset(
        (position.dx / _viewportSize.width).clamp(0.0, 1.0),
        (position.dy / _viewportSize.height).clamp(0.0, 1.0),
      );

  double get _progress => _reverse
      ? (_curlPosition.dx - _startPosition.dx).clamp(0.0, 1.0)
      : (_startPosition.dx - _curlPosition.dx).clamp(0.0, 1.0);

  bool get _imagesReady =>
      _currentImage != null &&
      (_reverse ? _backwardImage != null : _forwardImage != null);

  void _onDragStart(DragStartDetails details) {
    if (_settling || _viewportSize.isEmpty) return;
    final normalized = _normalize(details.localPosition);
    _dragStartPosition = normalized;
    if (normalized.dx >= 0.70 && widget.forwardPage != null) {
      _beginCurl(normalized, reverse: false);
    } else if (normalized.dx <= 0.30 && widget.backwardPage != null) {
      _beginCurl(normalized, reverse: true);
    }
  }

  void _beginCurl(Offset position, {required bool reverse}) {
    setState(() {
      _reverse = reverse;
      _startPosition = position;
      _curlPosition = position;
      _curling = true;
    });
    if (!_imagesReady) unawaited(_capturePages());
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_settling) return;
    final position = _normalize(details.localPosition);
    final dragStart = _dragStartPosition;
    if (!_curling && dragStart != null) {
      final horizontalDelta = position.dx - dragStart.dx;
      if (horizontalDelta <= -0.015 && widget.forwardPage != null) {
        _beginCurl(dragStart, reverse: false);
      } else if (horizontalDelta >= 0.015 && widget.backwardPage != null) {
        _beginCurl(dragStart, reverse: true);
      }
    }
    if (!_curling) return;
    setState(() => _curlPosition = position);
  }

  void _onDragEnd(DragEndDetails details) {
    _dragStartPosition = null;
    if (!_curling || _settling) return;
    final velocity = details.primaryVelocity ?? 0;
    final velocityCommits = _reverse ? velocity > 650 : velocity < -650;
    final commit = _progress >= 0.28 || velocityCommits;
    unawaited(_settleCurl(commit: commit));
  }

  void _onDragCancel() {
    _dragStartPosition = null;
    if (_curling && !_settling) {
      unawaited(_settleCurl(commit: false));
    }
  }

  Future<void> _turnForward() async {
    if (_settling || _reportedTurn || widget.forwardPage == null) return;
    if (!_imagesReady) await _capturePages();
    if (!mounted) return;
    _beginCurl(const Offset(0.98, 0.52), reverse: false);
    await _settleCurl(commit: true);
  }

  Future<void> _turnBackward() async {
    if (_settling || _reportedTurn || widget.backwardPage == null) return;
    if (!_imagesReady) await _capturePages();
    if (!mounted) return;
    _beginCurl(const Offset(0.02, 0.52), reverse: true);
    await _settleCurl(commit: true);
  }

  Future<void> _settleCurl({required bool commit}) async {
    if (_settling) return;
    _settling = true;
    final remaining = commit ? 1.0 - _progress : _progress;
    _settleController.duration = Duration(
      milliseconds: (80 + remaining * 140).round().clamp(90, 220),
    );
    _settleFrom = _curlPosition;
    _settleTo = commit
        ? Offset(_reverse ? 1.35 : -0.35, _startPosition.dy)
        : _startPosition;
    try {
      await _settleController.forward(from: 0);
      if (!mounted) return;
      if (commit && !_reportedTurn) {
        _reportedTurn = true;
        if (_reverse) {
          widget.onTurnBackward();
        } else {
          widget.onTurnForward();
        }
      } else if (!commit) {
        setState(() => _curling = false);
      }
    } finally {
      _settling = false;
    }
  }

  void _onSettleTick() {
    if (!mounted) return;
    final t = Curves.easeOutQuart.transform(_settleController.value);
    setState(() => _curlPosition = Offset.lerp(_settleFrom, _settleTo, t)!);
  }

  Widget _paper(GlobalKey key, Widget page) => RepaintBoundary(
        key: key,
        child: ColoredBox(color: widget.paperColor, child: page),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: _onDragCancel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.backwardPage case final page?)
                _paper(_backwardKey, page),
              if (widget.forwardPage case final page?)
                _paper(_forwardKey, page),
              _paper(_currentKey, widget.currentPage),
              if (_curling && _shader != null && _imagesReady)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ReaderCurlPainter(
                      shader: _shader!,
                      currentPage: _reverse ? _backwardImage! : _currentImage!,
                      targetPage: _reverse ? _currentImage! : _forwardImage!,
                      curlPosition: _curlPosition,
                      curlDirection:
                          _reverse ? const Offset(1, 0) : _curlDirection,
                      paperColor: widget.paperColor,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Offset get _curlDirection {
    final delta = _startPosition - _curlPosition;
    if (delta.distance < 0.001) {
      return _reverse ? const Offset(-1, 0) : const Offset(1, 0);
    }
    return delta / delta.distance;
  }
}

class _ReaderCurlPainter extends CustomPainter {
  const _ReaderCurlPainter({
    required this.shader,
    required this.currentPage,
    required this.targetPage,
    required this.curlPosition,
    required this.curlDirection,
    required this.paperColor,
  });

  final ui.FragmentShader shader;
  final ui.Image currentPage;
  final ui.Image targetPage;
  final Offset curlPosition;
  final Offset curlDirection;
  final Color paperColor;

  @override
  void paint(Canvas canvas, Size size) {
    var index = 0;
    shader
      ..setFloat(index++, size.width)
      ..setFloat(index++, size.height)
      ..setFloat(index++, curlPosition.dx)
      ..setFloat(index++, curlPosition.dy)
      ..setFloat(index++, curlDirection.dx)
      ..setFloat(index++, curlDirection.dy)
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
  bool shouldRepaint(covariant _ReaderCurlPainter oldDelegate) =>
      oldDelegate.curlPosition != curlPosition ||
      oldDelegate.curlDirection != curlDirection ||
      oldDelegate.paperColor != paperColor ||
      !identical(oldDelegate.currentPage, currentPage) ||
      !identical(oldDelegate.targetPage, targetPage);
}

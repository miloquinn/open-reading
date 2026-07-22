import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/reader_themes.dart';

class ReaderPullBookmark extends StatefulWidget {
  const ReaderPullBookmark({
    super.key,
    required this.enabled,
    required this.bookmarked,
    required this.busy,
    required this.palette,
    required this.addHint,
    required this.removeHint,
    required this.releaseHint,
    required this.onTriggered,
    required this.child,
  });

  final bool enabled;
  final bool bookmarked;
  final bool busy;
  final ReaderThemePalette palette;
  final String addHint;
  final String removeHint;
  final String releaseHint;
  final VoidCallback onTriggered;
  final Widget child;

  @override
  State<ReaderPullBookmark> createState() => _ReaderPullBookmarkState();
}

class _ReaderPullBookmarkState extends State<ReaderPullBookmark> {
  static const double _activationHeight = 72;
  static const double _triggerDistance = 76;
  static const double _maximumTravel = 116;

  int? _pointer;
  Offset? _origin;
  double _travel = 0;
  bool _eligible = false;

  void _reset() {
    if (_pointer == null && _travel == 0) return;
    setState(() {
      _pointer = null;
      _origin = null;
      _travel = 0;
      _eligible = false;
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || widget.busy || _pointer != null) return;
    final safeTop = MediaQuery.paddingOf(context).top;
    if (event.localPosition.dy > safeTop + _activationHeight) return;
    setState(() {
      _pointer = event.pointer;
      _origin = event.localPosition;
      _travel = 0;
      _eligible = true;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer || !_eligible || _origin == null) return;
    final delta = event.localPosition - _origin!;
    if (delta.dy < -8 || delta.dx.abs() > math.max(30, delta.dy * 0.8)) {
      _reset();
      return;
    }
    final next = delta.dy.clamp(0, _maximumTravel).toDouble();
    if (next != _travel) setState(() => _travel = next);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final triggered = _eligible && _travel >= _triggerDistance;
    _reset();
    if (triggered && !widget.busy) widget.onTriggered();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_travel / _triggerDistance).clamp(0.0, 1.0);
    final armed = progress >= 1;
    final label = armed
        ? widget.releaseHint
        : widget.bookmarked
        ? widget.removeHint
        : widget.addHint;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) => _reset(),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (widget.enabled && widget.bookmarked && _travel == 0)
            Positioned(
              top: 0,
              right: 28,
              child: IgnorePointer(
                child: CustomPaint(
                  size: const Size(20, 30),
                  painter: _BookmarkRibbonPainter(
                    color: widget.palette.accent,
                    shadow: widget.palette.shadow,
                  ),
                ),
              ),
            ),
          if (_travel > 0)
            Positioned(
              top: -46 + (_travel * 0.74),
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
                    decoration: BoxDecoration(
                      color: armed
                          ? widget.palette.accent
                          : widget.palette.controlBar,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(18),
                      ),
                      border: Border.all(
                        color: armed
                            ? widget.palette.accent
                            : widget.palette.border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.palette.shadow.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: armed ? math.pi : 0,
                          child: Icon(
                            widget.bookmarked
                                ? Icons.bookmark_remove_rounded
                                : Icons.bookmark_add_rounded,
                            size: 19,
                            color: armed
                                ? widget.palette.onAccent
                                : widget.palette.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: armed
                                    ? widget.palette.onAccent
                                    : widget.palette.text,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookmarkRibbonPainter extends CustomPainter {
  const _BookmarkRibbonPainter({required this.color, required this.shadow});

  final Color color;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 7)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, shadow.withValues(alpha: 0.24), 4, true);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BookmarkRibbonPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shadow != shadow;
}

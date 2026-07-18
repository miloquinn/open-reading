import 'package:flutter/material.dart';

/// Shared interaction shell for local and online vertical paging.
///
/// The tap recognizer deliberately lives inside [SelectionArea]. If it wraps
/// the selectable scroll view from outside, selection recognizers can consume
/// the light tap before the reader gets a chance to reveal its controls.
class ReaderVerticalPagingSurface extends StatelessWidget {
  const ReaderVerticalPagingSurface({
    super.key,
    required this.child,
    required this.onTap,
    this.surfaceKey,
    this.onHorizontalDragEnd,
  });

  final Widget child;
  final VoidCallback onTap;
  final Key? surfaceKey;
  final GestureDragEndCallback? onHorizontalDragEnd;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: GestureDetector(
        key: surfaceKey,
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        onHorizontalDragEnd: onHorizontalDragEnd,
        child: child,
      ),
    );
  }
}

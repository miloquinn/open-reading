part of '../../reader_shader_page_curl.dart';

/// Incoming completion is driven by X. Y is coupled to the remaining X
/// journey so a diagonal page becomes vertical before reaching the free-edge
/// terminal pose, rather than leaving a corner tail while a second spring
/// finishes later.
abstract final class _IncomingPageTurnSettle {
  static const double _flattenByProgress = 0.84;

  static Offset renderedTouch({
    required Offset start,
    required Offset current,
    required Offset target,
  }) {
    final totalX = target.dx - start.dx;
    final progress = totalX.abs() <= 1e-6
        ? 1.0
        : ((current.dx - start.dx) / totalX).clamp(0.0, 1.0);
    final flattenLinear = (progress / _flattenByProgress).clamp(0.0, 1.0);
    final flatten = flattenLinear * flattenLinear * (3 - 2 * flattenLinear);
    return Offset(
      current.dx,
      start.dy + (target.dy - start.dy) * flatten,
    );
  }
}

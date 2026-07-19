import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum ReaderPageTurnDirection { forward, backward }

enum ReaderPageTurnCorner { top, bottom }

enum ReaderPageTurnAnchorMode {
  nearestCorner,
  followEdge,
  followPointerEdge,
}

/// Clean-room paper-fold geometry in logical pixel space.
///
/// Both directions share a canonical right-edge page. Backward turns mirror
/// input/output across the vertical page axis. The crease is the perpendicular
/// bisector between the fixed paper corner and the constrained finger point.
@immutable
class ReaderPageTurnGeometry {
  const ReaderPageTurnGeometry._({
    required this.size,
    required this.direction,
    required this.corner,
    required this.canonicalAnchor,
    required this.canonicalTouch,
    required this.canonicalFoldPoint,
    required this.canonicalFoldNormal,
    required this.canonicalFoldStart,
    required this.canonicalFoldEnd,
    required this.progress,
  });

  factory ReaderPageTurnGeometry.fromPointer({
    required Size size,
    required ReaderPageTurnDirection direction,
    required Offset pointer,
    required Offset dragOrigin,
    ReaderPageTurnAnchorMode anchorMode =
        ReaderPageTurnAnchorMode.nearestCorner,
    bool canonicalBindingOnRight = false,
  }) {
    final canonicalOrigin = canonicalize(dragOrigin, size, direction);
    final canonicalPointer = canonicalize(pointer, size, direction);
    final corner = canonicalOrigin.dy <= size.height / 2
        ? ReaderPageTurnCorner.top
        : ReaderPageTurnCorner.bottom;
    final anchorY = switch (anchorMode) {
      ReaderPageTurnAnchorMode.nearestCorner =>
        corner == ReaderPageTurnCorner.top ? 0.0 : size.height,
      ReaderPageTurnAnchorMode.followEdge =>
        canonicalOrigin.dy.clamp(0.0, size.height),
      ReaderPageTurnAnchorMode.followPointerEdge =>
        canonicalPointer.dy.clamp(0.0, size.height),
    };
    return ReaderPageTurnGeometry.fromCanonicalTouch(
      size: size,
      direction: direction,
      corner: corner,
      canonicalAnchorY: anchorY,
      canonicalTouch: canonicalPointer,
      canonicalBindingOnRight: canonicalBindingOnRight,
    );
  }

  factory ReaderPageTurnGeometry.fromCanonicalTouch({
    required Size size,
    required ReaderPageTurnDirection direction,
    required ReaderPageTurnCorner corner,
    required Offset canonicalTouch,
    double? canonicalAnchorY,
    bool canonicalBindingOnRight = false,
  }) {
    final width = math.max(size.width, 1.0);
    final height = math.max(size.height, 1.0);
    final pageSize = Size(width, height);
    final anchor = Offset(
      width,
      (canonicalAnchorY ?? (corner == ReaderPageTurnCorner.top ? 0.0 : height))
          .clamp(0.0, height),
    );
    var touch = Offset(
      canonicalTouch.dx.clamp(-width, width),
      canonicalTouch.dy.clamp(0.0, height),
    );
    var delta = anchor - touch;
    if (delta.distance < 0.5) {
      touch = Offset(width - 0.5, anchor.dy);
      delta = anchor - touch;
    }
    final rawNormal = delta / delta.distance;
    final rawMidpoint = Offset(
      (anchor.dx + touch.dx) / 2,
      (anchor.dy + touch.dy) / 2,
    );
    var foldPoint = rawMidpoint;
    var foldNormal = rawNormal;
    var tangent = Offset(-foldNormal.dy, foldNormal.dx);
    var intersections = _lineRectangleIntersections(
      point: foldPoint,
      direction: tangent,
      size: pageSize,
    );
    var endpoints = _farthestPair(intersections, pageSize);

    // Clamp the infinite crease against the physical binding edge expressed
    // in canonical coordinates. Phone backward turns mirror motion but keep
    // a screen-left spine, so their canonical binding is on the right.
    if (rawNormal.dx.abs() > 1e-6) {
      double creaseXAt(double y) =>
          rawMidpoint.dx - rawNormal.dy * (y - rawMidpoint.dy) / rawNormal.dx;

      final rawTopX = creaseXAt(0);
      final rawBottomX = creaseXAt(height);
      final crossesBinding = canonicalBindingOnRight
          ? rawTopX > width || rawBottomX > width
          : rawTopX < 0 || rawBottomX < 0;
      if (crossesBinding) {
        final top = Offset(
          canonicalBindingOnRight
              ? math.min(width, rawTopX)
              : math.max(0, rawTopX),
          0,
        );
        final bottom = Offset(
          canonicalBindingOnRight
              ? math.min(width, rawBottomX)
              : math.max(0, rawBottomX),
          height,
        );
        tangent = (bottom - top) / (bottom - top).distance;
        foldNormal = Offset(tangent.dy, -tangent.dx);
        if (foldNormal.dx < 0) foldNormal = -foldNormal;
        foldPoint = top;
        intersections = _lineRectangleIntersections(
          point: foldPoint,
          direction: tangent,
          size: pageSize,
        );
        endpoints = _farthestPair(intersections, pageSize);
      }
    }
    return ReaderPageTurnGeometry._(
      size: pageSize,
      direction: direction,
      corner: corner,
      canonicalAnchor: anchor,
      canonicalTouch: touch,
      canonicalFoldPoint: foldPoint,
      canonicalFoldNormal: foldNormal,
      canonicalFoldStart: endpoints.$1,
      canonicalFoldEnd: endpoints.$2,
      progress: ((width - touch.dx) / width).clamp(0.0, 1.0),
    );
  }

  final Size size;
  final ReaderPageTurnDirection direction;
  final ReaderPageTurnCorner corner;
  final Offset canonicalAnchor;
  final Offset canonicalTouch;
  final Offset canonicalFoldPoint;
  final Offset canonicalFoldNormal;
  final Offset canonicalFoldStart;
  final Offset canonicalFoldEnd;
  final double progress;

  bool get reverse => direction == ReaderPageTurnDirection.backward;

  Offset get foldPoint => screenPoint(canonicalFoldPoint);

  Offset get anchor => screenPoint(canonicalAnchor);

  Offset get foldNormal => reverse
      ? Offset(-canonicalFoldNormal.dx, canonicalFoldNormal.dy)
      : canonicalFoldNormal;

  /// Renderer-facing turn axis. Its positive half-plane is always the page
  /// being uncovered, including when a backward turn mirrors the fold line.
  Offset get turnAxis => reverse ? -foldNormal : foldNormal;

  Offset get foldStart => screenPoint(canonicalFoldStart);

  Offset get foldEnd => screenPoint(canonicalFoldEnd);

  Offset get reflectedCorner {
    final distance =
        (canonicalAnchor - canonicalFoldPoint).dx * canonicalFoldNormal.dx +
            (canonicalAnchor - canonicalFoldPoint).dy * canonicalFoldNormal.dy;
    return screenPoint(
      canonicalAnchor - canonicalFoldNormal * (2 * distance),
    );
  }

  Offset screenPoint(Offset canonical) =>
      reverse ? Offset(size.width - canonical.dx, canonical.dy) : canonical;

  static Offset canonicalize(
    Offset point,
    Size size,
    ReaderPageTurnDirection direction,
  ) =>
      direction == ReaderPageTurnDirection.backward
          ? Offset(size.width - point.dx, point.dy)
          : point;

  static Offset canonicalVelocity(
    Offset velocity,
    ReaderPageTurnDirection direction,
  ) =>
      direction == ReaderPageTurnDirection.backward
          ? Offset(-velocity.dx, velocity.dy)
          : velocity;
}

List<Offset> _lineRectangleIntersections({
  required Offset point,
  required Offset direction,
  required Size size,
}) {
  const epsilon = 1e-6;
  final values = <Offset>[];

  void add(Offset candidate) {
    if (candidate.dx < -epsilon ||
        candidate.dx > size.width + epsilon ||
        candidate.dy < -epsilon ||
        candidate.dy > size.height + epsilon) {
      return;
    }
    final clamped = Offset(
      candidate.dx.clamp(0.0, size.width),
      candidate.dy.clamp(0.0, size.height),
    );
    if (values.every((value) => (value - clamped).distance > 0.25)) {
      values.add(clamped);
    }
  }

  if (direction.dx.abs() > epsilon) {
    var t = -point.dx / direction.dx;
    add(point + direction * t);
    t = (size.width - point.dx) / direction.dx;
    add(point + direction * t);
  }
  if (direction.dy.abs() > epsilon) {
    var t = -point.dy / direction.dy;
    add(point + direction * t);
    t = (size.height - point.dy) / direction.dy;
    add(point + direction * t);
  }
  return values;
}

(Offset, Offset) _farthestPair(List<Offset> values, Size size) {
  if (values.length < 2) {
    return (Offset(size.width, 0), Offset(size.width, size.height));
  }
  var first = values[0];
  var second = values[1];
  var greatestDistance = (first - second).distanceSquared;
  for (var left = 0; left < values.length; left++) {
    for (var right = left + 1; right < values.length; right++) {
      final distance = (values[left] - values[right]).distanceSquared;
      if (distance > greatestDistance) {
        greatestDistance = distance;
        first = values[left];
        second = values[right];
      }
    }
  }
  return (first, second);
}

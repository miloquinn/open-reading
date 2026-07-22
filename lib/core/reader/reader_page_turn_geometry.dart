import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum ReaderPageTurnDirection { forward, backward }

enum ReaderPageTurnCorner { top, bottom }

enum ReaderPageTurnAnchorMode { nearestCorner, followEdge }

/// Whether the visible leaf is being peeled away or unfolded into view.
///
/// This is deliberately independent from [ReaderPageTurnDirection]. A phone
/// forward turn peels the current leaf away, while a phone backward turn
/// unfolds the previous leaf into view. On the left side of a tablet spread,
/// a backward turn peels the current leaf toward the center binding.
enum ReaderPageTurnMotion { outgoing, incoming }

/// Clean-room paper-fold geometry in binding-local logical pixel space.
///
/// The canonical leaf is always bound on x=0 and has its free edge at x=width.
/// A physical right binding mirrors only the leaf coordinate system; navigation
/// direction never moves the spine. The crease is the perpendicular bisector
/// between the free edge rest point and a virtual paper corner.
@immutable
class ReaderPageTurnGeometry {
  const ReaderPageTurnGeometry._({
    required this.size,
    required this.direction,
    required this.motion,
    required this.bindingOnRight,
    required this.corner,
    required this.canonicalAnchor,
    required this.canonicalTouch,
    required this.canonicalFoldPoint,
    required this.canonicalFoldNormal,
    required this.canonicalFoldStart,
    required this.canonicalFoldEnd,
    required this.canonicalLineA,
    required this.canonicalLineB,
    required this.progress,
  });

  factory ReaderPageTurnGeometry.fromPointer({
    required Size size,
    required ReaderPageTurnDirection direction,
    required ReaderPageTurnMotion motion,
    required Offset pointer,
    required Offset dragOrigin,
    ReaderPageTurnAnchorMode anchorMode = ReaderPageTurnAnchorMode.followEdge,
    bool bindingOnRight = false,
  }) {
    final canonicalOrigin = toBindingSpace(
      dragOrigin,
      size,
      bindingOnRight: bindingOnRight,
    );
    final canonicalPointer = toBindingSpace(
      pointer,
      size,
      bindingOnRight: bindingOnRight,
    );
    final corner = canonicalOrigin.dy <= size.height / 2
        ? ReaderPageTurnCorner.top
        : ReaderPageTurnCorner.bottom;
    final anchorY = switch (anchorMode) {
      ReaderPageTurnAnchorMode.nearestCorner =>
        corner == ReaderPageTurnCorner.top ? 0.0 : size.height,
      ReaderPageTurnAnchorMode.followEdge => canonicalOrigin.dy.clamp(
        0.0,
        size.height,
      ),
    };
    final width = math.max(size.width, 1.0);
    final anchor = Offset(width, anchorY);

    // An outgoing turn makes the free paper corner follow the finger. An
    // incoming turn is a separate pose: the crease itself follows the finger,
    // so the virtual corner is reflected through the pointer around free-rest.
    // At the binding this yields touch=-width (fully turned out); at the free
    // edge it yields touch=width (the previous page is flat).
    final incomingCreaseDriver = Offset(
      (canonicalPointer.dx - canonicalOrigin.dx).clamp(0.0, width),
      anchorY + canonicalPointer.dy - canonicalOrigin.dy,
    );
    final canonicalTouch = motion == ReaderPageTurnMotion.outgoing
        ? canonicalPointer
        : incomingCreaseDriver * 2 - anchor;

    return ReaderPageTurnGeometry.fromCanonicalTouch(
      size: size,
      direction: direction,
      motion: motion,
      corner: corner,
      canonicalAnchorY: anchorY,
      canonicalTouch: canonicalTouch,
      bindingOnRight: bindingOnRight,
    );
  }

  factory ReaderPageTurnGeometry.fromCanonicalTouch({
    required Size size,
    required ReaderPageTurnDirection direction,
    required ReaderPageTurnMotion motion,
    required ReaderPageTurnCorner corner,
    required Offset canonicalTouch,
    double? canonicalAnchorY,
    bool bindingOnRight = false,
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
      canonicalTouch.dy.clamp(-height, height * 2),
    );
    final atBindingEndpoint = touch.dx == -width && touch.dy == anchor.dy;
    final atFreeEndpoint = touch.dx == width && touch.dy == anchor.dy;
    if (atBindingEndpoint || atFreeEndpoint) {
      final x = atBindingEndpoint ? 0.0 : width;
      final lineA = Offset(x, 0);
      final lineB = Offset(x, height);
      return ReaderPageTurnGeometry._(
        size: pageSize,
        direction: direction,
        motion: motion,
        bindingOnRight: bindingOnRight,
        corner: corner,
        canonicalAnchor: anchor,
        canonicalTouch: touch,
        canonicalFoldPoint: Offset(x, anchor.dy),
        canonicalFoldNormal: const Offset(1, 0),
        canonicalFoldStart: lineA,
        canonicalFoldEnd: lineB,
        canonicalLineA: lineA,
        canonicalLineB: lineB,
        progress: switch (motion) {
          ReaderPageTurnMotion.outgoing => atBindingEndpoint ? 1.0 : 0.0,
          ReaderPageTurnMotion.incoming => atFreeEndpoint ? 1.0 : 0.0,
        },
      );
    }
    var delta = anchor - touch;
    if (delta.distance < 0.5) {
      delta = const Offset(0.5, 0);
    }

    final rawNormal = delta / delta.distance;
    final rawMidpoint = Offset(
      (anchor.dx + touch.dx) / 2,
      (anchor.dy + touch.dy) / 2,
    );
    final rawTangent = Offset(-rawNormal.dy, rawNormal.dx);
    final lineExtent = width + height;
    final lineA = rawMidpoint + rawTangent * lineExtent;
    final lineB = rawMidpoint - rawTangent * lineExtent;

    // Mirrors the recovered shader's hard binding rule: intersect the crease
    // with the top/bottom edges and clamp both x coordinates with max(0, x).
    // The raw line is still retained for the shader, which performs the same
    // operation per pixel.
    final (top, bottom) = _bindingClampedTopBottom(
      point: rawMidpoint,
      normal: rawNormal,
      size: pageSize,
    );

    return ReaderPageTurnGeometry._(
      size: pageSize,
      direction: direction,
      motion: motion,
      bindingOnRight: bindingOnRight,
      corner: corner,
      canonicalAnchor: anchor,
      canonicalTouch: touch,
      canonicalFoldPoint: rawMidpoint,
      canonicalFoldNormal: rawNormal,
      canonicalFoldStart: top,
      canonicalFoldEnd: bottom,
      canonicalLineA: lineA,
      canonicalLineB: lineB,
      progress: switch (motion) {
        ReaderPageTurnMotion.outgoing => ((width - touch.dx) / width).clamp(
          0.0,
          1.0,
        ),
        ReaderPageTurnMotion.incoming =>
          ((touch.dx + width) / (width * 2)).clamp(0.0, 1.0),
      },
    );
  }

  final Size size;
  final ReaderPageTurnDirection direction;
  final ReaderPageTurnMotion motion;
  final bool bindingOnRight;
  final ReaderPageTurnCorner corner;
  final Offset canonicalAnchor;
  final Offset canonicalTouch;
  final Offset canonicalFoldPoint;
  final Offset canonicalFoldNormal;
  final Offset canonicalFoldStart;
  final Offset canonicalFoldEnd;

  /// Two far-apart points on the unclamped crease passed to the fragment
  /// shader as posA/posB.
  final Offset canonicalLineA;
  final Offset canonicalLineB;

  final double progress;

  Offset get foldPoint => screenPoint(canonicalFoldPoint);

  Offset get anchor => screenPoint(canonicalAnchor);

  Offset get foldNormal => bindingOnRight
      ? Offset(-canonicalFoldNormal.dx, canonicalFoldNormal.dy)
      : canonicalFoldNormal;

  Offset get turnAxis => foldNormal;

  Offset get foldStart => screenPoint(canonicalFoldStart);

  Offset get foldEnd => screenPoint(canonicalFoldEnd);

  Offset get lineA => screenPoint(canonicalLineA);

  Offset get lineB => screenPoint(canonicalLineB);

  Offset get reflectedCorner {
    final distance =
        (canonicalAnchor - canonicalFoldPoint).dx * canonicalFoldNormal.dx +
        (canonicalAnchor - canonicalFoldPoint).dy * canonicalFoldNormal.dy;
    return screenPoint(canonicalAnchor - canonicalFoldNormal * (2 * distance));
  }

  Offset screenPoint(Offset canonical) => bindingOnRight
      ? Offset(size.width - canonical.dx, canonical.dy)
      : canonical;

  static Offset toBindingSpace(
    Offset point,
    Size size, {
    required bool bindingOnRight,
  }) => bindingOnRight ? Offset(size.width - point.dx, point.dy) : point;

  static Offset velocityToBindingSpace(
    Offset velocity, {
    required bool bindingOnRight,
  }) => bindingOnRight ? Offset(-velocity.dx, velocity.dy) : velocity;
}

(Offset, Offset) _bindingClampedTopBottom({
  required Offset point,
  required Offset normal,
  required Size size,
}) {
  const epsilon = 1e-6;
  if (normal.dx.abs() <= epsilon) {
    final x = math.max(0.0, point.dx);
    return (Offset(x, 0), Offset(x, size.height));
  }

  double creaseXAt(double y) =>
      point.dx - normal.dy * (y - point.dy) / normal.dx;

  return (
    Offset(math.max(0.0, creaseXAt(0)), 0),
    Offset(math.max(0.0, creaseXAt(size.height)), size.height),
  );
}

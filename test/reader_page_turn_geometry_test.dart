import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_page_turn_geometry.dart';

void main() {
  const size = Size(400, 800);

  test('outgoing crease reflects the free paper corner onto the finger', () {
    final geometry = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      motion: ReaderPageTurnMotion.outgoing,
      pointer: const Offset(190, 610),
      dragOrigin: const Offset(398, 760),
    );

    expect(geometry.reflectedCorner.dx, closeTo(190, 0.001));
    expect(geometry.reflectedCorner.dy, closeTo(610, 0.001));
    expect(geometry.bindingOnRight, isFalse);
    expect(geometry.foldStart.dx, greaterThanOrEqualTo(0));
    expect(geometry.foldEnd.dx, greaterThanOrEqualTo(0));
  });

  test('phone backward is an incoming pose with the same left binding', () {
    final geometry = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.backward,
      motion: ReaderPageTurnMotion.incoming,
      pointer: const Offset(160, 360),
      dragOrigin: const Offset(0, 520),
    );

    expect(geometry.bindingOnRight, isFalse);
    expect(geometry.foldPoint.dx, closeTo(160, 0.001));
    expect(geometry.foldPoint.dy, closeTo(360, 0.001));
    expect(geometry.progress, closeTo(0.4, 0.001));
    expect(geometry.foldStart.dx, greaterThanOrEqualTo(0));
    expect(geometry.foldEnd.dx, greaterThanOrEqualTo(0));
  });

  test(
    'incoming middle gesture starts from displacement instead of half page',
    () {
      final geometry = ReaderPageTurnGeometry.fromPointer(
        size: size,
        direction: ReaderPageTurnDirection.backward,
        motion: ReaderPageTurnMotion.incoming,
        pointer: const Offset(232, 420),
        dragOrigin: const Offset(200, 400),
      );

      expect(geometry.foldPoint.dx, closeTo(32, 0.001));
      expect(geometry.foldPoint.dy, closeTo(420, 0.001));
      expect(geometry.progress, closeTo(0.08, 0.001));
    },
  );

  test('backward diagonal hand movement changes crease slope', () {
    final upper = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.backward,
      motion: ReaderPageTurnMotion.incoming,
      pointer: const Offset(160, 200),
      dragOrigin: const Offset(0, 400),
    );
    final lower = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.backward,
      motion: ReaderPageTurnMotion.incoming,
      pointer: const Offset(160, 600),
      dragOrigin: const Offset(0, 400),
    );

    expect(upper.canonicalFoldNormal.dy, greaterThan(0));
    expect(lower.canonicalFoldNormal.dy, lessThan(0));
    expect(upper.foldStart.dx, isNot(closeTo(upper.foldEnd.dx, 0.001)));
    expect(lower.foldStart.dx, isNot(closeTo(lower.foldEnd.dx, 0.001)));
  });

  test('horizontal incoming drag keeps a vertical crease at the driver', () {
    final geometry = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.backward,
      motion: ReaderPageTurnMotion.incoming,
      pointer: const Offset(210, 540),
      dragOrigin: const Offset(0, 540),
    );

    expect(geometry.foldPoint, const Offset(210, 540));
    expect(geometry.foldNormal.dy, closeTo(0, 0.001));
    expect(geometry.foldStart.dx, closeTo(210, 0.001));
    expect(geometry.foldEnd.dx, closeTo(210, 0.001));
  });

  test('right-bound tablet leaf mirrors leaf coordinates, not navigation', () {
    final leftLeafBackward = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.backward,
      motion: ReaderPageTurnMotion.outgoing,
      pointer: const Offset(180, 260),
      dragOrigin: const Offset(2, 40),
      bindingOnRight: true,
    );
    final canonicalOutgoing = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      motion: ReaderPageTurnMotion.outgoing,
      pointer: const Offset(220, 260),
      dragOrigin: const Offset(398, 40),
    );

    expect(leftLeafBackward.bindingOnRight, isTrue);
    expect(
      leftLeafBackward.foldPoint.dx,
      closeTo(size.width - canonicalOutgoing.foldPoint.dx, 0.001),
    );
    expect(
      leftLeafBackward.foldNormal.dx,
      closeTo(-canonicalOutgoing.foldNormal.dx, 0.001),
    );
  });

  test('binding clamp keeps both crease intersections off the glued side', () {
    final geometry = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.backward,
      motion: ReaderPageTurnMotion.incoming,
      pointer: const Offset(40, 40),
      dragOrigin: const Offset(0, 760),
    );

    expect(geometry.canonicalFoldStart.dx, greaterThanOrEqualTo(0));
    expect(geometry.canonicalFoldEnd.dx, greaterThanOrEqualTo(0));
  });

  test('outgoing and incoming completion progress are independent', () {
    final outgoingComplete = ReaderPageTurnGeometry.fromCanonicalTouch(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      motion: ReaderPageTurnMotion.outgoing,
      corner: ReaderPageTurnCorner.bottom,
      canonicalTouch: const Offset(-400, 800),
    );
    final incomingComplete = ReaderPageTurnGeometry.fromCanonicalTouch(
      size: size,
      direction: ReaderPageTurnDirection.backward,
      motion: ReaderPageTurnMotion.incoming,
      corner: ReaderPageTurnCorner.bottom,
      canonicalTouch: const Offset(400, 800),
    );

    expect(outgoingComplete.progress, 1);
    expect(incomingComplete.progress, 1);
    expect(outgoingComplete.canonicalFoldPoint.dx, closeTo(0, 0.001));
    expect(incomingComplete.canonicalFoldPoint.dx, closeTo(400, 0.001));
  });

  test('terminal poses use the shader exact vertical endpoints', () {
    final turnedOut = ReaderPageTurnGeometry.fromCanonicalTouch(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      motion: ReaderPageTurnMotion.outgoing,
      corner: ReaderPageTurnCorner.bottom,
      canonicalAnchorY: 620,
      canonicalTouch: const Offset(-400, 620),
    );
    final flatIncoming = ReaderPageTurnGeometry.fromCanonicalTouch(
      size: size,
      direction: ReaderPageTurnDirection.backward,
      motion: ReaderPageTurnMotion.incoming,
      corner: ReaderPageTurnCorner.bottom,
      canonicalAnchorY: 620,
      canonicalTouch: const Offset(400, 620),
    );
    final rightBoundTurnedOut = ReaderPageTurnGeometry.fromCanonicalTouch(
      size: size,
      direction: ReaderPageTurnDirection.backward,
      motion: ReaderPageTurnMotion.outgoing,
      corner: ReaderPageTurnCorner.bottom,
      canonicalAnchorY: 620,
      canonicalTouch: const Offset(-400, 620),
      bindingOnRight: true,
    );

    expect(turnedOut.canonicalLineA, Offset.zero);
    expect(turnedOut.canonicalLineB, const Offset(0, 800));
    expect(flatIncoming.canonicalLineA, const Offset(400, 0));
    expect(flatIncoming.canonicalLineB, const Offset(400, 800));
    expect(rightBoundTurnedOut.lineA, const Offset(400, 0));
    expect(rightBoundTurnedOut.lineB, const Offset(400, 800));
  });

  test('progress increases monotonically in both animation channels', () {
    ReaderPageTurnGeometry outgoing(double x) =>
        ReaderPageTurnGeometry.fromPointer(
          size: size,
          direction: ReaderPageTurnDirection.forward,
          motion: ReaderPageTurnMotion.outgoing,
          pointer: Offset(x, 700),
          dragOrigin: const Offset(400, 700),
        );
    ReaderPageTurnGeometry incoming(double x) =>
        ReaderPageTurnGeometry.fromPointer(
          size: size,
          direction: ReaderPageTurnDirection.backward,
          motion: ReaderPageTurnMotion.incoming,
          pointer: Offset(x, 700),
          dragOrigin: const Offset(0, 700),
        );

    expect(outgoing(360).progress, lessThan(outgoing(220).progress));
    expect(outgoing(220).progress, lessThan(outgoing(-40).progress));
    expect(incoming(40).progress, lessThan(incoming(220).progress));
    expect(incoming(220).progress, lessThan(incoming(380).progress));
  });
}

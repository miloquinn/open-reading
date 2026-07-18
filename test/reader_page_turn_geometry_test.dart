import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_page_turn_geometry.dart';

void main() {
  const size = Size(400, 800);

  test('crease reflects the selected paper corner onto the finger', () {
    final geometry = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      pointer: const Offset(190, 610),
      dragOrigin: const Offset(398, 760),
    );

    expect(geometry.reflectedCorner.dx, closeTo(190, 0.001));
    expect(geometry.reflectedCorner.dy, closeTo(610, 0.001));
    expect(_isOnBoundary(geometry.foldStart, size), isTrue);
    expect(_isOnBoundary(geometry.foldEnd, size), isTrue);
  });

  test('backward geometry is the horizontal mirror of forward geometry', () {
    final forward = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      pointer: const Offset(220, 260),
      dragOrigin: const Offset(398, 40),
    );
    final backward = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.backward,
      pointer: const Offset(180, 260),
      dragOrigin: const Offset(2, 40),
    );

    expect(backward.foldPoint.dx,
        closeTo(size.width - forward.foldPoint.dx, 0.001));
    expect(backward.foldPoint.dy, closeTo(forward.foldPoint.dy, 0.001));
    expect(backward.foldNormal.dx, closeTo(-forward.foldNormal.dx, 0.001));
    expect(backward.foldNormal.dy, closeTo(forward.foldNormal.dy, 0.001));
    expect(backward.reflectedCorner.dx, closeTo(180, 0.001));
    expect(backward.reflectedCorner.dy, closeTo(260, 0.001));
    expect(forward.turnAxis.dx, greaterThan(0));
    expect(backward.turnAxis.dx, greaterThan(0));
  });

  test('classic fold can settle with its crease on the opposite spine', () {
    final geometry = ReaderPageTurnGeometry.fromCanonicalTouch(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      corner: ReaderPageTurnCorner.bottom,
      canonicalTouch: const Offset(-400, 800),
    );

    expect(geometry.canonicalTouch, const Offset(-400, 800));
    expect(geometry.foldPoint.dx, closeTo(0, 0.001));
    expect(geometry.progress, 1);
  });

  test('classic fold keeps a horizontal drag on the same page-edge height', () {
    final geometry = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      pointer: const Offset(210, 540),
      dragOrigin: const Offset(398, 540),
      anchorMode: ReaderPageTurnAnchorMode.followEdge,
    );

    expect(geometry.anchor, const Offset(400, 540));
    expect(geometry.reflectedCorner, const Offset(210, 540));
    expect(geometry.foldNormal.dy, closeTo(0, 0.001));
    expect(geometry.foldStart.dx, closeTo(geometry.foldEnd.dx, 0.001));
    expect(geometry.foldStart.dy, closeTo(0, 0.001));
    expect(geometry.foldEnd.dy, closeTo(size.height, 0.001));
  });

  test('classic fold follows diagonal finger movement without corner snapping',
      () {
    final geometry = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      pointer: const Offset(210, 470),
      dragOrigin: const Offset(398, 540),
      anchorMode: ReaderPageTurnAnchorMode.followEdge,
    );

    expect(geometry.anchor.dy, 540);
    expect(geometry.reflectedCorner.dx, closeTo(210, 0.001));
    expect(geometry.reflectedCorner.dy, closeTo(470, 0.001));
    expect(geometry.foldNormal.dy, greaterThan(0));
    expect(geometry.foldNormal.dy, lessThan(geometry.foldNormal.dx));
  });

  test('crease keeps the full binding edge on the unlifted half-plane', () {
    final geometry = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      pointer: const Offset(-200, 100),
      dragOrigin: const Offset(400, 700),
      anchorMode: ReaderPageTurnAnchorMode.followEdge,
    );

    for (final bindingPoint in const [Offset.zero, Offset(0, 800)]) {
      final delta = bindingPoint - geometry.canonicalFoldPoint;
      final signedDistance = delta.dx * geometry.canonicalFoldNormal.dx +
          delta.dy * geometry.canonicalFoldNormal.dy;
      expect(signedDistance, lessThanOrEqualTo(0.001));
    }
    expect(geometry.canonicalFoldStart.dx, greaterThanOrEqualTo(0));
    expect(geometry.canonicalFoldEnd.dx, greaterThanOrEqualTo(0));
  });

  test('progress increases monotonically as the finger moves across the page',
      () {
    final nearEdge = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      pointer: const Offset(360, 700),
      dragOrigin: const Offset(398, 760),
    );
    final middle = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      pointer: const Offset(220, 650),
      dragOrigin: const Offset(398, 760),
    );
    final pastSpine = ReaderPageTurnGeometry.fromPointer(
      size: size,
      direction: ReaderPageTurnDirection.forward,
      pointer: const Offset(-40, 600),
      dragOrigin: const Offset(398, 760),
    );

    expect(nearEdge.progress, lessThan(middle.progress));
    expect(middle.progress, lessThan(pastSpine.progress));
  });
}

bool _isOnBoundary(Offset point, Size size) {
  const epsilon = 0.01;
  return point.dx.abs() < epsilon ||
      (point.dx - size.width).abs() < epsilon ||
      point.dy.abs() < epsilon ||
      (point.dy - size.height).abs() < epsilon;
}

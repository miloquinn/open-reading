part of '../../reader_shader_page_curl.dart';

class _ReaderClassicFoldPainter extends CustomPainter {
  const _ReaderClassicFoldPainter({
    required this.shader,
    required this.sourcePage,
    required this.geometry,
    required this.bindingEdge,
    required this.bindingOverflow,
  });

  final ui.FragmentShader shader;
  final ui.Image sourcePage;
  final ReaderPageTurnGeometry geometry;
  final ReaderPageBindingEdge bindingEdge;
  final double bindingOverflow;

  @override
  void paint(Canvas canvas, Size size) {
    var index = 0;
    shader
      ..setFloat(index++, size.width)
      ..setFloat(index++, size.height)
      ..setFloat(index++, geometry.canonicalLineA.dx)
      ..setFloat(index++, geometry.canonicalLineA.dy)
      ..setFloat(index++, geometry.canonicalLineB.dx)
      ..setFloat(index++, geometry.canonicalLineB.dy)
      ..setFloat(
        index++,
        bindingEdge == ReaderPageBindingEdge.right ? 1 : 0,
      )
      ..setImageSampler(0, sourcePage);
    final paintBounds = bindingEdge == ReaderPageBindingEdge.left
        ? Rect.fromLTRB(-bindingOverflow, 0, size.width, size.height)
        : Rect.fromLTRB(0, 0, size.width + bindingOverflow, size.height);
    canvas.drawRect(paintBounds, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _ReaderClassicFoldPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.bindingEdge != bindingEdge ||
      oldDelegate.bindingOverflow != bindingOverflow ||
      !identical(oldDelegate.sourcePage, sourcePage);
}

class _ReaderFallbackTurnPainter extends CustomPainter {
  const _ReaderFallbackTurnPainter({
    required this.sourcePage,
    required this.geometry,
    required this.bindingOverflow,
  });

  final ui.Image sourcePage;
  final ReaderPageTurnGeometry geometry;
  final double bindingOverflow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final turnExtent = bindingOverflow > 0 ? bindingOverflow : size.width;
    final canonicalOffset = switch (geometry.motion) {
      ReaderPageTurnMotion.outgoing => -turnExtent * geometry.progress,
      ReaderPageTurnMotion.incoming => -turnExtent * (1 - geometry.progress),
    };
    final offset = geometry.bindingOnRight ? -canonicalOffset : canonicalOffset;
    canvas.translate(offset, 0);
    _drawPageImage(canvas, sourcePage, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReaderFallbackTurnPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.bindingOverflow != bindingOverflow ||
      !identical(oldDelegate.sourcePage, sourcePage);
}

void _drawPageImage(Canvas canvas, ui.Image image, Size size) {
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.medium,
  );
}

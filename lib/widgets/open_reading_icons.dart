import 'package:flutter/material.dart';

abstract final class OpenReadingIconAssets {
  static const currentReadingSvg =
      'assets/icons/open_reading_current_reading.svg';
  static const currentReadingPng =
      'assets/icons/open_reading_current_reading.png';
}

class OpenReadingCurrentIcon extends StatelessWidget {
  const OpenReadingCurrentIcon({
    super.key,
    required this.color,
    this.size = 24,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Open Reading current reading position',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _OpenReadingCurrentIconPainter(color),
        ),
      ),
    );
  }
}

class _OpenReadingCurrentIconPainter extends CustomPainter {
  const _OpenReadingCurrentIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 24;
    final scaleY = size.height / 24;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final leftPage = Path()
      ..moveTo(2.75, 6.35)
      ..cubicTo(6.33, 5.93, 9.33, 7.08, 11.36, 10.23)
      ..cubicTo(10.34, 11.01, 9.63, 12.19, 9.22, 13.80)
      ..cubicTo(7.09, 13.08, 4.93, 13.08, 2.75, 13.74)
      ..close();
    canvas.drawPath(leftPage, paint);

    final rightPage = Path()
      ..moveTo(21.25, 6.35)
      ..cubicTo(17.67, 5.93, 14.67, 7.08, 12.64, 10.23)
      ..cubicTo(13.66, 11.01, 14.37, 12.19, 14.78, 13.80)
      ..cubicTo(16.91, 13.08, 19.07, 13.08, 21.25, 13.74)
      ..close();
    canvas.drawPath(rightPage, paint);

    canvas.drawCircle(const Offset(12, 14.42), 1.42, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OpenReadingCurrentIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

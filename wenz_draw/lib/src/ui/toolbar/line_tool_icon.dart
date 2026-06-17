import 'package:flutter/material.dart';

class LineToolIcon extends StatelessWidget {
  const LineToolIcon({required this.polyline});

  final bool polyline;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 18),
      painter: LineToolPainter(polyline),
    );
  }
}

class LineToolPainter extends CustomPainter {
  const LineToolPainter(this.polyline);

  final bool polyline;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5F6E7D)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final points = polyline
        ? [
            Offset(size.width * 0.12, size.height * 0.78),
            Offset(size.width * 0.44, size.height * 0.28),
            Offset(size.width * 0.88, size.height * 0.62),
          ]
        : [
            Offset(size.width * 0.14, size.height * 0.78),
            Offset(size.width * 0.86, size.height * 0.22),
          ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
    for (final point in points) {
      canvas.drawCircle(point, 2, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }
  }

  @override
  bool shouldRepaint(covariant LineToolPainter oldDelegate) {
    return oldDelegate.polyline != polyline;
  }
}

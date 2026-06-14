import 'package:flutter/material.dart';

class SpectrumIcon extends StatelessWidget {
  const SpectrumIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: SpectrumPainter());
  }
}

class SpectrumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2;
    final sweep = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFF3B30),
          Color(0xFFFFCC00),
          Color(0xFF34C759),
          Color(0xFF00C7BE),
          Color(0xFF007AFF),
          Color(0xFFAF52DE),
          Color(0xFFFF2D55),
          Color(0xFFFF3B30),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, sweep);
    final light = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.92),
          Colors.white.withValues(alpha: 0.18),
          Colors.black.withValues(alpha: 0.2),
        ],
        stops: const [0, 0.48, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius, light);
    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x3318232E),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

class RgbSpectrumPainter extends CustomPainter {
  const RgbSpectrumPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF9CA3AF),
    );
  }

  @override
  bool shouldRepaint(covariant RgbSpectrumPainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

class SpectrumThumbPainter extends CustomPainter {
  const SpectrumThumbPainter({required this.x, required this.y});

  final double x;
  final double y;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(x * size.width, y * size.height);
    canvas
      ..drawCircle(
        center,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      )
      ..drawCircle(
        center,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black,
      );
  }

  @override
  bool shouldRepaint(covariant SpectrumThumbPainter oldDelegate) {
    return oldDelegate.x != x || oldDelegate.y != y;
  }
}

class HueBarPainter extends CustomPainter {
  const HueBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Colors.red,
            Colors.yellow,
            Colors.green,
            Colors.cyan,
            Colors.blue,
            Colors.purple,
            Colors.red,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF9CA3AF),
    );
  }

  @override
  bool shouldRepaint(covariant HueBarPainter oldDelegate) => false;
}

class HueThumbPainter extends CustomPainter {
  const HueThumbPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final x = hue / 360 * size.width;
    final rect = Rect.fromCenter(
      center: Offset(x, size.height / 2),
      width: 6,
      height: size.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant HueThumbPainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

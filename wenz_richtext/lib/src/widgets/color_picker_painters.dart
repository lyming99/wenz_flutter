import 'package:flutter/material.dart';

/// Paints the saturation/value spectrum for a single HSV [hue].
class WenzRgbSpectrumPainter extends CustomPainter {
  const WenzRgbSpectrumPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas
      ..drawRect(
        bounds,
        Paint()
          ..shader = LinearGradient(
            colors: <Color>[Colors.white, hueColor],
          ).createShader(bounds),
      )
      ..drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Colors.transparent, Colors.black],
          ).createShader(bounds),
      )
      ..drawRect(
        bounds,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF9CA3AF),
      );
  }

  @override
  bool shouldRepaint(covariant WenzRgbSpectrumPainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

/// Paints the current selection on a saturation/value spectrum.
class WenzSpectrumThumbPainter extends CustomPainter {
  const WenzSpectrumThumbPainter({required this.x, required this.y});

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
  bool shouldRepaint(covariant WenzSpectrumThumbPainter oldDelegate) {
    return oldDelegate.x != x || oldDelegate.y != y;
  }
}

/// Paints a complete HSV hue gradient.
class WenzHueBarPainter extends CustomPainter {
  const WenzHueBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas
      ..drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            colors: <Color>[
              Colors.red,
              Colors.yellow,
              Colors.green,
              Colors.cyan,
              Colors.blue,
              Colors.purple,
              Colors.red,
            ],
          ).createShader(bounds),
      )
      ..drawRect(
        bounds,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF9CA3AF),
      );
  }

  @override
  bool shouldRepaint(covariant WenzHueBarPainter oldDelegate) => false;
}

/// Paints the current selection on a hue bar.
class WenzHueThumbPainter extends CustomPainter {
  const WenzHueThumbPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final x = hue / 360 * size.width;
    final rect = Rect.fromCenter(
      center: Offset(x, size.height / 2),
      width: 6,
      height: size.height + 6,
    );
    final thumb = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    canvas
      ..drawRRect(
        thumb,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      )
      ..drawRRect(
        thumb,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(covariant WenzHueThumbPainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

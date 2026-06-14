import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

class ShapePreviewIcon extends StatelessWidget {
  const ShapePreviewIcon({required this.shapeKey});

  final String shapeKey;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(42, 30),
      painter: ShapePreviewPainter(shapeKey),
    );
  }
}

class ShapePreviewPainter extends CustomPainter {
  const ShapePreviewPainter(this.shapeKey);

  final String shapeKey;

  @override
  void paint(Canvas canvas, Size size) {
    ensureDrawioShapeDefinitionsRegistered();
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final element = DrawioShapeElement(
      id: 'preview',
      shapeKey: shapeKey,
      rect: rect,
      strokeStyle: const PaintStyle(color: Color(0xFF425264), strokeWidth: 1.6),
      fillStyle: const PaintStyle(color: Color(0xFFFFFFFF), strokeWidth: 0),
    );
    ElementRendererRegistry.render(canvas, element);
  }

  @override
  bool shouldRepaint(covariant ShapePreviewPainter oldDelegate) {
    return oldDelegate.shapeKey != shapeKey;
  }
}

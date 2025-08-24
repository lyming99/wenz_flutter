import 'package:flutter/material.dart';

import '../mindmap.dart';

class LinePathPainter extends CustomPainter {
  List<LinePath> linePaths;

  LinePathPainter({
    required this.linePaths,
  });

  @override
  bool shouldRepaint(covariant LinePathPainter oldDelegate) {
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    var viewRect = Rect.fromPoints(
      const Offset(0, 0),
      Offset(size.width, size.height),
    );
    var paint = Paint();
    for (var linePath in linePaths) {
      var pathRect = Rect.fromPoints(
        Offset(linePath.start.dx, linePath.start.dy),
        Offset(linePath.end.dx, linePath.end.dy),
      );
      if (!pathRect.overlaps(viewRect)) {
        continue;
      }
      paint.color = linePath.color;
      paint.strokeWidth = 2*linePath.scale;
      paint.style = PaintingStyle.stroke;
      if (linePath.isDragging) {
        paint.color = paint.color.withOpacity(0.4);
      }
      canvas.drawPath(linePath.path, paint);
    }
  }
}

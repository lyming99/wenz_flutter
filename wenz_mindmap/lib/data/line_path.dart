import 'package:flutter/material.dart';
import 'index.dart';

class LinePath {
  Color color;
  Offset start;
  Offset end;
  bool isDragging = false;
  MindNode? node;
  double scale;

  LinePath({
    this.color = Colors.blue,
    this.start = Offset.zero,
    this.end = Offset.zero,
    this.node,
    required this.scale,
  });

  Path get path {
    return Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(start.dx + (4 + 8) * scale, start.dy)
      ..cubicTo((start.dx + end.dx) / 2, start.dy, (start.dx + end.dx) / 2,
          end.dy, end.dx, end.dy)
      ..lineTo(end.dx + 4 * scale, end.dy);
  }
}

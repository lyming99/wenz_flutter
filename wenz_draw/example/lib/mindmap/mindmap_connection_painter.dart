import 'package:flutter/material.dart';

import 'mindmap_layout.dart';

/// Paints connection lines using a trunk-merge-branch pattern:
///
/// ```
/// parent ──► merge ● ──┬──► child1
///                      └──► child2
///                      └──► child3
/// ```
///
/// - Parent → merge point: cubic bezier
/// - Merge → each child: cubic bezier
/// - When collapsed, only parent → merge point is drawn (no branches).
class MindmapConnectionPainter extends CustomPainter {
  MindmapConnectionPainter({
    required this.root,
    required this.color,
    this.strokeWidth = 2.0,
    this.mergePoints = const [],
  });

  final MindmapLayoutNode root;
  final Color color;
  final double strokeWidth;
  final List<MindmapMergePoint> mergePoints;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final mp in mergePoints) {
      // 1. Parent → merge point (trunk)
      _drawBezier(canvas, paint, mp.parentEdge, mp.position);

      if (!mp.isCollapsed) {
        // 2. Merge point → each child (branches)
        for (final childEdge in mp.childEdges) {
          _drawBezier(canvas, paint, mp.position, childEdge);
        }
      }
    }
  }

  /// Draw a smooth cubic bezier between [from] and [to].
  /// Control points are pushed horizontally for an S-curve effect.
  void _drawBezier(
    Canvas canvas,
    Paint paint,
    Offset from,
    Offset to,
  ) {
    final dx = (to.dx - from.dx).abs();
    // Control point offset: at least 10px, otherwise proportional
    final cpOffset = (dx * 0.5).clamp(10.0, 80.0);
    final sign = to.dx >= from.dx ? 1.0 : -1.0;

    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(
        from.dx + cpOffset * sign, from.dy,
        to.dx - cpOffset * sign, to.dy,
        to.dx, to.dy,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MindmapConnectionPainter oldDelegate) {
    return oldDelegate.root != root ||
        oldDelegate.color != color ||
        oldDelegate.mergePoints != mergePoints;
  }
}

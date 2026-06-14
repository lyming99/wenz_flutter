import 'package:flutter/material.dart';

import 'mindmap_layout_engine.dart';

/// Paints mind map connection lines for the non-component mode.
///
/// Same trunk-merge-branch visual as the old [MindmapConnectionPainter], but
/// the input is a flat list of [MindmapMergePoint]s computed by
/// [MindmapLayoutEngine] from rebuilt trees — these are already in world
/// coordinates. The painter draws relative to its own canvas origin, so the
/// hosting layer must translate the canvas (or use a Positioned widget) so
/// that world `(0,0)` maps to the layer's `(0,0)`.
///
/// ```
/// parent ──► merge ● ──┬──► child1
///                      └──► child2
/// ```
class MindmapConnectionPainterV2 extends CustomPainter {
  MindmapConnectionPainterV2({
    required this.mergePoints,
    required this.viewportOffset,
    required this.scale,
    this.color = const Color(0xFF94A3B8),
    this.strokeWidth = 2.5,
  });

  /// Merge points (world coordinates) to draw.
  final List<MindmapMergePoint> mergePoints;

  /// Screen-space offset (= canvas transform.offset).
  final Offset viewportOffset;

  /// Canvas zoom factor. The canvas is translated by [viewportOffset] then
  /// scaled by this factor, so world coordinates map to screen as:
  /// `screen = world * scale + offset`.
  final double scale;

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Apply the same transform the canvas uses: world→screen.
    canvas
      ..translate(viewportOffset.dx, viewportOffset.dy)
      ..scale(scale);

    for (final mp in mergePoints) {
      _drawBezier(canvas, paint, mp.parentEdge, mp.position);
      if (!mp.isCollapsed) {
        for (final childEdge in mp.childEdges) {
          _drawBezier(canvas, paint, mp.position, childEdge);
        }
      }
    }
  }

  void _drawBezier(Canvas canvas, Paint paint, Offset from, Offset to) {
    final dx = to.dx - from.dx;
    final absDx = dx.abs();
    // Control-point horizontal offset: proportional to the horizontal span,
    // pushed in the direction from→to so the curve works on both sides.
    final cpOffset = (absDx * 0.5).clamp(10.0, 80.0);
    final dir = dx >= 0 ? 1.0 : -1.0;
    final cp1 = Offset(from.dx + dir * cpOffset, from.dy);
    final cp2 = Offset(to.dx - dir * cpOffset, to.dy);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, to.dx, to.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MindmapConnectionPainterV2 oldDelegate) {
    return oldDelegate.mergePoints != mergePoints ||
        oldDelegate.viewportOffset != viewportOffset ||
        oldDelegate.scale != scale ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

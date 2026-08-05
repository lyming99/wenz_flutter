import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/style.dart';
import 'mermaid_painter.dart';

/// Painter for Mermaid mindmap diagrams.
class MindmapPainter extends MermaidPainter {
  /// Creates a mindmap painter.
  const MindmapPainter({
    required super.diagram,
    required super.style,
    this.deviceConfig,
  });

  /// Responsive device configuration.
  final MermaidDeviceConfig? deviceConfig;

  @override
  void paint(Canvas canvas, Size size) {
    if (diagram.nodes.isEmpty) return;

    for (final edge in diagram.edges) {
      _drawEdge(canvas, edge);
    }

    for (final node in diagram.nodes) {
      _drawNode(canvas, node);
    }
  }

  void _drawEdge(Canvas canvas, MermaidEdge edge) {
    final fromNode = diagram.getNode(edge.from);
    final toNode = diagram.getNode(edge.to);
    if (fromNode == null || toNode == null) return;

    final start = _connectionPoint(fromNode, toNode);
    final end = _connectionPoint(toNode, fromNode);

    final paint = createEdgePaint(edge);
    final minStroke = deviceConfig?.deviceType == DeviceType.mobile ? 1.4 : 1.8;
    if (paint.strokeWidth < minStroke) {
      paint.strokeWidth = minStroke;
    }

    final deltaX = end.dx - start.dx;
    final sign = deltaX == 0 ? 1.0 : deltaX.sign.toDouble();
    final controlOffset = math.max(deltaX.abs() * 0.45, 28.0);
    final control1 = Offset(start.dx + controlOffset * sign, start.dy);
    final control2 = Offset(end.dx - controlOffset * sign, end.dy);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        end.dx,
        end.dy,
      );

    drawPathLine(canvas, path, paint, edge.lineType);

    if (edge.arrowType != ArrowType.none) {
      final angle = math.atan2(end.dy - control2.dy, end.dx - control2.dx);
      drawArrowHead(canvas, end, angle, edge.arrowType, paint);
    }
  }

  Offset _connectionPoint(MermaidNode fromNode, MermaidNode toNode) {
    final fromRect = nodeRect(fromNode);
    final fromCenter = fromRect.center;
    final toCenter = nodeCenter(toNode);

    if (toCenter.dx >= fromCenter.dx) {
      return Offset(fromRect.right, fromCenter.dy);
    }
    return Offset(fromRect.left, fromCenter.dy);
  }

  void _drawNode(Canvas canvas, MermaidNode node) {
    final rect = nodeRect(node);
    final center = rect.center;
    final nodeStyle = style.getNodeStyle(node.className);

    final fillPaint = Paint()
      ..color = Color(nodeStyle.fillColor ?? MermaidColors.defaultNodeFill)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Color(nodeStyle.strokeColor ?? MermaidColors.defaultNodeStroke)
      ..style = PaintingStyle.stroke
      ..strokeWidth = nodeStyle.strokeWidth + (node.rank == 0 ? 0.4 : 0.0);

    switch (node.shape) {
      case NodeShape.circle:
        final radius = math.min(rect.width, rect.height) / 2;
        canvas.drawCircle(center, radius, fillPaint);
        canvas.drawCircle(center, radius, strokePaint);
        break;
      case NodeShape.doubleCircle:
        final radius = math.min(rect.width, rect.height) / 2;
        canvas.drawCircle(center, radius, fillPaint);
        canvas.drawCircle(center, radius, strokePaint);
        canvas.drawCircle(center, math.max(radius - 5, 0), strokePaint);
        break;
      case NodeShape.hexagon:
        final inset = rect.width * 0.16;
        final path = Path()
          ..moveTo(rect.left + inset, rect.top)
          ..lineTo(rect.right - inset, rect.top)
          ..lineTo(rect.right, center.dy)
          ..lineTo(rect.right - inset, rect.bottom)
          ..lineTo(rect.left + inset, rect.bottom)
          ..lineTo(rect.left, center.dy)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;
      case NodeShape.roundedRect:
        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.min(rect.height / 2, 18)),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);
        break;
      default:
        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(node.rank == 0 ? 14 : 10),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);
        break;
    }

    final textStyle = TextStyle(
      color: Color(nodeStyle.textColor ?? MermaidColors.defaultTextColor),
      fontSize: nodeStyle.fontSize,
      fontWeight: nodeStyle.fontWeight ??
          (node.rank == 0 ? FontWeight.w600 : FontWeight.w500),
      fontFamily: style.fontFamily,
      height: 1.2,
    );

    drawText(
      canvas,
      node.label,
      center,
      textStyle,
      maxWidth: math.max(rect.width - _textInset(node.shape), 32),
    );
  }

  double _textInset(NodeShape shape) {
    switch (shape) {
      case NodeShape.circle:
      case NodeShape.doubleCircle:
        return 26.0;
      case NodeShape.hexagon:
        return 34.0;
      default:
        return 20.0;
    }
  }
}

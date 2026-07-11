import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/style.dart';

/// Base class for Mermaid diagram painters
abstract class MermaidPainter extends CustomPainter {
  /// Creates a Mermaid painter
  const MermaidPainter({
    required this.diagram,
    required this.style,
  });

  /// The diagram data to render
  final MermaidDiagramData diagram;

  /// Style configuration
  final MermaidStyle style;

  @override
  bool shouldRepaint(covariant MermaidPainter oldDelegate) {
    return diagram != oldDelegate.diagram || style != oldDelegate.style;
  }

  /// Builds and lays out a [TextPainter].
  TextPainter buildTextPainter(
    String text,
    TextStyle textStyle, {
    TextAlign align = TextAlign.center,
    double? maxWidth,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
    textPainter.layout(maxWidth: maxWidth ?? double.infinity);
    return textPainter;
  }

  /// Measures text using Flutter text layout.
  Size measureText(
    String text,
    TextStyle textStyle, {
    TextAlign align = TextAlign.center,
    double? maxWidth,
  }) {
    return buildTextPainter(
      text,
      textStyle,
      align: align,
      maxWidth: maxWidth,
    ).size;
  }

  /// Rectangle occupied by a node.
  Rect nodeRect(MermaidNode node) {
    return Rect.fromLTWH(node.x, node.y, node.width, node.height);
  }

  /// Center point of a node.
  Offset nodeCenter(MermaidNode node) {
    return Offset(node.x + node.width / 2, node.y + node.height / 2);
  }

  /// Draws an arrow head at the given position and angle
  void drawArrowHead(
    Canvas canvas,
    Offset position,
    double angle,
    ArrowType type,
    Paint paint,
  ) {
    const arrowSize = 10.0;

    switch (type) {
      case ArrowType.arrow:
        final path = Path();
        path.moveTo(position.dx, position.dy);
        path.lineTo(
          position.dx - arrowSize * math.cos(angle - 0.4),
          position.dy - arrowSize * math.sin(angle - 0.4),
        );
        path.moveTo(position.dx, position.dy);
        path.lineTo(
          position.dx - arrowSize * math.cos(angle + 0.4),
          position.dy - arrowSize * math.sin(angle + 0.4),
        );
        canvas.drawPath(path, paint);
        break;

      case ArrowType.circle:
        canvas.drawCircle(
          Offset(
            position.dx - 5 * math.cos(angle),
            position.dy - 5 * math.sin(angle),
          ),
          5,
          paint..style = PaintingStyle.stroke,
        );
        break;

      case ArrowType.cross:
        const crossSize = 8.0;
        final centerX = position.dx - crossSize * math.cos(angle);
        final centerY = position.dy - crossSize * math.sin(angle);
        canvas.drawLine(
          Offset(centerX - crossSize / 2, centerY - crossSize / 2),
          Offset(centerX + crossSize / 2, centerY + crossSize / 2),
          paint,
        );
        canvas.drawLine(
          Offset(centerX + crossSize / 2, centerY - crossSize / 2),
          Offset(centerX - crossSize / 2, centerY + crossSize / 2),
          paint,
        );
        break;

      case ArrowType.none:
      case ArrowType.doubleArrow:
        break;
    }
  }

  /// Draws text with optional background
  void drawText(
    Canvas canvas,
    String text,
    Offset position,
    TextStyle textStyle, {
    TextAlign align = TextAlign.center,
    Color? backgroundColor,
    double? maxWidth,
  }) {
    final textPainter = buildTextPainter(
      text,
      textStyle,
      align: align,
      maxWidth: maxWidth,
    );

    if (backgroundColor != null) {
      final bgRect = Rect.fromCenter(
        center: position,
        width: textPainter.width + 8,
        height: textPainter.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(3)),
        Paint()..color = backgroundColor,
      );
    }

    final offset = Offset(
      position.dx - textPainter.width / 2,
      position.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, offset);
  }

  /// Creates a Paint from edge style
  Paint createEdgePaint(MermaidEdge edge) {
    final edgeStyle = edge.style ?? style.defaultEdgeStyle;
    return Paint()
      ..color = Color(edgeStyle.strokeColor ?? MermaidColors.defaultEdgeColor)
      ..strokeWidth = edgeStyle.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  /// Draws a path using Mermaid line style.
  void drawPathLine(
    Canvas canvas,
    Path path,
    Paint paint,
    LineType lineType,
  ) {
    if (lineType == LineType.dotted) {
      _drawDashedPath(canvas, path, paint, 5.0, 5.0);
      return;
    }

    if (lineType == LineType.thick) {
      final thickPaint = Paint()
        ..color = paint.color
        ..strokeWidth = paint.strokeWidth * 2
        ..style = paint.style
        ..strokeCap = paint.strokeCap
        ..strokeJoin = paint.strokeJoin;
      canvas.drawPath(path, thickPaint);
      return;
    }

    canvas.drawPath(path, paint);
  }

  /// Draws a line with optional dash pattern
  void drawLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    LineType lineType,
  ) {
    if (lineType == LineType.dotted) {
      _drawDashedLine(canvas, start, end, paint, [5, 5]);
    } else if (lineType == LineType.thick) {
      final thickPaint = Paint()
        ..color = paint.color
        ..strokeWidth = paint.strokeWidth * 2
        ..style = paint.style
        ..strokeCap = paint.strokeCap
        ..strokeJoin = paint.strokeJoin;
      canvas.drawLine(start, end, thickPaint);
    } else {
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    List<double> dashPattern,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) return;

    final unitDx = dx / length;
    final unitDy = dy / length;

    var currentLength = 0.0;
    var drawSegment = true;
    var patternIndex = 0;

    while (currentLength < length) {
      final segmentLength =
          math.min(dashPattern[patternIndex], length - currentLength);

      if (drawSegment) {
        final segmentStart = Offset(
          start.dx + unitDx * currentLength,
          start.dy + unitDy * currentLength,
        );
        final segmentEnd = Offset(
          start.dx + unitDx * (currentLength + segmentLength),
          start.dy + unitDy * (currentLength + segmentLength),
        );
        canvas.drawLine(segmentStart, segmentEnd, paint);
      }

      currentLength += segmentLength;
      drawSegment = !drawSegment;
      patternIndex = (patternIndex + 1) % dashPattern.length;
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dashLength,
    double gapLength,
  ) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gapLength;
      }
    }
  }
}
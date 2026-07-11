/// Painter for Radar charts
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/radar.dart';
import '../models/style.dart';
import 'color_utils.dart';

/// Painter for Radar charts
class RadarPainter extends CustomPainter {
  /// Creates a radar painter
  const RadarPainter({
    required this.radarData,
    required this.style,
    this.deviceConfig,
  });

  /// The Radar data to render
  final RadarChartData radarData;

  /// Style configuration
  final MermaidStyle style;

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  @override
  void paint(Canvas canvas, Size size) {
    if (radarData.axes.isEmpty || radarData.curves.isEmpty) return;

    final isMobile = deviceConfig?.deviceType == DeviceType.mobile;
    final padding = style.padding;

    var currentY = padding;

    // Draw title
    if (radarData.title != null) {
      _drawTitle(canvas, radarData.title!, size.width / 2, currentY);
      currentY += isMobile ? 40.0 : 50.0;
    }

    // Calculate chart area
    final chartSize = math.min(
      size.width - padding * 2,
      size.height - currentY - padding - (radarData.showLegend ? 60 : 0),
    );
    final center = Offset(
      size.width / 2,
      currentY + chartSize / 2,
    );
    final radius = chartSize / 2 * 0.85; // Leave some margin

    // Draw graticule (background grid)
    _drawGraticule(canvas, center, radius);

    // Draw axes
    _drawAxes(canvas, center, radius);

    // Draw data curves
    for (var i = 0; i < radarData.curves.length; i++) {
      _drawCurve(canvas, center, radius, radarData.curves[i], i);
    }

    // Draw legend
    if (radarData.showLegend && radarData.curves.length > 1) {
      final legendY = currentY + chartSize + 20;
      _drawLegend(canvas, size.width / 2, legendY);
    }
  }

  /// Draws the title
  void _drawTitle(Canvas canvas, String title, double centerX, double y) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          fontSize: (deviceConfig?.fontSize ?? 14.0) + 2,
          fontWeight: FontWeight.bold,
          color: Color(style.defaultNodeStyle.textColor ?? RadarChartColors.textColor),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(centerX - textPainter.width / 2, y),
    );
  }

  /// Draws the graticule (background concentric circles/polygons)
  void _drawGraticule(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(RadarChartColors.graticuleColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final ticks = radarData.ticks;
    final axisCount = radarData.axes.length;

    for (var i = 1; i <= ticks; i++) {
      final r = radius * (i / ticks);

      if (radarData.graticule == RadarGraticule.circle) {
        // Draw circle
        canvas.drawCircle(center, r, paint);
      } else {
        // Draw polygon
        final path = Path();
        for (var j = 0; j < axisCount; j++) {
          final angle = _getAngleForAxis(j);
          final x = center.dx + r * math.cos(angle);
          final y = center.dy + r * math.sin(angle);

          if (j == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  /// Draws the axes and labels
  void _drawAxes(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(RadarChartColors.axisColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fontSize = deviceConfig?.fontSize ?? 12.0;

    for (var i = 0; i < radarData.axes.length; i++) {
      final axis = radarData.axes[i];
      final angle = _getAngleForAxis(i);

      // Draw axis line
      final endX = center.dx + radius * math.cos(angle);
      final endY = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(endX, endY), paint);

      // Draw axis label
      final labelDistance = radius + 20;
      final labelX = center.dx + labelDistance * math.cos(angle);
      final labelY = center.dy + labelDistance * math.sin(angle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: axis.label,
          style: TextStyle(
            fontSize: fontSize,
            color: const Color(RadarChartColors.textColor),
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();

      // Adjust label position based on angle
      var offsetX = labelX - textPainter.width / 2;
      var offsetY = labelY - textPainter.height / 2;

      // Fine-tune positioning for better readability
      if (angle.abs() < math.pi / 4) {
        // Top
        offsetY = labelY - textPainter.height - 5;
      } else if (angle.abs() > 3 * math.pi / 4) {
        // Bottom
        offsetY = labelY + 5;
      } else if (angle > 0) {
        // Right side
        offsetX = labelX + 5;
      } else {
        // Left side
        offsetX = labelX - textPainter.width - 5;
      }

      textPainter.paint(canvas, Offset(offsetX, offsetY));
    }
  }

  /// Draws a data curve
  void _drawCurve(Canvas canvas, Offset center, double radius, RadarCurve curve, int curveIndex) {
    if (curve.values.isEmpty) return;

    final color = Color(RadarChartColors.getColorForCurve(curveIndex));
    final path = Path();
    final points = <Offset>[];

    final max = radarData.effectiveMax;
    final min = radarData.effectiveMin;

    for (var i = 0; i < math.min(curve.values.length, radarData.axes.length); i++) {
      final value = curve.values[i];
      final normalizedValue = (value - min) / (max - min);
      final r = radius * normalizedValue.clamp(0.0, 1.0).toDouble();
      final angle = _getAngleForAxis(i);

      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      final point = Offset(x, y);
      points.add(point);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Draw filled area with transparency
    final fillPaint = Paint()
      ..color = mermaidColorWithOpacity(color, 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Draw stroke
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Draw data points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas
        ..drawCircle(point, 4, pointPaint)
        // Draw white border
        ..drawCircle(
          point,
          4,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }
  }

  /// Draws the legend
  void _drawLegend(Canvas canvas, double centerX, double y) {
    final fontSize = deviceConfig?.fontSize ?? 12.0;
    const itemSpacing = 20.0;

    // Calculate total width needed
    var totalWidth = 0.0;
    final textPainters = <TextPainter>[];

    for (var i = 0; i < radarData.curves.length; i++) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: radarData.curves[i].label,
          style: TextStyle(
            fontSize: fontSize,
            color: const Color(RadarChartColors.textColor),
          ),
        ),
        textDirection: TextDirection.ltr,
      )
        ..layout();
      textPainters.add(textPainter);
      totalWidth += 24 + textPainter.width + itemSpacing;
    }
    totalWidth -= itemSpacing; // Remove last spacing

    var x = centerX - totalWidth / 2;

    for (var i = 0; i < radarData.curves.length; i++) {
      final color = Color(RadarChartColors.getColorForCurve(i));

      // Draw color box
      final boxRect = Rect.fromLTWH(x, y - 6, 16, 12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(2)),
        Paint()..color = color,
      );

      x += 24;

      // Draw label
      textPainters[i].paint(canvas, Offset(x, y - textPainters[i].height / 2));
      x += textPainters[i].width + itemSpacing;
    }
  }

  /// Gets the angle for an axis (in radians)
  /// Starts from top (-π/2) and goes clockwise
  double _getAngleForAxis(int index) {
    final axisCount = radarData.axes.length;
    final angleStep = 2 * math.pi / axisCount;
    return -math.pi / 2 + index * angleStep;
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.radarData != radarData ||
        oldDelegate.style != style ||
        oldDelegate.deviceConfig != deviceConfig;
  }
}

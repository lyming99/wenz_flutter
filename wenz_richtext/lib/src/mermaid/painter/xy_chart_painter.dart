/// Painter for XY Charts
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/style.dart';
import '../models/xy_chart.dart';
import 'color_utils.dart';

/// Painter for XY Charts (bar + line)
class XYChartPainter extends CustomPainter {
  /// Creates an XY chart painter
  const XYChartPainter({
    required this.xyData,
    required this.style,
    this.deviceConfig,
  });

  /// The XY chart data to render
  final XYChartData xyData;

  /// Style configuration
  final MermaidStyle style;

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  @override
  void paint(Canvas canvas, Size size) {
    if (xyData.series.isEmpty) return;

    final padding = style.padding;
    final isMobile = deviceConfig?.deviceType == DeviceType.mobile;
    final fontSize = deviceConfig?.fontSize ?? 12.0;

    // Layout areas
    var currentY = padding;
    const yAxisLabelWidth = 50.0;
    final xAxisLabelHeight = isMobile ? 40.0 : 50.0;

    // Draw title
    if (xyData.title != null) {
      _drawTitle(canvas, xyData.title!, size.width / 2, currentY);
      currentY += isMobile ? 35.0 : 45.0;
    }

    // Chart plot area
    final plotLeft = padding + yAxisLabelWidth;
    final plotRight = size.width - padding;
    final plotTop = currentY;
    final plotBottom = size.height - padding - xAxisLabelHeight;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    if (plotWidth <= 0 || plotHeight <= 0) return;

    final yMin = xyData.effectiveYMin;
    final yMax = xyData.effectiveYMax;
    final yRange = yMax - yMin;
    if (yRange == 0) return;

    final dataCount = xyData.dataPointCount;
    if (dataCount == 0) return;

    // Draw grid lines and Y-axis labels
    _drawYAxis(
        canvas, plotLeft, plotRight, plotTop, plotBottom, yMin, yMax, fontSize);

    // Draw X-axis labels
    _drawXAxis(canvas, plotLeft, plotRight, plotBottom, dataCount, fontSize);

    // Draw axis lines
    final axisPaint = Paint()
      ..color = const Color(XYChartColors.axisColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas
      ..drawLine(
          Offset(plotLeft, plotTop), Offset(plotLeft, plotBottom), axisPaint)
      ..drawLine(Offset(plotLeft, plotBottom), Offset(plotRight, plotBottom),
          axisPaint);

    // Count bar series for grouped bar layout
    final barSeriesCount =
        xyData.series.where((s) => s.type == XYSeriesType.bar).length;
    var barSeriesIndex = 0;

    // Draw each series
    for (var si = 0; si < xyData.series.length; si++) {
      final series = xyData.series[si];
      final color = Color(XYChartColors.getColorForSeries(si));

      if (series.type == XYSeriesType.bar) {
        _drawBarSeries(
          canvas,
          series,
          color,
          plotLeft,
          plotTop,
          plotBottom,
          plotWidth,
          plotHeight,
          dataCount,
          yMin,
          yRange,
          barSeriesIndex,
          barSeriesCount,
        );
        barSeriesIndex++;
      } else {
        _drawLineSeries(
          canvas,
          series,
          color,
          plotLeft,
          plotTop,
          plotBottom,
          plotWidth,
          plotHeight,
          dataCount,
          yMin,
          yRange,
        );
      }
    }
  }

  /// Draws the chart title
  void _drawTitle(Canvas canvas, String title, double centerX, double y) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          fontSize: (deviceConfig?.fontSize ?? 14.0) + 2,
          fontWeight: FontWeight.bold,
          color: const Color(XYChartColors.textColor),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, y));
  }

  /// Draws Y-axis grid lines and labels
  void _drawYAxis(
    Canvas canvas,
    double plotLeft,
    double plotRight,
    double plotTop,
    double plotBottom,
    double yMin,
    double yMax,
    double fontSize,
  ) {
    const tickCount = 5;
    final gridPaint = Paint()
      ..color = const Color(XYChartColors.gridColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final yRange = yMax - yMin;

    for (var i = 0; i <= tickCount; i++) {
      final ratio = i / tickCount;
      final y = plotBottom - (plotBottom - plotTop) * ratio;
      final value = yMin + yRange * ratio;

      // Grid line (horizontal across plot area)
      canvas.drawLine(
        Offset(plotLeft, y),
        Offset(plotLeft - 5, y),
        gridPaint,
      );

      // Draw faint horizontal grid line
      if (i > 0) {
        final faintGridPaint = Paint()
          ..color = const Color(XYChartColors.gridColor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.3;
        canvas.drawLine(
          Offset(plotLeft, y),
          Offset(plotRight, y),
          faintGridPaint,
        );
      }

      // Label
      final label = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: fontSize - 1,
            color: const Color(XYChartColors.textColor),
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(plotLeft - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    // Y-axis title
    if (xyData.yAxisTitle != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: xyData.yAxisTitle!,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: const Color(XYChartColors.textColor),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      final centerY = (plotTop + plotBottom) / 2;
      canvas
        ..translate(style.padding - 5, centerY)
        ..rotate(-math.pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
      canvas.restore();
    }
  }

  /// Draws X-axis labels
  void _drawXAxis(
    Canvas canvas,
    double plotLeft,
    double plotRight,
    double plotBottom,
    int dataCount,
    double fontSize,
  ) {
    final plotWidth = plotRight - plotLeft;

    for (var i = 0; i < dataCount; i++) {
      final x = plotLeft + plotWidth * (i + 0.5) / dataCount;

      final label = xyData.isCategorical && i < xyData.xAxisCategories.length
          ? xyData.xAxisCategories[i]
          : (i + 1).toString();

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: fontSize - 1,
            color: const Color(XYChartColors.textColor),
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, plotBottom + 8),
      );
    }

    // X-axis title
    if (xyData.xAxisTitle != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: xyData.xAxisTitle!,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: const Color(XYChartColors.textColor),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          (plotLeft + plotRight) / 2 - textPainter.width / 2,
          plotBottom + 30,
        ),
      );
    }
  }

  /// Draws a bar series
  void _drawBarSeries(
    Canvas canvas,
    XYChartSeries series,
    Color color,
    double plotLeft,
    double plotTop,
    double plotBottom,
    double plotWidth,
    double plotHeight,
    int dataCount,
    double yMin,
    double yRange,
    int barIndex,
    int totalBars,
  ) {
    final groupWidth = plotWidth / dataCount;
    final barAreaWidth = groupWidth * 0.7;
    final barWidth = totalBars > 1 ? barAreaWidth / totalBars : barAreaWidth;
    final barOffset =
        totalBars > 1 ? -barAreaWidth / 2 + barIndex * barWidth : -barWidth / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = mermaidColorWithOpacity(color, 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 0; i < series.values.length && i < dataCount; i++) {
      final value = series.values[i];
      final normalizedValue = (value - yMin) / yRange;
      final barHeight = plotHeight * normalizedValue.clamp(0.0, 1.0).toDouble();

      final x = plotLeft + groupWidth * (i + 0.5) + barOffset;
      final y = plotBottom - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(2),
      );
      canvas
        ..drawRRect(rect, paint)
        ..drawRRect(rect, borderPaint);
    }
  }

  /// Draws a line series
  void _drawLineSeries(
    Canvas canvas,
    XYChartSeries series,
    Color color,
    double plotLeft,
    double plotTop,
    double plotBottom,
    double plotWidth,
    double plotHeight,
    int dataCount,
    double yMin,
    double yRange,
  ) {
    if (series.values.isEmpty) return;

    final groupWidth = plotWidth / dataCount;
    final path = Path();
    final points = <Offset>[];

    for (var i = 0; i < series.values.length && i < dataCount; i++) {
      final value = series.values[i];
      final normalizedValue = (value - yMin) / yRange;
      final x = plotLeft + groupWidth * (i + 0.5);
      final y =
          plotBottom - plotHeight * normalizedValue.clamp(0.0, 1.0).toDouble();
      final point = Offset(x, y);
      points.add(point);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw line
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Draw data points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final point in points) {
      canvas
        ..drawCircle(point, 4, pointPaint)
        ..drawCircle(point, 4, pointBorderPaint);
    }
  }

  @override
  bool shouldRepaint(XYChartPainter oldDelegate) {
    return oldDelegate.xyData != xyData ||
        oldDelegate.style != style ||
        oldDelegate.deviceConfig != deviceConfig;
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/pie_chart.dart';
import '../models/style.dart';

/// Painter for pie chart diagrams
class PieChartPainter extends CustomPainter {
  /// Creates a pie chart painter
  const PieChartPainter({
    required this.pieData,
    required this.style,
    this.deviceConfig,
  });

  /// The pie chart data to render
  final PieChartData pieData;

  /// Style configuration
  final MermaidStyle style;

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  @override
  void paint(Canvas canvas, Size size) {
    if (pieData.slices.isEmpty) return;

    final padding = style.padding;
    final showLegendBelow = deviceConfig?.showLegendBelow ?? false;
    final minPieRadius = deviceConfig?.pieMinRadius ?? 90.0;
    final legendFontSize = deviceConfig?.legendFontSize ?? 11.0;

    // Title height
    final titleHeight = pieData.title != null ? 40.0 : 0.0;

    // Calculate legend dimensions first
    final legendMetrics = _measureLegend(legendFontSize);
    final legendWidth = legendMetrics.$1;
    final legendHeight = legendMetrics.$2;

    if (showLegendBelow) {
      // Mobile layout: pie on top, legend below
      final pieAreaHeight = size.height - titleHeight - legendHeight - padding * 4;
      final pieRadius = math.max(minPieRadius * 0.6, math.min(size.width - padding * 2, pieAreaHeight) / 2 - 10);

      final pieCenter = Offset(
        size.width / 2,
        titleHeight + padding + pieRadius + 10,
      );

      // Draw title centered
      if (pieData.title != null) {
        _drawTitle(canvas, pieData.title!, size.width / 2);
      }

      // Draw pie slices
      if (pieRadius > 20) {
        _drawPieSlices(canvas, pieCenter, pieRadius);
      }

      // Draw legend centered below the pie
      final legendX = (size.width - legendWidth) / 2;
      final legendY = pieCenter.dy + pieRadius + padding * 2;

      _drawLegend(
        canvas,
        Offset(math.max(legendX, padding), legendY),
        legendWidth,
        legendFontSize,
      );
    } else {
      // Desktop/tablet layout: pie on left, legend on right
      final availableForPie = size.width - legendWidth - padding * 4;
      final pieAreaHeight = size.height - titleHeight - padding * 2;

      // Ensure minimum pie radius
      final pieRadius = math.max(minPieRadius * 0.6, math.min(availableForPie, pieAreaHeight) / 2 - 10);

      // Center the pie in its area
      final pieCenter = Offset(
        padding + pieRadius + 10,
        titleHeight + padding + pieAreaHeight / 2,
      );

      // Draw title if present - centered above the pie
      if (pieData.title != null) {
        _drawTitle(canvas, pieData.title!, pieCenter.dx);
      }

      // Draw pie slices
      if (pieRadius > 20) {
        _drawPieSlices(canvas, pieCenter, pieRadius);
      }

      // Position legend to the right of the pie
      final legendX = pieCenter.dx + pieRadius + padding * 2;
      final legendY = titleHeight + padding + (pieAreaHeight - legendHeight) / 2;

      // Draw legend
      _drawLegend(
        canvas,
        Offset(legendX, math.max(legendY, titleHeight + padding)),
        size.width - legendX - padding,
        legendFontSize,
      );
    }
  }

  /// Measures the legend to get its required dimensions
  (double width, double height) _measureLegend(double fontSize) {
    final itemHeight = fontSize * 2;
    final colorBoxSize = fontSize * 1.1;
    const spacing = 6.0;

    var maxWidth = 0.0;

    for (var i = 0; i < pieData.slices.length; i++) {
      final slice = pieData.slices[i];
      final percentage = pieData.getPercentage(slice);

      var labelText = slice.label;
      if (pieData.showValuesInLegend) {
        labelText += ': ${slice.value.toStringAsFixed(0)}';
      }
      labelText += ' (${percentage.toStringAsFixed(1)}%)';

      // Estimate text width based on font size (roughly 0.6 * fontSize per character)
      final textWidth = labelText.length * fontSize * 0.6;
      final totalWidth = colorBoxSize + spacing + textWidth;

      if (totalWidth > maxWidth) {
        maxWidth = totalWidth;
      }
    }

    final height = pieData.slices.length * itemHeight;
    return (maxWidth + 10, height);
  }

  /// Draws the title centered above the pie chart
  void _drawTitle(Canvas canvas, String title, double pieCenterX) {
    final textStyle = TextStyle(
      color: Color(style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor),
      fontSize: 16.0,
      fontWeight: FontWeight.bold,
      fontFamily: style.fontFamily,
    );

    final textSpan = TextSpan(text: title, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    // Center the title horizontally on the pie center
    final offset = Offset(
      pieCenterX - textPainter.width / 2,
      style.padding,
    );
    textPainter.paint(canvas, offset);
  }

  void _drawPieSlices(Canvas canvas, Offset center, double radius) {
    final total = pieData.totalValue;
    if (total == 0) return;

    var startAngle = -math.pi / 2; // Start from top

    for (var i = 0; i < pieData.slices.length; i++) {
      final slice = pieData.slices[i];
      final sweepAngle = (slice.value / total) * 2 * math.pi;
      final color = slice.color ?? PieChartColors.getColor(i);

      // Draw slice
      final paint = Paint()
        ..color = Color(color)
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);

      // Draw slice border
      final borderPaint = Paint()
        ..color = Color(style.backgroundColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawPath(path, borderPaint);

      // Draw percentage label on slice if it's large enough
      if (sweepAngle > 0.3) { // Only show label if slice is > ~17%
        _drawSliceLabel(canvas, center, radius, startAngle, sweepAngle, slice);
      }

      startAngle += sweepAngle;
    }
  }

  void _drawSliceLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle,
    PieSlice slice,
  ) {
    final percentage = pieData.getPercentage(slice);
    final labelAngle = startAngle + sweepAngle / 2;
    final labelRadius = radius * 0.65;

    final labelX = center.dx + labelRadius * math.cos(labelAngle);
    final labelY = center.dy + labelRadius * math.sin(labelAngle);

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12.0,
      fontWeight: FontWeight.bold,
      fontFamily: style.fontFamily,
      shadows: const [
        Shadow(
          color: Colors.black54,
          blurRadius: 2,
          offset: Offset(1, 1),
        ),
      ],
    );

    final text = '${percentage.toStringAsFixed(1)}%';
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    final offset = Offset(
      labelX - textPainter.width / 2,
      labelY - textPainter.height / 2,
    );
    textPainter.paint(canvas, offset);
  }

  void _drawLegend(Canvas canvas, Offset topLeft, double maxWidth, double fontSize) {
    final itemHeight = fontSize * 2;
    final colorBoxSize = fontSize * 1.1;
    const spacing = 6.0;

    var y = topLeft.dy;

    for (var i = 0; i < pieData.slices.length; i++) {
      final slice = pieData.slices[i];
      final color = slice.color ?? PieChartColors.getColor(i);

      // Draw color box
      final colorRect = Rect.fromLTWH(
        topLeft.dx,
        y + (itemHeight - colorBoxSize) / 2,
        colorBoxSize,
        colorBoxSize,
      );

      final colorPaint = Paint()
        ..color = Color(color)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(colorRect, const Radius.circular(2)),
        colorPaint,
      );

      // Draw border for color box
      final borderPaint = Paint()
        ..color = Color(style.defaultEdgeStyle.strokeColor ?? MermaidColors.defaultEdgeColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(colorRect, const Radius.circular(2)),
        borderPaint,
      );

      // Draw label - single line, no wrap
      final percentage = pieData.getPercentage(slice);
      var labelText = slice.label;

      if (pieData.showValuesInLegend) {
        labelText += ': ${slice.value.toStringAsFixed(0)}';
      }

      labelText += ' (${percentage.toStringAsFixed(1)}%)';

      final textStyle = TextStyle(
        color: Color(style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor),
        fontSize: fontSize,
        fontFamily: style.fontFamily,
      );

      final textSpan = TextSpan(text: labelText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      // Don't limit width to allow single line
      textPainter.layout();

      final textOffset = Offset(
        topLeft.dx + colorBoxSize + spacing,
        y + (itemHeight - textPainter.height) / 2,
      );
      textPainter.paint(canvas, textOffset);

      y += itemHeight;
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return pieData != oldDelegate.pieData || style != oldDelegate.style;
  }
}

/// Layout engine for pie charts
class PieChartLayout {
  /// Creates a pie chart layout
  const PieChartLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Computes the size needed to render the pie chart
  Size computeLayout(PieChartData pieData, MermaidStyle style, Size availableSize) {
    // Get responsive values
    final minPieRadius = deviceConfig?.pieMinRadius ?? 90.0;
    final showLegendBelow = deviceConfig?.showLegendBelow ?? false;
    final legendFontSize = deviceConfig?.legendFontSize ?? 11.0;

    // Calculate legend dimensions
    final legendMetrics = _measureLegend(pieData, legendFontSize);
    final legendWidth = legendMetrics.$1;
    final legendHeight = legendMetrics.$2;

    final titleHeight = pieData.title != null ? 50.0 : 0.0;

    // Minimum pie diameter based on device
    final minPieDiameter = minPieRadius * 2;

    if (showLegendBelow) {
      // Mobile layout: pie on top, legend below
      final minWidth = math.max(minPieDiameter, legendWidth) + style.padding * 2;
      final minHeight = titleHeight + minPieDiameter + legendHeight + style.padding * 4;

      return Size(
        math.max(minWidth, math.min(availableSize.width, 400)),
        math.max(minHeight, math.min(availableSize.height, 500)),
      );
    } else {
      // Desktop/tablet layout: pie on left, legend on right
      final minWidth = minPieDiameter + legendWidth + style.padding * 5;
      final contentHeight = math.max(minPieDiameter, legendHeight);
      final minHeight = titleHeight + contentHeight + style.padding * 3;

      // Use available size but ensure minimums
      final maxWidth = deviceConfig?.deviceType == DeviceType.tablet ? 550.0 : 700.0;
      return Size(
        math.max(minWidth, math.min(availableSize.width, maxWidth)),
        math.max(minHeight, math.min(availableSize.height, 450)),
      );
    }
  }

  /// Measures the legend to get its required dimensions
  (double width, double height) _measureLegend(PieChartData pieData, double fontSize) {
    final itemHeight = fontSize * 2;
    final colorBoxSize = fontSize * 1.1;
    const spacing = 6.0;

    var maxWidth = 0.0;

    for (var i = 0; i < pieData.slices.length; i++) {
      final slice = pieData.slices[i];
      final percentage = (slice.value / pieData.totalValue) * 100;

      var labelText = slice.label;
      if (pieData.showValuesInLegend) {
        labelText += ': ${slice.value.toStringAsFixed(0)}';
      }
      labelText += ' (${percentage.toStringAsFixed(1)}%)';

      // Estimate text width based on font size (roughly 0.6 * fontSize per character)
      final textWidth = labelText.length * fontSize * 0.6;
      final totalWidth = colorBoxSize + spacing + textWidth;

      if (totalWidth > maxWidth) {
        maxWidth = totalWidth;
      }
    }

    final height = pieData.slices.length * itemHeight;
    return (maxWidth + 20, height);
  }
}

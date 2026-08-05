import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/gantt.dart';
import '../models/style.dart';
import 'color_utils.dart';

/// Painter for Gantt chart diagrams
class GanttPainter extends CustomPainter {
  /// Creates a Gantt chart painter
  const GanttPainter({
    required this.ganttData,
    required this.style,
    this.deviceConfig,
  });

  /// The Gantt chart data to render
  final GanttChartData ganttData;

  /// Style configuration
  final MermaidStyle style;

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  @override
  void paint(Canvas canvas, Size size) {
    if (ganttData.tasks.isEmpty) return;

    final padding = style.padding;
    final titleHeight = ganttData.title != null ? 40.0 : 0.0;

    // Layout constants
    final taskRowHeight =
        deviceConfig?.deviceType == DeviceType.mobile ? 28.0 : 32.0;
    final labelWidth = _calculateLabelWidth(size.width);
    const headerHeight = 50.0;
    final timelineWidth = size.width - labelWidth - padding * 2;

    // Calculate date range
    final minDate = ganttData.minDate!;
    final maxDate = ganttData.maxDate!;
    final totalDays = ganttData.totalDays;

    // Draw title if present
    var currentY = padding;
    if (ganttData.title != null) {
      _drawTitle(canvas, ganttData.title!, size.width / 2, currentY);
      currentY += titleHeight;
    }

    // Draw timeline header
    _drawTimelineHeader(
      canvas,
      Offset(labelWidth + padding, currentY),
      timelineWidth,
      headerHeight,
      minDate,
      totalDays,
    );
    currentY += headerHeight;

    // Draw grid and tasks
    _drawGridAndTasks(
      canvas,
      Offset(padding, currentY),
      labelWidth,
      timelineWidth,
      taskRowHeight,
      minDate,
      totalDays,
    );

    // Draw today marker if enabled
    if (ganttData.todayMarker) {
      final today = DateTime.now();
      if (!today.isBefore(minDate) && !today.isAfter(maxDate)) {
        _drawTodayMarker(
          canvas,
          labelWidth + padding,
          currentY,
          timelineWidth,
          taskRowHeight * ganttData.tasks.length,
          minDate,
          today,
          totalDays,
        );
      }
    }
  }

  /// Calculates the width needed for task labels
  double _calculateLabelWidth(double totalWidth) {
    final fontSize = deviceConfig?.fontSize ?? 12.0;
    var maxLabelWidth = 0.0;

    for (final task in ganttData.tasks) {
      final estimatedWidth = task.name.length * fontSize * 0.6;
      if (estimatedWidth > maxLabelWidth) {
        maxLabelWidth = estimatedWidth;
      }
    }

    // Add padding and constrain
    final labelWidth =
        (maxLabelWidth + 20).clamp(100.0, totalWidth * 0.35).toDouble();
    return labelWidth;
  }

  /// Draws the chart title
  void _drawTitle(Canvas canvas, String title, double centerX, double y) {
    final textStyle = TextStyle(
      color: Color(
          style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor),
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

    textPainter.paint(
      canvas,
      Offset(centerX - textPainter.width / 2, y),
    );
  }

  /// Draws the timeline header with date markers
  void _drawTimelineHeader(
    Canvas canvas,
    Offset topLeft,
    double width,
    double height,
    DateTime minDate,
    int totalDays,
  ) {
    final fontSize = deviceConfig?.fontSize ?? 11.0;

    // Draw header background
    final headerPaint = Paint()
      ..color = mermaidColorWithOpacity(Color(style.backgroundColor), 0.9)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, width, height),
      headerPaint,
    );

    // Draw bottom border
    final borderPaint = Paint()
      ..color = const Color(GanttChartColors.gridLineColor)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(topLeft.dx, topLeft.dy + height),
      Offset(topLeft.dx + width, topLeft.dy + height),
      borderPaint,
    );

    // Calculate appropriate time scale
    final dayWidth = width / totalDays;
    final showDays = dayWidth >= 20;
    final showWeeks = dayWidth >= 5 && !showDays;

    if (showDays && totalDays <= 60) {
      // Show individual days
      _drawDayMarkers(canvas, topLeft, width, height, minDate, totalDays,
          dayWidth, fontSize);
    } else if (showWeeks || totalDays <= 120) {
      // Show weeks
      _drawWeekMarkers(canvas, topLeft, width, height, minDate, totalDays,
          dayWidth, fontSize);
    } else {
      // Show months
      _drawMonthMarkers(canvas, topLeft, width, height, minDate, totalDays,
          dayWidth, fontSize);
    }
  }

  /// Draws day markers on the timeline
  void _drawDayMarkers(
    Canvas canvas,
    Offset topLeft,
    double width,
    double height,
    DateTime minDate,
    int totalDays,
    double dayWidth,
    double fontSize,
  ) {
    final textStyle = TextStyle(
      color: Color(
          style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor),
      fontSize: fontSize * 0.9,
      fontFamily: style.fontFamily,
    );

    for (var i = 0; i < totalDays; i++) {
      final date = minDate.add(Duration(days: i));
      final x = topLeft.dx + i * dayWidth;

      // Draw vertical grid line
      final linePaint = Paint()
        ..color = mermaidColorWithOpacity(
          const Color(GanttChartColors.gridLineColor),
          0.5,
        )
        ..strokeWidth = 0.5;

      canvas.drawLine(
        Offset(x, topLeft.dy),
        Offset(x, topLeft.dy + height),
        linePaint,
      );

      // Draw day number
      if (dayWidth >= 25) {
        final dayText = '${date.day}';
        final textSpan = TextSpan(text: dayText, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        textPainter.paint(
          canvas,
          Offset(
              x + (dayWidth - textPainter.width) / 2, topLeft.dy + height - 20),
        );
      }

      // Draw month name at the start of each month
      if (date.day == 1 || i == 0) {
        final monthText = _getMonthName(date.month);
        final monthStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
        final monthSpan = TextSpan(text: monthText, style: monthStyle);
        final monthPainter = TextPainter(
          text: monthSpan,
          textDirection: TextDirection.ltr,
        );
        monthPainter.layout();

        monthPainter.paint(
          canvas,
          Offset(x + 4, topLeft.dy + 4),
        );
      }
    }
  }

  /// Draws week markers on the timeline
  void _drawWeekMarkers(
    Canvas canvas,
    Offset topLeft,
    double width,
    double height,
    DateTime minDate,
    int totalDays,
    double dayWidth,
    double fontSize,
  ) {
    final textStyle = TextStyle(
      color: Color(
          style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor),
      fontSize: fontSize * 0.9,
      fontFamily: style.fontFamily,
    );

    // Find the first Monday
    var currentDate = minDate;
    while (currentDate.weekday != DateTime.monday) {
      currentDate = currentDate.add(const Duration(days: 1));
    }

    while (!currentDate.isAfter(minDate.add(Duration(days: totalDays)))) {
      final daysFromStart = currentDate.difference(minDate).inDays;
      final x = topLeft.dx + daysFromStart * dayWidth;

      if (x >= topLeft.dx && x <= topLeft.dx + width) {
        // Draw week marker line
        final linePaint = Paint()
          ..color = const Color(GanttChartColors.gridLineColor)
          ..strokeWidth = 1.0;

        canvas.drawLine(
          Offset(x, topLeft.dy),
          Offset(x, topLeft.dy + height),
          linePaint,
        );

        // Draw week date
        final weekText = '${currentDate.month}/${currentDate.day}';
        final textSpan = TextSpan(text: weekText, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        textPainter.paint(
          canvas,
          Offset(x + 4, topLeft.dy + height - 18),
        );
      }

      currentDate = currentDate.add(const Duration(days: 7));
    }

    // Draw month names
    var lastMonth = -1;
    for (var i = 0; i < totalDays; i++) {
      final date = minDate.add(Duration(days: i));
      if (date.month != lastMonth) {
        lastMonth = date.month;
        final x = topLeft.dx + i * dayWidth;

        final monthText = '${_getMonthName(date.month)} ${date.year}';
        final monthStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
        final monthSpan = TextSpan(text: monthText, style: monthStyle);
        final monthPainter = TextPainter(
          text: monthSpan,
          textDirection: TextDirection.ltr,
        );
        monthPainter.layout();

        monthPainter.paint(
          canvas,
          Offset(x + 4, topLeft.dy + 4),
        );
      }
    }
  }

  /// Draws month markers on the timeline
  void _drawMonthMarkers(
    Canvas canvas,
    Offset topLeft,
    double width,
    double height,
    DateTime minDate,
    int totalDays,
    double dayWidth,
    double fontSize,
  ) {
    final textStyle = TextStyle(
      color: Color(
          style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor),
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      fontFamily: style.fontFamily,
    );

    var lastMonth = -1;
    for (var i = 0; i < totalDays; i++) {
      final date = minDate.add(Duration(days: i));
      if (date.month != lastMonth || date.day == 1) {
        if (date.month != lastMonth) {
          lastMonth = date.month;
          final x = topLeft.dx + i * dayWidth;

          // Draw month divider line
          final linePaint = Paint()
            ..color = const Color(GanttChartColors.gridLineColor)
            ..strokeWidth = 1.5;

          canvas.drawLine(
            Offset(x, topLeft.dy),
            Offset(x, topLeft.dy + height),
            linePaint,
          );

          // Draw month name
          final monthText = '${_getMonthName(date.month)} ${date.year}';
          final textSpan = TextSpan(text: monthText, style: textStyle);
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();

          textPainter.paint(
            canvas,
            Offset(x + 4, topLeft.dy + (height - textPainter.height) / 2),
          );
        }
      }
    }
  }

  /// Draws the task grid and task bars
  void _drawGridAndTasks(
    Canvas canvas,
    Offset topLeft,
    double labelWidth,
    double timelineWidth,
    double taskRowHeight,
    DateTime minDate,
    int totalDays,
  ) {
    final fontSize = deviceConfig?.fontSize ?? 12.0;
    final dayWidth = timelineWidth / totalDays;

    // Group tasks by section for alternating backgrounds
    var currentSection = '';
    var sectionIndex = 0;

    for (var i = 0; i < ganttData.tasks.length; i++) {
      final task = ganttData.tasks[i];
      final y = topLeft.dy + i * taskRowHeight;

      // Check for section change
      if (task.section != null && task.section != currentSection) {
        currentSection = task.section!;
        sectionIndex++;
      }

      // Draw row background (alternating by section)
      final bgColor = GanttChartColors.sectionColors[sectionIndex % 2];
      final bgPaint = Paint()
        ..color = Color(bgColor)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(topLeft.dx, y, labelWidth + timelineWidth, taskRowHeight),
        bgPaint,
      );

      // Draw horizontal grid line
      final gridPaint = Paint()
        ..color = const Color(GanttChartColors.gridLineColor)
        ..strokeWidth = 0.5;

      canvas.drawLine(
        Offset(topLeft.dx, y + taskRowHeight),
        Offset(topLeft.dx + labelWidth + timelineWidth, y + taskRowHeight),
        gridPaint,
      );

      // Draw task label
      _drawTaskLabel(canvas, task.name, topLeft.dx, y, labelWidth,
          taskRowHeight, fontSize);

      // Draw task bar
      final taskStartDays = task.startDate.difference(minDate).inDays;
      final taskDuration = task.durationDays;

      final barX = topLeft.dx + labelWidth + taskStartDays * dayWidth;
      final barWidth = math.max(taskDuration * dayWidth, 4.0);
      final barY = y + 4;
      final barHeight = taskRowHeight - 8;

      if (task.status == GanttTaskStatus.milestone) {
        // Draw milestone as diamond
        _drawMilestone(
            canvas, barX, barY + barHeight / 2, barHeight / 2, task.status);
      } else {
        // Draw task bar
        _drawTaskBar(canvas, barX, barY, barWidth, barHeight, task.status);
      }
    }

    // Draw vertical separator between labels and timeline
    final separatorPaint = Paint()
      ..color = const Color(GanttChartColors.gridLineColor)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(topLeft.dx + labelWidth, topLeft.dy),
      Offset(topLeft.dx + labelWidth,
          topLeft.dy + ganttData.tasks.length * taskRowHeight),
      separatorPaint,
    );
  }

  /// Draws a task label
  void _drawTaskLabel(
    Canvas canvas,
    String label,
    double x,
    double y,
    double width,
    double height,
    double fontSize,
  ) {
    final textStyle = TextStyle(
      color: Color(
          style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor),
      fontSize: fontSize,
      fontFamily: style.fontFamily,
    );

    final textSpan = TextSpan(text: label, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    textPainter.layout(maxWidth: width - 16);

    textPainter.paint(
      canvas,
      Offset(x + 8, y + (height - textPainter.height) / 2),
    );
  }

  /// Draws a task bar
  void _drawTaskBar(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    GanttTaskStatus status,
  ) {
    final color = GanttChartColors.getColorForStatus(status);
    final paint = Paint()
      ..color = Color(color)
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, width, height),
      const Radius.circular(4),
    );

    canvas.drawRRect(rect, paint);

    // Draw border for better visibility
    final borderPaint = Paint()
      ..color = mermaidColorWithOpacity(Color(color), 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(rect, borderPaint);
  }

  /// Draws a milestone marker
  void _drawMilestone(
    Canvas canvas,
    double x,
    double y,
    double size,
    GanttTaskStatus status,
  ) {
    final color = GanttChartColors.getColorForStatus(status);
    final paint = Paint()
      ..color = Color(color)
      ..style = PaintingStyle.fill;

    // Draw diamond shape
    final path = Path()
      ..moveTo(x, y - size)
      ..lineTo(x + size, y)
      ..lineTo(x, y + size)
      ..lineTo(x - size, y)
      ..close();

    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = mermaidColorWithOpacity(Color(color), 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, borderPaint);
  }

  /// Draws the today marker
  void _drawTodayMarker(
    Canvas canvas,
    double startX,
    double y,
    double timelineWidth,
    double gridHeight,
    DateTime minDate,
    DateTime today,
    int totalDays,
  ) {
    final dayWidth = timelineWidth / totalDays;
    final todayOffset = today.difference(minDate).inDays;
    final x = startX + todayOffset * dayWidth;

    // Draw vertical line
    final linePaint = Paint()
      ..color = const Color(GanttChartColors.todayMarkerColor)
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(x, y),
      Offset(x, y + gridHeight),
      linePaint,
    );

    // Draw "Today" label
    final textStyle = TextStyle(
      color: const Color(GanttChartColors.todayMarkerColor),
      fontSize: 10.0,
      fontWeight: FontWeight.bold,
      fontFamily: style.fontFamily,
    );

    final textSpan = TextSpan(text: 'Today', style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Draw background for label
    final bgPaint = Paint()
      ..color = mermaidColorWithOpacity(
        const Color(GanttChartColors.todayMarkerColor),
        0.1,
      )
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x - textPainter.width / 2 - 4,
          y - 16,
          textPainter.width + 8,
          14,
        ),
        const Radius.circular(2),
      ),
      bgPaint,
    );

    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - 15),
    );
  }

  /// Gets month name abbreviation
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  @override
  bool shouldRepaint(covariant GanttPainter oldDelegate) {
    return ganttData != oldDelegate.ganttData || style != oldDelegate.style;
  }
}

/// Layout engine for Gantt charts
class GanttChartLayout {
  /// Creates a Gantt chart layout
  const GanttChartLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Computes the size needed to render the Gantt chart
  Size computeLayout(
      GanttChartData ganttData, MermaidStyle style, Size availableSize) {
    if (ganttData.tasks.isEmpty) {
      return const Size(400, 200);
    }

    final padding = style.padding;
    final titleHeight = ganttData.title != null ? 50.0 : 0.0;
    const headerHeight = 50.0;
    final taskRowHeight =
        deviceConfig?.deviceType == DeviceType.mobile ? 28.0 : 32.0;

    // Calculate minimum width based on date range
    final totalDays = ganttData.totalDays;
    final minDayWidth =
        deviceConfig?.deviceType == DeviceType.mobile ? 8.0 : 15.0;
    final minTimelineWidth = totalDays * minDayWidth;

    // Calculate label width
    final fontSize = deviceConfig?.fontSize ?? 12.0;
    var maxLabelWidth = 0.0;
    for (final task in ganttData.tasks) {
      final estimatedWidth = task.name.length * fontSize * 0.6;
      if (estimatedWidth > maxLabelWidth) {
        maxLabelWidth = estimatedWidth;
      }
    }
    final labelWidth = (maxLabelWidth + 20).clamp(100.0, 250.0).toDouble();

    // Calculate total size
    final minWidth = labelWidth + minTimelineWidth + padding * 2;
    final minHeight = titleHeight +
        headerHeight +
        ganttData.tasks.length * taskRowHeight +
        padding * 2;

    // Constrain to available size
    final width = math.max(minWidth, math.min(availableSize.width, 1200.0));
    final height =
        math.max(minHeight, math.min(minHeight, availableSize.height));

    return Size(width, height);
  }
}

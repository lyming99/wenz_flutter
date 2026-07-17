/// Painter for Kanban diagrams
library;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/kanban.dart';
import '../models/style.dart';
import 'color_utils.dart';

/// Painter for Kanban diagrams
class KanbanPainter extends CustomPainter {
  /// Creates a kanban painter
  const KanbanPainter({
    required this.kanbanData,
    required this.style,
    this.deviceConfig,
  });

  /// The Kanban data to render
  final KanbanChartData kanbanData;

  /// Style configuration
  final MermaidStyle style;

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  @override
  void paint(Canvas canvas, Size size) {
    if (kanbanData.columns.isEmpty) return;

    final isMobile = deviceConfig?.deviceType == DeviceType.mobile;
    final padding = style.padding;

    var currentY = padding;

    // Draw title
    if (kanbanData.title != null) {
      _drawTitle(canvas, kanbanData.title!, size.width / 2, currentY);
      currentY += isMobile ? 50.0 : 60.0;
    }

    // Draw columns
    final columnSpacing = isMobile ? 12.0 : 16.0;
    final columnWidth = _calculateColumnWidth(size, kanbanData.columns.length);
    var columnX = padding;

    for (final column in kanbanData.columns) {
      _drawColumn(
        canvas,
        column,
        Offset(columnX, currentY),
        Size(columnWidth, size.height - currentY - padding),
      );
      columnX += columnWidth + columnSpacing;
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
          color: Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
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

  /// Draws a single column
  void _drawColumn(
    Canvas canvas,
    KanbanColumn column,
    Offset topLeft,
    Size columnSize,
  ) {
    final isMobile = deviceConfig?.deviceType == DeviceType.mobile;
    final headerHeight = isMobile ? 50.0 : 60.0;

    // Draw column background
    final columnRect = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      columnSize.width,
      columnSize.height,
    );

    final columnPaint = Paint()
      ..color = const Color(0xFFF5F5F5)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(columnRect, const Radius.circular(8)),
      columnPaint,
    );

    // Draw column header
    _drawColumnHeader(
      canvas,
      column,
      topLeft,
      columnSize.width,
      headerHeight,
    );

    // Draw cards
    var cardY = topLeft.dy + headerHeight + (isMobile ? 8.0 : 12.0);
    final cardSpacing = isMobile ? 8.0 : 12.0;

    for (final task in column.tasks) {
      final cardHeight = _drawCard(
        canvas,
        task,
        Offset(topLeft.dx + 8, cardY),
        columnSize.width - 16,
      );
      cardY += cardHeight + cardSpacing;
    }
  }

  /// Draws column header with title and WIP limit
  void _drawColumnHeader(
    Canvas canvas,
    KanbanColumn column,
    Offset topLeft,
    double width,
    double height,
  ) {
    // Draw header border
    final headerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, width, height),
      const Radius.circular(8),
    );

    final borderPaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(headerRect, borderPaint);

    // Draw title
    final titlePainter = TextPainter(
      text: TextSpan(
        text: column.title,
        style: TextStyle(
          fontSize: (deviceConfig?.fontSize ?? 14.0) + 2,
          fontWeight: FontWeight.bold,
          color: Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    titlePainter.layout(maxWidth: width - 80);
    titlePainter.paint(
      canvas,
      Offset(topLeft.dx + 12, topLeft.dy + height / 2 - titlePainter.height / 2),
    );

    // Draw WIP limit badge
    if (column.wipLimit != null) {
      _drawWipBadge(
        canvas,
        column.tasks.length,
        column.wipLimit!,
        Offset(topLeft.dx + width - 60, topLeft.dy + height / 2),
      );
    }
  }

  /// Draws WIP limit badge
  void _drawWipBadge(
    Canvas canvas,
    int current,
    int limit,
    Offset center,
  ) {
    final isOverLimit = current > limit;
    final bgColor = isOverLimit
        ? 0xFFF44336
        : (current == limit ? 0xFFFFC107 : 0xFF4CAF50);

    // Draw badge background
    const badgeRadius = 18.0;
    final badgePaint = Paint()
      ..color = Color(bgColor)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, badgeRadius, badgePaint);

    // Draw badge text
    final badgeText = '$current/$limit';
    final textPainter = TextPainter(
      text: TextSpan(
        text: badgeText,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  /// Draws a single task card
  /// Returns the height of the card
  double _drawCard(
    Canvas canvas,
    KanbanTask task,
    Offset topLeft,
    double width,
  ) {
    final isMobile = deviceConfig?.deviceType == DeviceType.mobile;
    final padding = isMobile ? 10.0 : 12.0;
    final fontSize = deviceConfig?.fontSize ?? 12.0;

    // Calculate card content
    var contentHeight = padding;

    // 1. Priority indicator bar
    const priorityBarHeight = 4.0;
    contentHeight += priorityBarHeight + 6;

    // 2. Description text
    final descPainter = TextPainter(
      text: TextSpan(
        text: task.description,
        style: TextStyle(
          fontSize: fontSize,
          color: const Color(0xFF212121),
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
    );
    descPainter.layout(maxWidth: width - padding * 2);
    contentHeight += descPainter.height + 8;

    // 3. Metadata row (assignee + ticket)
    if (task.assigned != null || task.ticket != null) {
      contentHeight += 24 + 8; // Avatar/badge height + spacing
    }

    contentHeight += padding;

    // Draw card background with shadow
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, width, contentHeight),
      const Radius.circular(8),
    );

    // Shadow
    final shadowPaint = Paint()
      ..color = mermaidColorWithOpacity(Colors.black, 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawRRect(
      cardRect.shift(const Offset(0, 2)),
      shadowPaint,
    );

    // Card background
    final cardPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(cardRect, cardPaint);

    // Card border
    final borderPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(cardRect, borderPaint);

    // Draw priority indicator bar
    final priorityColor = KanbanChartColors.getColorForPriority(task.priority);
    final priorityPaint = Paint()
      ..color = Color(priorityColor)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(
          topLeft.dx,
          topLeft.dy,
          width,
          priorityBarHeight,
        ),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      ),
      priorityPaint,
    );

    var currentY = topLeft.dy + padding + priorityBarHeight + 6;

    // Draw description
    descPainter.paint(canvas, Offset(topLeft.dx + padding, currentY));
    currentY += descPainter.height + 8;

    // Draw metadata row
    if (task.assigned != null || task.ticket != null) {
      _drawCardMetadata(
        canvas,
        task,
        Offset(topLeft.dx + padding, currentY),
        width - padding * 2,
      );
    }

    return contentHeight;
  }

  /// Draws card metadata (assignee avatar + ticket badge)
  void _drawCardMetadata(
    Canvas canvas,
    KanbanTask task,
    Offset topLeft,
    double width,
  ) {
    var x = topLeft.dx;

    // Draw assignee avatar
    if (task.assigned != null) {
      _drawAvatar(canvas, task.assigned!, Offset(x, topLeft.dy));
      x += 30; // Avatar width + spacing
    }

    // Draw ticket badge
    if (task.ticket != null) {
      _drawTicketBadge(canvas, task.ticket!, Offset(x, topLeft.dy));
    }
  }

  /// Draws assignee avatar (circular with initials)
  void _drawAvatar(Canvas canvas, String assignee, Offset center) {
    const radius = 12.0;
    final bgColor = KanbanChartColors.getAvatarColor(assignee);

    // Draw circle
    final circlePaint = Paint()
      ..color = Color(bgColor)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx + radius, center.dy + radius),
      radius,
      circlePaint,
    );

    // Draw initials
    final initials = _getInitials(assignee);
    final textPainter = TextPainter(
      text: TextSpan(
        text: initials,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx + radius - textPainter.width / 2,
        center.dy + radius - textPainter.height / 2,
      ),
    );
  }

  /// Draws ticket ID badge
  void _drawTicketBadge(Canvas canvas, String ticket, Offset topLeft) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '#$ticket',
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF757575),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final badgeWidth = textPainter.width + 12;
    const badgeHeight = 20.0;

    // Draw badge background
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, badgeWidth, badgeHeight),
      const Radius.circular(4),
    );

    final bgPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(badgeRect, bgPaint);

    // Draw text
    textPainter.paint(
      canvas,
      Offset(topLeft.dx + 6, topLeft.dy + 5),
    );
  }

  /// Gets initials from name
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    } else {
      return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
    }
  }

  /// Calculates column width based on available space and column count
  double _calculateColumnWidth(Size size, int columnCount) {
    final isMobile = deviceConfig?.deviceType == DeviceType.mobile;
    final padding = style.padding;
    final columnSpacing = isMobile ? 12.0 : 16.0;

    if (isMobile) {
      return (size.width - padding * 2 - columnSpacing)
          .clamp(250.0, 350.0)
          .toDouble();
    }

    final availableWidth = size.width - padding * 2;
    final columnWidth = (availableWidth - columnSpacing * (columnCount - 1)) / columnCount;
    return columnWidth.clamp(200.0, 350.0).toDouble();
  }

  @override
  bool shouldRepaint(KanbanPainter oldDelegate) {
    return oldDelegate.kanbanData != kanbanData ||
        oldDelegate.style != style ||
        oldDelegate.deviceConfig != deviceConfig;
  }
}

import 'dart:math' as math;
import 'dart:ui';

import '../config/responsive_config.dart';
import '../models/diagram.dart';
import '../models/kanban.dart';
import '../models/node.dart';
import '../models/radar.dart';
import '../models/timeline.dart';
import '../models/style.dart';
import '../models/xy_chart.dart';
import '../render/layout_instrumentation.dart';

/// Abstract base class for layout engines
abstract class LayoutEngine {
  /// Creates a layout engine
  const LayoutEngine();

  /// Computes layout for the given diagram
  ///
  /// Returns the total size required to render the diagram
  Size computeLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  );

  /// Measures the size of a node
  Size measureNode(MermaidNode node, MermaidStyle style) {
    final watch = Stopwatch()..start();
    try {
      return _measureNode(node, style);
    } finally {
      watch.stop();
      recordMermaidTextMeasurement(watch.elapsed);
    }
  }

  Size _measureNode(MermaidNode node, MermaidStyle style) {
    final nodeStyle = style.getNodeStyle(node.className);

    // Calculate text size
    final fontSize = nodeStyle.fontSize;
    final textWidth = node.label.length * fontSize * 0.6;
    final textHeight = fontSize * 1.4;

    // Add padding based on shape
    double horizontalPadding = 24.0;
    double verticalPadding = 16.0;

    switch (node.shape) {
      case NodeShape.circle:
      case NodeShape.doubleCircle:
        // Circle needs equal dimensions
        final diameter = math.max(textWidth, textHeight) + 32;
        return Size(diameter, diameter);

      case NodeShape.diamond:
      case NodeShape.hexagon:
        // These shapes need more horizontal space
        horizontalPadding = 40.0;
        verticalPadding = 24.0;
        break;

      case NodeShape.stadium:
        // Stadium is wider
        horizontalPadding = 32.0;
        break;

      case NodeShape.cylinder:
        // Cylinder needs extra height for the 3D effect
        verticalPadding = 28.0;
        break;

      default:
        break;
    }

    return Size(
      textWidth + horizontalPadding,
      textHeight + verticalPadding,
    );
  }

  /// Computes the bounding box of positioned nodes.
  Rect computeNodeBounds(Iterable<MermaidNode> nodes) {
    var hasNode = false;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (final node in nodes) {
      hasNode = true;
      minX = math.min(minX, node.x);
      minY = math.min(minY, node.y);
      maxX = math.max(maxX, node.x + node.width);
      maxY = math.max(maxY, node.y + node.height);
    }

    if (!hasNode) return Rect.zero;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// Simple layout engine that arranges nodes in a grid-like pattern
///
/// This is a basic fallback layout when more sophisticated algorithms
/// aren't needed or available.
class SimpleLayoutEngine extends LayoutEngine {
  /// Creates a simple layout engine
  const SimpleLayoutEngine();

  @override
  Size computeLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (diagram.nodes.isEmpty) return Size.zero;

    // Measure all nodes first
    for (final node in diagram.nodes) {
      final size = measureNode(node, style);
      node.width = size.width;
      node.height = size.height;
    }

    final isHorizontal = diagram.direction == DiagramDirection.leftToRight ||
        diagram.direction == DiagramDirection.rightToLeft;

    // Simple row/column layout
    double x = style.padding;
    double y = style.padding;
    double maxRowHeight = 0;
    double maxWidth = 0;
    double maxHeight = 0;

    final nodesPerRow = isHorizontal
        ? diagram.nodes.length
        : math.sqrt(diagram.nodes.length).ceil();

    for (var i = 0; i < diagram.nodes.length; i++) {
      final node = diagram.nodes[i];

      if (!isHorizontal && i > 0 && i % nodesPerRow == 0) {
        // Move to next row
        x = style.padding;
        y += maxRowHeight + style.nodeSpacingY;
        maxRowHeight = 0;
      }

      node.x = x;
      node.y = y;

      x += node.width + style.nodeSpacingX;
      maxRowHeight = math.max(maxRowHeight, node.height);
      maxWidth = math.max(maxWidth, x);
      maxHeight = math.max(maxHeight, y + node.height);
    }

    return Size(
      maxWidth + style.padding,
      maxHeight + style.padding,
    );
  }
}

/// Layout engine for timeline diagrams
class TimelineChartLayout {
  /// Creates a timeline chart layout engine
  const TimelineChartLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Computes the layout size for a timeline chart
  Size computeLayout(
    TimelineChartData timelineData,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (timelineData.sections.isEmpty) return Size.zero;

    final padding = style.padding;
    final titleHeight = timelineData.title != null ? 60.0 : 20.0;

    // Calculate maximum events in any section
    var maxEvents = 0;
    for (final section in timelineData.sections) {
      if (section.events.length > maxEvents) {
        maxEvents = section.events.length;
      }
    }

    // Layout constants
    final isMobile = deviceConfig?.deviceType == DeviceType.mobile;
    final eventHeight = isMobile ? 50.0 : 60.0;
    final verticalSpacing = isMobile ? 30.0 : 40.0;
    const timelineMargin = 20.0;

    // Calculate total height
    // Structure: padding + title + spacing + period labels + timeline + spacing + events + padding
    final totalHeight = padding +
        titleHeight +
        verticalSpacing + // Space for period labels above timeline
        timelineMargin + // Space around timeline
        verticalSpacing + // Space before events
        (maxEvents * eventHeight) +
        padding;

    // Width should be based on available space
    final totalWidth = availableSize.width;

    return Size(totalWidth, totalHeight);
  }
}

/// Layout engine for Kanban diagrams
class KanbanChartLayout {
  /// Creates a Kanban chart layout engine
  const KanbanChartLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Computes layout size for Kanban chart
  Size computeLayout(
    KanbanChartData kanbanData,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (kanbanData.columns.isEmpty) return Size.zero;

    final isMobile = deviceConfig?.deviceType == DeviceType.mobile;
    final isTablet = deviceConfig?.deviceType == DeviceType.tablet;

    // Responsive constants
    final padding = style.padding;
    final titleHeight = kanbanData.title != null ? 60.0 : 20.0;
    final columnHeaderHeight = isMobile ? 50.0 : 60.0;
    final columnSpacing = isMobile ? 12.0 : 16.0;
    final cardHeight = isMobile ? 90.0 : 110.0; // Base card height
    final cardSpacing = isMobile ? 8.0 : 12.0;

    // Calculate column width strategy
    final totalColumns = kanbanData.columns.length;
    double columnWidth;

    if (isMobile) {
      // Mobile: Single column visible, horizontal scroll
      columnWidth = availableSize.width - (padding * 2) - columnSpacing;
      columnWidth = columnWidth.clamp(250.0, 350.0).toDouble();
    } else if (isTablet && totalColumns > 3) {
      // Tablet: Max 3 columns, scroll if more
      columnWidth = (availableSize.width - padding * 2 - columnSpacing * 2) / 3;
    } else {
      // Desktop: Fit all columns if possible
      final availableWidth = availableSize.width - padding * 2;
      columnWidth =
          (availableWidth - columnSpacing * (totalColumns - 1)) / totalColumns;
      columnWidth = columnWidth.clamp(200.0, 350.0).toDouble();
    }

    // Calculate maximum cards in any column
    var maxCards = 0;
    for (final column in kanbanData.columns) {
      if (column.tasks.length > maxCards) {
        maxCards = column.tasks.length;
      }
    }

    // Calculate total height
    final cardsAreaHeight =
        (maxCards * cardHeight) + ((maxCards + 1) * cardSpacing);

    final totalHeight =
        padding + titleHeight + columnHeaderHeight + cardsAreaHeight + padding;

    // Calculate total width
    final totalWidth = isMobile
        ? (columnWidth + columnSpacing) * totalColumns + padding * 2
        : availableSize.width;

    return Size(totalWidth, totalHeight);
  }
}

/// Layout engine for Radar charts
class RadarChartLayout {
  /// Creates a Radar chart layout engine
  const RadarChartLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Computes layout size for Radar chart
  Size computeLayout(
    RadarChartData radarData,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (radarData.axes.isEmpty) return Size.zero;

    final isMobile = deviceConfig?.deviceType == DeviceType.mobile;
    final padding = style.padding;
    final titleHeight =
        radarData.title != null ? (isMobile ? 40.0 : 50.0) : 0.0;
    final legendHeight =
        radarData.showLegend && radarData.curves.length > 1 ? 60.0 : 0.0;

    // Calculate chart size based on available space
    final availableChartWidth = availableSize.width - padding * 2;
    final availableChartHeight =
        availableSize.height - titleHeight - legendHeight - padding * 2;

    // Use square aspect ratio, fitting within available space
    final chartSize = math.min(
      math.min(availableChartWidth, availableChartHeight),
      isMobile ? 350.0 : 500.0,
    );

    final totalWidth = chartSize + padding * 2;
    final totalHeight = titleHeight + chartSize + legendHeight + padding * 2;

    return Size(totalWidth, totalHeight);
  }
}

/// Layout engine for XY charts
class XYChartLayout {
  /// Creates an XY chart layout engine
  const XYChartLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Computes layout size for XY chart
  Size computeLayout(
    XYChartData xyData,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (xyData.series.isEmpty) return Size.zero;

    final isMobile = deviceConfig?.deviceType == DeviceType.mobile;
    final padding = style.padding;
    final titleHeight = xyData.title != null ? (isMobile ? 35.0 : 45.0) : 0.0;
    final xAxisLabelHeight = isMobile ? 40.0 : 50.0;

    final totalWidth = math.min(availableSize.width, isMobile ? 400.0 : 700.0);
    final totalHeight = titleHeight +
        (isMobile ? 280.0 : 400.0) +
        xAxisLabelHeight +
        padding * 2;

    return Size(totalWidth, totalHeight);
  }
}

/// Data models for XY Charts
library;

import 'dart:math' as math;

/// Orientation of the XY chart
enum XYChartOrientation {
  /// Vertical bars (default)
  vertical,

  /// Horizontal bars
  horizontal,
}

/// Type of data series
enum XYSeriesType {
  /// Bar series
  bar,

  /// Line series
  line,
}

/// Represents a data series in the XY chart
class XYChartSeries {
  /// Creates an XY chart series
  const XYChartSeries({
    required this.type,
    required this.values,
  });

  /// Series type (bar or line)
  final XYSeriesType type;

  /// Data values
  final List<double> values;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is XYChartSeries && other.type == type;
  }

  @override
  int get hashCode => Object.hash(type, values.length);
}

/// Data for a complete XY chart
class XYChartData {
  /// Creates XY chart data
  const XYChartData({
    required this.series,
    this.title,
    this.xAxisTitle,
    this.yAxisTitle,
    this.xAxisCategories = const [],
    this.xAxisMin,
    this.xAxisMax,
    this.yAxisMin,
    this.yAxisMax,
    this.orientation = XYChartOrientation.vertical,
  });

  /// Optional chart title
  final String? title;

  /// X-axis title
  final String? xAxisTitle;

  /// Y-axis title
  final String? yAxisTitle;

  /// X-axis category labels (for categorical axis)
  final List<String> xAxisCategories;

  /// X-axis numeric min (for numeric axis)
  final double? xAxisMin;

  /// X-axis numeric max (for numeric axis)
  final double? xAxisMax;

  /// Y-axis numeric min
  final double? yAxisMin;

  /// Y-axis numeric max
  final double? yAxisMax;

  /// Chart orientation
  final XYChartOrientation orientation;

  /// Data series (bar and/or line)
  final List<XYChartSeries> series;

  /// Whether x-axis is categorical
  bool get isCategorical => xAxisCategories.isNotEmpty;

  /// Gets the effective Y-axis min
  double get effectiveYMin {
    if (yAxisMin != null) return yAxisMin!;
    double minVal = 0;
    for (final s in series) {
      for (final v in s.values) {
        if (v < minVal) minVal = v;
      }
    }
    return minVal;
  }

  /// Gets the effective Y-axis max
  double get effectiveYMax {
    if (yAxisMax != null) return yAxisMax!;
    double maxVal = 0;
    for (final s in series) {
      for (final v in s.values) {
        if (v > maxVal) maxVal = v;
      }
    }
    return _roundUpToNice(maxVal);
  }

  /// Gets the number of data points
  int get dataPointCount {
    if (isCategorical) return xAxisCategories.length;
    var max = 0;
    for (final s in series) {
      if (s.values.length > max) max = s.values.length;
    }
    return max;
  }

  double _roundUpToNice(double value) {
    if (value <= 0) return 10;
    // Use log10 to find the order of magnitude
    final exponent = (math.log(value) / math.ln10).floor();
    final power = math.pow(10, exponent).toDouble();
    final normalized = value / power;
    if (normalized <= 1) return power;
    if (normalized <= 2) return 2 * power;
    if (normalized <= 5) return 5 * power;
    return 10 * power;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is XYChartData &&
        other.title == title &&
        other.orientation == orientation;
  }

  @override
  int get hashCode => Object.hash(title, orientation);
}

/// Default color palette for XY charts
class XYChartColors {
  XYChartColors._();

  /// Series colors (cycling)
  static const List<int> seriesColors = [
    0xFF2196F3, // Blue
    0xFFFF9800, // Orange
    0xFF4CAF50, // Green
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFFFFC107, // Amber
    0xFF795548, // Brown
  ];

  /// Grid line color
  static const int gridColor = 0xFFE0E0E0;

  /// Axis line color
  static const int axisColor = 0xFF616161;

  /// Text color
  static const int textColor = 0xFF212121;

  /// Gets color for series by index
  static int getColorForSeries(int index) {
    return seriesColors[index % seriesColors.length];
  }
}

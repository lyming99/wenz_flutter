/// Data models for Radar charts
library;

/// Graticule type for radar charts
enum RadarGraticule {
  /// Circular graticule
  circle,

  /// Polygon graticule
  polygon,
}

/// Represents a single axis in the radar chart
class RadarAxis {
  /// Creates a radar axis
  const RadarAxis({
    required this.id,
    required this.label,
  });

  /// Axis identifier
  final String id;

  /// Axis display label
  final String label;

  /// Creates a copy with modified properties
  RadarAxis copyWith({
    String? id,
    String? label,
  }) {
    return RadarAxis(
      id: id ?? this.id,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RadarAxis && other.id == id && other.label == label;
  }

  @override
  int get hashCode => Object.hash(id, label);
}

/// Represents a data curve/series in the radar chart
class RadarCurve {
  /// Creates a radar curve
  const RadarCurve({
    required this.id,
    required this.label,
    required this.values,
  });

  /// Curve identifier
  final String id;

  /// Curve display label
  final String label;

  /// Data values for each axis (in order of axes)
  final List<double> values;

  /// Creates a copy with modified properties
  RadarCurve copyWith({
    String? id,
    String? label,
    List<double>? values,
  }) {
    return RadarCurve(
      id: id ?? this.id,
      label: label ?? this.label,
      values: values ?? this.values,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RadarCurve && other.id == id && other.label == label;
  }

  @override
  int get hashCode => Object.hash(id, label);
}

/// Data for a complete Radar chart
class RadarChartData {
  /// Creates radar chart data
  const RadarChartData({
    required this.axes,
    required this.curves,
    this.title,
    this.showLegend = true,
    this.max,
    this.min,
    this.graticule = RadarGraticule.polygon,
    this.ticks = 5,
  });

  /// Optional title for the radar chart
  final String? title;

  /// Axes defining the radar dimensions
  final List<RadarAxis> axes;

  /// Data curves to plot
  final List<RadarCurve> curves;

  /// Whether to show legend
  final bool showLegend;

  /// Maximum value for scale (auto-calculated if null)
  final double? max;

  /// Minimum value for scale (defaults to 0 if null)
  final double? min;

  /// Type of graticule (circle or polygon)
  final RadarGraticule graticule;

  /// Number of concentric circles/polygons
  final int ticks;

  /// Gets the actual maximum value for scaling
  double get effectiveMax {
    if (max != null) return max!;

    // Auto-calculate from data
    double maxValue = 0;
    for (final curve in curves) {
      for (final value in curve.values) {
        if (value > maxValue) maxValue = value;
      }
    }
    // Round up to nice number
    return _roundUpToNice(maxValue);
  }

  /// Gets the actual minimum value for scaling
  double get effectiveMin => min ?? 0.0;

  /// Rounds up to a nice number for scale
  double _roundUpToNice(double value) {
    if (value == 0) return 10;

    final magnitude = value.abs().toString().length - 1;
    final power = 1.0 * (magnitude > 0 ? magnitude : 1);
    final normalized = value / power;

    if (normalized <= 1) return 1 * power;
    if (normalized <= 2) return 2 * power;
    if (normalized <= 5) return 5 * power;
    return 10 * power;
  }

  /// Creates a copy with modified properties
  RadarChartData copyWith({
    String? title,
    List<RadarAxis>? axes,
    List<RadarCurve>? curves,
    bool? showLegend,
    double? max,
    double? min,
    RadarGraticule? graticule,
    int? ticks,
  }) {
    return RadarChartData(
      title: title ?? this.title,
      axes: axes ?? this.axes,
      curves: curves ?? this.curves,
      showLegend: showLegend ?? this.showLegend,
      max: max ?? this.max,
      min: min ?? this.min,
      graticule: graticule ?? this.graticule,
      ticks: ticks ?? this.ticks,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RadarChartData &&
        other.title == title &&
        other.showLegend == showLegend &&
        other.max == max &&
        other.min == min &&
        other.graticule == graticule &&
        other.ticks == ticks;
  }

  @override
  int get hashCode {
    return Object.hash(title, showLegend, max, min, graticule, ticks);
  }
}

/// Default color palette for Radar charts
class RadarChartColors {
  RadarChartColors._();

  /// Default curve colors (cycling)
  static const List<int> curveColors = [
    0xFF2196F3, // Blue
    0xFFFF9800, // Orange
    0xFF4CAF50, // Green
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFFFFC107, // Amber
    0xFF795548, // Brown
  ];

  /// Graticule line color
  static const int graticuleColor = 0xFFE0E0E0; // Light grey

  /// Axis line color
  static const int axisColor = 0xFF9E9E9E; // Grey

  /// Text color
  static const int textColor = 0xFF212121; // Dark grey

  /// Background color
  static const int backgroundColor = 0xFFFFFFFF; // White

  /// Gets color for curve by index
  static int getColorForCurve(int index) {
    return curveColors[index % curveColors.length];
  }
}

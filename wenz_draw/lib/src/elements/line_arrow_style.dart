import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../utils/math_utils.dart';

/// Arrow shape used at either end of line-like elements.
enum LineArrowType {
  none,
  normal;

  String get jsonValue => name;

  bool get isEnabled => this != LineArrowType.none;

  static LineArrowType fromJson(
    Object? value, {
    LineArrowType fallback = LineArrowType.none,
  }) {
    if (value == null) {
      return fallback;
    }
    if (value is LineArrowType) {
      return value;
    }
    if (value is bool) {
      return value ? LineArrowType.normal : LineArrowType.none;
    }
    if (value is num) {
      return value == 0 ? LineArrowType.none : LineArrowType.normal;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase().replaceAll(
        RegExp(r'[\s_-]+'),
        '',
      );
      switch (normalized) {
        case '':
        case '0':
        case 'false':
        case 'none':
        case 'noarrow':
        case 'null':
          return LineArrowType.none;
        case '1':
        case 'true':
        case 'arrow':
        case 'normal':
        case 'standard':
          return LineArrowType.normal;
      }
      for (final type in LineArrowType.values) {
        if (type.name.toLowerCase() == normalized) {
          return type;
        }
      }
    }
    return fallback;
  }
}

enum LineArrowEndpoint { start, end }

/// User-facing arrow presets shared by straight, polyline and curve lines.
enum LineArrowMode { none, single, both }

/// Start/end arrow configuration shared by straight, polyline and curve lines.
@immutable
class LineArrowStyle {
  const LineArrowStyle({
    LineArrowType? start,
    LineArrowType? end,
    LineArrowType? startArrowStyle,
    LineArrowType? endArrowStyle,
    this.headSize = defaultHeadSize,
  }) : startArrowStyle = startArrowStyle ?? start ?? LineArrowType.none,
       endArrowStyle = endArrowStyle ?? end ?? LineArrowType.none;

  static const double defaultHeadSize = 14;

  static const none = LineArrowStyle();

  static const endNormal = LineArrowStyle(endArrowStyle: LineArrowType.normal);

  static const bothNormal = LineArrowStyle(
    startArrowStyle: LineArrowType.normal,
    endArrowStyle: LineArrowType.normal,
  );

  final LineArrowType startArrowStyle;
  final LineArrowType endArrowStyle;
  final double headSize;

  LineArrowType get start => startArrowStyle;

  LineArrowType get end => endArrowStyle;

  bool get hasStartArrow => startArrowStyle.isEnabled;

  bool get hasEndArrow => endArrowStyle.isEnabled;

  bool get hasAnyArrow => hasStartArrow || hasEndArrow;

  LineArrowMode get mode {
    if (hasStartArrow && hasEndArrow) {
      return LineArrowMode.both;
    }
    if (hasAnyArrow) {
      return LineArrowMode.single;
    }
    return LineArrowMode.none;
  }

  bool get legacyEndArrow => hasEndArrow;

  double get effectiveHeadSize => normalizeHeadSize(headSize);

  LineArrowType typeFor(LineArrowEndpoint endpoint) {
    return endpoint == LineArrowEndpoint.start
        ? startArrowStyle
        : endArrowStyle;
  }

  LineArrowStyle copyWith({
    LineArrowType? start,
    LineArrowType? end,
    LineArrowType? startArrowStyle,
    LineArrowType? endArrowStyle,
    double? headSize,
  }) {
    return LineArrowStyle(
      startArrowStyle: startArrowStyle ?? start ?? this.startArrowStyle,
      endArrowStyle: endArrowStyle ?? end ?? this.endArrowStyle,
      headSize: headSize ?? this.headSize,
    );
  }

  LineArrowStyle copyWithEndpoint(
    LineArrowEndpoint endpoint,
    LineArrowType type,
  ) {
    return endpoint == LineArrowEndpoint.start
        ? copyWith(start: type)
        : copyWith(end: type);
  }

  LineArrowStyle withMode(LineArrowMode mode) {
    return switch (mode) {
      LineArrowMode.none => copyWith(
        start: LineArrowType.none,
        end: LineArrowType.none,
      ),
      LineArrowMode.single => copyWith(
        start: LineArrowType.none,
        end: LineArrowType.normal,
      ),
      LineArrowMode.both => copyWith(
        start: LineArrowType.normal,
        end: LineArrowType.normal,
      ),
    };
  }

  LineArrowStyle scale(double factor) {
    return copyWith(headSize: effectiveHeadSize * factor.abs());
  }

  Map<String, dynamic> toJson() {
    return {
      'startArrowStyle': startArrowStyle.jsonValue,
      'endArrowStyle': endArrowStyle.jsonValue,
      'headSize': effectiveHeadSize,
    };
  }

  static LineArrowStyle fromJson(Object? json) {
    if (json == null) {
      return LineArrowStyle.none;
    }
    if (json is LineArrowStyle) {
      return json;
    }
    if (json is Map<String, dynamic>) {
      return fromFields(
        startArrowStyle: json['startArrowStyle'] ?? json['start'],
        endArrowStyle: json['endArrowStyle'] ?? json['end'],
        endArrow: json['endArrow'],
        headSize: json['headSize'],
      );
    }
    if (json is Map) {
      return fromFields(
        startArrowStyle: json['startArrowStyle'] ?? json['start'],
        endArrowStyle: json['endArrowStyle'] ?? json['end'],
        endArrow: json['endArrow'],
        headSize: json['headSize'],
      );
    }
    return LineArrowStyle.none;
  }

  static LineArrowStyle fromFields({
    Object? startArrowStyle,
    Object? endArrowStyle,
    Object? endArrow,
    Object? headSize,
  }) {
    final legacyEndArrow = LineArrowType.fromJson(endArrow).isEnabled;
    final endFallback = legacyEndArrow
        ? LineArrowType.normal
        : LineArrowType.none;
    return LineArrowStyle(
      startArrowStyle: LineArrowType.fromJson(startArrowStyle),
      endArrowStyle: LineArrowType.fromJson(
        endArrowStyle,
        fallback: endFallback,
      ),
      headSize: _readHeadSize(headSize),
    );
  }

  static LineArrowStyle fromLegacyEndArrow({
    bool endArrow = false,
    double headSize = defaultHeadSize,
  }) {
    return LineArrowStyle(
      endArrowStyle: endArrow ? LineArrowType.normal : LineArrowType.none,
      headSize: normalizeHeadSize(headSize),
    );
  }

  static double normalizeHeadSize(double value) {
    return value.isFinite ? math.max(0, value) : defaultHeadSize;
  }

  static double _readHeadSize(Object? value) {
    if (value is num) {
      return normalizeHeadSize(value.toDouble());
    }
    if (value is String) {
      return normalizeHeadSize(double.tryParse(value) ?? defaultHeadSize);
    }
    return defaultHeadSize;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LineArrowStyle &&
            other.startArrowStyle == startArrowStyle &&
            other.endArrowStyle == endArrowStyle &&
            other.headSize == headSize;
  }

  @override
  int get hashCode => Object.hash(startArrowStyle, endArrowStyle, headSize);

  @override
  String toString() {
    return 'LineArrowStyle('
        'startArrowStyle: $startArrowStyle, '
        'endArrowStyle: $endArrowStyle, '
        'headSize: $headSize'
        ')';
  }
}

@immutable
class LineArrowGeometry {
  const LineArrowGeometry({
    required this.type,
    required this.tip,
    required this.firstWing,
    required this.secondWing,
    required this.headSize,
  });

  final LineArrowType type;
  final Offset tip;
  final Offset firstWing;
  final Offset secondWing;
  final double headSize;

  Path toPath() {
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(firstWing.dx, firstWing.dy)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(secondWing.dx, secondWing.dy);
  }

  Rect get bounds => boundsForPoints([tip, firstWing, secondWing]);

  bool hitTest(Offset worldPoint, {required double tolerance}) {
    return distanceToSegment(worldPoint, tip, firstWing) <= tolerance ||
        distanceToSegment(worldPoint, tip, secondWing) <= tolerance;
  }
}

class LineArrowGeometryUtils {
  const LineArrowGeometryUtils._();

  static const double minSegmentLength = 0.1;

  static const double wingAngleFactor = 0.82;

  static double boundsInflate({
    required LineArrowStyle style,
    double strokeWidth = 0,
  }) {
    return math.max(
      strokeWidth / 2,
      style.hasAnyArrow ? style.effectiveHeadSize : 0,
    );
  }

  static Rect expandBounds({
    required Rect bounds,
    required LineArrowStyle style,
    double strokeWidth = 0,
  }) {
    return bounds.inflate(
      boundsInflate(style: style, strokeWidth: strokeWidth),
    );
  }

  static Rect expandBoundsWithGeometries(
    Rect bounds,
    Iterable<LineArrowGeometry?> geometries,
  ) {
    var expanded = bounds;
    for (final geometry in geometries) {
      if (geometry == null) {
        continue;
      }
      expanded = expanded.expandToInclude(geometry.bounds);
    }
    return expanded;
  }

  static LineArrowGeometry? geometryForPoints({
    required List<Offset> points,
    required LineArrowStyle style,
    required LineArrowEndpoint endpoint,
  }) {
    if (points.length < 2) {
      return null;
    }
    return geometryForDirection(
      type: style.typeFor(endpoint),
      tip: endpoint == LineArrowEndpoint.start ? points.first : points.last,
      direction: terminalDirection(points, endpoint: endpoint),
      headSize: style.effectiveHeadSize,
    );
  }

  static LineArrowGeometry? geometryForDirection({
    required LineArrowType type,
    required Offset tip,
    required Offset? direction,
    required double headSize,
  }) {
    if (!type.isEnabled || direction == null) {
      return null;
    }
    final normalizedHeadSize = LineArrowStyle.normalizeHeadSize(headSize);
    if (normalizedHeadSize == 0 || direction.distance < minSegmentLength) {
      return null;
    }
    final angle = math.atan2(direction.dy, direction.dx);
    final wingA = angle + math.pi * wingAngleFactor;
    final wingB = angle - math.pi * wingAngleFactor;
    return LineArrowGeometry(
      type: type,
      tip: tip,
      firstWing:
          tip + Offset(math.cos(wingA), math.sin(wingA)) * normalizedHeadSize,
      secondWing:
          tip + Offset(math.cos(wingB), math.sin(wingB)) * normalizedHeadSize,
      headSize: normalizedHeadSize,
    );
  }

  static Offset? terminalDirection(
    List<Offset> points, {
    required LineArrowEndpoint endpoint,
  }) {
    if (points.length < 2) {
      return null;
    }

    if (endpoint == LineArrowEndpoint.start) {
      final start = points.first;
      for (var i = 1; i < points.length; i++) {
        final candidate = points[i];
        final direction = start - candidate;
        if (direction.distance >= minSegmentLength) {
          return direction;
        }
      }
      return null;
    }

    final end = points.last;
    for (var i = points.length - 2; i >= 0; i--) {
      final candidate = points[i];
      final direction = end - candidate;
      if (direction.distance >= minSegmentLength) {
        return direction;
      }
    }
    return null;
  }

  static bool hitTestArrow({
    required Offset worldPoint,
    required LineArrowType type,
    required Offset tip,
    required Offset? direction,
    required double headSize,
    required double tolerance,
  }) {
    return geometryForDirection(
          type: type,
          tip: tip,
          direction: direction,
          headSize: headSize,
        )?.hitTest(worldPoint, tolerance: tolerance) ??
        false;
  }

  static bool hitTestArrowForPoints({
    required Offset worldPoint,
    required List<Offset> points,
    required LineArrowStyle style,
    required LineArrowEndpoint endpoint,
    required double tolerance,
  }) {
    return geometryForPoints(
          points: points,
          style: style,
          endpoint: endpoint,
        )?.hitTest(worldPoint, tolerance: tolerance) ??
        false;
  }

  static bool hitTestAnyArrowForPoints({
    required Offset worldPoint,
    required List<Offset> points,
    required LineArrowStyle style,
    required double tolerance,
  }) {
    for (final endpoint in LineArrowEndpoint.values) {
      if (hitTestArrowForPoints(
        worldPoint: worldPoint,
        points: points,
        style: style,
        endpoint: endpoint,
        tolerance: tolerance,
      )) {
        return true;
      }
    }
    return false;
  }

  static void drawArrow(
    Canvas canvas,
    Paint paint, {
    required LineArrowType type,
    required Offset tip,
    required Offset? direction,
    required double headSize,
  }) {
    final geometry = geometryForDirection(
      type: type,
      tip: tip,
      direction: direction,
      headSize: headSize,
    );
    if (geometry == null) {
      return;
    }
    canvas.drawPath(geometry.toPath(), paint);
  }

  static void drawArrowForPoints(
    Canvas canvas,
    Paint paint, {
    required List<Offset> points,
    required LineArrowStyle style,
    required LineArrowEndpoint endpoint,
  }) {
    final geometry = geometryForPoints(
      points: points,
      style: style,
      endpoint: endpoint,
    );
    if (geometry == null) {
      return;
    }
    canvas.drawPath(geometry.toPath(), paint);
  }

  static void drawArrowsForPoints(
    Canvas canvas,
    Paint paint, {
    required List<Offset> points,
    required LineArrowStyle style,
  }) {
    for (final endpoint in LineArrowEndpoint.values) {
      drawArrowForPoints(
        canvas,
        paint,
        points: points,
        style: style,
        endpoint: endpoint,
      );
    }
  }
}

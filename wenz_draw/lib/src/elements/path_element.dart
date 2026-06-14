import 'package:flutter/widgets.dart';

import '../canvas/paint_style.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

@immutable
class PathPoint {
  const PathPoint({
    required this.position,
    this.pressure = 0.5,
    this.timestamp = 0,
  });

  final Offset position;
  final double pressure;
  final double timestamp;

  PathPoint translate(Offset delta) {
    return PathPoint(
      position: position + delta,
      pressure: pressure,
      timestamp: timestamp,
    );
  }

  PathPoint scale(double factor, Offset pivot) {
    return PathPoint(
      position: scalePoint(position, factor, pivot),
      pressure: pressure,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': position.dx,
      'y': position.dy,
      'pressure': pressure,
      'timestamp': timestamp,
    };
  }
}

@immutable
class PathElement extends CanvasElement {
  PathElement({
    required this.id,
    required List<PathPoint> points,
    this.style = const PaintStyle(),
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
    this.groupId,
  }) : points = List<PathPoint>.unmodifiable(points);

  static const elementType = 'path';

  @override
  final String id;

  final List<PathPoint> points;
  final PaintStyle style;

  @override
  final String layerId;

  @override
  final bool visible;

  @override
  final double opacity;

  @override
  final int zIndex;

  @override
  final String? groupId;

  @override
  String get type => elementType;

  @override
  Rect get bounds {
    if (points.isEmpty) {
      return Rect.zero;
    }
    return boundsForPoints(
      points.map((point) => point.position),
    ).inflate(style.strokeWidth / 2);
  }

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    if (points.isEmpty) {
      return false;
    }
    if (points.length == 1) {
      return (points.first.position - worldPoint).distance <=
          tolerance + style.strokeWidth / 2;
    }

    final threshold = tolerance + style.strokeWidth / 2;
    for (var i = 0; i < points.length - 1; i++) {
      if (distanceToSegment(
            worldPoint,
            points[i].position,
            points[i + 1].position,
          ) <=
          threshold) {
        return true;
      }
    }
    return false;
  }

  @override
  PathElement copyWith({
    String? id,
    List<PathPoint>? points,
    PaintStyle? style,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    Object? groupId = _unset,
  }) {
    return PathElement(
      id: id ?? this.id,
      points: points ?? this.points,
      style: style ?? this.style,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      groupId: identical(groupId, _unset)
          ? this.groupId
          : groupId as String?,
    );
  }

  @override
  PathElement translate(Offset delta) {
    return copyWith(
      points: [for (final point in points) point.translate(delta)],
    );
  }

  @override
  PathElement scaleElement(double factor, {Offset? pivot}) {
    final origin = pivot ?? bounds.center;
    return copyWith(
      points: [for (final point in points) point.scale(factor, origin)],
      style: style.copyWith(strokeWidth: style.strokeWidth * factor.abs()),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'layerId': layerId,
      'visible': visible,
      'opacity': opacity,
      'zIndex': zIndex,
      'groupId': groupId,
      'points': [for (final point in points) point.toJson()],
      'style': style.toJson(),
    };
  }

  static const _unset = Object();
}

class PathElementRenderer extends ElementRenderer<PathElement> {
  const PathElementRenderer();

  @override
  void render(Canvas canvas, PathElement element) {
    if (element.points.isEmpty || !element.visible) {
      return;
    }

    final paint = element.style
        .copyWith(opacity: element.style.opacity * element.opacity)
        .toPaint();

    if (element.points.length == 1) {
      canvas.drawCircle(
        element.points.first.position,
        element.style.strokeWidth / 2,
        paint,
      );
      return;
    }

    final path = Path()
      ..moveTo(
        element.points.first.position.dx,
        element.points.first.position.dy,
      );
    for (final point in element.points.skip(1)) {
      path.lineTo(point.position.dx, point.position.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool hitTest(PathElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}

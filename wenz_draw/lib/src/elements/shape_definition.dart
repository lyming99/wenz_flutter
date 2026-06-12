import 'package:flutter/material.dart';

import '../canvas/paint_style.dart';
import '../utils/math_utils.dart';

typedef ShapePathBuilder =
    Path Function(Rect rect, Map<String, dynamic> properties);

typedef ShapeSvgPathBuilder =
    String Function(Rect rect, Map<String, dynamic> properties);

typedef ShapeLabelRectBuilder =
    Rect Function(Rect rect, Map<String, dynamic> properties);

typedef ShapeOutlineBuilder =
    List<Offset> Function(Rect rect, Map<String, dynamic> properties);

typedef ShapeConnectionPointsBuilder =
    List<ShapeConnectionPoint> Function(
      Rect rect,
      Map<String, dynamic> properties,
    );

@immutable
class ShapeConnectionPoint {
  const ShapeConnectionPoint({
    required this.anchorId,
    required this.position,
    required this.kind,
  });

  final String anchorId;
  final Offset position;
  final ShapeConnectionPointKind kind;
}

enum ShapeConnectionPointKind { center, edge, corner, body }

@immutable
class ShapeDefinition {
  const ShapeDefinition({
    required this.key,
    required this.buildPath,
    required this.buildSvgPath,
    this.buildForegroundPaths,
    this.buildForegroundSvgPaths,
    this.buildLabelRect,
    this.buildOutline,
    this.buildConnectionPoints,
  });

  final String key;
  final ShapePathBuilder buildPath;
  final ShapeSvgPathBuilder buildSvgPath;
  final List<Path> Function(Rect rect, Map<String, dynamic> properties)?
  buildForegroundPaths;
  final List<String> Function(Rect rect, Map<String, dynamic> properties)?
  buildForegroundSvgPaths;
  final ShapeLabelRectBuilder? buildLabelRect;
  final ShapeOutlineBuilder? buildOutline;
  final ShapeConnectionPointsBuilder? buildConnectionPoints;

  Path pathFor(Rect rect, Map<String, dynamic> properties) {
    return buildPath(rect, properties);
  }

  String svgPathFor(Rect rect, Map<String, dynamic> properties) {
    return buildSvgPath(rect, properties);
  }

  List<Path> foregroundPathsFor(Rect rect, Map<String, dynamic> properties) {
    return buildForegroundPaths?.call(rect, properties) ?? const <Path>[];
  }

  List<String> foregroundSvgPathsFor(
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    return buildForegroundSvgPaths?.call(rect, properties) ?? const <String>[];
  }

  Rect labelRectFor(Rect rect, Map<String, dynamic> properties) {
    return buildLabelRect?.call(rect, properties) ?? rect;
  }

  List<ShapeConnectionPoint> connectionPointsFor(
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    return buildConnectionPoints?.call(rect, properties) ??
        defaultConnectionPoints(rect);
  }

  static List<ShapeConnectionPoint> defaultConnectionPoints(Rect rect) {
    if (rect.isEmpty) {
      return const <ShapeConnectionPoint>[];
    }
    return [
      ShapeConnectionPoint(
        anchorId: 'center',
        position: rect.center,
        kind: ShapeConnectionPointKind.center,
      ),
      ShapeConnectionPoint(
        anchorId: 'top',
        position: Offset(rect.center.dx, rect.top),
        kind: ShapeConnectionPointKind.edge,
      ),
      ShapeConnectionPoint(
        anchorId: 'right',
        position: Offset(rect.right, rect.center.dy),
        kind: ShapeConnectionPointKind.edge,
      ),
      ShapeConnectionPoint(
        anchorId: 'bottom',
        position: Offset(rect.center.dx, rect.bottom),
        kind: ShapeConnectionPointKind.edge,
      ),
      ShapeConnectionPoint(
        anchorId: 'left',
        position: Offset(rect.left, rect.center.dy),
        kind: ShapeConnectionPointKind.edge,
      ),
      ShapeConnectionPoint(
        anchorId: 'topLeft',
        position: rect.topLeft,
        kind: ShapeConnectionPointKind.corner,
      ),
      ShapeConnectionPoint(
        anchorId: 'topRight',
        position: rect.topRight,
        kind: ShapeConnectionPointKind.corner,
      ),
      ShapeConnectionPoint(
        anchorId: 'bottomRight',
        position: rect.bottomRight,
        kind: ShapeConnectionPointKind.corner,
      ),
      ShapeConnectionPoint(
        anchorId: 'bottomLeft',
        position: rect.bottomLeft,
        kind: ShapeConnectionPointKind.corner,
      ),
    ];
  }

  bool hitTest(
    Rect rect,
    Map<String, dynamic> properties,
    Offset worldPoint, {
    required PaintStyle strokeStyle,
    PaintStyle? fillStyle,
    double tolerance = 5,
  }) {
    if (rect.isEmpty) {
      return false;
    }

    final path = pathFor(rect, properties);
    if (fillStyle != null && path.contains(worldPoint)) {
      return true;
    }

    final threshold = tolerance + strokeStyle.strokeWidth / 2;
    final outline = buildOutline?.call(rect, properties);
    if (outline != null && outline.length > 1) {
      for (var i = 0; i < outline.length; i++) {
        final start = outline[i];
        final end = outline[(i + 1) % outline.length];
        if (distanceToSegment(worldPoint, start, end) <= threshold) {
          return true;
        }
      }
      return false;
    }

    final pathBounds = path.getBounds();
    if (pathBounds.isEmpty) {
      return false;
    }
    final outer = pathBounds.inflate(threshold);
    final inner = pathBounds.deflate(threshold);
    return outer.contains(worldPoint) &&
        (inner.isEmpty || !inner.contains(worldPoint));
  }

  void paint(
    Canvas canvas,
    Rect rect,
    Map<String, dynamic> properties, {
    required PaintStyle strokeStyle,
    PaintStyle? fillStyle,
    required double opacity,
  }) {
    final path = pathFor(rect, properties);
    if (fillStyle != null) {
      canvas.drawPath(
        path,
        fillStyle
            .copyWith(
              opacity: fillStyle.opacity * opacity,
              paintingStyle: PaintingStyle.fill,
            )
            .toPaint(),
      );
    }

    final strokePaint = strokeStyle
        .copyWith(opacity: strokeStyle.opacity * opacity)
        .toPaint();
    canvas.drawPath(path, strokePaint);
    for (final foreground in foregroundPathsFor(rect, properties)) {
      canvas.drawPath(foreground, strokePaint);
    }
  }
}

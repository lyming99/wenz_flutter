import 'package:flutter/widgets.dart';

import 'shape_definition.dart';

class ShapeConnectionPoints {
  const ShapeConnectionPoints._();

  static List<ShapeConnectionPoint> rectangle(Rect rect) {
    return ShapeDefinition.defaultConnectionPoints(rect);
  }

  static List<ShapeConnectionPoint> ellipse(Rect rect) {
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
    ];
  }

  static List<ShapeConnectionPoint> polygon(List<Offset> vertices) {
    if (vertices.isEmpty) {
      return const <ShapeConnectionPoint>[];
    }
    final rect = Rect.fromPoints(
      vertices.first,
      vertices.first,
    ).expandToInclude(_boundsFor(vertices));
    final points = <ShapeConnectionPoint>[
      ShapeConnectionPoint(
        anchorId: 'center',
        position: rect.center,
        kind: ShapeConnectionPointKind.center,
      ),
    ];
    for (var i = 0; i < vertices.length; i++) {
      final current = vertices[i];
      final next = vertices[(i + 1) % vertices.length];
      points
        ..add(
          ShapeConnectionPoint(
            anchorId: 'vertex$i',
            position: current,
            kind: ShapeConnectionPointKind.corner,
          ),
        )
        ..add(
          ShapeConnectionPoint(
            anchorId: 'edge$i',
            position: Offset.lerp(current, next, 0.5)!,
            kind: ShapeConnectionPointKind.edge,
          ),
        );
    }
    return points;
  }

  static List<ShapeConnectionPoint> swimlane(
    Rect rect, {
    required double headerHeight,
  }) {
    if (rect.isEmpty) {
      return const <ShapeConnectionPoint>[];
    }
    final header = headerHeight.clamp(0.0, rect.height).toDouble();
    final headerCenterY = rect.top + header / 2;
    final bodyTop = rect.top + header;
    final bodyCenterY = bodyTop + (rect.height - header) / 2;
    return [
      ...rectangle(rect),
      ShapeConnectionPoint(
        anchorId: 'headerCenter',
        position: Offset(rect.center.dx, headerCenterY),
        kind: ShapeConnectionPointKind.body,
      ),
      ShapeConnectionPoint(
        anchorId: 'headerLeft',
        position: Offset(rect.left, headerCenterY),
        kind: ShapeConnectionPointKind.edge,
      ),
      ShapeConnectionPoint(
        anchorId: 'headerRight',
        position: Offset(rect.right, headerCenterY),
        kind: ShapeConnectionPointKind.edge,
      ),
      ShapeConnectionPoint(
        anchorId: 'bodyCenter',
        position: Offset(rect.center.dx, bodyCenterY),
        kind: ShapeConnectionPointKind.body,
      ),
      ShapeConnectionPoint(
        anchorId: 'bodyLeft',
        position: Offset(rect.left, bodyCenterY),
        kind: ShapeConnectionPointKind.edge,
      ),
      ShapeConnectionPoint(
        anchorId: 'bodyRight',
        position: Offset(rect.right, bodyCenterY),
        kind: ShapeConnectionPointKind.edge,
      ),
    ];
  }

  static Rect _boundsFor(List<Offset> points) {
    var left = points.first.dx;
    var top = points.first.dy;
    var right = points.first.dx;
    var bottom = points.first.dy;
    for (final point in points.skip(1)) {
      left = point.dx < left ? point.dx : left;
      top = point.dy < top ? point.dy : top;
      right = point.dx > right ? point.dx : right;
      bottom = point.dy > bottom ? point.dy : bottom;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../canvas/canvas_controller.dart';
import '../elements/arrow_element.dart';
import '../elements/canvas_element.dart';
import '../elements/line_element.dart';
import '../elements/polyline_element.dart';

class SnapSettings {
  const SnapSettings({
    this.enabled = true,
    this.thresholdScreenPx = 12,
    this.includeCenters = true,
    this.includeEdges = true,
    this.includeCorners = true,
    this.includeLinePoints = true,
  });

  final bool enabled;
  final double thresholdScreenPx;
  final bool includeCenters;
  final bool includeEdges;
  final bool includeCorners;
  final bool includeLinePoints;

  double worldThreshold(double scale) {
    return thresholdScreenPx / math.max(scale.abs(), 0.0001);
  }
}

enum SnapPointKind { center, edge, corner, endpoint, midpoint }

class SnapBinding {
  const SnapBinding({required this.elementId, required this.anchorId});

  final String elementId;
  final String anchorId;

  Map<String, dynamic> toJson() {
    return {'elementId': elementId, 'anchorId': anchorId};
  }

  static SnapBinding? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final elementId = json['elementId'] as String?;
    final anchorId = json['anchorId'] as String?;
    if (elementId == null || anchorId == null) {
      return null;
    }
    return SnapBinding(elementId: elementId, anchorId: anchorId);
  }
}

class SnapPoint {
  const SnapPoint({
    required this.elementId,
    required this.anchorId,
    required this.position,
    required this.kind,
  });

  final String elementId;
  final String anchorId;
  final Offset position;
  final SnapPointKind kind;

  SnapBinding get binding =>
      SnapBinding(elementId: elementId, anchorId: anchorId);
}

class SnapResult {
  const SnapResult({required this.point, required this.distance});

  final SnapPoint point;
  final double distance;

  Offset get position => point.position;
  SnapBinding get binding => point.binding;
}

class SnapResolver {
  const SnapResolver({this.settings = const SnapSettings()});

  final SnapSettings settings;

  SnapResult? resolve(
    CanvasController controller,
    Offset worldPoint, {
    required double scale,
    Set<String> excludeElementIds = const <String>{},
  }) {
    if (!settings.enabled) {
      return null;
    }

    final threshold = settings.worldThreshold(scale);
    SnapResult? best;
    for (final point in snapPoints(
      controller,
      excludeElementIds: excludeElementIds,
    )) {
      final distance = (point.position - worldPoint).distance;
      if (distance > threshold) {
        continue;
      }
      if (best == null || distance < best.distance) {
        best = SnapResult(point: point, distance: distance);
      }
    }
    return best;
  }

  Offset? resolveBinding(CanvasController controller, SnapBinding? binding) {
    if (binding == null) {
      return null;
    }
    final element = controller.elementById(binding.elementId);
    if (element == null ||
        !element.visible ||
        !controller.isLayerVisible(element.layerId) ||
        controller.isLayerLocked(element.layerId)) {
      return null;
    }
    for (final point in pointsForElement(element)) {
      if (point.anchorId == binding.anchorId) {
        return point.position;
      }
    }
    return null;
  }

  Iterable<SnapPoint> snapPoints(
    CanvasController controller, {
    Set<String> excludeElementIds = const <String>{},
  }) sync* {
    for (final element in controller.elements) {
      if (!element.visible ||
          !controller.isLayerVisible(element.layerId) ||
          controller.isLayerLocked(element.layerId) ||
          excludeElementIds.contains(element.id)) {
        continue;
      }
      yield* pointsForElement(element);
    }
  }

  Iterable<SnapPoint> pointsForElement(CanvasElement element) sync* {
    if (element is LineElement) {
      if (!settings.includeLinePoints) {
        return;
      }
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'start',
        position: element.start,
        kind: SnapPointKind.endpoint,
      );
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'end',
        position: element.end,
        kind: SnapPointKind.endpoint,
      );
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'midpoint',
        position: Offset.lerp(element.start, element.end, 0.5)!,
        kind: SnapPointKind.midpoint,
      );
      return;
    }
    if (element is PolylineElement) {
      if (!settings.includeLinePoints || element.points.length < 2) {
        return;
      }
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'start',
        position: element.start,
        kind: SnapPointKind.endpoint,
      );
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'end',
        position: element.end,
        kind: SnapPointKind.endpoint,
      );
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'midpoint',
        position: _polylineMidpoint(element.points),
        kind: SnapPointKind.midpoint,
      );
      return;
    }
    if (element is ArrowElement) {
      if (!settings.includeLinePoints) {
        return;
      }
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'start',
        position: element.start,
        kind: SnapPointKind.endpoint,
      );
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'end',
        position: element.end,
        kind: SnapPointKind.endpoint,
      );
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'midpoint',
        position: Offset.lerp(element.start, element.end, 0.5)!,
        kind: SnapPointKind.midpoint,
      );
      return;
    }

    final bounds = element.bounds;
    if (bounds.isEmpty) {
      return;
    }
    if (settings.includeCenters) {
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'center',
        position: bounds.center,
        kind: SnapPointKind.center,
      );
    }
    if (settings.includeEdges) {
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'top',
        position: Offset(bounds.center.dx, bounds.top),
        kind: SnapPointKind.edge,
      );
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'right',
        position: Offset(bounds.right, bounds.center.dy),
        kind: SnapPointKind.edge,
      );
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'bottom',
        position: Offset(bounds.center.dx, bounds.bottom),
        kind: SnapPointKind.edge,
      );
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'left',
        position: Offset(bounds.left, bounds.center.dy),
        kind: SnapPointKind.edge,
      );
    }
    if (settings.includeCorners) {
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'topLeft',
        position: bounds.topLeft,
        kind: SnapPointKind.corner,
      );
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'topRight',
        position: bounds.topRight,
        kind: SnapPointKind.corner,
      );
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'bottomRight',
        position: bounds.bottomRight,
        kind: SnapPointKind.corner,
      );
      yield SnapPoint(
        elementId: element.id,
        anchorId: 'bottomLeft',
        position: bounds.bottomLeft,
        kind: SnapPointKind.corner,
      );
    }
  }

  Offset _polylineMidpoint(List<Offset> points) {
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    if (total <= 0) {
      return points.first;
    }
    var travelled = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final length = (points[i + 1] - points[i]).distance;
      if (travelled + length >= total / 2) {
        final t = (total / 2 - travelled) / length;
        return Offset.lerp(points[i], points[i + 1], t)!;
      }
      travelled += length;
    }
    return points.last;
  }
}

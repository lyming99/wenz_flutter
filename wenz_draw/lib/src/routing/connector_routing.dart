import 'package:flutter/widgets.dart';

import '../elements/arrow_element.dart';
import '../elements/canvas_element.dart';
import '../elements/line_element.dart';
import '../elements/polyline_element.dart';
import '../snap/snap_resolver.dart';
import '../utils/orthogonal_router.dart';

enum ConnectorRoutingMode {
  simpleManhattan,
  obstacleAvoiding,
  advancedOrthogonal,
}

enum ConnectorRouteQuality { fast, balanced, high }

class ConnectorRoutingOptions {
  const ConnectorRoutingOptions({
    this.mode = ConnectorRoutingMode.advancedOrthogonal,
    this.margin = 16,
    this.portLead = 18,
    this.searchPadding = 320,
    this.maxObstacles = 64,
    this.maxLanesPerAxis = 32,
    this.turnPenalty = 24,
    this.nodeCrossingPenalty = 100000,
    this.nodeTouchPenalty = 8,
    this.parallelLineGap = 8,
    this.stabilityPenalty = 18,
    this.previewQuality = ConnectorRouteQuality.fast,
    this.finalQuality = ConnectorRouteQuality.high,
  });

  final ConnectorRoutingMode mode;
  final double margin;
  final double portLead;
  final double searchPadding;
  final int maxObstacles;
  final int maxLanesPerAxis;
  final double turnPenalty;
  final double nodeCrossingPenalty;
  final double nodeTouchPenalty;
  final double parallelLineGap;
  final double stabilityPenalty;
  final ConnectorRouteQuality previewQuality;
  final ConnectorRouteQuality finalQuality;

  ConnectorRoutingOptions forQuality(ConnectorRouteQuality quality) {
    return switch (quality) {
      ConnectorRouteQuality.fast => ConnectorRoutingOptions(
        mode: mode,
        margin: margin,
        portLead: portLead,
        searchPadding: searchPadding * 0.75,
        maxObstacles: (maxObstacles / 2).ceil().clamp(8, maxObstacles),
        maxLanesPerAxis: (maxLanesPerAxis / 2).ceil().clamp(8, maxLanesPerAxis),
        turnPenalty: turnPenalty,
        nodeCrossingPenalty: nodeCrossingPenalty,
        nodeTouchPenalty: nodeTouchPenalty,
        parallelLineGap: parallelLineGap,
        stabilityPenalty: stabilityPenalty,
        previewQuality: previewQuality,
        finalQuality: finalQuality,
      ),
      ConnectorRouteQuality.balanced => ConnectorRoutingOptions(
        mode: mode,
        margin: margin,
        portLead: portLead,
        searchPadding: searchPadding,
        maxObstacles: (maxObstacles * 0.75).ceil().clamp(8, maxObstacles),
        maxLanesPerAxis: (maxLanesPerAxis * 0.75).ceil().clamp(
          8,
          maxLanesPerAxis,
        ),
        turnPenalty: turnPenalty,
        nodeCrossingPenalty: nodeCrossingPenalty,
        nodeTouchPenalty: nodeTouchPenalty,
        parallelLineGap: parallelLineGap,
        stabilityPenalty: stabilityPenalty,
        previewQuality: previewQuality,
        finalQuality: finalQuality,
      ),
      ConnectorRouteQuality.high => this,
    };
  }
}

enum ConnectorSide { left, right, top, bottom, center, free }

class ConnectorPort {
  const ConnectorPort({
    required this.position,
    required this.side,
    required this.normal,
    this.elementId,
    this.anchorId,
    this.bounds,
    this.locked = false,
  });

  final Offset position;
  final ConnectorSide side;
  final Offset normal;
  final String? elementId;
  final String? anchorId;
  final Rect? bounds;
  final bool locked;
}

enum RoutingObstacleKind { node, widget, label, connectorLabel, temporary }

class RoutingObstacle {
  const RoutingObstacle({
    required this.id,
    required this.bounds,
    this.kind = RoutingObstacleKind.node,
    this.margin = 0,
    this.cost = 1,
  });

  final String id;
  final Rect bounds;
  final RoutingObstacleKind kind;
  final double margin;
  final double cost;

  Rect inflated(double defaultMargin) => bounds.inflate(defaultMargin + margin);
}

enum ConnectorRouteStrategy {
  directOrthogonal,
  visibilityGraph,
  candidateFallback,
  straightFallback,
}

class ConnectorRouteResult {
  const ConnectorRouteResult({
    required this.points,
    required this.score,
    required this.strategy,
    this.usedFallback = false,
  });

  final List<Offset> points;
  final double score;
  final ConnectorRouteStrategy strategy;
  final bool usedFallback;
}

class ConnectorPortResolver {
  const ConnectorPortResolver();

  ConnectorPort resolve({
    required Offset position,
    required Offset toward,
    SnapBinding? binding,
    Rect? bounds,
  }) {
    final anchorId = binding?.anchorId;
    final side = _sideForAnchor(anchorId, position, toward, bounds);
    return ConnectorPort(
      position: position,
      side: side,
      normal: _normalForSide(side, position, toward, bounds),
      elementId: binding?.elementId,
      anchorId: anchorId,
      bounds: bounds,
      locked: binding != null,
    );
  }

  ConnectorSide _sideForAnchor(
    String? anchorId,
    Offset position,
    Offset toward,
    Rect? bounds,
  ) {
    return switch (anchorId) {
      'left' => ConnectorSide.left,
      'right' => ConnectorSide.right,
      'top' => ConnectorSide.top,
      'bottom' => ConnectorSide.bottom,
      'topLeft' || 'bottomLeft' => _cornerSide(
        horizontal: ConnectorSide.left,
        vertical: anchorId == 'topLeft'
            ? ConnectorSide.top
            : ConnectorSide.bottom,
        position: position,
        toward: toward,
      ),
      'topRight' || 'bottomRight' => _cornerSide(
        horizontal: ConnectorSide.right,
        vertical: anchorId == 'topRight'
            ? ConnectorSide.top
            : ConnectorSide.bottom,
        position: position,
        toward: toward,
      ),
      'center' => ConnectorSide.center,
      _ =>
        bounds == null
            ? ConnectorSide.free
            : _nearestSide(position, toward, bounds),
    };
  }

  ConnectorSide _cornerSide({
    required ConnectorSide horizontal,
    required ConnectorSide vertical,
    required Offset position,
    required Offset toward,
  }) {
    final delta = toward - position;
    return delta.dx.abs() >= delta.dy.abs() ? horizontal : vertical;
  }

  ConnectorSide _nearestSide(Offset position, Offset toward, Rect bounds) {
    final distances = <ConnectorSide, double>{
      ConnectorSide.left: (position.dx - bounds.left).abs(),
      ConnectorSide.right: (position.dx - bounds.right).abs(),
      ConnectorSide.top: (position.dy - bounds.top).abs(),
      ConnectorSide.bottom: (position.dy - bounds.bottom).abs(),
    };
    final nearest = distances.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    if (nearest.first.value <= 0.001) {
      return nearest.first.key;
    }
    final delta = toward - position;
    if (delta.dx.abs() >= delta.dy.abs()) {
      return delta.dx >= 0 ? ConnectorSide.right : ConnectorSide.left;
    }
    return delta.dy >= 0 ? ConnectorSide.bottom : ConnectorSide.top;
  }

  Offset _normalForSide(
    ConnectorSide side,
    Offset position,
    Offset toward,
    Rect? bounds,
  ) {
    return switch (side) {
      ConnectorSide.left => const Offset(-1, 0),
      ConnectorSide.right => const Offset(1, 0),
      ConnectorSide.top => const Offset(0, -1),
      ConnectorSide.bottom => const Offset(0, 1),
      ConnectorSide.center ||
      ConnectorSide.free => _freeNormal(position, toward, bounds),
    };
  }

  Offset _freeNormal(Offset position, Offset toward, Rect? bounds) {
    final origin = bounds?.center ?? position;
    final delta = toward - origin;
    if (delta.distance <= 0.0001) {
      return Offset.zero;
    }
    if (delta.dx.abs() >= delta.dy.abs()) {
      return Offset(delta.dx >= 0 ? 1 : -1, 0);
    }
    return Offset(0, delta.dy >= 0 ? 1 : -1);
  }
}

class ConnectorRoutingService {
  const ConnectorRoutingService({
    this.options = const ConnectorRoutingOptions(),
    this.portResolver = const ConnectorPortResolver(),
  });

  final ConnectorRoutingOptions options;
  final ConnectorPortResolver portResolver;

  ConnectorRouteResult route({
    required Offset start,
    required Offset end,
    required Iterable<CanvasElement> elements,
    required bool Function(String layerId) isLayerVisible,
    bool Function(String layerId)? isLayerLocked,
    SnapBinding? startBinding,
    SnapBinding? endBinding,
    String? connectorId,
    List<Offset>? previousRoute,
    ConnectorRouteQuality quality = ConnectorRouteQuality.high,
  }) {
    final tuned = options.forQuality(quality);
    if (tuned.mode == ConnectorRoutingMode.simpleManhattan) {
      final points = _simpleManhattan(start, end);
      return ConnectorRouteResult(
        points: points,
        score: _pathLength(points),
        strategy: ConnectorRouteStrategy.directOrthogonal,
      );
    }

    final byId = {for (final element in elements) element.id: element};
    final sourceBounds = _boundsForBinding(
      byId,
      startBinding,
      isLayerVisible,
      isLayerLocked,
    );
    final targetBounds = _boundsForBinding(
      byId,
      endBinding,
      isLayerVisible,
      isLayerLocked,
    );
    final sourcePort = portResolver.resolve(
      position: start,
      toward: end,
      binding: startBinding,
      bounds: sourceBounds,
    );
    final targetPort = portResolver.resolve(
      position: end,
      toward: start,
      binding: endBinding,
      bounds: targetBounds,
    );
    final queryRect = Rect.fromPoints(start, end).inflate(tuned.searchPadding);
    final obstacles = routingObstacles(
      elements: elements,
      isLayerVisible: isLayerVisible,
      queryRect: queryRect,
      excludeIds: {connectorId, startBinding?.elementId, endBinding?.elementId},
    );

    final points = OrthogonalRouteEngine.route(
      start: start,
      end: end,
      sourceBounds: sourceBounds,
      targetBounds: targetBounds,
      obstacles: [for (final obstacle in obstacles) obstacle.bounds],
      margin: tuned.margin,
      preferredStartDirection: sourcePort.locked ? sourcePort.normal : null,
      preferredEndDirection: targetPort.locked ? targetPort.normal : null,
      preferredStartPoint: sourcePort.position,
      preferredEndPoint: targetPort.position,
      searchPadding: tuned.searchPadding,
      maxObstacles: tuned.maxObstacles,
      maxLanesPerAxis: tuned.maxLanesPerAxis,
      turnPenalty: tuned.turnPenalty,
      nodeTouchPenalty: tuned.nodeTouchPenalty,
      previousRoute: previousRoute,
      stabilityPenalty: tuned.stabilityPenalty,
    );
    return ConnectorRouteResult(
      points: points,
      score: _pathLength(points),
      strategy: ConnectorRouteStrategy.visibilityGraph,
    );
  }

  Iterable<RoutingObstacle> routingObstacles({
    required Iterable<CanvasElement> elements,
    required bool Function(String layerId) isLayerVisible,
    required Rect queryRect,
    Set<String?> excludeIds = const <String?>{},
  }) sync* {
    for (final element in elements) {
      if (element is LineElement || element is ArrowElement || element is PolylineElement) {
        continue;
      }
      if (!element.visible ||
          !isLayerVisible(element.layerId) ||
          excludeIds.contains(element.id) ||
          element.bounds.isEmpty ||
          !element.bounds.overlaps(queryRect)) {
        continue;
      }
      yield RoutingObstacle(id: element.id, bounds: element.bounds);
    }
  }

  Rect? _boundsForBinding(
    Map<String, CanvasElement> elementsById,
    SnapBinding? binding,
    bool Function(String layerId) isLayerVisible,
    bool Function(String layerId)? isLayerLocked,
  ) {
    if (binding == null) {
      return null;
    }
    final target = elementsById[binding.elementId];
    if (target == null ||
        !target.visible ||
        !isLayerVisible(target.layerId) ||
        (isLayerLocked?.call(target.layerId) ?? false)) {
      return null;
    }
    return target.bounds;
  }

  List<Offset> _simpleManhattan(Offset start, Offset end) {
    if ((start.dx - end.dx).abs() < 0.0001 ||
        (start.dy - end.dy).abs() < 0.0001) {
      return [start, end];
    }
    return [start, Offset(end.dx, start.dy), end];
  }

  double _pathLength(List<Offset> points) {
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    return total;
  }
}

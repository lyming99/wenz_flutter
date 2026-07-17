import 'package:flutter/widgets.dart';

import '../elements/arrow_element.dart';
import '../elements/canvas_element.dart';
import '../elements/drawio_shape_element.dart';
import '../elements/line_element.dart';
import '../elements/polyline_element.dart';
import '../snap/snap_resolver.dart';
import '../utils/orthogonal_router.dart';
import 'elbow_router.dart';
import 'orth_connector.dart';
import 'perimeter.dart';
import 'segment_connector.dart';

/// 连接器路由模式。
enum ConnectorRoutingMode {
  /// 简单曼哈顿（两拐点，无避障）
  simpleManhattan,

  /// draw.io 风格自动肘形（SideToSide / TopToBottom）
  elbowStandard,

  /// 带避障的 A* 网格搜索 + draw.io 启发式
  obstacleAvoiding,

  /// 完整高级正交路由（A* 搜索 + 多候选回退）
  advancedOrthogonal,

  /// 纯查表正交路由（OrthConnector，源自 draw.io OrthConnector）
  orthConnector,

  /// 用户控制点的分段正交路由（SegmentConnector）
  segmentConnector,
}

enum ConnectorRouteQuality { fast, balanced, high }

/// 连接器路由选项。
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
    if (quality == ConnectorRouteQuality.fast) {
      return ConnectorRoutingOptions(
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
      );
    } else if (quality == ConnectorRouteQuality.balanced) {
      return ConnectorRoutingOptions(
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
      );
    }
    return this;
  }
}

/// 连接器端口方向。
enum ConnectorSide { left, right, top, bottom, center, free }

/// 连接器端口——描述连线在图形边界上的附着位置。
class ConnectorPort {
  const ConnectorPort({
    required this.position,
    required this.side,
    required this.normal,
    this.elementId,
    this.anchorId,
    this.bounds,
    this.locked = false,
    this.fixed = false,
  });

  /// 端口在图形边界上的绝对位置。
  final Offset position;

  /// 端口位于图形的哪一侧。
  final ConnectorSide side;

  /// 端口处的法向量（指向图形外部）。
  final Offset normal;

  final String? elementId;
  final String? anchorId;
  final Rect? bounds;
  final bool locked;

  /// 是否为固定端点（不可被路由引擎移动）。
  final bool fixed;
}

/// 路由中的障碍物。
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
  elbowStandard,
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

/// 端口解析器——使用 [WenzPerimeter] 计算连接器与图形边界的接触点。
class ConnectorPortResolver {
  const ConnectorPortResolver();

  /// 解析端口。
  ConnectorPort resolve({
    required Offset position,
    required Offset toward,
    SnapBinding? binding,
    Rect? bounds,
    String shapeType = 'rectangle',
    String direction = 'east',
  }) {
    final anchorId = binding?.anchorId;
    final side = _effectiveSide(
      _sideForAnchor(anchorId, position, toward, bounds),
      anchorId: anchorId,
      position: position,
      toward: toward,
      bounds: bounds,
      shapeType: shapeType,
    );

    // 固定连接点：用户明确绑定了某个锢点（anchorId 非空）。
    // 与 draw.io 一致：端点坐标恒定为锢点位置，不随对端移动而滑动。
    // 这里 position 已经是 snapResolver 解析出的精确锢点坐标。
    if (binding?.anchorId != null &&
        side != ConnectorSide.center &&
        anchorId != 'center') {
      return ConnectorPort(
        position: position,
        side: side,
        normal: _normalForSide(side, position, toward, bounds),
        elementId: binding?.elementId,
        anchorId: anchorId,
        bounds: bounds,
        locked: true,
        fixed: true,
      );
    }

    if (bounds != null &&
        side != ConnectorSide.center &&
        side != ConnectorSide.free) {
      final perimeterPoint = WenzPerimeter.computePerimeter(
        bounds,
        toward,
        orthogonal: true,
        shapeType: shapeType,
        direction: direction,
      );
      return ConnectorPort(
        position: perimeterPoint,
        side: side,
        normal: _normalForSide(side, perimeterPoint, toward, bounds),
        elementId: binding?.elementId,
        anchorId: anchorId,
        bounds: bounds,
        locked: binding != null,
      );
    }

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

  ConnectorSide _effectiveSide(
    ConnectorSide side, {
    required String? anchorId,
    required Offset position,
    required Offset toward,
    required Rect? bounds,
    required String shapeType,
  }) {
    if (anchorId == 'center' && bounds != null) {
      return shapeType == 'rectangle'
          ? side
          : _nearestSide(position, toward, bounds);
    }
    return side;
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
    final (side, _) = WenzPerimeter.nearestSide(bounds, toward);
    return switch (side) {
      'left' => ConnectorSide.left,
      'right' => ConnectorSide.right,
      'top' => ConnectorSide.top,
      'bottom' => ConnectorSide.bottom,
      _ => ConnectorSide.center,
    };
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
    if (delta.distance <= 0.0001) return Offset.zero;
    if (delta.dx.abs() >= delta.dy.abs()) {
      return Offset(delta.dx >= 0 ? 1 : -1, 0);
    }
    return Offset(0, delta.dy >= 0 ? 1 : -1);
  }
}

/// 连接器路由服务——连接器路由的主入口。
///
/// 整合多种路由策略：
/// 1. [ConnectorRoutingMode.simpleManhattan] → 简单两拐点
/// 2. [ConnectorRoutingMode.elbowStandard] → ElbowRouter
/// 3. [ConnectorRoutingMode.orthConnector] → OrthConnector (draw.io 查表法)
/// 4. [ConnectorRoutingMode.segmentConnector] → SegmentConnector (控制点)
/// 5. [ConnectorRoutingMode.advancedOrthogonal] → A* 网格搜索（默认）
/// 6. [ConnectorRoutingMode.obstacleAvoiding] → A* 网格搜索
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
    List<Offset>? segmentControlPoints,
  }) {
    final tuned = options.forQuality(quality);

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
    final sourceShape = _shapeTypeForBinding(byId, startBinding);
    final targetShape = _shapeTypeForBinding(byId, endBinding);
    final sourceDirection = _shapeDirectionForBinding(byId, startBinding);
    final targetDirection = _shapeDirectionForBinding(byId, endBinding);
    final sourcePort = portResolver.resolve(
      position: start,
      toward: end,
      binding: startBinding,
      bounds: sourceBounds,
      shapeType: sourceShape,
      direction: sourceDirection,
    );
    final targetPort = portResolver.resolve(
      position: end,
      toward: start,
      binding: endBinding,
      bounds: targetBounds,
      shapeType: targetShape,
      direction: targetDirection,
    );

    // 简单曼哈顿模式
    if (tuned.mode == ConnectorRoutingMode.simpleManhattan) {
      final points = _simpleManhattan(sourcePort.position, targetPort.position);
      return ConnectorRouteResult(
        points: points,
        score: _pathLength(points),
        strategy: ConnectorRouteStrategy.directOrthogonal,
      );
    }

    // 分段连接器模式
    if (tuned.mode == ConnectorRoutingMode.segmentConnector) {
      final points = SegmentConnector.route(
        start: sourcePort.position,
        end: targetPort.position,
        sourceBounds: sourceBounds,
        targetBounds: targetBounds,
        controlPoints: segmentControlPoints ?? const [],
      );
      return ConnectorRouteResult(
        points: points,
        score: _pathLength(points),
        strategy: ConnectorRouteStrategy.elbowStandard,
      );
    }

    // 肘形模式
    if (tuned.mode == ConnectorRoutingMode.elbowStandard) {
      final points = ElbowRouter.elbowConnector(
        start: sourcePort.position,
        end: targetPort.position,
        sourceBounds: sourceBounds,
        targetBounds: targetBounds,
        margin: tuned.margin,
      );
      return ConnectorRouteResult(
        points: points,
        score: _pathLength(points),
        strategy: ConnectorRouteStrategy.elbowStandard,
      );
    }

    // 纯 OrthConnector 模式 —— draw.io 查表正交路由
    if (tuned.mode == ConnectorRoutingMode.orthConnector) {
      final points = OrthConnector.route(
        start: sourcePort.position,
        end: targetPort.position,
        sourceBounds: sourceBounds,
        targetBounds: targetBounds,
        margin: tuned.margin,
        sourcePortConstraint: _portConstraintMask(sourcePort),
        targetPortConstraint: _portConstraintMask(targetPort),
        sourceFixed: startBinding?.anchorId != null,
        targetFixed: endBinding?.anchorId != null,
      );
      return ConnectorRouteResult(
        points: points,
        score: _pathLength(points),
        strategy: ConnectorRouteStrategy.directOrthogonal,
      );
    }

    // advancedOrthogonal / obstacleAvoiding：使用 A* 网格搜索
    final queryRect = Rect.fromPoints(start, end).inflate(tuned.searchPadding);
    final obstacles = routingObstacles(
      elements: elements,
      isLayerVisible: isLayerVisible,
      queryRect: queryRect,
      excludeIds: {connectorId, startBinding?.elementId, endBinding?.elementId},
    );

    final points = OrthogonalRouteEngine.route(
      start: sourcePort.position,
      end: targetPort.position,
      sourceBounds: sourceBounds,
      targetBounds: targetBounds,
      obstacles: [for (final o in obstacles) o.bounds],
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
      if (element is LineElement ||
          element is ArrowElement ||
          element is PolylineElement) {
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
    if (binding == null) return null;
    final target = elementsById[binding.elementId];
    if (target == null ||
        !target.visible ||
        !isLayerVisible(target.layerId) ||
        (isLayerLocked?.call(target.layerId) ?? false)) {
      return null;
    }
    if (target is DrawioShapeElement) {
      return target.rect;
    }
    return target.bounds;
  }

  String _shapeTypeForBinding(
    Map<String, CanvasElement> elementsById,
    SnapBinding? binding,
  ) {
    if (binding == null) return 'rectangle';
    final target = elementsById[binding.elementId];
    if (target is DrawioShapeElement) {
      return target.shapeKey;
    }
    return 'rectangle';
  }

  String _shapeDirectionForBinding(
    Map<String, CanvasElement> elementsById,
    SnapBinding? binding,
  ) {
    if (binding == null) return 'east';
    final target = elementsById[binding.elementId];
    if (target is DrawioShapeElement) {
      final direction = target.properties['direction'];
      if (direction is String) {
        return direction;
      }
    }
    return 'east';
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

  /// 将端口侧转换为 OrthConnector 的方向位掩码（WEST=1/NORTH=2/SOUTH=4/EAST=8）。
  /// 仅在端口锁定（固定连接点）时返回约束，否则返回 null（不限制）。
  static int? _portConstraintMask(ConnectorPort port) {
    if (!port.locked) return null;
    return switch (port.side) {
      ConnectorSide.left => 1,
      ConnectorSide.top => 2,
      ConnectorSide.bottom => 4,
      ConnectorSide.right => 8,
      ConnectorSide.center || ConnectorSide.free => null,
    };
  }
}

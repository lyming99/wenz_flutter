import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../config/responsive_config.dart';
import '../models/diagram.dart';
import '../models/node.dart';
import '../models/style.dart';
import 'layout_engine.dart';

/// Layout engine for Mermaid mindmap diagrams.
class MindmapLayout extends LayoutEngine {
  /// Creates a mindmap layout engine.
  const MindmapLayout({this.deviceConfig});

  /// Responsive device configuration.
  final MermaidDeviceConfig? deviceConfig;

  @override
  Size computeLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (diagram.nodes.isEmpty) return Size.zero;

    final graph = _buildGraph(diagram);
    final rootId = graph.rootId;
    if (rootId == null) return Size.zero;

    final horizontalGap = _horizontalGap(style);
    final verticalGap = _verticalGap(style);

    for (final node in diagram.nodes) {
      final size = _measureMindmapNode(node, style, availableSize);
      node.width = size.width;
      node.height = size.height;
    }

    final extents = <String, double>{};
    double computeExtent(String nodeId) {
      if (extents.containsKey(nodeId)) return extents[nodeId]!;

      final node = graph.nodeMap[nodeId]!;
      final children = graph.childrenByParent[nodeId] ?? const <String>[];
      if (children.isEmpty) {
        extents[nodeId] = node.height;
        return node.height;
      }

      final childExtent = _clusterExtent(
        children,
        extents,
        verticalGap,
        computeExtent,
      );
      final value = math.max(node.height, childExtent);
      extents[nodeId] = value;
      return value;
    }

    computeExtent(rootId);

    final rootNode = graph.nodeMap[rootId]!;
    rootNode.rank = 0;
    rootNode.order = 0;
    rootNode.x = -rootNode.width / 2;
    rootNode.y = -rootNode.height / 2;

    final rootChildren = graph.childrenByParent[rootId] ?? const <String>[];
    final split = _splitRootChildren(rootChildren, extents, computeExtent);

    _placeCluster(
      parentId: rootId,
      childIds: split.right,
      direction: 1,
      centerY: 0,
      horizontalGap: horizontalGap,
      verticalGap: verticalGap,
      graph: graph,
      extents: extents,
      computeExtent: computeExtent,
      depth: 1,
    );
    _placeCluster(
      parentId: rootId,
      childIds: split.left,
      direction: -1,
      centerY: 0,
      horizontalGap: horizontalGap,
      verticalGap: verticalGap,
      graph: graph,
      extents: extents,
      computeExtent: computeExtent,
      depth: 1,
    );

    final bounds = computeNodeBounds(diagram.nodes);
    if (bounds == Rect.zero) return Size.zero;

    final dx = style.padding - bounds.left;
    final dy = style.padding - bounds.top;
    for (final node in diagram.nodes) {
      node.x += dx;
      node.y += dy;
    }

    return Size(
      math.max(bounds.width + style.padding * 2, 1),
      math.max(bounds.height + style.padding * 2, 1),
    );
  }

  _MindmapGraph _buildGraph(MermaidDiagramData diagram) {
    final nodeMap = {for (final node in diagram.nodes) node.id: node};
    final childrenByParent = <String, List<String>>{
      for (final node in diagram.nodes) node.id: <String>[],
    };
    final incomingCount = <String, int>{
      for (final node in diagram.nodes) node.id: 0,
    };

    for (final edge in diagram.edges) {
      if (!nodeMap.containsKey(edge.from) || !nodeMap.containsKey(edge.to)) {
        continue;
      }
      childrenByParent[edge.from]!.add(edge.to);
      incomingCount[edge.to] = (incomingCount[edge.to] ?? 0) + 1;
    }

    final roots = diagram.nodes
        .where((node) => (incomingCount[node.id] ?? 0) == 0)
        .map((node) => node.id)
        .toList();

    return _MindmapGraph(
      rootId: roots.isNotEmpty
          ? roots.first
          : (diagram.nodes.isNotEmpty ? diagram.nodes.first.id : null),
      nodeMap: nodeMap,
      childrenByParent: childrenByParent,
    );
  }

  Size _measureMindmapNode(
    MermaidNode node,
    MermaidStyle style,
    Size availableSize,
  ) {
    final nodeStyle = style.getNodeStyle(node.className);
    final horizontalPadding = _horizontalPadding(node.shape);
    final verticalPadding = _verticalPadding(node.shape);
    final maxNodeWidth = _maxNodeWidth(availableSize);

    final textStyle = TextStyle(
      fontSize: nodeStyle.fontSize,
      fontWeight: nodeStyle.fontWeight,
      fontFamily: style.fontFamily,
      height: 1.2,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: node.label, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 6,
      ellipsis: '...',
    )..layout(maxWidth: math.max(maxNodeWidth - horizontalPadding, 48));

    var width = textPainter.width + horizontalPadding;
    var height = textPainter.height + verticalPadding;

    switch (node.shape) {
      case NodeShape.circle:
      case NodeShape.doubleCircle:
        final diameter = math.max(width, height);
        width = diameter;
        height = diameter;
        break;
      case NodeShape.hexagon:
        width += 18;
        break;
      case NodeShape.roundedRect:
        width = math.max(width, 88);
        break;
      default:
        width = math.max(width, 72);
        break;
    }

    return Size(
      width.clamp(72.0, 400.0).toDouble(),
      height.clamp(44.0, 280.0).toDouble(),
    );
  }

  double _maxNodeWidth(Size availableSize) {
    var preferred = 220.0;
    switch (deviceConfig?.deviceType) {
      case DeviceType.mobile:
        preferred = 180.0;
        break;
      case DeviceType.tablet:
        preferred = 220.0;
        break;
      case DeviceType.desktop:
        preferred = 260.0;
        break;
      case null:
        break;
    }

    if (availableSize.width.isFinite && availableSize.width > 0) {
      preferred = math.min(
        preferred,
        math.max(140.0, availableSize.width * 0.32),
      );
    }

    return preferred;
  }

  double _horizontalGap(MermaidStyle style) {
    return math.max(style.nodeSpacingX * 1.4, 90.0);
  }

  double _verticalGap(MermaidStyle style) {
    return math.max(style.nodeSpacingY * 0.55, 18.0);
  }

  double _horizontalPadding(NodeShape shape) {
    switch (shape) {
      case NodeShape.circle:
      case NodeShape.doubleCircle:
        return 36.0;
      case NodeShape.hexagon:
        return 38.0;
      case NodeShape.roundedRect:
        return 30.0;
      default:
        return 24.0;
    }
  }

  double _verticalPadding(NodeShape shape) {
    switch (shape) {
      case NodeShape.circle:
      case NodeShape.doubleCircle:
        return 32.0;
      case NodeShape.hexagon:
        return 26.0;
      default:
        return 18.0;
    }
  }

  double _clusterExtent(
    List<String> childIds,
    Map<String, double> extents,
    double verticalGap,
    double Function(String nodeId) computeExtent,
  ) {
    if (childIds.isEmpty) return 0;

    var total = 0.0;
    for (var i = 0; i < childIds.length; i++) {
      final childId = childIds[i];
      final extent = extents[childId] ?? computeExtent(childId);
      if (i > 0) total += verticalGap;
      total += extent;
    }
    return total;
  }

  _BranchSplit _splitRootChildren(
    List<String> childIds,
    Map<String, double> extents,
    double Function(String nodeId) computeExtent,
  ) {
    final left = <String>[];
    final right = <String>[];
    var leftTotal = 0.0;
    var rightTotal = 0.0;

    for (final childId in childIds) {
      final extent = extents[childId] ?? computeExtent(childId);
      if (right.isEmpty || rightTotal <= leftTotal) {
        right.add(childId);
        rightTotal += extent;
      } else {
        left.add(childId);
        leftTotal += extent;
      }
    }

    return _BranchSplit(left: left, right: right);
  }

  void _placeCluster({
    required String parentId,
    required List<String> childIds,
    required int direction,
    required double centerY,
    required double horizontalGap,
    required double verticalGap,
    required _MindmapGraph graph,
    required Map<String, double> extents,
    required double Function(String nodeId) computeExtent,
    required int depth,
  }) {
    if (childIds.isEmpty) return;

    final totalExtent = _clusterExtent(
      childIds,
      extents,
      verticalGap,
      computeExtent,
    );
    var cursor = centerY - totalExtent / 2;

    for (var i = 0; i < childIds.length; i++) {
      final childId = childIds[i];
      final extent = extents[childId] ?? computeExtent(childId);
      final childCenterY = cursor + extent / 2;
      _placeSubtree(
        nodeId: childId,
        parentId: parentId,
        direction: direction,
        centerY: childCenterY,
        siblingOrder: i,
        horizontalGap: horizontalGap,
        verticalGap: verticalGap,
        graph: graph,
        extents: extents,
        computeExtent: computeExtent,
        depth: depth,
      );
      cursor += extent + verticalGap;
    }
  }

  void _placeSubtree({
    required String nodeId,
    required String parentId,
    required int direction,
    required double centerY,
    required int siblingOrder,
    required double horizontalGap,
    required double verticalGap,
    required _MindmapGraph graph,
    required Map<String, double> extents,
    required double Function(String nodeId) computeExtent,
    required int depth,
  }) {
    final node = graph.nodeMap[nodeId]!;
    final parent = graph.nodeMap[parentId]!;

    node.rank = depth;
    node.order = siblingOrder;
    node.y = centerY - node.height / 2;
    if (direction >= 0) {
      node.x = parent.x + parent.width + horizontalGap;
    } else {
      node.x = parent.x - horizontalGap - node.width;
    }

    final childIds = graph.childrenByParent[nodeId] ?? const <String>[];
    if (childIds.isEmpty) return;

    final totalExtent = _clusterExtent(
      childIds,
      extents,
      verticalGap,
      computeExtent,
    );
    var cursor = centerY - totalExtent / 2;

    for (var i = 0; i < childIds.length; i++) {
      final childId = childIds[i];
      final extent = extents[childId] ?? computeExtent(childId);
      final childCenterY = cursor + extent / 2;
      _placeSubtree(
        nodeId: childId,
        parentId: nodeId,
        direction: direction,
        centerY: childCenterY,
        siblingOrder: i,
        horizontalGap: horizontalGap,
        verticalGap: verticalGap,
        graph: graph,
        extents: extents,
        computeExtent: computeExtent,
        depth: depth + 1,
      );
      cursor += extent + verticalGap;
    }
  }
}

class _MindmapGraph {
  const _MindmapGraph({
    required this.rootId,
    required this.nodeMap,
    required this.childrenByParent,
  });

  final String? rootId;
  final Map<String, MermaidNode> nodeMap;
  final Map<String, List<String>> childrenByParent;
}

class _BranchSplit {
  const _BranchSplit({required this.left, required this.right});

  final List<String> left;
  final List<String> right;
}
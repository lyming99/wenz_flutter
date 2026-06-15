import 'dart:ui';

import 'mindmap_node.dart';
import 'mindmap_node_metrics.dart';

/// Layout configuration for mind map nodes.
class MindmapLayoutConfig {
  const MindmapLayoutConfig({
    this.nodeWidth = MindmapNodeMetrics.minNodeWidth,
    this.nodeHeight = MindmapNodeMetrics.nodeHeight,
    this.rootNodeWidth = MindmapNodeMetrics.minRootWidth,
    this.rootNodeHeight = MindmapNodeMetrics.rootHeight,
    this.maxNodeWidth = MindmapNodeMetrics.maxNodeWidth,
    this.maxRootNodeWidth = MindmapNodeMetrics.maxRootWidth,
    this.horizontalGap = 50,
    this.siblingGap = 12,
  });

  final double nodeWidth;
  final double nodeHeight;
  final double rootNodeWidth;
  final double rootNodeHeight;
  final double maxNodeWidth;
  final double maxRootNodeWidth;

  /// Edge-to-edge horizontal gap between parent and child nodes.
  final double horizontalGap;
  final double siblingGap;

  double widthForNode(MindmapNode node, {required bool isRoot}) {
    return MindmapNodeMetrics.widthForText(
      node.text,
      isRoot: isRoot,
      minWidth: isRoot ? rootNodeWidth : nodeWidth,
      maxWidth: isRoot ? maxRootNodeWidth : maxNodeWidth,
    );
  }
}

/// Layout result for a single node.
class MindmapLayoutNode {
  const MindmapLayoutNode({
    required this.node,
    required this.rect,
    required this.depth,
    this.expandedChildren = const [],
  });

  final MindmapNode node;
  final Rect rect;
  final int depth;
  final List<MindmapLayoutNode> expandedChildren;

  Offset get center => rect.center;
  Offset get rightCenter => Offset(rect.right, rect.center.dy);
  Offset get leftCenter => Offset(rect.left, rect.center.dy);
}

/// A merge point where a parent's connection trunk meets branches to children.
class MindmapMergePoint {
  const MindmapMergePoint({
    required this.position,
    required this.parentNodeId,
    required this.side,
    required this.isCollapsed,
    required this.childCount,
    required this.parentEdge,
    required this.childEdges,
  });

  /// Screen position of the merge point.
  final Offset position;

  /// ID of the parent node this merge point belongs to.
  final String parentNodeId;

  /// Which side of the parent (left/right).
  final MindmapNodeSide side;

  /// Whether the parent's children are collapsed.
  final bool isCollapsed;

  /// Total number of children (for display when collapsed).
  final int childCount;

  /// Where the trunk starts (parent edge center).
  final Offset parentEdge;

  /// Where each branch ends (child edge centers).
  /// Empty when collapsed.
  final List<Offset> childEdges;
}

/// Two-pass mind map layout engine.
class MindmapLayout {
  static ({MindmapLayoutNode root, Size totalSize}) calculate(
    MindmapNode root, {
    MindmapLayoutConfig config = const MindmapLayoutConfig(),
  }) {
    final rightChildren = root.children
        .where((c) => c.side != MindmapNodeSide.left)
        .toList();
    final leftChildren = root.children
        .where((c) => c.side == MindmapNodeSide.left)
        .toList();

    final rootRect = Rect.fromCenter(
      center: Offset.zero,
      width: config.widthForNode(root, isRoot: true),
      height: config.rootNodeHeight,
    );

    final rightNodes = <MindmapLayoutNode>[];
    final leftNodes = <MindmapLayoutNode>[];

    // Only lay out children when the root is NOT collapsed
    if (!root.isCollapsed) {
      if (rightChildren.isNotEmpty) {
        final rightHeight = _totalSubtreeHeight(rightChildren, config);
        double y = -rightHeight / 2;
        for (final child in rightChildren) {
          final subH = _subtreeHeight(child, config);
          final childWidth = config.widthForNode(child, isRoot: false);
          rightNodes.add(
            _layoutSubtree(
              child,
              rootRect.right + config.horizontalGap + childWidth / 2,
              y + subH / 2,
              1,
              MindmapNodeSide.right,
              config,
            ),
          );
          y += subH + config.siblingGap;
        }
      }

      if (leftChildren.isNotEmpty) {
        final leftHeight = _totalSubtreeHeight(leftChildren, config);
        double y = -leftHeight / 2;
        for (final child in leftChildren) {
          final subH = _subtreeHeight(child, config);
          final childWidth = config.widthForNode(child, isRoot: false);
          leftNodes.add(
            _layoutSubtree(
              child,
              rootRect.left - config.horizontalGap - childWidth / 2,
              y + subH / 2,
              1,
              MindmapNodeSide.left,
              config,
            ),
          );
          y += subH + config.siblingGap;
        }
      }
    }

    final rootLayout = MindmapLayoutNode(
      node: root,
      rect: rootRect,
      depth: 0,
      expandedChildren: [...rightNodes, ...leftNodes],
    );

    final bounds = _boundsOf(rootLayout);
    const padding = 40.0;
    final totalSize = Size(bounds.width + padding, bounds.height + padding);

    return (root: rootLayout, totalSize: totalSize);
  }

  static double _totalSubtreeHeight(
    List<MindmapNode> children,
    MindmapLayoutConfig config,
  ) {
    if (children.isEmpty) return 0;
    double h = 0;
    for (final child in children) {
      h += _subtreeHeight(child, config);
    }
    h += config.siblingGap * (children.length - 1);
    return h;
  }

  static double _subtreeHeight(MindmapNode node, MindmapLayoutConfig config) {
    if (node.isCollapsed || node.children.isEmpty) {
      return config.nodeHeight;
    }
    double total = 0;
    for (final child in node.children) {
      total += _subtreeHeight(child, config);
    }
    total += config.siblingGap * (node.children.length - 1);
    return total > config.nodeHeight ? total : config.nodeHeight;
  }

  static MindmapLayoutNode _layoutSubtree(
    MindmapNode node,
    double xCenter,
    double yCenter,
    int depth,
    MindmapNodeSide side,
    MindmapLayoutConfig config,
  ) {
    final w = config.widthForNode(node, isRoot: depth == 0);
    final h = config.nodeHeight;
    final nodeRect = Rect.fromCenter(
      center: Offset(xCenter, yCenter),
      width: w,
      height: h,
    );

    if (node.isCollapsed || node.children.isEmpty) {
      return MindmapLayoutNode(node: node, rect: nodeRect, depth: depth);
    }

    final childrenHeight = _totalSubtreeHeight(node.children, config);
    double y = yCenter - childrenHeight / 2;

    final childNodes = <MindmapLayoutNode>[];
    for (final child in node.children) {
      final subH = _subtreeHeight(child, config);
      final childWidth = config.widthForNode(child, isRoot: false);
      final childX = side == MindmapNodeSide.right
          ? nodeRect.right + config.horizontalGap + childWidth / 2
          : nodeRect.left - config.horizontalGap - childWidth / 2;
      childNodes.add(
        _layoutSubtree(child, childX, y + subH / 2, depth + 1, side, config),
      );
      y += subH + config.siblingGap;
    }

    return MindmapLayoutNode(
      node: node,
      rect: nodeRect,
      depth: depth,
      expandedChildren: childNodes,
    );
  }

  static Rect _boundsOf(MindmapLayoutNode root) {
    var left = root.rect.left;
    var top = root.rect.top;
    var right = root.rect.right;
    var bottom = root.rect.bottom;

    void walk(MindmapLayoutNode n) {
      if (n.rect.left < left) left = n.rect.left;
      if (n.rect.top < top) top = n.rect.top;
      if (n.rect.right > right) right = n.rect.right;
      if (n.rect.bottom > bottom) bottom = n.rect.bottom;
      for (final c in n.expandedChildren) {
        walk(c);
      }
    }

    for (final c in root.expandedChildren) {
      walk(c);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  // ── Merge point computation ──────────────────────────────────────

  /// Compute all merge points for the tree.
  /// A merge point exists for every node that has children in the data model.
  static List<MindmapMergePoint> getMergePoints(
    MindmapLayoutNode root, {
    MindmapLayoutConfig config = const MindmapLayoutConfig(),
  }) {
    final points = <MindmapMergePoint>[];

    void walk(MindmapLayoutNode layoutNode) {
      final node = layoutNode.node;

      if (node.hasChildren) {
        // Determine which sides have children
        final isRoot = layoutNode.depth == 0;
        final sides = isRoot
            ? [MindmapNodeSide.right, MindmapNodeSide.left]
            : [
                node.side == MindmapNodeSide.center
                    ? MindmapNodeSide.right
                    : node.side,
              ];

        for (final side in sides) {
          // Check data model for children on this side
          final hasOnSide = isRoot
              ? (side == MindmapNodeSide.right
                    ? node.children.any((c) => c.side != MindmapNodeSide.left)
                    : node.children.any((c) => c.side == MindmapNodeSide.left))
              : true;

          if (!hasOnSide) continue;

          // Count children on this side
          final countOnSide = isRoot
              ? (side == MindmapNodeSide.right
                    ? node.children
                          .where((c) => c.side != MindmapNodeSide.left)
                          .length
                    : node.children
                          .where((c) => c.side == MindmapNodeSide.left)
                          .length)
              : node.children.length;

          if (countOnSide == 0) continue;

          // Expanded children on this side
          final expandedOnSide = layoutNode.expandedChildren
              .where(
                (c) => side == MindmapNodeSide.right
                    ? c.rect.center.dx >= layoutNode.rect.center.dx
                    : c.rect.center.dx < layoutNode.rect.center.dx,
              )
              .toList();

          // Merge point position: midpoint of the gap
          final mergeX = side == MindmapNodeSide.right
              ? layoutNode.rect.right + config.horizontalGap / 2
              : layoutNode.rect.left - config.horizontalGap / 2;
          final mergeY = layoutNode.rect.center.dy;

          final parentEdge = side == MindmapNodeSide.right
              ? layoutNode.rightCenter
              : layoutNode.leftCenter;

          final childEdges = [
            for (final c in expandedOnSide)
              side == MindmapNodeSide.right ? c.leftCenter : c.rightCenter,
          ];

          points.add(
            MindmapMergePoint(
              position: Offset(mergeX, mergeY),
              parentNodeId: node.id,
              side: side,
              isCollapsed: node.isCollapsed,
              childCount: countOnSide,
              parentEdge: parentEdge,
              childEdges: childEdges,
            ),
          );
        }
      }

      for (final child in layoutNode.expandedChildren) {
        walk(child);
      }
    }

    walk(root);
    return points;
  }

  /// Flatten tree → list of all visible layout nodes.
  static List<MindmapLayoutNode> getAllNodes(MindmapLayoutNode root) {
    final list = <MindmapLayoutNode>[];
    void walk(MindmapLayoutNode n) {
      list.add(n);
      for (final c in n.expandedChildren) {
        walk(c);
      }
    }

    walk(root);
    return list;
  }
}

import 'dart:ui';

import 'mindmap_node.dart';
import 'mindmap_node_metrics.dart';
import 'mindmap_tree.dart';

/// Layout configuration for the non-component mind map.
///
/// Node sizes here MUST match the rendering sizes used by
/// [MindmapNodeBuilder] so that laid-out rects match the drawn footprint.
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

  double widthForNode(MindmapTreeNode node) {
    final isRoot = node.depth == 0 || node.data.isRoot;
    return MindmapNodeMetrics.widthForText(
      node.data.text,
      isRoot: isRoot,
      minWidth: isRoot ? rootNodeWidth : nodeWidth,
      maxWidth: isRoot ? maxRootNodeWidth : maxNodeWidth,
    );
  }
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

  /// World position of the merge point.
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

/// Result of laying out one tree: absolute world rects per node id, plus the
/// computed merge points for connection drawing.
class MindmapLayoutResult {
  const MindmapLayoutResult({required this.rects, required this.mergePoints});

  /// nodeId → absolute world rect.
  final Map<String, Rect> rects;

  /// Merge points for this tree.
  final List<MindmapMergePoint> mergePoints;
}

/// Two-pass mind map layout engine for the non-component mode.
///
/// Computes absolute world rects for every visible node, anchored at the
/// root's current center. Sizes and gaps use fixed world units (from
/// [MindmapLayoutConfig]) — exactly like other canvas elements (rectangles,
/// ellipses, …). The canvas zoom then scales the whole tree uniformly, so
/// there is no need to relayout on zoom.
class MindmapLayoutEngine {
  /// Lay out [tree] anchored at the root's current [Rect.center].
  static MindmapLayoutResult layout(
    MindmapTree tree, {
    MindmapLayoutConfig config = const MindmapLayoutConfig(),
  }) {
    final rootCenter = tree.root.rect.center;
    return _layoutAt(tree, rootCenter, config: config);
  }

  /// Lay out [tree] anchored at an explicit origin (root center).
  static MindmapLayoutResult _layoutAt(
    MindmapTree tree,
    Offset rootCenter, {
    MindmapLayoutConfig config = const MindmapLayoutConfig(),
  }) {
    final rects = <String, Rect>{};
    final root = tree.root;

    final rootRect = Rect.fromCenter(
      center: rootCenter,
      width: config.widthForNode(root),
      height: config.rootNodeHeight,
    );
    rects[root.id] = rootRect;

    final rightChildren = root.children
        .where((c) => c.data.side != MindmapNodeSide.left)
        .toList();
    final leftChildren = root.children
        .where((c) => c.data.side == MindmapNodeSide.left)
        .toList();

    // Root collapses per-side; the tree builder already pruned collapsed
    // subtrees, so rightChildren/leftChildren only contain visible nodes.
    if (rightChildren.isNotEmpty) {
      final rightHeight = _totalSubtreeHeight(rightChildren, config);
      double y = rootCenter.dy - rightHeight / 2;
      for (final child in rightChildren) {
        final subH = _subtreeHeight(child, config);
        final childWidth = config.widthForNode(child);
        _layoutSubtree(
          child,
          Offset(
            rootRect.right + config.horizontalGap + childWidth / 2,
            y + subH / 2,
          ),
          MindmapNodeSide.right,
          rects,
          config,
        );
        y += subH + config.siblingGap;
      }
    }

    if (leftChildren.isNotEmpty) {
      final leftHeight = _totalSubtreeHeight(leftChildren, config);
      double y = rootCenter.dy - leftHeight / 2;
      for (final child in leftChildren) {
        final subH = _subtreeHeight(child, config);
        final childWidth = config.widthForNode(child);
        _layoutSubtree(
          child,
          Offset(
            rootRect.left - config.horizontalGap - childWidth / 2,
            y + subH / 2,
          ),
          MindmapNodeSide.left,
          rects,
          config,
        );
        y += subH + config.siblingGap;
      }
    }

    final mergePoints = _computeMergePoints(tree, rects, config);
    return MindmapLayoutResult(rects: rects, mergePoints: mergePoints);
  }

  static double _totalSubtreeHeight(
    List<MindmapTreeNode> children,
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

  static double _subtreeHeight(
    MindmapTreeNode node,
    MindmapLayoutConfig config,
  ) {
    if (node.data.isCollapsed || node.children.isEmpty) {
      return config.nodeHeight;
    }
    double total = 0;
    for (final child in node.children) {
      total += _subtreeHeight(child, config);
    }
    total += config.siblingGap * (node.children.length - 1);
    return total > config.nodeHeight ? total : config.nodeHeight;
  }

  static void _layoutSubtree(
    MindmapTreeNode node,
    Offset center,
    MindmapNodeSide side,
    Map<String, Rect> rects,
    MindmapLayoutConfig config,
  ) {
    final w = config.widthForNode(node);
    final h = config.nodeHeight;
    final nodeRect = Rect.fromCenter(center: center, width: w, height: h);
    rects[node.id] = nodeRect;

    if (node.data.isCollapsed || node.children.isEmpty) return;

    final childrenHeight = _totalSubtreeHeight(node.children, config);
    double y = center.dy - childrenHeight / 2;

    for (final child in node.children) {
      final subH = _subtreeHeight(child, config);
      final childWidth = config.widthForNode(child);
      final childX = side == MindmapNodeSide.right
          ? nodeRect.right + config.horizontalGap + childWidth / 2
          : nodeRect.left - config.horizontalGap - childWidth / 2;
      _layoutSubtree(child, Offset(childX, y + subH / 2), side, rects, config);
      y += subH + config.siblingGap;
    }
  }

  /// Compute merge points for connection drawing.
  static List<MindmapMergePoint> _computeMergePoints(
    MindmapTree tree,
    Map<String, Rect> rects,
    MindmapLayoutConfig config,
  ) {
    final points = <MindmapMergePoint>[];

    void walk(MindmapTreeNode layoutNode) {
      final node = layoutNode.data;

      if (tree.hasChildrenInData(node.id)) {
        final isRoot = layoutNode.depth == 0;
        final sides = isRoot
            ? [MindmapNodeSide.right, MindmapNodeSide.left]
            : [
                node.side == MindmapNodeSide.center
                    ? MindmapNodeSide.right
                    : node.side,
              ];

        for (final side in sides) {
          final countOnSide = isRoot
              ? tree.childCountOnSide(node.id, side)
              : (tree.childCountByParent[node.id] ?? 0);

          if (countOnSide == 0) continue;

          final nodeRect = rects[node.id];
          if (nodeRect == null) continue;

          final collapsedOnSide = node.isCollapsedOnSide(side);

          // Expanded children on this side (visible). Empty when collapsed.
          final expandedOnSide = collapsedOnSide
              ? const <MindmapTreeNode>[]
              : layoutNode.children.where((c) {
                  final r = rects[c.id];
                  if (r == null) return false;
                  return side == MindmapNodeSide.right
                      ? r.center.dx >= nodeRect.center.dx
                      : r.center.dx < nodeRect.center.dx;
                }).toList();

          final mergeX = side == MindmapNodeSide.right
              ? nodeRect.right + config.horizontalGap / 2
              : nodeRect.left - config.horizontalGap / 2;
          final mergeY = nodeRect.center.dy;

          final parentEdge = side == MindmapNodeSide.right
              ? Offset(nodeRect.right, nodeRect.center.dy)
              : Offset(nodeRect.left, nodeRect.center.dy);

          final childEdges = [
            for (final c in expandedOnSide)
              side == MindmapNodeSide.right
                  ? Offset(rects[c.id]!.left, rects[c.id]!.center.dy)
                  : Offset(rects[c.id]!.right, rects[c.id]!.center.dy),
          ];

          points.add(
            MindmapMergePoint(
              position: Offset(mergeX, mergeY),
              parentNodeId: node.id,
              side: side,
              isCollapsed: collapsedOnSide,
              childCount: countOnSide,
              parentEdge: parentEdge,
              childEdges: childEdges,
            ),
          );
        }
      }

      for (final child in layoutNode.children) {
        walk(child);
      }
    }

    walk(tree.root);
    return points;
  }
}

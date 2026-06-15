import 'package:flutter/widgets.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_node.dart';
import 'mindmap_node_data.dart';

/// Widget type tag used by all mind map node elements.
const String kMindmapNodeWidgetType = 'mindmap_node';

/// A reconstructed mind map tree node.
///
/// Unlike the old component-mode model, this is a **view** over canvas
/// elements — it is rebuilt on demand from element widgetData and never
/// persisted as a blob. The tree holds references back to each node's
/// [MindmapNodeData] (parsed) and its canvas element [Rect].
class MindmapTreeNode {
  MindmapTreeNode({
    required this.data,
    required this.rect,
    required this.depth,
    required this.siblingIndex,
    required this.siblingCount,
    required this.branchIndex,
    List<MindmapTreeNode>? children,
  }) : children = children ?? [];

  /// Parsed node data (text/side/collapsed/...).
  MindmapNodeData data;

  /// Current world rect of the hosting canvas element.
  Rect rect;

  /// Depth in the tree (root = 0).
  final int depth;

  /// Position among visible siblings under the same parent.
  final int siblingIndex;

  /// Total visible siblings under the same parent.
  final int siblingCount;

  /// Index of the first-level branch this node belongs to.
  final int branchIndex;

  /// Visible (non-collapsed) children.
  final List<MindmapTreeNode> children;

  /// Node id (convenience — same as [data.id]).
  String get id => data.id;

  /// Whether this node has any children in the data model.
  ///
  /// NOTE: this reflects **visible** children in the rebuilt tree only if the
  /// node is expanded. To know whether a node *has* children at all (even when
  /// collapsed), check [data] — but the rebuilt tree prunes collapsed
  /// subtrees, so we expose [hasChildrenFromData] via the builder instead.
  bool get hasVisibleChildren => children.isNotEmpty;

  Offset get center => rect.center;
  Offset get rightCenter => Offset(rect.right, rect.center.dy);
  Offset get leftCenter => Offset(rect.left, rect.center.dy);
}

/// A whole reconstructed tree rooted at one `isRoot` node.
class MindmapTree {
  MindmapTree({
    required this.root,
    required this.allNodes,
    required this.childCountByParent,
    required this.childCountByParentSide,
  });

  final MindmapTreeNode root;

  /// Flat map of every node in this tree by id (including collapsed ones).
  /// Used to look up the collapse state of nodes whose children were pruned.
  final Map<String, MindmapNodeData> allNodes;

  /// Number of children each node has in the data model (keyed by parent id).
  /// Used to decide whether to render the merge-point collapse button.
  final Map<String, int> childCountByParent;

  /// Per-side child counts for root nodes: `childCountByParentSide[rootId]`
  /// → `{'right': n, 'left': m}`. Used so the collapse button on each side of
  /// the root shows the correct count even when the other side is expanded.
  final Map<String, Map<MindmapNodeSide, int>> childCountByParentSide;

  /// Walk all visible nodes (root + expanded descendants).
  List<MindmapTreeNode> get visibleNodes {
    final list = <MindmapTreeNode>[];
    void walk(MindmapTreeNode n) {
      list.add(n);
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(root);
    return list;
  }

  /// Whether a node has any children in the data model (collapsed or not).
  bool hasChildrenInData(String nodeId) =>
      (childCountByParent[nodeId] ?? 0) > 0;

  /// Number of children [nodeId] has on [side] in the data model.
  int childCountOnSide(String nodeId, MindmapNodeSide side) {
    final bySide = childCountByParentSide[nodeId];
    if (bySide != null) return bySide[side] ?? 0;
    // Non-root nodes: all children are on one side, fall back to total count.
    return childCountByParent[nodeId] ?? 0;
  }
}

/// Rebuilds [MindmapTree]s from a flat list of canvas elements by walking
/// `parentId` links. Nodes whose `widgetType` is [kMindmapNodeWidgetType] are
/// treated as mind map nodes; one tree is produced per `isRoot: true` node.
class MindmapTreeBuilder {
  MindmapTreeBuilder._();

  /// Build **all** mind map trees present on the canvas.
  ///
  /// Each `isRoot: true` node starts a new tree. Orphaned nodes (whose
  /// `parentId` points to a missing node) are ignored.
  static List<MindmapTree> buildAll(List<CanvasElement> elements) {
    final parsed = <String, _ParsedNode>{};
    for (final element in elements) {
      if (element is! CanvasWidgetElement) continue;
      if (element.widgetType != kMindmapNodeWidgetType) continue;
      final data = MindmapNodeData.fromWidgetData(element.widgetData);
      parsed[element.id] = _ParsedNode(data: data, rect: element.worldRect);
    }

    // Collect roots and build child index by parentId.
    final roots = <MindmapNodeData>[];
    final byParent = <String, List<MindmapNodeData>>{};
    for (final p in parsed.values) {
      if (p.data.isRoot || p.data.parentId == null) {
        roots.add(p.data);
      } else {
        (byParent[p.data.parentId!] ??= <MindmapNodeData>[]).add(p.data);
      }
    }

    // Order children by their `order` field (ascending). This makes `order`
    // the single source of truth for sibling sequence — the element insertion
    // order is *not* used for layout, so reorders must go through `order`.
    for (final kids in byParent.values) {
      kids.sort((a, b) => a.order.compareTo(b.order));
    }

    return [
      for (final rootData in roots) _buildTree(rootData, parsed, byParent),
    ];
  }

  /// Build a single tree rooted at [rootId]. Returns null if the root is not
  /// found among the elements.
  static MindmapTree? build(List<CanvasElement> elements, String rootId) {
    for (final tree in buildAll(elements)) {
      if (tree.root.id == rootId) return tree;
    }
    return null;
  }

  static MindmapTree _buildTree(
    MindmapNodeData rootData,
    Map<String, _ParsedNode> parsed,
    Map<String, List<MindmapNodeData>> byParent,
  ) {
    final allNodes = <String, MindmapNodeData>{};
    final childCountByParent = <String, int>{};
    final childCountByParentSide = <String, Map<MindmapNodeSide, int>>{};
    // Populate allNodes with every node reachable from this root (even if
    // collapsed — we want the data map to be complete).
    void collectData(MindmapNodeData n) {
      allNodes[n.id] = n;
      final kids = byParent[n.id] ?? const <MindmapNodeData>[];
      childCountByParent[n.id] = kids.length;
      // Root nodes track per-side child counts.
      if (n.isRoot) {
        final bySide = <MindmapNodeSide, int>{
          MindmapNodeSide.right: 0,
          MindmapNodeSide.left: 0,
        };
        for (final child in kids) {
          final side = child.side == MindmapNodeSide.left
              ? MindmapNodeSide.left
              : MindmapNodeSide.right;
          bySide[side] = (bySide[side] ?? 0) + 1;
        }
        childCountByParentSide[n.id] = bySide;
      }
      for (final child in kids) {
        collectData(child);
      }
    }

    collectData(rootData);

    MindmapTreeNode buildNode(
      MindmapNodeData data,
      int depth, {
      int siblingIndex = 0,
      int siblingCount = 1,
      int branchIndex = 0,
    }) {
      final parsedNode = parsed[data.id];
      final rect = parsedNode?.rect ?? Rect.zero;
      final node = MindmapTreeNode(
        data: data,
        rect: rect,
        depth: depth,
        siblingIndex: siblingIndex,
        siblingCount: siblingCount,
        branchIndex: branchIndex,
      );
      final kids = byParent[data.id] ?? const <MindmapNodeData>[];
      final visibleKids = <MindmapNodeData>[];
      for (final childData in kids) {
        // Root nodes collapse per-side; non-root nodes collapse as a whole.
        final side = childData.side == MindmapNodeSide.left
            ? MindmapNodeSide.left
            : MindmapNodeSide.right;
        if (data.isCollapsedOnSide(side)) continue;
        visibleKids.add(childData);
      }
      for (var i = 0; i < visibleKids.length; i++) {
        node.children.add(
          buildNode(
            visibleKids[i],
            depth + 1,
            siblingIndex: i,
            siblingCount: visibleKids.length,
            branchIndex: depth == 0 ? i : branchIndex,
          ),
        );
      }
      return node;
    }

    final root = buildNode(rootData, 0);
    return MindmapTree(
      root: root,
      allNodes: allNodes,
      childCountByParent: childCountByParent,
      childCountByParentSide: childCountByParentSide,
    );
  }
}

class _ParsedNode {
  const _ParsedNode({required this.data, required this.rect});

  final MindmapNodeData data;
  final Rect rect;
}

import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_drag_session.dart';
import 'mindmap_layout_engine.dart';
import 'mindmap_node.dart';
import 'mindmap_node_data.dart';
import 'mindmap_tree.dart';

/// Central place for all mind map mutations in "non-component mode".
///
/// Each node is a [CanvasWidgetElement] with `widgetType == 'mindmap_node'`;
/// the tree is reconstructed on demand from `parentId` links. This class
/// performs add/sibling/delete/toggle/color/text operations on the canvas and
/// then triggers a [relayout] so all child node rects follow the new tree
/// shape. The [MindmapSyncController] listens to the same canvas and handles
/// "drag the root → translate whole tree".
///
/// A single [MindmapActions] instance is attached per [CanvasController] via
/// [attach]/[of], so node builders can reach it from a plain
/// [CanvasWidgetBuildContext].
class MindmapActions {
  MindmapActions(this._canvas);

  final CanvasController _canvas;

  /// Active drag session (long-press drag on a child node). The connection
  /// layer listens to this to render the ghost + drop target highlight.
  final MindmapDragSession dragSession = MindmapDragSession();

  static final Map<CanvasController, MindmapActions> _registry = {};

  /// Attach an actions instance to [controller]. Idempotent.
  static MindmapActions attach(CanvasController controller) {
    return _registry.putIfAbsent(controller, () => MindmapActions(controller));
  }

  /// Look up the actions instance for [controller], if any.
  static MindmapActions? of(CanvasController controller) =>
      _registry[controller];

  /// Detach and dispose the actions instance for [controller].
  static void detach(CanvasController controller) {
    _registry.remove(controller);
  }

  // ── Queries ────────────────────────────────────────────────────────

  /// All mind map trees currently on the canvas.
  List<MindmapTree> get trees =>
      MindmapTreeBuilder.buildAll(_canvas.elements);

  /// The root id of the tree containing [nodeId], or null if not found.
  String? rootIdOf(String nodeId) {
    for (final tree in trees) {
      if (tree.allNodes.containsKey(nodeId)) return tree.root.id;
    }
    return null;
  }

  // ── Mutations ──────────────────────────────────────────────────────

  /// Add a child to [parentId]. The new child inherits the parent's side
  /// (right if parent is root).
  void addChild(String parentId) {
    final parent = _nodeData(parentId);
    if (parent == null) return;

    final side = parent.isRoot ? MindmapNodeSide.right : parent.side;
    final newId = 'node-${DateTime.now().microsecondsSinceEpoch}';
    final newRect = _tempRectNear(parentId);

    final newElement = _makeElement(
      MindmapNodeData(
        id: newId,
        text: '新节点',
        parentId: parentId,
        side: side,
        color: 0xFFE3F2FD,
      ),
      newRect,
    );

    _canvas.addElement(newElement);

    // Expand the parent (on the child's side) so the new child is visible.
    _setCollapsed(parentId, side, false);
    relayoutOf(parentId, select: newId);
  }

  /// Add a sibling of [nodeId] (same parent, same side). No-op for root.
  void addSibling(String nodeId) {
    final node = _nodeData(nodeId);
    if (node == null || node.isRoot) return;
    final parentId = node.parentId;
    if (parentId == null) return;

    final side = node.side;
    final newId = 'node-${DateTime.now().microsecondsSinceEpoch}';
    final newElement = _makeElement(
      MindmapNodeData(
        id: newId,
        text: '新节点',
        parentId: parentId,
        side: side,
        color: 0xFFE3F2FD,
      ),
      _tempRectNear(nodeId),
    );

    _canvas.addElement(newElement);
    // Insert visually after the sibling by reordering is not necessary —
    // layout is vertical by subtree height. Relayout takes care of position.
    relayoutOf(nodeId, select: newId);
  }

  /// Delete [nodeId] and its whole subtree. No-op for root.
  void deleteNode(String nodeId) {
    final node = _nodeData(nodeId);
    if (node == null || node.isRoot) return;

    // Collect the subtree (all descendants by parentId walk).
    final toRemove = <String>{};
    void collect(String id) {
      toRemove.add(id);
      for (final e in _canvas.elements) {
        if (e is CanvasWidgetElement &&
            e.widgetType == kMindmapNodeWidgetType &&
            e.widgetData['parentId'] == id) {
          collect(e.id);
        }
      }
    }

    collect(nodeId);

    final commands = [
      for (final id in toRemove)
        RemoveElementCommand(_canvas.elementById(id)!),
    ];
    _canvas.historyManager.execute(
      BatchCommand(commands: commands, description: 'Delete mind map subtree'),
      _canvas,
    );

    // Select parent after deletion.
    final parentId = node.parentId;
    if (parentId != null) {
      _canvas.setSelection({parentId});
      relayoutOf(parentId);
    }
  }

  /// Toggle the collapsed state of [nodeId] on [side].
  ///
  /// Root nodes collapse per-side (left/right independently); non-root nodes
  /// ignore [side] and toggle their whole subtree.
  void toggleCollapse(String nodeId, MindmapNodeSide side) {
    final node = _nodeData(nodeId);
    if (node == null) return;
    // Only meaningful if the node actually has children on this side.
    if (!_hasChildrenInData(nodeId)) return;
    final willCollapse = !node.isCollapsedOnSide(side);
    _setCollapsed(nodeId, side, willCollapse);
    // When collapsing, any selected descendant becomes hidden — collapse the
    // selection down to the toggled node so we never hold a selection on an
    // invisible element.
    if (willCollapse) {
      _canvas.setSelection({nodeId});
    }
    relayoutOf(nodeId);
  }

  /// Update the color of [nodeId].
  void setNodeColor(String nodeId, int color) {
    final element = _canvas.elementById(nodeId);
    if (element is! CanvasWidgetElement) return;
    final data = MindmapNodeData.fromWidgetData(element.widgetData);
    _updateNodeData(nodeId, data.copyWith(color: color));
  }

  /// Commit edited text for [nodeId] (no sibling/child creation).
  void commitText(String nodeId, String text) {
    final element = _canvas.elementById(nodeId);
    if (element is! CanvasWidgetElement) return;
    final data = MindmapNodeData.fromWidgetData(element.widgetData);
    _updateNodeData(nodeId, data.copyWith(text: text));
  }

  /// Commit text for [nodeId] and immediately add a sibling, selecting it.
  void commitAndAddSibling(String nodeId, String text) {
    final element = _canvas.elementById(nodeId);
    if (element is! CanvasWidgetElement) return;
    final data = MindmapNodeData.fromWidgetData(element.widgetData);
    _updateNodeData(nodeId, data.copyWith(text: text));
    if (!data.isRoot) {
      addSibling(nodeId);
    } else {
      relayoutOf(nodeId);
    }
  }

  /// Commit text for [nodeId] and immediately add a child, selecting it.
  void commitAndAddChild(String nodeId, String text) {
    final element = _canvas.elementById(nodeId);
    if (element is! CanvasWidgetElement) return;
    final data = MindmapNodeData.fromWidgetData(element.widgetData);
    _updateNodeData(nodeId, data.copyWith(text: text));
    addChild(nodeId);
  }

  // ── Drag reorder / reparent ────────────────────────────────────────

  /// Compute the best drop target for a drag pointer at world [position].
  ///
  /// Strategy (mixed: prefer same-level reorder, else reparent):
  ///   1. Among the dragged node's **current siblings** (same parent), find
  ///      the nearest one by center distance. If it's within the reorder
  ///      threshold, insert before/after it depending on pointer Y.
  ///   2. Otherwise, find the **nearest non-sibling visible node** (excluding
  ///      self and descendants) and treat it as a prospective new parent.
  ///
  /// [reorderThreshold] and [parentThreshold] are in world units.
  MindmapDropTarget? computeDropTarget(
    String draggedNodeId,
    Offset position, {
    double reorderThreshold = 80,
    double parentThreshold = 120,
  }) {
    final dragged = _nodeData(draggedNodeId);
    if (dragged == null) return null;

    // Gather all visible nodes with their rects, grouped by tree.
    final candidates = <_DragCandidate>[];
    for (final tree in trees) {
      for (final n in tree.visibleNodes) {
        if (n.id == draggedNodeId) continue;
        // Skip the dragged node's own descendants (can't reparent into self).
        if (_isAncestorOf(draggedNodeId, n.id)) continue;
        final dist = (n.center - position).distance;
        candidates.add(_DragCandidate(node: n, distance: dist));
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.distance.compareTo(b.distance));

    final nearest = candidates.first;

    // 1. Same-parent sibling → reorder.
    if (nearest.node.data.parentId == dragged.parentId &&
        nearest.distance <= reorderThreshold) {
      final kind = position.dy < nearest.node.center.dy
          ? MindmapDropTargetKind.siblingBefore
          : MindmapDropTargetKind.siblingAfter;
      return MindmapDropTarget(
        kind: kind,
        nodeId: nearest.node.id,
        reason: 'sibling reorder',
      );
    }

    // 2. Otherwise → reparent to the nearest node (if close enough).
    if (nearest.distance <= parentThreshold) {
      return MindmapDropTarget(
        kind: MindmapDropTargetKind.parent,
        nodeId: nearest.node.id,
        reason: 'reparent (dist ${nearest.distance.toStringAsFixed(0)})',
      );
    }

    return null;
  }

  /// Predict where [draggedNodeId] would land if dropped on [target].
  ///
  /// Returns the predicted world rect + the connection line from the
  /// (prospective) parent edge to the node. Used to render the drop shadow
  /// and preview connection during the drag.
  MindmapDropPreview? computeDropPreview(
    String draggedNodeId,
    MindmapDropTarget? target,
  ) {
    if (target == null) return null;
    final draggedEl = _canvas.elementById(draggedNodeId);
    if (draggedEl is! CanvasWidgetElement) return null;

    // Simulate the drop by building a hypothetical element list where the
    // dragged node is reparented / reordered, then run the layout engine and
    // read back the node's predicted rect.
    final simulated = _simulateElements(draggedNodeId, target);

    // Find which root the dragged node belongs to after the simulated change.
    final simTrees = MindmapTreeBuilder.buildAll(simulated);
    MindmapTreeNode? simNode;
    Offset? parentEdge;
    MindmapNodeSide? connSide;
    for (final tree in simTrees) {
      for (final n in tree.visibleNodes) {
        if (n.id == draggedNodeId) {
          simNode = n;
          // Find parent edge for the connection preview.
          final dragged = _nodeData(draggedNodeId);
          final parentId = n.data.parentId ?? dragged?.parentId;
          if (parentId != null) {
            final parentEl = _canvas.elementById(parentId);
            if (parentEl is CanvasWidgetElement) {
              final side = n.data.side == MindmapNodeSide.left
                  ? MindmapNodeSide.left
                  : MindmapNodeSide.right;
              connSide = side;
              final pr = parentEl.worldRect;
              parentEdge = side == MindmapNodeSide.left
                  ? Offset(pr.left, pr.center.dy)
                  : Offset(pr.right, pr.center.dy);
            }
          }
          break;
        }
      }
      if (simNode != null) break;
    }
    if (simNode == null) return null;

    // Run layout on the simulated tree to get the predicted rect.
    final result = MindmapLayoutEngine.layout(
      simTrees.firstWhere(
        (t) => t.allNodes.containsKey(draggedNodeId),
        orElse: () => simTrees.first,
      ),
    );
    final previewRect = result.rects[draggedNodeId];
    if (previewRect == null) return null;

    MindmapPreviewConnection? connection;
    if (parentEdge != null && connSide != null) {
      final to = connSide == MindmapNodeSide.left
          ? Offset(previewRect.right, previewRect.center.dy)
          : Offset(previewRect.left, previewRect.center.dy);
      connection = MindmapPreviewConnection(from: parentEdge, to: to);
    }

    return MindmapDropPreview(rect: previewRect, connection: connection);
  }

  /// Build a hypothetical element list reflecting what the canvas would look
  /// like if [draggedNodeId] were dropped on [target].
  ///
  /// For sibling reorders the node's data stays the same but we rely on the
  /// tree builder picking up the same children order (the dragged node is
  /// already among them). For reparent, we rewrite the node's `parentId` +
  /// `side`.
  List<CanvasElement> _simulateElements(
    String draggedNodeId,
    MindmapDropTarget target,
  ) {
    final elements = <CanvasElement>[];
    for (final e in _canvas.elements) {
      if (e is CanvasWidgetElement &&
          e.id == draggedNodeId &&
          e.widgetType == kMindmapNodeWidgetType) {
        final data = MindmapNodeData.fromWidgetData(e.widgetData);
        if (target.kind == MindmapDropTargetKind.parent) {
          // Reparent: rewrite parentId + side to match the new parent.
          final newParent = _nodeData(target.nodeId);
          final newSide = newParent?.isRoot == true
              ? MindmapNodeSide.right
              : (newParent?.side ?? MindmapNodeSide.right);
          final simulated = data.copyWith(
            parentId: target.nodeId,
            side: newSide,
            isCollapsed: false,
          );
          elements.add(e.copyWith(
            widgetData: Map<String, dynamic>.unmodifiable(simulated.toWidgetData()),
          ));
        } else {
          elements.add(e);
        }
      } else {
        elements.add(e);
      }
    }
    return elements;
  }

  /// Whether [ancestorId] is an ancestor of [descendantId] in the data model.
  bool _isAncestorOf(String ancestorId, String descendantId) {
    var current = descendantId;
    while (true) {
      final data = _nodeData(current);
      if (data == null) return false;
      final parent = data.parentId;
      if (parent == null) return false;
      if (parent == ancestorId) return true;
      current = parent;
    }
  }

  /// Execute a reorder or reparent for [draggedNodeId] given [target].
  ///
  /// For sibling reorders, the dragged node is moved within its parent's
  /// children list to before/after [target.nodeId]. For reparent, the node's
  /// `parentId` is changed and its `side` updated to match the new parent.
  /// A relayout is triggered at the end.
  void reorderOrReparent(String draggedNodeId, MindmapDropTarget? target) {
    if (target == null) {
      // No valid drop — just relayout to snap back to original position.
      relayoutOf(draggedNodeId);
      return;
    }

    final dragged = _nodeData(draggedNodeId);
    if (dragged == null) return;

    switch (target.kind) {
      case MindmapDropTargetKind.siblingBefore:
      case MindmapDropTargetKind.siblingAfter:
        _reorderSibling(draggedNodeId, target.nodeId, target.kind);
        break;
      case MindmapDropTargetKind.parent:
        _reparent(draggedNodeId, target.nodeId);
        break;
    }
  }

  void _reorderSibling(
    String draggedNodeId,
    String siblingId,
    MindmapDropTargetKind kind,
  ) {
    final dragged = _nodeData(draggedNodeId);
    if (dragged == null || dragged.parentId == null) return;
    final parentId = dragged.parentId!;

    // Rebuild the parent's children list, moving dragged next to sibling.
    final siblings = <String>[];
    for (final e in _canvas.elements) {
      if (e is CanvasWidgetElement &&
          e.widgetType == kMindmapNodeWidgetType &&
          e.widgetData['parentId'] == parentId) {
        siblings.add(e.id);
      }
    }
    siblings.remove(draggedNodeId);

    final insertIndex = siblings.indexOf(siblingId);
    if (insertIndex < 0) {
      siblings.add(draggedNodeId);
    } else if (kind == MindmapDropTargetKind.siblingAfter) {
      siblings.insert(insertIndex + 1, draggedNodeId);
    } else {
      siblings.insert(insertIndex, draggedNodeId);
    }

    // Apply the new order by updating zIndex of each child.
    final commands = <CanvasCommand>[];
    final baseZ = _canvas.elementById(draggedNodeId)?.zIndex ?? 0;
    for (var i = 0; i < siblings.length; i++) {
      final element = _canvas.elementById(siblings[i]);
      if (element is! CanvasWidgetElement) continue;
      final newZ = baseZ + i;
      if (element.zIndex == newZ) continue;
      commands.add(UpdateElementCommand(
        before: element,
        after: element.copyWith(zIndex: newZ),
        description: 'Reorder mind map node',
      ));
    }
    if (commands.isNotEmpty) {
      _canvas.historyManager.execute(
        BatchCommand(commands: commands, description: 'Reorder mind map'),
        _canvas,
      );
    }
    relayoutOf(parentId);
  }

  void _reparent(String draggedNodeId, String newParentId) {
    final dragged = _nodeData(draggedNodeId);
    if (dragged == null) return;
    final newParent = _nodeData(newParentId);
    if (newParent == null) return;

    // Remember the original tree root before mutating, so we can relayout
    // both the source tree and the destination tree afterwards.
    final originalRootId = rootIdOf(draggedNodeId);

    if (dragged.parentId == newParentId) {
      relayoutOf(draggedNodeId);
      return;
    }

    // Determine the new side: root parent → right; non-root → parent's side.
    final newSide = newParent.isRoot ? MindmapNodeSide.right : newParent.side;

    // Update the dragged node's parentId + side.
    final element = _canvas.elementById(draggedNodeId);
    if (element is! CanvasWidgetElement) return;
    _updateNodeData(
      draggedNodeId,
      dragged.copyWith(parentId: newParentId, side: newSide),
    );
    // Expand the new parent so the moved node is visible.
    _setCollapsed(newParentId, newSide, false);

    // Relayout the destination tree.
    final destRootId = rootIdOf(newParentId);
    if (destRootId != null) relayout(destRootId);
    // Relayout the source tree too (it may have changed shape). Skip if the
    // node stayed within the same tree.
    if (originalRootId != null && originalRootId != destRootId) {
      relayout(originalRootId);
    }
  }

  // ── Layout ─────────────────────────────────────────────────────────

  /// Re-layout the tree that contains [nodeId], optionally selecting a node.
  ///
  /// Layout is computed from the current root rect center, then all node
  /// rects are pushed back as a single [BatchCommand] so undo restores the
  /// previous geometry in one step.
  void relayoutOf(String nodeId, {String? select}) {
    final rootId = rootIdOf(nodeId);
    if (rootId == null) return;
    relayout(rootId, select: select);
  }

  /// Re-layout the tree rooted at [rootId], optionally selecting a node.
  ///
  /// Besides repositioning visible nodes, this also syncs element `visible`
  /// flags: nodes whose subtree is collapsed are hidden (`visible: false`),
  /// and re-shown when their ancestor is expanded again.
  void relayout(String rootId, {String? select}) {
    final tree = MindmapTreeBuilder.build(_canvas.elements, rootId);
    if (tree == null) return;

    final result = MindmapLayoutEngine.layout(tree);
    final visibleIds = result.rects.keys.toSet();

    // Build a batch of updates: position + visibility per node that changed.
    final commands = <CanvasCommand>[];
    for (final entry in result.rects.entries) {
      final id = entry.key;
      final newRect = entry.value;
      final element = _canvas.elementById(id);
      if (element is! CanvasWidgetElement) continue;
      if (element.worldRect == newRect && element.visible) continue;
      commands.add(UpdateElementCommand(
        before: element,
        after: element.copyWith(worldRect: newRect, visible: true),
        description: 'Relayout mind map node',
      ));
    }
    // Hide nodes that belong to this tree but were pruned by collapse.
    for (final id in tree.allNodes.keys) {
      if (visibleIds.contains(id)) continue;
      final element = _canvas.elementById(id);
      if (element is! CanvasWidgetElement) continue;
      if (!element.visible) continue;
      commands.add(UpdateElementCommand(
        before: element,
        after: element.copyWith(visible: false),
        description: 'Hide collapsed mind map node',
      ));
    }

    if (commands.isNotEmpty) {
      _canvas.historyManager.execute(
        BatchCommand(commands: commands, description: 'Relayout mind map'),
        _canvas,
      );
    }

    if (select != null) {
      _canvas.setSelection({select});
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  MindmapNodeData? _nodeData(String id) {
    final element = _canvas.elementById(id);
    if (element is! CanvasWidgetElement) return null;
    if (element.widgetType != kMindmapNodeWidgetType) return null;
    return MindmapNodeData.fromWidgetData(element.widgetData);
  }

  bool _hasChildrenInData(String parentId) {
    for (final e in _canvas.elements) {
      if (e is CanvasWidgetElement &&
          e.widgetType == kMindmapNodeWidgetType &&
          e.widgetData['parentId'] == parentId) {
        return true;
      }
    }
    return false;
  }

  void _setCollapsed(String id, MindmapNodeSide side, bool collapsed) {
    final element = _canvas.elementById(id);
    if (element is! CanvasWidgetElement) return;
    final data = MindmapNodeData.fromWidgetData(element.widgetData);
    if (data.isRoot) {
      // Root nodes collapse per-side.
      _updateNodeData(
        id,
        side == MindmapNodeSide.left
            ? data.copyWith(collapsedLeft: collapsed)
            : data.copyWith(collapsedRight: collapsed),
      );
    } else {
      // Non-root nodes collapse as a whole.
      _updateNodeData(id, data.copyWith(isCollapsed: collapsed));
    }
  }

  void _updateNodeData(String id, MindmapNodeData data) {
    final element = _canvas.elementById(id);
    if (element is! CanvasWidgetElement) return;
    _canvas.updateElement(
      id,
      element.copyWith(
        widgetData: Map<String, dynamic>.unmodifiable(data.toWidgetData()),
      ),
    );
  }

  /// Temporary rect placed near [referenceId] before relayout kicks in.
  /// Relayout will overwrite it immediately.
  Rect _tempRectNear(String referenceId) {
    final ref = _canvas.elementById(referenceId);
    if (ref == null) {
      return const Rect.fromLTWH(0, 0, 120, 40);
    }
    return Rect.fromCenter(
      center: ref.bounds.center + const Offset(160, 0),
      width: 120,
      height: 40,
    );
  }

  CanvasWidgetElement _makeElement(MindmapNodeData data, Rect rect) {
    return makeMindmapNodeElement(data: data, rect: rect);
  }
}

/// A candidate drop target during a drag, with its distance to the pointer.
class _DragCandidate {
  const _DragCandidate({required this.node, required this.distance});

  final MindmapTreeNode node;
  final double distance;
}

/// Build a [CanvasWidgetElement] for a single mind map node.
///
/// Nodes use [CanvasWidgetRenderMode.live] (always interactive) and the
/// default [CanvasWidgetScaleMode.layoutScale] — exactly like other canvas
/// elements, the world rect is laid out in fixed world units and the canvas
/// zoom scales it uniformly.
CanvasWidgetElement makeMindmapNodeElement({
  required MindmapNodeData data,
  required Rect rect,
}) {
  return CanvasWidgetElement(
    id: data.id,
    worldRect: rect,
    widgetType: kMindmapNodeWidgetType,
    widgetData: Map<String, dynamic>.unmodifiable(data.toWidgetData()),
    renderMode: CanvasWidgetRenderMode.live,
  );
}

/// Helper to create the initial set of node elements for a new mind map.
/// Used by the "add mind map" toolbar action. Rects are placeholders — the
/// caller is expected to trigger [MindmapActions.relayout] right after.
List<CanvasWidgetElement> createMindmapNodeElements({
  required Offset center,
  String rootText = '中心主题',
}) {
  final rootId = 'mm-${DateTime.now().microsecondsSinceEpoch}';
  final rootRect = Rect.fromCenter(
    center: center,
    width: 140,
    height: 48,
  );

  CanvasWidgetElement asWidget(MindmapNodeData data) {
    return makeMindmapNodeElement(data: data, rect: rootRect);
  }

  return [
    makeMindmapNodeElement(
      data: MindmapNodeData(
        id: rootId,
        text: rootText,
        isRoot: true,
        side: MindmapNodeSide.center,
        color: 0xFF2563EB,
        textColor: 0xFFFFFFFF,
      ),
      rect: rootRect,
    ),
    asWidget(MindmapNodeData(
      id: '$rootId-r1',
      text: '分支1',
      parentId: rootId,
      side: MindmapNodeSide.right,
    )),
    asWidget(MindmapNodeData(
      id: '$rootId-r2',
      text: '分支2',
      parentId: rootId,
      side: MindmapNodeSide.right,
    )),
    asWidget(MindmapNodeData(
      id: '$rootId-l1',
      text: '分支3',
      parentId: rootId,
      side: MindmapNodeSide.left,
    )),
  ];
}

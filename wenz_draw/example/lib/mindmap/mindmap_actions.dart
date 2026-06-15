import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_drag_session.dart';
import 'mindmap_layout_engine.dart';
import 'mindmap_node.dart';
import 'mindmap_node_data.dart';
import 'mindmap_node_metrics.dart';
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

  static const int _rootNodeColor = 0xFF2563EB;
  static const int _rootTextColor = 0xFFFFFFFF;
  static const int _childNodeColor = 0xFFE3F2FD;
  static const int _childTextColor = 0xFF1F2937;

  /// Active drag session (long-press drag on a child node). The connection
  /// layer listens to this to render the ghost + drop target highlight.
  final MindmapDragSession dragSession = MindmapDragSession();
  final ValueNotifier<MindmapEditRequest?> editRequest = ValueNotifier(null);
  final ValueNotifier<String?> editingNodeId = ValueNotifier(null);

  int _editRequestSerial = 0;

  void _requestEdit(String nodeId) {
    editRequest.value = MindmapEditRequest(nodeId, ++_editRequestSerial);
  }

  void consumeEditRequest(MindmapEditRequest request) {
    if (identical(editRequest.value, request)) {
      editRequest.value = null;
    }
  }

  void beginEditing(String nodeId) {
    if (_nodeData(nodeId) == null) return;
    _canvas.setSelection({nodeId});
    editingNodeId.value = nodeId;
  }

  void endEditing(String nodeId) {
    if (editingNodeId.value == nodeId) {
      editingNodeId.value = null;
    }
  }

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
  List<MindmapTree> get trees => MindmapTreeBuilder.buildAll(_canvas.elements);

  /// The root id of the tree containing [nodeId], or null if not found.
  String? rootIdOf(String nodeId) {
    for (final tree in trees) {
      if (tree.allNodes.containsKey(nodeId)) return tree.root.id;
    }
    return null;
  }

  bool isMindmapNode(String nodeId) => _nodeData(nodeId) != null;

  Set<String> subtreeIdsOf(String rootId) =>
      Set.unmodifiable(_subtreeIds(rootId));

  List<String> topLevelDragNodeIds(
    Iterable<String> nodeIds, {
    String? primaryId,
  }) {
    final candidates = <String>{
      for (final id in nodeIds)
        if (isMindmapNode(id)) id,
    };
    if (primaryId != null && isMindmapNode(primaryId)) {
      candidates.add(primaryId);
    }
    if (candidates.isEmpty) return const [];

    final topLevel = candidates.where((id) {
      for (final other in candidates) {
        if (other == id) continue;
        if (_isAncestorOf(other, id)) return false;
      }
      return true;
    }).toSet();

    final ordered = <String>[];
    for (final tree in trees) {
      for (final node in tree.visibleNodes) {
        if (topLevel.remove(node.id)) ordered.add(node.id);
      }
    }
    for (final element in _canvas.elements) {
      if (topLevel.remove(element.id)) ordered.add(element.id);
    }
    return ordered;
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
    _requestEdit(newId);
  }

  /// Add a sibling of [nodeId] (same parent, same side). No-op for root.
  void addSibling(String nodeId) {
    final node = _nodeData(nodeId);
    if (node == null || node.isRoot) return;
    final parentId = node.parentId;
    if (parentId == null) return;

    final side = node.side;
    final newId = 'node-${DateTime.now().microsecondsSinceEpoch}';
    final siblings = _childData(parentId, side: side);
    final currentIndex = siblings.indexWhere((child) => child.id == nodeId);
    final insertIndex = currentIndex < 0 ? siblings.length : currentIndex + 1;
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

    final newData = MindmapNodeData.fromWidgetData(
      newElement.widgetData,
    ).copyWith(order: insertIndex);
    final orderedNewElement = newElement.copyWith(
      widgetData: Map<String, dynamic>.unmodifiable(newData.toWidgetData()),
    );
    final reordered = <MindmapNodeData>[...siblings]
      ..insert(insertIndex, newData);
    final commands = <CanvasCommand>[];

    for (var i = 0; i < reordered.length; i++) {
      final sibling = reordered[i];
      if (sibling.id == newId) continue;
      final element = _canvas.elementById(sibling.id);
      if (element is! CanvasWidgetElement) continue;
      final updated = sibling.copyWith(order: i);
      if (_sameNodeData(sibling, updated)) continue;
      commands.add(
        UpdateElementCommand(
          before: element,
          after: element.copyWith(
            widgetData: Map<String, dynamic>.unmodifiable(
              updated.toWidgetData(),
            ),
          ),
          description: 'Insert mind map sibling',
        ),
      );
    }

    _canvas.addElement(orderedNewElement);
    if (commands.isNotEmpty) {
      _canvas.historyManager.execute(
        BatchCommand(
          commands: commands,
          description: 'Reorder mind map siblings',
        ),
        _canvas,
      );
    }
    relayoutOf(nodeId, select: newId);
    _requestEdit(newId);
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
      for (final id in toRemove) RemoveElementCommand(_canvas.elementById(id)!),
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
    relayoutOf(nodeId);
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

  // ── Drag reorder / reparent / detach ───────────────────────────────

  /// Compute the best drop target for a drag pointer at world [position].
  ///
  /// Three-phase algorithm:
  ///   **Phase 1 — pick the preview parent.** Among all visible nodes
  ///   (excluding self and self's descendants) find the nearest one `N` by
  ///   center distance. If `N` is within [parentThreshold], it becomes the
  ///   prospective parent → go to phase 2. Otherwise → phase 3.
  ///
  ///   **Phase 2 — fix the sort position under that parent.**
  ///     • If the dragged node is *already* a child of `N` (same parent),
  ///       this is a reorder: among `N`'s children find the anchor `A` whose
  ///       vertical band contains the pointer Y, and insert before/after it.
  ///     • If the dragged node is *not* a child of `N`, this is a reparent:
  ///       it will be appended to the end of `N`'s children (no sibling
  ///       subdivision needed).
  ///
  ///   **Phase 3 — no parent → detach.** Drop into empty space: promote the
  ///   dragged node to a new independent tree root.
  ///
  /// [parentThreshold] is in world units and gates phase 1 vs phase 3.
  MindmapDropTarget? computeDropTarget(
    String draggedNodeId,
    Offset position, {
    double parentThreshold = 120,
    Set<String>? excludedNodeIds,
  }) {
    final dragged = _nodeData(draggedNodeId);
    if (dragged == null) return null;
    final excludedIds = _dropExcludedIds(draggedNodeId, excludedNodeIds);

    // ── Phase 1: nearest candidate parent node. ─────────────────────
    _DropParentCandidate? previewParent;
    for (final tree in trees) {
      for (final n in tree.visibleNodes) {
        if (excludedIds.contains(n.id)) continue;
        // Skip the dragged node's own descendants (can't reparent into self).
        if (_isAncestorOf(draggedNodeId, n.id)) continue;
        final resolved = _resolveDropParent(tree, n, position);
        if (resolved == null) continue;
        if (excludedIds.contains(resolved.parent.id)) continue;
        if (_isAncestorOf(draggedNodeId, resolved.parent.id)) continue;
        final score = _previewParentScore(
          resolved.parent,
          resolved.side,
          position,
          excludeIds: excludedIds,
        );
        if (previewParent == null || score < previewParent.distance) {
          previewParent = resolved.withDistance(score);
        }
      }
    }

    // Nothing near enough (or nothing at all) → detach to empty space.
    if (previewParent == null || previewParent.distance > parentThreshold) {
      return MindmapDropTarget(
        kind: MindmapDropTargetKind.detached,
        nodeId: draggedNodeId,
        detachedCenter: _findOpenDetachedCenter(
          draggedNodeId,
          position,
          movingIds: excludedIds,
        ),
        reason: 'detach to empty space',
      );
    }

    final parentNode = previewParent.parent;

    // ── Phase 2: fix the sort position under the chosen parent. ─────
    final side = previewParent.side;
    final insertIndex = _insertIndexUnderParent(
      parentNode,
      side,
      position,
      excludeIds: excludedIds,
    );
    final isReorder = dragged.parentId == parentNode.id && dragged.side == side;

    // Different parent → reparent (appended to the parent's children).
    return MindmapDropTarget(
      kind: MindmapDropTargetKind.parent,
      nodeId: parentNode.id,
      parentId: parentNode.id,
      side: side,
      insertIndex: insertIndex,
      reason: isReorder
          ? 'sibling reorder'
          : 'reparent (score ${previewParent.distance.toStringAsFixed(0)})',
    );
  }

  _DropParentCandidate? _resolveDropParent(
    MindmapTree tree,
    MindmapTreeNode hover,
    Offset position,
  ) {
    if (hover.data.isRoot) {
      return _DropParentCandidate(
        hover: hover,
        parent: hover,
        side: _sideForDropParent(hover, position),
      );
    }

    final hoverSide = hover.data.side == MindmapNodeSide.left
        ? MindmapNodeSide.left
        : MindmapNodeSide.right;
    final parentSideHalf = hoverSide == MindmapNodeSide.right
        ? position.dx <= hover.center.dx
        : position.dx >= hover.center.dx;

    if (parentSideHalf) {
      final parentId = hover.data.parentId;
      final parent = parentId == null
          ? null
          : _visibleNodeInTree(tree, parentId);
      if (parent != null) {
        return _DropParentCandidate(
          hover: hover,
          parent: parent,
          side: parent.data.isRoot
              ? hoverSide
              : _sideForDropParent(parent, position),
        );
      }
    }

    return _DropParentCandidate(
      hover: hover,
      parent: hover,
      side: _sideForDropParent(hover, position),
    );
  }

  MindmapTreeNode? _visibleNodeInTree(MindmapTree tree, String nodeId) {
    for (final node in tree.visibleNodes) {
      if (node.id == nodeId) return node;
    }
    return null;
  }

  MindmapNodeSide _sideForDropParent(MindmapTreeNode parent, Offset position) {
    if (!parent.data.isRoot) {
      return parent.data.side == MindmapNodeSide.left
          ? MindmapNodeSide.left
          : MindmapNodeSide.right;
    }
    return position.dx < parent.center.dx
        ? MindmapNodeSide.left
        : MindmapNodeSide.right;
  }

  double _previewParentScore(
    MindmapTreeNode parent,
    MindmapNodeSide side,
    Offset position, {
    required Set<String> excludeIds,
  }) {
    final nodeScore = _distanceToRect(position, parent.rect.inflate(24));
    if (nodeScore == 0) return 0;

    const config = MindmapLayoutConfig();
    final childLaneX = side == MindmapNodeSide.left
        ? parent.rect.left - config.horizontalGap - config.nodeWidth / 2
        : parent.rect.right + config.horizontalGap + config.nodeWidth / 2;
    final dx = (position.dx - childLaneX).abs();
    final children = _visibleChildrenOnSide(
      parent,
      side,
      excludeIds: excludeIds,
    );

    double top;
    double bottom;
    if (children.isEmpty) {
      top = parent.rect.top - config.nodeHeight - config.siblingGap;
      bottom = parent.rect.bottom + config.nodeHeight + config.siblingGap;
    } else {
      top = children.first.rect.top;
      bottom = children.first.rect.bottom;
      for (final child in children.skip(1)) {
        if (child.rect.top < top) top = child.rect.top;
        if (child.rect.bottom > bottom) bottom = child.rect.bottom;
      }
      top -= config.siblingGap * 2;
      bottom += config.siblingGap * 2;
    }

    final dy = position.dy < top
        ? top - position.dy
        : position.dy > bottom
        ? position.dy - bottom
        : 0.0;
    final laneScore = dx + dy * 0.75;
    final parentScore = nodeScore + 24;
    return laneScore < parentScore ? laneScore : parentScore;
  }

  double _distanceToRect(Offset point, Rect rect) {
    final dx = point.dx < rect.left
        ? rect.left - point.dx
        : point.dx > rect.right
        ? point.dx - rect.right
        : 0.0;
    final dy = point.dy < rect.top
        ? rect.top - point.dy
        : point.dy > rect.bottom
        ? point.dy - rect.bottom
        : 0.0;
    return Offset(dx, dy).distance;
  }

  int _insertIndexUnderParent(
    MindmapTreeNode parent,
    MindmapNodeSide side,
    Offset position, {
    required Set<String> excludeIds,
  }) {
    final children = _visibleChildrenOnSide(
      parent,
      side,
      excludeIds: excludeIds,
    );
    var index = 0;
    for (final child in children) {
      if (position.dy > child.center.dy) index++;
    }
    return index;
  }

  List<MindmapTreeNode> _visibleChildrenOnSide(
    MindmapTreeNode parent,
    MindmapNodeSide side, {
    required Set<String> excludeIds,
  }) {
    return parent.children.where((child) {
      if (excludeIds.contains(child.id)) return false;
      if (!parent.data.isRoot) return true;
      final childSide = child.data.side == MindmapNodeSide.left
          ? MindmapNodeSide.left
          : MindmapNodeSide.right;
      return childSide == side;
    }).toList();
  }

  Set<String> _dropExcludedIds(String draggedNodeId, Set<String>? extraIds) {
    final ids = <String>{..._subtreeIds(draggedNodeId)};
    if (extraIds != null) ids.addAll(extraIds);
    return ids;
  }

  Offset _findOpenDetachedCenter(
    String draggedNodeId,
    Offset preferred, {
    Set<String>? movingIds,
  }) {
    final draggedEl = _canvas.elementById(draggedNodeId);
    final excludedIds = movingIds ?? _subtreeIds(draggedNodeId);
    final movingBounds = _boundsForIds(excludedIds);
    final fallbackBounds = draggedEl is CanvasWidgetElement
        ? draggedEl.worldRect
        : Rect.fromCenter(center: preferred, width: 120, height: 40);
    final footprint = movingBounds ?? fallbackBounds;
    final originCenter = draggedEl is CanvasWidgetElement
        ? draggedEl.worldRect.center
        : footprint.center;

    const gap = 48.0;
    final stepX = footprint.width + gap;
    final stepY = footprint.height + gap;
    final candidates = <Offset>[
      preferred,
      preferred + Offset(stepX, 0),
      preferred + Offset(-stepX, 0),
      preferred + Offset(0, stepY),
      preferred + Offset(0, -stepY),
      preferred + Offset(stepX, stepY),
      preferred + Offset(stepX, -stepY),
      preferred + Offset(-stepX, stepY),
      preferred + Offset(-stepX, -stepY),
      preferred + Offset(stepX * 2, 0),
      preferred + Offset(-stepX * 2, 0),
      preferred + Offset(0, stepY * 2),
      preferred + Offset(0, -stepY * 2),
    ];

    for (final candidate in candidates) {
      final rect = footprint.shift(candidate - originCenter).inflate(gap / 2);
      if (!_intersectsOtherVisibleElements(rect, excludedIds)) {
        return candidate;
      }
    }
    return preferred;
  }

  Set<String> _subtreeIds(String rootId) {
    final ids = <String>{rootId};
    for (final element in _canvas.elements) {
      if (element is! CanvasWidgetElement) continue;
      if (element.widgetType != kMindmapNodeWidgetType) continue;
      if (element.id == rootId || _isAncestorOf(rootId, element.id)) {
        ids.add(element.id);
      }
    }
    return ids;
  }

  Rect? _boundsForIds(Set<String> ids) {
    Rect? bounds;
    for (final id in ids) {
      final element = _canvas.elementById(id);
      if (element == null) continue;
      bounds = bounds == null
          ? element.bounds
          : bounds.expandToInclude(element.bounds);
    }
    return bounds;
  }

  bool _intersectsOtherVisibleElements(Rect rect, Set<String> excludeIds) {
    for (final element in _canvas.elements) {
      if (!element.visible || excludeIds.contains(element.id)) continue;
      if (rect.overlaps(element.bounds)) return true;
    }
    return false;
  }

  /// Predict where [draggedNodeId] would land if dropped on [target].
  ///
  /// Returns the predicted world rect + the connection line from the
  /// (prospective) parent edge to the node. Used to render the drop shadow
  /// and preview connection during the drag.
  MindmapDropPreview? computeDropPreview(
    String draggedNodeId,
    MindmapDropTarget? target, {
    Set<String>? excludedNodeIds,
  }) {
    if (target == null) return null;
    final draggedEl = _canvas.elementById(draggedNodeId);
    if (draggedEl is! CanvasWidgetElement) return null;
    final excludedIds = _dropExcludedIds(draggedNodeId, excludedNodeIds);

    // Detached: the node becomes an independent root centered on the pointer.
    // There is no parent, so there is no connection to preview.
    if (target.kind == MindmapDropTargetKind.detached) {
      final draggedData = MindmapNodeData.fromWidgetData(draggedEl.widgetData);
      final size = Size(
        MindmapNodeMetrics.widthForText(draggedData.text, isRoot: true),
        MindmapNodeMetrics.rootHeight,
      );
      final center = target.detachedCenter ?? dragSession.worldPosition;
      final previewRect = Rect.fromCenter(
        center: center,
        width: size.width,
        height: size.height,
      );
      return MindmapDropPreview(rect: previewRect, connection: null);
    }

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
    final laidOutRect = result.rects[draggedNodeId];
    final previewRect = laidOutRect == null
        ? null
        : _offsetPreviewRectForInsertion(
            laidOutRect,
            target,
            excludedIds: excludedIds,
          );
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

  Rect _offsetPreviewRectForInsertion(
    Rect rect,
    MindmapDropTarget target, {
    required Set<String> excludedIds,
  }) {
    if (target.kind != MindmapDropTargetKind.parent) return rect;

    const config = MindmapLayoutConfig();
    final side = target.side ?? MindmapNodeSide.right;
    final parentId = target.parentId ?? target.nodeId;
    final parent = _canvas.elementById(parentId);

    final children = _visibleChildElementsForSlot(
      parentId,
      side,
      excludedIds: excludedIds,
    );
    final insertIndex = (target.insertIndex ?? children.length)
        .clamp(0, children.length)
        .toInt();
    final isBetweenSiblings =
        children.isNotEmpty && insertIndex > 0 && insertIndex < children.length;

    Rect slotRect = rect;
    var preferredDirection = 1.0;
    if (children.isEmpty) {
      if (parent is CanvasWidgetElement) {
        slotRect = Rect.fromCenter(
          center: Offset(rect.center.dx, parent.worldRect.center.dy),
          width: rect.width,
          height: rect.height,
        );
      }
    } else if (insertIndex == 0) {
      final anchor = children.first.worldRect;
      preferredDirection = -1;
      slotRect = Rect.fromCenter(
        center: Offset(
          rect.center.dx,
          anchor.top - config.siblingGap - rect.height / 2,
        ),
        width: rect.width,
        height: rect.height,
      );
    } else if (insertIndex < children.length) {
      final previous = children[insertIndex - 1].worldRect;
      final next = children[insertIndex].worldRect;
      preferredDirection =
          rect.center.dy < (previous.center.dy + next.center.dy) / 2 ? -1 : 1;
      slotRect = Rect.fromCenter(
        center: Offset(rect.center.dx, (previous.bottom + next.top) / 2),
        width: rect.width,
        height: rect.height,
      );
    } else {
      final anchor = children.last.worldRect;
      preferredDirection = 1;
      slotRect = Rect.fromCenter(
        center: Offset(
          rect.center.dx,
          anchor.bottom + config.siblingGap + rect.height / 2,
        ),
        width: rect.width,
        height: rect.height,
      );
    }

    bool overlapsCurrent(Rect candidate) {
      final inflated = candidate.inflate(2);
      for (final element in _canvas.elements) {
        if (!element.visible || excludedIds.contains(element.id)) continue;
        if (inflated.overlaps(element.bounds)) return true;
      }
      return false;
    }

    if (isBetweenSiblings) return slotRect;
    if (!overlapsCurrent(slotRect)) return slotRect;

    final stepY = rect.height + config.siblingGap;
    final candidates = [
      slotRect.shift(Offset(0, preferredDirection * stepY)),
      slotRect.shift(Offset(0, -preferredDirection * stepY)),
      slotRect.shift(Offset(0, preferredDirection * stepY * 2)),
      slotRect.shift(Offset(0, -preferredDirection * stepY * 2)),
    ];

    for (final candidate in candidates) {
      if (!overlapsCurrent(candidate)) return candidate;
    }
    return candidates.first;
  }

  List<CanvasWidgetElement> _visibleChildElementsForSlot(
    String parentId,
    MindmapNodeSide side, {
    required Set<String> excludedIds,
  }) {
    final parent = _nodeData(parentId);
    final children = <CanvasWidgetElement>[];
    for (final element in _canvas.elements) {
      if (element is! CanvasWidgetElement) continue;
      if (element.widgetType != kMindmapNodeWidgetType) continue;
      if (!element.visible || excludedIds.contains(element.id)) continue;
      final data = MindmapNodeData.fromWidgetData(element.widgetData);
      if (data.parentId != parentId) continue;
      if (parent?.isRoot == true) {
        final childSide = data.side == MindmapNodeSide.left
            ? MindmapNodeSide.left
            : MindmapNodeSide.right;
        if (childSide != side) continue;
      }
      children.add(element);
    }
    children.sort((a, b) {
      final dataA = MindmapNodeData.fromWidgetData(a.widgetData);
      final dataB = MindmapNodeData.fromWidgetData(b.widgetData);
      return dataA.order.compareTo(dataB.order);
    });
    return children;
  }

  /// Build a hypothetical element list reflecting what the canvas would look
  /// like if [draggedNodeId] were dropped on [target].
  ///
  /// - [parent]: rewrite `parentId` + `side`, append after the parent's
  ///   existing children (order = max sibling order + 1).
  /// - [detached]: promote to an independent root (`isRoot`, no `parentId`,
  ///   `side = center`, `order = 0`).
  List<CanvasElement> _simulateElements(
    String draggedNodeId,
    MindmapDropTarget target,
  ) {
    final parentRenumbered = target.kind == MindmapDropTargetKind.parent
        ? _renumberedChildrenForTarget(draggedNodeId, target)
        : const <String, MindmapNodeData>{};

    return [
      for (final e in _canvas.elements)
        if (e is CanvasWidgetElement && e.widgetType == kMindmapNodeWidgetType)
          _simulateMindmapElement(e, draggedNodeId, target, parentRenumbered)
        else
          e,
    ];
  }

  CanvasElement _simulateMindmapElement(
    CanvasWidgetElement e,
    String draggedNodeId,
    MindmapDropTarget target,
    Map<String, MindmapNodeData> parentRenumbered,
  ) {
    switch (target.kind) {
      case MindmapDropTargetKind.parent:
        final updated = parentRenumbered[e.id];
        if (updated == null) return e;
        return e.copyWith(
          widgetData: Map<String, dynamic>.unmodifiable(updated.toWidgetData()),
        );
      case MindmapDropTargetKind.detached:
        if (e.id != draggedNodeId) return e;
        final data = MindmapNodeData.fromWidgetData(e.widgetData);
        final simulated = _asRootNode(data);
        return e.copyWith(
          widgetData: Map<String, dynamic>.unmodifiable(
            simulated.toWidgetData(),
          ),
        );
    }
  }

  Map<String, MindmapNodeData> _renumberedChildrenForTarget(
    String draggedNodeId,
    MindmapDropTarget target,
  ) {
    return _renumberedChildrenForTargets([draggedNodeId], target);
  }

  Map<String, MindmapNodeData> _renumberedChildrenForTargets(
    List<String> draggedNodeIds,
    MindmapDropTarget target,
  ) {
    final draggedNodes = [
      for (final id in draggedNodeIds)
        if (_nodeData(id) != null) _nodeData(id)!,
    ];
    final parentId = target.parentId ?? target.nodeId;
    final parent = _nodeData(parentId);
    if (draggedNodes.isEmpty || parent == null) return {};
    final draggedIdSet = draggedNodes.map((node) => node.id).toSet();

    final side =
        target.side ??
        (parent.isRoot
            ? MindmapNodeSide.right
            : parent.side == MindmapNodeSide.left
            ? MindmapNodeSide.left
            : MindmapNodeSide.right);
    final children = <MindmapNodeData>[];
    for (final child in _childData(parentId, side: side)) {
      if (!draggedIdSet.contains(child.id)) children.add(child);
    }

    final insertIndex = (target.insertIndex ?? children.length)
        .clamp(0, children.length)
        .toInt();
    children.insertAll(
      insertIndex,
      draggedNodes.map(
        (dragged) => _asChildNode(
          dragged,
          parentId: parentId,
          side: side,
          clearCollapse: true,
        ),
      ),
    );

    final result = <String, MindmapNodeData>{};
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      result[child.id] = _asChildNode(
        child,
        parentId: parentId,
        side: side,
        order: i,
      );
    }
    for (final dragged in draggedNodes) {
      for (final descendantId in _subtreeIds(dragged.id)) {
        if (descendantId == dragged.id || result.containsKey(descendantId)) {
          continue;
        }
        final descendant = _nodeData(descendantId);
        if (descendant == null) continue;
        result[descendantId] = _asDescendantOnSide(descendant, side);
      }
    }
    return result;
  }

  List<MindmapNodeData> _childData(String parentId, {MindmapNodeSide? side}) {
    final children = <MindmapNodeData>[];
    for (final e in _canvas.elements) {
      if (e is! CanvasWidgetElement) continue;
      if (e.widgetType != kMindmapNodeWidgetType) continue;
      final data = MindmapNodeData.fromWidgetData(e.widgetData);
      if (data.parentId != parentId) continue;
      if (side != null) {
        final childSide = data.side == MindmapNodeSide.left
            ? MindmapNodeSide.left
            : MindmapNodeSide.right;
        if (childSide != side) continue;
      }
      children.add(data);
    }
    children.sort((a, b) => a.order.compareTo(b.order));
    return children;
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

  /// Execute a reorder, reparent or detach for [draggedNodeId] given [target].
  ///
  /// - sibling reorder: the dragged node is moved within its parent's
  ///   children list to before/after [target.nodeId].
  /// - reparent: the node's `parentId`/`side`/`order` are updated to match the
  ///   new parent (appended to the end of its children).
  /// - detach: the node is promoted to an independent tree root at
  ///   [dropPosition] (or its current position if null).
  ///
  /// A relayout is triggered at the end.
  void reorderOrReparent(
    String draggedNodeId,
    MindmapDropTarget? target, {
    Offset? dropPosition,
  }) {
    _reorderOrReparentOne(draggedNodeId, target, dropPosition: dropPosition);
  }

  void reorderOrReparentMany(
    List<String> draggedNodeIds,
    MindmapDropTarget? target, {
    Offset? dropPosition,
  }) {
    final structuralIds = topLevelDragNodeIds(
      draggedNodeIds,
      primaryId: draggedNodeIds.isEmpty ? null : draggedNodeIds.first,
    );
    if (structuralIds.isEmpty) return;

    if (target == null) {
      final roots = <String>{};
      for (final id in structuralIds) {
        final rootId = rootIdOf(id);
        if (rootId != null) roots.add(rootId);
      }
      for (final rootId in roots) {
        relayout(rootId);
      }
      return;
    }

    switch (target.kind) {
      case MindmapDropTargetKind.parent:
        _reparentManyToTarget(structuralIds, target);
        break;
      case MindmapDropTargetKind.detached:
        _detachMany(
          structuralIds,
          target.detachedCenter ?? dropPosition,
          primaryId: target.nodeId,
        );
        break;
    }
  }

  void _reorderOrReparentOne(
    String draggedNodeId,
    MindmapDropTarget? target, {
    Offset? dropPosition,
  }) {
    if (target == null) {
      // No valid drop — just relayout to snap back to original position.
      relayoutOf(draggedNodeId);
      return;
    }

    final dragged = _nodeData(draggedNodeId);
    if (dragged == null) return;

    switch (target.kind) {
      case MindmapDropTargetKind.parent:
        _reparentToTarget(draggedNodeId, target);
        break;
      case MindmapDropTargetKind.detached:
        _detach(draggedNodeId, target.detachedCenter ?? dropPosition);
        break;
    }
  }

  void _reparentToTarget(String draggedNodeId, MindmapDropTarget target) {
    final dragged = _nodeData(draggedNodeId);
    if (dragged == null) return;
    final newParentId = target.parentId ?? target.nodeId;
    final newParent = _nodeData(newParentId);
    if (newParent == null) return;

    final originalRootId = rootIdOf(draggedNodeId);
    final newSide =
        target.side ??
        (newParent.isRoot ? MindmapNodeSide.right : newParent.side);
    final renumbered = _renumberedChildrenForTarget(draggedNodeId, target);
    final commands = <CanvasCommand>[];

    for (final entry in renumbered.entries) {
      final element = _canvas.elementById(entry.key);
      if (element is! CanvasWidgetElement) continue;
      final before = MindmapNodeData.fromWidgetData(element.widgetData);
      final after = entry.value;
      if (_sameNodeData(before, after)) continue;
      commands.add(
        UpdateElementCommand(
          before: element,
          after: element.copyWith(
            widgetData: Map<String, dynamic>.unmodifiable(after.toWidgetData()),
          ),
          description: 'Move mind map node',
        ),
      );
    }

    if (commands.isNotEmpty) {
      _canvas.historyManager.execute(
        BatchCommand(commands: commands, description: 'Move mind map node'),
        _canvas,
      );
    }

    _setCollapsed(newParentId, newSide, false);

    final destRootId = rootIdOf(newParentId);
    if (destRootId != null) relayout(destRootId);
    if (originalRootId != null && originalRootId != destRootId) {
      relayout(originalRootId);
    }
  }

  void _reparentManyToTarget(
    List<String> draggedNodeIds,
    MindmapDropTarget target,
  ) {
    if (draggedNodeIds.isEmpty) return;
    final newParentId = target.parentId ?? target.nodeId;
    final newParent = _nodeData(newParentId);
    if (newParent == null) return;

    final originalRootIds = <String>{};
    for (final id in draggedNodeIds) {
      final rootId = rootIdOf(id);
      if (rootId != null) originalRootIds.add(rootId);
    }
    final newSide =
        target.side ??
        (newParent.isRoot ? MindmapNodeSide.right : newParent.side);
    final renumbered = _renumberedChildrenForTargets(draggedNodeIds, target);
    final commands = <CanvasCommand>[];

    for (final entry in renumbered.entries) {
      final element = _canvas.elementById(entry.key);
      if (element is! CanvasWidgetElement) continue;
      final before = MindmapNodeData.fromWidgetData(element.widgetData);
      final after = entry.value;
      if (_sameNodeData(before, after)) continue;
      commands.add(
        UpdateElementCommand(
          before: element,
          after: element.copyWith(
            widgetData: Map<String, dynamic>.unmodifiable(after.toWidgetData()),
          ),
          description: 'Move mind map nodes',
        ),
      );
    }

    if (commands.isNotEmpty) {
      _canvas.historyManager.execute(
        BatchCommand(commands: commands, description: 'Move mind map nodes'),
        _canvas,
      );
    }

    _setCollapsed(newParentId, newSide, false);
    _canvas.setSelection(draggedNodeIds.toSet());

    final destRootId = rootIdOf(newParentId);
    if (destRootId != null) relayout(destRootId);
    for (final originalRootId in originalRootIds) {
      if (originalRootId != destRootId) relayout(originalRootId);
    }
  }

  /// Promote [draggedNodeId] to an independent tree root placed at
  /// [dropPosition] (world coords). The node keeps its text/color/size but
  /// loses its parent, becomes a root, and clears all collapse flags. The
  /// subtree travels with it (descendants keep their `parentId` links).
  void _detach(String draggedNodeId, Offset? dropPosition) {
    final dragged = _nodeData(draggedNodeId);
    if (dragged == null) return;

    // Root nodes are already detached — nothing structural to do.
    if (dragged.isRoot) {
      _moveRootToDetachedCenter(draggedNodeId, dropPosition);
      return;
    }

    final originalRootId = rootIdOf(draggedNodeId);
    final element = _canvas.elementById(draggedNodeId);
    if (element is! CanvasWidgetElement) return;

    // New rect: center on the drop position, keep the node's current size.
    final newRect = dropPosition == null
        ? element.worldRect
        : Rect.fromCenter(
            center: dropPosition,
            width: element.worldRect.width,
            height: element.worldRect.height,
          );

    final detached = _asRootNode(dragged);

    // Write both the data change and the new position in a single command so
    // undo restores them together.
    final after = element.copyWith(
      worldRect: newRect,
      widgetData: Map<String, dynamic>.unmodifiable(detached.toWidgetData()),
    );
    _canvas.historyManager.execute(
      UpdateElementCommand(
        before: element,
        after: after,
        description: 'Detach mind map node to new tree',
      ),
      _canvas,
    );

    final descendantCommands = <CanvasCommand>[];
    for (final descendantId in _subtreeIds(draggedNodeId)) {
      if (descendantId == draggedNodeId) continue;
      final descendantEl = _canvas.elementById(descendantId);
      if (descendantEl is! CanvasWidgetElement) continue;
      final descendant = MindmapNodeData.fromWidgetData(
        descendantEl.widgetData,
      );
      final next = descendant.copyWith(
        side: MindmapNodeSide.right,
        isRoot: false,
      );
      descendantCommands.add(
        UpdateElementCommand(
          before: descendantEl,
          after: descendantEl.copyWith(
            widgetData: Map<String, dynamic>.unmodifiable(next.toWidgetData()),
          ),
          description: 'Detach mind map subtree',
        ),
      );
    }
    if (descendantCommands.isNotEmpty) {
      _canvas.historyManager.execute(
        BatchCommand(
          commands: descendantCommands,
          description: 'Detach mind map subtree',
        ),
        _canvas,
      );
    }

    _canvas.setSelection({draggedNodeId});
    relayout(draggedNodeId);
    // Fix the gap left in the original tree.
    if (originalRootId != null) relayout(originalRootId);
  }

  void _moveRootToDetachedCenter(String rootId, Offset? dropPosition) {
    final element = _canvas.elementById(rootId);
    if (element is! CanvasWidgetElement) return;
    if (dropPosition != null) {
      final newRect = Rect.fromCenter(
        center: dropPosition,
        width: element.worldRect.width,
        height: element.worldRect.height,
      );
      _canvas.historyManager.execute(
        UpdateElementCommand(
          before: element,
          after: element.copyWith(worldRect: newRect),
          description: 'Move mind map root',
        ),
        _canvas,
      );
    }
    _canvas.setSelection({rootId});
    relayout(rootId);
  }

  void _detachMany(
    List<String> draggedNodeIds,
    Offset? dropPosition, {
    String? primaryId,
  }) {
    if (draggedNodeIds.isEmpty) return;

    final originalRootIds = <String>{};
    for (final id in draggedNodeIds) {
      final rootId = rootIdOf(id);
      if (rootId != null) originalRootIds.add(rootId);
    }

    final primary = _canvas.elementById(primaryId ?? draggedNodeIds.first);
    final delta = primary is CanvasWidgetElement && dropPosition != null
        ? dropPosition - primary.worldRect.center
        : Offset.zero;

    final rootIds = draggedNodeIds.toSet();
    final wasRootById = {
      for (final id in draggedNodeIds) id: _nodeData(id)?.isRoot == true,
    };
    final detachedIdSet = <String>{};
    for (final id in draggedNodeIds) {
      detachedIdSet.addAll(_subtreeIds(id));
    }

    final commands = <CanvasCommand>[];
    for (final id in detachedIdSet) {
      final isDetachedRoot = rootIds.contains(id);
      final detachedRootId = isDetachedRoot
          ? id
          : draggedNodeIds
                .where((rootId) => _isAncestorOf(rootId, id))
                .firstOrNull;
      final preservesExistingTree =
          detachedRootId != null && wasRootById[detachedRootId] == true;
      final rootDelta = isDetachedRoot ? delta : Offset.zero;
      final side = isDetachedRoot
          ? MindmapNodeSide.center
          : preservesExistingTree
          ? _nodeData(id)?.side ?? MindmapNodeSide.right
          : MindmapNodeSide.right;
      final parentId = isDetachedRoot ? null : _nodeData(id)?.parentId;
      final dragged = _nodeData(id);
      final element = _canvas.elementById(id);
      if (dragged == null || element is! CanvasWidgetElement) continue;
      final isExistingRoot = isDetachedRoot && wasRootById[id] == true;

      final detached = isDetachedRoot
          ? isExistingRoot
                ? dragged.copyWith(
                    parentId: null,
                    isRoot: true,
                    side: MindmapNodeSide.center,
                    order: 0,
                  )
                : _asRootNode(dragged)
          : _asDescendantOnSide(
              dragged,
              side,
            ).copyWith(parentId: parentId, order: dragged.order);
      commands.add(
        UpdateElementCommand(
          before: element,
          after: element.copyWith(
            worldRect: element.worldRect.shift(rootDelta),
            widgetData: Map<String, dynamic>.unmodifiable(
              detached.toWidgetData(),
            ),
          ),
          description: 'Detach mind map nodes',
        ),
      );
    }

    if (commands.isNotEmpty) {
      _canvas.historyManager.execute(
        BatchCommand(commands: commands, description: 'Detach mind map nodes'),
        _canvas,
      );
    }

    _canvas.setSelection(draggedNodeIds.toSet());
    for (final id in draggedNodeIds) {
      relayout(id);
    }
    for (final originalRootId in originalRootIds) {
      if (!draggedNodeIds.contains(originalRootId)) relayout(originalRootId);
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
      commands.add(
        UpdateElementCommand(
          before: element,
          after: element.copyWith(worldRect: newRect, visible: true),
          description: 'Relayout mind map node',
        ),
      );
    }
    // Hide nodes that belong to this tree but were pruned by collapse.
    for (final id in tree.allNodes.keys) {
      if (visibleIds.contains(id)) continue;
      final element = _canvas.elementById(id);
      if (element is! CanvasWidgetElement) continue;
      if (!element.visible) continue;
      commands.add(
        UpdateElementCommand(
          before: element,
          after: element.copyWith(visible: false),
          description: 'Hide collapsed mind map node',
        ),
      );
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

  MindmapNodeData _asRootNode(MindmapNodeData data) {
    return data.copyWith(
      parentId: null,
      side: MindmapNodeSide.center,
      isRoot: true,
      isCollapsed: false,
      collapsedRight: false,
      collapsedLeft: false,
      order: 0,
      color: _rootNodeColor,
      textColor: _rootTextColor,
    );
  }

  MindmapNodeData _asChildNode(
    MindmapNodeData data, {
    required String parentId,
    required MindmapNodeSide side,
    int? order,
    bool clearCollapse = false,
  }) {
    final roleChanged = data.isRoot || data.parentId == null;
    return data.copyWith(
      parentId: parentId,
      side: side,
      isRoot: false,
      isCollapsed: clearCollapse || roleChanged ? false : data.isCollapsed,
      collapsedRight: false,
      collapsedLeft: false,
      order: order ?? data.order,
      color: roleChanged ? _childNodeColor : data.color,
      textColor: roleChanged ? _childTextColor : data.textColor,
    );
  }

  MindmapNodeData _asDescendantOnSide(
    MindmapNodeData data,
    MindmapNodeSide side,
  ) {
    final roleChanged = data.isRoot || data.parentId == null;
    return data.copyWith(
      side: side,
      isRoot: false,
      collapsedRight: false,
      collapsedLeft: false,
      color: roleChanged ? _childNodeColor : data.color,
      textColor: roleChanged ? _childTextColor : data.textColor,
    );
  }

  bool _sameNodeData(MindmapNodeData a, MindmapNodeData b) {
    return a.id == b.id &&
        a.text == b.text &&
        a.parentId == b.parentId &&
        a.side == b.side &&
        a.isCollapsed == b.isCollapsed &&
        a.collapsedRight == b.collapsedRight &&
        a.collapsedLeft == b.collapsedLeft &&
        a.isRoot == b.isRoot &&
        a.order == b.order &&
        a.color == b.color &&
        a.textColor == b.textColor;
  }

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
      return const Rect.fromLTWH(
        0,
        0,
        MindmapNodeMetrics.minNodeWidth,
        MindmapNodeMetrics.nodeHeight,
      );
    }
    return Rect.fromCenter(
      center: ref.bounds.center + const Offset(160, 0),
      width: MindmapNodeMetrics.minNodeWidth,
      height: MindmapNodeMetrics.nodeHeight,
    );
  }

  CanvasWidgetElement _makeElement(MindmapNodeData data, Rect rect) {
    return makeMindmapNodeElement(data: data, rect: rect);
  }
}

class _DropParentCandidate {
  const _DropParentCandidate({
    required this.hover,
    required this.parent,
    required this.side,
    this.distance = double.infinity,
  });

  final MindmapTreeNode hover;
  final MindmapTreeNode parent;
  final MindmapNodeSide side;
  final double distance;

  _DropParentCandidate withDistance(double distance) {
    return _DropParentCandidate(
      hover: hover,
      parent: parent,
      side: side,
      distance: distance,
    );
  }
}

class MindmapEditRequest {
  const MindmapEditRequest(this.nodeId, this.serial);

  final String nodeId;
  final int serial;
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
    clipBehavior: Clip.none,
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
    width: MindmapNodeMetrics.widthForText(rootText, isRoot: true),
    height: MindmapNodeMetrics.rootHeight,
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
    asWidget(
      MindmapNodeData(
        id: '$rootId-r1',
        text: '分支1',
        parentId: rootId,
        side: MindmapNodeSide.right,
      ),
    ),
    asWidget(
      MindmapNodeData(
        id: '$rootId-r2',
        text: '分支2',
        parentId: rootId,
        side: MindmapNodeSide.right,
      ),
    ),
    asWidget(
      MindmapNodeData(
        id: '$rootId-l1',
        text: '分支3',
        parentId: rootId,
        side: MindmapNodeSide.left,
      ),
    ),
  ];
}

import 'package:flutter/widgets.dart';

import 'mindmap_node.dart';

/// The kind of drop target the drag is currently hovering over.
///
/// - [parent]: reparent the dragged node under [MindmapDropTarget.nodeId].
/// - [detached]: drop into empty space — promote the dragged node to a new
///   independent tree root (no parent, no connection line).
enum MindmapDropTargetKind { parent, detached }

/// A candidate drop target computed during a drag.
class MindmapDropTarget {
  const MindmapDropTarget({
    required this.kind,
    required this.nodeId,
    required this.reason,
    this.parentId,
    this.side,
    this.insertIndex,
    this.detachedCenter,
  });

  /// What role [nodeId] would play if dropped here.
  ///
  /// For [MindmapDropTargetKind.detached], [nodeId] is the dragged node's own
  /// id (the node is being promoted to an independent root, so there is no
  /// target node to reference).
  final MindmapDropTargetKind kind;

  /// The id of the node being targeted (a sibling to insert next to, or a
  /// prospective new parent). For [MindmapDropTargetKind.detached] this is the
  /// dragged node's own id.
  final String nodeId;

  /// Owning parent after the drop. Null for detached drops.
  final String? parentId;

  /// Side under [parentId] after the drop. Root parents use left/right;
  /// non-root parents inherit their own side.
  final MindmapNodeSide? side;

  /// Zero-based position among the children of [parentId] on [side].
  final int? insertIndex;

  /// Final root center for detached drops, already adjusted to an open area.
  final Offset? detachedCenter;

  /// Human-readable reason for debugging.
  final String reason;

  @override
  String toString() {
    return 'DropTarget($kind, node=$nodeId, parent=$parentId, '
        'index=$insertIndex, reason=$reason)';
  }
}

/// A preview of where the dragged node will land if dropped on the current
/// target — the predicted world rect + the connection line that would link
/// it to its (new) parent.
class MindmapDropPreview {
  const MindmapDropPreview({required this.rect, required this.connection});

  /// Predicted world rect of the dragged node after layout.
  final Rect rect;

  /// Predicted connection: from the parent's edge to this node's edge.
  /// Null when there is no parent connection (shouldn't happen for non-root).
  final MindmapPreviewConnection? connection;
}

/// A predicted connection segment for the drop preview.
class MindmapPreviewConnection {
  const MindmapPreviewConnection({required this.from, required this.to});

  /// Start point (parent edge center), world coords.
  final Offset from;

  /// End point (dragged node edge center), world coords.
  final Offset to;
}

/// State for an active mind map node drag.
///
/// Created by [MindmapNodeBuilder] when the user long-presses a non-root
/// node and starts moving. The connection layer listens to this notifier to
/// render: the ghost following the pointer, the drop shadow at the predicted
/// landing rect, and the preview connection line.
class MindmapDragSession extends ChangeNotifier {
  MindmapDragSession();

  /// The id of the node being dragged, or null when idle.
  String? _draggedNodeId;
  String? get draggedNodeId => _draggedNodeId;

  /// Top-level nodes that will be structurally moved on drop.
  List<String> _draggedNodeIds = const [];
  List<String> get draggedNodeIds => List.unmodifiable(_draggedNodeIds);

  /// All visible/owned nodes that visually follow the pointer during drag.
  List<String> _movingNodeIds = const [];
  List<String> get movingNodeIds => List.unmodifiable(_movingNodeIds);

  /// Current world-space position of the pointer (the ghost node center).
  Offset _worldPosition = Offset.zero;
  Offset get worldPosition => _worldPosition;

  /// The node's original world center (where it was before the drag).
  Offset _origin = Offset.zero;
  Offset get origin => _origin;

  final Map<String, Offset> _origins = {};
  Offset? originOf(String nodeId) => _origins[nodeId];

  /// The original parent id (to detect reparent vs reorder).
  String? _originalParentId;
  String? get originalParentId => _originalParentId;

  /// The original side of the dragged node.
  MindmapNodeSide _originalSide = MindmapNodeSide.right;
  MindmapNodeSide get originalSide => _originalSide;

  /// The current drop target, recomputed as the pointer moves.
  MindmapDropTarget? _target;
  MindmapDropTarget? get target => _target;

  /// Predicted landing position + connection for the current target.
  MindmapDropPreview? _preview;
  MindmapDropPreview? get preview => _preview;

  bool get isActive => _draggedNodeId != null;

  /// Begin dragging [nodeId] at [worldOrigin], with the given original parent
  /// and side.
  void start({
    required String nodeId,
    required Offset worldOrigin,
    required String? originalParentId,
    required MindmapNodeSide originalSide,
    List<String>? nodeIds,
    List<String>? movingNodeIds,
    Map<String, Offset>? origins,
  }) {
    _draggedNodeId = nodeId;
    _draggedNodeIds = List.unmodifiable(nodeIds ?? [nodeId]);
    _movingNodeIds = List.unmodifiable(movingNodeIds ?? _draggedNodeIds);
    _origin = worldOrigin;
    _origins
      ..clear()
      ..addAll(origins ?? {nodeId: worldOrigin});
    _worldPosition = worldOrigin;
    _originalParentId = originalParentId;
    _originalSide = originalSide;
    _target = null;
    _preview = null;
    notifyListeners();
  }

  /// Update only the pointer's world position (no target recompute). The sync
  /// controller listens to this via [notifyListeners] to snap the node to the
  /// pointer; target/preview are refreshed separately by [updateTarget].
  void updateWorld(Offset worldPosition) {
    _worldPosition = worldPosition;
    notifyListeners();
  }

  /// Update the computed [target] and predicted landing [preview], keeping the
  /// current world position.
  void updateTarget(MindmapDropTarget? target, MindmapDropPreview? preview) {
    _target = target;
    _preview = preview;
    notifyListeners();
  }

  /// Update the pointer's world position, the computed [target], and the
  /// predicted landing [preview].
  void update(
    Offset worldPosition,
    MindmapDropTarget? target,
    MindmapDropPreview? preview,
  ) {
    _worldPosition = worldPosition;
    _target = target;
    _preview = preview;
    notifyListeners();
  }

  /// End the drag. Returns the final target to act on (or null if no valid
  /// drop). Resets the session to idle.
  MindmapDropTarget? end() {
    final result = _target;
    _draggedNodeId = null;
    _draggedNodeIds = const [];
    _movingNodeIds = const [];
    _worldPosition = Offset.zero;
    _origin = Offset.zero;
    _origins.clear();
    _originalParentId = null;
    _target = null;
    _preview = null;
    notifyListeners();
    return result;
  }

  /// Cancel the drag without committing.
  void cancel() {
    _draggedNodeId = null;
    _draggedNodeIds = const [];
    _movingNodeIds = const [];
    _origins.clear();
    _target = null;
    _preview = null;
    notifyListeners();
  }
}

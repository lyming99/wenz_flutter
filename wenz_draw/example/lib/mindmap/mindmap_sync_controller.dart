import 'package:flutter/widgets.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_actions.dart';
import 'mindmap_node_data.dart';
import 'mindmap_tree.dart';

/// Keeps mind map trees visually consistent:
///   1. Expands the selection to the whole tree when a root is selected, so
///      dragging moves the entire tree atomically.
///   2. Detects when a **non-root** node is dragged by the select tool and
///      drives a [MindmapDragSession]: the dragged node follows the pointer
///      (select tool moves it), while the connection layer renders the ghost,
///      drop shadow + preview connection. On drag end, the node is
///      reordered / reparented and its world rect is restored so layout can
///      reposition it.
class MindmapSyncController {
  MindmapSyncController(this._canvas, InfiniteCanvasController view)
      : _view = view {
    _actions = MindmapActions.attach(_canvas);
    _canvas.addListener(_onCanvasChanged);
  }

  final CanvasController _canvas;
  // ignore: unused_field
  final InfiniteCanvasController _view;
  late final MindmapActions _actions;

  bool _applying = false;

  /// The last undo-stack length we saw. When it increases, a command was
  /// committed (e.g. select tool's `_recordMove`) → a drag just ended.
  int _lastHistoryLength = 0;

  /// The node currently being dragged (id), or null when idle.
  String? _dragNodeId;

  /// The node's world center before the drag started (to detect movement +
  /// restore on end).
  Offset _dragOrigin = Offset.zero;

  /// A candidate drag node: selected but not yet moved. We watch it and only
  /// start the drag session once its world rect actually changes.
  String? _dragCandidateId;
  Offset _dragCandidateOrigin = Offset.zero;

  void dispose() {
    _canvas.removeListener(_onCanvasChanged);
    MindmapActions.detach(_canvas);
  }

  void _onCanvasChanged() {
    if (_applying) return;

    final historyLen = _canvas.historyManager.undoStack.length;

    if (_dragNodeId != null) {
      // A drag is in progress — update preview, check for end.
      _handleDragMove();
      if (historyLen > _lastHistoryLength) {
        _handleDragEnd();
      }
    } else {
      _maybeTrackCandidate();
      _maybePromoteCandidate();
    }

    _lastHistoryLength = historyLen;
    _expandTreeSelections();
  }

  // ── Drag lifecycle ─────────────────────────────────────────────────

  /// Track a newly-selected non-root node as a drag candidate.
  void _maybeTrackCandidate() {
    final selected = _canvas.selectedIds;
    if (selected.length != 1) {
      _dragCandidateId = null;
      return;
    }
    final id = selected.first;
    // Don't replace a candidate if the same node stays selected.
    if (id == _dragCandidateId) return;
    final el = _canvas.elementById(id);
    if (el is! CanvasWidgetElement ||
        el.widgetType != kMindmapNodeWidgetType) {
      _dragCandidateId = null;
      return;
    }
    final data = MindmapNodeData.fromWidgetData(el.widgetData);
    if (data.isRoot) {
      _dragCandidateId = null;
      return;
    }
    _dragCandidateId = id;
    _dragCandidateOrigin = el.worldRect.center;
  }

  /// Promote the candidate to an active drag once its world rect moves.
  void _maybePromoteCandidate() {
    final id = _dragCandidateId;
    if (id == null) return;
    final el = _canvas.elementById(id);
    if (el is! CanvasWidgetElement) {
      _dragCandidateId = null;
      return;
    }
    final center = el.worldRect.center;
    if ((center - _dragCandidateOrigin).distance < 2) return;

    // Movement detected → start the drag session.
    final data = MindmapNodeData.fromWidgetData(el.widgetData);
    _dragNodeId = id;
    _dragOrigin = _dragCandidateOrigin;
    _dragCandidateId = null;
    _actions.dragSession.start(
      nodeId: id,
      worldOrigin: _dragOrigin,
      originalParentId: data.parentId,
      originalSide: data.side,
    );
    // Immediately compute the first preview.
    final target = _actions.computeDropTarget(id, center);
    final preview = _actions.computeDropPreview(id, target);
    _actions.dragSession.update(center, target, preview);
  }

  void _handleDragMove() {
    final id = _dragNodeId;
    if (id == null) return;
    final el = _canvas.elementById(id);
    if (el is! CanvasWidgetElement) return;

    // The select tool moves the node to follow the pointer. We use its
    // current center as the pointer's world position for target/preview.
    final pointerWorld = el.worldRect.center;
    final target = _actions.computeDropTarget(id, pointerWorld);
    final preview = _actions.computeDropPreview(id, target);
    _actions.dragSession.update(pointerWorld, target, preview);
  }

  void _handleDragEnd() {
    final id = _dragNodeId;
    _dragNodeId = null;
    if (id == null) return;

    final session = _actions.dragSession;
    final target = session.end();

    // Restore the node's world rect (select tool moved it) before reparenting
    // / reordering, so relayout starts from a clean state.
    final el = _canvas.elementById(id);
    if (el is CanvasWidgetElement) {
      _applying = true;
      _canvas.applyElementUpdated(
        id,
        el.copyWith(
          worldRect: Rect.fromCenter(
            center: _dragOrigin,
            width: el.worldRect.width,
            height: el.worldRect.height,
          ),
        ),
      );
      _applying = false;
    }

    _actions.reorderOrReparent(id, target);
  }

  // ── Selection expansion ────────────────────────────────────────────

  void _expandTreeSelections() {
    final selected = _canvas.selectedIds;
    if (selected.isEmpty) return;

    final trees = _actions.trees;
    final expanded = <String>{...selected};

    for (final tree in trees) {
      final rootId = tree.root.id;
      if (!selected.contains(rootId)) continue;
      for (final node in tree.visibleNodes) {
        expanded.add(node.id);
      }
    }

    if (expanded.length == selected.length) return;

    _applying = true;
    try {
      _canvas.setSelection(expanded);
    } finally {
      _applying = false;
    }
  }
}

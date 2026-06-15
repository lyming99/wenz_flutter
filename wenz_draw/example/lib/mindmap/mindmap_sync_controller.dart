import 'package:flutter/widgets.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_actions.dart';

/// Keeps mind map trees visually consistent:
///   1. Expands the selection to the whole tree when a root is selected.
///   2. While a node drag is active ([MindmapDragSession]), drives the dragged
///      node's world rect to follow the pointer (`session.worldPosition`) so
///      the user sees the node being dragged. The select tool's deferred
///      gesture (`moveSelected`) competes with this — we override its delta on
///      every canvas change by snapping the rect back to the pointer position.
///      When the drag ends, reorder/reparent/detach + relayout reposition
///      everything.
class MindmapSyncController {
  MindmapSyncController(this._canvas, InfiniteCanvasController view)
    : _view = view {
    _actions = MindmapActions.attach(_canvas);
    _canvas.addListener(_onCanvasChanged);
    _actions.dragSession.addListener(_onCanvasChanged);
  }

  final CanvasController _canvas;
  // ignore: unused_field
  final InfiniteCanvasController _view;
  late final MindmapActions _actions;

  bool _applying = false;

  void dispose() {
    _actions.dragSession.removeListener(_onCanvasChanged);
    _canvas.removeListener(_onCanvasChanged);
    MindmapActions.detach(_canvas);
  }

  void _onCanvasChanged() {
    if (_applying) return;
    _pinDraggedNode();
    _expandTreeSelections();
  }

  /// If a drag is active, snap the dragged node to follow the pointer
  /// (`session.worldPosition`).
  ///
  /// The select tool promotes deferred widget gestures and calls
  /// `moveSelected`, which shifts the node by a screen delta. We override that
  /// by setting the rect so its center matches the current pointer world
  /// position on every canvas change. The node visually trails the cursor; the
  /// connection layer additionally renders a drop shadow at the predicted
  /// landing rect.
  void _pinDraggedNode() {
    final session = _actions.dragSession;
    if (!session.isActive) return;
    final delta = session.worldPosition - session.origin;
    final movingIds = session.movingNodeIds;
    if (movingIds.isEmpty) return;

    _applying = true;
    try {
      for (final id in movingIds) {
        final origin = session.originOf(id);
        if (origin == null) continue;
        final el = _canvas.elementById(id);
        if (el is! CanvasWidgetElement) continue;

        final pinned = Rect.fromCenter(
          center: origin + delta,
          width: el.worldRect.width,
          height: el.worldRect.height,
        );
        if (el.worldRect != pinned) {
          _canvas.applyElementUpdated(id, el.copyWith(worldRect: pinned));
        }
      }
    } finally {
      _applying = false;
    }
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

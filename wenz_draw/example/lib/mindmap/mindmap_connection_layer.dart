import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_actions.dart';
import 'mindmap_connection_painter_v2.dart';
import 'mindmap_drag_session.dart';
import 'mindmap_layout_engine.dart';
import 'mindmap_node.dart';
import 'mindmap_node_data.dart';
import 'mindmap_node_metrics.dart';
import 'mindmap_theme.dart';
import 'mindmap_tree.dart';

/// Overlay that draws mind map connections + collapse buttons on top of the
/// canvas. Sits in the same [Stack] as [InfiniteCanvasWidget] and follows the
/// view transform (pan/zoom) so connections stay aligned with node elements.
///
/// Connections are recomputed from the rebuilt trees every rebuild — they are
/// NOT stored as elements. Merge-point collapse buttons are real widgets
/// (positioned at the merge point's screen coordinate) so they stay tappable.
class MindmapConnectionLayer extends StatefulWidget {
  const MindmapConnectionLayer({
    super.key,
    required this.canvasController,
    required this.viewController,
    this.rootId,
    this.connectionColor = const Color(0xFF94A3B8),
    this.strokeWidth = 2.5,
  });

  final CanvasController canvasController;
  final InfiniteCanvasController viewController;
  final String? rootId;

  final Color connectionColor;
  final double strokeWidth;

  @override
  State<MindmapConnectionLayer> createState() => _MindmapConnectionLayerState();
}

class _MindmapConnectionLayerState extends State<MindmapConnectionLayer> {
  MindmapThemeController? _themeController;

  @override
  void initState() {
    super.initState();
    widget.canvasController.addListener(_onChanged);
    widget.viewController.addListener(_onChanged);
    _dragSession?.addListener(_onChanged);
    _editingNodeId?.addListener(_onChanged);
    _bindThemeController();
  }

  MindmapDragSession? get _dragSession =>
      MindmapActions.of(widget.canvasController)?.dragSession;

  ValueNotifier<String?>? get _editingNodeId =>
      MindmapActions.of(widget.canvasController)?.editingNodeId;

  void _bindThemeController() {
    final next = MindmapActions.of(widget.canvasController)?.themeController;
    if (identical(next, _themeController)) return;
    _themeController?.removeListener(_onChanged);
    _themeController = next;
    _themeController?.addListener(_onChanged);
  }

  @override
  void dispose() {
    _editingNodeId?.removeListener(_onChanged);
    _dragSession?.removeListener(_onChanged);
    _themeController?.removeListener(_onChanged);
    widget.canvasController.removeListener(_onChanged);
    widget.viewController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final actions = MindmapActions.of(widget.canvasController);
    if (actions == null) return const SizedBox.shrink();
    _bindThemeController();

    final transform = widget.viewController.transform;
    final scale = transform.scale;
    final visibleRect = widget.viewController.visibleWorldRect();

    final trees = actions.trees
        .where((tree) => widget.rootId == null || tree.root.id == widget.rootId)
        .toList(growable: false);
    if (trees.isEmpty) return const SizedBox.shrink();

    // Connections use fixed world units — same as node elements — so they
    // scale uniformly with the canvas. No inverse-scale trickery here.
    final allMergePoints = <MindmapMergePoint>[];
    final connectionPainters = <Widget>[];
    for (final tree in trees) {
      final result = MindmapLayoutEngine.layout(tree);
      final visibleMergePoints = _visibleMergePoints(result, visibleRect);
      allMergePoints.addAll(visibleMergePoints);
      connectionPainters.add(
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: MindmapConnectionPainterV2(
                mergePoints: visibleMergePoints,
                viewportOffset: transform.offset,
                scale: scale,
                color: actions.themeForNode(tree.root.id).connectionColor,
                strokeWidth: widget.strokeWidth,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }

    // Convert world → screen for merge-point buttons positioned in screen space.
    Offset worldToScreen(Offset world) => world * scale + transform.offset;

    var content = Stack(children: connectionPainters).stackWithMergeButtons(
      mergePoints: allMergePoints,
      scale: scale,
      worldToScreen: worldToScreen,
      viewController: widget.viewController,
      onTap: (parentId, side) => actions.toggleCollapse(parentId, side),
    );

    if (_containsAnyNode(trees, actions.dragSession.movingNodeIds)) {
      content = content.stackWithDragPreview(
        dragSession: actions.dragSession,
        scale: scale,
        worldToScreen: worldToScreen,
        canvasController: widget.canvasController,
      );
    }

    if (widget.rootId == null &&
        _containsNode(trees, actions.editingNodeId.value)) {
      content = content.stackWithEditingOverlay(
        actions: actions,
        scale: scale,
        worldToScreen: worldToScreen,
        canvasController: widget.canvasController,
      );
    }

    return content;
  }

  List<MindmapMergePoint> _visibleMergePoints(
    MindmapLayoutResult result,
    Rect visibleRect,
  ) {
    final paddedVisibleRect = visibleRect.inflate(1);
    final points = <MindmapMergePoint>[];

    for (final mp in result.mergePoints) {
      final parentVisible = _nodeVisible(
        result.rects,
        mp.parentNodeId,
        paddedVisibleRect,
      );
      if (mp.isCollapsed) {
        if (parentVisible) points.add(mp);
        continue;
      }

      final childEdges = <Offset>[];
      final childNodeIds = <String>[];
      final count = math.min(mp.childEdges.length, mp.childNodeIds.length);
      for (var i = 0; i < count; i++) {
        final childNodeId = mp.childNodeIds[i];
        final childVisible = _nodeVisible(
          result.rects,
          childNodeId,
          paddedVisibleRect,
        );
        if (!parentVisible && !childVisible) {
          continue;
        }
        childEdges.add(mp.childEdges[i]);
        childNodeIds.add(childNodeId);
      }

      if (childEdges.isEmpty) {
        continue;
      }

      points.add(
        MindmapMergePoint(
          position: mp.position,
          parentNodeId: mp.parentNodeId,
          side: mp.side,
          isCollapsed: mp.isCollapsed,
          childCount: mp.childCount,
          parentEdge: mp.parentEdge,
          childEdges: childEdges,
          childNodeIds: childNodeIds,
        ),
      );
    }

    return points;
  }

  bool _nodeVisible(Map<String, Rect> rects, String nodeId, Rect visibleRect) {
    final rect = rects[nodeId];
    return rect != null && rect.overlaps(visibleRect);
  }

  bool _containsAnyNode(List<MindmapTree> trees, Iterable<String> nodeIds) {
    if (widget.rootId == null) return true;
    for (final nodeId in nodeIds) {
      if (_containsNode(trees, nodeId)) return true;
    }
    return false;
  }

  bool _containsNode(List<MindmapTree> trees, String? nodeId) {
    if (widget.rootId == null) return true;
    if (nodeId == null) return false;
    for (final tree in trees) {
      if (tree.allNodes.containsKey(nodeId)) return true;
    }
    return false;
  }
}

class MindmapEditingLayer extends StatefulWidget {
  const MindmapEditingLayer({
    super.key,
    required this.canvasController,
    required this.viewController,
  });

  final CanvasController canvasController;
  final InfiniteCanvasController viewController;

  @override
  State<MindmapEditingLayer> createState() => _MindmapEditingLayerState();
}

class _MindmapEditingLayerState extends State<MindmapEditingLayer> {
  MindmapThemeController? _themeController;

  MindmapActions? get _actions => MindmapActions.of(widget.canvasController);

  ValueNotifier<String?>? get _editingNodeId => _actions?.editingNodeId;

  @override
  void initState() {
    super.initState();
    widget.canvasController.addListener(_onChanged);
    widget.viewController.addListener(_onChanged);
    _editingNodeId?.addListener(_onChanged);
    _bindThemeController();
  }

  @override
  void dispose() {
    _editingNodeId?.removeListener(_onChanged);
    _themeController?.removeListener(_onChanged);
    widget.viewController.removeListener(_onChanged);
    widget.canvasController.removeListener(_onChanged);
    super.dispose();
  }

  void _bindThemeController() {
    final next = _actions?.themeController;
    if (identical(next, _themeController)) return;
    _themeController?.removeListener(_onChanged);
    _themeController = next;
    _themeController?.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions;
    if (actions == null) return const SizedBox.shrink();
    _bindThemeController();

    final transform = widget.viewController.transform;
    final scale = transform.scale;
    Offset worldToScreen(Offset world) => world * scale + transform.offset;

    return const SizedBox.shrink().stackWithEditingOverlay(
      actions: actions,
      scale: scale,
      worldToScreen: worldToScreen,
      canvasController: widget.canvasController,
    );
  }
}

/// A full-canvas listener that observes mind map node dragging.
///
/// It wraps the canvas stack instead of sitting above it, so normal canvas
/// hits still reach their original widgets. If pointer-down starts on a
/// mind map node under the select tool, the first significant move starts a
/// drag session and computes target/preview positions. Root nodes drag their
/// whole tree visually; dropping onto another mind map reparents the root,
/// while dropping on empty canvas records a plain tree translation.
class MindmapDragOverlay extends StatefulWidget {
  const MindmapDragOverlay({
    super.key,
    required this.canvasController,
    required this.viewController,
    required this.child,
  });

  final CanvasController canvasController;
  final InfiniteCanvasController viewController;
  final Widget child;

  @override
  State<MindmapDragOverlay> createState() => _MindmapDragOverlayState();
}

class _MindmapDragOverlayState extends State<MindmapDragOverlay> {
  static const double _startDragDistance = 4;

  MindmapActions? get _actions => MindmapActions.of(widget.canvasController);

  bool _isDragging = false;

  /// Pointer-down screen position (for delta → world conversion).
  Offset _downScreen = Offset.zero;

  /// Node world center at pointer-down.
  Offset _nodeWorldOrigin = Offset.zero;

  /// The node id we're dragging.
  String? _dragNodeId;
  List<String> _dragNodeIds = const [];
  List<String> _movingNodeIds = const [];
  Map<String, Offset> _nodeOrigins = const {};
  Map<String, Rect> _nodeOriginRects = const {};
  bool _draggingRoot = false;

  /// The pointer stream that owns the current drag candidate/session.
  int? _dragPointer;

  bool _isDraggableNode(CanvasElement? el) {
    if (el is! CanvasWidgetElement) return false;
    if (el.widgetType != kMindmapNodeWidgetType) return false;
    return true;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_dragPointer != null) return;
    if (event.buttons != kPrimaryButton) return;
    // Only engage under the select tool — otherwise let the canvas handle it.
    if (widget.canvasController.currentTool?.id != SelectTool.idValue) return;
    final actions = _actions;
    if (actions == null) return;
    if (actions.editingNodeId.value != null) return;

    final world = widget.viewController.screenToWorld(event.localPosition);
    final hit = widget.canvasController.hitTest(world);
    if (!_isDraggableNode(hit)) return;
    final hitElement = hit as CanvasWidgetElement;
    final hitData = MindmapNodeData.fromWidgetData(hitElement.widgetData);

    if (hitData.isRoot) {
      _startRootMoveCandidate(event, hitElement, actions);
      return;
    }

    final selected = widget.canvasController.selectedIds;
    final requestedIds = selected.contains(hitElement.id)
        ? selected
        : {hitElement.id};
    final structuralIds = actions.topLevelDragNodeIds(
      requestedIds,
      primaryId: hitElement.id,
    );
    if (structuralIds.isEmpty) return;

    final primaryId = structuralIds.contains(hitElement.id)
        ? hitElement.id
        : structuralIds.first;
    final movingIds = <String>[];
    final seenMovingIds = <String>{};
    for (final id in structuralIds) {
      for (final movingId in actions.subtreeIdsOf(id)) {
        if (seenMovingIds.add(movingId)) movingIds.add(movingId);
      }
    }
    final origins = <String, Offset>{};
    final originRects = <String, Rect>{};
    for (final id in movingIds) {
      final element = widget.canvasController.elementById(id);
      if (element is CanvasWidgetElement) {
        origins[id] = element.bounds.center;
        originRects[id] = element.worldRect;
      }
    }
    final primary = widget.canvasController.elementById(primaryId);
    if (primary is! CanvasWidgetElement) return;

    _dragNodeId = primaryId;
    _dragNodeIds = structuralIds;
    _movingNodeIds = movingIds;
    _nodeOrigins = origins;
    _nodeOriginRects = originRects;
    _draggingRoot = false;
    _dragPointer = event.pointer;
    _downScreen = event.position;
    _nodeWorldOrigin = primary.bounds.center;
  }

  void _startRootMoveCandidate(
    PointerDownEvent event,
    CanvasWidgetElement root,
    MindmapActions actions,
  ) {
    final movingIds = actions.subtreeIdsOf(root.id).toList(growable: false);
    final origins = <String, Offset>{};
    final originRects = <String, Rect>{};
    for (final id in movingIds) {
      final element = widget.canvasController.elementById(id);
      if (element is CanvasWidgetElement) {
        origins[id] = element.worldRect.center;
        originRects[id] = element.worldRect;
      }
    }
    if (origins.isEmpty) return;

    widget.canvasController.setSelection({root.id});
    _dragNodeId = root.id;
    _dragNodeIds = [root.id];
    _movingNodeIds = movingIds;
    _nodeOrigins = origins;
    _nodeOriginRects = originRects;
    _draggingRoot = true;
    _dragPointer = event.pointer;
    _downScreen = event.position;
    _nodeWorldOrigin = root.worldRect.center;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _dragPointer) return;
    final nodeId = _dragNodeId;
    final actions = _actions;
    if (nodeId == null || actions == null) return;

    final scale = widget.viewController.transform.scale;
    final worldPos = _nodeWorldOrigin + (event.position - _downScreen) / scale;

    // Start the drag session on first significant movement, then cancel the
    // select tool's normal move interaction so the session owns the drag.
    if (!actions.dragSession.isActive) {
      if ((event.position - _downScreen).distance < _startDragDistance) {
        return;
      }
      final el = widget.canvasController.elementById(nodeId);
      if (el is! CanvasWidgetElement) return;
      final data = MindmapNodeData.fromWidgetData(el.widgetData);
      actions.dragSession.start(
        nodeId: nodeId,
        worldOrigin: _nodeWorldOrigin,
        originalParentId: data.parentId,
        originalSide: data.side,
        nodeIds: _dragNodeIds,
        movingNodeIds: _movingNodeIds,
        origins: _nodeOrigins,
      );
      widget.canvasController.cancelCurrentInteraction();
      setState(() => _isDragging = true);
    }
    actions.dragSession.updateWorld(worldPos);

    final excludedIds = actions.dragSession.movingNodeIds.toSet();
    final target = actions.computeDropTarget(
      nodeId,
      worldPos,
      excludedNodeIds: excludedIds,
    );
    if (_draggingRoot && target?.kind == MindmapDropTargetKind.detached) {
      actions.dragSession.updateTarget(null, null);
      return;
    }

    final preview = actions.computeDropPreview(
      nodeId,
      target,
      excludedNodeIds: excludedIds,
    );
    actions.dragSession.updateTarget(target, preview);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _dragPointer) return;
    _commit();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _dragPointer) return;
    if (_draggingRoot) {
      _restoreRootMove();
    }
    _actions?.dragSession.cancel();
    _reset();
  }

  void _commit() {
    final nodeId = _dragNodeId;
    final actions = _actions;
    if (nodeId == null || actions == null || !actions.dragSession.isActive) {
      _reset();
      return;
    }
    final dropPosition = actions.dragSession.worldPosition;
    final draggedNodeIds = actions.dragSession.draggedNodeIds;
    final target = actions.dragSession.end();
    if (_draggingRoot && target == null) {
      _recordRootMove(nodeId);
      _reset();
      return;
    }
    actions.reorderOrReparentMany(
      draggedNodeIds,
      target,
      dropPosition: dropPosition,
    );
    _reset();
  }

  void _recordRootMove(String rootId) {
    final commands = <CanvasCommand>[];
    for (final id in _movingNodeIds) {
      final originalRect = _nodeOriginRects[id];
      final element = widget.canvasController.elementById(id);
      if (originalRect == null || element is! CanvasWidgetElement) continue;
      if (element.worldRect == originalRect) continue;

      commands.add(
        UpdateElementCommand(
          before: element.copyWith(worldRect: originalRect),
          after: element,
          description: 'Move mind map tree',
        ),
      );
    }

    if (commands.isNotEmpty) {
      widget.canvasController.historyManager.execute(
        BatchCommand(commands: commands, description: 'Move mind map tree'),
        widget.canvasController,
      );
    }
    widget.canvasController.setSelection({rootId});
  }

  void _restoreRootMove() {
    for (final entry in _nodeOriginRects.entries) {
      final element = widget.canvasController.elementById(entry.key);
      if (element is! CanvasWidgetElement) continue;
      if (element.worldRect == entry.value) continue;
      widget.canvasController.applyElementUpdated(
        entry.key,
        element.copyWith(worldRect: entry.value),
      );
    }
  }

  void _reset() {
    _dragNodeId = null;
    _dragNodeIds = const [];
    _movingNodeIds = const [];
    _nodeOrigins = const {};
    _nodeOriginRects = const {};
    _draggingRoot = false;
    _dragPointer = null;
    if (_isDragging) setState(() => _isDragging = false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}

extension on Widget {
  /// Place connection paint behind, then overlay each merge-point button.
  Widget stackWithMergeButtons({
    required List<MindmapMergePoint> mergePoints,
    required double scale,
    required Offset Function(Offset) worldToScreen,
    required InfiniteCanvasController viewController,
    required void Function(String parentId, MindmapNodeSide side) onTap,
  }) {
    return Stack(
      children: [
        this,
        for (final mp in mergePoints)
          _MergeButtonOverlay(
            position: worldToScreen(mp.position),
            isCollapsed: mp.isCollapsed,
            childCount: mp.childCount,
            scale: scale,
            viewController: viewController,
            onTap: () => onTap(mp.parentNodeId, mp.side),
          ),
      ],
    );
  }
}

/// A single merge-point collapse/expand button positioned in screen space.
///
/// All dimensions scale with [scale] so the button grows/shrinks with the
/// canvas zoom — matching the node elements which use fixed world units.
class _MergeButtonOverlay extends StatelessWidget {
  const _MergeButtonOverlay({
    required this.position,
    required this.isCollapsed,
    required this.childCount,
    required this.scale,
    required this.viewController,
    required this.onTap,
  });

  /// Screen-space center of the button.
  final Offset position;
  final bool isCollapsed;
  final int childCount;
  final double scale;
  final InfiniteCanvasController viewController;
  final VoidCallback onTap;

  // Base (scale = 1) dimensions in screen pixels.
  static const _baseSize = 24.0;
  static const _baseIconSize = 16.0;
  static const _baseFontSize = 11.0;
  static const _baseBorderWidth = 2.0;
  static const _baseShadowBlur = 4.0;
  static const _scrollZoomSensitivity = 0.0015;

  void _handlePointerSignal(PointerSignalEvent event, double size) {
    if (event is! PointerScrollEvent) return;
    final factor = math.exp(-event.scrollDelta.dy * _scrollZoomSensitivity);
    final focalPoint =
        Offset(position.dx - size / 2, position.dy - size / 2) +
        event.localPosition;
    viewController.zoomBy(factor, focalPoint: focalPoint);
  }

  @override
  Widget build(BuildContext context) {
    final size = _baseSize * scale;
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: Listener(
        onPointerSignal: (event) => _handlePointerSignal(event, size),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isCollapsed ? const Color(0xFF2563EB) : Colors.white,
              borderRadius: BorderRadius.circular(size / 2),
              border: Border.all(
                color: isCollapsed
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF94A3B8),
                width: _baseBorderWidth * scale,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: _baseShadowBlur * scale,
                  offset: Offset(0, scale),
                ),
              ],
            ),
            child: Center(
              child: isCollapsed
                  ? Text(
                      '$childCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _baseFontSize * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Icon(
                      Icons.expand_more,
                      size: _baseIconSize * scale,
                      color: const Color(0xFF94A3B8),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

extension _EditingOverlayExtension on Widget {
  Widget stackWithEditingOverlay({
    required MindmapActions actions,
    required double scale,
    required Offset Function(Offset) worldToScreen,
    required CanvasController canvasController,
  }) {
    final nodeId = actions.editingNodeId.value;
    if (nodeId == null) return this;

    final element = canvasController.elementById(nodeId);
    if (element is! CanvasWidgetElement || !element.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (actions.editingNodeId.value == nodeId) {
          actions.endEditing(nodeId);
        }
      });
      return this;
    }

    final data = MindmapNodeData.fromWidgetData(element.widgetData);
    final style = actions.styleForNode(nodeId);
    return Stack(
      children: [
        this,
        Positioned.fill(
          child: _MindmapEditingOverlay(
            key: ValueKey('mindmap-edit-$nodeId'),
            actions: actions,
            nodeId: nodeId,
            data: data,
            style: style,
            center: worldToScreen(element.worldRect.center),
            scale: scale,
          ),
        ),
      ],
    );
  }
}

class _MindmapEditingOverlay extends StatefulWidget {
  const _MindmapEditingOverlay({
    super.key,
    required this.actions,
    required this.nodeId,
    required this.data,
    required this.style,
    required this.center,
    required this.scale,
  });

  final MindmapActions actions;
  final String nodeId;
  final MindmapNodeData data;
  final MindmapResolvedNodeStyle style;
  final Offset center;
  final double scale;

  @override
  State<_MindmapEditingOverlay> createState() => _MindmapEditingOverlayState();
}

class _MindmapEditingOverlayState extends State<_MindmapEditingOverlay> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.data.text);
    _focusNode = FocusNode(debugLabel: 'MindmapEditor:${widget.nodeId}');
    _selectAllText();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant _MindmapEditingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodeId != widget.nodeId ||
        oldWidget.data.text != widget.data.text) {
      _controller.text = widget.data.text;
      _selectAllText();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _selectAllText() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  void _commit() {
    if (_finished) return;
    _finished = true;
    widget.actions.commitText(widget.nodeId, _controller.text);
    widget.actions.endEditing(widget.nodeId);
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    widget.actions.endEditing(widget.nodeId);
  }

  void _commitAndAddChild() {
    if (_finished) return;
    _finished = true;
    widget.actions.commitAndAddChild(widget.nodeId, _controller.text);
    widget.actions.endEditing(widget.nodeId);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _commit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _commitAndAddChild();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  double _lineHeightForNode({
    required double fontSize,
    required double contentHeight,
  }) {
    if (fontSize <= 0 || contentHeight <= 0) {
      return 1.0;
    }
    return contentHeight / fontSize;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _commit,
          child: const SizedBox.expand(),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final isRoot = widget.data.isRoot;
            final scale = widget.scale.isFinite && widget.scale > 0
                ? widget.scale
                : 1.0;
            // This overlay is outside the canvas transform, so every visible
            // metric is converted from world units to screen units here.
            final worldWidth = MindmapNodeMetrics.widthForText(
              _controller.text,
              isRoot: isRoot,
            );
            final worldHeight = isRoot
                ? MindmapNodeMetrics.rootHeight
                : MindmapNodeMetrics.nodeHeight;
            final screenWidth = worldWidth * scale;
            final screenHeight = worldHeight * scale;
            final layoutScale = scale < 1 ? 1.0 : scale;
            final paintScale = scale < 1 ? scale : 1.0;
            final layoutWidth = worldWidth * layoutScale;
            final layoutHeight = worldHeight * layoutScale;
            final scaledPadding = widget.style.padding * layoutScale;
            final contentWidth = math.max(
              0.0,
              layoutWidth - scaledPadding.horizontal,
            );
            final contentHeight = math.max(
              0.0,
              layoutHeight - scaledPadding.vertical,
            );
            final baseFontSize =
                widget.style.textStyle.fontSize ?? (isRoot ? 16 : 14);
            final fontSize = baseFontSize * layoutScale;
            final lineHeight = _lineHeightForNode(
              fontSize: fontSize,
              contentHeight: contentHeight,
            );
            final textDirection = Directionality.of(context);
            final textScaler = MediaQuery.textScalerOf(context);
            final editStyle = widget.style.textStyle.copyWith(
              fontSize: fontSize,
              height: lineHeight,
            );
            final measuredText = _controller.text.isEmpty
                ? ' '
                : _controller.text;
            final textPainter = TextPainter(
              text: TextSpan(text: measuredText, style: editStyle),
              textAlign: TextAlign.center,
              maxLines: 1,
              textDirection: textDirection,
              textScaler: textScaler,
            )..layout(maxWidth: contentWidth);
            final lineMetrics = textPainter.computeLineMetrics();
            final measuredTextHeight = lineMetrics.isEmpty
                ? textPainter.size.height
                : lineMetrics.first.height;
            Rect? glyphBounds;
            final glyphBoxes = textPainter.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: measuredText.length),
            );
            for (final box in glyphBoxes) {
              final rect = box.toRect();
              if (rect.isEmpty) continue;
              glyphBounds = glyphBounds == null
                  ? rect
                  : glyphBounds.expandToInclude(rect);
            }
            final glyphCenterY =
                glyphBounds?.center.dy ?? measuredTextHeight / 2;
            final inputHeight = measuredTextHeight;
            final textTopOffset = contentHeight / 2 - glyphCenterY;
            final editor = SizedBox(
              width: layoutWidth,
              height: layoutHeight,
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.style.fillColor,
                    borderRadius: BorderRadius.circular(
                      widget.style.borderRadius * layoutScale,
                    ),
                    border: Border.all(
                      color: const Color(0xFF2563EB),
                      width: 2 * layoutScale,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8 * layoutScale,
                        offset: Offset(0, 2 * layoutScale),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: scaledPadding,
                    child: SizedBox(
                      width: contentWidth,
                      height: contentHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: textTopOffset,
                            height: inputHeight,
                            child: Focus(
                              onKeyEvent: _handleKeyEvent,
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                textAlignVertical: TextAlignVertical.center,
                                cursorColor: widget.style.textColor,
                                cursorHeight: inputHeight,
                                style: editStyle,
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.done,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  isCollapsed: true,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  hintText: '',
                                ),
                                onSubmitted: (_) => _commit(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );

            return Positioned(
              left: widget.center.dx - screenWidth / 2,
              top: widget.center.dy - screenHeight / 2,
              width: screenWidth,
              height: screenHeight,
              child: paintScale == 1
                  ? editor
                  : OverflowBox(
                      alignment: Alignment.center,
                      minWidth: layoutWidth,
                      maxWidth: layoutWidth,
                      minHeight: layoutHeight,
                      maxHeight: layoutHeight,
                      child: Transform.scale(
                        scale: paintScale,
                        alignment: Alignment.center,
                        child: editor,
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }
}

extension _DragPreviewExtension on Widget {
  /// Overlay the drop shadow + preview connection line when a drag is active.
  ///
  /// The dragged node itself follows the pointer, the origin ghost marks where
  /// it came from, and the dashed preview shows the predicted landing slot.
  Widget stackWithDragPreview({
    required MindmapDragSession dragSession,
    required double scale,
    required Offset Function(Offset) worldToScreen,
    required CanvasController canvasController,
  }) {
    if (!dragSession.isActive) return this;

    return Stack(
      children: [
        this,
        for (final id in dragSession.movingNodeIds)
          _OriginGhost(
            rect: _originGhostRect(
              id,
              dragSession,
              scale,
              worldToScreen,
              canvasController,
            ),
            element: canvasController.elementById(id),
            actions: MindmapActions.of(canvasController),
          ),
        // Preview connection line (parent edge → predicted node edge).
        // Null for detach drops (node becomes an independent root, no parent).
        if (dragSession.preview?.connection != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PreviewLinePainter(
                  from: worldToScreen(dragSession.preview!.connection!.from),
                  to: worldToScreen(dragSession.preview!.connection!.to),
                ),
              ),
            ),
          ),
        // Drop shadow at the predicted landing rect.
        if (dragSession.preview != null)
          _DropShadow(
            rect:
                worldToScreen(dragSession.preview!.rect.topLeft) &
                (dragSession.preview!.rect.size * scale),
          ),
      ],
    );
  }

  Rect? _originGhostRect(
    String id,
    MindmapDragSession dragSession,
    double scale,
    Offset Function(Offset) worldToScreen,
    CanvasController canvasController,
  ) {
    final element = canvasController.elementById(id);
    if (element is! CanvasWidgetElement) return null;
    if (!element.visible) return null;
    final origin = dragSession.originOf(id);
    if (origin == null) return null;
    final worldRect = Rect.fromCenter(
      center: origin,
      width: element.worldRect.width,
      height: element.worldRect.height,
    );
    return worldToScreen(worldRect.topLeft) & (worldRect.size * scale);
  }
}

class _OriginGhost extends StatelessWidget {
  const _OriginGhost({
    required this.rect,
    required this.element,
    required this.actions,
  });

  final Rect? rect;
  final CanvasElement? element;
  final MindmapActions? actions;

  @override
  Widget build(BuildContext context) {
    final rect = this.rect;
    final element = this.element;
    if (rect == null || element is! CanvasWidgetElement) {
      return const SizedBox.shrink();
    }
    final data = MindmapNodeData.fromWidgetData(element.widgetData);
    final style =
        actions?.styleForNode(element.id) ??
        MindmapThemeController().styleFor(
          MindmapThemeNodeContext.fromNodeData(
            data,
            depth: data.isRoot ? 0 : 1,
            siblingIndex: data.order,
            siblingCount: 1,
          ),
        );
    final text = data.text;
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.4,
          child: MindmapNodeFrame(
            style: style,
            child: Center(
              child: Padding(
                padding: style.padding,
                child: Text(
                  text.isEmpty ? '...' : text,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: style.textStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed-outline shadow block shown at the predicted landing position.
class _DropShadow extends StatelessWidget {
  const _DropShadow({required this.rect});

  final Rect rect;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _DashedBoxPainter(
            color: const Color(0xFF34C759),
            fillColor: const Color(0xFF34C759).withValues(alpha: 0.12),
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed rectangle (the drop shadow block).
class _DashedBoxPainter extends CustomPainter {
  const _DashedBoxPainter({required this.color, required this.fillColor});

  final Color color;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = fillColor;
    canvas.drawRect(Offset.zero & size, fillPaint);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    // Top + bottom
    for (double x = 0; x < size.width; x += dashWidth + dashSpace) {
      final w = (size.width - x).clamp(0.0, dashWidth);
      canvas.drawLine(Offset(x, 0), Offset(x + w, 0), paint);
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + w, size.height),
        paint,
      );
    }
    // Left + right
    for (double y = 0; y < size.height; y += dashWidth + dashSpace) {
      final h = (size.height - y).clamp(0.0, dashWidth);
      canvas.drawLine(Offset(0, y), Offset(0, y + h), paint);
      canvas.drawLine(Offset(size.width, y), Offset(size.width, y + h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBoxPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fillColor != fillColor;
}

/// Paints a dashed bezier preview connection line between two screen points.
class _PreviewLinePainter extends CustomPainter {
  const _PreviewLinePainter({required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    // from/to are already in screen coordinates, so the control-point offset
    // is computed directly in screen units (no extra scale factor).
    final dx = to.dx - from.dx;
    final absDx = dx.abs();
    final cpOffset = (absDx * 0.5).clamp(10.0, 80.0);
    final dir = dx >= 0 ? 1.0 : -1.0;
    final cp1 = Offset(from.dx + dir * cpOffset, from.dy);
    final cp2 = Offset(to.dx - dir * cpOffset, to.dy);

    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, to.dx, to.dy);

    // Draw dashed.
    final paint = Paint()
      ..color = const Color(0xFF34C759)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLength = 8.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = (metric.length - distance).clamp(0.0, dashLength);
        final sub = metric.extractPath(distance, distance + len);
        canvas.drawPath(sub, paint);
        distance += dashLength + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewLinePainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to;
}

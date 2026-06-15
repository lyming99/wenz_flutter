import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_actions.dart';
import 'mindmap_connection_painter_v2.dart';
import 'mindmap_drag_session.dart';
import 'mindmap_layout_engine.dart';
import 'mindmap_node.dart';
import 'mindmap_node_data.dart';
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
    this.connectionColor = const Color(0xFF94A3B8),
    this.strokeWidth = 2.5,
  });

  final CanvasController canvasController;
  final InfiniteCanvasController viewController;

  final Color connectionColor;
  final double strokeWidth;

  @override
  State<MindmapConnectionLayer> createState() => _MindmapConnectionLayerState();
}

class _MindmapConnectionLayerState extends State<MindmapConnectionLayer> {
  @override
  void initState() {
    super.initState();
    widget.canvasController.addListener(_onChanged);
    widget.viewController.addListener(_onChanged);
    _dragSession?.addListener(_onChanged);
  }

  MindmapDragSession? get _dragSession =>
      MindmapActions.of(widget.canvasController)?.dragSession;

  @override
  void dispose() {
    _dragSession?.removeListener(_onChanged);
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

    final transform = widget.viewController.transform;
    final scale = transform.scale;

    final trees = actions.trees;
    if (trees.isEmpty) return const SizedBox.shrink();

    // Connections use fixed world units — same as node elements — so they
    // scale uniformly with the canvas. No inverse-scale trickery here.
    final allMergePoints = <MindmapMergePoint>[];
    for (final tree in trees) {
      final result = MindmapLayoutEngine.layout(tree);
      allMergePoints.addAll(result.mergePoints);
    }

    // Convert world → screen for merge-point buttons positioned in screen space.
    Offset worldToScreen(Offset world) => world * scale + transform.offset;

    return IgnorePointer(
          child: CustomPaint(
            painter: MindmapConnectionPainterV2(
              mergePoints: allMergePoints,
              viewportOffset: transform.offset,
              scale: scale,
              color: widget.connectionColor,
              strokeWidth: widget.strokeWidth,
            ),
            child: const SizedBox.expand(),
          ),
        )
        .stackWithMergeButtons(
          mergePoints: allMergePoints,
          scale: scale,
          worldToScreen: worldToScreen,
          onTap: (parentId, side) => actions.toggleCollapse(parentId, side),
        )
        .stackWithDragPreview(
          dragSession: actions.dragSession,
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
/// non-root mind map node under the select tool, the first significant move
/// starts a drag session and computes target/preview positions.
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

    final world = widget.viewController.screenToWorld(event.localPosition);
    final hit = widget.canvasController.hitTest(world);
    if (!_isDraggableNode(hit)) return;

    final actions = _actions;
    if (actions == null) return;

    final selected = widget.canvasController.selectedIds;
    final requestedIds = selected.contains(hit!.id) ? selected : {hit.id};
    final structuralIds = actions.topLevelDragNodeIds(
      requestedIds,
      primaryId: hit.id,
    );
    if (structuralIds.isEmpty) return;

    final primaryId = structuralIds.contains(hit.id)
        ? hit.id
        : structuralIds.first;
    final movingIds = <String>[];
    final seenMovingIds = <String>{};
    for (final id in structuralIds) {
      for (final movingId in actions.subtreeIdsOf(id)) {
        if (seenMovingIds.add(movingId)) movingIds.add(movingId);
      }
    }
    final origins = <String, Offset>{};
    for (final id in movingIds) {
      final element = widget.canvasController.elementById(id);
      if (element is CanvasWidgetElement) {
        origins[id] = element.bounds.center;
      }
    }
    final primary = widget.canvasController.elementById(primaryId);
    if (primary is! CanvasWidgetElement) return;

    _dragNodeId = primaryId;
    _dragNodeIds = structuralIds;
    _movingNodeIds = movingIds;
    _nodeOrigins = origins;
    _dragPointer = event.pointer;
    _downScreen = event.position;
    _nodeWorldOrigin = primary.bounds.center;
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
    actions.reorderOrReparentMany(
      draggedNodeIds,
      target,
      dropPosition: dropPosition,
    );
    _reset();
  }

  void _reset() {
    _dragNodeId = null;
    _dragNodeIds = const [];
    _movingNodeIds = const [];
    _nodeOrigins = const {};
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
    required this.onTap,
  });

  /// Screen-space center of the button.
  final Offset position;
  final bool isCollapsed;
  final int childCount;
  final double scale;
  final VoidCallback onTap;

  // Base (scale = 1) dimensions in screen pixels.
  static const _baseSize = 24.0;
  static const _baseIconSize = 16.0;
  static const _baseFontSize = 11.0;
  static const _baseBorderWidth = 2.0;
  static const _baseShadowBlur = 4.0;

  @override
  Widget build(BuildContext context) {
    final size = _baseSize * scale;
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
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
  const _OriginGhost({required this.rect, required this.element});

  final Rect? rect;
  final CanvasElement? element;

  @override
  Widget build(BuildContext context) {
    final rect = this.rect;
    final element = this.element;
    if (rect == null || element is! CanvasWidgetElement) {
      return const SizedBox.shrink();
    }
    final color = Color(_parseIntColor(element.widgetData['color']));
    final textColor = Color(
      _parseIntColor(element.widgetData['textColor'], 0xFF1F2937),
    );
    final text = element.widgetData['text'] as String? ?? '';
    final isRoot = element.widgetData['isRoot'] == true;

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(isRoot ? 24 : 8),
              border: Border.all(color: const Color(0xFF94A3B8), width: 1),
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isRoot ? 16 : 12,
                  vertical: isRoot ? 10 : 6,
                ),
                child: Text(
                  text.isEmpty ? '...' : text,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: isRoot ? 16 : 14,
                    fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static int _parseIntColor(dynamic value, [int fallback = 0xFFE3F2FD]) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
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

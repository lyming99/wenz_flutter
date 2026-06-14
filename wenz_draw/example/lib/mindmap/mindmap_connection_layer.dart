import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_actions.dart';
import 'mindmap_connection_painter_v2.dart';
import 'mindmap_drag_session.dart';
import 'mindmap_layout_engine.dart';
import 'mindmap_node.dart';

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
    Offset worldToScreen(Offset world) =>
        world * scale + transform.offset;

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
    ).stackWithMergeButtons(
      mergePoints: allMergePoints,
      scale: scale,
      worldToScreen: worldToScreen,
      onTap: (parentId, side) => actions.toggleCollapse(parentId, side),
    ).stackWithDragPreview(
      dragSession: actions.dragSession,
      scale: scale,
      worldToScreen: worldToScreen,
      canvasController: widget.canvasController,
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
            onTap: () => onTap(mp.parentNodeId, mp.side),
          ),
      ],
    );
  }
}

/// A single merge-point collapse/expand button positioned in screen space.
class _MergeButtonOverlay extends StatelessWidget {
  const _MergeButtonOverlay({
    required this.position,
    required this.isCollapsed,
    required this.childCount,
    required this.onTap,
  });

  /// Screen-space center of the button.
  final Offset position;
  final bool isCollapsed;
  final int childCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - 12,
      top: position.dy - 12,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCollapsed ? const Color(0xFF2563EB) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCollapsed
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF94A3B8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: isCollapsed
                ? Text(
                    '$childCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : const Icon(
                    Icons.expand_more,
                    size: 16,
                    color: Color(0xFF94A3B8),
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
  /// The dragged node itself (at 0.4 opacity) follows the pointer because the
  /// select tool moves it — no separate ghost is needed here.
  Widget stackWithDragPreview({
    required MindmapDragSession dragSession,
    required double scale,
    required Offset Function(Offset) worldToScreen,
    required CanvasController canvasController,
  }) {
    if (!dragSession.isActive) return this;

    // The dragged node's original rect (world) — used to render a ghost at
    // the home position so the user sees where the node came from.
    final draggedEl = dragSession.draggedNodeId != null
        ? canvasController.elementById(dragSession.draggedNodeId!)
        : null;
    final originRect = draggedEl is CanvasWidgetElement
        ? Rect.fromCenter(
            center: dragSession.origin,
            width: draggedEl.worldRect.width,
            height: draggedEl.worldRect.height,
          )
        : null;
    final originText = draggedEl is CanvasWidgetElement
        ? (draggedEl.widgetData['text'] as String? ?? '')
        : '';
    final originColor = draggedEl is CanvasWidgetElement
        ? Color(_parseIntColor(draggedEl.widgetData['color']))
        : const Color(0xFFE3F2FD);

    return Stack(
      children: [
        this,
        // Ghost at the original position (0.4 opacity).
        if (originRect != null)
          _OriginGhost(
            rect: worldToScreen(originRect.topLeft) &
                (originRect.size * scale),
            text: originText.isEmpty ? '...' : originText,
            color: originColor,
          ),
        // Preview connection line (parent edge → predicted node edge).
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
            rect: worldToScreen(dragSession.preview!.rect.topLeft) &
                (dragSession.preview!.rect.size * scale),
          ),
      ],
    );
  }

  static int _parseIntColor(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0xFFE3F2FD;
    return 0xFFE3F2FD;
  }
}

/// A semi-transparent ghost of the dragged node rendered at its original
/// (home) position, so the user can see where the node came from.
class _OriginGhost extends StatelessWidget {
  const _OriginGhost({
    required this.rect,
    required this.text,
    required this.color,
  });

  final Rect rect;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF94A3B8), width: 1),
            ),
            child: Center(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
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
          Offset(x, size.height), Offset(x + w, size.height), paint);
    }
    // Left + right
    for (double y = 0; y < size.height; y += dashWidth + dashSpace) {
      final h = (size.height - y).clamp(0.0, dashWidth);
      canvas.drawLine(Offset(0, y), Offset(0, y + h), paint);
      canvas.drawLine(
          Offset(size.width, y), Offset(size.width, y + h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBoxPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fillColor != fillColor;
}

/// Paints a dashed bezier preview connection line between two screen points.
class _PreviewLinePainter extends CustomPainter {
  const _PreviewLinePainter({
    required this.from,
    required this.to,
  });

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

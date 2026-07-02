import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'flowchart_model.dart';

/// Fixed canvas height for the embed. The flowchart is a content-sized block,
/// so the renderer paints into a bounded box instead of asking the editor for a
/// flexible height.
const double kFlowchartCanvasHeight = 300;

const double _kHeaderHeight = 28;

/// Builds the `flowchart` [BlockRendererBuilder].
///
/// The builder is returned from a closure so the two integration paths share
/// it: the config-injection path (host `blockEmbedRenderers`) and the plugin
/// path (`FlowchartPlugin.install`) both supply an [onWriteBack] that routes
/// the edited data back to the controller via `updateBlockEmbed`, keeping
/// history, callbacks, and the permission gate intact.
BlockRendererBuilder flowchartRendererBuilder({
  required void Function(String blockId, Map<String, Object?> data) onWriteBack,
}) {
  return (BuildContext context, BlockRenderContext renderContext) {
    final block = renderContext.block as BlockEmbedNode;
    return WenzObjectBlockSurface(
      renderContext: renderContext,
      child: FlowchartView(
        block: block,
        canEdit: renderContext.canEdit,
        onChanged: (Map<String, Object?> data) => onWriteBack(block.id, data),
      ),
    );
  };
}

/// Slash-menu item (`/流程图`) that inserts a sample flowchart in place of the
/// trigger text. The slash controller deletes the `/流程图` token before the
/// action runs, so the embed lands at [SlashMenuContext.blockIndex].
SlashMenuItem flowchartSlashMenuItem() {
  return SlashMenuItem(
    id: kFlowchartEmbedType,
    title: '流程图',
    description: '插入可拖拽编辑的流程图',
    icon: 'account_tree',
    keywords: const <String>['flowchart', '流程', '流程图', '图'],
    action: (editor, context) {
      editor.insertBlockEmbed(
        index: context.blockIndex,
        blockId: context.generatedId(kFlowchartEmbedType),
        embedType: kFlowchartEmbedType,
        data: FlowchartDocument.sample().toJson(),
        fallbackText: kFlowchartFallbackText,
      );
    },
  );
}

/// Toolbar item descriptor for the flowchart. Hosts render the descriptor
/// registry in their own toolbar widget; the example app also renders a
/// matching button directly so the entry is visible without one.
WenzToolbarItem flowchartToolbarItem() {
  return WenzToolbarItem(
    id: kFlowchartEmbedType,
    title: '流程图',
    tooltip: '插入流程图',
    icon: 'account_tree',
    action: (editor, state) {
      editor.insertBlockEmbed(
        index: editor.document.blocks.length,
        blockId: '$kFlowchartEmbedType-${editor.document.blocks.length}',
        embedType: kFlowchartEmbedType,
        data: FlowchartDocument.sample().toJson(),
        fallbackText: kFlowchartFallbackText,
      );
    },
  );
}

/// Renders a flowchart [BlockEmbedNode] as a draggable node graph.
///
/// The view is read from [block.data] and, when [canEdit] is true, lets the
/// user drag nodes to new coordinates. Dragging is confined to node hit-tests
/// (the empty canvas stays tappable so the surrounding [WenzObjectBlockSurface]
/// keeps handling block selection) and the new layout is written back through
/// [onChanged] when a drag ends.
class FlowchartView extends StatefulWidget {
  const FlowchartView({
    super.key,
    required this.block,
    required this.canEdit,
    required this.onChanged,
  });

  final BlockEmbedNode block;
  final bool canEdit;

  /// Invoked with the full updated `data` map when a drag completes. The host
  /// forwards it to `WenzRichTextController.updateBlockEmbed`.
  final ValueChanged<Map<String, Object?>> onChanged;

  @override
  State<FlowchartView> createState() => _FlowchartViewState();
}

class _FlowchartViewState extends State<FlowchartView> {
  FlowchartDocument _document = FlowchartDocument.empty;
  String? _draggingId;
  double _canvasWidth = 0;

  @override
  void initState() {
    super.initState();
    _document = flowchartDocumentFromBlock(widget.block);
  }

  @override
  void didUpdateWidget(covariant FlowchartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync from the model when the embed data changed externally (undo/redo,
    // the drag write-back round-trip, or collaboration). Equal content compares
    // equal, so a self-triggered round-trip never causes feedback jitter.
    final incoming = flowchartDocumentFromBlock(widget.block);
    if (!_documentsEqual(_document, incoming)) {
      _document = incoming;
    }
  }

  bool _documentsEqual(FlowchartDocument a, FlowchartDocument b) {
    return a.direction == b.direction &&
        a.version == b.version &&
        listEquals(a.nodes, b.nodes) &&
        listEquals(a.edges, b.edges);
  }

  void _applyDrag(String nodeId, Offset delta, Size size) {
    final maxX = math.max(0.0, _canvasWidth - size.width);
    final maxY = math.max(0.0, kFlowchartCanvasHeight - size.height);
    setState(() {
      _document = _document.copyWith(
        nodes: _document.nodes
            .map((node) => node.id == nodeId
                ? node.copyWith(
                    x: (node.x + delta.dx).clamp(0.0, maxX),
                    y: (node.y + delta.dy).clamp(0.0, maxY),
                  )
                : node)
            .toList(),
      );
    });
  }

  void _commitDrag() {
    setState(() => _draggingId = null);
    widget.onChanged(_document.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _canvasWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 360;
        final nodes = _document.nodes;
        final nodeRects = <String, Rect>{};
        for (final node in nodes) {
          final size = _nodeSize(node.kind);
          nodeRects[node.id] =
              Rect.fromLTWH(node.x, node.y, size.width, size.height);
        }
        return SizedBox(
          height: _kHeaderHeight + kFlowchartCanvasHeight,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _FlowchartHeader(
                    nodeCount: nodes.length,
                    canEdit: widget.canEdit,
                  ),
                  Expanded(
                    child: nodes.isEmpty
                        ? const _FlowchartEmpty()
                        : Stack(
                            clipBehavior: Clip.hardEdge,
                            children: <Widget>[
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _FlowchartEdgePainter(
                                    edges: _document.edges,
                                    nodeRects: nodeRects,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    labelStyle: theme.textTheme.labelSmall ??
                                        const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                              for (final node in nodes)
                                _buildNode(node),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNode(FlowchartNode node) {
    final size = _nodeSize(node.kind);
    final dragging = _draggingId == node.id;
    final chip = _FlowchartNodeChip(node: node, dragging: dragging);
    if (!widget.canEdit) {
      return Positioned(
        left: node.x,
        top: node.y,
        width: size.width,
        height: size.height,
        child: chip,
      );
    }
    return Positioned(
      left: node.x,
      top: node.y,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        // Translucent so a plain tap still reaches the block surface for
        // selection; only a drag (pointer moves past the slop threshold) is
        // claimed by this recognizer, keeping business gestures off the empty
        // canvas.
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => setState(() => _draggingId = node.id),
        onPanUpdate: (details) => _applyDrag(node.id, details.delta, size),
        onPanEnd: (_) => _commitDrag(),
        child: MouseRegion(
          cursor: dragging
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          child: chip,
        ),
      ),
    );
  }
}

Size _nodeSize(FlowchartNodeKind kind) {
  switch (kind) {
    case FlowchartNodeKind.decision:
      return const Size(120, 60);
    case FlowchartNodeKind.start:
    case FlowchartNodeKind.end:
      return const Size(96, 36);
    case FlowchartNodeKind.process:
      return const Size(104, 40);
  }
}

class _FlowchartHeader extends StatelessWidget {
  const _FlowchartHeader({required this.nodeCount, required this.canEdit});

  final int nodeCount;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: _kHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.account_tree_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '流程图 · $nodeCount 节点',
            style: theme.textTheme.labelSmall,
          ),
          const Spacer(),
          if (canEdit)
            Text(
              '拖拽节点调整位置',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _FlowchartEmpty extends StatelessWidget {
  const _FlowchartEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        '空流程图',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FlowchartNodeChip extends StatelessWidget {
  const _FlowchartNodeChip({required this.node, required this.dragging});

  final FlowchartNode node;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _kNodeColors[node.kind] ?? _kNodeColors[FlowchartNodeKind.process]!;
    final size = _nodeSize(node.kind);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _NodeShapePainter(
                kind: node.kind,
                fill: colors.fill,
                border: colors.border,
                dragging: dragging,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                node.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeColors {
  const _NodeColors(this.fill, this.border, this.foreground);

  final Color fill;
  final Color border;
  final Color foreground;
}

const Map<FlowchartNodeKind, _NodeColors> _kNodeColors =
    <FlowchartNodeKind, _NodeColors>{
  FlowchartNodeKind.start: _NodeColors(Color(0xFFD1FAE5), Color(0xFF059669), Color(0xFF064E3B)),
  FlowchartNodeKind.process: _NodeColors(Color(0xFFDBEAFE), Color(0xFF2563EB), Color(0xFF1E3A8A)),
  FlowchartNodeKind.decision: _NodeColors(Color(0xFFFEF3C7), Color(0xFFD97706), Color(0xFF92400E)),
  FlowchartNodeKind.end: _NodeColors(Color(0xFFFEE2E2), Color(0xFFDC2626), Color(0xFF991B1B)),
};

class _NodeShapePainter extends CustomPainter {
  _NodeShapePainter({
    required this.kind,
    required this.fill,
    required this.border,
    required this.dragging,
  });

  final FlowchartNodeKind kind;
  final Color fill;
  final Color border;
  final bool dragging;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = dragging ? 2.2 : 1.4;
    switch (kind) {
      case FlowchartNodeKind.start:
      case FlowchartNodeKind.end:
        {
          final rounded = RRect.fromRectAndRadius(
            rect,
            Radius.circular(rect.height / 2),
          );
          canvas.drawRRect(rounded, fillPaint);
          canvas.drawRRect(rounded, borderPaint);
        }
      case FlowchartNodeKind.process:
        {
          final rounded =
              RRect.fromRectAndRadius(rect, const Radius.circular(8));
          canvas.drawRRect(rounded, fillPaint);
          canvas.drawRRect(rounded, borderPaint);
        }
      case FlowchartNodeKind.decision:
        {
          final mid = rect.center;
          final path = Path()
            ..moveTo(mid.dx, rect.top)
            ..lineTo(rect.right, mid.dy)
            ..lineTo(mid.dx, rect.bottom)
            ..lineTo(rect.left, mid.dy)
            ..close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, borderPaint);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _NodeShapePainter old) {
    return old.kind != kind ||
        old.fill != fill ||
        old.border != border ||
        old.dragging != dragging;
  }
}

/// Paints edges (with arrowheads and optional labels) behind the node stack.
/// Endpoints are clipped to each node's bounding box so lines meet the border
/// instead of disappearing under the chip.
class _FlowchartEdgePainter extends CustomPainter {
  _FlowchartEdgePainter({
    required this.edges,
    required this.nodeRects,
    required this.color,
    required this.labelStyle,
  });

  final List<FlowchartEdge> edges;
  final Map<String, Rect> nodeRects;
  final Color color;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final edge in edges) {
      final source = nodeRects[edge.from];
      final target = nodeRects[edge.to];
      if (source == null || target == null) {
        continue;
      }
      final start = _rectBorderPoint(source, target.center);
      final end = _rectBorderPoint(target, source.center);
      canvas.drawLine(start, end, linePaint);
      _drawArrowhead(canvas, end, start, linePaint);
      if (edge.label.isNotEmpty) {
        _drawLabel(canvas, start, end, edge.label);
      }
    }
  }

  void _drawArrowhead(Canvas canvas, Offset tip, Offset from, Paint paint) {
    final direction = tip - from;
    final length = direction.distance;
    if (length == 0) {
      return;
    }
    final unit = direction / length;
    final angle = math.atan2(unit.dy, unit.dx);
    const arrowLen = 7.0;
    const arrowHalf = math.pi / 7;
    final left = Offset(
      tip.dx - arrowLen * math.cos(angle - arrowHalf),
      tip.dy - arrowLen * math.sin(angle - arrowHalf),
    );
    final right = Offset(
      tip.dx - arrowLen * math.cos(angle + arrowHalf),
      tip.dy - arrowLen * math.sin(angle + arrowHalf),
    );
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy);
    canvas.drawPath(path, paint);
  }

  void _drawLabel(Canvas canvas, Offset start, Offset end, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final mid = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );
    final background = Rect.fromCenter(
      center: mid,
      width: painter.width + 8,
      height: painter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(background, const Radius.circular(4)),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    painter.paint(
      canvas,
      Offset(
        mid.dx - painter.width / 2,
        mid.dy - painter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _FlowchartEdgePainter old) {
    return old.color != color ||
        old.labelStyle != labelStyle ||
        !listEquals(old.edges, edges) ||
        !_rectMapsEqual(old.nodeRects, nodeRects);
  }
}

Offset _rectBorderPoint(Rect rect, Offset toward) {
  final center = rect.center;
  final dx = toward.dx - center.dx;
  final dy = toward.dy - center.dy;
  if (dx == 0 && dy == 0) {
    return center;
  }
  final halfWidth = rect.width / 2;
  final halfHeight = rect.height / 2;
  final scaleX = dx == 0 ? double.infinity : halfWidth / dx.abs();
  final scaleY = dy == 0 ? double.infinity : halfHeight / dy.abs();
  final scale = math.min(scaleX, scaleY);
  return Offset(center.dx + dx * scale, center.dy + dy * scale);
}

bool _rectMapsEqual(Map<String, Rect> a, Map<String, Rect> b) {
  if (a.length != b.length) {
    return false;
  }
  for (final key in a.keys) {
    if (a[key] != b[key]) {
      return false;
    }
  }
  return true;
}

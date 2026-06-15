import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_actions.dart';
import 'mindmap_drag_session.dart';
import 'mindmap_node_data.dart';

/// WidgetElementBuilder for a single mind map node in "non-component mode".
///
/// Each node is an independent [CanvasWidgetElement] with
/// `widgetType == 'mindmap_node'`. The builder only renders the node visual +
/// handles inline text editing and the context menu; tree layout is driven
/// externally by [MindmapActions] / [MindmapSyncController].
///
/// IMPORTANT: do NOT add a [GestureDetector] that swallows taps for
/// selection — the canvas select tool already drives selection via its own
/// hit-testing. We only handle double-tap (edit) and long-press (menu) here.
class MindmapNodeBuilder extends WidgetElementBuilder {
  const MindmapNodeBuilder();

  @override
  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    final data = MindmapNodeData.fromWidgetData(element.widgetData);

    if (canvas.renderDetail != CanvasWidgetRenderDetail.full) {
      return _buildPreview(data, canvas.renderDetail);
    }

    return _MindmapNodeView(
      element: element,
      data: data,
      canvas: canvas,
    );
  }

  Widget _buildPreview(MindmapNodeData data, CanvasWidgetRenderDetail detail) {
    final color = Color(data.color);
    return switch (detail) {
      CanvasWidgetRenderDetail.color => ColoredBox(color: color),
      CanvasWidgetRenderDetail.colorWithText ||
      CanvasWidgetRenderDetail.thumbnail => DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: Center(
            child: Text(
              data.text.isEmpty ? '…' : data.text,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ),
      CanvasWidgetRenderDetail.full => ColoredBox(color: color),
    };
  }
}

/// Stateful node view: handles inline editing + context menu.
class _MindmapNodeView extends StatefulWidget {
  const _MindmapNodeView({
    required this.element,
    required this.data,
    required this.canvas,
  });

  final CanvasWidgetElement element;
  final MindmapNodeData data;
  final CanvasWidgetBuildContext canvas;

  @override
  State<_MindmapNodeView> createState() => _MindmapNodeViewState();
}

class _MindmapNodeViewState extends State<_MindmapNodeView> {
  final GlobalKey _editKey = GlobalKey();
  late TextEditingController _editController;
  late FocusNode _editFocusNode;
  bool _isEditing = false;

  MindmapDragSession? get _dragSession => _actions?.dragSession;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.data.text);
    _editFocusNode = FocusNode();
    _dragSession?.addListener(_onDragChanged);
  }

  @override
  void didUpdateWidget(covariant _MindmapNodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.text != oldWidget.data.text && !_isEditing) {
      _editController.text = widget.data.text;
    }
  }

  @override
  void dispose() {
    _dragSession?.removeListener(_onDragChanged);
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  void _onDragChanged() {
    if (mounted) setState(() {});
  }

  /// Whether this node is currently being dragged (→ render dimmed).
  bool get _isBeingDragged =>
      _dragSession?.isActive == true &&
      _dragSession!.movingNodeIds.contains(widget.element.id);

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _editController.text = widget.data.text;
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.data.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode.requestFocus();
    });
  }

  void _commitEdit() {
    final newText = _editController.text;
    setState(() => _isEditing = false);
    MindmapActions.of(widget.canvas.canvasController)
        ?.commitText(widget.element.id, newText);
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
    _editController.text = widget.data.text;
  }

  // ── Context menu ───────────────────────────────────────────────────

  MindmapActions? get _actions =>
      MindmapActions.of(widget.canvas.canvasController);

  void _onSecondaryTapDown(TapDownDetails details) {
    _showContextMenu();
  }

  void _showContextMenu() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final origin = renderBox.localToGlobal(Offset.zero);
    final position = RelativeRect.fromLTRB(
      origin.dx,
      origin.dy,
      origin.dx + renderBox.size.width,
      origin.dy + renderBox.size.height,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(value: 'addChild', child: Text('添加子节点')),
        if (!widget.data.isRoot)
          const PopupMenuItem(value: 'addSibling', child: Text('添加同级节点')),
        if (!widget.data.isRoot)
          const PopupMenuItem(value: 'delete', child: Text('删除节点')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'color', child: Text('修改颜色')),
      ],
    ).then((value) {
      final actions = MindmapActions.of(widget.canvas.canvasController);
      if (actions == null || value == null) return;
      switch (value) {
        case 'addChild':
          actions.addChild(widget.element.id);
          break;
        case 'addSibling':
          actions.addSibling(widget.element.id);
          break;
        case 'delete':
          actions.deleteNode(widget.element.id);
          break;
        case 'color':
          _showColorPalette();
          break;
      }
    });
  }

  void _showColorPalette() {
    const colors = [
      0xFF2563EB, 0xFFE3F2FD, 0xFF34C759, 0xFFE8F5E9,
      0xFFFF9500, 0xFFFFF3E0, 0xFFEC4899, 0xFFFCE4EC,
      0xFF8B5CF6, 0xFFF3E5F5, 0xFF6B7280, 0xFFF3F4F6,
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('选择颜色'),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in colors)
                GestureDetector(
                  onTap: () {
                    MindmapActions.of(widget.canvas.canvasController)
                        ?.setNodeColor(widget.element.id, c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.data.color == c
                            ? const Color(0xFF2563EB)
                            : Colors.grey.shade300,
                        width: widget.data.color == c ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(widget.data.color);
    final txtColor = Color(widget.data.textColor);
    final isRoot = widget.data.isRoot;
    final selected = widget.canvas.selected;

    if (_isEditing) {
      return _buildEditingNode(bgColor, txtColor, isRoot);
    }

    final borderRadius = isRoot ? 24.0 : 8.0;

    return Opacity(
      // Dim the node slightly while it is being dragged.
      opacity: _isBeingDragged ? 0.6 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => widget.canvas.canvasController
            .setSelection({widget.element.id}),
        onDoubleTap: _startEditing,
        // Right-click opens the context menu.
        onSecondaryTapDown: _onSecondaryTapDown,
        // FittedBox scales the node content to fit the element's worldRect
        // (120×40 for regular nodes, 140×48 for root) so text never overflows
        // the laid-out footprint.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isRoot ? 16 : 12,
              vertical: isRoot ? 10 : 6,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: selected
                    ? const Color(0xFF2563EB)
                    : bgColor.computeLuminance() > 0.5
                        ? const Color(0xFFD1D5DB)
                        : const Color(0x33FFFFFF),
                width: selected ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.data.text.isEmpty ? '...' : widget.data.text,
              style: TextStyle(
                color: txtColor,
                fontSize: isRoot ? 16 : 14,
                fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              softWrap: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditingNode(Color bgColor, Color txtColor, bool isRoot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isRoot ? 24 : 8),
        border: Border.all(color: const Color(0xFF2563EB), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 60, maxWidth: 140),
              child: KeyboardListener(
                key: _editKey,
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event is! KeyDownEvent) return;
                  final key = event.logicalKey;
                  if (key == LogicalKeyboardKey.enter ||
                      key == LogicalKeyboardKey.numpadEnter) {
                    final text = _editController.text;
                    final actions =
                        MindmapActions.of(widget.canvas.canvasController);
                    if (widget.data.isRoot) {
                      _commitEdit();
                    } else if (actions != null) {
                      setState(() => _isEditing = false);
                      actions.commitAndAddSibling(widget.element.id, text);
                    } else {
                      _commitEdit();
                    }
                  } else if (key == LogicalKeyboardKey.tab) {
                    final text = _editController.text;
                    final actions =
                        MindmapActions.of(widget.canvas.canvasController);
                    if (actions != null) {
                      setState(() => _isEditing = false);
                      actions.commitAndAddChild(widget.element.id, text);
                    } else {
                      _commitEdit();
                    }
                  } else if (key == LogicalKeyboardKey.escape) {
                    _cancelEdit();
                  }
                },
                child: TextField(
                  controller: _editController,
                  focusNode: _editFocusNode,
                  style: TextStyle(
                    color: txtColor,
                    fontSize: isRoot ? 16 : 14,
                    fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    border: InputBorder.none,
                    hintText: '输入文字...',
                  ),
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _commitEdit(),
                  onTapOutside: (_) => _commitEdit(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _commitEdit,
            child: const Icon(Icons.check, size: 18, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }
}

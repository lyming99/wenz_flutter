import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mindmap_node.dart';

/// Renders a single mind map node.
///
/// Features:
/// - Tap to select
/// - Double-tap to enter text editing mode
/// - Long-press context menu (add child / delete / color)
/// - Collapse/expand is handled by the merge-point button on connections
class MindmapNodeWidget extends StatefulWidget {
  const MindmapNodeWidget({
    super.key,
    required this.node,
    required this.isSelected,
    required this.isEditing,
    required this.onTap,
    required this.onDoubleTap,
    required this.onCommitEdit,
    required this.onCancelEdit,
    required this.onColorChange,
    required this.onAddChild,
    required this.onDelete,
    required this.isRoot,
    this.onCommitAndAddSibling,
    this.onCommitAndAddChild,
  });

  final MindmapNode node;
  final bool isSelected;
  final bool isEditing;
  final bool isRoot;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<String> onCommitEdit;
  final VoidCallback onCancelEdit;
  final ValueChanged<int> onColorChange;
  final VoidCallback onAddChild;
  final VoidCallback onDelete;
  final void Function(String nodeId, String text)? onCommitAndAddSibling;
  final void Function(String nodeId, String text)? onCommitAndAddChild;

  @override
  State<MindmapNodeWidget> createState() => _MindmapNodeWidgetState();
}

class _MindmapNodeWidgetState extends State<MindmapNodeWidget> {
  late TextEditingController _editController;
  late FocusNode _editFocusNode;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.node.text);
    _editFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant MindmapNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing && !oldWidget.isEditing) {
      _editController.text = widget.node.text;
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.node.text.length,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _editFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  void _commit() {
    widget.onCommitEdit(_editController.text);
  }

  void _showContextMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromLTRB(
      button.localToGlobal(Offset.zero).dx,
      button.localToGlobal(Offset.zero).dy,
      button.localToGlobal(Offset.zero).dx + button.size.width,
      button.localToGlobal(Offset.zero).dy + button.size.height,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(value: 'addChild', child: Text('添加子节点')),
        if (!widget.isRoot)
          const PopupMenuItem(value: 'delete', child: Text('删除节点')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'color', child: Text('修改颜色')),
      ],
    ).then((value) {
      if (value == 'addChild') {
        widget.onAddChild();
      } else if (value == 'delete') {
        widget.onDelete();
      } else if (value == 'color') {
        _showColorPalette(context);
      }
    });
  }

  void _showColorPalette(BuildContext context) {
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
                    widget.onColorChange(c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.node.color == c
                            ? const Color(0xFF2563EB)
                            : Colors.grey.shade300,
                        width: widget.node.color == c ? 3 : 1,
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
    final bgColor = Color(widget.node.color);
    final txtColor = Color(widget.node.textColor);

    if (widget.isEditing) {
      return _buildEditingNode(bgColor, txtColor);
    }

    final borderRadius = widget.isRoot ? 24.0 : 8.0;

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: () => _showContextMenu(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.isRoot ? 16 : 12,
          vertical: widget.isRoot ? 10 : 6,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: widget.isSelected
                ? const Color(0xFF2563EB)
                : bgColor.computeLuminance() > 0.5
                    ? const Color(0xFFD1D5DB)
                    : const Color(0x33FFFFFF),
            width: widget.isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            widget.node.text.isEmpty ? '...' : widget.node.text,
            style: TextStyle(
              color: txtColor,
              fontSize: widget.isRoot ? 16 : 14,
              fontWeight: widget.isRoot ? FontWeight.w700 : FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            softWrap: true,
          ),
        ),
      ),
    );
  }

  Widget _buildEditingNode(Color bgColor, Color txtColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
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
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event is! KeyDownEvent) return;
                  final key = event.logicalKey;
                  if (key == LogicalKeyboardKey.enter ||
                      key == LogicalKeyboardKey.numpadEnter) {
                    _handleEnter();
                  } else if (key == LogicalKeyboardKey.tab) {
                    _handleTab();
                  }
                },
                child: TextField(
                  controller: _editController,
                  focusNode: _editFocusNode,
                  style: TextStyle(
                    color: txtColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    border: InputBorder.none,
                    hintText: '输入文字...',
                  ),
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _commit(),
                  onTapOutside: (_) => _commit(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _commit,
            child: const Icon(Icons.check, size: 18, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  void _handleEnter() {
    final text = _editController.text;
    if (widget.onCommitAndAddSibling != null) {
      widget.onCommitAndAddSibling!(widget.node.id, text);
    } else {
      _commit();
    }
  }

  void _handleTab() {
    final text = _editController.text;
    if (widget.onCommitAndAddChild != null) {
      widget.onCommitAndAddChild!(widget.node.id, text);
    } else {
      _commit();
    }
  }
}

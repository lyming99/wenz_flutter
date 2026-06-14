import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mindmap_connection_painter.dart';
import 'mindmap_controller.dart';
import 'mindmap_layout.dart';
import 'mindmap_node_widget.dart';

/// The main mind map widget that renders the tree.
///
/// Uses a [MindmapController] for state management.
/// Listens to changes and rebuilds the layout accordingly.
///
/// Keyboard shortcuts (non-editing mode):
/// - **Enter**: create a sibling of the selected node.
/// - **Tab**: create a child of the selected node.
class MindmapWidget extends StatefulWidget {
  const MindmapWidget({
    super.key,
    required this.controller,
    this.connectionColor = const Color(0xFF94A3B8),
  });

  final MindmapController controller;
  final Color connectionColor;

  @override
  State<MindmapWidget> createState() => _MindmapWidgetState();
}

class _MindmapWidgetState extends State<MindmapWidget> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Handle keyboard shortcuts when NOT in editing mode.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final controller = widget.controller;

    if (controller.isEditing) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final selectedId = controller.selectedNodeId ?? controller.data.root.id;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      controller.addSibling(selectedId);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.tab) {
      controller.addChild(selectedId);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final layoutResult = MindmapLayout.calculate(controller.data.root);
    final rootNode = layoutResult.root;
    final totalSize = layoutResult.totalSize;

    // Root node is ALWAYS fixed at the center of the SizedBox.
    // All child positions are relative to root and auto-adjust when
    // nodes are added / removed / collapsed.
    // Since root is at Offset.zero in layout space, shift to center.
    final shiftX = totalSize.width / 2;
    final shiftY = totalSize.height / 2;
    final shiftedRoot = _shiftLayout(rootNode, Offset(shiftX, shiftY));
    final shiftedNodes = MindmapLayout.getAllNodes(shiftedRoot);

    // Compute merge points from the already-shifted layout
    final mergePoints = MindmapLayout.getMergePoints(shiftedRoot);

    return SizedBox(
      width: totalSize.width,
      height: totalSize.height,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _onKeyEvent,
        child: GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Connection layer
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: MindmapConnectionPainter(
                      root: shiftedRoot,
                      color: widget.connectionColor,
                      strokeWidth: 2.5,
                      mergePoints: mergePoints,
                    ),
                  ),
                ),
              ),
              // Merge-point buttons (collapse/expand)
              for (final mp in mergePoints)
                Positioned(
                  left: mp.position.dx - 12,
                  top: mp.position.dy - 12,
                  child: _MergeButton(
                    isCollapsed: mp.isCollapsed,
                    childCount: mp.childCount,
                    onTap: () {
                      controller.toggleCollapse(mp.parentNodeId);
                    },
                  ),
                ),
              // Node layer
              for (final layoutNode in shiftedNodes)
                Positioned(
                  left: layoutNode.rect.left,
                  top: layoutNode.rect.top,
                  child: SizedBox(
                    width: layoutNode.rect.width,
                    height: layoutNode.rect.height,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: MindmapNodeWidget(
                          node: layoutNode.node,
                          isRoot: layoutNode.depth == 0,
                          isSelected:
                              controller.selectedNodeId == layoutNode.node.id,
                          isEditing:
                              controller.editingNodeId == layoutNode.node.id,
                          onTap: () {
                            controller.selectNode(layoutNode.node.id);
                            _focusNode.requestFocus();
                          },
                          onDoubleTap: () =>
                              controller.startEditing(layoutNode.node.id),
                          onCommitEdit: (text) =>
                              controller.commitEdit(layoutNode.node.id, text),
                          onCancelEdit: () => controller.cancelEdit(),
                          onColorChange: (color) =>
                              controller.setNodeColor(layoutNode.node.id, color),
                          onAddChild: () =>
                              controller.addChild(layoutNode.node.id),
                          onDelete: () =>
                              controller.deleteNode(layoutNode.node.id),
                          onCommitAndAddSibling: (nodeId, text) =>
                              controller.commitAndAddSibling(nodeId, text),
                          onCommitAndAddChild: (nodeId, text) =>
                              controller.commitAndAddChild(nodeId, text),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  MindmapLayoutNode _shiftLayout(MindmapLayoutNode node, Offset offset) {
    return MindmapLayoutNode(
      node: node.node,
      rect: node.rect.shift(offset),
      depth: node.depth,
      expandedChildren: [
        for (final c in node.expandedChildren) _shiftLayout(c, offset),
      ],
    );
  }
}

/// The merge-point collapse/expand button.
/// Sits on the connection line between parent and children.
class _MergeButton extends StatelessWidget {
  const _MergeButton({
    required this.isCollapsed,
    required this.childCount,
    required this.onTap,
  });

  final bool isCollapsed;
  final int childCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isCollapsed
              ? const Color(0xFF2563EB)
              : Colors.white,
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
    );
  }
}

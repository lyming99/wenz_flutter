import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_actions.dart';
import 'mindmap_drag_session.dart';
import 'mindmap_node_data.dart';
import 'mindmap_node_metrics.dart';

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
  bool get useDefaultThumbnailFrame => false;

  @override
  bool get useDefaultSelectionFrame => false;

  @override
  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    return _buildNode(element, canvas);
  }

  @override
  Widget buildPreview(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    return _buildNode(element, canvas);
  }

  Widget _buildNode(
    CanvasWidgetElement element,
    CanvasWidgetBuildContext canvas,
  ) {
    return _MindmapNodeView(
      element: element,
      data: MindmapNodeData.fromWidgetData(element.widgetData),
      canvas: canvas,
    );
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
  late FocusNode _nodeFocusNode;
  DateTime? _lastTapDownTime;
  Offset? _lastTapDownPosition;

  static const Duration _doubleTapInterval = Duration(milliseconds: 300);
  static const double _doubleTapSlop = 18;

  MindmapDragSession? get _dragSession => _actions?.dragSession;
  MindmapActions? _listenedActions;

  @override
  void initState() {
    super.initState();
    _nodeFocusNode = FocusNode(debugLabel: 'MindmapNode:${widget.element.id}');
    _listenedActions = _actions;
    _listenedActions?.dragSession.addListener(_onDragChanged);
    _listenedActions?.editRequest.addListener(_onEditRequestChanged);
    _scheduleEditRequestCheck();
  }

  @override
  void didUpdateWidget(covariant _MindmapNodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.element.id != oldWidget.element.id) {
      _lastTapDownTime = null;
      _lastTapDownPosition = null;
    }
    _scheduleEditRequestCheck();
  }

  @override
  void dispose() {
    _listenedActions?.editRequest.removeListener(_onEditRequestChanged);
    _listenedActions?.dragSession.removeListener(_onDragChanged);
    _nodeFocusNode.dispose();
    super.dispose();
  }

  void _onDragChanged() {
    if (mounted) setState(() {});
  }

  void _onEditRequestChanged() {
    _handleEditRequest(_listenedActions?.editRequest.value);
  }

  void _scheduleEditRequestCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleEditRequest(_listenedActions?.editRequest.value);
    });
  }

  void _handleEditRequest(MindmapEditRequest? request) {
    if (!mounted || request == null || request.nodeId != widget.element.id) {
      return;
    }
    _startEditing();
    _listenedActions?.consumeEditRequest(request);
  }

  /// Whether this node is currently being dragged (→ render dimmed).
  bool get _isBeingDragged =>
      _dragSession?.isActive == true &&
      _dragSession!.movingNodeIds.contains(widget.element.id);

  void _startEditing() {
    final actions = _actions;
    if (actions != null) {
      actions.beginEditing(widget.element.id);
    } else {
      widget.canvas.canvasController.setSelection({widget.element.id});
    }
  }

  void _onPrimaryTapDown(TapDownDetails details) {
    if (_actions?.editingNodeId.value != null) return;

    final now = DateTime.now();
    final position = details.globalPosition;
    final lastTime = _lastTapDownTime;
    final lastPosition = _lastTapDownPosition;
    final isDoubleTap =
        lastTime != null &&
        lastPosition != null &&
        now.difference(lastTime) <= _doubleTapInterval &&
        (position - lastPosition).distance <= _doubleTapSlop;

    _lastTapDownTime = now;
    _lastTapDownPosition = position;

    widget.canvas.canvasController.setSelection({widget.element.id});
    _nodeFocusNode.requestFocus();

    if (isDoubleTap) {
      _lastTapDownTime = null;
      _lastTapDownPosition = null;
      _startEditing();
    }
  }

  KeyEventResult _onNodeKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !widget.canvas.selected) {
      return KeyEventResult.ignored;
    }

    final hardware = HardwareKeyboard.instance;
    if (hardware.isControlPressed ||
        hardware.isMetaPressed ||
        hardware.isAltPressed) {
      return KeyEventResult.ignored;
    }

    final actions = _actions;
    if (actions == null) return KeyEventResult.ignored;
    if (actions.editingNodeId.value != null) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab) {
      actions.addChild(widget.element.id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      actions.addSibling(widget.element.id);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
      0xFF2563EB,
      0xFFE3F2FD,
      0xFF34C759,
      0xFFE8F5E9,
      0xFFFF9500,
      0xFFFFF3E0,
      0xFFEC4899,
      0xFFFCE4EC,
      0xFF8B5CF6,
      0xFFF3E5F5,
      0xFF6B7280,
      0xFFF3F4F6,
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
                    MindmapActions.of(
                      widget.canvas.canvasController,
                    )?.setNodeColor(widget.element.id, c);
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

    final child = _buildDisplayNode(bgColor, txtColor, isRoot);

    return Opacity(
      // Dim the node slightly while it is being dragged.
      opacity: _isBeingDragged ? 0.6 : 1.0,
      child: Focus(
        focusNode: _nodeFocusNode,
        onKeyEvent: _onNodeKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: _onPrimaryTapDown,
          // Right-click opens the context menu.
          onSecondaryTapDown: _onSecondaryTapDown,
          child: child,
        ),
      ),
    );
  }

  Widget _buildDisplayNode(Color bgColor, Color txtColor, bool isRoot) {
    return switch (widget.canvas.renderDetail) {
      CanvasWidgetRenderDetail.color => _buildNodeShell(
        bgColor: bgColor,
        isRoot: isRoot,
        fill: Colors.transparent,
        width: 1.5,
      ),
      CanvasWidgetRenderDetail.colorWithText => _buildNodeShell(
        bgColor: bgColor,
        isRoot: isRoot,
        fill: Colors.transparent,
        width: 1.5,
        child: _buildScaledText(
          text: widget.data.text,
          color: _textColorForOutline(bgColor),
          fontSize: isRoot ? 11 : 10,
          fontWeight: FontWeight.w700,
          maxLines: 1,
        ),
      ),
      CanvasWidgetRenderDetail.thumbnail ||
      CanvasWidgetRenderDetail.full => _buildNodeShell(
        bgColor: bgColor,
        isRoot: isRoot,
        fill: bgColor,
        shadow: true,
        child: _buildScaledText(
          text: widget.data.text,
          color: txtColor,
          fontSize: isRoot ? 16 : 14,
          fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
          maxLines: 2,
        ),
      ),
    };
  }

  Widget _buildNodeShell({
    required Color bgColor,
    required bool isRoot,
    required Color fill,
    Widget? child,
    double width = 1,
    bool shadow = false,
    bool highlighted = false,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(isRoot ? 24 : 8),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF2563EB)
              : _borderColorFor(bgColor),
          width: highlighted ? 2 : width,
        ),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child == null
          ? const SizedBox.expand()
          : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isRoot ? 16 : 12,
                vertical: isRoot ? 10 : 6,
              ),
              child: Center(child: child),
            ),
    );
  }

  Widget _buildScaledText({
    required String text,
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    required int maxLines,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MindmapNodeMetrics.maxNodeWidth;
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Text(
              text.isEmpty ? '...' : text,
              overflow: TextOverflow.ellipsis,
              maxLines: maxLines,
              softWrap: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _borderColorFor(Color color) {
    if (color.computeLuminance() > 0.72) {
      return const Color(0xFFD1D5DB);
    }
    return color;
  }

  Color _textColorForOutline(Color color) {
    return color.computeLuminance() > 0.72 ? const Color(0xFF1F2937) : color;
  }
}

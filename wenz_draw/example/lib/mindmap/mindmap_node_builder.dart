import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_actions.dart';
import 'mindmap_drag_session.dart';
import 'mindmap_node_data.dart';
import 'mindmap_node_metrics.dart';
import 'mindmap_theme.dart';

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
  MindmapThemeController? _themeController;

  @override
  void initState() {
    super.initState();
    _nodeFocusNode = FocusNode(debugLabel: 'MindmapNode:${widget.element.id}');
    _listenedActions = _actions;
    _listenedActions?.dragSession.addListener(_onDragChanged);
    _listenedActions?.editRequest.addListener(_onEditRequestChanged);
    _bindThemeController();
    _scheduleEditRequestCheck();
  }

  @override
  void didUpdateWidget(covariant _MindmapNodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.element.id != oldWidget.element.id) {
      _lastTapDownTime = null;
      _lastTapDownPosition = null;
    }
    _bindThemeController();
    _scheduleEditRequestCheck();
  }

  @override
  void dispose() {
    _themeController?.removeListener(_onThemeChanged);
    _listenedActions?.editRequest.removeListener(_onEditRequestChanged);
    _listenedActions?.dragSession.removeListener(_onDragChanged);
    _nodeFocusNode.dispose();
    super.dispose();
  }

  void _bindThemeController() {
    final next = _actions?.themeController;
    if (identical(next, _themeController)) return;
    _themeController?.removeListener(_onThemeChanged);
    _themeController = next;
    _themeController?.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
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
        const PopupMenuItem(value: 'style', child: Text('设置样式')),
        if (widget.data.isRoot)
          const PopupMenuItem(value: 'theme', child: Text('切换主题')),
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
        case 'style':
          _showStylePalette();
          break;
        case 'theme':
          _showThemePicker();
          break;
      }
    });
  }

  void _showStylePalette() {
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
          title: const Text('节点样式'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StylePaletteSection(
                  title: '底色',
                  colors: colors,
                  selectedColor: widget.data.fillColor,
                  onReset: () {
                    MindmapActions.of(
                      widget.canvas.canvasController,
                    )?.setNodeStyle(widget.element.id, fillColor: null);
                    Navigator.pop(ctx);
                  },
                  onPick: (color) {
                    MindmapActions.of(
                      widget.canvas.canvasController,
                    )?.setNodeStyle(widget.element.id, fillColor: color);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 16),
                _StylePaletteSection(
                  title: '边框',
                  colors: colors,
                  selectedColor: widget.data.borderColor,
                  onReset: () {
                    MindmapActions.of(
                      widget.canvas.canvasController,
                    )?.setNodeStyle(widget.element.id, borderColor: null);
                    Navigator.pop(ctx);
                  },
                  onPick: (color) {
                    MindmapActions.of(
                      widget.canvas.canvasController,
                    )?.setNodeStyle(widget.element.id, borderColor: color);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 16),
                _StylePaletteSection(
                  title: '字体',
                  colors: colors,
                  selectedColor: widget.data.fontColor,
                  onReset: () {
                    MindmapActions.of(
                      widget.canvas.canvasController,
                    )?.setNodeStyle(widget.element.id, fontColor: null);
                    Navigator.pop(ctx);
                  },
                  onPick: (color) {
                    MindmapActions.of(
                      widget.canvas.canvasController,
                    )?.setNodeStyle(widget.element.id, fontColor: color);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
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

  void _showThemePicker() {
    final actions = MindmapActions.of(widget.canvas.canvasController);
    if (actions == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('切换主题'),
          children: [
            for (final theme in MindmapThemes.presets)
              SimpleDialogOption(
                onPressed: () {
                  actions.setRootTheme(widget.element.id, theme.id);
                  Navigator.pop(ctx);
                },
                child: Row(
                  children: [
                    Expanded(child: Text(theme.label)),
                    if (actions.themeIdForNode(widget.element.id) == theme.id)
                      const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRoot = widget.data.isRoot;
    final style = _styleForNode();

    final child = _buildDisplayNode(style, isRoot);

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

  MindmapResolvedNodeStyle _styleForNode() {
    final actions = _actions;
    if (actions != null) {
      return actions.styleForNode(
        widget.element.id,
        isSelected: widget.canvas.selected,
      );
    }
    return MindmapThemeController().styleFor(
      MindmapThemeNodeContext.fromNodeData(
        widget.data,
        depth: widget.data.isRoot ? 0 : 1,
        siblingIndex: widget.data.order,
        siblingCount: 1,
        isSelected: widget.canvas.selected,
      ),
    );
  }

  Widget _buildDisplayNode(MindmapResolvedNodeStyle style, bool isRoot) {
    return switch (widget.canvas.renderDetail) {
      CanvasWidgetRenderDetail.color => _buildNodeShell(
        style: style,
        isRoot: isRoot,
        fill: style.fillColor,
        width: 1.5,
      ),
      CanvasWidgetRenderDetail.colorWithText ||
      CanvasWidgetRenderDetail.thumbnail ||
      CanvasWidgetRenderDetail.full => _buildNodeShell(
        style: style,
        isRoot: isRoot,
        fill: style.fillColor,
        shadow: true,
        child: _buildScaledText(
          text: widget.data.text,
          style: style.textStyle,
          maxLines: 2,
        ),
      ),
    };
  }

  Widget _buildNodeShell({
    required MindmapResolvedNodeStyle style,
    required bool isRoot,
    required Color fill,
    Widget? child,
    double width = 1,
    bool shadow = false,
    bool highlighted = false,
  }) {
    final effectiveStyle = style.copyWith(shadow: shadow && style.shadow);
    return MindmapNodeFrame(
      style: effectiveStyle,
      fillColor: fill,
      borderWidth: width,
      highlighted: highlighted,
      child: child == null
          ? const SizedBox.expand()
          : Padding(
              padding: style.padding,
              child: Center(child: child),
            ),
    );
  }

  Widget _buildScaledText({
    required String text,
    required TextStyle style,
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
              style: style,
            ),
          ),
        );
      },
    );
  }
}

class _StylePaletteSection extends StatelessWidget {
  const _StylePaletteSection({
    required this.title,
    required this.colors,
    required this.selectedColor,
    required this.onPick,
    required this.onReset,
  });

  final String title;
  final List<int> colors;
  final int? selectedColor;
  final ValueChanged<int> onPick;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(onPressed: onReset, child: const Text('跟随主题')),
            for (final c in colors)
              GestureDetector(
                onTap: () => onPick(c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Color(c),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedColor == c
                          ? const Color(0xFF2563EB)
                          : Colors.grey.shade300,
                      width: selectedColor == c ? 3 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

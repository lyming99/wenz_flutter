import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_actions.dart';
import 'mindmap_drag_session.dart';
import 'mindmap_link_opener.dart';
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
    _listenedActions?.registerNodeFocusRequester(
      widget.element.id,
      _requestNodeFocus,
    );
    _bindThemeController();
    _scheduleEditRequestCheck();
  }

  @override
  void didUpdateWidget(covariant _MindmapNodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.element.id != oldWidget.element.id) {
      _listenedActions?.unregisterNodeFocusRequester(
        oldWidget.element.id,
        _requestNodeFocus,
      );
      _listenedActions?.registerNodeFocusRequester(
        widget.element.id,
        _requestNodeFocus,
      );
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
    _listenedActions?.unregisterNodeFocusRequester(
      widget.element.id,
      _requestNodeFocus,
    );
    _nodeFocusNode.dispose();
    super.dispose();
  }

  void _requestNodeFocus() {
    if (mounted) {
      _nodeFocusNode.requestFocus();
    }
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

  // ignore: unused_element
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
        PopupMenuItem(
          value: 'todo',
          child: Text(widget.data.todoEnabled ? '关闭 TODO' : '开启 TODO'),
        ),
        if (widget.data.todoEnabled)
          PopupMenuItem(
            value: 'todoDone',
            child: Text(widget.data.todoDone ? '标记未完成' : '标记完成'),
          ),
        PopupMenuItem(
          value: 'link',
          child: Text(widget.data.linkUrl == null ? '插入链接' : '编辑链接'),
        ),
        if (widget.data.linkUrl != null)
          const PopupMenuItem(value: 'openLink', child: Text('打开链接')),
        if (widget.data.linkUrl != null)
          const PopupMenuItem(value: 'removeLink', child: Text('清除链接')),
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
        case 'todo':
          actions.setNodeTodo(
            widget.element.id,
            enabled: !widget.data.todoEnabled,
          );
          break;
        case 'todoDone':
          actions.setNodeTodo(widget.element.id, done: !widget.data.todoDone);
          break;
        case 'link':
          _showLinkDialog();
          break;
        case 'openLink':
          _openLink(widget.data.linkUrl);
          break;
        case 'removeLink':
          actions.setNodeLink(widget.element.id, null);
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

  void _showLinkDialog() {
    final controller = TextEditingController(text: widget.data.linkUrl ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(widget.data.linkUrl == null ? '插入链接' : '编辑链接'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '链接地址',
              hintText: 'https://example.com',
            ),
            onSubmitted: (_) {
              MindmapActions.of(
                widget.canvas.canvasController,
              )?.setNodeLink(widget.element.id, controller.text);
              Navigator.pop(ctx);
            },
          ),
          actions: [
            if (widget.data.linkUrl != null)
              TextButton(
                onPressed: () {
                  MindmapActions.of(
                    widget.canvas.canvasController,
                  )?.setNodeLink(widget.element.id, null);
                  Navigator.pop(ctx);
                },
                child: const Text('清除'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                MindmapActions.of(
                  widget.canvas.canvasController,
                )?.setNodeLink(widget.element.id, controller.text);
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _openLink(String? url) async {
    final uri = _uriFromLink(url);
    if (uri == null) return;
    final opened = await MindmapLinkOpenerHolder.current.open(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }

  Uri? _uriFromLink(String? url) {
    final text = url?.trim();
    if (text == null || text.isEmpty) return null;
    final parsed = Uri.tryParse(text);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed;
    return Uri.tryParse('https://$text');
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
        child: _buildNodeContent(
          data: widget.data,
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
    double? width,
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

  Widget _buildNodeContent({
    required MindmapNodeData data,
    required TextStyle style,
    required int maxLines,
  }) {
    // Force the SAME strut height used by the editing TextField so the text
    // box height is identical in display and edit states — the text then
    // sits at exactly the same vertical center in both, at any zoom level.
    final strutStyle = StrutStyle(
      fontSize: style.fontSize,
      height: MindmapResolvedNodeStyle.lineHeight,
      fontWeight: style.fontWeight,
      leading: 0,
      forceStrutHeight: true,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MindmapNodeMetrics.maxNodeWidth;
        final textStyle = data.todoEnabled && data.todoDone
            ? style.copyWith(decoration: TextDecoration.lineThrough)
            : style;
        final text = data.text.isEmpty ? '...' : data.text;
        final hasLink = data.linkUrl != null && data.linkUrl!.isNotEmpty;
        final hasPrefix = data.todoEnabled || hasLink;
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: hasPrefix
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (data.todoEnabled) ...[
                        _TodoCheckbox(
                          checked: data.todoDone,
                          color: style.color ?? const Color(0xFF1F2937),
                          onTap: () =>
                              _actions?.toggleNodeTodoDone(widget.element.id),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (hasLink) ...[
                        _LinkButton(
                          color: style.color ?? const Color(0xFF1F2937),
                          onTap: () => _openLink(data.linkUrl),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          text,
                          overflow: TextOverflow.ellipsis,
                          maxLines: maxLines,
                          softWrap: true,
                          textAlign: TextAlign.center,
                          style: textStyle,
                          strutStyle: strutStyle,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    maxLines: maxLines,
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: textStyle,
                    strutStyle: strutStyle,
                  ),
          ),
        );
      },
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Icon(Icons.link, size: 16, color: color),
    );
  }
}

class _TodoCheckbox extends StatelessWidget {
  const _TodoCheckbox({
    required this.checked,
    required this.color,
    required this.onTap,
  });

  final bool checked;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: checked ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: checked
            ? const Icon(Icons.check, size: 12, color: Colors.white)
            : null,
      ),
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

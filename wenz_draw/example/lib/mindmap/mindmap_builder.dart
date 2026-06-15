import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_controller.dart';
import 'mindmap_data.dart';
import 'mindmap_theme.dart';
import 'mindmap_widget.dart';

/// WidgetElementBuilder for rendering mind maps on the canvas.
///
/// Registered with [WidgetElementRegistry] under 'mindmap'.
class MindmapBuilder extends WidgetElementBuilder {
  const MindmapBuilder();

  @override
  bool get useDefaultThumbnailFrame => false;

  @override
  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    return _buildForDetail(element, canvas);
  }

  @override
  Widget buildPreview(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    return _buildForDetail(element, canvas);
  }

  Widget _buildForDetail(
    CanvasWidgetElement element,
    CanvasWidgetBuildContext canvas,
  ) {
    return switch (canvas.renderDetail) {
      CanvasWidgetRenderDetail.color => _buildOutlinePreview(
        canvas,
        _readData(element),
      ),
      CanvasWidgetRenderDetail.colorWithText ||
      CanvasWidgetRenderDetail.thumbnail ||
      CanvasWidgetRenderDetail.full => _buildFullMindmap(
        element,
        canvas,
        _readData(element),
      ),
    };
  }

  Widget _buildFullMindmap(
    CanvasWidgetElement element,
    CanvasWidgetBuildContext canvas,
    MindmapData data,
  ) {
    return _MindmapElementView(element: element, canvas: canvas, data: data);
  }

  MindmapData _readData(CanvasWidgetElement element) {
    try {
      return element.widgetData.containsKey('root')
          ? MindmapData.fromWidgetData(element.widgetData)
          : MindmapData.createDefault();
    } catch (_) {
      return MindmapData.createDefault();
    }
  }

  Widget _buildOutlinePreview(
    CanvasWidgetBuildContext canvas,
    MindmapData data,
  ) {
    final style = _rootPreviewStyle(data, isSelected: canvas.selected);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.fillColor,
        borderRadius: BorderRadius.all(Radius.circular(style.borderRadius)),
        border: Border.all(
          color: canvas.selected ? const Color(0xFF2563EB) : style.borderColor,
          width: canvas.selected ? 2 : 1.5,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }

  MindmapResolvedNodeStyle _rootPreviewStyle(
    MindmapData data, {
    required bool isSelected,
  }) {
    final theme =
        MindmapThemes.byId(data.root.themeId ?? MindmapThemes.simpleFill.id) ??
        MindmapThemes.simpleFill;
    return MindmapThemeController().styleForTheme(
      theme,
      MindmapThemeNodeContext.fromNode(
        data.root,
        depth: 0,
        siblingIndex: 0,
        siblingCount: 1,
        isSelected: isSelected,
      ),
    );
  }
}

/// Stateful view that maintains the MindmapController for a canvas element.
///
/// Key design: the outer container does NOT intercept any gestures.
/// Each mind map node handles its own tap/double-tap/long-press.
/// The container only provides a visual selection border.
class _MindmapElementView extends StatefulWidget {
  const _MindmapElementView({
    required this.element,
    required this.canvas,
    required this.data,
  });

  final CanvasWidgetElement element;
  final CanvasWidgetBuildContext canvas;
  final MindmapData data;

  @override
  State<_MindmapElementView> createState() => _MindmapElementViewState();
}

class _MindmapElementViewState extends State<_MindmapElementView> {
  late MindmapController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MindmapController(data: widget.data);
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    // Sync back to canvas element's widgetData
    widget.canvas.updateProps(widget.element.id, _controller.toWidgetData());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Do NOT wrap in GestureDetector here.
    // The mind map nodes handle their own gestures internally.
    // We only add a visual selection border.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: widget.canvas.selected
            ? Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: MindmapWidget(controller: _controller),
    );
  }
}

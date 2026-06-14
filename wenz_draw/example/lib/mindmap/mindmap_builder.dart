import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_controller.dart';
import 'mindmap_data.dart';
import 'mindmap_widget.dart';

/// WidgetElementBuilder for rendering mind maps on the canvas.
///
/// Registered with [WidgetElementRegistry] under 'mindmap'.
class MindmapBuilder extends WidgetElementBuilder {
  const MindmapBuilder();

  @override
  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    if (canvas.renderDetail != CanvasWidgetRenderDetail.full) {
      return _buildPreview(canvas);
    }

    // Parse or create mind map data
    MindmapData data;
    try {
      data = element.widgetData.containsKey('root')
          ? MindmapData.fromWidgetData(element.widgetData)
          : MindmapData.createDefault();
    } catch (_) {
      data = MindmapData.createDefault();
    }

    return _MindmapElementView(
      element: element,
      canvas: canvas,
      data: data,
    );
  }

  Widget _buildPreview(CanvasWidgetBuildContext canvas) {
    const color = Color(0xFFE3F2FD);
    return switch (canvas.renderDetail) {
      CanvasWidgetRenderDetail.color => const ColoredBox(color: color),
      CanvasWidgetRenderDetail.colorWithText ||
      CanvasWidgetRenderDetail.thumbnail =>
        const DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          child: Center(
            child: Text(
              'Mind Map',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      CanvasWidgetRenderDetail.full => const ColoredBox(color: color),
    };
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
    widget.canvas.updateProps(
      widget.element.id,
      _controller.toWidgetData(),
    );
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
            ? Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4), width: 1.5)
            : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: MindmapWidget(controller: _controller),
    );
  }
}

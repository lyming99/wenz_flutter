import 'package:flutter/material.dart';

import 'infinite_canvas_controller.dart';

class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
    required this.controller,
    this.axis = Axis.horizontal,
  });

  final InfiniteCanvasController controller;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final children = [
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.remove),
            onPressed: controller.zoomOut,
          ),
          Text('${(controller.transform.scale * 100).round()}%'),
          IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.add),
            onPressed: controller.zoomIn,
          ),
          IconButton(
            tooltip: 'Reset view',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: controller.resetView,
          ),
        ];
        return axis == Axis.horizontal
            ? Row(mainAxisSize: MainAxisSize.min, children: children)
            : Column(mainAxisSize: MainAxisSize.min, children: children);
      },
    );
  }
}

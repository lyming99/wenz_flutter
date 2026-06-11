import 'package:flutter/material.dart';

import '../elements/canvas_element.dart';
import '../elements/element_registry.dart';
import '../elements/widget_element.dart';
import '../layers/canvas_layer.dart';
import '../rendering/grid_renderer.dart';
import '../rendering/selection_renderer.dart';
import '../rendering/viewport_culling.dart';
import 'infinite_canvas_config.dart';
import 'infinite_canvas_controller.dart';

class InfiniteCanvasPainter extends CustomPainter {
  InfiniteCanvasPainter({
    required this.controller,
    this.config = const InfiniteCanvasConfig(),
  }) : revision = controller.canvasController.state.revision;

  final InfiniteCanvasController controller;
  final InfiniteCanvasConfig config;
  final int revision;

  static const _gridRenderer = GridRenderer();
  static const _selectionRenderer = SelectionRenderer();

  @override
  void paint(Canvas canvas, Size size) {
    final transform = controller.transform;
    final canvasController = controller.canvasController;

    canvas.drawColor(config.backgroundColor, BlendMode.src);
    _gridRenderer.render(canvas, size, transform, config);

    canvas.save();
    canvas.translate(transform.offset.dx, transform.offset.dy);
    canvas.scale(transform.scale);

    final visibleRect = transform.visibleWorldRect(size);
    final visibleElements =
        ViewportCulling.visibleElements(canvasController.elements, visibleRect)
            .where(
              (element) =>
                  canvasController.isLayerVisible(element.layerId) &&
                  element is! CanvasWidgetElement,
            )
            .toList()
          ..sort((a, b) {
            final layerOrder = canvasController
                .layerIndexOf(a.layerId)
                .compareTo(canvasController.layerIndexOf(b.layerId));
            if (layerOrder != 0) {
              return layerOrder;
            }
            return a.zIndex.compareTo(b.zIndex);
          });

    final elementsByLayer = <String, List<CanvasElement>>{};
    final unknownLayerElements = <CanvasElement>[];
    for (final element in visibleElements) {
      if (canvasController.layerManager.layerById(element.layerId) == null) {
        unknownLayerElements.add(element);
      } else {
        (elementsByLayer[element.layerId] ??= <CanvasElement>[]).add(element);
      }
    }

    for (final layer in canvasController.layers) {
      if (!layer.isVisible) {
        continue;
      }
      _paintLayer(
        canvas,
        elementsByLayer[layer.id] ?? const <CanvasElement>[],
        layer,
      );
    }

    _paintLayer(canvas, unknownLayerElements, null);

    final preview = canvasController.previewElement;
    if (preview != null && preview is! CanvasWidgetElement) {
      ElementRendererRegistry.render(canvas, preview);
    }

    _selectionRenderer.render(canvas, canvasController, transform);
    canvas.restore();
  }

  void _paintLayer(
    Canvas canvas,
    Iterable<CanvasElement> elements,
    CanvasLayer? layer,
  ) {
    final opacity = (layer?.opacity ?? 1).clamp(0.0, 1.0).toDouble();
    final blendMode = layer?.blendMode ?? BlendMode.srcOver;
    final needsLayer = opacity < 1 || blendMode != BlendMode.srcOver;

    if (needsLayer) {
      canvas.saveLayer(
        null,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, opacity)
          ..blendMode = blendMode,
      );
    }

    for (final element in elements) {
      ElementRendererRegistry.render(canvas, element);
    }

    if (needsLayer) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant InfiniteCanvasPainter oldDelegate) {
    return oldDelegate.revision != revision ||
        oldDelegate.controller.transform != controller.transform ||
        oldDelegate.config != config;
  }
}

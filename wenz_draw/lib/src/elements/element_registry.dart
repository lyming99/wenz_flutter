import 'package:flutter/widgets.dart';

import 'arrow_element.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';
import 'ellipse_element.dart';
import 'image_element.dart';
import 'line_element.dart';
import 'path_element.dart';
import 'rect_element.dart';
import 'text_element.dart';

class ElementRendererRegistry {
  ElementRendererRegistry._();

  static final Map<String, ElementRenderer<CanvasElement>> _renderers = {};
  static bool _builtInsRegistered = false;

  static void register<T extends CanvasElement>(
    String type,
    ElementRenderer<T> renderer,
  ) {
    _renderers[type] = _RendererAdapter<T>(renderer);
  }

  static ElementRenderer<CanvasElement>? getRenderer(String type) {
    ensureBuiltInsRegistered();
    return _renderers[type];
  }

  static void render(Canvas canvas, CanvasElement element) {
    final renderer = getRenderer(element.type);
    renderer?.render(canvas, element);
  }

  static bool hitTest(
    CanvasElement element,
    Offset worldPoint, {
    double tolerance = 5,
  }) {
    final renderer = getRenderer(element.type);
    return renderer?.hitTest(element, worldPoint, tolerance) ??
        element.hitTest(worldPoint, tolerance: tolerance);
  }

  static void ensureBuiltInsRegistered() {
    if (_builtInsRegistered) {
      return;
    }
    _builtInsRegistered = true;
    register(PathElement.elementType, const PathElementRenderer());
    register(LineElement.elementType, const LineElementRenderer());
    register(RectElement.elementType, const RectElementRenderer());
    register(EllipseElement.elementType, const EllipseElementRenderer());
    register(ArrowElement.elementType, const ArrowElementRenderer());
    register(TextElement.elementType, const TextElementRenderer());
    register(ImageElement.elementType, const ImageElementRenderer());
  }
}

class _RendererAdapter<T extends CanvasElement>
    extends ElementRenderer<CanvasElement> {
  const _RendererAdapter(this.inner);

  final ElementRenderer<T> inner;

  @override
  void render(Canvas canvas, CanvasElement element) {
    if (element is T) {
      inner.render(canvas, element);
    }
  }

  @override
  bool hitTest(CanvasElement element, Offset worldPoint, double tolerance) {
    if (element is T) {
      return inner.hitTest(element, worldPoint, tolerance);
    }
    return false;
  }
}

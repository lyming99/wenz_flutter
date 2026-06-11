import 'package:flutter/widgets.dart';

import 'canvas_element.dart';

abstract class ElementRenderer<T extends CanvasElement> {
  const ElementRenderer();

  void render(Canvas canvas, T element);

  bool hitTest(T element, Offset worldPoint, double tolerance);
}

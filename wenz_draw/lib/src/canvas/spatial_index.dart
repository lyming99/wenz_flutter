import 'package:flutter/widgets.dart';

import '../elements/canvas_element.dart';
import '../utils/quad_tree.dart';

class SpatialIndex {
  const SpatialIndex({this.threshold = 200});

  final int threshold;

  Iterable<CanvasElement> query(
    Iterable<CanvasElement> elements,
    Rect visibleRect,
  ) {
    final elementList = elements.toList(growable: false);
    if (elementList.length < threshold) {
      return elementList.where(
        (element) => element.bounds.overlaps(visibleRect),
      );
    }

    final bounds = _boundsForElements(elementList).inflate(1);
    final tree = QuadTree<CanvasElement>(bounds: bounds);
    for (final element in elementList) {
      tree.insert(element.bounds, element);
    }
    return tree.query(visibleRect);
  }

  Rect _boundsForElements(List<CanvasElement> elements) {
    if (elements.isEmpty) {
      return Rect.zero;
    }
    var bounds = elements.first.bounds;
    for (final element in elements.skip(1)) {
      bounds = bounds.expandToInclude(element.bounds);
    }
    return bounds;
  }
}

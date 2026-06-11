import 'package:flutter/widgets.dart';

import '../elements/canvas_element.dart';
import '../utils/quad_tree.dart';

class SpatialIndex {
  SpatialIndex({this.threshold = 200});

  final int threshold;

  List<CanvasElement>? _cachedElements;
  QuadTree<CanvasElement>? _cachedTree;

  Iterable<CanvasElement> query(
    Iterable<CanvasElement> elements,
    Rect visibleRect,
  ) {
    final elementList = _asStableList(elements);
    if (elementList.length < threshold) {
      return elementList.where(
        (element) => element.visible && element.bounds.overlaps(visibleRect),
      );
    }

    return _treeFor(
      elementList,
    ).query(visibleRect).where((element) => element.visible);
  }

  Iterable<CanvasElement> queryPoint(
    Iterable<CanvasElement> elements,
    Offset worldPoint, {
    double tolerance = 5,
  }) {
    final queryRect = Rect.fromCircle(center: worldPoint, radius: tolerance);
    return query(elements, queryRect);
  }

  void invalidate() {
    _cachedElements = null;
    _cachedTree = null;
  }

  List<CanvasElement> _asStableList(Iterable<CanvasElement> elements) {
    if (elements is List<CanvasElement>) {
      return elements;
    }
    return elements.toList(growable: false);
  }

  QuadTree<CanvasElement> _treeFor(List<CanvasElement> elements) {
    final cachedTree = _cachedTree;
    if (identical(_cachedElements, elements) && cachedTree != null) {
      return cachedTree;
    }

    final bounds = _boundsForElements(elements).inflate(1);
    final tree = QuadTree<CanvasElement>(bounds: bounds);
    for (final element in elements) {
      if (element.visible) {
        tree.insert(element.bounds, element);
      }
    }

    _cachedElements = elements;
    _cachedTree = tree;
    return tree;
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

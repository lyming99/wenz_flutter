import 'package:flutter/widgets.dart';

import '../canvas/spatial_index.dart';
import '../elements/canvas_element.dart';

class ViewportCulling {
  const ViewportCulling._();

  static const _spatialIndex = SpatialIndex();

  static Iterable<CanvasElement> visibleElements(
    Iterable<CanvasElement> elements,
    Rect visibleWorldRect,
  ) {
    return _spatialIndex.query(
      elements.where((element) => element.visible),
      visibleWorldRect,
    );
  }
}

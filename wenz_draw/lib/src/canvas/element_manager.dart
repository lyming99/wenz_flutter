import 'package:flutter/widgets.dart';

import '../elements/canvas_element.dart';

typedef CanvasElementLayerRank = int Function(CanvasElement element);

class ElementManager {
  const ElementManager();

  List<CanvasElement> add(List<CanvasElement> elements, CanvasElement element) {
    return List<CanvasElement>.unmodifiable([...elements, element]);
  }

  List<CanvasElement> remove(List<CanvasElement> elements, String id) {
    return List<CanvasElement>.unmodifiable(
      elements.where((element) => element.id != id),
    );
  }

  List<CanvasElement> update(
    List<CanvasElement> elements,
    String id,
    CanvasElement updated,
  ) {
    return List<CanvasElement>.unmodifiable(
      elements.map((element) => element.id == id ? updated : element),
    );
  }

  CanvasElement? hitTest(
    Iterable<CanvasElement> elements,
    Offset worldPoint, {
    double tolerance = 5,
    CanvasElementLayerRank? layerRank,
  }) {
    final elementList = elements.toList(growable: false);
    final ordered =
        [
          for (var i = 0; i < elementList.length; i++)
            MapEntry(i, elementList[i]),
        ]..sort((a, b) {
          final aLayerRank = layerRank?.call(a.value) ?? 0;
          final bLayerRank = layerRank?.call(b.value) ?? 0;
          final layerOrder = aLayerRank.compareTo(bLayerRank);
          if (layerOrder != 0) {
            return layerOrder;
          }

          final zOrder = a.value.zIndex.compareTo(b.value.zIndex);
          if (zOrder != 0) {
            return zOrder;
          }
          return a.key.compareTo(b.key);
        });

    for (final entry in ordered.reversed) {
      final element = entry.value;
      if (!element.visible) {
        continue;
      }
      if (element.hitTest(worldPoint, tolerance: tolerance)) {
        return element;
      }
    }
    return null;
  }
}

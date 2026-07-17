import '../elements/arrow_element.dart';
import '../elements/canvas_element.dart';
import '../elements/line_element.dart';
import '../elements/text_element.dart';
import '../elements/widget_element.dart';

class AutoLayeringPolicy {
  const AutoLayeringPolicy({
    this.mode = AutoLayeringMode.activeLayer,
    this.overlapAware = false,
    this.assignZIndex = false,
  });

  const AutoLayeringPolicy.manual()
    : mode = AutoLayeringMode.manual,
      overlapAware = false,
      assignZIndex = false;

  const AutoLayeringPolicy.activeLayer({
    this.overlapAware = false,
    this.assignZIndex = false,
  }) : mode = AutoLayeringMode.activeLayer;

  const AutoLayeringPolicy.typeLane({
    this.overlapAware = false,
    this.assignZIndex = true,
  }) : mode = AutoLayeringMode.typeLane;

  final AutoLayeringMode mode;
  final bool overlapAware;
  final bool assignZIndex;
}

enum AutoLayeringMode { manual, activeLayer, typeLane }

class AutoLayeringResolver {
  const AutoLayeringResolver();

  CanvasElement resolve({
    required CanvasElement element,
    required Iterable<CanvasElement> existingElements,
    required String activeLayerId,
    required bool Function(String layerId) layerExists,
    required AutoLayeringPolicy policy,
    bool bringToFront = false,
  }) {
    var prepared = element;
    final shouldUseActiveLayer =
        policy.mode == AutoLayeringMode.activeLayer ||
        policy.mode == AutoLayeringMode.typeLane ||
        !layerExists(prepared.layerId);

    if (shouldUseActiveLayer) {
      prepared = prepared.copyWith(layerId: activeLayerId);
    }

    if (bringToFront || policy.assignZIndex || policy.overlapAware) {
      prepared = prepared.copyWith(
        zIndex: nextZIndex(
          prepared,
          existingElements.where((e) => e.layerId == prepared.layerId),
          policy,
        ),
      );
    }

    return prepared;
  }

  int nextZIndex(
    CanvasElement element,
    Iterable<CanvasElement> sameLayerElements,
    AutoLayeringPolicy policy,
  ) {
    final laneBase = policy.mode == AutoLayeringMode.typeLane
        ? laneFor(element) * 100000
        : 0;
    var maxZ = laneBase;

    for (final existing in sameLayerElements) {
      final sameLane =
          policy.mode != AutoLayeringMode.typeLane ||
          laneFor(existing) == laneFor(element);
      final overlaps =
          !policy.overlapAware || existing.bounds.overlaps(element.bounds);
      if (sameLane && overlaps && existing.zIndex >= maxZ) {
        maxZ = existing.zIndex;
      }
    }

    return maxZ + 1;
  }

  int laneFor(CanvasElement element) {
    if (element is LineElement || element is ArrowElement) {
      return 30;
    }
    if (element is CanvasWidgetElement) {
      return 20;
    }
    if (element is TextElement) {
      return 40;
    }
    return 10;
  }
}

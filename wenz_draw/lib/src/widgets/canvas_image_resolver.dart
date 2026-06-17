import 'dart:async';
import 'dart:ui' as ui;

import '../canvas/canvas_controller.dart';
import '../elements/image_element.dart';

/// Resolves the raster data for every [ImageElement] that lacks an in-memory
/// [ui.Image] (typically those freshly deserialized from JSON).
///
/// It listens to its [CanvasController]; whenever the element list settles, it
/// walks the image elements, asks the controller's [ImageLoaderRegistry] to
/// decode each one, and writes the result back into the element via
/// [CanvasController.applyElementUpdated] (`record: false`, so the undo stack
/// is not polluted). Writing the image back notifies listeners, which repaints
/// the canvas — no renderer changes are needed.
///
/// Create one per [InfiniteCanvasWidget] and dispose it when the widget is
/// torn down. Concurrent decodes for the same element are coalesced.
class CanvasImageResolver {
  CanvasImageResolver(this._controller) {
    _controller.addListener(_onChanged);
  }

  final CanvasController _controller;

  /// Element ids whose image is currently being decoded. Prevents a second
  /// listener callback from kicking off a duplicate decode before the first
  /// finishes.
  final Set<String> _pending = {};

  void dispose() {
    _controller.removeListener(_onChanged);
    _pending.clear();
  }

  void _onChanged() {
    if (_pending.length > 64) {
      // Back-pressure guard: if many decodes are in flight, wait for some to
      // drain before scheduling more. This bound is generous; a normal canvas
      // has at most a few unresolved images at a time.
      return;
    }
    for (final element in _controller.elements) {
      if (element is! ImageElement) continue;
      if (element.image != null) continue;
      if (!element.visible) continue;
      if (_pending.contains(element.id)) continue;
      _resolve(element);
    }
  }

  Future<void> _resolve(ImageElement element) async {
    _pending.add(element.id);
    try {
      final image = await _controller.imageLoaders.load(element.toImageSource());
      if (image == null) return;
      if (!_isCurrentElementStillRelevant(element.id, image)) {
        image.dispose();
        return;
      }
      _controller.applyElementUpdated(element.id, element.copyWith(image: image));
    } finally {
      _pending.remove(element.id);
    }
  }

  /// Guards against writing a decoded image into an element that has since been
  /// removed or already replaced with a fresher image.
  bool _isCurrentElementStillRelevant(String id, ui.Image decoded) {
    final current = _controller.elementById(id);
    if (current is! ImageElement) return false;
    if (current.image != null) return false;
    return true;
  }
}

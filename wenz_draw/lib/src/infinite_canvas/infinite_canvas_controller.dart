import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../canvas/canvas_controller.dart';
import '../serialization/canvas_document.dart';
import 'canvas_transform.dart';

class InfiniteCanvasController extends ChangeNotifier {
  InfiniteCanvasController({
    CanvasController? canvasController,
    CanvasTransform transform = CanvasTransform.identity,
    this.minScale = CanvasTransform.minScale,
    this.maxScale = CanvasTransform.maxScale,
  }) : canvasController = canvasController ?? CanvasController(),
       _transform = transform;

  final CanvasController canvasController;

  /// Minimum zoom scale. Defaults to [CanvasTransform.minScale]; override via
  /// the constructor to match a host's [InfiniteCanvasConfig.minScale].
  final double minScale;

  /// Maximum zoom scale. Defaults to [CanvasTransform.maxScale]; override via
  /// the constructor to match a host's [InfiniteCanvasConfig.maxScale].
  final double maxScale;

  CanvasTransform _transform;
  Size _viewportSize = Size.zero;

  CanvasTransform get transform => _transform;
  Size get viewportSize => _viewportSize;

  void setViewportSize(Size size) {
    if (_viewportSize == size) {
      return;
    }
    _viewportSize = size;
    notifyListeners();
  }

  void pan(Offset delta) {
    if (delta == Offset.zero) {
      return;
    }
    _setTransform(_transform.pan(delta));
  }

  void zoomTo(double newScale, {Offset? focalPoint}) {
    final focus = focalPoint ?? _viewportCenter;
    _setTransform(
      _transform.zoomTo(
        newScale,
        focus,
        minScale: minScale,
        maxScale: maxScale,
      ),
    );
  }

  void zoomBy(double factor, {Offset? focalPoint}) {
    final focus = focalPoint ?? _viewportCenter;
    _setTransform(
      _transform.zoomBy(
        factor,
        focus,
        minScale: minScale,
        maxScale: maxScale,
      ),
    );
  }

  void zoomIn({Offset? focalPoint}) {
    zoomBy(1.2, focalPoint: focalPoint);
  }

  void zoomOut({Offset? focalPoint}) {
    zoomBy(1 / 1.2, focalPoint: focalPoint);
  }

  void resetView() {
    _setTransform(CanvasTransform.identity);
  }

  /// The current view as a serializable [DocumentViewport].
  ///
  /// Captures the zoom scale and the world-space point currently centered in
  /// the viewport, so a document can be saved and later restored to the exact
  /// same view. Returns an empty viewport when the viewport size is unknown
  /// (e.g. before the widget has been laid out).
  DocumentViewport get currentViewport {
    if (_viewportSize.isEmpty) {
      return const DocumentViewport();
    }
    final worldCenter = screenToWorld(_viewportCenter);
    return DocumentViewport(
      scale: _transform.scale,
      centerX: worldCenter.dx,
      centerY: worldCenter.dy,
    );
  }

  /// Restores a previously saved view ([DocumentViewport]).
  ///
  /// Sets the zoom scale and recenters on the stored world point. No-op when
  /// the viewport is empty (the widget has not been laid out yet) or the given
  /// viewport carries no data. Call after [loadDocument] once the canvas widget
  /// has a size; otherwise defer to the next frame.
  void applyViewport(DocumentViewport viewport) {
    if (_viewportSize.isEmpty || viewport.isEmpty) {
      return;
    }
    final scale = viewport.scale;
    if (scale == null) {
      return;
    }
    final center = Offset(
      viewport.centerX ?? 0,
      viewport.centerY ?? 0,
    );
    final nextOffset = _viewportCenter - center * scale;
    _setTransform(CanvasTransform(scale: scale, offset: nextOffset));
  }

  void centerOnWorld(Offset worldPoint) {
    if (_viewportSize.isEmpty) {
      return;
    }
    final nextOffset = _viewportCenter - worldPoint * _transform.scale;
    _setTransform(_transform.copyWith(offset: nextOffset));
  }

  void zoomToFit(Rect contentBounds, {double padding = 48}) {
    if (contentBounds.isEmpty || _viewportSize.isEmpty) {
      return;
    }

    final availableWidth = (_viewportSize.width - padding * 2).clamp(
      1.0,
      double.infinity,
    );
    final availableHeight = (_viewportSize.height - padding * 2).clamp(
      1.0,
      double.infinity,
    );
    final widthScale = availableWidth / contentBounds.width;
    final heightScale = availableHeight / contentBounds.height;
    final scale = math
        .min(widthScale, heightScale)
        .clamp(minScale, maxScale)
        .toDouble();
    final viewportCenter = _viewportCenter;
    final contentCenter = contentBounds.center;
    final nextOffset = viewportCenter - contentCenter * scale;
    _setTransform(CanvasTransform(scale: scale, offset: nextOffset));
  }

  Offset screenToWorld(Offset screenPoint) {
    return _transform.screenToWorld(screenPoint);
  }

  Offset worldToScreen(Offset worldPoint) {
    return _transform.worldToScreen(worldPoint);
  }

  Rect visibleWorldRect() {
    return _transform.visibleWorldRect(_viewportSize);
  }

  Offset get _viewportCenter {
    if (_viewportSize.isEmpty) {
      return Offset.zero;
    }
    return Offset(_viewportSize.width / 2, _viewportSize.height / 2);
  }

  void _setTransform(CanvasTransform transform) {
    if (transform == _transform) {
      return;
    }
    _transform = transform;
    notifyListeners();
  }
}

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../canvas/canvas_controller.dart';
import 'canvas_transform.dart';

class InfiniteCanvasController extends ChangeNotifier {
  InfiniteCanvasController({
    CanvasController? canvasController,
    CanvasTransform transform = CanvasTransform.identity,
  }) : canvasController = canvasController ?? CanvasController(),
       _transform = transform;

  final CanvasController canvasController;

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
        minScale: CanvasTransform.minScale,
        maxScale: CanvasTransform.maxScale,
      ),
    );
  }

  void zoomBy(double factor, {Offset? focalPoint}) {
    final focus = focalPoint ?? _viewportCenter;
    _setTransform(
      _transform.zoomBy(
        factor,
        focus,
        minScale: CanvasTransform.minScale,
        maxScale: CanvasTransform.maxScale,
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
        .clamp(CanvasTransform.minScale, CanvasTransform.maxScale)
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

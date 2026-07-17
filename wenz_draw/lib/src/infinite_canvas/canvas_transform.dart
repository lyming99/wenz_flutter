import 'package:flutter/widgets.dart';

@immutable
class CanvasTransform {
  const CanvasTransform({this.scale = 1.0, this.offset = Offset.zero});

  static const identity = CanvasTransform();

  static const minScale = 0.1;
  static const maxScale = 10.0;

  final double scale;
  final Offset offset;

  Offset screenToWorld(Offset screenPoint) {
    return (screenPoint - offset) / scale;
  }

  Offset worldToScreen(Offset worldPoint) {
    return worldPoint * scale + offset;
  }

  Rect visibleWorldRect(Size viewportSize) {
    return Rect.fromLTWH(
      -offset.dx / scale,
      -offset.dy / scale,
      viewportSize.width / scale,
      viewportSize.height / scale,
    );
  }

  CanvasTransform pan(Offset delta) {
    return copyWith(offset: offset + delta);
  }

  CanvasTransform zoomTo(
    double newScale,
    Offset focalPoint, {
    double minScale = CanvasTransform.minScale,
    double maxScale = CanvasTransform.maxScale,
  }) {
    final clampedScale = newScale.clamp(minScale, maxScale).toDouble();
    final worldPoint = screenToWorld(focalPoint);
    final nextOffset = Offset(
      focalPoint.dx - worldPoint.dx * clampedScale,
      focalPoint.dy - worldPoint.dy * clampedScale,
    );

    return CanvasTransform(scale: clampedScale, offset: nextOffset);
  }

  CanvasTransform zoomBy(
    double factor,
    Offset focalPoint, {
    double minScale = CanvasTransform.minScale,
    double maxScale = CanvasTransform.maxScale,
  }) {
    return zoomTo(
      scale * factor,
      focalPoint,
      minScale: minScale,
      maxScale: maxScale,
    );
  }

  CanvasTransform reset() {
    return identity;
  }

  Matrix4 toMatrix4() {
    return Matrix4.identity()
      ..translateByDouble(offset.dx, offset.dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  CanvasTransform copyWith({double? scale, Offset? offset}) {
    return CanvasTransform(
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CanvasTransform &&
        other.scale == scale &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(scale, offset);

  @override
  String toString() {
    return 'CanvasTransform(scale: $scale, offset: $offset)';
  }
}

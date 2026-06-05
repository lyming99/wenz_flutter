import 'package:flutter/material.dart';

/// 不可变的 2D 仿射变换（平移 + 缩放）。
///
/// 用于无限画布的视图变换，支持 Screen ↔ World 坐标互转。
/// 所有修改操作返回新实例，保持不可变性。
class CanvasTransform {
  /// 缩放比例，默认 1.0。
  final double scale;

  /// 画布原点在屏幕上的位置（平移偏移）。
  final Offset offset;

  /// 最小缩放比例。
  static const double minScale = 0.1;

  /// 最大缩放比例。
  static const double maxScale = 10.0;

  /// 恒等变换（无缩放、无平移）。
  static const identity = CanvasTransform();

  const CanvasTransform({
    this.scale = 1.0,
    this.offset = Offset.zero,
  });

  // ─── 坐标转换 ───────────────────────────────────────────

  /// 屏幕坐标 → 世界坐标
  Offset screenToWorld(Offset screenPoint) {
    return Offset(
      (screenPoint.dx - offset.dx) / scale,
      (screenPoint.dy - offset.dy) / scale,
    );
  }

  /// 世界坐标 → 屏幕坐标
  Offset worldToScreen(Offset worldPoint) {
    return Offset(
      worldPoint.dx * scale + offset.dx,
      worldPoint.dy * scale + offset.dy,
    );
  }

  /// 视口在世界坐标系中的可见矩形。
  ///
  /// [viewportSize] 为屏幕视口的物理尺寸。
  Rect visibleWorldRect(Size viewportSize) {
    return Rect.fromLTWH(
      -offset.dx / scale,
      -offset.dy / scale,
      viewportSize.width / scale,
      viewportSize.height / scale,
    );
  }

  // ─── 变换操作（返回新实例） ────────────────────────────────

  /// 平移画布。
  CanvasTransform pan(Offset delta) {
    return copyWith(offset: offset + delta);
  }

  /// 以 [focalPoint]（屏幕坐标）为焦点缩放到 [newScale]。
  ///
  /// 算法：缩放前后保持焦点对应的世界坐标不变。
  CanvasTransform zoomTo(double newScale, Offset focalPoint) {
    newScale = newScale.clamp(minScale, maxScale);
    // 缩放前焦点对应的世界坐标
    final worldPoint = screenToWorld(focalPoint);
    // 缩放后保持该世界坐标点仍在屏幕同一位置
    final newOffset = Offset(
      focalPoint.dx - worldPoint.dx * newScale,
      focalPoint.dy - worldPoint.dy * newScale,
    );
    return CanvasTransform(scale: newScale, offset: newOffset);
  }

  /// 按比例缩放（相对于当前 scale）。
  CanvasTransform zoomBy(double factor, Offset focalPoint) {
    return zoomTo(scale * factor, focalPoint);
  }

  /// 放大一步（×1.2）。
  CanvasTransform zoomIn({Offset? focalPoint}) {
    final focal = focalPoint ?? offset;
    return zoomTo(scale * 1.2, focal);
  }

  /// 缩小一步（÷1.2）。
  CanvasTransform zoomOut({Offset? focalPoint}) {
    final focal = focalPoint ?? offset;
    return zoomTo(scale / 1.2, focal);
  }

  /// 重置为恒等变换。
  CanvasTransform reset() => const CanvasTransform();

  /// 缩放至指定内容区域刚好适配视口。
  ///
  /// [contentBounds] 为世界坐标系中内容的包围盒。
  /// [viewportSize] 为屏幕视口尺寸。
  /// [padding] 为边距比例，默认 0.1（10%）。
  CanvasTransform zoomToFit(
    Rect contentBounds,
    Size viewportSize, {
    double padding = 0.1,
  }) {
    if (contentBounds.isEmpty || viewportSize.isEmpty) return this;

    final double contentWidth = contentBounds.width;
    final double contentHeight = contentBounds.height;
    if (contentWidth <= 0 || contentHeight <= 0) return this;

    final double effectiveWidth = viewportSize.width * (1 - padding * 2);
    final double effectiveHeight = viewportSize.height * (1 - padding * 2);

    final double newScale = (effectiveWidth / contentWidth)
        .clamp(0.0, effectiveHeight / contentHeight)
        .clamp(minScale, maxScale);

    // 内容中心在世界坐标中的位置
    final double contentCenterX =
        contentBounds.left + contentBounds.width / 2;
    final double contentCenterY =
        contentBounds.top + contentBounds.height / 2;

    // 将内容中心映射到屏幕中心
    final double screenCenterX = viewportSize.width / 2;
    final double screenCenterY = viewportSize.height / 2;

    final newOffset = Offset(
      screenCenterX - contentCenterX * newScale,
      screenCenterY - contentCenterY * newScale,
    );

    return CanvasTransform(scale: newScale, offset: newOffset);
  }

  // ─── 工具方法 ─────────────────────────────────────────────

  /// 转换为 Matrix4（可用于 Transform widget 等）。
  Matrix4 toMatrix4() {
    return Matrix4.identity()
      ..setEntry(0, 3, offset.dx)
      ..setEntry(1, 3, offset.dy)
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale);
  }

  /// 复制并修改部分字段。
  CanvasTransform copyWith({
    double? scale,
    Offset? offset,
  }) {
    return CanvasTransform(
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CanvasTransform &&
        other.scale == scale &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(scale, offset);

  @override
  String toString() => 'CanvasTransform(scale: $scale, offset: $offset)';
}

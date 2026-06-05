import 'package:flutter/material.dart';

/// 网格类型
enum GridType {
  /// 点阵网格
  dots,

  /// 线条网格
  lines,
}

/// 自适应网格渲染器。
///
/// 根据当前缩放级别自动调整网格密度，只绘制视口内可见的网格元素。
class GridRenderer {
  /// 基础网格间距（世界坐标系）
  static const double baseGridSize = 50.0;

  /// 网格颜色
  final Color color;

  /// 网格类型
  final GridType gridType;

  /// 点阵半径（仅 GridType.dots 时有效）
  final double dotRadius;

  /// 线条宽度（仅 GridType.lines 时有效）
  final double strokeWidth;

  const GridRenderer({
    this.color = const Color(0xFFE0E0E0),
    this.gridType = GridType.dots,
    this.dotRadius = 1.5,
    this.strokeWidth = 0.5,
  });

  /// 根据缩放级别计算自适应的网格间距。
  ///
  /// 缩放越小（看越远），网格越稀疏；缩放越大（看越近），网格越密。
  double getGridSize(double scale) {
    if (scale < 0.25) return baseGridSize * 8;
    if (scale < 0.5) return baseGridSize * 4;
    if (scale < 1.0) return baseGridSize * 2;
    if (scale < 2.0) return baseGridSize;
    if (scale < 4.0) return baseGridSize / 2;
    return baseGridSize / 4;
  }

  /// 绘制网格。
  ///
  /// [canvas] 画布（已处于屏幕坐标系）。
  /// [size] 视口尺寸。
  /// [offset] 当前平移偏移（屏幕坐标系）。
  /// [scale] 当前缩放比例。
  void paint(Canvas canvas, Size size, Offset offset, double scale) {
    if (scale <= 0) return;

    final gridSize = getGridSize(scale);
    final scaledGridSize = gridSize * scale;

    // 避免网格过密导致性能问题
    if (scaledGridSize < 8.0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = gridType == GridType.dots
          ? PaintingStyle.fill
          : PaintingStyle.stroke;

    // 计算视口内可见网格的起止位置
    final double startX = offset.dx % scaledGridSize;
    final double startY = offset.dy % scaledGridSize;

    switch (gridType) {
      case GridType.dots:
        _drawDots(canvas, size, startX, startY, scaledGridSize, paint);
      case GridType.lines:
        _drawLines(canvas, size, startX, startY, scaledGridSize, paint);
    }
  }

  /// 绘制点阵网格
  void _drawDots(
    Canvas canvas,
    Size size,
    double startX,
    double startY,
    double scaledGridSize,
    Paint paint,
  ) {
    for (double x = startX; x < size.width; x += scaledGridSize) {
      for (double y = startY; y < size.height; y += scaledGridSize) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  /// 绘制线条网格
  void _drawLines(
    Canvas canvas,
    Size size,
    double startX,
    double startY,
    double scaledGridSize,
    Paint paint,
  ) {
    // 竖线
    for (double x = startX; x < size.width; x += scaledGridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // 横线
    for (double y = startY; y < size.height; y += scaledGridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
}

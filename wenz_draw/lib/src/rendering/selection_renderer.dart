import 'dart:ui' show Offset, Rect;

import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';

/// 选中装饰渲染器。
///
/// 绘制选中元素的边框和控制手柄。
class SelectionRenderer {
  /// 选中边框颜色
  static const Color borderColor = Color(0xFF2196F3);

  /// 手柄颜色
  static const Color handleColor = Color(0xFFFFFFFF);

  /// 手柄边框颜色
  static const Color handleBorderColor = Color(0xFF2196F3);

  /// 手柄大小（世界坐标）
  static const double handleSize = 8.0;

  /// 手柄边框宽度（世界坐标）
  static const double handleStrokeWidth = 2.0;

  /// 选中边框宽度（世界坐标）
  static const double borderStrokeWidth = 1.5;

  /// 绘制选中元素的装饰（边框 + 手柄）。
  ///
  /// [canvas] 已应用视图变换的画布。
  /// [controller] 画布控制器，用于获取选中元素信息。
  /// [scale] 当前缩放比例（用于调整线宽）。
  static void paint(
    Canvas canvas,
    CanvasController controller,
    double scale,
  ) {
    final selectedElements = controller.selectedElements;
    if (selectedElements.isEmpty) return;

    // 计算选中元素的统一包围盒
    final bounds = controller.selectionBounds;
    if (bounds == null) return;

    final inverseScale = 1.0 / scale;

    // 绘制每个选中元素的边框
    for (final element in selectedElements) {
      final elemBounds = element.bounds;
      final borderPaint = Paint()
        ..color = borderColor
        ..strokeWidth = borderStrokeWidth * inverseScale
        ..style = PaintingStyle.stroke;

      canvas.drawRect(elemBounds, borderPaint);
    }

    // 绘制统一包围盒的手柄（仅当有选中元素时）
    _drawHandles(canvas, bounds, inverseScale);
  }

  /// 绘制变换控制手柄。
  static void _drawHandles(Canvas canvas, Rect bounds, double inverseScale) {
    final handleHalf = (handleSize * inverseScale) / 2;
    final handleStroke = handleStrokeWidth * inverseScale;

    final fillPaint = Paint()
      ..color = handleColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = handleBorderColor
      ..strokeWidth = handleStroke
      ..style = PaintingStyle.stroke;

    // 8 个手柄位置：四角 + 四边中点
    final positions = [
      Offset(bounds.left, bounds.top), // 左上
      Offset(bounds.right, bounds.top), // 右上
      Offset(bounds.left, bounds.bottom), // 左下
      Offset(bounds.right, bounds.bottom), // 右下
      Offset(bounds.left + bounds.width / 2, bounds.top), // 上中
      Offset(bounds.left + bounds.width / 2, bounds.bottom), // 下中
      Offset(bounds.left, bounds.top + bounds.height / 2), // 左中
      Offset(bounds.right, bounds.top + bounds.height / 2), // 右中
    ];

    for (final pos in positions) {
      final handleRect = Rect.fromCenter(
        center: pos,
        width: handleHalf * 2,
        height: handleHalf * 2,
      );
      canvas.drawRect(handleRect, fillPaint);
      canvas.drawRect(handleRect, strokePaint);
    }
  }

  /// 判断点击位置是否在手柄上。
  ///
  /// 返回手柄索引（0-7），-1 表示不在任何手柄上。
  /// 手柄顺序：左上、右上、左下、右下、上中、下中、左中、右中。
  static int hitTestHandle(
    Offset worldPoint,
    Rect bounds,
    double scale,
    double tolerance,
  ) {
    final handleHalf = (handleSize / scale) / 2 + tolerance;

    final positions = [
      Offset(bounds.left, bounds.top),
      Offset(bounds.right, bounds.top),
      Offset(bounds.left, bounds.bottom),
      Offset(bounds.right, bounds.bottom),
      Offset(bounds.left + bounds.width / 2, bounds.top),
      Offset(bounds.left + bounds.width / 2, bounds.bottom),
      Offset(bounds.left, bounds.top + bounds.height / 2),
      Offset(bounds.right, bounds.top + bounds.height / 2),
    ];

    for (int i = 0; i < positions.length; i++) {
      final dx = (worldPoint.dx - positions[i].dx).abs();
      final dy = (worldPoint.dy - positions[i].dy).abs();
      if (dx <= handleHalf && dy <= handleHalf) {
        return i;
      }
    }
    return -1;
  }
}

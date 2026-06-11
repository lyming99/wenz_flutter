import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../infinite_canvas/canvas_transform.dart';
import '../infinite_canvas/infinite_canvas_config.dart';

class GridRenderer {
  const GridRenderer();

  void render(
    Canvas canvas,
    Size size,
    CanvasTransform transform,
    InfiniteCanvasConfig config,
  ) {
    if (!config.showGrid || config.gridType == GridType.none) {
      return;
    }

    final visibleRect = transform.visibleWorldRect(size);
    final gridSize = _gridSize(transform.scale, config.gridBaseSize);
    final minorPaint = Paint()
      ..color = config.gridColor
      ..strokeWidth = 1 / transform.scale;
    final majorPaint = Paint()
      ..color = config.majorGridColor
      ..strokeWidth = 1.2 / transform.scale;

    canvas.save();
    canvas.translate(transform.offset.dx, transform.offset.dy);
    canvas.scale(transform.scale);

    switch (config.gridType) {
      case GridType.lines:
        _drawLineGrid(canvas, visibleRect, gridSize, minorPaint, majorPaint);
      case GridType.dots:
        _drawDotGrid(canvas, visibleRect, gridSize, minorPaint, majorPaint);
      case GridType.none:
        break;
    }

    canvas.restore();
  }

  double _gridSize(double scale, double base) {
    if (scale < 0.25) return base * 8;
    if (scale < 0.5) return base * 4;
    if (scale < 1.0) return base * 2;
    if (scale < 2.0) return base;
    if (scale < 4.0) return base / 2;
    return base / 4;
  }

  void _drawLineGrid(
    Canvas canvas,
    Rect visibleRect,
    double gridSize,
    Paint minorPaint,
    Paint majorPaint,
  ) {
    final startX = (visibleRect.left / gridSize).floor() * gridSize;
    final endX = (visibleRect.right / gridSize).ceil() * gridSize;
    final startY = (visibleRect.top / gridSize).floor() * gridSize;
    final endY = (visibleRect.bottom / gridSize).ceil() * gridSize;

    for (var x = startX; x <= endX; x += gridSize) {
      final paint = _isMajorLine(x, gridSize) ? majorPaint : minorPaint;
      canvas.drawLine(Offset(x, startY), Offset(x, endY), paint);
    }

    for (var y = startY; y <= endY; y += gridSize) {
      final paint = _isMajorLine(y, gridSize) ? majorPaint : minorPaint;
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
    }
  }

  void _drawDotGrid(
    Canvas canvas,
    Rect visibleRect,
    double gridSize,
    Paint minorPaint,
    Paint majorPaint,
  ) {
    final startX = (visibleRect.left / gridSize).floor() * gridSize;
    final endX = (visibleRect.right / gridSize).ceil() * gridSize;
    final startY = (visibleRect.top / gridSize).floor() * gridSize;
    final endY = (visibleRect.bottom / gridSize).ceil() * gridSize;
    final radius = math.max(1.2 * minorPaint.strokeWidth, 0.5);

    for (var x = startX; x <= endX; x += gridSize) {
      for (var y = startY; y <= endY; y += gridSize) {
        final major = _isMajorLine(x, gridSize) && _isMajorLine(y, gridSize);
        final paint = major ? majorPaint : minorPaint;
        canvas.drawCircle(Offset(x, y), major ? radius * 1.35 : radius, paint);
      }
    }
  }

  bool _isMajorLine(double value, double gridSize) {
    final index = (value / gridSize).round();
    return index % 4 == 0;
  }
}

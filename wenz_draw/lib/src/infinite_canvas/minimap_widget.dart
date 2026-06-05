import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/element_registry.dart';
import 'infinite_canvas_controller.dart';
import 'canvas_transform.dart';

/// 小地图 Widget。
///
/// 显示画布全局缩略图，当前视口位置用蓝色矩形标识。
/// 支持点击/拖拽快速导航到指定位置。
class MinimapWidget extends StatelessWidget {
  final InfiniteCanvasController controller;
  final Size size;
  final Color borderColor;
  final Color viewportColor;
  final Color backgroundColor;

  const MinimapWidget({
    super.key,
    required this.controller,
    this.size = const Size(160, 120),
    this.borderColor = const Color(0xFFCCCCCC),
    this.viewportColor = const Color(0x402196F3),
    this.backgroundColor = const Color(0xFFF5F5F5),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: GestureDetector(
            onTapDown: _handleTap,
            onPanUpdate: _handlePan,
            child: CustomPaint(
              size: size,
              painter: _MinimapPainter(
                controller: controller,
                viewportColor: viewportColor,
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(TapDownDetails details) {
    _navigateToPoint(details.localPosition);
  }

  void _handlePan(DragUpdateDetails details) {
    _navigateToPoint(details.localPosition);
  }

  void _navigateToPoint(Offset localPoint) {
    final contentBounds = _getContentBounds();
    if (contentBounds == null) return;

    final mapping = _getContentMapping(contentBounds);
    if (mapping == null) return;

    // 小地图坐标 → 世界坐标
    final worldX = (localPoint.dx - mapping.offsetX) / mapping.scale;
    final worldY = (localPoint.dy - mapping.offsetY) / mapping.scale;

    // 将该世界坐标点移到视口中心
    final vp = controller.viewportSize;
    if (vp == null) return;

    final newOffset = Offset(
      vp.width / 2 - worldX * controller.transform.scale,
      vp.height / 2 - worldY * controller.transform.scale,
    );

    controller.setTransform(CanvasTransform(
      scale: controller.transform.scale,
      offset: newOffset,
    ));
  }

  /// 获取所有元素的内容包围盒。
  Rect? _getContentBounds() {
    final elements = controller.canvasController.elements;
    if (elements.isEmpty) return null;

    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;

    for (final element in elements) {
      final bounds = element.bounds;
      if (bounds.left < left) left = bounds.left;
      if (bounds.top < top) top = bounds.top;
      if (bounds.right > right) right = bounds.right;
      if (bounds.bottom > bottom) bottom = bounds.bottom;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// 计算内容到小地图的映射关系。
  _MinimapMapping? _getContentMapping(Rect contentBounds) {
    final padding = 8.0;
    final availableWidth = size.width - padding * 2;
    final availableHeight = size.height - padding * 2;

    final contentWidth = contentBounds.width;
    final contentHeight = contentBounds.height;
    if (contentWidth <= 0 || contentHeight <= 0) return null;

    final scaleX = availableWidth / contentWidth;
    final scaleY = availableHeight / contentHeight;
    final scale = math.min(scaleX, scaleY);

    final mappedWidth = contentWidth * scale;
    final mappedHeight = contentHeight * scale;
    final offsetX = (size.width - mappedWidth) / 2;
    final offsetY = (size.height - mappedHeight) / 2;

    return _MinimapMapping(
      scale: scale,
      offsetX: offsetX - contentBounds.left * scale,
      offsetY: offsetY - contentBounds.top * scale,
    );
  }
}

class _MinimapMapping {
  final double scale;
  final double offsetX;
  final double offsetY;
  const _MinimapMapping({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });
}

class _MinimapPainter extends CustomPainter {
  final InfiniteCanvasController controller;
  final Color viewportColor;

  _MinimapPainter({
    required this.controller,
    required this.viewportColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final elements = controller.canvasController.elements;
    if (elements.isEmpty) return;

    // 计算内容包围盒
    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;

    for (final element in elements) {
      final bounds = element.bounds;
      if (bounds.left < left) left = bounds.left;
      if (bounds.top < top) top = bounds.top;
      if (bounds.right > right) right = bounds.right;
      if (bounds.bottom > bottom) bottom = bounds.bottom;
    }

    final contentBounds = Rect.fromLTRB(left, top, right, bottom);
    final contentWidth = contentBounds.width;
    final contentHeight = contentBounds.height;
    if (contentWidth <= 0 || contentHeight <= 0) return;

    // 计算缩放和偏移
    final padding = 8.0;
    final scaleX = (size.width - padding * 2) / contentWidth;
    final scaleY = (size.height - padding * 2) / contentHeight;
    final minimapScale = math.min(scaleX, scaleY);

    final mappedWidth = contentWidth * minimapScale;
    final mappedHeight = contentHeight * minimapScale;
    final ox = (size.width - mappedWidth) / 2 - contentBounds.left * minimapScale;
    final oy = (size.height - mappedHeight) / 2 - contentBounds.top * minimapScale;

    // 绘制元素缩略图
    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(minimapScale);

    final elementPaint = Paint()
      ..color = const Color(0xFF666666)
      ..strokeWidth = 1.0 / minimapScale
      ..style = PaintingStyle.stroke;

    for (final element in elements) {
      if (!element.visible) continue;
      canvas.drawRect(element.bounds, elementPaint);
    }

    canvas.restore();

    // 绘制视口矩形
    final vp = controller.viewportSize;
    if (vp == null) return;

    final transform = controller.transform;
    final visibleRect = transform.visibleWorldRect(vp);

    final vpLeft = visibleRect.left * minimapScale + ox;
    final vpTop = visibleRect.top * minimapScale + oy;
    final vpWidth = visibleRect.width * minimapScale;
    final vpHeight = visibleRect.height * minimapScale;

    final vpPaint = Paint()
      ..color = viewportColor
      ..style = PaintingStyle.fill;
    final vpStrokePaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final vpRect = Rect.fromLTWH(vpLeft, vpTop, vpWidth, vpHeight);
    canvas.drawRect(vpRect, vpPaint);
    canvas.drawRect(vpRect, vpStrokePaint);
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) {
    return oldDelegate.controller.transform != controller.transform ||
        oldDelegate.controller.canvasController.elements.length !=
            controller.canvasController.elements.length;
  }
}

import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';
import '../elements/element_registry.dart';
import '../rendering/grid_renderer.dart';
import '../rendering/selection_renderer.dart';
import 'infinite_canvas_controller.dart';

/// 无限画布配置
class InfiniteCanvasConfig {
  /// 是否显示网格
  final bool showGrid;

  /// 网格类型
  final GridType gridType;

  /// 背景颜色
  final Color backgroundColor;

  /// 网格颜色
  final Color gridColor;

  const InfiniteCanvasConfig({
    this.showGrid = true,
    this.gridType = GridType.dots,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.gridColor = const Color(0xFFE0E0E0),
  });
}

/// 无限画布主渲染器（CustomPainter）。
///
/// 分层渲染架构：
/// - Layer 1: 背景色 + 网格
/// - Layer 2: 绘图元素（视口裁剪 + 渲染器）
/// - Layer 3: 工具预览
/// - Layer 4: 选中装饰（Phase 3）
/// - Layer 5: UI 叠加层（Phase 5）
class InfiniteCanvasPainter extends CustomPainter {
  final InfiniteCanvasController controller;
  final InfiniteCanvasConfig config;

  /// 当前工具的预览元素（由 Widget 层设置）
  CanvasElement? previewElement;

  /// 缓存的网格渲染器
  final GridRenderer _gridRenderer;

  InfiniteCanvasPainter({
    required this.controller,
    this.previewElement,
    this.config = const InfiniteCanvasConfig(),
  }) : _gridRenderer = GridRenderer(
         color: config.gridColor,
         gridType: config.gridType,
       );

  @override
  void paint(Canvas canvas, Size size) {
    final transform = controller.transform;
    final canvasCtrl = controller.canvasController;

    // ── Layer 1: 背景 ─────────────────────────────────────
    canvas.drawColor(config.backgroundColor, BlendMode.srcOver);

    // ── Layer 1b: 网格 ────────────────────────────────────
    if (config.showGrid) {
      _gridRenderer.paint(
        canvas,
        size,
        transform.offset,
        transform.scale,
      );
    }

    // ── Layer 2: 绘图元素 ──────────────────────────────────
    canvas.save();
    canvas.translate(transform.offset.dx, transform.offset.dy);
    canvas.scale(transform.scale);

    // 视口裁剪：只绘制可见元素
    final visibleRect = transform.visibleWorldRect(size);
    final visibleElements = canvasCtrl.getVisibleElements(visibleRect);

    for (final element in visibleElements) {
      final renderer = ElementRendererRegistry.getRenderer(element.type);
      if (renderer != null) {
        if (element.opacity < 1.0) {
          canvas.saveLayer(null, Paint());
        }
        renderer.render(canvas, element);
        if (element.opacity < 1.0) {
          canvas.restore();
        }
      }
    }

    // ── Layer 3: 工具预览 ──────────────────────────────────
    if (previewElement != null) {
      final renderer = ElementRendererRegistry.getRenderer(previewElement!.type);
      if (renderer != null) {
        canvas.saveLayer(null, Paint());
        renderer.render(canvas, previewElement!);
        canvas.restore();
      }
    }

    // ── Layer 4: 选中装饰 ──────────────────────────────────
    if (canvasCtrl.hasSelection) {
      SelectionRenderer.paint(canvas, canvasCtrl, transform.scale);
    }

    canvas.restore();

    // ── Layer 5: UI 叠加层（不参与变换） ─────────────────────
    // TODO: Phase 5 - 小地图、缩放指示器等
  }

  @override
  bool shouldRepaint(InfiniteCanvasPainter oldDelegate) {
    return oldDelegate.controller.transform != controller.transform ||
        oldDelegate.config != config ||
        oldDelegate.previewElement != previewElement ||
        oldDelegate.controller.canvasController.elements.length !=
            controller.canvasController.elements.length;
  }
}

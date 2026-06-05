import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../elements/canvas_element.dart';
import '../../elements/element_registry.dart';

// ---------------------------------------------------------------------------
// PngExporter
// ---------------------------------------------------------------------------

/// PNG 导出器。
///
/// 将 [CanvasElement] 列表渲染为 PNG 图片字节。
class PngExporter {
  /// 将元素列表导出为 PNG 图片的原始字节。
  ///
  /// [elements] 要导出的元素列表。
  /// [contentBounds] 内容包围盒（世界坐标）。
  /// [pixelRatio] 像素比，默认 2.0（高清）。
  /// [backgroundColor] 背景颜色（ARGB 32-bit），默认白色。
  ///
  /// 返回 PNG 字节。
  static Future<Uint8List?> exportToPng({
    required List<CanvasElement> elements,
    required Rect contentBounds,
    double pixelRatio = 2.0,
    int backgroundColor = 0xFFFFFFFF,
  }) async {
    final width = (contentBounds.width * pixelRatio).ceil();
    final height = (contentBounds.height * pixelRatio).ceil();
    if (width <= 0 || height <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制背景
    canvas.drawColor(Color(backgroundColor), BlendMode.srcOver);

    // 平移使内容从 (0,0) 开始绘制
    canvas.translate(-contentBounds.left, -contentBounds.top);

    // 渲染每个元素
    for (final element in elements) {
      if (!element.visible) continue;
      final renderer = ElementRendererRegistry.getRenderer(element.type);
      if (renderer != null) {
        renderer.render(canvas, element);
      }
    }

    final picture = recorder.endRecording();

    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }
}

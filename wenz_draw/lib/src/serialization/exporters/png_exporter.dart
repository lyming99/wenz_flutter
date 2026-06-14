import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../elements/canvas_element.dart';
import '../../elements/element_registry.dart';
import '../../elements/widget_element.dart';

class PngExporter {
  const PngExporter._();

  static Future<Uint8List> exportElements({
    required Iterable<CanvasElement> elements,
    Rect? bounds,
    Color backgroundColor = Colors.white,
    double pixelRatio = 1,
  }) async {
    final elementList = elements.toList(growable: false)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final exportBounds = bounds ?? _contentBounds(elementList).inflate(24);
    final width = (exportBounds.width * pixelRatio).ceil().clamp(1, 32768);
    final height = (exportBounds.height * pixelRatio).ceil().clamp(1, 32768);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    canvas.drawRect(
      Offset.zero & exportBounds.size,
      Paint()..color = backgroundColor,
    );
    canvas.translate(-exportBounds.left, -exportBounds.top);
    for (final element in elementList) {
      if (element is CanvasWidgetElement) {
        _drawWidgetPlaceholder(canvas, element);
      } else {
        ElementRendererRegistry.render(canvas, element);
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    if (data == null) {
      throw StateError('Failed to encode PNG: image.toByteData returned null');
    }
    return data.buffer.asUint8List();
  }

  static void _drawWidgetPlaceholder(
    Canvas canvas,
    CanvasWidgetElement element,
  ) {
    final rect = element.worldRect;
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFFF3F4F6)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF9CA3AF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: element.widgetType,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    textPainter.layout(maxWidth: rect.width - 8);
    textPainter.paint(
      canvas,
      rect.center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  static Rect _contentBounds(List<CanvasElement> elements) {
    if (elements.isEmpty) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    var bounds = elements.first.bounds;
    for (final element in elements.skip(1)) {
      bounds = bounds.expandToInclude(element.bounds);
    }
    return bounds;
  }
}

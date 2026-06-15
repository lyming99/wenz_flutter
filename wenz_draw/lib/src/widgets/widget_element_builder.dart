import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/widget_element.dart';
import '../infinite_canvas/infinite_canvas_controller.dart';

enum CanvasWidgetRenderDetail { color, colorWithText, thumbnail, full }

class CanvasWidgetBuildContext {
  const CanvasWidgetBuildContext({
    required this.canvasController,
    required this.viewController,
    required this.selected,
    required this.scale,
    this.renderDetail = CanvasWidgetRenderDetail.full,
  });

  final CanvasController canvasController;
  final InfiniteCanvasController viewController;
  final bool selected;
  final double scale;
  final CanvasWidgetRenderDetail renderDetail;

  void updateProps(String elementId, Map<String, dynamic> props) {
    final element = canvasController.elementById(elementId);
    if (element is! CanvasWidgetElement) {
      return;
    }

    canvasController.updateElement(
      elementId,
      element.copyWith(widgetData: Map<String, dynamic>.unmodifiable(props)),
    );
  }

  Color previewColor(CanvasWidgetElement element) {
    final value = element.widgetData['color'];
    if (value is Color) {
      return value;
    }
    if (value is int) {
      return Color(value);
    }
    if (value is String) {
      return Color(int.tryParse(value) ?? 0xFFE5E7EB);
    }
    return const Color(0xFFE5E7EB);
  }

  String previewText(CanvasWidgetElement element) {
    final label = element.widgetData['label'];
    if (label != null && label.toString().isNotEmpty) {
      return label.toString();
    }
    final text = element.widgetData['text'];
    if (text != null && text.toString().isNotEmpty) {
      return text.toString();
    }
    return element.widgetType;
  }
}

abstract class WidgetElementBuilder {
  const WidgetElementBuilder();

  bool get useDefaultThumbnailFrame => true;
  bool get useDefaultSelectionFrame => true;

  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  });

  Widget buildPreview(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    final color = canvas.previewColor(element);
    final text = canvas.previewText(element);
    return ColoredBox(
      color: color,
      child:
          canvas.renderDetail == CanvasWidgetRenderDetail.colorWithText ||
              canvas.renderDetail == CanvasWidgetRenderDetail.thumbnail
          ? Center(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                maxLines:
                    canvas.renderDetail == CanvasWidgetRenderDetail.thumbnail
                    ? 2
                    : 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textColorFor(color),
                  fontSize:
                      canvas.renderDetail == CanvasWidgetRenderDetail.thumbnail
                      ? 12
                      : 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : const SizedBox.expand(),
    );
  }

  Color _textColorFor(Color color) {
    return color.computeLuminance() > 0.55
        ? const Color(0xFF111827)
        : const Color(0xFFFFFFFF);
  }
}

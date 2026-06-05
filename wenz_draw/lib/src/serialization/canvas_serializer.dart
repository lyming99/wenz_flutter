import 'dart:convert';
import 'dart:ui' show Offset, Rect;

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';
import '../elements/path_element.dart';
import '../elements/line_element.dart';
import '../elements/rect_element.dart';
import '../elements/ellipse_element.dart';
import '../elements/arrow_element.dart';
import '../elements/text_element.dart';
import '../infinite_canvas/canvas_transform.dart';

/// 画布序列化器。
///
/// 将画布状态（元素、图层、视图变换）序列化为 JSON，
/// 并支持从 JSON 反序列化恢复完整画布状态。
class CanvasSerializer {
  static const String version = '1.0';

  /// 序列化画布状态为 JSON 字符串。
  static String toJsonString(CanvasController controller) {
    final json = toJson(controller);
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  /// 序列化画布状态为 Map。
  static Map<String, dynamic> toJson(CanvasController controller) {
    return {
      'version': version,
      'elements': controller.elements.map((e) => _serializeElement(e)).toList(),
      'transform': {
        'scale': controller.elementManager.toString(), // placeholder
      },
    };
  }

  /// 序列化完整画布（含视图变换）。
  static Map<String, dynamic> toJsonFull(
    CanvasController controller,
    CanvasTransform transform,
  ) {
    return {
      'version': version,
      'transform': {
        'scale': transform.scale,
        'offset': {'dx': transform.offset.dx, 'dy': transform.offset.dy},
      },
      'elements': controller.elements.map((e) => _serializeElement(e)).toList(),
    };
  }

  /// 从 JSON 字符串反序列化。
  static void fromJsonString(String jsonString, CanvasController controller) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    fromJson(json, controller);
  }

  /// 从 JSON Map 反序列化。
  static void fromJson(Map<String, dynamic> json, CanvasController controller) {
    controller.elementManager.clear();
    controller.deselectAll();

    final elementsJson = json['elements'] as List?;
    if (elementsJson != null) {
      for (final elemJson in elementsJson) {
        final element = _deserializeElement(elemJson as Map<String, dynamic>);
        if (element != null) {
          controller.elementManager.addElement(element);
        }
      }
    }
  }

  /// 从 JSON 恢复完整画布（含视图变换）。
  static CanvasTransform? fromJsonFull(
    Map<String, dynamic> json,
    CanvasController controller,
  ) {
    fromJson(json, controller);

    final transformJson = json['transform'] as Map<String, dynamic>?;
    if (transformJson != null) {
      return CanvasTransform(
        scale: (transformJson['scale'] as num?)?.toDouble() ?? 1.0,
        offset: Offset(
          ((transformJson['offset'] as Map?)?['dx'] as num?)?.toDouble() ?? 0,
          ((transformJson['offset'] as Map?)?['dy'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
    return null;
  }

  /// 序列化单个元素。
  static Map<String, dynamic> _serializeElement(CanvasElement element) {
    return element.toJson();
  }

  /// 反序列化单个元素。
  static CanvasElement? _deserializeElement(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'path':
        return PathElement.fromJson(json);
      case 'line':
        return LineElement.fromJson(json);
      case 'rect':
        return RectElement.fromJson(json);
      case 'ellipse':
        return EllipseElement.fromJson(json);
      case 'arrow':
        return ArrowElement.fromJson(json);
      case 'text':
        return TextElement.fromJson(json);
      default:
        return null; // 未知类型跳过
    }
  }
}

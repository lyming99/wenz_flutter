import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../canvas/paint_style.dart';
import '../elements/arrow_element.dart';
import '../elements/canvas_element.dart';
import '../elements/curve_element.dart';
import '../elements/drawio_shape_element.dart';
import '../elements/ellipse_element.dart';
import '../elements/image_element.dart';
import '../elements/line_element.dart';
import '../elements/line_label_painter.dart';
import '../elements/path_element.dart';
import '../elements/polyline_element.dart';
import '../elements/rect_element.dart';
import '../elements/shape_label_painter.dart';
import '../elements/text_element.dart';
import '../elements/unknown_element.dart';
import '../elements/widget_element.dart';
import '../layers/canvas_layer.dart';
import '../snap/snap_resolver.dart';
import 'canvas_document.dart';
import 'document_migrator.dart';

class CanvasSerializer {
  const CanvasSerializer._();

  /// Serializes the controller's state to a schema-2.0 document JSON. The
  /// optional [metadata], [viewport] and [assets] are merged in when supplied.
  static Map<String, dynamic> toJson(
    CanvasController controller, {
    DocumentMetadata? metadata,
    DocumentViewport? viewport,
    List<DocumentAsset>? assets,
  }) {
    return CanvasDocument(
      schemaVersion: DocumentSchema.current,
      metadata: metadata ?? const DocumentMetadata(),
      viewport: viewport ?? const DocumentViewport(),
      assets: assets ?? const <DocumentAsset>[],
      layers: controller.layers,
      elements: controller.elements,
    ).toJson();
  }

  static CanvasDocument fromJson(Map<String, dynamic> json) {
    // Always migrate first so the rest of the loader can assume schema 2.0.
    final migrated = DocumentMigrator.migrate(Map<String, dynamic>.from(json));

    final layerJson = migrated['layers'] as List<dynamic>? ?? const [];
    final elementJson = migrated['elements'] as List<dynamic>? ?? const [];
    final assetJson = migrated['assets'] as List<dynamic>? ?? const [];

    // Preserve any top-level keys this loader does not recognize, so a newer
    // app's document survives a round-trip through this one.
    final knownKeys = const {
      'schemaVersion',
      'metadata',
      'viewport',
      'assets',
      'layers',
      'elements',
      // legacy, already consumed by the migrator but listed for completeness
      'version',
    };
    final extras = Map<String, dynamic>.from(
      migrated..removeWhere((key, _) => knownKeys.contains(key)),
    );

    return CanvasDocument(
      schemaVersion: (migrated['schemaVersion'] as String?) ??
          DocumentSchema.current,
      metadata: _metadataFromJson(migrated['metadata']),
      viewport: _viewportFromJson(migrated['viewport']),
      assets: [
        for (final asset in assetJson)
          if (asset is Map<String, dynamic>)
            DocumentAsset.fromJson(asset),
      ],
      layers: [
        for (final layer in layerJson)
          if (layer is Map<String, dynamic>) _layerFromJson(layer),
      ],
      elements: [
        for (final element in elementJson)
          if (element is Map<String, dynamic>) elementFromJson(element),
      ],
      extras: extras,
    );
  }

  static void load(CanvasController controller, Map<String, dynamic> json) {
    final document = fromJson(json);
    controller.loadDocument(document.layers, document.elements);
  }

  static CanvasElement elementFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final layerId = json['layerId'] as String? ?? CanvasLayer.defaultLayerId;
    final visible = json['visible'] as bool? ?? true;
    final opacity = (json['opacity'] as num?)?.toDouble() ?? 1;
    final zIndex = (json['zIndex'] as num?)?.toInt() ?? 0;
    final type = json['type'] as String? ?? '';

    switch (type) {
      case PathElement.elementType:
        return PathElement(
          id: id,
          layerId: layerId,
          visible: visible,
          opacity: opacity,
          zIndex: zIndex,
          groupId: json['groupId'] as String?,
          points: [
            for (final point in json['points'] as List<dynamic>? ?? const [])
              if (point is Map<String, dynamic>)
                PathPoint(
                  position: _point(point),
                  pressure: (point['pressure'] as num?)?.toDouble() ?? 0.5,
                  timestamp: (point['timestamp'] as num?)?.toDouble() ?? 0,
                ),
          ],
          style: _style(json['style']),
        );
      case CurveElement.elementType:
        return CurveElement(
          id: id,
          layerId: layerId,
          visible: visible,
          opacity: opacity,
          zIndex: zIndex,
          groupId: json['groupId'] as String?,
          start: _point(json['start']),
          end: _point(json['end']),
          control: _point(json['control']),
          style: _style(json['style']),
        );
      case LineElement.elementType:
        return LineElement(
          id: id,
          layerId: layerId,
          visible: visible,
          opacity: opacity,
          zIndex: zIndex,
          groupId: json['groupId'] as String?,
          start: _point(json['start']),
          end: _point(json['end']),
          style: _style(json['style']),
          startBinding: SnapBinding.fromJson(json['startBinding']),
          endBinding: SnapBinding.fromJson(json['endBinding']),
          label: json['label'] as String?,
          labelStyle: LineLabelPainter.styleFromJson(json['labelStyle']),
          labelPosition:
              (json['labelPosition'] as num?)?.toDouble() ??
              LineLabelPainter.defaultPosition,
          labelOffset: LineLabelPainter.offsetFromJson(json['labelOffset']),
          labelBackground: _colorFromJson(json['labelBackground']),
        );
      case PolylineElement.elementType:
        return PolylineElement(
          id: id,
          layerId: layerId,
          visible: visible,
          opacity: opacity,
          zIndex: zIndex,
          groupId: json['groupId'] as String?,
          points: [
            for (final point in json['points'] as List<dynamic>? ?? const [])
              _point(point),
          ],
          style: _style(json['style']),
          startBinding: SnapBinding.fromJson(json['startBinding']),
          endBinding: SnapBinding.fromJson(json['endBinding']),
          endArrow: json['endArrow'] as bool? ?? false,
          headSize: (json['headSize'] as num?)?.toDouble() ?? 14,
          label: json['label'] as String?,
          labelStyle: LineLabelPainter.styleFromJson(json['labelStyle']),
          labelPosition:
              (json['labelPosition'] as num?)?.toDouble() ??
              LineLabelPainter.defaultPosition,
          labelOffset: LineLabelPainter.offsetFromJson(json['labelOffset']),
          labelBackground: _colorFromJson(json['labelBackground']),
        );
      case DrawioShapeElement.elementType:
        return DrawioShapeElement(
          id: id,
          layerId: layerId,
          visible: visible,
          opacity: opacity,
          zIndex: zIndex,
          groupId: json['groupId'] as String?,
          shapeKey: _shapeKey(json['shapeKey']),
          rect: _rect(json['rect']),
          strokeStyle: _style(json['strokeStyle']),
          fillStyle: _nullableStyle(json['fillStyle']),
          properties: _stringMap(json['properties']),
          label: json['label'] as String?,
          labelStyle: ShapeLabelPainter.styleFromJson(json['labelStyle']),
          labelAlign: ShapeLabelPainter.textAlignFromString(
            json['labelAlign'] as String?,
          ),
          labelPadding: ShapeLabelPainter.paddingFromJson(json['labelPadding']),
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        );
      case RectElement.elementType:
        return RectElement(
          id: id,
          layerId: layerId,
          visible: visible,
          opacity: opacity,
          zIndex: zIndex,
          groupId: json['groupId'] as String?,
          rect: _rect(json['rect']),
          strokeStyle: _style(json['strokeStyle']),
          fillStyle: _nullableStyle(json['fillStyle']),
          label: json['label'] as String?,
          labelStyle: ShapeLabelPainter.styleFromJson(json['labelStyle']),
          labelAlign: ShapeLabelPainter.textAlignFromString(
            json['labelAlign'] as String?,
          ),
          labelPadding: ShapeLabelPainter.paddingFromJson(json['labelPadding']),
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        );
      case EllipseElement.elementType:
        return EllipseElement(
          id: id,
          layerId: layerId,
          visible: visible,
          opacity: opacity,
          zIndex: zIndex,
          groupId: json['groupId'] as String?,
          rect: _rect(json['rect']),
          strokeStyle: _style(json['strokeStyle']),
          fillStyle: _nullableStyle(json['fillStyle']),
          label: json['label'] as String?,
          labelStyle: ShapeLabelPainter.styleFromJson(json['labelStyle']),
          labelAlign: ShapeLabelPainter.textAlignFromString(
            json['labelAlign'] as String?,
          ),
          labelPadding: ShapeLabelPainter.paddingFromJson(json['labelPadding']),
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        );
      case ArrowElement.elementType:
        return ArrowElement(
          id: id,
          layerId: layerId,
          visible: visible,
          opacity: opacity,
          zIndex: zIndex,
          groupId: json['groupId'] as String?,
          start: _point(json['start']),
          end: _point(json['end']),
          headSize: (json['headSize'] as num?)?.toDouble() ?? 14,
          style: _style(json['style']),
          startBinding: SnapBinding.fromJson(json['startBinding']),
          endBinding: SnapBinding.fromJson(json['endBinding']),
          label: json['label'] as String?,
          labelStyle: LineLabelPainter.styleFromJson(json['labelStyle']),
          labelPosition:
              (json['labelPosition'] as num?)?.toDouble() ??
              LineLabelPainter.defaultPosition,
          labelOffset: LineLabelPainter.offsetFromJson(json['labelOffset']),
          labelBackground: _colorFromJson(json['labelBackground']),
        );
      case TextElement.elementType:
        final styleJson = json['style'];
        final style = styleJson is Map<String, dynamic>
            ? TextStyle(
                color: Color(
                  (styleJson['color'] as num?)?.toInt() ??
                      Colors.black.toARGB32(),
                ),
                fontSize: (styleJson['fontSize'] as num?)?.toDouble() ?? 24,
                fontWeight: _fontWeight(styleJson['fontWeight']),
                height: (styleJson['height'] as num?)?.toDouble() ?? 1.2,
                fontFamily: styleJson['fontFamily'] as String?,
              )
            : const TextStyle(color: Colors.black, fontSize: 24, height: 1.2);
        return TextElement(
          id: id,
          layerId: layerId,
          visible: visible,
          opacity: opacity,
          zIndex: zIndex,
          groupId: json['groupId'] as String?,
          position: _point(json['position']),
          text: json['text'] as String? ?? '',
          style: style,
          maxWidth: (json['maxWidth'] as num?)?.toDouble(),
          boxSize: _size(json['boxSize']),
          textAlign: _textAlign(json['textAlign'] as String?),
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        );
      case ImageElement.elementType:
        return ImageElement(
          id: id,
          layerId: layerId,
          visible: visible,
          opacity: opacity,
          zIndex: zIndex,
          groupId: json['groupId'] as String?,
          rect: _rect(json['rect']),
          fit: _boxFitFromString(json['fit'] as String?),
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
          imageData: json['imageData'] as String?,
          url: json['url'] as String?,
          filePath: json['filePath'] as String?,
        );
      case CanvasWidgetElement.elementType:
        return CanvasWidgetElement(
          id: id,
          worldRect: _rect(json['worldRect']),
          widgetType: json['widgetType'] as String? ?? '',
          widgetData: _stringMap(json['widgetData']),
          layerId: layerId,
          visible: visible,
          opacity: opacity,
          zIndex: zIndex,
          groupId: json['groupId'] as String?,
          isLocked: json['isLocked'] as bool? ?? false,
          interactive: json['interactive'] as bool? ?? true,
          scaleMode: _scaleModeFromString(json['scaleMode'] as String?),
          renderMode: _renderModeFromString(json['renderMode'] as String?),
          minScreenSize: _size(json['minScreenSize']),
          maxScreenSize: _size(json['maxScreenSize']),
          clipBehavior: _clipFromString(json['clipBehavior'] as String?),
        );
      default:
        // Unknown element type: preserve the original JSON so a round-trip
        // through this app does not lose data written by a newer one. The
        // common fields are extracted so selection/layering still works.
        return UnknownElement(
          id: id,
          rawJson: Map<String, dynamic>.from(json),
          layerId: layerId,
          visible: visible,
          opacity: opacity,
          zIndex: zIndex,
          groupId: json['groupId'] as String?,
        );
    }
  }

  static DocumentMetadata _metadataFromJson(Object? value) {
    if (value is Map<String, dynamic>) return DocumentMetadata.fromJson(value);
    if (value is Map) {
      return DocumentMetadata.fromJson(
        Map<String, dynamic>.from(value),
      );
    }
    return const DocumentMetadata();
  }

  static DocumentViewport _viewportFromJson(Object? value) {
    if (value is Map<String, dynamic>) return DocumentViewport.fromJson(value);
    if (value is Map) {
      return DocumentViewport.fromJson(
        Map<String, dynamic>.from(value),
      );
    }
    return const DocumentViewport();
  }

  static String _shapeKey(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? 'rectangle' : text;
  }

  static CanvasLayer _layerFromJson(Map<String, dynamic> json) {
    return CanvasLayer(
      id: json['id'] as String? ?? CanvasLayer.defaultLayerId,
      name: json['name'] as String? ?? 'Layer',
      isVisible: json['visible'] as bool? ?? true,
      isLocked: json['locked'] as bool? ?? false,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
    );
  }

  static CanvasWidgetScaleMode _scaleModeFromString(String? value) {
    switch (value) {
      case 'paintScale':
        return CanvasWidgetScaleMode.paintScale;
      case 'fixedScreenSize':
        return CanvasWidgetScaleMode.fixedScreenSize;
      case 'layoutScale':
      default:
        return CanvasWidgetScaleMode.layoutScale;
    }
  }

  static CanvasWidgetRenderMode _renderModeFromString(String? value) {
    switch (value) {
      case 'live':
        return CanvasWidgetRenderMode.live;
      case 'snapshot':
      default:
        return CanvasWidgetRenderMode.snapshot;
    }
  }

  static Offset _point(Object? json) {
    if (json is Map<String, dynamic>) {
      return Offset(
        (json['x'] as num?)?.toDouble() ?? 0,
        (json['y'] as num?)?.toDouble() ?? 0,
      );
    }
    return Offset.zero;
  }

  static Rect _rect(Object? json) {
    if (json is Map<String, dynamic>) {
      return Rect.fromLTRB(
        (json['left'] as num?)?.toDouble() ?? 0,
        (json['top'] as num?)?.toDouble() ?? 0,
        (json['right'] as num?)?.toDouble() ?? 0,
        (json['bottom'] as num?)?.toDouble() ?? 0,
      );
    }
    return Rect.zero;
  }

  static Size? _size(Object? json) {
    if (json is Map<String, dynamic>) {
      final width = (json['width'] as num?)?.toDouble();
      final height = (json['height'] as num?)?.toDouble();
      if (width == null || height == null) {
        return null;
      }
      return Size(width, height);
    }
    return null;
  }

  static PaintStyle _style(Object? json) {
    return json is Map<String, dynamic>
        ? PaintStyle.fromJson(json)
        : const PaintStyle();
  }

  static PaintStyle? _nullableStyle(Object? json) {
    return json is Map<String, dynamic> ? PaintStyle.fromJson(json) : null;
  }

  static Color? _colorFromJson(Object? value) {
    return value is num ? Color(value.toInt()) : null;
  }

  static Map<String, dynamic> _stringMap(Object? json) {
    if (json is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(json);
    }
    if (json is Map) {
      return Map<String, dynamic>.unmodifiable(
        json.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return const <String, dynamic>{};
  }

  static Clip _clipFromString(String? value) {
    for (final clip in Clip.values) {
      if (clip.name == value) {
        return clip;
      }
    }
    return Clip.hardEdge;
  }

  static TextAlign _textAlign(String? value) {
    for (final align in TextAlign.values) {
      if (align.name == value) {
        return align;
      }
    }
    return TextAlign.left;
  }

  static BoxFit _boxFitFromString(String? value) {
    for (final fit in BoxFit.values) {
      if (fit.name == value) {
        return fit;
      }
    }
    return BoxFit.contain;
  }

  static FontWeight _fontWeight(Object? value) {
    final weight = value is num ? value.toInt() : FontWeight.normal.value;
    return FontWeight.values.reduce((previous, current) {
      return (current.value - weight).abs() < (previous.value - weight).abs()
          ? current
          : previous;
    });
  }
}

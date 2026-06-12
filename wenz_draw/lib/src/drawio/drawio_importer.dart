import 'package:flutter/widgets.dart';
import 'package:xml/xml.dart';

import '../elements/drawio_shape_element.dart';
import 'drawio_shape_adapter.dart';

class DrawioImporter {
  const DrawioImporter._();

  static List<DrawioShapeElement> fromJson(Object? source) {
    return [
      for (final cell in _jsonCells(source))
        if (_isVertex(cell)) _elementFromJsonCell(cell),
    ];
  }

  static List<DrawioShapeElement> fromXml(String source) {
    final document = XmlDocument.parse(source);
    return [
      for (final cell in document.findAllElements('mxCell'))
        if (_xmlBool(cell.getAttribute('vertex'))) _elementFromXmlCell(cell),
    ];
  }

  static Iterable<Map<String, dynamic>> _jsonCells(Object? source) sync* {
    if (source is List) {
      for (final item in source) {
        if (item is Map) {
          yield _dynamicMap(item);
        }
      }
      return;
    }
    if (source is! Map) {
      return;
    }
    final map = _dynamicMap(source);
    final direct = map['cells'] ?? map['mxCell'] ?? map['elements'];
    if (direct is List) {
      yield* _jsonCells(direct);
      return;
    }
    final model = map['mxGraphModel'];
    if (model is Map) {
      yield* _jsonCells(model);
      return;
    }
    final root = map['root'];
    if (root is Map) {
      yield* _jsonCells(root);
      return;
    }
    if (map.containsKey('style') || map.containsKey('mxGeometry')) {
      yield map;
    }
  }

  static DrawioShapeElement _elementFromJsonCell(Map<String, dynamic> cell) {
    final geometry = _jsonGeometry(cell);
    return DrawioShapeAdapter.fromStyleString(
      id: (cell['id'] ?? '').toString(),
      rect: geometry,
      style: (cell['style'] ?? '').toString(),
      label: _label(cell['value']),
      layerId: (cell['layerId'] ?? cell['parent'] ?? 'default').toString(),
      zIndex: _intValue(cell['zIndex']),
    );
  }

  static DrawioShapeElement _elementFromXmlCell(XmlElement cell) {
    final geometry = cell.findElements('mxGeometry').firstOrNull;
    return DrawioShapeAdapter.fromStyleString(
      id: cell.getAttribute('id') ?? '',
      rect: _xmlGeometry(geometry),
      style: cell.getAttribute('style') ?? '',
      label: _label(cell.getAttribute('value')),
      layerId: cell.getAttribute('parent') ?? 'default',
    );
  }

  static Rect _jsonGeometry(Map<String, dynamic> cell) {
    final raw = cell['geometry'] ?? cell['mxGeometry'];
    if (raw is Map) {
      final geometry = _dynamicMap(raw);
      return Rect.fromLTWH(
        _doubleValue(geometry['x']),
        _doubleValue(geometry['y']),
        _doubleValue(geometry['width']),
        _doubleValue(geometry['height']),
      );
    }
    return Rect.zero;
  }

  static Rect _xmlGeometry(XmlElement? geometry) {
    if (geometry == null) {
      return Rect.zero;
    }
    return Rect.fromLTWH(
      _doubleValue(geometry.getAttribute('x')),
      _doubleValue(geometry.getAttribute('y')),
      _doubleValue(geometry.getAttribute('width')),
      _doubleValue(geometry.getAttribute('height')),
    );
  }

  static bool _isVertex(Map<String, dynamic> cell) {
    return _boolValue(cell['vertex']);
  }

  static bool _boolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value == null) {
      return false;
    }
    final text = value.toString().toLowerCase();
    return text == '1' || text == 'true';
  }

  static bool _xmlBool(String? value) => _boolValue(value);

  static double _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _intValue(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _label(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString();
    if (text.isEmpty) {
      return null;
    }
    final withBreaks = text.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    final stripped = withBreaks.replaceAll(RegExp(r'<[^>]*>'), '');
    return stripped.isEmpty ? null : stripped;
  }

  static Map<String, dynamic> _dynamicMap(Map source) {
    return {
      for (final entry in source.entries) entry.key.toString(): entry.value,
    };
  }
}

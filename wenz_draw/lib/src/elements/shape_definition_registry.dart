import 'package:flutter/widgets.dart';

import 'shape_definition.dart';

class ShapeDefinitionRegistry {
  ShapeDefinitionRegistry._();

  static final Map<String, ShapeDefinition> _definitions = {};

  static final ShapeDefinition defaultDefinition = ShapeDefinition(
    key: 'rectangle',
    buildPath: (rect, _) => Path()..addRect(rect),
    buildSvgPath: (rect, _) =>
        'M ${rect.left} ${rect.top} L ${rect.right} ${rect.top} '
        'L ${rect.right} ${rect.bottom} L ${rect.left} ${rect.bottom} Z',
    buildOutline: (rect, _) => [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ],
  );

  static void register(ShapeDefinition definition, {List<String> aliases = const []}) {
    _definitions[definition.key] = definition;
    for (final alias in aliases) {
      _definitions[alias] = definition;
    }
  }

  static ShapeDefinition definitionFor(String key) {
    return _definitions[key] ?? defaultDefinition;
  }

  static bool contains(String key) {
    return _definitions.containsKey(key);
  }

  static Iterable<String> get keys => _definitions.keys;

  static void clear() {
    _definitions.clear();
  }
}

import 'package:flutter/foundation.dart';

@immutable
class DrawioStyle {
  const DrawioStyle({
    required this.raw,
    required this.values,
    required this.flags,
  });

  final String raw;
  final Map<String, String> values;
  final Set<String> flags;

  String? operator [](String key) => values[key];

  bool hasFlag(String key) => flags.contains(key);

  bool boolValue(String key, {bool fallback = false}) {
    final value = values[key];
    if (value == null) {
      return flags.contains(key) || fallback;
    }
    return value == '1' || value.toLowerCase() == 'true';
  }

  double? doubleValue(String key) {
    final value = values[key];
    return value == null ? null : double.tryParse(value);
  }

  int? intValue(String key) {
    final value = values[key];
    return value == null ? null : int.tryParse(value);
  }

  Map<String, String> get extra {
    const known = {
      'shape',
      'rounded',
      'whiteSpace',
      'html',
      'fillColor',
      'strokeColor',
      'strokeWidth',
      'dashed',
      'direction',
      'arcSize',
      'opacity',
      'fillOpacity',
      'strokeOpacity',
      'fontColor',
      'fontSize',
      'fontStyle',
      'align',
      'spacing',
      'spacingLeft',
      'spacingTop',
      'spacingRight',
      'spacingBottom',
    };
    return Map<String, String>.unmodifiable({
      for (final entry in values.entries)
        if (!known.contains(entry.key)) entry.key: entry.value,
    });
  }
}

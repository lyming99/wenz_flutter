import 'package:flutter/material.dart';

class DrawioColor {
  const DrawioColor._();

  static const Map<String, Color> _named = {
    'black': Colors.black,
    'white': Colors.white,
    'red': Colors.red,
    'green': Colors.green,
    'blue': Colors.blue,
    'yellow': Colors.yellow,
    'gray': Colors.grey,
    'grey': Colors.grey,
    'none': Colors.transparent,
  };

  static Color? parse(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.toLowerCase() == 'none') {
      return null;
    }
    final named = _named[normalized.toLowerCase()];
    if (named != null && normalized.toLowerCase() != 'none') {
      return named;
    }
    if (normalized.startsWith('#')) {
      return _hex(normalized.substring(1));
    }
    if (normalized.startsWith('0x') || normalized.startsWith('0X')) {
      return _hex(normalized.substring(2));
    }
    return null;
  }

  static double opacityFromPercent(String? value, {double fallback = 1}) {
    if (value == null || value.isEmpty) {
      return fallback;
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return fallback;
    }
    return (parsed / 100).clamp(0.0, 1.0).toDouble();
  }

  static Color? _hex(String hex) {
    final normalized = hex.length == 3
        ? hex.split('').map((char) => '$char$char').join()
        : hex;
    final value = int.tryParse(normalized, radix: 16);
    if (value == null) {
      return null;
    }
    return switch (normalized.length) {
      6 => Color(0xFF000000 | value),
      8 => Color(value),
      _ => null,
    };
  }
}

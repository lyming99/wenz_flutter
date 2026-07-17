import 'package:flutter/material.dart';

/// Applies opacity without using Flutter APIs that are version-sensitive
/// across the package's supported Flutter SDK range.
Color mermaidColorWithOpacity(Color color, double opacity) {
  final effectiveOpacity = opacity < 0.0
      ? 0.0
      : opacity > 1.0
          ? 1.0
          : opacity;
  return color.withAlpha((255.0 * effectiveOpacity).round());
}

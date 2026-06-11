import 'package:flutter/material.dart';

enum GridType { lines, dots, none }

@immutable
class InfiniteCanvasConfig {
  const InfiniteCanvasConfig({
    this.showGrid = true,
    this.gridType = GridType.dots,
    this.backgroundColor = Colors.white,
    this.gridColor = const Color(0xFFE1E5EA),
    this.majorGridColor = const Color(0xFFC8CED8),
    this.minScale = 0.1,
    this.maxScale = 10.0,
    this.scrollZoomSensitivity = 0.0015,
    this.gridBaseSize = 50.0,
  });

  final bool showGrid;
  final GridType gridType;
  final Color backgroundColor;
  final Color gridColor;
  final Color majorGridColor;
  final double minScale;
  final double maxScale;
  final double scrollZoomSensitivity;
  final double gridBaseSize;
}

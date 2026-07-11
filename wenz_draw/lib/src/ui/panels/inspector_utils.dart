import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

bool canEditPaint(CanvasElement? element) {
  return element is DrawioShapeElement ||
      element is RectElement ||
      element is EllipseElement;
}

LineArrowStyle? lineArrowStyleOf(CanvasElement? element) {
  return switch (element) {
    final LineElement e => e.arrowStyle,
    final PolylineElement e => e.arrowStyle,
    final CurveElement e => e.arrowStyle,
    _ => null,
  };
}

Color? fillColorOf(CanvasElement? element) {
  return switch (element) {
    final DrawioShapeElement e => e.fillStyle?.color,
    final RectElement e => e.fillStyle?.color,
    final EllipseElement e => e.fillStyle?.color,
    _ => null,
  };
}

Color? strokeColorOf(CanvasElement? element) {
  return switch (element) {
    final DrawioShapeElement e => e.strokeStyle.color,
    final RectElement e => e.strokeStyle.color,
    final EllipseElement e => e.strokeStyle.color,
    _ => null,
  };
}

double? strokeWidthOf(CanvasElement? element) {
  return switch (element) {
    final DrawioShapeElement e => e.strokeStyle.strokeWidth,
    final RectElement e => e.strokeStyle.strokeWidth,
    final EllipseElement e => e.strokeStyle.strokeWidth,
    _ => null,
  };
}

const inspectorSwatches = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFE6F1FB),
  Color(0xFFDFF4EE),
  Color(0xFFFFF6D6),
  Color(0xFFF7E6EE),
  Color(0xFF263442),
];

double? opacityOf(CanvasElement? element) {
  return switch (element) {
    final DrawioShapeElement e => e.strokeStyle.opacity,
    final RectElement e => e.strokeStyle.opacity,
    final EllipseElement e => e.strokeStyle.opacity,
    _ => null,
  };
}

bool canRotateElement(CanvasElement? element) {
  return element is DrawioShapeElement ||
      element is RectElement ||
      element is EllipseElement ||
      element is TextElement ||
      element is ImageElement;
}

double rotationDegreesOf(CanvasElement? element) {
  final rotation = switch (element) {
    final DrawioShapeElement e => e.rotation,
    final RectElement e => e.rotation,
    final EllipseElement e => e.rotation,
    final TextElement e => e.rotation,
    final ImageElement e => e.rotation,
    _ => 0.0,
  };
  final degrees = rotation * 180 / math.pi;
  return ((degrees + 180) % 360) - 180;
}

double radiusOf(CanvasElement? element) {
  return element is RectElement ? element.borderRadius : 7;
}

double? fontSizeOf(CanvasElement? element) {
  if (element is TextElement) {
    return element.style.fontSize;
  }
  if (element is RectElement) {
    return element.labelStyle.fontSize;
  }
  if (element is EllipseElement) {
    return element.labelStyle.fontSize;
  }
  return 14;
}

Color? textColorOf(CanvasElement? element) {
  return switch (element) {
    final TextElement e => e.style.color,
    final DrawioShapeElement e => e.labelStyle.color,
    final RectElement e => e.labelStyle.color,
    final EllipseElement e => e.labelStyle.color,
    final LineElement e => e.labelStyle.color,
    final ArrowElement e => e.labelStyle.color,
    final PolylineElement e => e.labelStyle.color,
    _ => null,
  };
}

const toolbarColorSwatches = <Color>[
  Color(0xFF111827),
  Color(0xFF6B7280),
  Color(0xFFEF4444),
  Color(0xFFF97316),
  Color(0xFFF59E0B),
  Color(0xFFEAB308),
  Color(0xFF84CC16),
  Color(0xFF22C55E),
  Color(0xFF10B981),
  Color(0xFF14B8A6),
  Color(0xFF06B6D4),
  Color(0xFF0EA5E9),
  Color(0xFF3B82F6),
  Color(0xFF6366F1),
  Color(0xFF8B5CF6),
  Color(0xFFA855F7),
  Color(0xFFD946EF),
  Color(0xFFEC4899),
  Color(0xFFF43F5E),
];

extension FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

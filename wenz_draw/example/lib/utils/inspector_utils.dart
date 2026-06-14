import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

bool canEditPaint(CanvasElement? element) {
  return element is DrawioShapeElement ||
      element is RectElement ||
      element is EllipseElement;
}

Color? fillColorOf(CanvasElement? element) {
  return switch (element) {
    DrawioShapeElement e => e.fillStyle?.color,
    RectElement e => e.fillStyle?.color,
    EllipseElement e => e.fillStyle?.color,
    _ => null,
  };
}

Color? strokeColorOf(CanvasElement? element) {
  return switch (element) {
    DrawioShapeElement e => e.strokeStyle.color,
    RectElement e => e.strokeStyle.color,
    EllipseElement e => e.strokeStyle.color,
    _ => null,
  };
}

double? strokeWidthOf(CanvasElement? element) {
  return switch (element) {
    DrawioShapeElement e => e.strokeStyle.strokeWidth,
    RectElement e => e.strokeStyle.strokeWidth,
    EllipseElement e => e.strokeStyle.strokeWidth,
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
    DrawioShapeElement e => e.strokeStyle.opacity,
    RectElement e => e.strokeStyle.opacity,
    EllipseElement e => e.strokeStyle.opacity,
    _ => null,
  };
}

double rotationDegreesOf(CanvasElement? element) {
  if (element is DrawioShapeElement) {
    final degrees = element.rotation * 180 / math.pi;
    return ((degrees + 180) % 360) - 180;
  }
  return 0;
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
    TextElement e => e.style.color,
    DrawioShapeElement e => e.labelStyle.color,
    RectElement e => e.labelStyle.color,
    EllipseElement e => e.labelStyle.color,
    LineElement e => e.labelStyle.color,
    ArrowElement e => e.labelStyle.color,
    PolylineElement e => e.labelStyle.color,
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

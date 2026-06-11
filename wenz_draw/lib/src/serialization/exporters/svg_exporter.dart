import 'package:flutter/material.dart';

import '../../elements/arrow_element.dart';
import '../../elements/canvas_element.dart';
import '../../elements/ellipse_element.dart';
import '../../elements/image_element.dart';
import '../../elements/line_element.dart';
import '../../elements/path_element.dart';
import '../../elements/polyline_element.dart';
import '../../elements/rect_element.dart';
import '../../elements/shape_label_painter.dart';
import '../../elements/text_element.dart';
import '../../elements/widget_element.dart';

class SvgExporter {
  const SvgExporter._();

  static String exportElements({
    required Iterable<CanvasElement> elements,
    Rect? bounds,
    Color backgroundColor = Colors.white,
  }) {
    final elementList = elements.toList(growable: false)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final exportBounds = bounds ?? _contentBounds(elementList).inflate(24);
    final buffer = StringBuffer()
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="${exportBounds.left} ${exportBounds.top} ${exportBounds.width} ${exportBounds.height}">',
      )
      ..writeln(
        '<rect x="${exportBounds.left}" y="${exportBounds.top}" width="${exportBounds.width}" height="${exportBounds.height}" fill="${_color(backgroundColor)}"/>',
      );

    for (final element in elementList) {
      buffer.writeln(_elementSvg(element));
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  static String _elementSvg(CanvasElement element) {
    return switch (element) {
      final PathElement e => _path(e),
      final PolylineElement e => _polyline(e),
      final LineElement e => _line(e),
      final RectElement e => _rect(e),
      final EllipseElement e => _ellipse(e),
      final ArrowElement e => '${_line(e)}${_arrowHead(e)}',
      final TextElement e => _text(e),
      final ImageElement e => _imagePlaceholder(e),
      final CanvasWidgetElement e => _widgetPlaceholder(e),
      _ => '',
    };
  }

  static String _path(PathElement e) {
    if (e.points.isEmpty) return '';
    final d = StringBuffer()
      ..write('M ${e.points.first.position.dx} ${e.points.first.position.dy}');
    for (final point in e.points.skip(1)) {
      d.write(' L ${point.position.dx} ${point.position.dy}');
    }
    return '<path d="$d" fill="none" stroke="${_color(e.style.color)}" stroke-width="${e.style.strokeWidth}" opacity="${e.opacity * e.style.opacity}" stroke-linecap="round" stroke-linejoin="round"/>';
  }

  static String _line(dynamic e) {
    final style = e.style;
    return '<line x1="${e.start.dx}" y1="${e.start.dy}" x2="${e.end.dx}" y2="${e.end.dy}" stroke="${_color(style.color)}" stroke-width="${style.strokeWidth}" opacity="${e.opacity * style.opacity}" stroke-linecap="round"/>';
  }

  static String _polyline(PolylineElement e) {
    if (e.points.length < 2) {
      return '';
    }
    final style = e.style;
    final points = e.points.map((point) => '${point.dx},${point.dy}').join(' ');
    return '<polyline points="$points" fill="none" stroke="${_color(style.color)}" stroke-width="${style.strokeWidth}" opacity="${e.opacity * style.opacity}" stroke-linecap="round" stroke-linejoin="round"/>';
  }

  static String _rect(RectElement e) {
    final fill = e.fillStyle == null ? 'none' : _color(e.fillStyle!.color);
    final shape =
        '<rect x="${e.rect.left}" y="${e.rect.top}" width="${e.rect.width}" height="${e.rect.height}" rx="${e.borderRadius}" fill="$fill" stroke="${_color(e.strokeStyle.color)}" stroke-width="${e.strokeStyle.strokeWidth}" opacity="${e.opacity}"/>';
    return '$shape${_shapeLabel(e.rect, e.label, e.labelStyle, e.labelAlign, e.labelPadding, e.opacity)}';
  }

  static String _ellipse(EllipseElement e) {
    final fill = e.fillStyle == null ? 'none' : _color(e.fillStyle!.color);
    final shape =
        '<ellipse cx="${e.rect.center.dx}" cy="${e.rect.center.dy}" rx="${e.rect.width / 2}" ry="${e.rect.height / 2}" fill="$fill" stroke="${_color(e.strokeStyle.color)}" stroke-width="${e.strokeStyle.strokeWidth}" opacity="${e.opacity}"/>';
    return '$shape${_shapeLabel(e.rect, e.label, e.labelStyle, e.labelAlign, e.labelPadding, e.opacity)}';
  }

  static String _arrowHead(ArrowElement e) {
    return '<circle cx="${e.end.dx}" cy="${e.end.dy}" r="${e.style.strokeWidth * 1.25}" fill="${_color(e.style.color)}" opacity="${e.opacity * e.style.opacity}"/>';
  }

  static String _shapeLabel(
    Rect rect,
    String? label,
    TextStyle style,
    TextAlign align,
    EdgeInsets padding,
    double opacity,
  ) {
    if (label == null || label.isEmpty) {
      return '';
    }
    final contentRect = padding.deflateRect(rect);
    if (contentRect.width <= 0 || contentRect.height <= 0) {
      return '';
    }
    final color = style.color ?? Colors.black;
    final size =
        style.fontSize ?? ShapeLabelPainter.defaultStyle.fontSize ?? 16;
    final weight = style.fontWeight?.value ?? FontWeight.normal.value;
    final anchor = switch (align) {
      TextAlign.center => 'middle',
      TextAlign.right || TextAlign.end => 'end',
      _ => 'start',
    };
    final x = switch (align) {
      TextAlign.center => contentRect.center.dx,
      TextAlign.right || TextAlign.end => contentRect.right,
      _ => contentRect.left,
    };
    final lines = label.split('\n');
    final lineHeight = size * (style.height ?? 1.2);
    final totalHeight = size + (lines.length - 1) * lineHeight;
    final firstBaseline = contentRect.center.dy - totalHeight / 2 + size;
    return [
      '<text x="$x" y="$firstBaseline" fill="${_color(color)}" font-size="$size" font-weight="$weight" opacity="$opacity" text-anchor="$anchor">',
      for (var i = 0; i < lines.length; i++)
        '<tspan x="$x" dy="${i == 0 ? 0 : lineHeight}">${_escape(lines[i])}</tspan>',
      '</text>',
    ].join();
  }

  static String _text(TextElement e) {
    final color = e.style.color ?? Colors.black;
    final size = e.style.fontSize ?? 24;
    final weight = e.style.fontWeight?.value ?? FontWeight.normal.value;
    final anchor = switch (e.textAlign) {
      TextAlign.center => 'middle',
      TextAlign.right || TextAlign.end => 'end',
      _ => 'start',
    };
    final x = switch (e.textAlign) {
      TextAlign.center => e.bounds.center.dx,
      TextAlign.right || TextAlign.end => e.bounds.right,
      _ => e.position.dx,
    };
    final lines = e.text.split('\n');
    final lineHeight = size * (e.style.height ?? 1.2);
    return [
      '<text x="$x" y="${e.position.dy + size}" fill="${_color(color)}" font-size="$size" font-weight="$weight" opacity="${e.opacity}" text-anchor="$anchor">',
      for (var i = 0; i < lines.length; i++)
        '<tspan x="$x" dy="${i == 0 ? 0 : lineHeight}">${_escape(lines[i])}</tspan>',
      '</text>',
    ].join();
  }

  static String _imagePlaceholder(ImageElement e) {
    return '<rect x="${e.rect.left}" y="${e.rect.top}" width="${e.rect.width}" height="${e.rect.height}" fill="#e5e7eb" stroke="#64748b"/>';
  }

  static String _widgetPlaceholder(CanvasWidgetElement e) {
    return '<rect x="${e.worldRect.left}" y="${e.worldRect.top}" width="${e.worldRect.width}" height="${e.worldRect.height}" fill="#f3f4f6" stroke="#9ca3af" stroke-width="1.5" rx="4"/>'
        '<text x="${e.worldRect.center.dx}" y="${e.worldRect.center.dy}" fill="#6b7280" font-size="14" text-anchor="middle" dominant-baseline="central">${_escape(e.widgetType)}</text>';
  }

  static Rect _contentBounds(List<CanvasElement> elements) {
    if (elements.isEmpty) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    var bounds = elements.first.bounds;
    for (final element in elements.skip(1)) {
      bounds = bounds.expandToInclude(element.bounds);
    }
    return bounds;
  }

  static String _color(Color color) {
    final value = color.toARGB32();
    return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}

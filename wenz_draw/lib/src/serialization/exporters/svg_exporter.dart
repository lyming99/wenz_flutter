import 'dart:math' as math show cos, pi, sin;
import 'dart:ui' show Offset, Rect;

import '../../elements/arrow_element.dart';
import '../../elements/canvas_element.dart';
import '../../elements/ellipse_element.dart';
import '../../elements/line_element.dart';
import '../../elements/path_element.dart';
import '../../elements/rect_element.dart';
import '../../elements/text_element.dart';

// ---------------------------------------------------------------------------
// SvgExporter
// ---------------------------------------------------------------------------

/// SVG 导出器。
///
/// 将 [CanvasElement] 列表转换为 SVG 字符串。
class SvgExporter {
  /// 将元素列表导出为 SVG 字符串。
  ///
  /// [elements] 要导出的元素列表。
  /// [contentBounds] 内容包围盒（世界坐标）。
  /// [backgroundColor] 背景颜色（ARGB 32-bit），默认白色。
  static String exportToSvg({
    required List<CanvasElement> elements,
    required Rect contentBounds,
    int backgroundColor = 0xFFFFFFFF,
  }) {
    final buffer = StringBuffer();

    // SVG 头部
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${_fmt(contentBounds.width)}" '
      'height="${_fmt(contentBounds.height)}" '
      'viewBox="${_fmt(contentBounds.left)} ${_fmt(contentBounds.top)} '
      '${_fmt(contentBounds.width)} ${_fmt(contentBounds.height)}">',
    );

    // 背景
    buffer.writeln(
      '  <rect x="${_fmt(contentBounds.left)}" '
      'y="${_fmt(contentBounds.top)}" '
      'width="${_fmt(contentBounds.width)}" '
      'height="${_fmt(contentBounds.height)}" '
      'fill="${_colorToHex(backgroundColor)}" />',
    );

    // 遍历元素
    for (final element in elements) {
      if (!element.visible) continue;
      _writeElement(buffer, element);
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  // ─── 元素分发 ─────────────────────────────────────────────

  static void _writeElement(StringBuffer buffer, CanvasElement element) {
    switch (element) {
      case PathElement():
        _writePath(buffer, element);
      case LineElement():
        _writeLine(buffer, element);
      case RectElement():
        _writeRect(buffer, element);
      case EllipseElement():
        _writeEllipse(buffer, element);
      case ArrowElement():
        _writeArrow(buffer, element);
      case TextElement():
        _writeText(buffer, element);
    }
  }

  // ─── PathElement ──────────────────────────────────────────

  static void _writePath(StringBuffer buffer, PathElement element) {
    if (element.points.isEmpty) return;

    final pointsStr = element.points
        .map((p) => '${_fmt(p.position.dx)},${_fmt(p.position.dy)}')
        .join(' ');

    final style = element.style;
    final alpha = (style.opacity * element.opacity).clamp(0.0, 1.0);

    buffer.writeln(
      '  <polyline points="$pointsStr" '
      'stroke="${_colorToHex(style.color)}" '
      'stroke-width="${_fmt(style.strokeWidth)}" '
      'fill="none" '
      'stroke-linecap="${_strokeCap(style.strokeCap)}" '
      'stroke-linejoin="${_strokeJoin(style.strokeJoin)}" '
      'opacity="${_fmt(alpha)}" />',
    );
  }

  // ─── LineElement ──────────────────────────────────────────

  static void _writeLine(StringBuffer buffer, LineElement element) {
    final style = element.style;
    final alpha = (style.opacity * element.opacity).clamp(0.0, 1.0);

    buffer.writeln(
      '  <line '
      'x1="${_fmt(element.start.dx)}" y1="${_fmt(element.start.dy)}" '
      'x2="${_fmt(element.end.dx)}" y2="${_fmt(element.end.dy)}" '
      'stroke="${_colorToHex(style.color)}" '
      'stroke-width="${_fmt(style.strokeWidth)}" '
      'stroke-linecap="${_strokeCap(style.strokeCap)}" '
      'opacity="${_fmt(alpha)}" />',
    );
  }

  // ─── RectElement ──────────────────────────────────────────

  static void _writeRect(StringBuffer buffer, RectElement element) {
    final strokeStyle = element.stroke;
    final strokeAlpha = (strokeStyle.opacity * element.opacity)
        .clamp(0.0, 1.0);

    final fillAttr = element.fill != null
        ? 'fill="${_colorToHex(element.fill!.color)}" '
            'fill-opacity="${_fmt(element.fill!.opacity * element.opacity)}"'
        : 'fill="none"';

    final rxAttr = element.borderRadius > 0
        ? 'rx="${_fmt(element.borderRadius)}" ry="${_fmt(element.borderRadius)}" '
        : '';

    buffer.writeln(
      '  <rect '
      'x="${_fmt(element.rect.left)}" y="${_fmt(element.rect.top)}" '
      'width="${_fmt(element.rect.width)}" height="${_fmt(element.rect.height)}" '
      '$rxAttr'
      'stroke="${_colorToHex(strokeStyle.color)}" '
      'stroke-width="${_fmt(strokeStyle.strokeWidth)}" '
      'stroke-linecap="${_strokeCap(strokeStyle.strokeCap)}" '
      'stroke-linejoin="${_strokeJoin(strokeStyle.strokeJoin)}" '
      'stroke-opacity="${_fmt(strokeAlpha)}" '
      '$fillAttr />',
    );
  }

  // ─── EllipseElement ───────────────────────────────────────

  static void _writeEllipse(StringBuffer buffer, EllipseElement element) {
    final cx = element.rect.center.dx;
    final cy = element.rect.center.dy;
    final rx = element.rect.width / 2;
    final ry = element.rect.height / 2;

    final strokeStyle = element.stroke;
    final strokeAlpha = (strokeStyle.opacity * element.opacity)
        .clamp(0.0, 1.0);

    final fillAttr = element.fill != null
        ? 'fill="${_colorToHex(element.fill!.color)}" '
            'fill-opacity="${_fmt(element.fill!.opacity * element.opacity)}"'
        : 'fill="none"';

    buffer.writeln(
      '  <ellipse '
      'cx="${_fmt(cx)}" cy="${_fmt(cy)}" '
      'rx="${_fmt(rx)}" ry="${_fmt(ry)}" '
      'stroke="${_colorToHex(strokeStyle.color)}" '
      'stroke-width="${_fmt(strokeStyle.strokeWidth)}" '
      'stroke-linecap="${_strokeCap(strokeStyle.strokeCap)}" '
      'stroke-linejoin="${_strokeJoin(strokeStyle.strokeJoin)}" '
      'stroke-opacity="${_fmt(strokeAlpha)}" '
      '$fillAttr />',
    );
  }

  // ─── ArrowElement ─────────────────────────────────────────

  static void _writeArrow(StringBuffer buffer, ArrowElement element) {
    final style = element.style;
    final alpha = (style.opacity * element.opacity).clamp(0.0, 1.0);

    // 线段
    buffer.writeln(
      '  <line '
      'x1="${_fmt(element.start.dx)}" y1="${_fmt(element.start.dy)}" '
      'x2="${_fmt(element.end.dx)}" y2="${_fmt(element.end.dy)}" '
      'stroke="${_colorToHex(style.color)}" '
      'stroke-width="${_fmt(style.strokeWidth)}" '
      'stroke-linecap="${_strokeCap(style.strokeCap)}" '
      'opacity="${_fmt(alpha)}" />',
    );

    // 箭头头部（三角形）
    final arrowPoints = _buildArrowHeadPoints(
      element.end,
      element.start,
      element.arrowHeadSize,
    );
    if (arrowPoints != null) {
      buffer.writeln(
        '  <polygon '
        'points="$arrowPoints" '
        'fill="${_colorToHex(style.color)}" '
        'opacity="${_fmt(alpha)}" />',
      );
    }
  }

  // ─── TextElement ──────────────────────────────────────────

  static void _writeText(StringBuffer buffer, TextElement element) {
    final alpha = element.opacity.clamp(0.0, 1.0);
    final escapedText = _escapeXml(element.text);

    buffer.writeln(
      '  <text '
      'x="${_fmt(element.position.dx)}" '
      'y="${_fmt(element.position.dy + element.fontSize)}" '
      'font-size="${_fmt(element.fontSize)}" '
      'fill="${_colorToHex(element.color)}" '
      'opacity="${_fmt(alpha)}"'
      '${element.bold ? ' font-weight="bold"' : ''}>'
      '$escapedText</text>',
    );
  }

  // ─── 箭头头部计算 ──────────────────────────────────────────

  /// 计算箭头头部三角形的三个顶点，返回 SVG points 字符串。
  static String? _buildArrowHeadPoints(
    Offset tip,
    Offset from,
    double size,
  ) {
    final direction = tip - from;
    final length = direction.distance;
    if (length == 0) return null;

    final unitDir = direction / length;
    const angle = 25.0 * math.pi / 180.0;

    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    final dir1 = Offset(
      unitDir.dx * cosA - unitDir.dy * sinA,
      unitDir.dx * sinA + unitDir.dy * cosA,
    );
    final dir2 = Offset(
      unitDir.dx * cosA + unitDir.dy * sinA,
      -unitDir.dx * sinA + unitDir.dy * cosA,
    );

    final p1 = tip - dir1 * size;
    final p2 = tip - dir2 * size;

    return '${_fmt(tip.dx)},${_fmt(tip.dy)} '
        '${_fmt(p1.dx)},${_fmt(p1.dy)} '
        '${_fmt(p2.dx)},${_fmt(p2.dy)}';
  }

  // ─── 工具方法 ─────────────────────────────────────────────

  /// 将 ARGB 32-bit 颜色转为 `#RRGGBB` 字符串。
  static String _colorToHex(int color) {
    return '#${(color & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  /// 线帽样式映射。
  static String _strokeCap(int cap) {
    switch (cap) {
      case 0:
        return 'butt';
      case 1:
        return 'round';
      case 2:
        return 'square';
      default:
        return 'round';
    }
  }

  /// 线连接样式映射。
  static String _strokeJoin(int join) {
    switch (join) {
      case 0:
        return 'miter';
      case 1:
        return 'round';
      case 2:
        return 'bevel';
      default:
        return 'round';
    }
  }

  /// 格式化浮点数（去掉尾部多余零）。
  static String _fmt(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  /// XML 特殊字符转义。
  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

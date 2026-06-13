import 'package:flutter/material.dart';

import '../canvas/paint_style.dart';
import '../elements/drawio_shape_element.dart';
import '../elements/shape_label_painter.dart';
import 'drawio_color.dart';
import 'drawio_style.dart';
import 'drawio_style_parser.dart';

class DrawioShapeAdapter {
  const DrawioShapeAdapter._();

  static DrawioShapeElement fromStyleString({
    required String id,
    required Rect rect,
    required String style,
    String? label,
    String layerId = 'default',
    int zIndex = 0,
  }) {
    return fromStyle(
      id: id,
      rect: rect,
      style: DrawioStyleParser.parse(style),
      label: label,
      layerId: layerId,
      zIndex: zIndex,
    );
  }

  static DrawioShapeElement fromStyle({
    required String id,
    required Rect rect,
    required DrawioStyle style,
    String? label,
    String layerId = 'default',
    int zIndex = 0,
  }) {
    final shapeKey = _shapeKey(style);
    final opacity = DrawioColor.opacityFromPercent(style['opacity']);
    final fillColor = DrawioColor.parse(style['fillColor'] ?? '#ffffff');
    final strokeColor = DrawioColor.parse(style['strokeColor'] ?? '#000000');
    final strokeWidth = style.doubleValue('strokeWidth') ?? 1.0;
    final fillOpacity = DrawioColor.opacityFromPercent(
      style['fillOpacity'],
      fallback: opacity,
    );
    final strokeOpacity = DrawioColor.opacityFromPercent(
      style['strokeOpacity'],
      fallback: opacity,
    );

    return DrawioShapeElement(
      id: id,
      shapeKey: shapeKey,
      rect: rect,
      strokeStyle: PaintStyle(
        color: strokeColor ?? Colors.transparent,
        strokeWidth: strokeColor == null ? 0 : strokeWidth,
        opacity: strokeColor == null ? 0 : strokeOpacity,
      ),
      fillStyle: fillColor == null
          ? null
          : PaintStyle(
              color: fillColor,
              opacity: fillOpacity,
              paintingStyle: PaintingStyle.fill,
            ),
      properties: _properties(style),
      label: label,
      labelStyle: _labelStyle(style),
      labelAlign: _labelAlign(style),
      labelPadding: _labelPadding(style),
      layerId: layerId,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  static String _shapeKey(DrawioStyle style) {
    final raw = style['shape'];
    if (raw == null || raw.isEmpty) {
      return style.boolValue('rounded') ? 'roundedRectangle' : 'rectangle';
    }
    final normalized = _normalizeShapeKey(raw);
    if (normalized != null) {
      return normalized;
    }
    return switch (raw) {
      'rect' => 'rectangle',
      'process' => 'flowchart.process',
      'rounded' => 'roundedRectangle',
      'manualInput' => 'flowchart.manualInput',
      'isoRectangle' => 'cube',
      _ => raw,
    };
  }

  static String? _normalizeShapeKey(String raw) {
    const aliases = <String, String>{
      'mxgraph.flowchart.annotation_1': 'flowchart.annotation1',
      'mxgraph.flowchart.annotation-1': 'flowchart.annotation1',
      'mxgraph.flowchart.annotation1': 'flowchart.annotation1',
      'mxgraph.flowchart.annotation_2': 'flowchart.annotation2',
      'mxgraph.flowchart.annotation-2': 'flowchart.annotation2',
      'mxgraph.flowchart.annotation2': 'flowchart.annotation2',
      'mxgraph.flowchart.extract_or_measurement':
          'flowchart.extractOrMeasurement',
      'mxgraph.flowchart.extract-or-measurement':
          'flowchart.extractOrMeasurement',
      'mxgraph.flowchart.direct_data': 'flowchart.directData',
      'mxgraph.flowchart.direct-data': 'flowchart.directData',
      'mxgraph.flowchart.internal_storage': 'flowchart.internalStorage',
      'mxgraph.flowchart.internal-storage': 'flowchart.internalStorage',
      'mxgraph.flowchart.loop_limit': 'flowchart.loopLimit',
      'mxgraph.flowchart.loop-limit': 'flowchart.loopLimit',
      'mxgraph.flowchart.manual_input': 'flowchart.manualInput',
      'mxgraph.flowchart.manual-input': 'flowchart.manualInput',
      'mxgraph.flowchart.manual_operation': 'flowchart.manualOperation',
      'mxgraph.flowchart.manual-operation': 'flowchart.manualOperation',
      'mxgraph.flowchart.merge_or_storage': 'flowchart.mergeOrStorage',
      'mxgraph.flowchart.merge-or-storage': 'flowchart.mergeOrStorage',
      'mxgraph.flowchart.multi_document': 'flowchart.multiDocument',
      'mxgraph.flowchart.multi-document': 'flowchart.multiDocument',
      'mxgraph.flowchart.off_page_reference': 'flowchart.offPageReference',
      'mxgraph.flowchart.off-page-reference': 'flowchart.offPageReference',
      'mxgraph.flowchart.on_page_reference': 'flowchart.onPageReference',
      'mxgraph.flowchart.on-page-reference': 'flowchart.onPageReference',
      'mxgraph.flowchart.paper_tape': 'flowchart.paperTape',
      'mxgraph.flowchart.paper-tape': 'flowchart.paperTape',
      'mxgraph.flowchart.parallel_mode': 'flowchart.parallelMode',
      'mxgraph.flowchart.parallel-mode': 'flowchart.parallelMode',
      'mxgraph.flowchart.predefined_process': 'flowchart.predefinedProcess',
      'mxgraph.flowchart.predefined-process': 'flowchart.predefinedProcess',
      'mxgraph.flowchart.sequential_data': 'flowchart.sequentialData',
      'mxgraph.flowchart.sequential-data': 'flowchart.sequentialData',
      'mxgraph.flowchart.start_1': 'flowchart.start1',
      'mxgraph.flowchart.start-1': 'flowchart.start1',
      'mxgraph.flowchart.start1': 'flowchart.start1',
      'mxgraph.flowchart.start_2': 'flowchart.start2',
      'mxgraph.flowchart.start-2': 'flowchart.start2',
      'mxgraph.flowchart.start2': 'flowchart.start2',
      'mxgraph.flowchart.stored_data': 'flowchart.storedData',
      'mxgraph.flowchart.stored-data': 'flowchart.storedData',
      'mxgraph.flowchart.summing_function': 'flowchart.summingFunction',
      'mxgraph.flowchart.summing-function': 'flowchart.summingFunction',
      'card': 'flowchart.card',
      'tape': 'flowchart.paperTape',
      'delay': 'flowchart.delay',
      'data': 'flowchart.data',
      'database': 'flowchart.database',
      'document': 'flowchart.document',
      'decision': 'flowchart.decision',
      'terminator': 'flowchart.terminator',
      'preparation': 'flowchart.preparation',
      'manual-input': 'flowchart.manualInput',
      'manual_input': 'flowchart.manualInput',
      'mxgraph.basic.4PointStar': 'basic.4PointStar',
      'mxgraph.basic.4_point_star': 'basic.4PointStar',
      'mxgraph.basic.4-point-star': 'basic.4PointStar',
      'mxgraph.basic.6PointStar': 'basic.6PointStar',
      'mxgraph.basic.6_point_star': 'basic.6PointStar',
      'mxgraph.basic.6-point-star': 'basic.6PointStar',
      'mxgraph.basic.8PointStar': 'basic.8PointStar',
      'mxgraph.basic.8_point_star': 'basic.8PointStar',
      'mxgraph.basic.8-point-star': 'basic.8PointStar',
      'mxgraph.basic.banner': 'basic.banner',
      'mxgraph.basic.cloudCallout': 'basic.cloudCallout',
      'mxgraph.basic.cloud_callout': 'basic.cloudCallout',
      'mxgraph.basic.cloud-callout': 'basic.cloudCallout',
      'mxgraph.basic.cloudRect': 'basic.cloudRect',
      'mxgraph.basic.cloud_rect': 'basic.cloudRect',
      'mxgraph.basic.cloud-rect': 'basic.cloudRect',
      'mxgraph.basic.cone': 'basic.cone',
      'mxgraph.basic.cross': 'basic.cross',
      'mxgraph.basic.document': 'basic.document',
      'mxgraph.basic.flash': 'basic.flash',
      'mxgraph.basic.halfCircle': 'basic.halfCircle',
      'mxgraph.basic.half_circle': 'basic.halfCircle',
      'mxgraph.basic.half-circle': 'basic.halfCircle',
      'mxgraph.basic.heart': 'basic.heart',
      'mxgraph.basic.loudCallout': 'basic.loudCallout',
      'mxgraph.basic.loud_callout': 'basic.loudCallout',
      'mxgraph.basic.loud-callout': 'basic.loudCallout',
      'mxgraph.basic.moon': 'basic.moon',
      'mxgraph.basic.noSymbol': 'basic.noSymbol',
      'mxgraph.basic.no_symbol': 'basic.noSymbol',
      'mxgraph.basic.no-symbol': 'basic.noSymbol',
      'mxgraph.basic.octagon': 'basic.octagon',
      'mxgraph.basic.orthogonalTriangle': 'basic.orthogonalTriangle',
      'mxgraph.basic.orthogonal_triangle': 'basic.orthogonalTriangle',
      'mxgraph.basic.orthogonal-triangle': 'basic.orthogonalTriangle',
      'mxgraph.basic.ovalCallout': 'basic.ovalCallout',
      'mxgraph.basic.oval_callout': 'basic.ovalCallout',
      'mxgraph.basic.oval-callout': 'basic.ovalCallout',
      'mxgraph.basic.parallelepiped': 'basic.parallelepiped',
      'mxgraph.basic.pentagon': 'basic.pentagon',
      'mxgraph.basic.pointedOval': 'basic.pointedOval',
      'mxgraph.basic.pointed_oval': 'basic.pointedOval',
      'mxgraph.basic.pointed-oval': 'basic.pointedOval',
      'mxgraph.basic.rectangularCallout': 'basic.rectangularCallout',
      'mxgraph.basic.rectangular_callout': 'basic.rectangularCallout',
      'mxgraph.basic.rectangular-callout': 'basic.rectangularCallout',
      'mxgraph.basic.roundedRectangularCallout':
          'basic.roundedRectangularCallout',
      'mxgraph.basic.rounded_rectangular_callout':
          'basic.roundedRectangularCallout',
      'mxgraph.basic.rounded-rectangular-callout':
          'basic.roundedRectangularCallout',
      'mxgraph.basic.smiley': 'basic.smiley',
      'mxgraph.basic.star': 'basic.star',
      'mxgraph.basic.sun': 'basic.sun',
      'mxgraph.basic.tick': 'basic.tick',
      'mxgraph.basic.trapezoid': 'basic.trapezoid',
      'mxgraph.basic.wave': 'basic.wave',
      'mxgraph.basic.x': 'basic.x',
      'cross': 'basic.cross',
      'star': 'basic.star',
    };
    if (aliases.containsKey(raw)) {
      return aliases[raw];
    }
    if (raw.startsWith('mxgraph.flowchart.')) {
      return 'flowchart.${_toLowerCamelShapeSuffix(raw.substring('mxgraph.flowchart.'.length))}';
    }
    if (raw.startsWith('mxgraph.basic.')) {
      return 'basic.${_toLowerCamelShapeSuffix(raw.substring('mxgraph.basic.'.length))}';
    }
    if (raw.startsWith('mxgraph.arrows.')) {
      return 'arrows.${_toLowerCamelShapeSuffix(raw.substring('mxgraph.arrows.'.length))}';
    }
    return null;
  }

  static String _toLowerCamelShapeSuffix(String suffix) {
    if (!suffix.contains('_') &&
        !suffix.contains('-') &&
        !suffix.contains(' ') &&
        suffix.isNotEmpty &&
        suffix[0] == suffix[0].toLowerCase()) {
      return suffix;
    }
    final parts = suffix
        .split(RegExp(r'[_\-\s]+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return suffix;
    }
    String normalizePart(String part, {required bool first}) {
      final lower = part.toLowerCase();
      return first ? lower : '${lower[0].toUpperCase()}${lower.substring(1)}';
    }

    return [
      normalizePart(parts.first, first: true),
      for (final part in parts.skip(1)) normalizePart(part, first: false),
    ].join();
  }

  static Map<String, dynamic> _properties(DrawioStyle style) {
    final properties = <String, dynamic>{
      'drawioStyle': style.raw,
      ...style.extra,
    };
    for (final key in const [
      'direction',
      'flipH',
      'flipV',
      'absoluteArcSize',
      'boundedLbl',
      'backgroundOutline',
      'verticalLabelPosition',
      'verticalAlign',
      'labelPosition',
    ]) {
      final value = style[key];
      if (value != null && value.isNotEmpty) {
        properties[key] = value;
      }
    }
    for (final key in const ['arcSize', 'size']) {
      final value = style.doubleValue(key);
      if (value != null) {
        properties[key] = value;
      } else {
        final raw = style[key];
        if (raw != null && raw.isNotEmpty) {
          properties[key] = raw;
        }
      }
    }
    for (final key in const [
      'flipH',
      'flipV',
      'absoluteArcSize',
      'boundedLbl',
      'backgroundOutline',
    ]) {
      if (style.boolValue(key)) {
        properties[key] = true;
      }
    }
    if (style.boolValue('rounded')) {
      properties['rounded'] = true;
    }
    if (style.boolValue('dashed')) {
      properties['dashed'] = true;
    }
    return Map<String, dynamic>.unmodifiable(properties);
  }

  static TextStyle _labelStyle(DrawioStyle style) {
    final color = DrawioColor.parse(style['fontColor']) ?? Colors.black;
    final size =
        style.doubleValue('fontSize') ??
        ShapeLabelPainter.defaultStyle.fontSize ??
        16;
    final fontStyle = style.intValue('fontStyle') ?? 0;
    return ShapeLabelPainter.defaultStyle.copyWith(
      color: color,
      fontSize: size,
      height: ShapeLabelPainter.defaultStyle.height,
      fontWeight: (fontStyle & 1) != 0 ? FontWeight.bold : FontWeight.normal,
      fontStyle: (fontStyle & 2) != 0 ? FontStyle.italic : FontStyle.normal,
      decoration: (fontStyle & 4) != 0 ? TextDecoration.underline : null,
      fontFamily: style['fontFamily'],
    );
  }

  static TextAlign _labelAlign(DrawioStyle style) {
    return switch (style['align']) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      _ => TextAlign.center,
    };
  }

  static EdgeInsets _labelPadding(DrawioStyle style) {
    final base =
        style.doubleValue('spacing') ?? ShapeLabelPainter.defaultPadding.left;
    return EdgeInsets.fromLTRB(
      style.doubleValue('spacingLeft') ?? base,
      style.doubleValue('spacingTop') ?? base,
      style.doubleValue('spacingRight') ?? base,
      style.doubleValue('spacingBottom') ?? base,
    );
  }
}

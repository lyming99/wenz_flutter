import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shape_connection_points.dart';
import 'shape_definition.dart';
import 'shape_definition_registry.dart';

class DrawioShapeDefinitions {
  const DrawioShapeDefinitions._();

  static void registerAll() {
    ShapeDefinitionRegistry.register(
      _rectangle,
      aliases: const ['rect', 'process'],
    );
    ShapeDefinitionRegistry.register(
      _roundedRectangle,
      aliases: const ['rounded'],
    );
    ShapeDefinitionRegistry.register(_ellipse, aliases: const ['circle']);
    ShapeDefinitionRegistry.register(_rhombus, aliases: const ['diamond']);
    ShapeDefinitionRegistry.register(_triangle);
    ShapeDefinitionRegistry.register(_hexagon);
    ShapeDefinitionRegistry.register(
      _parallelogram,
      aliases: const ['manualInput'],
    );
    ShapeDefinitionRegistry.register(_trapezoid);
    ShapeDefinitionRegistry.register(_cylinder, aliases: const ['cylinder3']);
    ShapeDefinitionRegistry.register(_doubleEllipse);
    ShapeDefinitionRegistry.register(_actor);
    ShapeDefinitionRegistry.register(_cloud);
    ShapeDefinitionRegistry.register(_swimlane);
    ShapeDefinitionRegistry.register(_document);
    ShapeDefinitionRegistry.register(_note);
    ShapeDefinitionRegistry.register(_callout);
    ShapeDefinitionRegistry.register(_plus);
    ShapeDefinitionRegistry.register(_cross);
    ShapeDefinitionRegistry.register(_step);
    ShapeDefinitionRegistry.register(_cube, aliases: const ['isoRectangle']);
  }

  static final ShapeDefinition _rectangle = ShapeDefinition(
    key: 'rectangle',
    buildPath: (rect, _) => Path()..addRect(rect),
    buildSvgPath: (rect, _) => _rectSvgPath(rect),
    buildOutline: (rect, _) => [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ],
    buildConnectionPoints: (rect, _) => ShapeConnectionPoints.rectangle(rect),
  );

  static final ShapeDefinition _roundedRectangle = ShapeDefinition(
    key: 'roundedRectangle',
    buildPath: (rect, properties) {
      final radius = _radius(rect, properties);
      return Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    },
    buildSvgPath: (rect, properties) {
      final radius = _radius(rect, properties);
      return _roundedRectSvgPath(rect, radius);
    },
    buildConnectionPoints: (rect, _) => ShapeConnectionPoints.rectangle(rect),
  );

  static final ShapeDefinition _ellipse = ShapeDefinition(
    key: 'ellipse',
    buildPath: (rect, _) => Path()..addOval(rect),
    buildSvgPath: (rect, _) => _ellipseSvgPath(rect),
    buildOutline: (rect, _) => _ellipseOutline(rect),
    buildConnectionPoints: (rect, _) => ShapeConnectionPoints.ellipse(rect),
  );

  static final ShapeDefinition _rhombus = ShapeDefinition(
    key: 'rhombus',
    buildPath: (rect, _) => _polygonPath(_rhombusPoints(rect)),
    buildSvgPath: (rect, _) => _polygonSvgPath(_rhombusPoints(rect)),
    buildOutline: (rect, _) => _rhombusPoints(rect),
    buildConnectionPoints: (rect, _) =>
        ShapeConnectionPoints.polygon(_rhombusPoints(rect)),
  );

  static final ShapeDefinition _triangle = ShapeDefinition(
    key: 'triangle',
    buildPath: (rect, properties) =>
        _polygonPath(_trianglePoints(rect, _direction(properties))),
    buildSvgPath: (rect, properties) =>
        _polygonSvgPath(_trianglePoints(rect, _direction(properties))),
    buildOutline: (rect, properties) =>
        _trianglePoints(rect, _direction(properties)),
    buildConnectionPoints: (rect, properties) => ShapeConnectionPoints.polygon(
      _trianglePoints(rect, _direction(properties)),
    ),
  );

  static final ShapeDefinition _hexagon = ShapeDefinition(
    key: 'hexagon',
    buildPath: (rect, _) => _polygonPath(_hexagonPoints(rect)),
    buildSvgPath: (rect, _) => _polygonSvgPath(_hexagonPoints(rect)),
    buildOutline: (rect, _) => _hexagonPoints(rect),
    buildConnectionPoints: (rect, _) =>
        ShapeConnectionPoints.polygon(_hexagonPoints(rect)),
  );

  static final ShapeDefinition _parallelogram = ShapeDefinition(
    key: 'parallelogram',
    buildPath: (rect, properties) =>
        _polygonPath(_parallelogramPoints(rect, properties)),
    buildSvgPath: (rect, properties) =>
        _polygonSvgPath(_parallelogramPoints(rect, properties)),
    buildOutline: (rect, properties) => _parallelogramPoints(rect, properties),
    buildConnectionPoints: (rect, properties) =>
        ShapeConnectionPoints.polygon(_parallelogramPoints(rect, properties)),
  );

  static final ShapeDefinition _trapezoid = ShapeDefinition(
    key: 'trapezoid',
    buildPath: (rect, properties) =>
        _polygonPath(_trapezoidPoints(rect, properties)),
    buildSvgPath: (rect, properties) =>
        _polygonSvgPath(_trapezoidPoints(rect, properties)),
    buildOutline: (rect, properties) => _trapezoidPoints(rect, properties),
    buildConnectionPoints: (rect, properties) =>
        ShapeConnectionPoints.polygon(_trapezoidPoints(rect, properties)),
  );

  static final ShapeDefinition _cylinder = ShapeDefinition(
    key: 'cylinder',
    buildPath: (rect, properties) => _cylinderPath(rect, properties),
    buildSvgPath: (rect, properties) => _cylinderSvgPath(rect, properties),
    buildForegroundPaths: (rect, properties) => [
      _cylinderTopPath(rect, properties),
    ],
    buildForegroundSvgPaths: (rect, properties) => [
      _cylinderTopSvgPath(rect, properties),
    ],
  );

  static final ShapeDefinition _doubleEllipse = ShapeDefinition(
    key: 'doubleEllipse',
    buildPath: (rect, _) => Path()..addOval(rect),
    buildSvgPath: (rect, _) => _ellipseSvgPath(rect),
    buildForegroundPaths: (rect, properties) => [
      Path()..addOval(rect.deflate(_doubleEllipseInset(rect, properties))),
    ],
    buildForegroundSvgPaths: (rect, properties) => [
      _ellipseSvgPath(rect.deflate(_doubleEllipseInset(rect, properties))),
    ],
    buildLabelRect: (rect, properties) =>
        rect.deflate(_doubleEllipseInset(rect, properties)),
    buildOutline: (rect, _) => _ellipseOutline(rect),
    buildConnectionPoints: (rect, _) => ShapeConnectionPoints.ellipse(rect),
  );

  static final ShapeDefinition _actor = ShapeDefinition(
    key: 'actor',
    buildPath: (rect, _) => _actorPath(rect),
    buildSvgPath: (rect, _) => _pathToSvg(_actorPath(rect)),
  );

  static final ShapeDefinition _cloud = ShapeDefinition(
    key: 'cloud',
    buildPath: (rect, _) => _cloudPath(rect),
    buildSvgPath: (rect, _) => _pathToSvg(_cloudPath(rect)),
  );

  static final ShapeDefinition _swimlane = ShapeDefinition(
    key: 'swimlane',
    buildPath: (rect, _) => Path()..addRect(rect),
    buildSvgPath: (rect, _) => _rectSvgPath(rect),
    buildForegroundPaths: (rect, properties) => [
      _swimlaneDivider(rect, properties),
    ],
    buildForegroundSvgPaths: (rect, properties) => [
      _pathToSvg(_swimlaneDivider(rect, properties)),
    ],
    buildLabelRect: (rect, properties) {
      final header = _swimlaneHeader(rect, properties);
      return Rect.fromLTWH(rect.left, rect.top, rect.width, header);
    },
    buildOutline: (rect, _) => [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ],
    buildConnectionPoints: (rect, properties) => ShapeConnectionPoints.swimlane(
      rect,
      headerHeight: _swimlaneHeader(rect, properties),
    ),
  );

  static final ShapeDefinition _document = ShapeDefinition(
    key: 'document',
    buildPath: (rect, properties) => _documentPath(rect, properties),
    buildSvgPath: (rect, properties) =>
        _pathToSvg(_documentPath(rect, properties)),
  );

  static final ShapeDefinition _note = ShapeDefinition(
    key: 'note',
    buildPath: (rect, properties) => _notePath(rect, properties),
    buildSvgPath: (rect, properties) => _pathToSvg(_notePath(rect, properties)),
    buildForegroundPaths: (rect, properties) => [
      _noteFoldPath(rect, properties),
    ],
    buildForegroundSvgPaths: (rect, properties) => [
      _pathToSvg(_noteFoldPath(rect, properties)),
    ],
  );

  static final ShapeDefinition _callout = ShapeDefinition(
    key: 'callout',
    buildPath: (rect, properties) => _calloutPath(rect, properties),
    buildSvgPath: (rect, properties) =>
        _pathToSvg(_calloutPath(rect, properties)),
    buildLabelRect: (rect, properties) {
      final tail = _number(
        properties,
        'tailHeight',
        rect.height * 0.28,
      ).clamp(0.0, rect.height * 0.5).toDouble();
      return Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - tail);
    },
  );

  static final ShapeDefinition _plus = ShapeDefinition(
    key: 'plus',
    buildPath: (rect, properties) => _orthogonalSymbolPath(rect, properties),
    buildSvgPath: (rect, properties) =>
        _pathToSvg(_orthogonalSymbolPath(rect, properties)),
  );

  static final ShapeDefinition _cross = ShapeDefinition(
    key: 'cross',
    buildPath: (rect, properties) => _diagonalCrossPath(rect, properties),
    buildSvgPath: (rect, properties) =>
        _pathToSvg(_diagonalCrossPath(rect, properties)),
  );

  static final ShapeDefinition _step = ShapeDefinition(
    key: 'step',
    buildPath: (rect, properties) =>
        _polygonPath(_stepPoints(rect, properties)),
    buildSvgPath: (rect, properties) =>
        _polygonSvgPath(_stepPoints(rect, properties)),
    buildOutline: (rect, properties) => _stepPoints(rect, properties),
    buildConnectionPoints: (rect, properties) =>
        ShapeConnectionPoints.polygon(_stepPoints(rect, properties)),
  );

  static final ShapeDefinition _cube = ShapeDefinition(
    key: 'cube',
    buildPath: (rect, properties) => _cubePath(rect, properties),
    buildSvgPath: (rect, properties) => _pathToSvg(_cubePath(rect, properties)),
    buildForegroundPaths: (rect, properties) =>
        _cubeForeground(rect, properties),
    buildForegroundSvgPaths: (rect, properties) => [
      for (final path in _cubeForeground(rect, properties)) _pathToSvg(path),
    ],
  );

  static String _direction(Map<String, dynamic> properties) {
    return properties['direction'] as String? ?? 'east';
  }

  static double _number(
    Map<String, dynamic> properties,
    String key,
    double fallback,
  ) {
    final value = properties[key];
    return value is num ? value.toDouble() : fallback;
  }

  static double _radius(Rect rect, Map<String, dynamic> properties) {
    final defaultRadius = math.min(rect.width, rect.height) * 0.12;
    return _number(
      properties,
      'radius',
      defaultRadius,
    ).clamp(0.0, math.min(rect.width, rect.height) / 2).toDouble();
  }

  static double _cylinderCap(Rect rect, Map<String, dynamic> properties) {
    final fallback = math.min(rect.height * 0.18, rect.width / 3);
    return _number(
      properties,
      'capHeight',
      fallback,
    ).clamp(0.0, rect.height / 2).toDouble();
  }

  static double _doubleEllipseInset(
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    final fallback = math.min(6.0, math.min(rect.width, rect.height) / 5);
    return _number(
      properties,
      'inset',
      fallback,
    ).clamp(0.0, math.min(rect.width, rect.height) / 2).toDouble();
  }

  static List<Offset> _rhombusPoints(Rect rect) {
    return [
      rect.topCenter,
      rect.centerRight,
      rect.bottomCenter,
      rect.centerLeft,
    ];
  }

  static List<Offset> _trianglePoints(Rect rect, String direction) {
    return switch (direction) {
      'north' => [rect.bottomLeft, rect.topCenter, rect.bottomRight],
      'south' => [rect.topLeft, rect.bottomCenter, rect.topRight],
      'west' => [rect.topRight, rect.centerLeft, rect.bottomRight],
      _ => [rect.topLeft, rect.centerRight, rect.bottomLeft],
    };
  }

  static List<Offset> _hexagonPoints(Rect rect) {
    final inset = rect.width * 0.25;
    return [
      Offset(rect.left + inset, rect.top),
      Offset(rect.right - inset, rect.top),
      rect.centerRight,
      Offset(rect.right - inset, rect.bottom),
      Offset(rect.left + inset, rect.bottom),
      rect.centerLeft,
    ];
  }

  static List<Offset> _parallelogramPoints(
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    final inset = _number(
      properties,
      'inset',
      rect.width * 0.2,
    ).clamp(0.0, rect.width * 0.45).toDouble();
    return [
      Offset(rect.left + inset, rect.top),
      rect.topRight,
      Offset(rect.right - inset, rect.bottom),
      rect.bottomLeft,
    ];
  }

  static List<Offset> _trapezoidPoints(
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    final inset = _number(
      properties,
      'inset',
      rect.width * 0.18,
    ).clamp(0.0, rect.width * 0.45).toDouble();
    return [
      Offset(rect.left + inset, rect.top),
      Offset(rect.right - inset, rect.top),
      rect.bottomRight,
      rect.bottomLeft,
    ];
  }

  static List<Offset> _stepPoints(Rect rect, Map<String, dynamic> properties) {
    final inset = _number(
      properties,
      'inset',
      rect.width * 0.22,
    ).clamp(0.0, rect.width * 0.45).toDouble();
    return [
      rect.topLeft,
      Offset(rect.right - inset, rect.top),
      rect.centerRight,
      Offset(rect.right - inset, rect.bottom),
      rect.bottomLeft,
      Offset(rect.left + inset, rect.center.dy),
    ];
  }

  static Path _polygonPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  static String _polygonSvgPath(List<Offset> points) {
    final buffer = StringBuffer('M ${points.first.dx} ${points.first.dy}');
    for (final point in points.skip(1)) {
      buffer.write(' L ${point.dx} ${point.dy}');
    }
    buffer.write(' Z');
    return buffer.toString();
  }

  static String _rectSvgPath(Rect rect) {
    return 'M ${rect.left} ${rect.top} L ${rect.right} ${rect.top} '
        'L ${rect.right} ${rect.bottom} L ${rect.left} ${rect.bottom} Z';
  }

  static String _roundedRectSvgPath(Rect rect, double radius) {
    if (radius <= 0) {
      return _rectSvgPath(rect);
    }
    final r = radius;
    return 'M ${rect.left + r} ${rect.top} '
        'L ${rect.right - r} ${rect.top} '
        'Q ${rect.right} ${rect.top} ${rect.right} ${rect.top + r} '
        'L ${rect.right} ${rect.bottom - r} '
        'Q ${rect.right} ${rect.bottom} ${rect.right - r} ${rect.bottom} '
        'L ${rect.left + r} ${rect.bottom} '
        'Q ${rect.left} ${rect.bottom} ${rect.left} ${rect.bottom - r} '
        'L ${rect.left} ${rect.top + r} '
        'Q ${rect.left} ${rect.top} ${rect.left + r} ${rect.top} Z';
  }

  static String _ellipseSvgPath(Rect rect) {
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    return 'M ${cx - rx} $cy '
        'A $rx $ry 0 1 0 ${cx + rx} $cy '
        'A $rx $ry 0 1 0 ${cx - rx} $cy Z';
  }

  static List<Offset> _ellipseOutline(Rect rect) {
    final points = <Offset>[];
    for (var i = 0; i < 32; i++) {
      final angle = math.pi * 2 * i / 32;
      points.add(
        Offset(
          rect.center.dx + math.cos(angle) * rect.width / 2,
          rect.center.dy + math.sin(angle) * rect.height / 2,
        ),
      );
    }
    return points;
  }

  static Path _cylinderPath(Rect rect, Map<String, dynamic> properties) {
    final cap = _cylinderCap(rect, properties);
    final yTop = rect.top + cap / 2;
    final yBottom = rect.bottom - cap / 2;
    return Path()
      ..moveTo(rect.left, yTop)
      ..cubicTo(
        rect.left,
        yTop - cap / 2,
        rect.right,
        yTop - cap / 2,
        rect.right,
        yTop,
      )
      ..lineTo(rect.right, yBottom)
      ..cubicTo(
        rect.right,
        yBottom + cap / 2,
        rect.left,
        yBottom + cap / 2,
        rect.left,
        yBottom,
      )
      ..close();
  }

  static Path _cylinderTopPath(Rect rect, Map<String, dynamic> properties) {
    final cap = _cylinderCap(rect, properties);
    final k = rect.width * 0.2761423749;
    final yTop = rect.top + cap / 2;
    return Path()
      ..moveTo(rect.left, yTop)
      ..cubicTo(
        rect.left + k,
        yTop + cap / 2,
        rect.right - k,
        yTop + cap / 2,
        rect.right,
        yTop,
      );
  }

  static String _cylinderSvgPath(Rect rect, Map<String, dynamic> properties) {
    final cap = _cylinderCap(rect, properties);
    final yTop = rect.top + cap / 2;
    final yBottom = rect.bottom - cap / 2;
    return 'M ${rect.left} $yTop '
        'C ${rect.left} ${yTop - cap / 2} ${rect.right} ${yTop - cap / 2} ${rect.right} $yTop '
        'L ${rect.right} $yBottom '
        'C ${rect.right} ${yBottom + cap / 2} ${rect.left} ${yBottom + cap / 2} ${rect.left} $yBottom Z';
  }

  static String _cylinderTopSvgPath(
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    final cap = _cylinderCap(rect, properties);
    final k = rect.width * 0.2761423749;
    final yTop = rect.top + cap / 2;
    return 'M ${rect.left} $yTop '
        'C ${rect.left + k} ${yTop + cap / 2} ${rect.right - k} ${yTop + cap / 2} ${rect.right} $yTop';
  }

  static double _swimlaneHeader(Rect rect, Map<String, dynamic> properties) {
    return _number(
      properties,
      'headerHeight',
      math.min(36, rect.height * 0.25),
    ).clamp(0.0, rect.height).toDouble();
  }

  static Path _swimlaneDivider(Rect rect, Map<String, dynamic> properties) {
    final y = rect.top + _swimlaneHeader(rect, properties);
    return Path()
      ..moveTo(rect.left, y)
      ..lineTo(rect.right, y);
  }

  static Path _documentPath(Rect rect, Map<String, dynamic> properties) {
    final wave = _number(
      properties,
      'waveHeight',
      rect.height * 0.12,
    ).clamp(0.0, rect.height * 0.3).toDouble();
    final y = rect.bottom - wave;
    return Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, y)
      ..cubicTo(
        rect.left + rect.width * 0.75,
        rect.bottom + wave,
        rect.left + rect.width * 0.25,
        y - wave,
        rect.left,
        y,
      )
      ..close();
  }

  static Path _notePath(Rect rect, Map<String, dynamic> properties) {
    final fold = _number(
      properties,
      'foldSize',
      math.min(18, rect.shortestSide * 0.25),
    ).clamp(0.0, rect.shortestSide * 0.5).toDouble();
    return Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right - fold, rect.top)
      ..lineTo(rect.right, rect.top + fold)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  static Path _noteFoldPath(Rect rect, Map<String, dynamic> properties) {
    final fold = _number(
      properties,
      'foldSize',
      math.min(18, rect.shortestSide * 0.25),
    ).clamp(0.0, rect.shortestSide * 0.5).toDouble();
    return Path()
      ..moveTo(rect.right - fold, rect.top)
      ..lineTo(rect.right - fold, rect.top + fold)
      ..lineTo(rect.right, rect.top + fold);
  }

  static Path _calloutPath(Rect rect, Map<String, dynamic> properties) {
    final tailHeight = _number(
      properties,
      'tailHeight',
      rect.height * 0.28,
    ).clamp(0.0, rect.height * 0.5).toDouble();
    final tailWidth = _number(
      properties,
      'tailWidth',
      rect.width * 0.22,
    ).clamp(0.0, rect.width * 0.6).toDouble();
    final bodyBottom = rect.bottom - tailHeight;
    final tailCenter = _number(
      properties,
      'tailCenter',
      0.55,
    ).clamp(0.1, 0.9).toDouble();
    final cx = rect.left + rect.width * tailCenter;
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(rect.left, rect.top, rect.right, bodyBottom),
          Radius.circular(math.min(rect.width, rect.height) * 0.08),
        ),
      )
      ..moveTo(cx - tailWidth / 2, bodyBottom)
      ..lineTo(cx, rect.bottom)
      ..lineTo(cx + tailWidth / 2, bodyBottom)
      ..close();
  }

  static Path _orthogonalSymbolPath(
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    final maxBar = rect.shortestSide < 1.0 ? 1.0 : rect.shortestSide;
    final bar = _number(
      properties,
      'barSize',
      rect.shortestSide * 0.34,
    ).clamp(1.0, maxBar).toDouble();
    final left = rect.center.dx - bar / 2;
    final right = rect.center.dx + bar / 2;
    final top = rect.center.dy - bar / 2;
    final bottom = rect.center.dy + bar / 2;
    return Path()
      ..moveTo(left, rect.top)
      ..lineTo(right, rect.top)
      ..lineTo(right, top)
      ..lineTo(rect.right, top)
      ..lineTo(rect.right, bottom)
      ..lineTo(right, bottom)
      ..lineTo(right, rect.bottom)
      ..lineTo(left, rect.bottom)
      ..lineTo(left, bottom)
      ..lineTo(rect.left, bottom)
      ..lineTo(rect.left, top)
      ..lineTo(left, top)
      ..close();
  }

  static Path _diagonalCrossPath(Rect rect, Map<String, dynamic> properties) {
    final maxArm = rect.shortestSide * 0.5 < 1.0 ? 1.0 : rect.shortestSide * 0.5;
    final arm = _number(
      properties,
      'armSize',
      rect.shortestSide * 0.28,
    ).clamp(1.0, maxArm).toDouble();
    final dx = arm / math.sqrt2;
    final dy = arm / math.sqrt2;
    return Path()
      ..moveTo(rect.left + dx, rect.top)
      ..lineTo(rect.center.dx, rect.center.dy - dy)
      ..lineTo(rect.right - dx, rect.top)
      ..lineTo(rect.right, rect.top + dy)
      ..lineTo(rect.center.dx + dx, rect.center.dy)
      ..lineTo(rect.right, rect.bottom - dy)
      ..lineTo(rect.right - dx, rect.bottom)
      ..lineTo(rect.center.dx, rect.center.dy + dy)
      ..lineTo(rect.left + dx, rect.bottom)
      ..lineTo(rect.left, rect.bottom - dy)
      ..lineTo(rect.center.dx - dx, rect.center.dy)
      ..lineTo(rect.left, rect.top + dy)
      ..close();
  }

  static Path _cubePath(Rect rect, Map<String, dynamic> properties) {
    final depth = _number(
      properties,
      'depth',
      math.min(rect.width, rect.height) * 0.18,
    ).clamp(0.0, rect.shortestSide * 0.45).toDouble();
    return Path()
      ..moveTo(rect.left, rect.top + depth)
      ..lineTo(rect.left + depth, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom - depth)
      ..lineTo(rect.right - depth, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  static List<Path> _cubeForeground(
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    final depth = _number(
      properties,
      'depth',
      math.min(rect.width, rect.height) * 0.18,
    ).clamp(0.0, rect.shortestSide * 0.45).toDouble();
    return [
      Path()
        ..moveTo(rect.left, rect.top + depth)
        ..lineTo(rect.right - depth, rect.top + depth)
        ..lineTo(rect.right, rect.top),
      Path()
        ..moveTo(rect.right - depth, rect.top + depth)
        ..lineTo(rect.right - depth, rect.bottom)
        ..lineTo(rect.right, rect.bottom - depth),
    ];
  }

  static Path _actorPath(Rect rect) {
    final head = Rect.fromCircle(
      center: Offset(rect.center.dx, rect.top + rect.height * 0.22),
      radius: rect.shortestSide * 0.13,
    );
    return Path()
      ..addOval(head)
      ..moveTo(rect.center.dx, head.bottom)
      ..lineTo(rect.center.dx, rect.top + rect.height * 0.62)
      ..moveTo(rect.left + rect.width * 0.22, rect.top + rect.height * 0.42)
      ..lineTo(rect.right - rect.width * 0.22, rect.top + rect.height * 0.42)
      ..moveTo(rect.center.dx, rect.top + rect.height * 0.62)
      ..lineTo(rect.left + rect.width * 0.25, rect.bottom)
      ..moveTo(rect.center.dx, rect.top + rect.height * 0.62)
      ..lineTo(rect.right - rect.width * 0.25, rect.bottom);
  }

  static Path _cloudPath(Rect rect) {
    return Path()
      ..moveTo(rect.left + rect.width * 0.25, rect.bottom - rect.height * 0.18)
      ..cubicTo(
        rect.left - rect.width * 0.05,
        rect.bottom - rect.height * 0.22,
        rect.left + rect.width * 0.04,
        rect.top + rect.height * 0.38,
        rect.left + rect.width * 0.28,
        rect.top + rect.height * 0.42,
      )
      ..cubicTo(
        rect.left + rect.width * 0.28,
        rect.top + rect.height * 0.10,
        rect.left + rect.width * 0.68,
        rect.top + rect.height * 0.04,
        rect.left + rect.width * 0.72,
        rect.top + rect.height * 0.34,
      )
      ..cubicTo(
        rect.right + rect.width * 0.08,
        rect.top + rect.height * 0.34,
        rect.right + rect.width * 0.02,
        rect.bottom - rect.height * 0.14,
        rect.left + rect.width * 0.68,
        rect.bottom - rect.height * 0.16,
      )
      ..close();
  }

  static String _pathToSvg(Path path) {
    final data = StringBuffer();
    for (final metric in path.computeMetrics()) {
      final points = <Offset>[];
      final steps = math.max(8, (metric.length / 8).ceil());
      for (var i = 0; i <= steps; i++) {
        final tangent = metric.getTangentForOffset(metric.length * i / steps);
        if (tangent != null) {
          points.add(tangent.position);
        }
      }
      if (points.isEmpty) {
        continue;
      }
      data.write('M ${points.first.dx} ${points.first.dy}');
      for (final point in points.skip(1)) {
        data.write(' L ${point.dx} ${point.dy}');
      }
      if (metric.isClosed) {
        data.write(' Z');
      }
    }
    return data.toString();
  }
}

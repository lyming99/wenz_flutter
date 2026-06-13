import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../elements/shape_definition.dart';
import 'builtin_stencils.dart';
import 'stencil_definition.dart';

class StencilRenderer {
  const StencilRenderer._();

  static Path buildPath(
    StencilDefinition stencil,
    Rect rect,
    Map<String, dynamic> properties, {
    bool includeForeground = false,
  }) {
    final path = Path();
    for (final command in stencil.background) {
      path.addPath(
        _pathForCommand(stencil, command, rect, properties),
        Offset.zero,
      );
    }
    if (includeForeground) {
      for (final command in stencil.foreground) {
        path.addPath(
          _pathForCommand(stencil, command, rect, properties),
          Offset.zero,
        );
      }
    }
    return path;
  }

  static List<Path> buildForegroundPaths(
    StencilDefinition stencil,
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    return [
      for (final command in stencil.foreground)
        _pathForCommand(stencil, command, rect, properties),
    ].where((path) => !path.getBounds().isEmpty).toList(growable: false);
  }

  static String buildSvgPath(
    StencilDefinition stencil,
    Rect rect,
    Map<String, dynamic> properties, {
    bool includeForeground = false,
  }) {
    final commands = includeForeground ? stencil.commands : stencil.background;
    return [
      for (final command in commands)
        _svgForCommand(stencil, command, rect, properties),
    ].where((path) => path.isNotEmpty).join(' ');
  }

  static List<String> buildForegroundSvgPaths(
    StencilDefinition stencil,
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    return [
      for (final command in stencil.foreground)
        _svgForCommand(stencil, command, rect, properties),
    ].where((path) => path.isNotEmpty).toList(growable: false);
  }

  static List<ShapeConnectionPoint> connectionPointsFor(
    StencilDefinition stencil,
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    if (stencil.connections.isEmpty || rect.isEmpty) {
      return ShapeDefinition.defaultConnectionPoints(rect);
    }
    return [
      ShapeConnectionPoint(
        anchorId: 'center',
        position: rect.center,
        kind: ShapeConnectionPointKind.center,
      ),
      for (var i = 0; i < stencil.connections.length; i++)
        ShapeConnectionPoint(
          anchorId: stencil.connections[i].name ?? 'connection$i',
          position: _mapPoint(
            stencil,
            Offset(
              stencil.connections[i].x * stencil.width,
              stencil.connections[i].y * stencil.height,
            ),
            rect,
            properties,
          ),
          kind: stencil.connections[i].perimeter
              ? ShapeConnectionPointKind.edge
              : ShapeConnectionPointKind.body,
        ),
    ];
  }

  static ShapeDefinition shapeDefinitionFor(StencilDefinition stencil) {
    return ShapeDefinition(
      key: stencil.name,
      buildPath: (rect, properties) => buildPath(stencil, rect, properties),
      buildSvgPath: (rect, properties) =>
          buildSvgPath(stencil, rect, properties),
      buildForegroundPaths: (rect, properties) =>
          buildForegroundPaths(stencil, rect, properties),
      buildForegroundSvgPaths: (rect, properties) =>
          buildForegroundSvgPaths(stencil, rect, properties),
      buildConnectionPoints: (rect, properties) =>
          connectionPointsFor(stencil, rect, properties),
    );
  }

  static Path _pathForCommand(
    StencilDefinition stencil,
    StencilCommand command,
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    switch (command) {
      case final StencilPathCommand c:
        return _pathForOperations(stencil, c.operations, rect, properties);
      case final StencilRectCommand c:
        return Path()..addRect(
          _mapRect(stencil, c.x, c.y, c.width, c.height, rect, properties),
        );
      case final StencilRoundRectCommand c:
        final mapped = _mapRect(
          stencil,
          c.x,
          c.y,
          c.width,
          c.height,
          rect,
          properties,
        );
        final radius = math.min(
          mapped.shortestSide / 2,
          (c.arcSize ?? 10) * _scaleForRadius(stencil, rect),
        );
        return Path()
          ..addRRect(RRect.fromRectAndRadius(mapped, Radius.circular(radius)));
      case final StencilEllipseCommand c:
        return Path()..addOval(
          _mapRect(stencil, c.x, c.y, c.width, c.height, rect, properties),
        );
      case final StencilIncludeShapeCommand c:
        final included = BuiltinStencils.definitionFor(c.name);
        if (included == null) {
          return Path();
        }
        return buildPath(
          included,
          _mapRect(stencil, c.x, c.y, c.width, c.height, rect, properties),
          properties,
          includeForeground: true,
        );
      case StencilTextCommand _:
      case StencilStyleCommand _:
      case StencilUnsupportedCommand _:
        return Path();
    }
  }

  static Path _pathForOperations(
    StencilDefinition stencil,
    List<StencilPathOperation> operations,
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    final path = Path();
    Offset current = Offset.zero;
    for (final operation in operations) {
      switch (operation) {
        case final StencilMoveTo o:
          current = _mapPoint(stencil, Offset(o.x, o.y), rect, properties);
          path.moveTo(current.dx, current.dy);
        case final StencilLineTo o:
          current = _mapPoint(stencil, Offset(o.x, o.y), rect, properties);
          path.lineTo(current.dx, current.dy);
        case final StencilQuadTo o:
          final p1 = _mapPoint(stencil, Offset(o.x1, o.y1), rect, properties);
          current = _mapPoint(stencil, Offset(o.x2, o.y2), rect, properties);
          path.quadraticBezierTo(p1.dx, p1.dy, current.dx, current.dy);
        case final StencilCurveTo o:
          final p1 = _mapPoint(stencil, Offset(o.x1, o.y1), rect, properties);
          final p2 = _mapPoint(stencil, Offset(o.x2, o.y2), rect, properties);
          current = _mapPoint(stencil, Offset(o.x3, o.y3), rect, properties);
          path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, current.dx, current.dy);
        case final StencilArcTo o:
          final target = _mapPoint(stencil, Offset(o.x, o.y), rect, properties);
          // Use independent X/Y scales for arc radii to match how path points
          // are scaled. The old uniform min() scale distorted arcs when the
          // target rect aspect differs from the stencil aspect.
          final mappedRect = _mappedContentRect(stencil, rect);
          final scaleX = stencil.width > 0
              ? mappedRect.width / stencil.width
              : 1.0;
          final scaleY = stencil.height > 0
              ? mappedRect.height / stencil.height
              : 1.0;
          final radius = Radius.elliptical(
            o.rx * scaleX,
            o.ry * scaleY,
          );
          path.arcToPoint(
            target,
            radius: radius,
            rotation: o.xAxisRotation,
            largeArc: o.largeArcFlag,
            clockwise: o.sweepFlag,
          );
          current = target;
        case StencilClosePath _:
          path.close();
      }
    }
    return path;
  }

  static String _svgForCommand(
    StencilDefinition stencil,
    StencilCommand command,
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    switch (command) {
      case final StencilPathCommand c:
        return _svgForOperations(stencil, c.operations, rect, properties);
      case final StencilRectCommand c:
        final r = _mapRect(
          stencil,
          c.x,
          c.y,
          c.width,
          c.height,
          rect,
          properties,
        );
        return 'M ${r.left} ${r.top} L ${r.right} ${r.top} L ${r.right} ${r.bottom} L ${r.left} ${r.bottom} Z';
      case StencilRoundRectCommand _:
      case StencilEllipseCommand _:
      case StencilIncludeShapeCommand _:
        return _pathToSvg(_pathForCommand(stencil, command, rect, properties));
      case StencilTextCommand _:
      case StencilStyleCommand _:
      case StencilUnsupportedCommand _:
        return '';
    }
  }

  static String _svgForOperations(
    StencilDefinition stencil,
    List<StencilPathOperation> operations,
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    final data = StringBuffer();
    for (final operation in operations) {
      switch (operation) {
        case final StencilMoveTo o:
          final p = _mapPoint(stencil, Offset(o.x, o.y), rect, properties);
          data.write('M ${p.dx} ${p.dy} ');
        case final StencilLineTo o:
          final p = _mapPoint(stencil, Offset(o.x, o.y), rect, properties);
          data.write('L ${p.dx} ${p.dy} ');
        case final StencilQuadTo o:
          final p1 = _mapPoint(stencil, Offset(o.x1, o.y1), rect, properties);
          final p2 = _mapPoint(stencil, Offset(o.x2, o.y2), rect, properties);
          data.write('Q ${p1.dx} ${p1.dy} ${p2.dx} ${p2.dy} ');
        case final StencilCurveTo o:
          final p1 = _mapPoint(stencil, Offset(o.x1, o.y1), rect, properties);
          final p2 = _mapPoint(stencil, Offset(o.x2, o.y2), rect, properties);
          final p3 = _mapPoint(stencil, Offset(o.x3, o.y3), rect, properties);
          data.write(
            'C ${p1.dx} ${p1.dy} ${p2.dx} ${p2.dy} ${p3.dx} ${p3.dy} ',
          );
        case StencilArcTo _:
          return _pathToSvg(
            _pathForOperations(stencil, operations, rect, properties),
          );
        case StencilClosePath _:
          data.write('Z ');
      }
    }
    return data.toString().trim();
  }

  static Rect _mapRect(
    StencilDefinition stencil,
    double x,
    double y,
    double width,
    double height,
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    final topLeft = _mapPoint(stencil, Offset(x, y), rect, properties);
    final bottomRight = _mapPoint(
      stencil,
      Offset(x + width, y + height),
      rect,
      properties,
    );
    return Rect.fromPoints(topLeft, bottomRight);
  }

  static Offset _mapPoint(
    StencilDefinition stencil,
    Offset point,
    Rect rect,
    Map<String, dynamic> properties,
  ) {
    final mappedRect = _mappedContentRect(stencil, rect);
    final x = mappedRect.left + point.dx * mappedRect.width / stencil.width;
    final y = mappedRect.top + point.dy * mappedRect.height / stencil.height;
    final direction = properties['direction'] as String? ?? 'east';
    return _rotateForDirection(Offset(x, y), rect, direction);
  }

  static Rect _mappedContentRect(StencilDefinition stencil, Rect rect) {
    if (stencil.aspect == StencilAspect.variable ||
        stencil.width <= 0 ||
        stencil.height <= 0) {
      return rect;
    }
    final scale = math.min(
      rect.width / stencil.width,
      rect.height / stencil.height,
    );
    final width = stencil.width * scale;
    final height = stencil.height * scale;
    return Rect.fromCenter(center: rect.center, width: width, height: height);
  }

  static Offset _rotateForDirection(Offset point, Rect rect, String direction) {
    final angle = switch (direction) {
      'north' => -math.pi / 2,
      'south' => math.pi / 2,
      'west' => math.pi,
      _ => 0.0,
    };
    if (angle == 0) {
      return point;
    }
    final translated = point - rect.center;
    final sinA = math.sin(angle);
    final cosA = math.cos(angle);
    return Offset(
      rect.center.dx + translated.dx * cosA - translated.dy * sinA,
      rect.center.dy + translated.dx * sinA + translated.dy * cosA,
    );
  }

  static double _scaleForRadius(StencilDefinition stencil, Rect rect) {
    if (stencil.width <= 0 || stencil.height <= 0) {
      return 1;
    }
    return math.min(rect.width / stencil.width, rect.height / stencil.height);
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

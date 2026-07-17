import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../canvas/paint_style.dart';
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
      paintForeground: (canvas, rect, properties,
          {required strokeStyle, fillStyle, required opacity}) {
        paintForeground(canvas, stencil, rect, properties,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            opacity: opacity);
      },
      buildConnectionPoints: (rect, properties) =>
          connectionPointsFor(stencil, rect, properties),
    );
  }

  /// Paints the foreground section of a stencil following draw.io's
  /// sequential execution model:
  /// - Path-building commands (path, rect, ellipse, roundrect) accumulate
  ///   into a current path buffer.
  /// - `fillstroke` triggers fill + stroke of the current buffer.
  /// - `stroke` triggers stroke-only of the current buffer.
  /// - `fill` triggers fill-only of the current buffer.
  /// - `save` / `restore` manage a style stack.
  /// - `strokewidth`, `fillcolor`, `strokecolor` override local styles.
  /// - After processing all commands, any un-drawn path is discarded.
  static void paintForeground(
    Canvas canvas,
    StencilDefinition stencil,
    Rect rect,
    Map<String, dynamic> properties, {
    required PaintStyle strokeStyle,
    PaintStyle? fillStyle,
    required double opacity,
  }) {
    final fg = stencil.foreground;
    if (fg.isEmpty) {
      return;
    }

    // Build the list of "segments": a segment is a group of consecutive
    // path-building commands terminated by a paint trigger (fillstroke /
    // stroke / fill). draw.io semantics: path commands accumulate until a
    // paint trigger fires, which consumes the accumulated path.
    var currentStroke = strokeStyle;
    Color? currentFillColor = fillStyle?.color;
    Color? currentStrokeColor = strokeStyle.color;
    List<double>? currentDashPattern;
    _ShadowState? currentShadow;
    _GradientState? currentGradient;

    final styleStack = <_StyleState>[];
    var accumulated = Path();

    void flush({required bool doFill, required bool doStroke}) {
      if (accumulated.getBounds().isEmpty) {
        accumulated = Path();
        return;
      }
      // Draw shadow first (behind the shape).
      if (currentShadow != null) {
        final s = currentShadow;
        canvas.save();
        canvas.translate(s.dx, s.dy);
        canvas.drawPath(
          accumulated,
          Paint()
            ..color = s.color.withValues(alpha: s.opacity * opacity)
            ..style = PaintingStyle.fill
            ..maskFilter = s.blur > 0
                ? MaskFilter.blur(BlurStyle.normal, s.blur)
                : null,
        );
        canvas.restore();
      }
      if (doFill && (currentFillColor != null || currentGradient != null)) {
        final paint = Paint()..style = PaintingStyle.fill;
        if (currentGradient != null) {
          final g = currentGradient;
          final bounds = accumulated.getBounds();
          paint.shader = ui.Gradient.linear(
            Offset(bounds.left + g.x1 * bounds.width, bounds.top + g.y1 * bounds.height),
            Offset(bounds.left + g.x2 * bounds.width, bounds.top + g.y2 * bounds.height),
            [g.color1, g.color2],
            null,
            ui.TileMode.clamp,
          );
          paint.color = Colors.white.withValues(alpha: opacity);
        } else {
          paint.color = currentFillColor!.withValues(alpha: opacity);
        }
        canvas.drawPath(accumulated, paint);
      }
      if (doStroke) {
        final sc = currentStrokeColor ?? currentStroke.color;
        final paint = Paint()
          ..color = sc.withValues(alpha: currentStroke.opacity * opacity)
          ..strokeWidth = currentStroke.strokeWidth
          ..strokeCap = currentStroke.strokeCap
          ..strokeJoin = currentStroke.strokeJoin
          ..style = PaintingStyle.stroke;
        if (currentDashPattern != null && currentDashPattern.isNotEmpty) {
          _drawDashedPath(canvas, accumulated, paint, currentDashPattern);
        } else {
          canvas.drawPath(accumulated, paint);
        }
      }
      accumulated = Path();
    }

    for (final command in fg) {
      switch (command) {
        case final StencilPathCommand c:
          accumulated.addPath(
            _pathForOperations(stencil, c.operations, rect, properties),
            Offset.zero,
          );
        case final StencilRectCommand c:
          accumulated.addPath(
            Path()..addRect(
              _mapRect(stencil, c.x, c.y, c.width, c.height, rect, properties),
            ),
            Offset.zero,
          );
        case final StencilRoundRectCommand c:
          final mapped = _mapRect(
            stencil, c.x, c.y, c.width, c.height, rect, properties,
          );
          // draw.io: arcsize is a percentage of the shortest side.
          final pct2 = ((c.arcSize ?? 0) <= 0 ? 15.0 : c.arcSize!) / 100;
          final radius2 = math.min(
            mapped.shortestSide / 2,
            math.min(mapped.width * pct2, mapped.height * pct2),
          );
          accumulated.addPath(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(mapped, Radius.circular(radius2)),
              ),
            Offset.zero,
          );
        case final StencilEllipseCommand c:
          accumulated.addPath(
            Path()..addOval(
              _mapRect(stencil, c.x, c.y, c.width, c.height, rect, properties),
            ),
            Offset.zero,
          );
        case final StencilIncludeShapeCommand c:
          final included = BuiltinStencils.definitionFor(c.name);
          if (included != null) {
            accumulated.addPath(
              buildPath(
                included,
                _mapRect(
                  stencil, c.x, c.y, c.width, c.height, rect, properties,
                ),
                properties,
                includeForeground: true,
              ),
              Offset.zero,
            );
          }
        case StencilFillStrokeCommand _:
          flush(doFill: true, doStroke: true);
        case StencilStrokeCommand _:
          flush(doFill: false, doStroke: true);
        case StencilSaveCommand _:
          styleStack.add(_StyleState(
            strokeWidth: currentStroke.strokeWidth,
            fillColor: currentFillColor,
            strokeColor: currentStrokeColor,
            strokeOpacity: currentStroke.opacity,
            dashPattern: currentDashPattern,
            shadow: currentShadow,
            gradient: currentGradient,
          ));
        case StencilRestoreCommand _:
          if (styleStack.isNotEmpty) {
            final s = styleStack.removeLast();
            currentStroke = currentStroke.copyWith(strokeWidth: s.strokeWidth);
            currentFillColor = s.fillColor;
            currentStrokeColor = s.strokeColor;
            currentStroke = currentStroke.copyWith(opacity: s.strokeOpacity);
            currentDashPattern = s.dashPattern;
            currentShadow = s.shadow;
            currentGradient = s.gradient;
          }
        case final StencilStrokeWidthCommand c:
          currentStroke = currentStroke.copyWith(strokeWidth: c.width);
        case final StencilFillColorCommand c:
          currentFillColor = _parseColor(c.color, c.defaultColor);
        case final StencilMiterLimitCommand _:
          // Close enough for canvas rendering.
          break;
        case final StencilLineJoinCommand c:
          currentStroke = currentStroke.copyWith(
            strokeJoin: _parseStrokeJoin(c.join),
          );
        case final StencilDashPatternCommand c:
          currentDashPattern = _parseDashPattern(c.pattern);
        case final StencilShadowCommand c:
          final shadowColor = _colorFromString(c.color) ??
              const Color(0xFF808080);
          currentShadow = _ShadowState(
            dx: c.dx,
            dy: c.dy,
            blur: c.blur,
            color: shadowColor,
            opacity: c.opacity,
          );
        case final StencilGradientCommand c:
          final c1 = _colorFromString(c.color1) ?? Colors.white;
          final c2 = _colorFromString(c.color2) ?? const Color(0xFF808080);
          currentGradient = _GradientState(
            x1: c.x1,
            y1: c.y1,
            x2: c.x2,
            y2: c.y2,
            color1: c1,
            color2: c2,
          );
        case StencilTextCommand _:
        case StencilUnsupportedCommand _:
          break;
      }
    }
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
        // draw.io: arcsize is a percentage of the shortest side.
        // Default to 100 * RECTANGLE_ROUNDING_FACTOR = 15 when 0 or null.
        final pct = ((c.arcSize ?? 0) <= 0 ? 15.0 : c.arcSize!) / 100;
        final radius = math.min(
          mapped.shortestSide / 2,
          math.min(mapped.width * pct, mapped.height * pct),
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

  static Color? _parseColor(String color, [String? defaultColor]) {
    final resolved = (color.isEmpty || color == 'none' || color == 'default')
        ? defaultColor
        : color;
    if (resolved == null || resolved.isEmpty || resolved == 'none') {
      return null;
    }
    return _colorFromString(resolved);
  }

  static Color? _colorFromString(String value) {
    // Handle named colors and hex.
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      } else if (hex.length == 3) {
        final r = hex[0];
        final g = hex[1];
        final b = hex[2];
        return Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
      }
    }
    // Common named colors.
    return switch (value.toLowerCase()) {
      'black' => const Color(0xFF000000),
      'white' => const Color(0xFFFFFFFF),
      'red' => const Color(0xFFFF0000),
      'green' => const Color(0xFF00FF00),
      'blue' => const Color(0xFF0000FF),
      'yellow' => const Color(0xFFFFFF00),
      'orange' => const Color(0xFFFFA500),
      'gray' || 'grey' => const Color(0xFF808080),
      'none' => null,
      _ => null,
    };
  }

  static StrokeJoin _parseStrokeJoin(String join) {
    return switch (join.toLowerCase()) {
      'round' => StrokeJoin.round,
      'bevel' => StrokeJoin.bevel,
      _ => StrokeJoin.miter,
    };
  }

  static List<double>? _parseDashPattern(String pattern) {
    final parts = pattern
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .toList(growable: false);
    if (parts.isEmpty || parts.length < 2) {
      return null;
    }
    return parts;
  }

  /// Draws a [path] with a dashed [pattern] using [paint].
  /// The pattern is a list of dash/gap lengths, e.g. [5, 3] means
  /// 5px dash, 3px gap, repeated.
  static void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    List<double> pattern,
  ) {
    final totalPattern = pattern.fold<double>(0, (sum, v) => sum + v);
    if (totalPattern <= 0) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var patternIndex = 0;
      var drawDash = true;
      while (distance < metric.length) {
        final segmentLength = pattern[patternIndex % pattern.length];
        final nextDistance = distance + segmentLength;
        if (drawDash) {
          final end = nextDistance.clamp(0.0, metric.length).toDouble();
          final extract = metric.extractPath(distance, end);
          canvas.drawPath(extract, paint);
        }
        distance = nextDistance;
        patternIndex++;
        drawDash = !drawDash;
      }
    }
  }
}

class _StyleState {
  const _StyleState({
    required this.strokeWidth,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeOpacity,
    this.dashPattern,
    this.shadow,
    this.gradient,
  });

  final double strokeWidth;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeOpacity;
  final List<double>? dashPattern;
  final _ShadowState? shadow;
  final _GradientState? gradient;
}

class _ShadowState {
  const _ShadowState({
    required this.dx,
    required this.dy,
    required this.blur,
    required this.color,
    required this.opacity,
  });

  final double dx;
  final double dy;
  final double blur;
  final Color color;
  final double opacity;
}

class _GradientState {
  const _GradientState({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.color1,
    required this.color2,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final Color color1;
  final Color color2;
}

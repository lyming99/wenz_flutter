import 'package:flutter/widgets.dart';
import 'package:xml/xml.dart';

import 'stencil_definition.dart';

class StencilParser {
  const StencilParser._();

  static StencilDefinition parse(String source, {String? fallbackName}) {
    final document = XmlDocument.parse(source);
    final shape = document.findAllElements('shape').firstOrNull;
    if (shape == null) {
      throw const FormatException('Stencil XML does not contain a <shape>.');
    }
    final shapeName = shape._attr('name') ?? fallbackName ?? 'stencil';

    return StencilDefinition(
      name: shapeName,
      width: shape._doubleAttr('w', fallback: 100),
      height: shape._doubleAttr('h', fallback: 100),
      aspect: _aspect(shape._attr('aspect')),
      strokeWidth: _strokeWidth(shape._attr('strokewidth')),
      background: _commandsIn(shape, 'background'),
      foreground: _commandsIn(shape, 'foreground'),
      connections: _connections(shape),
    );
  }

  static List<StencilCommand> _commandsIn(
    XmlElement shape,
    String sectionName,
  ) {
    final section = shape.findElements(sectionName).firstOrNull;
    if (section == null) {
      return const <StencilCommand>[];
    }
    return [for (final child in section.childElements) _command(child)];
  }

  static StencilCommand _command(XmlElement element) {
    return switch (element.name.local) {
      'path' => StencilPathCommand(_pathOperations(element)),
      'rect' => StencilRectCommand(
        element._doubleAttr('x'),
        element._doubleAttr('y'),
        element._doubleAttr('w'),
        element._doubleAttr('h'),
      ),
      'roundrect' => StencilRoundRectCommand(
        element._doubleAttr('x'),
        element._doubleAttr('y'),
        element._doubleAttr('w'),
        element._doubleAttr('h'),
        arcSize: element._maybeDoubleAttr('arcsize'),
      ),
      'ellipse' => StencilEllipseCommand(
        element._doubleAttr('x'),
        element._doubleAttr('y'),
        element._doubleAttr('w'),
        element._doubleAttr('h'),
      ),
      'text' => StencilTextCommand(
        x: element._doubleAttr('x'),
        y: element._doubleAttr('y'),
        width: element._doubleAttr('w'),
        height: element._doubleAttr('h'),
        value: element._attr('str') ?? element._attr('value') ?? '',
        align: _textAlign(element._attr('align')),
      ),
      'include-shape' => StencilIncludeShapeCommand(
        name: element._attr('name') ?? '',
        x: element._doubleAttr('x'),
        y: element._doubleAttr('y'),
        width: element._doubleAttr('w'),
        height: element._doubleAttr('h'),
      ),
      'fillstroke' => const StencilFillStrokeCommand(),
      'stroke' => const StencilStrokeCommand(),
      'save' => const StencilSaveCommand(),
      'restore' => const StencilRestoreCommand(),
      'strokewidth' => StencilStrokeWidthCommand(
        element._doubleAttr('width', fallback: 1),
      ),
      'fillcolor' => StencilFillColorCommand(
        color: element._attr('color') ?? '',
        defaultColor: element._attr('default'),
      ),
      'miterlimit' => StencilMiterLimitCommand(
        element._doubleAttr('limit', fallback: 10),
      ),
      'linejoin' => StencilLineJoinCommand(element._attr('join') ?? 'miter'),
      'dashpattern' => StencilDashPatternCommand(
        element._attr('pattern') ?? '5 3',
      ),
      'shadow' => StencilShadowCommand(
        dx: element._doubleAttr('dx', fallback: 2),
        dy: element._doubleAttr('dy', fallback: 2),
        blur: element._doubleAttr('blur', fallback: 4),
        color: element._attr('color') ?? 'gray',
        opacity: element._doubleAttr('opacity', fallback: 0.5),
      ),
      'gradient' => StencilGradientCommand(
        x1: element._doubleAttr('x1', fallback: 0),
        y1: element._doubleAttr('y1', fallback: 0),
        x2: element._doubleAttr('x2', fallback: 1),
        y2: element._doubleAttr('y2', fallback: 0),
        color1: element._attr('c1') ?? element._attr('color1') ?? 'white',
        color2: element._attr('c2') ?? element._attr('color2') ?? 'gray',
        direction: element._attr('direction') ?? 'east',
      ),
      _ => StencilUnsupportedCommand(element.name.local),
    };
  }

  static List<StencilPathOperation> _pathOperations(XmlElement path) {
    final operations = <StencilPathOperation>[];
    for (final child in path.childElements) {
      switch (child.name.local) {
        case 'move':
          operations.add(
            StencilMoveTo(child._doubleAttr('x'), child._doubleAttr('y')),
          );
        case 'line':
          operations.add(
            StencilLineTo(child._doubleAttr('x'), child._doubleAttr('y')),
          );
        case 'quad':
          operations.add(
            StencilQuadTo(
              child._doubleAttr('x1'),
              child._doubleAttr('y1'),
              child._doubleAttr('x2'),
              child._doubleAttr('y2'),
            ),
          );
        case 'curve':
          operations.add(
            StencilCurveTo(
              child._doubleAttr('x1'),
              child._doubleAttr('y1'),
              child._doubleAttr('x2'),
              child._doubleAttr('y2'),
              child._doubleAttr('x3'),
              child._doubleAttr('y3'),
            ),
          );
        case 'arc':
          operations.add(
            StencilArcTo(
              rx: child._doubleAttr('rx'),
              ry: child._doubleAttr('ry'),
              xAxisRotation: child._doubleAttr('x-axis-rotation'),
              largeArcFlag: child._boolAttr('large-arc-flag'),
              sweepFlag: child._boolAttr('sweep-flag'),
              x: child._doubleAttr('x'),
              y: child._doubleAttr('y'),
            ),
          );
        case 'close':
          operations.add(const StencilClosePath());
      }
    }
    return operations;
  }

  static List<StencilConnection> _connections(XmlElement shape) {
    final connections = shape.findElements('connections').firstOrNull;
    if (connections == null) {
      return const <StencilConnection>[];
    }
    return [
      for (final constraint in connections.findElements('constraint'))
        StencilConnection(
          x: constraint._doubleAttr('x'),
          y: constraint._doubleAttr('y'),
          name: constraint._attr('name'),
          perimeter: constraint._boolAttr('perimeter', fallback: true),
        ),
    ];
  }

  static StencilAspect _aspect(String? value) {
    return value == 'fixed' ? StencilAspect.fixed : StencilAspect.variable;
  }

  static StencilStrokeWidth _strokeWidth(String? value) {
    if (value == null || value == 'inherit') {
      return StencilStrokeWidth.inherited;
    }
    return StencilStrokeWidth.value(double.tryParse(value) ?? 1);
  }

  static TextAlign _textAlign(String? value) {
    return switch (value) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      _ => TextAlign.center,
    };
  }
}

extension _XmlElementAttrs on XmlElement {
  String? _attr(String name) => getAttribute(name);

  double _doubleAttr(String name, {double fallback = 0}) {
    return _maybeDoubleAttr(name) ?? fallback;
  }

  double? _maybeDoubleAttr(String name) {
    return double.tryParse(getAttribute(name) ?? '');
  }

  bool _boolAttr(String name, {bool fallback = false}) {
    final value = getAttribute(name);
    if (value == null) {
      return fallback;
    }
    return value == '1' || value == 'true';
  }
}

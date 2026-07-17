import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  setUp(ensureDrawioShapeDefinitionsRegistered);

  test('drawio shape serializes, restores, translates, and scales', () {
    const element = DrawioShapeElement(
      id: 'shape-1',
      shapeKey: 'rhombus',
      rect: Rect.fromLTWH(10, 20, 120, 80),
      strokeStyle: PaintStyle(color: Color(0xFF0F172A), strokeWidth: 3),
      fillStyle: PaintStyle(color: Color(0xFFE0F2FE)),
      properties: {'direction': 'north', 'inset': 12},
      label: 'Decision',
      labelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      labelPadding: EdgeInsets.all(10),
      opacity: 0.75,
      zIndex: 5,
    );

    final restored =
        CanvasSerializer.elementFromJson(element.toJson())
            as DrawioShapeElement;

    expect(restored.shapeKey, 'rhombus');
    expect(restored.rect, element.rect);
    expect(restored.strokeStyle.color, const Color(0xFF0F172A));
    expect(restored.fillStyle!.color, const Color(0xFFE0F2FE));
    expect(restored.properties['direction'], 'north');
    expect(restored.label, 'Decision');
    expect(restored.labelStyle.fontSize, 18);
    expect(restored.labelPadding.left, 10);
    expect(restored.opacity, 0.75);
    expect(restored.zIndex, 5);

    final moved = restored.translate(const Offset(5, -10));
    expect(moved.rect.topLeft, const Offset(15, 10));

    final scaled = restored.scaleElement(2, pivot: Offset.zero);
    expect(scaled.rect, const Rect.fromLTWH(20, 40, 240, 160));
    expect(scaled.strokeStyle.strokeWidth, 6);
    expect(scaled.labelStyle.fontSize, 36);
    expect(scaled.labelPadding.left, 20);
    expect(scaled.properties['inset'], 24);
  });

  test('built-in MVP shape definitions produce paths and hit tests', () {
    const rect = Rect.fromLTWH(0, 0, 120, 80);
    const keys = [
      'rectangle',
      'roundedRectangle',
      'ellipse',
      'rhombus',
      'triangle',
      'hexagon',
      'parallelogram',
      'trapezoid',
      'cylinder',
      'doubleEllipse',
      'actor',
      'cloud',
      'swimlane',
      'document',
      'note',
      'callout',
      'plus',
      'cross',
      'step',
      'cube',
    ];

    for (final key in keys) {
      final definition = ShapeDefinitionRegistry.definitionFor(key);
      expect(definition.pathFor(rect, const {}).getBounds().isEmpty, isFalse);
      expect(definition.svgPathFor(rect, const {}), isNotEmpty);
    }

    const filled = DrawioShapeElement(
      id: 'tri-1',
      shapeKey: 'triangle',
      rect: rect,
      fillStyle: PaintStyle(color: Colors.white),
    );
    expect(filled.hitTest(const Offset(80, 40)), isTrue);
    expect(filled.hitTest(const Offset(119, 79), tolerance: 1), isFalse);

    const strokeOnly = DrawioShapeElement(
      id: 'dia-1',
      shapeKey: 'rhombus',
      rect: rect,
    );
    expect(strokeOnly.hitTest(rect.topCenter), isTrue);
    expect(strokeOnly.hitTest(rect.center, tolerance: 1), isFalse);
  });

  test('unknown shape falls back to rectangle without throwing', () {
    const element = DrawioShapeElement(
      id: 'unknown-1',
      shapeKey: 'not-a-shape',
      rect: Rect.fromLTWH(0, 0, 100, 60),
      fillStyle: PaintStyle(color: Colors.white),
    );

    expect(element.hitTest(const Offset(50, 30)), isTrue);
    final svg = SvgExporter.exportElements(
      elements: const [element],
      bounds: const Rect.fromLTWH(0, 0, 120, 80),
    );
    expect(svg, contains('<path'));
  });

  test('svg exporter emits drawio shape path, foreground, and label', () {
    const element = DrawioShapeElement(
      id: 'cyl-1',
      shapeKey: 'cylinder',
      rect: Rect.fromLTWH(10, 20, 120, 80),
      strokeStyle: PaintStyle(color: Color(0xFF1D4ED8), strokeWidth: 2),
      fillStyle: PaintStyle(color: Color(0xFFDBEAFE), opacity: 0.5),
      label: 'Database',
    );

    final svg = SvgExporter.exportElements(
      elements: const [element],
      bounds: const Rect.fromLTWH(0, 0, 160, 140),
    );

    expect(svg, contains('<path d="M'));
    expect(svg, contains('fill="#dbeafe"'));
    expect(svg, contains('stroke="#1d4ed8"'));
    expect(svg, contains('Database'));
  });

  test('all flowchart stencils are registered and export non-empty SVG', () {
    ensureDrawioShapeDefinitionsRegistered();
    const rect = Rect.fromLTWH(0, 0, 120, 80);

    expect(FlowchartStencils.keys, hasLength(34));
    for (final key in FlowchartStencils.keys) {
      expect(ShapeDefinitionRegistry.contains(key), isTrue, reason: key);
      final definition = ShapeDefinitionRegistry.definitionFor(key);
      expect(
        definition.pathFor(rect, const {}).getBounds().isEmpty,
        isFalse,
        reason: key,
      );
      expect(definition.svgPathFor(rect, const {}), isNotEmpty, reason: key);

      final svg = SvgExporter.exportElements(
        elements: [
          DrawioShapeElement(
            id: key,
            shapeKey: key,
            rect: rect,
            fillStyle: const PaintStyle(color: Colors.white),
          ),
        ],
        bounds: const Rect.fromLTWH(0, 0, 160, 120),
      );
      expect(svg, contains('<path'), reason: key);
    }
  });

  test('flowchart aliases and drawio adapter map to registered shapes', () {
    ensureDrawioShapeDefinitionsRegistered();

    expect(ShapeDefinitionRegistry.contains('stencil.process'), isTrue);
    expect(
      ShapeDefinitionRegistry.contains('mxgraph.flowchart.manual_input'),
      isTrue,
    );
    expect(
      ShapeDefinitionRegistry.contains('mxgraph.flowchart.manual-input'),
      isTrue,
    );

    final mxgraph = DrawioShapeAdapter.fromStyleString(
      id: 'fc-1',
      rect: const Rect.fromLTWH(0, 0, 120, 80),
      style: 'shape=mxgraph.flowchart.decision;',
    );
    expect(mxgraph.shapeKey, 'flowchart.decision');

    final legacy = DrawioShapeAdapter.fromStyleString(
      id: 'fc-2',
      rect: const Rect.fromLTWH(0, 0, 120, 80),
      style: 'shape=manualInput;',
    );
    expect(legacy.shapeKey, 'flowchart.manualInput');
  });

  test('all basic stencils are registered and export non-empty SVG', () {
    ensureDrawioShapeDefinitionsRegistered();
    const rect = Rect.fromLTWH(0, 0, 120, 100);

    expect(BasicStencils.keys, hasLength(30));
    for (final key in BasicStencils.keys) {
      expect(ShapeDefinitionRegistry.contains(key), isTrue, reason: key);
      final definition = ShapeDefinitionRegistry.definitionFor(key);
      expect(
        definition.pathFor(rect, const {}).getBounds().isEmpty,
        isFalse,
        reason: key,
      );
      expect(definition.svgPathFor(rect, const {}), isNotEmpty, reason: key);

      final svg = SvgExporter.exportElements(
        elements: [
          DrawioShapeElement(
            id: key,
            shapeKey: key,
            rect: rect,
            fillStyle: const PaintStyle(color: Colors.white),
          ),
        ],
        bounds: const Rect.fromLTWH(0, 0, 160, 130),
      );
      expect(svg, contains('<path'), reason: key);
    }
  });

  test('complex basic symbols keep visible foreground and aliases', () {
    ensureDrawioShapeDefinitionsRegistered();
    const rect = Rect.fromLTWH(0, 0, 120, 100);
    const complexKeys = <String>[
      'basic.smiley',
      'basic.sun',
      'basic.cloudCallout',
    ];

    for (final key in complexKeys) {
      final definition = ShapeDefinitionRegistry.definitionFor(key);
      expect(
        definition.foregroundPathsFor(rect, const {}),
        isNotEmpty,
        reason: key,
      );
      expect(
        definition.foregroundSvgPathsFor(rect, const {}),
        isNotEmpty,
        reason: key,
      );
    }

    final noSymbol = ShapeDefinitionRegistry.definitionFor('basic.noSymbol');
    expect(
      noSymbol.pathFor(rect, const {}).getBounds().isEmpty,
      isFalse,
      reason: 'basic.noSymbol',
    );

    expect(
      ShapeDefinitionRegistry.contains('mxgraph.basic.cloud_callout'),
      isTrue,
    );
    expect(ShapeDefinitionRegistry.contains('mxgraph.basic.no-symbol'), isTrue);
    expect(ShapeDefinitionRegistry.contains('star'), isTrue);

    final element = DrawioShapeAdapter.fromStyleString(
      id: 'basic-1',
      rect: rect,
      style: 'shape=mxgraph.basic.cloud_callout;',
    );
    expect(element.shapeKey, 'basic.cloudCallout');
  });

  test('all arrows stencils are registered and export non-empty SVG', () {
    ensureDrawioShapeDefinitionsRegistered();
    const rect = Rect.fromLTWH(0, 0, 140, 100);

    expect(ArrowStencils.keys, hasLength(34));
    for (final key in ArrowStencils.keys) {
      expect(ShapeDefinitionRegistry.contains(key), isTrue, reason: key);
      final definition = ShapeDefinitionRegistry.definitionFor(key);
      expect(
        definition.pathFor(rect, const {}).getBounds().isEmpty,
        isFalse,
        reason: key,
      );
      expect(definition.svgPathFor(rect, const {}), isNotEmpty, reason: key);

      final svg = SvgExporter.exportElements(
        elements: [
          DrawioShapeElement(
            id: key,
            shapeKey: key,
            rect: rect,
            fillStyle: const PaintStyle(color: Colors.white),
          ),
        ],
        bounds: const Rect.fromLTWH(0, 0, 180, 140),
      );
      expect(svg, contains('<path'), reason: key);
    }
  });

  test('arrows aliases and drawio adapter map block arrows', () {
    ensureDrawioShapeDefinitionsRegistered();

    expect(
      ShapeDefinitionRegistry.contains('mxgraph.arrows.arrowRight'),
      isTrue,
    );
    expect(
      ShapeDefinitionRegistry.contains('mxgraph.arrows.arrow_right'),
      isTrue,
    );
    expect(
      ShapeDefinitionRegistry.contains('mxgraph.arrows.arrow-right'),
      isTrue,
    );

    final camel = DrawioShapeAdapter.fromStyleString(
      id: 'arr-1',
      rect: const Rect.fromLTWH(0, 0, 120, 80),
      style: 'shape=mxgraph.arrows.arrowRight;',
    );
    expect(camel.shapeKey, 'arrows.arrowRight');

    final snake = DrawioShapeAdapter.fromStyleString(
      id: 'arr-2',
      rect: const Rect.fromLTWH(0, 0, 120, 80),
      style: 'shape=mxgraph.arrows.u_turn_left_arrow;',
    );
    expect(snake.shapeKey, 'arrows.uTurnLeftArrow');
  });
}

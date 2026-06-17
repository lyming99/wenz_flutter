import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';
import 'package:xml/xml.dart';

void main() {
  setUp(ensureDrawioShapeDefinitionsRegistered);

  test(
    'canvas document writes current version and keeps imported unknown shape',
    () {
      final controller = CanvasController()
        ..addElement(
          const DrawioShapeElement(
            id: 'future-1',
            shapeKey: 'mxgraph.future.shape',
            rect: Rect.fromLTWH(0, 0, 100, 60),
            fillStyle: PaintStyle(color: Colors.white),
          ),
        );

      final json = CanvasSerializer.toJson(controller);
      expect(json['schemaVersion'], DocumentSchema.current);

      final document = CanvasSerializer.fromJson(json);
      final element = document.elements.single as DrawioShapeElement;
      expect(element.shapeKey, 'mxgraph.future.shape');
      expect(element.hitTest(const Offset(50, 30)), isTrue);
    },
  );

  test(
    'svg exporter emits parseable drawio shape SVG with label and opacity',
    () {
      const element = DrawioShapeElement(
        id: 'note-1',
        shapeKey: 'note',
        rect: Rect.fromLTWH(10, 20, 120, 80),
        strokeStyle: PaintStyle(color: Color(0xFFB85450), strokeWidth: 2),
        fillStyle: PaintStyle(color: Color(0xFFF8CECC), opacity: 0.4),
        label: 'Note & <todo>',
        opacity: 0.75,
      );

      final svg = SvgExporter.exportElements(
        elements: const [element],
        bounds: const Rect.fromLTWH(0, 0, 160, 140),
      );

      expect(() => XmlDocument.parse(svg), returnsNormally);
      expect(svg, contains('<path'));
      expect(svg, contains('fill="#f8cecc"'));
      expect(svg, contains('fill-opacity="0.4"'));
      expect(svg, contains('stroke="#b85450"'));
      expect(svg, contains('stroke-width="2.0"'));
      expect(svg, contains('opacity="0.75"'));
      expect(svg, contains('Note &amp; &lt;todo&gt;'));
    },
  );

  test('svg exporter emits stencil shapes as paths', () {
    const element = DrawioShapeElement(
      id: 'stencil-1',
      shapeKey: 'stencil.decision',
      rect: Rect.fromLTWH(0, 0, 120, 80),
      strokeStyle: PaintStyle(color: Color(0xFF1F2937), strokeWidth: 1.5),
      fillStyle: PaintStyle(color: Color(0xFFFFFFFF)),
    );

    final svg = SvgExporter.exportElements(
      elements: const [element],
      bounds: const Rect.fromLTWH(0, 0, 140, 100),
    );

    expect(() => XmlDocument.parse(svg), returnsNormally);
    expect(svg, contains('<path d="M 60.0 0.0'));
    expect(svg, contains('L 120.0 40.0'));
  });

  test('svg exporter preserves drawio flip transform and label positions', () {
    const element = DrawioShapeElement(
      id: 'stage4-1',
      shapeKey: 'flowchart.process',
      rect: Rect.fromLTWH(10, 20, 120, 80),
      strokeStyle: PaintStyle(color: Color(0xFF1F2937), strokeWidth: 1.5),
      fillStyle: PaintStyle(color: Color(0xFFFFFFFF)),
      label: 'Bottom Right',
      labelAlign: TextAlign.left,
      labelPadding: EdgeInsets.zero,
      properties: {
        'flipH': true,
        'flipV': true,
        'labelPosition': 'right',
        'verticalAlign': 'bottom',
      },
    );

    final svg = SvgExporter.exportElements(
      elements: const [element],
      bounds: const Rect.fromLTWH(0, 0, 160, 130),
    );

    expect(() => XmlDocument.parse(svg), returnsNormally);
    expect(
      svg,
      contains('<g transform="translate(70.0 60.0) scale(-1.0 -1.0)'),
    );
    expect(svg, contains('text-anchor="end"'));
    expect(svg, contains('x="130.0"'));
    expect(svg, contains('Bottom Right'));
  });
}

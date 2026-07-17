import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  test('imports simplified mxCell JSON vertices into drawio shapes', () {
    final elements = DrawioImporter.fromJson({
      'root': {
        'mxCell': [
          {'id': '0'},
          {
            'id': 'shape-1',
            'vertex': '1',
            'parent': '1',
            'value': 'Decision',
            'style':
                'shape=rhombus;fillColor=#fff2cc;strokeColor=#d6b656;strokeWidth=2;fontColor=#1f2937;',
            'mxGeometry': {'x': 40, 'y': 50, 'width': 120, 'height': 80},
          },
          {'id': 'edge-1', 'edge': '1', 'style': 'endArrow=block;'},
        ],
      },
    });

    expect(elements, hasLength(1));
    final element = elements.single;
    expect(element.id, 'shape-1');
    expect(element.shapeKey, 'rhombus');
    expect(element.rect, const Rect.fromLTWH(40, 50, 120, 80));
    expect(element.label, 'Decision');
    expect(element.fillStyle!.color, const Color(0xFFFFF2CC));
    expect(element.strokeStyle.color, const Color(0xFFD6B656));
    expect(element.strokeStyle.strokeWidth, 2);
    expect(element.labelStyle.color, const Color(0xFF1F2937));
    expect(element.layerId, '1');
  });

  test('imports simplified mxCell XML vertices into drawio shapes', () {
    final elements = DrawioImporter.fromXml('''
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="shape-2" value="Database&lt;br&gt;Main" style="shape=cylinder;fillColor=#dae8fc;strokeColor=#6c8ebf;opacity=80;" vertex="1" parent="1">
      <mxGeometry x="10" y="20" width="140" height="90" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>
''');

    expect(elements, hasLength(1));
    final element = elements.single;
    expect(element.id, 'shape-2');
    expect(element.shapeKey, 'cylinder');
    expect(element.rect, const Rect.fromLTWH(10, 20, 140, 90));
    expect(element.label, 'Database\nMain');
    expect(element.opacity, 0.8);
    expect(element.fillStyle!.color, const Color(0xFFDAE8FC));
    expect(element.strokeStyle.color, const Color(0xFF6C8EBF));
  });

  test(
    'unknown imported shape key loads and falls back safely when rendered',
    () {
      final elements = DrawioImporter.fromJson([
        {
          'id': 'unknown-1',
          'vertex': true,
          'value': '<b>Custom</b>',
          'style': 'shape=mxgraph.custom.futureShape;fillColor=#ffffff;',
          'geometry': {'x': 0, 'y': 0, 'width': 100, 'height': 60},
        },
      ]);

      final element = elements.single;
      expect(element.shapeKey, 'mxgraph.custom.futureShape');
      expect(element.label, 'Custom');
      expect(element.fillStyle!.color, Colors.white);

      final restored =
          CanvasSerializer.elementFromJson(element.toJson())
              as DrawioShapeElement;
      expect(restored.shapeKey, 'mxgraph.custom.futureShape');
      expect(restored.hitTest(const Offset(50, 30)), isTrue);
    },
  );

  test('imports official mxgraph style aliases and preserves stage 4 fields', () {
    final elements = DrawioImporter.fromJson([
      {
        'id': 'flow-1',
        'vertex': true,
        'value': 'Manual Op',
        'style':
            'shape=mxgraph.flowchart.manual_operation;direction=west;flipH=1;flipV=1;size=20;arcSize=8;absoluteArcSize=1;boundedLbl=1;backgroundOutline=1;labelPosition=right;verticalLabelPosition=bottom;verticalAlign=bottom;futureField=kept;',
        'geometry': {'x': 5, 'y': 6, 'width': 110, 'height': 70},
      },
      {
        'id': 'arrow-block',
        'vertex': true,
        'style': 'shape=mxgraph.arrows.u-turn-up-arrow;',
        'geometry': {'x': 0, 'y': 0, 'width': 90, 'height': 50},
      },
    ]);

    expect(elements, hasLength(2));
    expect(elements.first.shapeKey, 'flowchart.manualOperation');
    expect(elements.first.properties['direction'], 'west');
    expect(elements.first.properties['flipH'], isTrue);
    expect(elements.first.properties['flipV'], isTrue);
    expect(elements.first.properties['size'], 20);
    expect(elements.first.properties['arcSize'], 8);
    expect(elements.first.properties['absoluteArcSize'], isTrue);
    expect(elements.first.properties['boundedLbl'], isTrue);
    expect(elements.first.properties['backgroundOutline'], isTrue);
    expect(elements.first.properties['labelPosition'], 'right');
    expect(elements.first.properties['verticalLabelPosition'], 'bottom');
    expect(elements.first.properties['verticalAlign'], 'bottom');
    expect(elements.first.properties['futureField'], 'kept');
    expect(elements.last.shapeKey, 'arrows.uTurnUpArrow');
  });
}

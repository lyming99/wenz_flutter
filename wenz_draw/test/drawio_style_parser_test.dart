import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  test('parser handles key value pairs, flags, and unknown extras', () {
    final style = DrawioStyleParser.parse(
      'shape=rhombus;whiteSpace=wrap;html=1;rounded=1;sketch;foo=bar;',
    );

    expect(style.raw, contains('shape=rhombus'));
    expect(style['shape'], 'rhombus');
    expect(style['whiteSpace'], 'wrap');
    expect(style.boolValue('html'), isTrue);
    expect(style.boolValue('rounded'), isTrue);
    expect(style.hasFlag('sketch'), isTrue);
    expect(style.extra, {'foo': 'bar'});
  });

  test('color parser supports none, hex, short hex, alpha hex, and names', () {
    expect(DrawioColor.parse('none'), isNull);
    expect(DrawioColor.parse('#fff'), const Color(0xFFFFFFFF));
    expect(DrawioColor.parse('#d6b656'), const Color(0xFFD6B656));
    expect(DrawioColor.parse('#80ff0000'), const Color(0x80FF0000));
    expect(DrawioColor.parse('blue'), Colors.blue);
    expect(DrawioColor.opacityFromPercent('35'), 0.35);
    expect(DrawioColor.opacityFromPercent('bogus', fallback: 0.4), 0.4);
  });

  test('adapter creates drawio shape element from common style string', () {
    final element = DrawioShapeAdapter.fromStyleString(
      id: 'style-1',
      rect: const Rect.fromLTWH(10, 20, 120, 80),
      label: 'Decision',
      style:
          'shape=rhombus;fillColor=#fff2cc;strokeColor=#d6b656;strokeWidth=3;direction=north;fontColor=#1f2937;fontSize=18;fontStyle=1;align=right;spacing=12;foo=bar;',
    );

    expect(element.shapeKey, 'rhombus');
    expect(element.rect, const Rect.fromLTWH(10, 20, 120, 80));
    expect(element.fillStyle!.color, const Color(0xFFFFF2CC));
    expect(element.strokeStyle.color, const Color(0xFFD6B656));
    expect(element.strokeStyle.strokeWidth, 3);
    expect(element.properties['direction'], 'north');
    expect(element.properties['foo'], 'bar');
    expect(element.label, 'Decision');
    expect(element.labelStyle.color, const Color(0xFF1F2937));
    expect(element.labelStyle.fontSize, 18);
    expect(element.labelStyle.fontWeight, FontWeight.bold);
    expect(element.labelAlign, TextAlign.right);
    expect(element.labelPadding.left, 12);
  });

  test('adapter maps none colors and drawio shape aliases', () {
    final element = DrawioShapeAdapter.fromStyleString(
      id: 'style-2',
      rect: const Rect.fromLTWH(0, 0, 100, 60),
      style:
          'shape=manualInput;fillColor=none;strokeColor=none;opacity=50;rounded=1;',
    );

    expect(element.shapeKey, 'parallelogram');
    expect(element.fillStyle, isNull);
    expect(element.strokeStyle.strokeWidth, 0);
    expect(element.strokeStyle.opacity, 0);
    expect(element.opacity, 0.5);
    expect(element.properties['rounded'], isTrue);

    final restored =
        CanvasSerializer.elementFromJson(element.toJson())
            as DrawioShapeElement;
    expect(restored.shapeKey, 'parallelogram');
    expect(restored.properties['drawioStyle'], contains('shape=manualInput'));
  });

  test('adapter defaults plain rounded styles to rounded rectangle', () {
    final element = DrawioShapeAdapter.fromStyleString(
      id: 'style-3',
      rect: const Rect.fromLTWH(0, 0, 100, 60),
      style: 'rounded=1;fillColor=#ffffff;strokeColor=#000000;',
    );

    expect(element.shapeKey, 'roundedRectangle');
    expect(element.hitTest(const Offset(50, 30)), isTrue);
  });
}

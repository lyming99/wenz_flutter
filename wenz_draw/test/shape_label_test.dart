import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  test('rect label serializes, restores, and scales with shape', () {
    const element = RectElement(
      id: 'rect-1',
      rect: Rect.fromLTWH(10, 20, 120, 80),
      fillStyle: PaintStyle(color: Color(0xFFE0F2FE)),
      label: 'Decision',
      labelStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      labelAlign: TextAlign.center,
      labelPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );

    final restored =
        CanvasSerializer.elementFromJson(element.toJson()) as RectElement;

    expect(restored.label, 'Decision');
    expect(restored.labelStyle.color, const Color(0xFF0F172A));
    expect(restored.labelStyle.fontSize, 18);
    expect(restored.labelStyle.fontWeight, FontWeight.w700);
    expect(restored.labelStyle.height, 1.3);
    expect(restored.labelAlign, TextAlign.center);
    expect(restored.labelPadding.left, 12);
    expect(restored.labelPadding.top, 8);

    final scaled = element.scaleElement(2, pivot: Offset.zero);
    expect(scaled.rect, const Rect.fromLTWH(20, 40, 240, 160));
    expect(scaled.labelStyle.fontSize, 36);
    expect(scaled.labelPadding.left, 24);
    expect(scaled.hitTest(const Offset(80, 50)), isTrue);
    expect(
      scaled.bounds,
      scaled.rect.inflate(scaled.strokeStyle.strokeWidth / 2),
    );
  });

  test('ellipse label restores defaults for old json without label fields', () {
    final restored =
        CanvasSerializer.elementFromJson({
              'id': 'ellipse-1',
              'type': 'ellipse',
              'rect': {'left': 0, 'top': 0, 'right': 100, 'bottom': 60},
            })
            as EllipseElement;

    expect(restored.label, isNull);
    expect(restored.labelStyle.fontSize, 16);
    expect(restored.labelAlign, TextAlign.center);
    expect(restored.labelPadding, const EdgeInsets.all(8));
    expect(restored.hitTest(const Offset(50, 30)), isFalse);
  });

  test('svg exporter emits shape labels after rect and ellipse', () {
    final svg = SvgExporter.exportElements(
      elements: const [
        RectElement(
          id: 'rect-1',
          rect: Rect.fromLTWH(0, 0, 120, 80),
          label: 'Rect label',
          labelStyle: TextStyle(fontSize: 14),
        ),
        EllipseElement(
          id: 'ellipse-1',
          rect: Rect.fromLTWH(150, 0, 120, 80),
          label: 'Ellipse\nlabel',
          labelAlign: TextAlign.right,
          labelPadding: EdgeInsets.all(10),
        ),
      ],
      bounds: Rect.fromLTWH(0, 0, 300, 120),
    );

    expect(svg, contains('<rect x="0.0"'));
    expect(svg, contains('Rect label'));
    expect(svg, contains('Ellipse'));
    expect(svg, contains('label'));
    expect(svg, contains('text-anchor="end"'));
  });
  test('controller edits shape label without removing shape when cleared', () {
    final controller = CanvasController();
    controller.addElement(
      const RectElement(
        id: 'rect-1',
        rect: Rect.fromLTWH(0, 0, 100, 80),
        fillStyle: PaintStyle(),
        label: 'Keep me',
      ),
      record: false,
    );

    controller.beginShapeLabelEditing('rect-1');
    expect(controller.editingShapeLabelElementId, 'rect-1');
    controller.endShapeLabelEditing(text: '');

    final element = controller.elementById('rect-1') as RectElement;
    expect(element.label, '');
    expect(controller.elements.length, 1);
    expect(controller.canUndo, isTrue);
    controller.undo();
    expect((controller.elementById('rect-1') as RectElement).label, 'Keep me');
  });

  test('double tapping shape begins label editing', () {
    final controller = CanvasController();
    controller.addElement(
      const RectElement(
        id: 'rect-1',
        rect: Rect.fromLTWH(0, 0, 100, 80),
        fillStyle: PaintStyle(),
      ),
      record: false,
    );
    controller.setTool(SelectTool.idValue);

    controller.dispatchCanvasEvent(
      const CanvasDoubleTapEvent(
        screenPoint: Offset(40, 40),
        worldPoint: Offset(40, 40),
        transform: CanvasTransform.identity,
      ),
    );

    expect(controller.editingShapeLabelElementId, 'rect-1');
    controller.endShapeLabelEditing(text: 'New label');
    expect(
      (controller.elementById('rect-1') as RectElement).label,
      'New label',
    );
  });
  test('drawio shape label can be edited and styled through controller', () {
    final controller = CanvasController();
    controller.addElement(
      const DrawioShapeElement(
        id: 'shape-1',
        shapeKey: 'rhombus',
        rect: Rect.fromLTWH(0, 0, 120, 80),
        fillStyle: PaintStyle(color: Color(0xFFE0F2FE)),
        label: 'Old',
      ),
      record: false,
    );

    controller.beginShapeLabelEditing('shape-1');
    expect(controller.editingShapeLabelElementId, 'shape-1');
    controller.updateShapeLabelStyle(
      'shape-1',
      color: const Color(0xFF1D4ED8),
      fontSize: 20,
      textAlign: TextAlign.right,
      record: false,
    );
    controller.endShapeLabelEditing(text: 'New');

    final element = controller.elementById('shape-1') as DrawioShapeElement;
    expect(element.label, 'New');
    expect(element.labelStyle.color, const Color(0xFF1D4ED8));
    expect(element.labelStyle.fontSize, 20);
    expect(element.labelAlign, TextAlign.right);
    expect(controller.canUndo, isTrue);
    controller.undo();
    expect(
      (controller.elementById('shape-1') as DrawioShapeElement).label,
      'Old',
    );
  });

  test('double tapping drawio shape begins label editing', () {
    final controller = CanvasController();
    controller.addElement(
      const DrawioShapeElement(
        id: 'shape-1',
        shapeKey: 'hexagon',
        rect: Rect.fromLTWH(0, 0, 120, 80),
        fillStyle: PaintStyle(color: Color(0xFFFFFFFF)),
      ),
      record: false,
    );
    controller.setTool(SelectTool.idValue);

    controller.dispatchCanvasEvent(
      const CanvasDoubleTapEvent(
        screenPoint: Offset(60, 40),
        worldPoint: Offset(60, 40),
        transform: CanvasTransform.identity,
      ),
    );

    expect(controller.editingShapeLabelElementId, 'shape-1');
    controller.endShapeLabelEditing(text: 'Shape label');
    expect(
      (controller.elementById('shape-1') as DrawioShapeElement).label,
      'Shape label',
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  test('line label serializes, restores, moves and scales with line', () {
    const element = LineElement(
      id: 'line-1',
      start: Offset(0, 0),
      end: Offset(100, 0),
      label: 'HTTP',
      labelStyle: TextStyle(
        color: Color(0xFF1D4ED8),
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
      labelOffset: Offset(4, -10),
      labelBackground: Color(0xFFFFFFFF),
    );

    expect(
      LineLabelPainter.labelCenter(
        [element.start, element.end],
        labelPosition: element.labelPosition,
        labelOffset: element.labelOffset,
      ),
      const Offset(54, -10),
    );

    final restored =
        CanvasSerializer.elementFromJson(element.toJson()) as LineElement;
    expect(restored.label, 'HTTP');
    expect(restored.labelStyle.color, const Color(0xFF1D4ED8));
    expect(restored.labelStyle.fontSize, 16);
    expect(restored.labelStyle.fontWeight, FontWeight.w700);
    expect(restored.labelOffset, const Offset(4, -10));
    expect(restored.labelBackground, const Color(0xFFFFFFFF));

    final moved = element.translate(const Offset(10, 5));
    expect(
      LineLabelPainter.labelCenter(
        [moved.start, moved.end],
        labelPosition: moved.labelPosition,
        labelOffset: moved.labelOffset,
      ),
      const Offset(64, -5),
    );

    final scaled = element.scaleElement(2, pivot: Offset.zero);
    expect(scaled.end, const Offset(200, 0));
    expect(scaled.labelStyle.fontSize, 32);
    expect(scaled.labelOffset, const Offset(8, -20));
  });

  test('polyline label uses middle of total path length', () {
    const element = PolylineElement(
      id: 'poly-1',
      points: [Offset(0, 0), Offset(100, 0), Offset(100, 100)],
      label: 'Middle',
    );

    expect(
      LineLabelPainter.labelCenter(
        element.points,
        labelPosition: element.labelPosition,
        labelOffset: element.labelOffset,
      ),
      const Offset(100, 0),
    );

    final restored =
        CanvasSerializer.elementFromJson(element.toJson()) as PolylineElement;
    expect(restored.label, 'Middle');
    expect(restored.labelPosition, 0.5);
    expect(restored.labelOffset, Offset.zero);
  });

  test('arrow label serializes and svg exporter emits line labels', () {
    const arrow = ArrowElement(
      id: 'arrow-1',
      start: Offset(0, 0),
      end: Offset(80, 0),
      label: 'calls',
      labelPosition: 0.25,
      labelOffset: Offset(0, -8),
      labelBackground: Color(0xFFFFF7ED),
    );
    final restored =
        CanvasSerializer.elementFromJson(arrow.toJson()) as ArrowElement;
    expect(restored.label, 'calls');
    expect(restored.labelPosition, 0.25);
    expect(restored.labelOffset, const Offset(0, -8));

    final svg = SvgExporter.exportElements(
      elements: const [
        LineElement(
          id: 'line-1',
          start: Offset(0, 0),
          end: Offset(100, 0),
          label: 'Line label',
        ),
        PolylineElement(
          id: 'poly-1',
          points: [Offset(0, 20), Offset(40, 20), Offset(40, 60)],
          label: 'Polyline label',
          labelBackground: Color(0xFFFFFFFF),
        ),
        arrow,
      ],
      bounds: const Rect.fromLTWH(-20, -40, 160, 140),
    );

    expect(svg, contains('Line label'));
    expect(svg, contains('Polyline label'));
    expect(svg, contains('calls'));
    expect(svg, contains('<rect x='));
    expect(svg, contains('text-anchor="middle"'));
  });

  test('old line json restores label defaults without changing hit test', () {
    final restored =
        CanvasSerializer.elementFromJson({
              'id': 'line-1',
              'type': 'line',
              'start': {'x': 0, 'y': 0},
              'end': {'x': 100, 'y': 0},
            })
            as LineElement;

    expect(restored.label, isNull);
    expect(restored.labelStyle.fontSize, 14);
    expect(restored.labelPosition, 0.5);
    expect(restored.labelOffset, Offset.zero);
    expect(restored.hitTest(const Offset(50, 3)), isTrue);
    expect(restored.hitTest(const Offset(50, 30)), isFalse);
  });
  test('double tapping polyline begins line label editing', () {
    final controller = CanvasController();
    controller
      ..addElement(
        const PolylineElement(
          id: 'poly-1',
          points: [Offset(0, 0), Offset(100, 0), Offset(100, 100)],
        ),
        record: false,
      )
      ..setTool(SelectTool.idValue);

    controller.dispatchCanvasEvent(
      const CanvasDoubleTapEvent(
        screenPoint: Offset(100, 0),
        worldPoint: Offset(100, 0),
        transform: CanvasTransform.identity,
      ),
    );

    expect(controller.editingShapeLabelElementId, 'poly-1');
    controller.endShapeLabelEditing(text: 'Flow');
    expect((controller.elementById('poly-1') as PolylineElement).label, 'Flow');
  });

  test('double tapping line and arrow begins label editing', () {
    final controller = CanvasController();
    controller
      ..addElement(
        const LineElement(
          id: 'line-1',
          start: Offset(0, 0),
          end: Offset(100, 0),
        ),
        record: false,
      )
      ..addElement(
        const ArrowElement(
          id: 'arrow-1',
          start: Offset(0, 50),
          end: Offset(100, 50),
        ),
        record: false,
      )
      ..setTool(SelectTool.idValue);

    controller.dispatchCanvasEvent(
      const CanvasDoubleTapEvent(
        screenPoint: Offset(50, 0),
        worldPoint: Offset(50, 0),
        transform: CanvasTransform.identity,
      ),
    );
    expect(controller.editingShapeLabelElementId, 'line-1');
    controller.endShapeLabelEditing(text: 'Line');
    expect((controller.elementById('line-1') as LineElement).label, 'Line');

    controller.dispatchCanvasEvent(
      const CanvasDoubleTapEvent(
        screenPoint: Offset(50, 50),
        worldPoint: Offset(50, 50),
        transform: CanvasTransform.identity,
      ),
    );
    expect(controller.editingShapeLabelElementId, 'arrow-1');
    controller.endShapeLabelEditing(text: 'Arrow');
    expect((controller.elementById('arrow-1') as ArrowElement).label, 'Arrow');
  });
}

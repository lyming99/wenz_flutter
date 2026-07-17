import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  group('shared line arrow settings', () {
    test('straight, polyline and curve default to no arrows', () {
      const line = LineElement(
        id: 'line',
        start: Offset.zero,
        end: Offset(100, 0),
      );
      const polyline = PolylineElement(
        id: 'polyline',
        points: [Offset.zero, Offset(50, 0), Offset(50, 50)],
      );
      const curve = CurveElement(
        id: 'curve',
        start: Offset.zero,
        control: Offset(50, 50),
        end: Offset(100, 0),
      );

      expect(line.arrowStyle.mode, LineArrowMode.none);
      expect(polyline.arrowStyle.mode, LineArrowMode.none);
      expect(curve.arrowStyle.mode, LineArrowMode.none);
    });

    test('presets map to no arrow, end arrow and arrows at both ends', () {
      const base = LineArrowStyle(headSize: 20);

      final none = base.withMode(LineArrowMode.none);
      final single = base.withMode(LineArrowMode.single);
      final both = base.withMode(LineArrowMode.both);

      expect(none.hasAnyArrow, isFalse);
      expect(single.hasStartArrow, isFalse);
      expect(single.hasEndArrow, isTrue);
      expect(both.hasStartArrow, isTrue);
      expect(both.hasEndArrow, isTrue);
      expect(both.headSize, 20);
    });

    test('double arrows round-trip for every supported line type', () {
      const elements = <CanvasElement>[
        LineElement(
          id: 'line',
          start: Offset.zero,
          end: Offset(100, 0),
          startArrowStyle: LineArrowType.normal,
          endArrowStyle: LineArrowType.normal,
        ),
        PolylineElement(
          id: 'polyline',
          points: [Offset.zero, Offset(50, 0), Offset(50, 50)],
          startArrowStyle: LineArrowType.normal,
          endArrowStyle: LineArrowType.normal,
        ),
        CurveElement(
          id: 'curve',
          start: Offset.zero,
          control: Offset(50, 50),
          end: Offset(100, 0),
          startArrowStyle: LineArrowType.normal,
          endArrowStyle: LineArrowType.normal,
        ),
      ];

      for (final element in elements) {
        final restored = CanvasSerializer.elementFromJson(element.toJson());
        final arrowStyle = switch (restored) {
          final LineElement e => e.arrowStyle,
          final PolylineElement e => e.arrowStyle,
          final CurveElement e => e.arrowStyle,
          _ => fail('Unexpected element type: ${restored.runtimeType}'),
        };
        expect(arrowStyle.mode, LineArrowMode.both);
      }
    });

    test('controller applies modes and records undo history', () {
      final controller = CanvasController()
        ..addElement(
          const LineElement(
            id: 'line',
            start: Offset.zero,
            end: Offset(100, 0),
          ),
          record: false,
        );

      controller.updateLineArrowMode('line', LineArrowMode.both);
      expect(
        (controller.elementById('line') as LineElement).arrowStyle.mode,
        LineArrowMode.both,
      );

      controller.undo();
      expect(
        (controller.elementById('line') as LineElement).arrowStyle.mode,
        LineArrowMode.none,
      );
      controller.redo();
      expect(
        (controller.elementById('line') as LineElement).arrowStyle.mode,
        LineArrowMode.both,
      );
    });

    test('straight line hit testing includes arrowheads at both ends', () {
      const line = LineElement(
        id: 'line',
        start: Offset.zero,
        end: Offset(100, 0),
        startArrowStyle: LineArrowType.normal,
        endArrowStyle: LineArrowType.normal,
      );

      expect(line.hitTest(const Offset(12, 8), tolerance: 1), isTrue);
      expect(line.hitTest(const Offset(88, 8), tolerance: 1), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  group('CurveElement arrows', () {
    test('copyWith and scaleElement preserve arrow settings', () {
      const element = CurveElement(
        id: 'curve-1',
        start: Offset.zero,
        control: Offset(50, 0),
        end: Offset(100, 0),
        style: PaintStyle(strokeWidth: 2),
        endArrow: true,
        headSize: 12,
      );

      final copied = element.copyWith(end: const Offset(120, 0));
      expect(copied.endArrow, isTrue);
      expect(copied.headSize, 12);
      expect(copied.end, const Offset(120, 0));

      final disabled = element.copyWith(endArrow: false);
      expect(disabled.endArrow, isFalse);
      expect(disabled.headSize, 12);

      final scaled = element.scaleElement(2, pivot: Offset.zero);
      expect(scaled.endArrow, isTrue);
      expect(scaled.headSize, 24);
      expect(scaled.style.strokeWidth, 4);
      expect(scaled.control, const Offset(100, 0));
      expect(scaled.end, const Offset(200, 0));
    });

    test('bounds and hitTest include enabled arrowhead only', () {
      const base = CurveElement(
        id: 'curve-1',
        start: Offset.zero,
        control: Offset(50, 0),
        end: Offset(100, 0),
        style: PaintStyle(strokeWidth: 2),
        headSize: 20,
      );
      final withArrow = base.copyWith(endArrow: true);

      expect(base.bounds.right, 101);
      expect(withArrow.bounds.right, 120);
      expect(base.hitTest(const Offset(50, 0)), isTrue);
      expect(base.hitTest(const Offset(84, 11)), isFalse);
      expect(withArrow.hitTest(const Offset(84, 11)), isTrue);
    });

    test('end tangent falls back when control point equals end', () {
      const element = CurveElement(
        id: 'degenerate-curve',
        start: Offset.zero,
        control: Offset(100, 0),
        end: Offset(100, 0),
        style: PaintStyle(strokeWidth: 2),
        endArrow: true,
        headSize: 20,
      );

      expect(element.endTangentDirection, isNotNull);
      expect(element.hitTest(const Offset(84, 11)), isTrue);
    });
  });

  group('CurveElement bindings', () {
    test('copy, translate, and scale preserve endpoint bindings', () {
      const element = CurveElement(
        id: 'bound-curve',
        start: Offset(10, 20),
        control: Offset(50, 80),
        end: Offset(100, 30),
        startBinding: SnapBinding(
          elementId: 'start-shape',
          anchorId: 'right',
        ),
        endBinding: SnapBinding(
          elementId: 'end-shape',
          anchorId: 'left',
        ),
      );

      final copied = element.copyWith(control: const Offset(60, 90));
      final translated = element.translate(const Offset(5, -10));
      final scaled = element.scaleElement(2, pivot: Offset.zero);

      for (final transformed in [copied, translated, scaled]) {
        expect(transformed.startBinding?.elementId, 'start-shape');
        expect(transformed.startBinding?.anchorId, 'right');
        expect(transformed.endBinding?.elementId, 'end-shape');
        expect(transformed.endBinding?.anchorId, 'left');
      }
      expect(translated.start, const Offset(15, 10));
      expect(scaled.end, const Offset(200, 60));
    });

    test('copyWith can clear either endpoint binding independently', () {
      const element = CurveElement(
        id: 'bound-curve',
        start: Offset.zero,
        control: Offset(50, 50),
        end: Offset(100, 0),
        startBinding: SnapBinding(
          elementId: 'start-shape',
          anchorId: 'center',
        ),
        endBinding: SnapBinding(
          elementId: 'end-shape',
          anchorId: 'center',
        ),
      );

      final clearedStart = element.copyWith(startBinding: null);
      final clearedEnd = element.copyWith(endBinding: null);

      expect(clearedStart.startBinding, isNull);
      expect(clearedStart.endBinding?.elementId, 'end-shape');
      expect(clearedEnd.endBinding, isNull);
      expect(clearedEnd.startBinding?.elementId, 'start-shape');
    });
  });
}

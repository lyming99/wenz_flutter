import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/src/canvas/canvas_controller.dart';
import 'package:wenz_draw/src/canvas/paint_style.dart';
import 'package:wenz_draw/src/elements/rect_element.dart';
import 'package:wenz_draw/src/elements/text_element.dart';
import 'package:wenz_draw/src/infinite_canvas/canvas_event.dart';
import 'package:wenz_draw/src/infinite_canvas/canvas_transform.dart';
import 'package:wenz_draw/src/layers/auto_layering.dart';
import 'package:wenz_draw/src/tools/alignment_tools.dart';
import 'package:wenz_draw/src/tools/eraser_tool.dart';

void main() {
  CanvasController createController() {
    return CanvasController(
      autoLayeringPolicy: const AutoLayeringPolicy.manual(),
    );
  }

  RectElement makeRect(
    String id,
    Rect rect, {
    int zIndex = 0,
    String groupId = '',
  }) {
    return RectElement(
      id: id,
      rect: rect,
      strokeStyle: const PaintStyle(),
      fillStyle: const PaintStyle(),
      zIndex: zIndex,
      groupId: groupId.isEmpty ? null : groupId,
    );
  }

  group('Clipboard operations', () {
    // ─── copySelected + paste ────────────────────────────────────
    test('copySelected + paste creates offset duplicates', () {
      final controller = createController();

      controller.addElement(
        makeRect('r1', const Rect.fromLTWH(0, 0, 100, 50)),
        record: false,
      );
      controller.addElement(
        makeRect('r2', const Rect.fromLTWH(200, 0, 100, 50)),
        record: false,
      );

      controller.setSelection({'r1', 'r2'});
      controller.copySelected();
      controller.paste();

      // 2 original + 2 pasted
      expect(controller.elements.length, 4);

      // Pasted elements should be offset by (20, 20)
      final newElements = controller.elements
          .where((e) => e.id != 'r1' && e.id != 'r2')
          .toList();
      expect(newElements.length, 2);
      for (final e in newElements) {
        expect(e, isA<RectElement>());
        final rect = (e as RectElement).rect;
        // The pasted rects should be shifted by Offset(20, 20) from originals
        // Originals: (0,0) and (200,0); pasted should be (20,20) and (220,20)
        expect(rect.left, anyOf(20, 220));
        expect(rect.top, 20);
      }
    });

    // ─── cutSelected ──────────────────────────────────────────────
    test('cutSelected removes elements and clipboard retains them', () {
      final controller = createController();

      controller.addElement(
        makeRect('r1', const Rect.fromLTWH(0, 0, 100, 50)),
        record: false,
      );

      controller.setSelection({'r1'});
      controller.cutSelected();

      // Element removed
      expect(controller.elements, isEmpty);

      // Clipboard retained — paste should bring it back
      controller.paste();
      expect(controller.elements.length, 1);
      final pasted = controller.elements.first as RectElement;
      expect(pasted.rect, const Rect.fromLTWH(20, 20, 100, 50));
    });

    // ─── duplicateSelected ────────────────────────────────────────
    test('duplicateSelected creates copy with different ID', () {
      final controller = createController();

      controller.addElement(
        makeRect('r1', const Rect.fromLTWH(0, 0, 100, 50)),
        record: false,
      );

      controller.setSelection({'r1'});
      controller.duplicateSelected();

      expect(controller.elements.length, 2);

      // The duplicate must have a different ID
      final ids = controller.elements.map((e) => e.id).toSet();
      expect(ids.length, 2);
      expect(ids, contains('r1'));

      // The duplicate should be offset by (20, 20)
      final dup = controller.elements.firstWhere((e) => e.id != 'r1');
      expect((dup as RectElement).rect, const Rect.fromLTWH(20, 20, 100, 50));

      // Selection should now be the duplicate
      expect(controller.selectedIds.length, 1);
      expect(controller.selectedIds, isNot(contains('r1')));
    });
  });

  group('Z-order operations', () {
    // ─── bringSelectedToFront / sendSelectedToBack ───────────────
    test('bringSelectedToFront moves selected to highest z-index', () {
      final controller = createController();

      controller.addElement(
        makeRect('a', const Rect.fromLTWH(0, 0, 50, 50), zIndex: 1),
        record: false,
      );
      controller.addElement(
        makeRect('b', const Rect.fromLTWH(0, 0, 50, 50), zIndex: 2),
        record: false,
      );
      controller.addElement(
        makeRect('c', const Rect.fromLTWH(0, 0, 50, 50), zIndex: 3),
        record: false,
      );

      // Select 'a' (z=1) and bring it to front
      controller.setSelection({'a'});
      controller.bringSelectedToFront();

      final aZ = controller.elementById('a')!.zIndex;
      expect(aZ, greaterThan(controller.elementById('c')!.zIndex),
          reason: 'After bringToFront, "a" should have the highest z');
      expect(aZ, 4);
    });

    test('sendSelectedToBack moves selected to lowest z-index', () {
      final controller = createController();

      controller.addElement(
        makeRect('a', const Rect.fromLTWH(0, 0, 50, 50), zIndex: 1),
        record: false,
      );
      controller.addElement(
        makeRect('b', const Rect.fromLTWH(0, 0, 50, 50), zIndex: 2),
        record: false,
      );
      controller.addElement(
        makeRect('c', const Rect.fromLTWH(0, 0, 50, 50), zIndex: 3),
        record: false,
      );

      // Select 'c' (z=3) and send to back
      controller.setSelection({'c'});
      controller.sendSelectedToBack();

      final cZ = controller.elementById('c')!.zIndex;
      expect(cZ, lessThan(controller.elementById('a')!.zIndex),
          reason: 'After sendToBack, "c" should have the lowest z');
      // min non-selected z is 1 (a), send 1 element → 1 - 1 = 0
      expect(cZ, 0);
    });
  });

  group('Group / ungroup', () {
    // ─── groupSelected / ungroupSelected ─────────────────────────
    test('groupSelected assigns same groupId to selected elements', () {
      final controller = createController();

      controller
        ..addElement(
          makeRect('a', const Rect.fromLTWH(0, 0, 50, 50)),
          record: false,
        )
        ..addElement(
          makeRect('b', const Rect.fromLTWH(100, 0, 50, 50)),
          record: false,
        )
        ..addElement(
          makeRect('c', const Rect.fromLTWH(200, 0, 50, 50)),
          record: false,
        );

      // Select 2 of them
      controller.setSelection({'a', 'b'});
      controller.groupSelected();

      final aGid = controller.elementById('a')!.groupId;
      final bGid = controller.elementById('b')!.groupId;
      final cGid = controller.elementById('c')!.groupId;

      expect(aGid, isNotNull);
      expect(aGid, bGid, reason: 'Grouped elements share the same groupId');
      expect(cGid, isNull, reason: 'Unselected element has no groupId');
    });

    test('ungroupSelected removes groupId from all group members', () {
      final controller = createController();

      controller
        ..addElement(
          makeRect('a', const Rect.fromLTWH(0, 0, 50, 50), groupId: 'grp1'),
          record: false,
        )
        ..addElement(
          makeRect('b', const Rect.fromLTWH(100, 0, 50, 50), groupId: 'grp1'),
          record: false,
        )
        ..addElement(
          makeRect('c', const Rect.fromLTWH(200, 0, 50, 50)),
          record: false,
        );

      controller.setSelection({'a', 'b'});
      controller.ungroupSelected();

      expect(controller.elementById('a')!.groupId, isNull);
      expect(controller.elementById('b')!.groupId, isNull);
      expect(controller.elementById('c')!.groupId, isNull);
    });
  });

  group('Alignment & distribution', () {
    // ─── alignSelected ───────────────────────────────────────────
    test('alignSelected top makes all tops equal', () {
      final controller = createController();

      controller
        ..addElement(
          makeRect('a', const Rect.fromLTWH(0, 10, 50, 50)),
          record: false,
        )
        ..addElement(
          makeRect('b', const Rect.fromLTWH(100, 30, 50, 50)),
          record: false,
        )
        ..addElement(
          makeRect('c', const Rect.fromLTWH(200, 5, 50, 50)),
          record: false,
        );

      controller.setSelection({'a', 'b', 'c'});
      controller.alignSelected(AlignMode.top);

      final tops = controller.elements.map((e) => e.bounds.top).toSet();
      expect(tops.length, 1, reason: 'All elements should share the same top');
    });

    // ─── distributeSelected ──────────────────────────────────────
    test('distributeSelected horizontal produces equal gaps', () {
      final controller = createController();

      // Three rects at uneven spacings: all same width
      controller
        ..addElement(
          makeRect('a', const Rect.fromLTWH(0, 0, 50, 50)),
          record: false,
        )
        ..addElement(
          makeRect('b', const Rect.fromLTWH(200, 0, 50, 50)),
          record: false,
        )
        ..addElement(
          makeRect('c', const Rect.fromLTWH(500, 0, 50, 50)),
          record: false,
        );

      controller.setSelection({'a', 'b', 'c'});
      controller.distributeSelected(AlignAxis.horizontal);

      final sorted = controller.elements.toList()
        ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
      final aRight = sorted[0].bounds.right;
      final bLeft = sorted[1].bounds.left;
      final bRight = sorted[1].bounds.right;
      final cLeft = sorted[2].bounds.left;

      final gap1 = bLeft - aRight;
      final gap2 = cLeft - bRight;
      expect(gap1, closeTo(gap2, 0.001),
          reason: 'Gaps between distributed elements should be equal');
    });
  });

  group('Eraser batch undo', () {
    // ─── Eraser batch undo ───────────────────────────────────────
    test('erasing multiple elements in one drag creates single undo step', () {
      final controller = createController();

      // Three rects that overlap a horizontal eraser path at y=25
      controller
        ..addElement(
          makeRect('r1', const Rect.fromLTWH(0, 0, 50, 50)),
          record: false,
        )
        ..addElement(
          makeRect('r2', const Rect.fromLTWH(60, 0, 50, 50)),
          record: false,
        )
        ..addElement(
          makeRect('r3', const Rect.fromLTWH(120, 0, 50, 50)),
          record: false,
        );

      controller.setTool(EraserTool.idValue);

      // Simulate a single eraser drag session: pointerDown, multiple moves, up
      controller.dispatchCanvasEvent(
        const CanvasPointerDownEvent(
          screenPoint: Offset(25, 25),
          worldPoint: Offset(25, 25),
          transform: CanvasTransform.identity,
        ),
      );
      controller.dispatchCanvasEvent(
        const CanvasPointerMoveEvent(
          screenPoint: Offset(85, 25),
          worldPoint: Offset(85, 25),
          transform: CanvasTransform.identity,
          delta: Offset(60, 0),
        ),
      );
      controller.dispatchCanvasEvent(
        const CanvasPointerMoveEvent(
          screenPoint: Offset(145, 25),
          worldPoint: Offset(145, 25),
          transform: CanvasTransform.identity,
          delta: Offset(60, 0),
        ),
      );
      controller.dispatchCanvasEvent(
        const CanvasPointerUpEvent(
          screenPoint: Offset(145, 25),
          worldPoint: Offset(145, 25),
          transform: CanvasTransform.identity,
        ),
      );

      // All elements erased
      expect(controller.elements, isEmpty,
          reason: 'All elements should be erased');

      // Single undo restores everything
      expect(controller.canUndo, isTrue);
      controller.undo();

      expect(controller.elements.length, 3,
          reason: 'One undo step should restore all erased elements');
    });
  });

  group('Undo / redo', () {
    // ─── Undo/redo after paste ───────────────────────────────────
    test('undo after paste removes pasted elements, redo brings them back', () {
      final controller = createController();

      controller.addElement(
        makeRect('r1', const Rect.fromLTWH(0, 0, 100, 50)),
        record: false,
      );

      controller.setSelection({'r1'});
      controller.copySelected();

      // Before paste: 1 element
      expect(controller.elements.length, 1);

      controller.paste();
      expect(controller.elements.length, 2);

      // Undo removes the pasted element
      controller.undo();
      expect(controller.elements.length, 1);
      expect(controller.elements.single.id, 'r1');

      // Redo brings it back
      controller.redo();
      expect(controller.elements.length, 2);
    });
  });
}

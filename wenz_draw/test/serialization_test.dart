import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/src/serialization/canvas_serializer.dart';
import 'package:wenz_draw/src/serialization/canvas_document.dart';
import 'package:wenz_draw/src/elements/line_element.dart';
import 'package:wenz_draw/src/elements/rect_element.dart';
import 'package:wenz_draw/src/elements/ellipse_element.dart';
import 'package:wenz_draw/src/elements/text_element.dart';
import 'package:wenz_draw/src/elements/image_element.dart';
import 'package:wenz_draw/src/elements/polyline_element.dart';
import 'package:wenz_draw/src/elements/curve_element.dart';
import 'package:wenz_draw/src/elements/canvas_element.dart';
import 'package:wenz_draw/src/canvas/canvas_controller.dart';
import 'package:wenz_draw/src/canvas/paint_style.dart';
import 'package:wenz_draw/src/layers/canvas_layer.dart';
import 'package:wenz_draw/src/layers/auto_layering.dart';
import 'package:wenz_draw/src/snap/snap_resolver.dart';

void main() {
  group('Serialization round-trip', () {
    // ─── LineElement ──────────────────────────────────────────────
    test('LineElement round-trip preserves all fields', () {
      const element = LineElement(
        id: 'line-1',
        start: Offset(10, 20),
        end: Offset(200, 300),
        style: PaintStyle(color: Color(0xFF112233), strokeWidth: 4),
        startBinding: SnapBinding(elementId: 'shape-a', anchorId: 'right'),
        endBinding: SnapBinding(elementId: 'shape-b', anchorId: 'left'),
        label: 'Connection',
        labelStyle: TextStyle(fontSize: 18, color: Color(0xFFAABBCC)),
        zIndex: 5,
        groupId: 'group-1',
      );

      final json = element.toJson();
      final restored = CanvasSerializer.elementFromJson(json) as LineElement;

      expect(restored, isA<LineElement>());
      expect(restored.id, 'line-1');
      expect(restored.type, LineElement.elementType);
      expect(restored.start, const Offset(10, 20));
      expect(restored.end, const Offset(200, 300));
      expect(restored.style.color, const Color(0xFF112233));
      expect(restored.style.strokeWidth, 4);
      expect(restored.startBinding!.elementId, 'shape-a');
      expect(restored.startBinding!.anchorId, 'right');
      expect(restored.endBinding!.elementId, 'shape-b');
      expect(restored.endBinding!.anchorId, 'left');
      expect(restored.label, 'Connection');
      expect(restored.labelStyle.fontSize, 18);
      expect(restored.labelStyle.color, const Color(0xFFAABBCC));
      expect(restored.zIndex, 5);
      expect(restored.groupId, 'group-1');
    });

    // ─── RectElement ──────────────────────────────────────────────
    test('RectElement round-trip preserves all fields', () {
      const element = RectElement(
        id: 'rect-1',
        rect: Rect.fromLTRB(10, 20, 200, 150),
        strokeStyle: PaintStyle(color: Color(0xFFFF0000), strokeWidth: 3),
        fillStyle: PaintStyle(color: Color(0xFF00FF00)),
        label: 'Box',
        rotation: 0.5,
        zIndex: 3,
        groupId: 'group-rect',
      );

      final json = element.toJson();
      final restored = CanvasSerializer.elementFromJson(json) as RectElement;

      expect(restored, isA<RectElement>());
      expect(restored.id, 'rect-1');
      expect(restored.type, RectElement.elementType);
      expect(restored.rect, const Rect.fromLTRB(10, 20, 200, 150));
      expect(restored.strokeStyle.color, const Color(0xFFFF0000));
      expect(restored.strokeStyle.strokeWidth, 3);
      expect(restored.fillStyle!.color, const Color(0xFF00FF00));
      expect(restored.label, 'Box');
      expect(restored.rotation, 0.5);
      expect(restored.zIndex, 3);
      expect(restored.groupId, 'group-rect');
    });

    // ─── EllipseElement ───────────────────────────────────────────
    test('EllipseElement round-trip preserves all fields', () {
      const element = EllipseElement(
        id: 'ellipse-1',
        rect: Rect.fromLTRB(0, 0, 100, 80),
        strokeStyle: PaintStyle(color: Color(0xFF0000FF), strokeWidth: 2),
        fillStyle: PaintStyle(color: Color(0xFFFFFF00)),
        label: 'Circle',
        rotation: 1.2,
        zIndex: 7,
        groupId: 'group-ellipse',
      );

      final json = element.toJson();
      final restored =
          CanvasSerializer.elementFromJson(json) as EllipseElement;

      expect(restored, isA<EllipseElement>());
      expect(restored.id, 'ellipse-1');
      expect(restored.type, EllipseElement.elementType);
      expect(restored.rect, const Rect.fromLTRB(0, 0, 100, 80));
      expect(restored.strokeStyle.color, const Color(0xFF0000FF));
      expect(restored.strokeStyle.strokeWidth, 2);
      expect(restored.fillStyle!.color, const Color(0xFFFFFF00));
      expect(restored.label, 'Circle');
      expect(restored.rotation, 1.2);
      expect(restored.zIndex, 7);
      expect(restored.groupId, 'group-ellipse');
    });

    // ─── TextElement ──────────────────────────────────────────────
    test('TextElement round-trip preserves custom style and layout', () {
      final element = TextElement(
        id: 'text-1',
        position: const Offset(50, 60),
        text: 'Hello World',
        style: const TextStyle(
          color: Color(0xFF445566),
          fontSize: 32,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
        maxWidth: 200,
        boxSize: const Size(180, 40),
        zIndex: 2,
        groupId: 'group-text',
      );

      final json = element.toJson();
      final restored = CanvasSerializer.elementFromJson(json) as TextElement;

      expect(restored, isA<TextElement>());
      expect(restored.id, 'text-1');
      expect(restored.type, TextElement.elementType);
      expect(restored.position, const Offset(50, 60));
      expect(restored.text, 'Hello World');
      expect(restored.style.color, const Color(0xFF445566));
      expect(restored.style.fontSize, 32);
      expect(restored.style.fontWeight, FontWeight.bold);
      expect(restored.style.height, 1.5);
      expect(restored.textAlign, TextAlign.center);
      expect(restored.maxWidth, 200);
      expect(restored.boxSize, const Size(180, 40));
      expect(restored.zIndex, 2);
      expect(restored.groupId, 'group-text');
    });

    // ─── ImageElement (Bug B2: BoxFit preservation) ──────────────
    test('ImageElement round-trip preserves BoxFit.cover (Bug B2)', () {
      const element = ImageElement(
        id: 'img-1',
        rect: Rect.fromLTRB(0, 0, 400, 300),
        fit: BoxFit.cover,
        zIndex: 10,
        groupId: 'group-img',
      );

      final json = element.toJson();
      final restored = CanvasSerializer.elementFromJson(json) as ImageElement;

      expect(restored, isA<ImageElement>());
      expect(restored.id, 'img-1');
      expect(restored.type, ImageElement.elementType);
      expect(restored.rect, const Rect.fromLTRB(0, 0, 400, 300));
      expect(restored.fit, BoxFit.cover,
          reason: 'BoxFit.cover must survive serialization (Bug B2)');
      expect(restored.zIndex, 10);
      expect(restored.groupId, 'group-img');
    });

    test('ImageElement round-trip preserves BoxFit.fitWidth', () {
      const element = ImageElement(
        id: 'img-2',
        rect: Rect.fromLTRB(0, 0, 200, 200),
        fit: BoxFit.fitWidth,
      );

      final json = element.toJson();
      final restored = CanvasSerializer.elementFromJson(json) as ImageElement;

      expect(restored.fit, BoxFit.fitWidth);
    });

    // ─── PolylineElement ──────────────────────────────────────────
    test('PolylineElement round-trip preserves points, arrows, bindings', () {
      const element = PolylineElement(
        id: 'poly-1',
        points: [
          Offset(0, 0),
          Offset(50, 30),
          Offset(100, 0),
          Offset(150, 30),
        ],
        style: PaintStyle(color: Color(0xFFCC0000), strokeWidth: 2.5),
        startBinding: SnapBinding(elementId: 'node-a', anchorId: 'right'),
        endBinding: SnapBinding(elementId: 'node-b', anchorId: 'left'),
        endArrow: true,
        headSize: 18,
        label: 'Connector',
        zIndex: 4,
        groupId: 'group-poly',
      );

      final json = element.toJson();
      final restored =
          CanvasSerializer.elementFromJson(json) as PolylineElement;

      expect(restored, isA<PolylineElement>());
      expect(restored.id, 'poly-1');
      expect(restored.type, PolylineElement.elementType);
      expect(restored.points.length, 4);
      expect(restored.points[0], Offset.zero);
      expect(restored.points[1], const Offset(50, 30));
      expect(restored.points[2], const Offset(100, 0));
      expect(restored.points[3], const Offset(150, 30));
      expect(restored.style.color, const Color(0xFFCC0000));
      expect(restored.style.strokeWidth, 2.5);
      expect(restored.startBinding!.elementId, 'node-a');
      expect(restored.endBinding!.elementId, 'node-b');
      expect(restored.endArrow, isTrue);
      expect(restored.headSize, 18);
      expect(restored.label, 'Connector');
      expect(restored.zIndex, 4);
      expect(restored.groupId, 'group-poly');
    });

    // ─── CurveElement ─────────────────────────────────────────────
    test('CurveElement round-trip preserves start, end, control, style', () {
      const element = CurveElement(
        id: 'curve-1',
        start: Offset(0, 0),
        end: Offset(100, 0),
        control: Offset(50, 80),
        style: PaintStyle(color: Color(0xFF880088), strokeWidth: 3),
        zIndex: 6,
        groupId: 'group-curve',
      );

      final json = element.toJson();
      final restored = CanvasSerializer.elementFromJson(json) as CurveElement;

      expect(restored, isA<CurveElement>());
      expect(restored.id, 'curve-1');
      expect(restored.type, CurveElement.elementType);
      expect(restored.start, Offset.zero);
      expect(restored.end, const Offset(100, 0));
      expect(restored.control, const Offset(50, 80));
      expect(restored.style.color, const Color(0xFF880088));
      expect(restored.style.strokeWidth, 3);
      expect(restored.zIndex, 6);
      expect(restored.groupId, 'group-curve');
    });

    // ─── Canvas layer round-trip ──────────────────────────────────
    test('CanvasDocument.toJson() and fromJson() round-trip with layers', () {
      final document = CanvasDocument(
        version: '1.1',
        layers: const [
          CanvasLayer(id: 'background', name: 'Background', isVisible: false),
          CanvasLayer(
            id: 'foreground',
            name: 'Foreground',
            isVisible: true,
            isLocked: true,
            opacity: 0.8,
          ),
        ],
        elements: [
          const RectElement(
            id: 'rect-bg',
            rect: Rect.fromLTWH(0, 0, 50, 50),
            layerId: 'background',
          ),
          TextElement(id: 'text-fg', position: Offset.zero, text: 'Hi'),
        ],
      );

      final json = document.toJson();
      final restored = CanvasSerializer.fromJson(json);

      // Verify layers
      expect(restored.layers.length, 2);
      expect(restored.layers[0].id, 'background');
      expect(restored.layers[0].name, 'Background');
      expect(restored.layers[0].isVisible, isFalse);
      expect(restored.layers[1].id, 'foreground');
      expect(restored.layers[1].name, 'Foreground');
      expect(restored.layers[1].isVisible, isTrue);
      expect(restored.layers[1].isLocked, isTrue);
      expect(restored.layers[1].opacity, 0.8);

      // Verify elements
      expect(restored.elements.length, 2);
      expect(restored.elements[0].id, 'rect-bg');
      expect(restored.elements[0], isA<RectElement>());
      expect((restored.elements[0] as RectElement).layerId, 'background');
      expect(restored.elements[1].id, 'text-fg');
      expect(restored.elements[1], isA<TextElement>());
    });

    // ─── Sprint 5: TextElement rotation ─────────────────────────
    test('TextElement rotation round-trip preserves rotation', () {
      final element = TextElement(
        id: 'text-rot',
        position: const Offset(50, 60),
        text: 'Rotated',
        rotation: 0.5,
      );

      final json = element.toJson();
      final restored = CanvasSerializer.elementFromJson(json) as TextElement;

      expect(restored, isA<TextElement>());
      expect(restored.rotation, 0.5);
    });

    // ─── Sprint 5: ImageElement rotation ─────────────────────────
    test('ImageElement rotation round-trip preserves rotation', () {
      const element = ImageElement(
        id: 'img-rot',
        rect: Rect.fromLTRB(0, 0, 200, 150),
        rotation: 1.2,
      );

      final json = element.toJson();
      final restored = CanvasSerializer.elementFromJson(json) as ImageElement;

      expect(restored, isA<ImageElement>());
      expect(restored.rotation, 1.2);
    });

    // ─── Sprint 5: ImageElement base64 imageData ─────────────────
    test('ImageElement base64 imageData round-trip preserves data', () {
      const element = ImageElement(
        id: 'img-b64',
        rect: Rect.fromLTRB(0, 0, 100, 100),
        imageData: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      );

      final json = element.toJson();
      final restored = CanvasSerializer.elementFromJson(json) as ImageElement;

      expect(restored, isA<ImageElement>());
      expect(restored.imageData, isNotNull);
      expect(restored.imageData, 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');
    });

    // ─── Layer preservation in load() (Bug B1) ───────────────────
    test('Layer preservation in load() preserves custom layers (Bug B1)', () {
      // Create a controller with custom layers and elements
      final controller = CanvasController(
        autoLayeringPolicy: const AutoLayeringPolicy.manual(),
      );
      controller.addLayer(name: 'Custom Layer');
      final customLayerId = controller.activeLayerId;
      controller.addElement(
        RectElement(
          id: 'el-1',
          rect: const Rect.fromLTWH(10, 10, 100, 100),
          layerId: customLayerId,
          zIndex: 0,
        ),
        record: false,
      );
      controller.addElement(
        TextElement(
          id: 'el-2',
          position: const Offset(200, 200),
          text: 'Label',
          layerId: customLayerId,
        ),
        record: false,
      );

      // Serialize
      final json = CanvasSerializer.toJson(controller);

      // Load into a new controller
      final newController = CanvasController(
        autoLayeringPolicy: const AutoLayeringPolicy.manual(),
      );
      CanvasSerializer.load(newController, json);

      // Verify layers are preserved (Bug B1: layers were being lost)
      expect(newController.layers.length, 2,
          reason: 'Custom layers must be preserved after load');
      expect(newController.layers.any((l) => l.id == customLayerId), isTrue);
      expect(newController.layers.any((l) => l.name == 'Custom Layer'), isTrue);

      // Verify elements are preserved with their layer assignments
      expect(newController.elements.length, 2);
      final rect = newController.elementById('el-1')!;
      expect(rect.layerId, customLayerId,
          reason: 'Element layer assignment must survive load');
      final text = newController.elementById('el-2')!;
      expect(text.layerId, customLayerId);
    });
  });
}

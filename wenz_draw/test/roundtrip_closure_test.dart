import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/src/canvas/canvas_controller.dart';
import 'package:wenz_draw/src/elements/rect_element.dart';
import 'package:wenz_draw/src/elements/text_element.dart';
import 'package:wenz_draw/src/elements/ellipse_element.dart';
import 'package:wenz_draw/src/infinite_canvas/infinite_canvas_controller.dart';
import 'package:wenz_draw/src/layers/canvas_layer.dart';
import 'package:wenz_draw/src/layers/layer_manager.dart';
import 'package:wenz_draw/src/serialization/canvas_document.dart';
import 'package:wenz_draw/src/serialization/canvas_serializer.dart';
import 'package:wenz_draw/src/serialization/document_store.dart';

/// End-to-end closure tests: 新建 → 编辑 → 保存 → 关闭 → 重新打开 → 继续编辑.
/// These exercise the full save/load round-trip through a [DocumentStore] and
/// assert that layers, elements, and the viewport all survive a close/reopen.
void main() {
  group('Document closure round-trip', () {
    test(
        'save via store then load into a fresh controller restores layers and '
        'elements', () async {
      // ── Session 1: build a document and persist it ───────────────
      final canvas1 = CanvasController(
        layerManager: LayerManager(
          layers: const [
            CanvasLayer(id: 'main', name: 'Main'),
            CanvasLayer(id: 'notes', name: 'Notes'),
          ],
          activeLayerId: 'main',
        ),
      );
      canvas1.addElement(
        const RectElement(
          id: 'rect-1',
          rect: Rect.fromLTWH(40, 40, 120, 80),
          label: 'Start',
          zIndex: 1,
        ),
        record: false,
      );
      canvas1.addElement(
        const EllipseElement(
          id: 'ell-1',
          rect: Rect.fromLTWH(300, 100, 160, 100),
          label: 'Done',
          zIndex: 2,
        ),
        record: false,
      );
      canvas1.addElement(
        TextElement(
          id: 'txt-1',
          position: const Offset(50, 200),
          text: 'Flow Sketch',
        ),
        record: false,
      );

      final view1 = InfiniteCanvasController(canvasController: canvas1);
      view1.setViewportSize(const Size(1024, 768));
      view1.zoomTo(1.5);
      view1.pan(const Offset(120, 80));
      final expectedViewport = view1.currentViewport;

      final store = MemoryDocumentStore();
      final json = CanvasSerializer.toJsonWithView(
        view1,
        viewport: view1.currentViewport,
        metadata: const DocumentMetadata(title: 'Flow Sketch', appId: 'test'),
      );
      await store.save(json);
      // Simulate "close": drop both controllers.
      view1.dispose();
      canvas1.dispose();

      // ── Session 2: reopen from the store into fresh controllers ──
      final canvas2 = CanvasController();
      final view2 = InfiniteCanvasController(canvasController: canvas2);
      view2.setViewportSize(const Size(1024, 768));

      final loaded = await store.load();
      expect(loaded, isNotNull);
      final document = CanvasSerializer.loadDocument(view2, loaded!);

      // Layers survive.
      expect(canvas2.layers.length, 2);
      expect(canvas2.layers[0].id, 'main');
      expect(canvas2.layers[1].id, 'notes');

      // Elements survive (type, id, geometry, label).
      expect(canvas2.elements.length, 3);
      final rect = canvas2.elements.whereType<RectElement>().single;
      expect(rect.id, 'rect-1');
      expect(rect.rect, const Rect.fromLTWH(40, 40, 120, 80));
      expect(rect.label, 'Start');
      final ell = canvas2.elements.whereType<EllipseElement>().single;
      expect(ell.id, 'ell-1');
      expect(ell.label, 'Done');
      final txt = canvas2.elements.whereType<TextElement>().single;
      expect(txt.id, 'txt-1');
      expect(txt.text, 'Flow Sketch');

      // Metadata survives.
      expect(document.metadata.title, 'Flow Sketch');
      expect(document.metadata.appId, 'test');

      // Viewport is restored (scale + center within tolerance).
      expect(document.viewport.scale, expectedViewport.scale);
      expect(
        (document.viewport.centerX! - expectedViewport.centerX!).abs() < 0.5,
        isTrue,
      );
      expect(
        (document.viewport.centerY! - expectedViewport.centerY!).abs() < 0.5,
        isTrue,
      );
      expect(view2.transform.scale, expectedViewport.scale);

      view2.dispose();
      canvas2.dispose();
    });

    test('DocumentStore.save/load round-trips the JSON verbatim', () async {
      final store = MemoryDocumentStore();
      expect(await store.exists(), isFalse);

      final doc = {
        'schemaVersion': '2.0',
        'metadata': {'title': 'X'},
        'layers': <Map<String, dynamic>>[],
        'elements': <Map<String, dynamic>>[],
      };
      await store.save(doc);
      expect(await store.exists(), isTrue);

      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!['schemaVersion'], '2.0');
      expect(loaded['metadata']['title'], 'X');

      // Mutating the returned map does not corrupt the stored document.
      loaded['metadata'] = {'title': 'tampered'};
      final reloaded = await store.load();
      expect(reloaded!['metadata']['title'], 'X');
    });

    test('loading a legacy schema-1.0 document upgrades to current', () {
      final legacy = <String, dynamic>{
        'version': '0.1.0',
        'layers': [
          {'id': 'l1', 'name': 'Layer 1'},
        ],
        'elements': [
          {
            'type': 'rect',
            'id': 'r1',
            'rect': {'left': 0, 'top': 0, 'right': 50, 'bottom': 50},
          },
        ],
      };

      final canvas = CanvasController();
      CanvasSerializer.load(canvas, legacy);

      expect(canvas.layers.length, 1);
      expect(canvas.layers.first.id, 'l1');
      expect(canvas.elements.length, 1);
      expect(canvas.elements.first.id, 'r1');
      canvas.dispose();
    });

    test(
        'a reopened document can be edited and re-saved without losing prior '
        'content', () async {
      final store = MemoryDocumentStore();
      final canvas1 = CanvasController();
      canvas1.addElement(
        const RectElement(id: 'r1', rect: Rect.fromLTWH(0, 0, 10, 10)),
        record: false,
      );
      final view1 = InfiniteCanvasController(canvasController: canvas1);
      await store.save(CanvasSerializer.toJsonWithView(view1));
      view1.dispose();
      canvas1.dispose();

      // Reopen, add another element, save again.
      final canvas2 = CanvasController();
      final view2 = InfiniteCanvasController(canvasController: canvas2);
      CanvasSerializer.loadDocument(view2, (await store.load())!);
      expect(canvas2.elements.length, 1);
      canvas2.addElement(
        const RectElement(id: 'r2', rect: Rect.fromLTWH(20, 20, 10, 10)),
        record: false,
      );
      await store.save(CanvasSerializer.toJsonWithView(view2));
      view2.dispose();
      canvas2.dispose();

      // Reopen again: both elements present.
      final canvas3 = CanvasController();
      CanvasSerializer.load(canvas3, (await store.load())!);
      expect(canvas3.elements.length, 2);
      expect(canvas3.elements.map((e) => e.id).toSet(), {'r1', 'r2'});
      canvas3.dispose();
    });
  });
}

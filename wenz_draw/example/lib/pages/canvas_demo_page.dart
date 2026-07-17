import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';
import 'package:wenz_draw/wenz_draw_mindmap.dart';
import 'package:wenz_draw/wenz_draw_ui.dart';

import '../utils/image_importer.dart';

class CanvasDemoPage extends StatefulWidget {
  const CanvasDemoPage({super.key, this.onShowMinimal});

  /// Called when the user wants to switch to the minimal kernel-only demo.
  final VoidCallback? onShowMinimal;

  @override
  State<CanvasDemoPage> createState() => _CanvasDemoPageState();
}

class _CanvasDemoPageState extends State<CanvasDemoPage> {
  late final CanvasController _canvasController;
  late final InfiniteCanvasController _viewController;
  late final MindmapSyncController _mindmapSync;

  /// In-memory store that backs the save/load round-trip in the 菜单. A real
  /// app would implement [DocumentStore] against a file, DB row, or note
  /// payload — the example keeps it in memory for portability.
  final MemoryDocumentStore _store = MemoryDocumentStore();

  @override
  void initState() {
    super.initState();
    _canvasController = CanvasController(
      // 与 draw.io 一致：边的默认样式即 OrthConnector（正交查表路由）
      connectorRoutingOptions: const ConnectorRoutingOptions(
        mode: ConnectorRoutingMode.orthConnector,
      ),
      layerManager: LayerManager(
        layers: const [
          CanvasLayer(id: 'product-flow', name: '产品流程'),
          CanvasLayer(id: 'annotations', name: '注释'),
          CanvasLayer(id: 'draft', name: '草稿'),
        ],
        activeLayerId: 'product-flow',
      ),
    );
    _viewController = InfiniteCanvasController(
      canvasController: _canvasController,
    );
    _mindmapSync = MindmapSyncController(_canvasController, _viewController);
    _addExampleDiagram();
  }

  @override
  void dispose() {
    _mindmapSync.dispose();
    _viewController.dispose();
    _canvasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WenzDrawEditor(
        canvasController: _canvasController,
        viewController: _viewController,
        config: EditorConfig(
          contentCallbacks: EditorContentCallbacks(
            onAddStickyNote: _addStickyNote,
            onAddCounter: _addCounter,
            onAddMindmap: _addMindmap,
            onInsertImage: _insertImageFile,
            // 闭环接入点：菜单里的 保存/加载 会通过此 store 完成往返。
            documentStore: _store,
            metadata: const DocumentMetadata(
              title: 'Flow Sketch demo',
              appId: 'wenz_draw.example',
            ),
          ),
          toolbarActions: const [
            EditorToolbarAction(
              label: '清空',
              icon: Icons.delete_sweep_outlined,
              onPressed: _clearCanvas,
            ),
          ],
        ),
      ),
      // Floating entry to the minimal kernel-only demo.
      floatingActionButton: widget.onShowMinimal == null
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.onShowMinimal,
              icon: const Icon(Icons.code),
              label: const Text('Minimal kernel'),
            ),
    );
  }

  /// Clears the canvas and the in-memory store. Demonstrates the "new
  /// document" leg of the create→edit→save→reopen loop.
  static void _clearCanvas(
    CanvasController canvas,
    InfiniteCanvasController view,
  ) {
    canvas.clear();
    view.resetView();
  }

  void _addExampleDiagram() {
    _canvasController
      ..addElement(
        const RectElement(
          id: 'demo-start',
          rect: Rect.fromLTWH(0, 60, 180, 92),
          borderRadius: 7,
          fillStyle: PaintStyle(color: Color(0xFFFFFFFF)),
          strokeStyle: PaintStyle(color: Color(0xFF2476C7), strokeWidth: 2),
          label: 'Start',
          labelStyle: TextStyle(
            color: Color(0xFF263442),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          labelAlign: TextAlign.center,
          zIndex: 1,
        ),
        record: false,
      )
      ..addElement(
        const RectElement(
          id: 'demo-decision',
          rect: Rect.fromLTWH(310, 68, 130, 130),
          borderRadius: 4,
          fillStyle: PaintStyle(color: Color(0xFFFFFFFF)),
          strokeStyle: PaintStyle(color: Color(0xFF2476C7), strokeWidth: 2),
          label: 'Decision',
          labelStyle: TextStyle(
            color: Color(0xFF263442),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          labelAlign: TextAlign.center,
          zIndex: 2,
        ),
        record: false,
      )
      ..addElement(
        const EllipseElement(
          id: 'demo-finish',
          rect: Rect.fromLTWH(540, 226, 164, 90),
          fillStyle: PaintStyle(color: Color(0xFFFFFFFF)),
          strokeStyle: PaintStyle(color: Color(0xFF2476C7), strokeWidth: 2),
          label: 'Done',
          labelStyle: TextStyle(
            color: Color(0xFF263442),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          labelAlign: TextAlign.center,
          zIndex: 3,
        ),
        record: false,
      )
      ..addElement(
        const PolylineElement(
          id: 'demo-connector',
          points: [
            Offset(180, 106),
            Offset(242, 106),
            Offset(242, 133),
            Offset(310, 133),
          ],
          style: PaintStyle(color: Color(0xFF2476C7), strokeWidth: 3),
          zIndex: 0,
        ),
        record: false,
      )
      ..addElement(
        const PolylineElement(
          id: 'demo-connector-2',
          points: [
            Offset(440, 140),
            Offset(488, 140),
            Offset(488, 271),
            Offset(540, 271),
          ],
          style: PaintStyle(color: Color(0xFF2476C7), strokeWidth: 3),
          zIndex: 0,
        ),
        record: false,
      )
      ..addElement(
        const CanvasWidgetElement(
          id: 'demo-note',
          worldRect: Rect.fromLTWH(75, 278, 200, 116),
          widgetType: 'sticky_note',
          widgetData: {'text': '拖动画布可平移，滚轮可缩放。', 'color': '0xFFFFF6D6'},
          zIndex: 4,
        ),
        record: false,
      )
      ..addElement(
        TextElement(
          id: 'demo-title',
          position: const Offset(520, -25),
          text: 'Flow Sketch',
          style: const TextStyle(
            color: Color(0xFF263442),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          zIndex: 5,
        ),
        record: false,
      );
  }

  void _addStickyNote() {
    final center = _viewController.visibleWorldRect().center;
    _canvasController.addElement(
      CanvasWidgetElement(
        id: 'sticky-${DateTime.now().millisecondsSinceEpoch}',
        worldRect: Rect.fromCenter(center: center, width: 200, height: 140),
        widgetType: 'sticky_note',
        widgetData: const {'text': 'New note', 'color': '0xFFFFEB3B'},
        zIndex: _canvasController.elements.length + 1,
      ),
    );
  }

  void _addCounter() {
    final center = _viewController.visibleWorldRect().center;
    _canvasController.addElement(
      CanvasWidgetElement(
        id: 'counter-${DateTime.now().millisecondsSinceEpoch}',
        worldRect: Rect.fromCenter(center: center, width: 140, height: 100),
        widgetType: 'counter_button',
        widgetData: const {
          'count': 0,
          'label': 'Clicks',
          'color': '0xFF2563EB',
        },
        zIndex: _canvasController.elements.length + 1,
      ),
    );
  }

  void _addMindmap() {
    final center = _viewController.visibleWorldRect().center;
    final nodes = createMindmapNodeElements(center: center);
    final zIndex = _canvasController.elements.length + 1;
    for (final node in nodes) {
      _canvasController.addElement(node.copyWith(zIndex: zIndex));
    }
    // Trigger an explicit initial layout on the new root.
    final rootId = nodes.first.id;
    MindmapActions.of(_canvasController)?.relayout(rootId);
  }

  Future<void> _insertImageFile() async {
    try {
      final imported = await pickCanvasImageFile();
      if (!mounted || imported == null) {
        return;
      }
      final rect = initialImageRectForViewport(
        imported.sourceSize,
        _viewController.visibleWorldRect(),
      );
      final element = ImageElement(
        id: 'image-${DateTime.now().microsecondsSinceEpoch}',
        rect: rect,
        image: imported.image,
        imageData: imported.imageData,
        fit: BoxFit.contain,
        layerId: _canvasController.activeLayerId,
        zIndex: _canvasController.nextZIndex(_canvasController.activeLayerId),
      );
      _canvasController
        ..addElement(element, bringToFront: true)
        ..setSelection({element.id})
        ..setTool(SelectTool.idValue);
      final optimized = imported.wasDownsampled
          ? ' · optimized ${imported.sourceSize.width.round()}x${imported.sourceSize.height.round()} to ${imported.decodedSize.width.round()}x${imported.decodedSize.height.round()}'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inserted ${imported.name}$optimized')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to insert image: $error')));
    }
  }
}

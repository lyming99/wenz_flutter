import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import '../theme/ui_colors.dart';
import '../components/toolbar/toolbar.dart';
import '../components/left_panel/left_shape_panel.dart';
import '../components/canvas_stage/canvas_stage.dart';
import '../components/right_panel/right_inspector_panel.dart';
import '../mindmap/mindmap_actions.dart';
import '../mindmap/mindmap_sync_controller.dart';

class CanvasDemoPage extends StatefulWidget {
  const CanvasDemoPage({super.key});

  @override
  State<CanvasDemoPage> createState() => _CanvasDemoPageState();
}

class _CanvasDemoPageState extends State<CanvasDemoPage> {
  late final CanvasController _canvasController;
  late final InfiniteCanvasController _viewController;
  late final MindmapSyncController _mindmapSync;

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
      backgroundColor: UiColors.appBackground,
      body: Column(
        children: [
          Toolbar(
            canvasController: _canvasController,
            viewController: _viewController,
            onAddStickyNote: _addStickyNote,
            onAddCounter: _addCounter,
            onAddMindmap: _addMindmap,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LeftShapePanel(
                  canvasController: _canvasController,
                  onAddStickyNote: _addStickyNote,
                ),
                Expanded(
                  child: CanvasStage(
                    canvasController: _canvasController,
                    viewController: _viewController,
                  ),
                ),
                RightInspectorPanel(canvasController: _canvasController),
              ],
            ),
          ),
        ],
      ),
    );
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
}

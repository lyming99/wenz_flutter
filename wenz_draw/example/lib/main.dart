import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

class _DrawioShapePaletteEntry {
  const _DrawioShapePaletteEntry({
    required this.label,
    required this.shapeKey,
    required this.group,
  });

  final String label;
  final String shapeKey;
  final String group;

  String get toolId => ShapeTool.idFor(shapeKey);
}

final _flowchartShapePalette = [
  for (final key in FlowchartStencils.keys)
    _DrawioShapePaletteEntry(
      label: FlowchartStencils.labels[key] ?? key,
      shapeKey: key,
      group: 'flowchart',
    ),
];

final _basicSymbolShapePalette = [
  for (final key in BasicStencils.keys)
    _DrawioShapePaletteEntry(
      label: BasicStencils.labels[key] ?? key,
      shapeKey: key,
      group: 'basicSymbols',
    ),
];

final _arrowShapePalette = [
  for (final key in ArrowStencils.keys)
    _DrawioShapePaletteEntry(
      label: ArrowStencils.labels[key] ?? key,
      shapeKey: key,
      group: 'arrows',
    ),
];

const _drawioShapePalette = [
  _DrawioShapePaletteEntry(label: '菱形', shapeKey: 'rhombus', group: 'basic'),
  _DrawioShapePaletteEntry(label: '三角形', shapeKey: 'triangle', group: 'basic'),
  _DrawioShapePaletteEntry(label: '六边形', shapeKey: 'hexagon', group: 'basic'),
  _DrawioShapePaletteEntry(label: '加号', shapeKey: 'plus', group: 'basic'),
  _DrawioShapePaletteEntry(label: '交叉', shapeKey: 'cross', group: 'basic'),
  _DrawioShapePaletteEntry(
    label: '流程',
    shapeKey: 'parallelogram',
    group: 'flowchart',
  ),
  _DrawioShapePaletteEntry(
    label: '梯形',
    shapeKey: 'trapezoid',
    group: 'flowchart',
  ),
  _DrawioShapePaletteEntry(
    label: '文档',
    shapeKey: 'document',
    group: 'flowchart',
  ),
  _DrawioShapePaletteEntry(label: '步骤', shapeKey: 'step', group: 'flowchart'),
  _DrawioShapePaletteEntry(
    label: '圆柱',
    shapeKey: 'cylinder',
    group: 'flowchart',
  ),
  _DrawioShapePaletteEntry(
    label: '泳道',
    shapeKey: 'swimlane',
    group: 'container',
  ),
  _DrawioShapePaletteEntry(label: '便签形', shapeKey: 'note', group: 'container'),
  _DrawioShapePaletteEntry(
    label: '标注',
    shapeKey: 'callout',
    group: 'container',
  ),
  _DrawioShapePaletteEntry(
    label: '双椭圆',
    shapeKey: 'doubleEllipse',
    group: 'container',
  ),
  _DrawioShapePaletteEntry(
    label: 'Actor',
    shapeKey: 'actor',
    group: 'container',
  ),
  _DrawioShapePaletteEntry(label: '云', shapeKey: 'cloud', group: 'container'),
  _DrawioShapePaletteEntry(label: '立方体', shapeKey: 'cube', group: 'container'),
];

void main() {
  WidgetElementRegistry.register('sticky_note', const StickyNoteBuilder());
  WidgetElementRegistry.register(
    'counter_button',
    const CounterButtonBuilder(),
  );
  runApp(const WenzDrawExampleApp());
}

class StickyNoteBuilder extends WidgetElementBuilder {
  const StickyNoteBuilder();

  @override
  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    final text = element.widgetData['text'] as String? ?? 'Double tap to edit';
    final colorValue =
        int.tryParse(element.widgetData['color'] as String? ?? '0xFFFFEB3B') ??
        0xFFFFEB3B;

    if (canvas.renderDetail != CanvasWidgetRenderDetail.full) {
      return _buildPreview(text, Color(colorValue), canvas.renderDetail);
    }

    return GestureDetector(
      onDoubleTap: () => _showEditDialog(context, element, canvas),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(colorValue),
          borderRadius: BorderRadius.circular(4),
          border: canvas.selected
              ? Border.all(color: const Color(0xFF2563EB), width: 1.5)
              : null,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 4,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1F2937),
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(
    String text,
    Color color,
    CanvasWidgetRenderDetail detail,
  ) {
    return switch (detail) {
      CanvasWidgetRenderDetail.color => ColoredBox(color: color),
      CanvasWidgetRenderDetail.colorWithText => ColoredBox(
        color: color,
        child: Center(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ),
      CanvasWidgetRenderDetail.thumbnail => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: const Color(0x33000000)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
              style: const TextStyle(
                fontSize: 11,
                height: 1.2,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ),
      ),
      CanvasWidgetRenderDetail.full => ColoredBox(color: color),
    };
  }

  void _showEditDialog(
    BuildContext context,
    CanvasWidgetElement element,
    CanvasWidgetBuildContext canvas,
  ) {
    final controller = TextEditingController(
      text: element.widgetData['text'] as String? ?? '',
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit note'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Note text',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              canvas.updateProps(element.id, {
                ...element.widgetData,
                'text': controller.text,
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class CounterButtonBuilder extends WidgetElementBuilder {
  const CounterButtonBuilder();

  @override
  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    final count = element.widgetData['count'] as int? ?? 0;
    final label = element.widgetData['label'] as String? ?? 'Clicks';
    final colorValue =
        int.tryParse(element.widgetData['color'] as String? ?? '0xFF2563EB') ??
        0xFF2563EB;

    if (canvas.renderDetail != CanvasWidgetRenderDetail.full) {
      return _buildPreview(
        count: count,
        label: label,
        color: Color(colorValue),
        detail: canvas.renderDetail,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Color(colorValue),
        borderRadius: BorderRadius.circular(8),
        border: canvas.selected
            ? Border.all(color: Colors.white, width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            canvas.updateProps(element.id, {
              ...element.widgetData,
              'count': count + 1,
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFBFDBFE),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview({
    required int count,
    required String label,
    required Color color,
    required CanvasWidgetRenderDetail detail,
  }) {
    return switch (detail) {
      CanvasWidgetRenderDetail.color => ColoredBox(color: color),
      CanvasWidgetRenderDetail.colorWithText => ColoredBox(
        color: color,
        child: Center(
          child: Text(
            '$count',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
      CanvasWidgetRenderDetail.thumbnail => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: const Color(0x33000000)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontSize: 9, color: Color(0xFFBFDBFE)),
            ),
          ],
        ),
      ),
      CanvasWidgetRenderDetail.full => ColoredBox(color: color),
    };
  }
}

class WenzDrawExampleApp extends StatelessWidget {
  const WenzDrawExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'wenz_draw',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const CanvasDemoPage(),
    );
  }
}

class CanvasDemoPage extends StatefulWidget {
  const CanvasDemoPage({super.key});

  @override
  State<CanvasDemoPage> createState() => _CanvasDemoPageState();
}

class _CanvasDemoPageState extends State<CanvasDemoPage> {
  late final CanvasController _canvasController;
  late final InfiniteCanvasController _viewController;

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
    _addExampleDiagram();
  }

  @override
  void dispose() {
    _viewController.dispose();
    _canvasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _UiColors.appBackground,
      body: Column(
        children: [
          _Toolbar(
            canvasController: _canvasController,
            viewController: _viewController,
            onAddStickyNote: _addStickyNote,
            onAddCounter: _addCounter,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LeftShapePanel(
                  canvasController: _canvasController,
                  onAddStickyNote: _addStickyNote,
                ),
                Expanded(
                  child: _CanvasStage(
                    canvasController: _canvasController,
                    viewController: _viewController,
                  ),
                ),
                _RightInspectorPanel(canvasController: _canvasController),
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
}

class _UiColors {
  const _UiColors._();

  static const appBackground = Color(0xFFF3F6F8);
  static const canvasBackground = Color(0xFFEEF3F7);
  static const panel = Color(0xFFFFFFFF);
  static const panelSoft = Color(0xFFF7F9FB);
  static const line = Color(0xFFD9E1E8);
  static const text = Color(0xFF18232E);
  static const muted = Color(0xFF61707F);
  static const accent = Color(0xFF2476C7);
  static const accentSoft = Color(0xFFE6F1FB);
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.canvasController,
    required this.viewController,
    required this.onAddStickyNote,
    required this.onAddCounter,
  });

  final CanvasController canvasController;
  final InfiniteCanvasController viewController;
  final VoidCallback onAddStickyNote;
  final VoidCallback onAddCounter;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([canvasController, viewController]),
      builder: (context, _) {
        final activeTool = canvasController.currentTool?.id;

        return Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: _UiColors.panel,
            border: Border(bottom: BorderSide(color: _UiColors.line)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(MediaQuery.sizeOf(context).width - 24, 760),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ToolButton(
                    label: '菜单',
                    icon: Icons.menu,
                    selected: false,
                    onPressed: () => _showFileMenu(context),
                  ),
                  const _ToolbarDivider(),
                  _ToolButton(
                    label: '选择',
                    icon: Icons.near_me_outlined,
                    selected: activeTool == SelectTool.idValue,
                    onPressed: () =>
                        canvasController.setTool(SelectTool.idValue),
                  ),
                  _ToolButton(
                    label: '拖拽',
                    icon: Icons.open_with,
                    selected: activeTool == PanTool.idValue,
                    onPressed: () => canvasController.setTool(PanTool.idValue),
                  ),
                  const _ToolbarDivider(),
                  _ToolButton(
                    label: '画笔',
                    icon: Icons.edit_outlined,
                    selected: activeTool == PenTool.idValue,
                    onPressed: () => canvasController.setTool(PenTool.idValue),
                  ),
                  _ToolButton(
                    label: '荧光笔',
                    icon: Icons.border_color_outlined,
                    selected: activeTool == HighlighterTool.idValue,
                    onPressed: () =>
                        canvasController.setTool(HighlighterTool.idValue),
                  ),
                  _ToolButton(
                    label: '直线',
                    iconWidget: const _LineToolIcon(polyline: false),
                    selected: activeTool == LineTool.idValue,
                    onPressed: () => canvasController.setTool(LineTool.idValue),
                  ),
                  _ToolButton(
                    label: '折线',
                    iconWidget: const _LineToolIcon(polyline: true),
                    selected: activeTool == PolylineTool.idValue,
                    onPressed: () =>
                        canvasController.setTool(PolylineTool.idValue),
                  ),
                  _ToolButton(
                    label: '曲线',
                    icon: Icons.timeline,
                    selected: activeTool == CurveTool.idValue,
                    onPressed: () =>
                        canvasController.setTool(CurveTool.idValue),
                  ),
                  const _ToolbarDivider(),
                  _ToolButton(
                    label: '图形',
                    icon: Icons.category_outlined,
                    selected:
                        activeTool == RectTool.idValue ||
                        activeTool == EllipseTool.idValue ||
                        (activeTool?.startsWith(ShapeTool.idPrefix) ?? false),
                    onPressed: () => canvasController.setTool(RectTool.idValue),
                  ),
                  _ToolButton(
                    label: '文字',
                    icon: Icons.text_fields,
                    selected: activeTool == TextTool.idValue,
                    onPressed: () => canvasController.setTool(TextTool.idValue),
                  ),
                  _ToolButton(
                    label: '橡皮擦',
                    icon: Icons.cleaning_services_outlined,
                    selected: activeTool == EraserTool.idValue,
                    onPressed: () =>
                        canvasController.setTool(EraserTool.idValue),
                  ),
                  _ToolButton(
                    label: '颜色选择器',
                    selected: false,
                    iconWidget: const _SpectrumIcon(size: 18),
                    onPressed: () => _showColorMenu(context, canvasController),
                  ),
                  const _ToolbarDivider(),
                  _ToolButton(
                    label: '特殊组件创建',
                    icon: Icons.add,
                    selected: false,
                    onPressed: () => _showComponentMenu(context),
                  ),
                  _ToolButton(
                    label: '图层',
                    icon: Icons.layers_outlined,
                    selected: false,
                    onPressed: () => canvasController.addLayer(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFileMenu(BuildContext context) {
    _showAnchoredMenu<String>(
      context: context,
      items: const [
        PopupMenuItem(value: 'import-json', child: Text('导入 JSON')),
        PopupMenuItem(value: 'import-drawio', child: Text('导入 draw.io')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'export-json', child: Text('导出 JSON')),
        PopupMenuItem(value: 'export-svg', child: Text('导出 SVG')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'save', child: Text('保存')),
      ],
    ).then((value) {
      switch (value) {
        case 'import-json':
          _showImportDialog(context, canvasController, importDrawio: false);
        case 'import-drawio':
          _showImportDialog(context, canvasController, importDrawio: true);
        case 'export-json':
          _showExportDialog(
            context,
            'JSON',
            _prettyJson(CanvasSerializer.toJson(canvasController)),
          );
        case 'export-svg':
          _showExportDialog(
            context,
            'SVG',
            SvgExporter.exportElements(elements: canvasController.elements),
          );
        case 'save':
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('当前画布已保存到内存快照')));
      }
    });
  }

  void _showComponentMenu(BuildContext context) {
    _showAnchoredMenu<String>(
      context: context,
      items: const [
        PopupMenuItem(value: 'note', child: Text('便签')),
        PopupMenuItem(value: 'counter', child: Text('计数器')),
      ],
    ).then((value) {
      if (value == 'counter') {
        onAddCounter();
      } else if (value == 'note') {
        onAddStickyNote();
      }
    });
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: _UiColors.line,
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.iconWidget,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? _UiColors.accent : _UiColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? _UiColors.accentSoft : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: selected ? const Color(0xFFC7DDF2) : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onPressed,
            child: SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(size: 16, color: foreground),
                  child: iconWidget ?? Icon(icon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LineToolIcon extends StatelessWidget {
  const _LineToolIcon({required this.polyline});

  final bool polyline;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 18),
      painter: _LineToolPainter(polyline),
    );
  }
}

class _LineToolPainter extends CustomPainter {
  const _LineToolPainter(this.polyline);

  final bool polyline;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5F6E7D)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final points = polyline
        ? [
            Offset(size.width * 0.12, size.height * 0.78),
            Offset(size.width * 0.44, size.height * 0.28),
            Offset(size.width * 0.88, size.height * 0.62),
          ]
        : [
            Offset(size.width * 0.14, size.height * 0.78),
            Offset(size.width * 0.86, size.height * 0.22),
          ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
    for (final point in points) {
      canvas.drawCircle(point, 2, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }
  }

  @override
  bool shouldRepaint(covariant _LineToolPainter oldDelegate) {
    return oldDelegate.polyline != polyline;
  }
}

class _LeftShapePanel extends StatelessWidget {
  const _LeftShapePanel({
    required this.canvasController,
    required this.onAddStickyNote,
  });

  final CanvasController canvasController;
  final VoidCallback onAddStickyNote;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: canvasController,
      builder: (context, _) {
        final activeTool = canvasController.currentTool?.id;
        return Container(
          width: 244,
          color: _UiColors.panel,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: _UiColors.line)),
            ),
            child: SingleChildScrollView(
              child: _PanelSection(
                title: '图形',
                actionLabel: '管理',
                children: [
                  const _SearchBox(),
                  _ShapePaletteGroup(
                    title: 'Basic',
                    entries: _drawioShapePalette
                        .where((entry) => entry.group == 'basic')
                        .toList(growable: false),
                    activeTool: activeTool,
                    onSelect: canvasController.setTool,
                  ),
                  _ShapePaletteGroup(
                    title: 'Basic Symbols',
                    entries: _basicSymbolShapePalette,
                    activeTool: activeTool,
                    onSelect: canvasController.setTool,
                  ),
                  _ShapePaletteGroup(
                    title: 'Flowchart',
                    entries: _flowchartShapePalette,
                    activeTool: activeTool,
                    onSelect: canvasController.setTool,
                  ),
                  _ShapePaletteGroup(
                    title: 'Arrows',
                    entries: _arrowShapePalette,
                    activeTool: activeTool,
                    onSelect: canvasController.setTool,
                  ),
                  _ShapePaletteGroup(
                    title: 'Container',
                    entries: _drawioShapePalette
                        .where((entry) => entry.group == 'container')
                        .toList(growable: false),
                    activeTool: activeTool,
                    onSelect: canvasController.setTool,
                  ),
                  const SizedBox(height: 6),
                  const _PaletteSubhead('Legacy'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.35,
                    children: [
                      _ShapeTile(
                        label: '矩形',
                        icon: Icons.crop_square,
                        selected: activeTool == RectTool.idValue,
                        onPressed: () =>
                            canvasController.setTool(RectTool.idValue),
                      ),
                      _ShapeTile(
                        label: '圆形',
                        icon: Icons.circle_outlined,
                        selected: activeTool == EllipseTool.idValue,
                        onPressed: () =>
                            canvasController.setTool(EllipseTool.idValue),
                      ),
                      _ShapeTile(
                        label: '菱形',
                        iconWidget: Transform.rotate(
                          angle: math.pi / 4,
                          child: const Icon(Icons.crop_square, size: 32),
                        ),
                        selected: activeTool == ShapeTool.idFor('rhombus'),
                        onPressed: () => canvasController.setTool(
                          ShapeTool.idFor('rhombus'),
                        ),
                      ),
                      _ShapeTile(
                        label: '箭头',
                        icon: Icons.arrow_forward,
                        selected: activeTool == ArrowTool.idValue,
                        onPressed: () =>
                            canvasController.setTool(ArrowTool.idValue),
                      ),
                      _ShapeTile(
                        label: '便签',
                        icon: Icons.sticky_note_2_outlined,
                        selected: false,
                        onPressed: onAddStickyNote,
                      ),
                      _ShapeTile(
                        label: '文本',
                        icon: Icons.text_fields,
                        selected: activeTool == TextTool.idValue,
                        onPressed: () =>
                            canvasController.setTool(TextTool.idValue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShapePaletteGroup extends StatelessWidget {
  const _ShapePaletteGroup({
    required this.title,
    required this.entries,
    required this.activeTool,
    required this.onSelect,
  });

  final String title;
  final List<_DrawioShapePaletteEntry> entries;
  final String? activeTool;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PaletteSubhead(title),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.35,
          children: [
            for (final entry in entries)
              _ShapeTile(
                label: entry.label,
                iconWidget: _ShapePreviewIcon(shapeKey: entry.shapeKey),
                selected: activeTool == entry.toolId,
                onPressed: () => onSelect(entry.toolId),
              ),
          ],
        ),
      ],
    );
  }
}

class _PaletteSubhead extends StatelessWidget {
  const _PaletteSubhead(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 7),
      child: Text(
        title,
        style: const TextStyle(
          color: _UiColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _CanvasStage extends StatelessWidget {
  const _CanvasStage({
    required this.canvasController,
    required this.viewController,
  });

  final CanvasController canvasController;
  final InfiniteCanvasController viewController;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _UiColors.canvasBackground,
      child: Stack(
        children: [
          InfiniteCanvasWidget(
            controller: viewController,
            config: const InfiniteCanvasConfig(
              gridType: GridType.lines,
              backgroundColor: _UiColors.canvasBackground,
              gridColor: Color(0x1F5F748B),
              majorGridColor: Color(0x2B5F748B),
              gridBaseSize: 20,
            ),
          ),
          Positioned(
            left: 18,
            top: 14,
            child: AnimatedBuilder(
              animation: Listenable.merge([canvasController, viewController]),
              builder: (context, _) {
                return _FloatingPill(
                  child: Text(
                    '${canvasController.currentTool?.name ?? 'Select'}  '
                    '${canvasController.selectedIds.length} 个对象  '
                    '${canvasController.elements.length} 个元素',
                    style: const TextStyle(
                      color: Color(0xFF405164),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 18,
            bottom: 18,
            child: _ZoomPill(viewController: viewController),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _UiColors.panel.withValues(alpha: 0.9),
                border: Border.all(color: _UiColors.line),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1418232E),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MinimapWidget(controller: viewController),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RightInspectorPanel extends StatelessWidget {
  const _RightInspectorPanel({required this.canvasController});

  final CanvasController canvasController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: canvasController,
      builder: (context, _) {
        final selected = canvasController.selectedElements.firstOrNull;
        final bounds = selected?.bounds;
        final brush = canvasController.brushSettings;
        final selectedFill = _fillColorOf(selected) ?? brush.fillColor;
        final selectedStroke = _strokeColorOf(selected) ?? brush.color;
        final selectedStrokeWidth =
            _strokeWidthOf(selected) ?? brush.strokeWidth;
        return Container(
          width: 292,
          color: _UiColors.panel,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: _UiColors.line)),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _PanelSection(
                    title: '图层',
                    actionLabel: '新建',
                    onAction: () => canvasController.addLayer(),
                    children: [
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: canvasController.layers.length,
                        onReorder: (oldIndex, newIndex) {
                          final adjusted = newIndex > oldIndex
                              ? newIndex - 1
                              : newIndex;
                          canvasController.reorderLayer(oldIndex, adjusted);
                        },
                        itemBuilder: (context, index) {
                          final layer = canvasController.layers[index];
                          return _LayerRow(
                            key: ValueKey(layer.id),
                            layer: layer,
                            index: index,
                            active: layer.id == canvasController.activeLayerId,
                            canDelete: canvasController.layers.length > 1,
                            onSelect: () =>
                                canvasController.setActiveLayer(layer.id),
                            onToggleVisible: () => canvasController
                                .toggleLayerVisibility(layer.id),
                            onDelete: () =>
                                canvasController.removeLayer(layer.id),
                          );
                        },
                      ),
                    ],
                  ),
                  _PanelSection(
                    title: '位置与尺寸',
                    children: [
                      _FieldGrid(
                        children: [
                          _ReadoutField(label: 'X', value: bounds?.left),
                          _ReadoutField(label: 'Y', value: bounds?.top),
                          _ReadoutField(label: '宽', value: bounds?.width),
                          _ReadoutField(label: '高', value: bounds?.height),
                        ],
                      ),
                    ],
                  ),
                  _PanelSection(
                    title: '填充与描边',
                    children: [
                      _FieldGrid(
                        children: [
                          _ColorButtonField(
                            label: '填充',
                            color: selectedFill,
                            enabled: _canEditPaint(selected),
                            onPressed: selected == null
                                ? null
                                : () => _showShapeColorPicker(
                                    context,
                                    selected,
                                    canvasController,
                                    fill: true,
                                  ),
                          ),
                          _ColorButtonField(
                            label: '描边',
                            color: selectedStroke,
                            enabled: _canEditPaint(selected),
                            onPressed: selected == null
                                ? null
                                : () => _showShapeColorPicker(
                                    context,
                                    selected,
                                    canvasController,
                                    fill: false,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SliderField(
                        label: '描边宽度',
                        value: selectedStrokeWidth,
                        min: 1,
                        max: 20,
                        onChanged: _canEditPaint(selected)
                            ? (value) => canvasController.updateShapePaint(
                                selected!.id,
                                strokeWidth: value,
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      const _FieldLabel('常用颜色'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final color in _swatches)
                            _ColorSwatch(
                              color: color,
                              selected: selectedStroke == color,
                              onPressed: _canEditPaint(selected)
                                  ? () => canvasController.updateShapePaint(
                                      selected!.id,
                                      strokeColor: color,
                                    )
                                  : () {
                                      canvasController.updateBrushSettings(
                                        canvasController.brushSettings.copyWith(
                                          color: color,
                                        ),
                                      );
                                    },
                            ),
                        ],
                      ),
                    ],
                  ),
                  _PanelSection(
                    title: '文本',
                    children: [
                      _TextReadout(
                        selected: selected,
                        onChanged: (text) {
                          if (selected != null) {
                            canvasController.updateTextContent(
                              selected.id,
                              text,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _FieldGrid(
                        children: [
                          _ReadoutField(
                            label: '字号',
                            value: _fontSizeOf(selected),
                          ),
                          const _StaticField(label: '字重', value: '半粗'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const _FieldLabel('对齐'),
                      const SizedBox(height: 6),
                      const _SegmentedControl(),
                    ],
                  ),
                  _PanelSection(
                    title: '旋转',
                    children: [
                      _SliderField(
                        label: '角度',
                        value: _rotationDegreesOf(selected),
                        min: -180,
                        max: 180,
                        onChanged: selected is DrawioShapeElement
                            ? (value) {
                                canvasController.updateElementRotation(
                                  selected.id,
                                  value * math.pi / 180,
                                );
                              }
                            : null,
                      ),
                    ],
                  ),
                  _PanelSection(
                    title: '外观',
                    children: [
                      _SliderField(
                        label: '圆角',
                        value: _radiusOf(selected),
                        min: 0,
                        max: 24,
                      ),
                      const SizedBox(height: 12),
                      _SliderField(
                        label: '透明度',
                        value: _opacityOf(selected) ?? brush.opacity,
                        min: 0,
                        max: 1,
                        fractionDigits: 2,
                        onChanged: (value) {
                          if (_canEditPaint(selected)) {
                            canvasController.updateShapePaint(
                              selected!.id,
                              fillColor: _fillColorOf(selected),
                              strokeColor: _strokeColorOf(selected),
                              strokeWidth: _strokeWidthOf(selected),
                              opacity: value,
                            );
                          } else {
                            canvasController.updateBrushSettings(
                              brush.copyWith(opacity: value),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static bool _canEditPaint(CanvasElement? element) {
    return element is DrawioShapeElement ||
        element is RectElement ||
        element is EllipseElement;
  }

  static Color? _fillColorOf(CanvasElement? element) {
    return switch (element) {
      DrawioShapeElement e => e.fillStyle?.color,
      RectElement e => e.fillStyle?.color,
      EllipseElement e => e.fillStyle?.color,
      _ => null,
    };
  }

  static Color? _strokeColorOf(CanvasElement? element) {
    return switch (element) {
      DrawioShapeElement e => e.strokeStyle.color,
      RectElement e => e.strokeStyle.color,
      EllipseElement e => e.strokeStyle.color,
      _ => null,
    };
  }

  static double? _strokeWidthOf(CanvasElement? element) {
    return switch (element) {
      DrawioShapeElement e => e.strokeStyle.strokeWidth,
      RectElement e => e.strokeStyle.strokeWidth,
      EllipseElement e => e.strokeStyle.strokeWidth,
      _ => null,
    };
  }

  static const _swatches = [
    Color(0xFFFFFFFF),
    Color(0xFFE6F1FB),
    Color(0xFFDFF4EE),
    Color(0xFFFFF6D6),
    Color(0xFFF7E6EE),
    Color(0xFF263442),
  ];

  static double? _opacityOf(CanvasElement? element) {
    return switch (element) {
      DrawioShapeElement e => e.strokeStyle.opacity,
      RectElement e => e.strokeStyle.opacity,
      EllipseElement e => e.strokeStyle.opacity,
      _ => null,
    };
  }

  static double _rotationDegreesOf(CanvasElement? element) {
    if (element is DrawioShapeElement) {
      final degrees = element.rotation * 180 / math.pi;
      return ((degrees + 180) % 360) - 180;
    }
    return 0;
  }

  static double _radiusOf(CanvasElement? element) {
    return element is RectElement ? element.borderRadius : 7;
  }

  static double? _fontSizeOf(CanvasElement? element) {
    if (element is TextElement) {
      return element.style.fontSize;
    }
    if (element is RectElement) {
      return element.labelStyle.fontSize;
    }
    if (element is EllipseElement) {
      return element.labelStyle.fontSize;
    }
    return 14;
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({
    required this.title,
    required this.children,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _UiColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF465667),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    foregroundColor: _UiColors.accent,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextField(
        style: const TextStyle(fontSize: 14, color: _UiColors.text),
        decoration: InputDecoration(
          hintText: '搜索图形',
          hintStyle: const TextStyle(color: Color(0xFF8795A3)),
          prefixIcon: const Icon(
            Icons.search,
            size: 16,
            color: Color(0xFF7D8C99),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          isDense: true,
          filled: true,
          fillColor: _UiColors.panelSoft,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: _UiColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: _UiColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFF9FC4E8)),
          ),
        ),
      ),
    );
  }
}

class _ShapeTile extends StatelessWidget {
  const _ShapeTile({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.iconWidget,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : _UiColors.panelSoft,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? const Color(0xFF9FC4E8) : _UiColors.line,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: const IconThemeData(size: 34, color: Color(0xFF425264)),
              child: iconWidget ?? Icon(icon),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF425264),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShapePreviewIcon extends StatelessWidget {
  const _ShapePreviewIcon({required this.shapeKey});

  final String shapeKey;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(42, 30),
      painter: _ShapePreviewPainter(shapeKey),
    );
  }
}

class _ShapePreviewPainter extends CustomPainter {
  const _ShapePreviewPainter(this.shapeKey);

  final String shapeKey;

  @override
  void paint(Canvas canvas, Size size) {
    ensureDrawioShapeDefinitionsRegistered();
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final element = DrawioShapeElement(
      id: 'preview',
      shapeKey: shapeKey,
      rect: rect,
      strokeStyle: const PaintStyle(color: Color(0xFF425264), strokeWidth: 1.6),
      fillStyle: const PaintStyle(color: Color(0xFFFFFFFF), strokeWidth: 0),
    );
    ElementRendererRegistry.render(canvas, element);
  }

  @override
  bool shouldRepaint(covariant _ShapePreviewPainter oldDelegate) {
    return oldDelegate.shapeKey != shapeKey;
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    super.key,
    required this.layer,
    required this.index,
    required this.active,
    required this.canDelete,
    required this.onSelect,
    required this.onToggleVisible,
    required this.onDelete,
  });

  final CanvasLayer layer;
  final int index;
  final bool active;
  final bool canDelete;
  final VoidCallback onSelect;
  final VoidCallback onToggleVisible;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: active ? _UiColors.accentSoft : _UiColors.panelSoft,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onSelect,
          child: SizedBox(
            height: 38,
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: _UiColors.muted,
                    ),
                  ),
                ),
                Icon(
                  active
                      ? Icons.check_box_outline_blank
                      : Icons.diamond_outlined,
                  size: 14,
                  color: active ? _UiColors.accent : _UiColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    layer.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active
                          ? _UiColors.accent
                          : const Color(0xFF415162),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: layer.isVisible ? '隐藏' : '显示',
                  icon: Icon(
                    layer.isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 15,
                    color: active ? _UiColors.accent : _UiColors.muted,
                  ),
                  onPressed: onToggleVisible,
                ),
                IconButton(
                  tooltip: canDelete ? '删除图层' : '至少保留一个图层',
                  icon: const Icon(Icons.delete_outline, size: 15),
                  color: canDelete ? _UiColors.muted : const Color(0xFFB8C2CC),
                  onPressed: canDelete ? onDelete : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.45,
      children: children,
    );
  }
}

class _ReadoutField extends StatelessWidget {
  const _ReadoutField({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final display = value == null ? '-' : value!.round().toString();
    return _StaticField(label: label, value: display);
  }
}

class _StaticField extends StatelessWidget {
  const _StaticField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _UiColors.panelSoft,
              border: Border.all(color: _UiColors.line),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: _UiColors.text),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorField extends StatelessWidget {
  const _ColorField({required this.label, required this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _UiColors.panelSoft,
              border: Border.all(color: _UiColors.line),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: color ?? Colors.white,
                border: Border.all(color: const Color(0x3318232E)),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorButtonField extends StatelessWidget {
  const _ColorButtonField({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final Color? color;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        Expanded(
          child: Material(
            color: _UiColors.panelSoft,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: _UiColors.line),
              borderRadius: BorderRadius.circular(7),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: enabled ? onPressed : null,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color ?? Colors.transparent,
                    border: Border.all(color: const Color(0x3318232E)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Center(
                    child: color == null
                        ? Icon(
                            Icons.format_color_reset_outlined,
                            size: 16,
                            color: enabled
                                ? _UiColors.muted
                                : const Color(0xFFB8C2CC),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TextReadout extends StatefulWidget {
  const _TextReadout({required this.selected, required this.onChanged});

  final CanvasElement? selected;
  final ValueChanged<String> onChanged;

  @override
  State<_TextReadout> createState() => _TextReadoutState();
}

class _TextReadoutState extends State<_TextReadout> {
  late final TextEditingController _controller;
  String? _editingElementId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _textOf(widget.selected));
    _editingElementId = widget.selected?.id;
  }

  @override
  void didUpdateWidget(covariant _TextReadout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextId = widget.selected?.id;
    final nextText = _textOf(widget.selected);
    if (nextId != _editingElementId || _controller.text != nextText) {
      _editingElementId = nextId;
      _controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('内容'),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          enabled: widget.selected != null,
          minLines: 1,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: _UiColors.text),
          decoration: InputDecoration(
            hintText: widget.selected == null ? '未选择对象' : '输入文字内容',
            isDense: true,
            filled: true,
            fillColor: _UiColors.panelSoft,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: _UiColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: _UiColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Color(0xFF9FC4E8)),
            ),
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }

  static String _textOf(CanvasElement? selected) {
    return switch (selected) {
      TextElement e => e.text,
      DrawioShapeElement e => e.label ?? '',
      RectElement e => e.label ?? '',
      EllipseElement e => e.label ?? '',
      LineElement e => e.label ?? '',
      ArrowElement e => e.label ?? '',
      PolylineElement e => e.label ?? '',
      _ => '',
    };
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _UiColors.panelSoft,
        border: Border.all(color: _UiColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(child: _Segment(label: '左', active: true)),
          Expanded(child: _Segment(label: '中', active: false)),
          Expanded(child: _Segment(label: '右', active: false)),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? _UiColors.accent : _UiColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.fractionDigits = 0,
    this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int fractionDigits;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: _UiColors.accent,
                  thumbColor: _UiColors.accent,
                  inactiveTrackColor: _UiColors.line,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _UiColors.panelSoft,
                border: Border.all(color: _UiColors.line),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                value.toStringAsFixed(fractionDigits),
                style: const TextStyle(fontSize: 12, color: _UiColors.text),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _UiColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Container(
          width: 34,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
              color: selected ? _UiColors.accent : const Color(0x2918232E),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _ZoomPill extends StatelessWidget {
  const _ZoomPill({required this.viewController});

  final InfiniteCanvasController viewController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewController,
      builder: (context, _) {
        return _FloatingPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniButton(
                icon: Icons.remove,
                onPressed: viewController.zoomOut,
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${(viewController.transform.scale * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF425264),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _MiniButton(icon: Icons.add, onPressed: viewController.zoomIn),
            ],
          ),
        );
      },
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 15),
      color: _UiColors.muted,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}

class _FloatingPill extends StatelessWidget {
  const _FloatingPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _UiColors.panel.withValues(alpha: 0.9),
        border: Border.all(color: _UiColors.line),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1418232E),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(8), child: child),
    );
  }
}

class _SpectrumIcon extends StatelessWidget {
  const _SpectrumIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _SpectrumPainter());
  }
}

class _SpectrumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2;
    final sweep = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFF3B30),
          Color(0xFFFFCC00),
          Color(0xFF34C759),
          Color(0xFF00C7BE),
          Color(0xFF007AFF),
          Color(0xFFAF52DE),
          Color(0xFFFF2D55),
          Color(0xFFFF3B30),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, sweep);
    final light = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.92),
          Colors.white.withValues(alpha: 0.18),
          Colors.black.withValues(alpha: 0.2),
        ],
        stops: const [0, 0.48, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius, light);
    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x3318232E),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void _showExportDialog(BuildContext context, String title, String content) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('导出 $title'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: TextEditingController(text: content),
            readOnly: true,
            maxLines: 16,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      );
    },
  );
}

void _showImportDialog(
  BuildContext context,
  CanvasController controller, {
  required bool importDrawio,
}) {
  final textController = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(importDrawio ? '导入 draw.io' : '导入 JSON'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: textController,
            maxLines: 16,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: importDrawio ? '粘贴 draw.io XML' : '粘贴画布 JSON',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              try {
                if (importDrawio) {
                  final elements = DrawioImporter.fromXml(textController.text);
                  controller.replaceElements(elements);
                } else {
                  final json = jsonDecode(textController.text);
                  if (json is! Map<String, dynamic>) {
                    throw const FormatException('JSON 根节点必须是对象');
                  }
                  CanvasSerializer.load(controller, json);
                }
                Navigator.pop(context);
              } catch (error) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
              }
            },
            child: const Text('导入'),
          ),
        ],
      );
    },
  );
}

String _prettyJson(Object value) {
  return const JsonEncoder.withIndent('  ').convert(value);
}

Future<T?> _showAnchoredMenu<T>({
  required BuildContext context,
  required List<PopupMenuEntry<T>> items,
}) {
  final button = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (button == null || overlay == null) {
    return Future<T?>.value();
  }
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );
  return showMenu<T>(context: context, position: position, items: items);
}

Future<void> _showShapeColorPicker(
  BuildContext context,
  CanvasElement selected,
  CanvasController controller, {
  required bool fill,
}) async {
  final initialColor = fill
      ? _RightInspectorPanel._fillColorOf(selected) ?? Colors.white
      : _RightInspectorPanel._strokeColorOf(selected) ?? Colors.black;
  final color = await showDialog<Color>(
    context: context,
    builder: (context) => _ColorPickerDialog(
      initialColor: initialColor,
      swatches: _toolbarColorSwatches,
    ),
  );
  if (color != null) {
    controller.updateShapePaint(
      selected.id,
      fillColor: fill ? color : null,
      strokeColor: fill ? null : color,
    );
  }
}

Future<void> _showColorMenu(
  BuildContext context,
  CanvasController controller,
) async {
  final color = await showDialog<Color>(
    context: context,
    builder: (context) => _ColorPickerDialog(
      initialColor: controller.brushSettings.color,
      swatches: _toolbarColorSwatches,
    ),
  );
  if (color != null) {
    final brush = controller.brushSettings;
    controller.updateBrushSettings(
      brush.copyWith(color: color, fillColor: color.withValues(alpha: 0.12)),
    );
  }
}

const _toolbarColorSwatches = <Color>[
  Color(0xFF111827),
  Color(0xFF6B7280),
  Color(0xFFEF4444),
  Color(0xFFF97316),
  Color(0xFFF59E0B),
  Color(0xFFEAB308),
  Color(0xFF84CC16),
  Color(0xFF22C55E),
  Color(0xFF10B981),
  Color(0xFF14B8A6),
  Color(0xFF06B6D4),
  Color(0xFF0EA5E9),
  Color(0xFF3B82F6),
  Color(0xFF6366F1),
  Color(0xFF8B5CF6),
  Color(0xFFA855F7),
  Color(0xFFD946EF),
  Color(0xFFEC4899),
  Color(0xFFF43F5E),
];

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: selected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
          width: selected ? 2.5 : 1.5,
        ),
      ),
      child: const SizedBox.square(dimension: 22),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.initialColor,
    required this.swatches,
  });

  final Color initialColor;
  final List<Color> swatches;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _hexController = TextEditingController(text: _hexFor(_color));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _color => HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('颜色选择器'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in widget.swatches)
                  InkResponse(
                    radius: 14,
                    onTap: () => _setColor(color),
                    child: _ColorDot(color: color, selected: color == _color),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _RgbSpectrumPicker(
              hue: _hue,
              saturation: _saturation,
              value: _value,
              onChanged: _setSpectrumColor,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ColorDot(color: _color, selected: true),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    decoration: const InputDecoration(
                      labelText: 'HEX',
                      prefixText: '#',
                      isDense: true,
                    ),
                    onChanged: _setHex,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('应用'),
        ),
      ],
    );
  }

  void _setColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    setState(() {
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
      _hexController.text = _hexFor(_color);
    });
  }

  void _setSpectrumColor(double hue, double saturation, double value) {
    setState(() {
      _hue = hue;
      _saturation = saturation;
      _value = value;
      _hexController.text = _hexFor(_color);
    });
  }

  void _setHex(String value) {
    final color = _parseHex(value);
    if (color != null) {
      _setColor(color);
    }
  }

  static String _hexFor(Color color) {
    return (color.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
  }

  static Color? _parseHex(String value) {
    final normalized = value.replaceAll('#', '').trim();
    if (normalized.length != 6 && normalized.length != 8) {
      return null;
    }
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
  }
}

class _RgbSpectrumPicker extends StatelessWidget {
  const _RgbSpectrumPicker({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final void Function(double hue, double saturation, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RGB spectrum', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        GestureDetector(
          onPanDown: (details) => _pickSv(details.localPosition),
          onPanUpdate: (details) => _pickSv(details.localPosition),
          child: SizedBox(
            width: 240,
            height: 150,
            child: CustomPaint(
              painter: _RgbSpectrumPainter(hue: hue),
              foregroundPainter: _SpectrumThumbPainter(
                x: saturation,
                y: 1 - value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onPanDown: (details) => _pickHue(details.localPosition),
          onPanUpdate: (details) => _pickHue(details.localPosition),
          child: SizedBox(
            width: 240,
            height: 18,
            child: CustomPaint(
              painter: const _HueBarPainter(),
              foregroundPainter: _HueThumbPainter(hue: hue),
            ),
          ),
        ),
      ],
    );
  }

  void _pickSv(Offset localPosition) {
    final nextSaturation = (localPosition.dx / 240).clamp(0.0, 1.0).toDouble();
    final nextValue = (1 - localPosition.dy / 150).clamp(0.0, 1.0).toDouble();
    onChanged(hue, nextSaturation, nextValue);
  }

  void _pickHue(Offset localPosition) {
    final nextHue = (localPosition.dx / 240 * 360).clamp(0.0, 360.0).toDouble();
    onChanged(nextHue, saturation, value);
  }
}

class _RgbSpectrumPainter extends CustomPainter {
  const _RgbSpectrumPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF9CA3AF),
    );
  }

  @override
  bool shouldRepaint(covariant _RgbSpectrumPainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

class _SpectrumThumbPainter extends CustomPainter {
  const _SpectrumThumbPainter({required this.x, required this.y});

  final double x;
  final double y;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(x * size.width, y * size.height);
    canvas
      ..drawCircle(
        center,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      )
      ..drawCircle(
        center,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black,
      );
  }

  @override
  bool shouldRepaint(covariant _SpectrumThumbPainter oldDelegate) {
    return oldDelegate.x != x || oldDelegate.y != y;
  }
}

class _HueBarPainter extends CustomPainter {
  const _HueBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Colors.red,
            Colors.yellow,
            Colors.green,
            Colors.cyan,
            Colors.blue,
            Colors.purple,
            Colors.red,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF9CA3AF),
    );
  }

  @override
  bool shouldRepaint(covariant _HueBarPainter oldDelegate) => false;
}

class _HueThumbPainter extends CustomPainter {
  const _HueThumbPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final x = hue / 360 * size.width;
    final rect = Rect.fromCenter(
      center: Offset(x, size.height / 2),
      width: 6,
      height: size.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _HueThumbPainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

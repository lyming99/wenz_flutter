import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

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
    _addLabeledShapes();
    _addDemoWidgets();
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

  void _addLabeledShapes() {
    _canvasController
      ..addElement(
        const RectElement(
          id: 'demo-labeled-rect',
          rect: Rect.fromLTWH(-320, -180, 220, 120),
          borderRadius: 12,
          fillStyle: PaintStyle(color: Color(0xFFE0F2FE)),
          strokeStyle: PaintStyle(color: Color(0xFF0284C7), strokeWidth: 2),
          label: 'Embedded\ntext',
          labelStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
          labelAlign: TextAlign.center,
          labelPadding: EdgeInsets.all(16),
          zIndex: -20010,
        ),
        record: false,
      )
      ..addElement(
        const EllipseElement(
          id: 'demo-labeled-ellipse',
          rect: Rect.fromLTWH(-60, -180, 220, 120),
          fillStyle: PaintStyle(color: Color(0xFFDCFCE7)),
          strokeStyle: PaintStyle(color: Color(0xFF16A34A), strokeWidth: 2),
          label: 'Aligned right',
          labelStyle: TextStyle(
            color: Color(0xFF14532D),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          labelAlign: TextAlign.right,
          labelPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          zIndex: -20009,
        ),
        record: false,
      );
  }

  void _addDemoWidgets() {
    const columns = 40;
    const rows = 25;
    const cellW = 80.0;
    const cellH = 48.0;
    const gap = 4.0;
    final rng = math.Random(42);

    // Build all elements first, then add in one batch for speed.
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        final index = row * columns + col;
        final x = col * (cellW + gap);
        final y = row * (cellH + gap);
        final hue = rng.nextInt(360);
        final color = HSLColor.fromAHSL(
          0.85,
          hue.toDouble(),
          0.45,
          0.80,
        ).toColor().toARGB32();
        final colorHex =
            '0x${color.toRadixString(16).padLeft(8, '0').toUpperCase()}';

        _canvasController.addElement(
          CanvasWidgetElement(
            id: 'perf-$index',
            worldRect: Rect.fromLTWH(x, y, cellW, cellH),
            widgetType: index.isEven ? 'sticky_note' : 'counter_button',
            widgetData: index.isEven
                ? {'text': '$col,$row', 'color': colorHex}
                : {'count': index, 'label': '$col,$row', 'color': colorHex},
            zIndex: -10000 + index,
            scaleMode: index.isEven
                ? CanvasWidgetScaleMode.layoutScale
                : CanvasWidgetScaleMode.paintScale,
          ),
          record: false,
        );
      }
    }
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
                    icon: Icons.show_chart,
                    selected: activeTool == LineTool.idValue,
                    onPressed: () => canvasController.setTool(LineTool.idValue),
                  ),
                  _ToolButton(
                    label: '折线',
                    icon: Icons.account_tree_outlined,
                    selected: activeTool == PolylineTool.idValue,
                    onPressed: () =>
                        canvasController.setTool(PolylineTool.idValue),
                  ),
                  _ToolButton(
                    label: '曲线',
                    icon: Icons.timeline,
                    selected: false,
                    onPressed: () => canvasController.setTool(PenTool.idValue),
                  ),
                  const _ToolbarDivider(),
                  _ToolButton(
                    label: '图形',
                    icon: Icons.crop_square,
                    selected:
                        activeTool == RectTool.idValue ||
                        activeTool == EllipseTool.idValue,
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

  void _showComponentMenu(BuildContext context) {
    final button = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) {
      onAddStickyNote();
      return;
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
    showMenu<String>(
      context: context,
      position: position,
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
                        selected: false,
                        onPressed: () =>
                            canvasController.setTool(RectTool.idValue),
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
                      for (final layer in canvasController.layers)
                        _LayerRow(
                          layer: layer,
                          active: layer.id == canvasController.activeLayerId,
                          onSelect: () =>
                              canvasController.setActiveLayer(layer.id),
                          onToggleVisible: () =>
                              canvasController.toggleLayerVisibility(layer.id),
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
                          _ColorField(label: '填充', color: brush.fillColor),
                          _ColorField(label: '描边', color: brush.color),
                        ],
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
                              selected: brush.color == color,
                              onPressed: () {
                                canvasController.updateBrushSettings(
                                  brush.copyWith(color: color),
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
                      _TextReadout(selected: selected),
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
                        value: brush.opacity,
                        min: 0,
                        max: 1,
                        fractionDigits: 2,
                        onChanged: (value) {
                          canvasController.updateBrushSettings(
                            brush.copyWith(opacity: value),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _SliderField(
                        label: '描边宽度',
                        value: brush.strokeWidth,
                        min: 1,
                        max: 20,
                        onChanged: (value) {
                          canvasController.updateBrushSettings(
                            brush.copyWith(strokeWidth: value),
                          );
                        },
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

  static const _swatches = [
    Color(0xFFFFFFFF),
    Color(0xFFE6F1FB),
    Color(0xFFDFF4EE),
    Color(0xFFFFF6D6),
    Color(0xFFF7E6EE),
    Color(0xFF263442),
  ];

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

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.layer,
    required this.active,
    required this.onSelect,
    required this.onToggleVisible,
  });

  final CanvasLayer layer;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onToggleVisible;

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
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: 8),
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
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: active ? _UiColors.accent : _UiColors.muted,
                  ),
                  onPressed: onToggleVisible,
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

class _TextReadout extends StatelessWidget {
  const _TextReadout({required this.selected});

  final CanvasElement? selected;

  @override
  Widget build(BuildContext context) {
    final text = switch (selected) {
      TextElement e => e.text,
      RectElement e => e.label ?? '',
      EllipseElement e => e.label ?? '',
      _ => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('内容'),
        const SizedBox(height: 6),
        Container(
          height: 36,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _UiColors.panelSoft,
            border: Border.all(color: _UiColors.line),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            text.isEmpty ? '开始节点' : text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: _UiColors.text),
          ),
        ),
      ],
    );
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

void _showColorMenu(BuildContext context, CanvasController controller) {
  const colors = [
    Colors.black,
    Color(0xFF2476C7),
    Color(0xFF12A58B),
    Color(0xFFD2A02B),
    Color(0xFFD44D4D),
    Color(0xFF263442),
  ];
  showDialog<void>(
    context: context,
    builder: (context) {
      final brush = controller.brushSettings;
      return AlertDialog(
        title: const Text('颜色选择器'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in colors)
              _ColorSwatch(
                color: color,
                selected: brush.color == color,
                onPressed: () {
                  controller.updateBrushSettings(brush.copyWith(color: color));
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      );
    },
  );
}

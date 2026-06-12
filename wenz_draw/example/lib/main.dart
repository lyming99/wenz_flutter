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
      body: SafeArea(
        child: Column(
          children: [
            _Toolbar(
              canvasController: _canvasController,
              viewController: _viewController,
              onAddStickyNote: _addStickyNote,
              onAddCounter: _addCounter,
            ),
            Expanded(
              child: Stack(
                children: [
                  InfiniteCanvasWidget(
                    controller: _viewController,
                    config: const InfiniteCanvasConfig(
                      gridType: GridType.dots,
                      backgroundColor: Color(0xFFFBFCFE),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: MinimapWidget(controller: _viewController),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _LayerButton extends StatelessWidget {
  const _LayerButton({required this.controller});

  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Layers',
      icon: const Icon(Icons.layers_outlined),
      onSelected: (value) {
        if (value == '__add__') {
          controller.addLayer();
        } else {
          controller.setActiveLayer(value);
        }
      },
      itemBuilder: (context) {
        return [
          for (final layer in controller.layers)
            PopupMenuItem(
              value: layer.id,
              child: Row(
                children: [
                  Icon(
                    controller.activeLayerId == layer.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(layer.name),
                  const Spacer(),
                  IconButton(
                    tooltip: layer.isVisible ? 'Hide' : 'Show',
                    icon: Icon(
                      layer.isVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      controller.toggleLayerVisibility(layer.id);
                    },
                  ),
                ],
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: '__add__',
            child: Row(
              children: [Icon(Icons.add), SizedBox(width: 8), Text('Layer')],
            ),
          ),
        ];
      },
    );
  }
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

  static const _colors = [
    Colors.black,
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFDC2626),
    Color(0xFF9333EA),
    Color(0xFFF59E0B),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([canvasController, viewController]),
      builder: (context, _) {
        final activeTool = canvasController.currentTool?.id;
        final brush = canvasController.brushSettings;

        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final tool in canvasController.toolManager.tools)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Tooltip(
                      message: tool.name,
                      child: IconButton(
                        isSelected: activeTool == tool.id,
                        icon: Icon(tool.icon),
                        selectedIcon: Icon(tool.icon),
                        onPressed: () => canvasController.setTool(tool.id),
                      ),
                    ),
                  ),
                const VerticalDivider(width: 20),
                for (final color in _colors)
                  _ColorSwatch(
                    color: color,
                    selected: brush.color == color,
                    onPressed: () {
                      canvasController.updateBrushSettings(
                        brush.copyWith(color: color),
                      );
                    },
                  ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  child: Slider(
                    value: brush.strokeWidth,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    onChanged: (value) {
                      canvasController.updateBrushSettings(
                        brush.copyWith(strokeWidth: value),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Tooltip(
                  message: 'Zoom out',
                  child: IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: viewController.zoomOut,
                  ),
                ),
                Text('${(viewController.transform.scale * 100).round()}%'),
                Tooltip(
                  message: 'Zoom in',
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: viewController.zoomIn,
                  ),
                ),
                Tooltip(
                  message: 'Reset view',
                  child: IconButton(
                    icon: const Icon(Icons.center_focus_strong),
                    onPressed: viewController.resetView,
                  ),
                ),
                const VerticalDivider(width: 20),
                Tooltip(
                  message: 'Add sticky note',
                  child: IconButton(
                    icon: const Icon(Icons.note_add_outlined),
                    onPressed: onAddStickyNote,
                  ),
                ),
                Tooltip(
                  message: 'Add counter',
                  child: IconButton(
                    icon: const Icon(Icons.plus_one),
                    onPressed: onAddCounter,
                  ),
                ),
                const VerticalDivider(width: 20),
                Tooltip(
                  message: 'Undo',
                  child: IconButton(
                    icon: const Icon(Icons.undo),
                    onPressed: canvasController.canUndo
                        ? canvasController.undo
                        : null,
                  ),
                ),
                Tooltip(
                  message: 'Redo',
                  child: IconButton(
                    icon: const Icon(Icons.redo),
                    onPressed: canvasController.canRedo
                        ? canvasController.redo
                        : null,
                  ),
                ),
                _LayerButton(controller: canvasController),
                Tooltip(
                  message: 'Clear',
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: canvasController.elements.isEmpty
                        ? null
                        : () => canvasController.clear(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
        child: InkResponse(
          onTap: onPressed,
          radius: 17,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: selected ? const Color(0xFF111827) : Colors.white,
                width: selected ? 3 : 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

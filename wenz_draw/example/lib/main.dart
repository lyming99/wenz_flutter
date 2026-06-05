import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  WenzDraw.registerBuiltinRenderers();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wenz_draw 无限画布示例',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const InfiniteCanvasDemo(),
    );
  }
}

class InfiniteCanvasDemo extends StatefulWidget {
  const InfiniteCanvasDemo({super.key});

  @override
  State<InfiniteCanvasDemo> createState() => _InfiniteCanvasDemoState();
}

class _InfiniteCanvasDemoState extends State<InfiniteCanvasDemo> {
  late InfiniteCanvasController _controller;
  late List<CanvasTool> _tools;
  String _activeToolId = 'pen';

  @override
  void initState() {
    super.initState();
    _controller = InfiniteCanvasController();

    _tools = [
      SelectTool(getController: () => _controller.canvasController),
      PenTool(getBrushSettings: () => _controller.canvasController.brushSettings),
      HighlighterTool(getBrushSettings: () => _controller.canvasController.brushSettings),
      LineTool(getBrushSettings: () => _controller.canvasController.brushSettings),
      ArrowTool(getBrushSettings: () => _controller.canvasController.brushSettings),
      RectTool(getBrushSettings: () => _controller.canvasController.brushSettings),
      EllipseTool(getBrushSettings: () => _controller.canvasController.brushSettings),
      TextTool(getBrushSettings: () => _controller.canvasController.brushSettings),
      EraserTool(getController: () => _controller.canvasController),
    ];

    for (final tool in _tools) {
      _controller.canvasController.toolManager.registerTool(tool);
    }
    _controller.canvasController.setTool('pen');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setTool(String toolId) {
    setState(() {
      _activeToolId = toolId;
    });
    _controller.canvasController.setTool(toolId);
  }

  IconData _getToolIcon(String iconName) {
    const iconMap = {
      'near_me': Icons.near_me,
      'edit': Icons.edit,
      'highlight': Icons.highlight,
      'show_chart': Icons.show_chart,
      'arrow_forward': Icons.arrow_forward,
      'crop_square': Icons.crop_square,
      'radio_button_unchecked': Icons.radio_button_unchecked,
      'text_fields': Icons.text_fields,
      'auto_fix_high': Icons.auto_fix_high,
    };
    return iconMap[iconName] ?? Icons.brush;
  }

  Future<void> _exportPng() async {
    final elements = _controller.canvasController.elements;
    if (elements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画布为空，无法导出')),
      );
      return;
    }

    final bounds = _controller.canvasController.selectionBounds ??
        _computeContentBounds(elements);

    try {
      final bytes = await PngExporter.exportToPng(
        elements: elements,
        contentBounds: bounds,
      );
      if (bytes != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PNG 导出成功 (${bytes.length ~/ 1024} KB)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  void _exportSvg() {
    final elements = _controller.canvasController.elements;
    if (elements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画布为空，无法导出')),
      );
      return;
    }

    final bounds = _computeContentBounds(elements);
    final svg = SvgExporter.exportToSvg(
      elements: elements,
      contentBounds: bounds,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SVG 导出成功 (${svg.length ~/ 1024} KB)')),
    );
  }

  void _exportJson() {
    final json = _controller.canvasController.toJson();
    final jsonString = const JsonEncoder.withIndent('  ').convert(json);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('JSON 导出成功 (${jsonString.length ~/ 1024} KB)')),
    );
  }

  Rect _computeContentBounds(List<CanvasElement> elements) {
    if (elements.isEmpty) return Rect.zero;
    double left = double.infinity, top = double.infinity;
    double right = double.negativeInfinity, bottom = double.negativeInfinity;
    for (final e in elements) {
      if (e.bounds.left < left) left = e.bounds.left;
      if (e.bounds.top < top) top = e.bounds.top;
      if (e.bounds.right > right) right = e.bounds.right;
      if (e.bounds.bottom > bottom) bottom = e.bounds.bottom;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('wenz_draw 无限画布'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: '更多操作',
            onSelected: (value) {
              switch (value) {
                case 'export_png': _exportPng(); break;
                case 'export_svg': _exportSvg(); break;
                case 'export_json': _exportJson(); break;
                case 'clear':
                  _controller.canvasController.elementManager.clear();
                  _controller.canvasController.deselectAll();
                  setState(() {});
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export_png', child: Text('导出 PNG')),
              const PopupMenuItem(value: 'export_svg', child: Text('导出 SVG')),
              const PopupMenuItem(value: 'export_json', child: Text('导出 JSON')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'clear', child: Text('清除画布')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 工具栏
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    ..._tools.map((tool) {
                      final isActive = tool.id == _activeToolId;
                      return _toolButton(tool, isActive);
                    }),
                    const SizedBox(width: 4),
                    Container(width: 1, height: 28, color: Theme.of(context).dividerColor),
                    const SizedBox(width: 4),
                    _colorButton(Colors.black, '黑色'),
                    _colorButton(const Color(0xFFD32F2F), '红色'),
                    _colorButton(const Color(0xFF1976D2), '蓝色'),
                    const SizedBox(width: 4),
                    // 缩放控制
                    IconButton(
                      icon: const Icon(Icons.zoom_in, size: 20),
                      tooltip: '放大',
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      onPressed: () => _controller.zoomIn(),
                    ),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final scale = _controller.transform.scale;
                        final count = _controller.canvasController.elements.length;
                        return Text(
                          '${(scale * 100).toStringAsFixed(0)}% | $count',
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_out, size: 20),
                      tooltip: '缩小',
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      onPressed: () => _controller.zoomOut(),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          // 画布 + 小地图
          Expanded(
            child: InfiniteCanvasWidget(
              controller: _controller,
              config: const InfiniteCanvasConfig(
                showGrid: true,
                gridType: GridType.dots,
                backgroundColor: Color(0xFFFFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorButton(Color color, String tooltip) {
    return IconButton(
      icon: Icon(Icons.circle, color: color, size: 16),
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      onPressed: () => _controller.canvasController.updateBrushSettings(
        BrushSettings(color: color),
      ),
    );
  }

  Widget _toolButton(CanvasTool tool, bool isActive) {
    return IconButton(
      icon: Icon(_getToolIcon(tool.iconName)),
      tooltip: tool.name,
      iconSize: 22,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: isActive
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        foregroundColor: isActive
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : null,
      ),
      onPressed: () => _setTool(tool.id),
    );
  }
}

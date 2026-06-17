import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import '../theme/ui_colors.dart';
import '../editor/editor_actions.dart';
import '../widgets/spectrum_icon.dart';
import 'line_tool_icon.dart';
import 'tool_button.dart';
import 'toolbar_divider.dart';

class Toolbar extends StatelessWidget {
  const Toolbar({
    required this.canvasController,
    required this.viewController,
    required this.onAddStickyNote,
    required this.onAddCounter,
    required this.onAddMindmap,
    required this.onInsertImage,
  });

  final CanvasController canvasController;
  final InfiniteCanvasController viewController;
  final VoidCallback onAddStickyNote;
  final VoidCallback onAddCounter;
  final VoidCallback onAddMindmap;
  final VoidCallback onInsertImage;

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
            color: UiColors.panel,
            border: Border(bottom: BorderSide(color: UiColors.line)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(MediaQuery.sizeOf(context).width - 24, 760),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ToolButton(
                    label: '菜单',
                    icon: Icons.menu,
                    selected: false,
                    onPressed: () => showFileMenu(context),
                  ),
                  const ToolbarDivider(),
                  ToolButton(
                    label: '选择',
                    icon: Icons.near_me_outlined,
                    selected: activeTool == SelectTool.idValue,
                    onPressed: () =>
                        canvasController.setTool(SelectTool.idValue),
                  ),
                  ToolButton(
                    label: '拖拽',
                    icon: Icons.open_with,
                    selected: activeTool == PanTool.idValue,
                    onPressed: () => canvasController.setTool(PanTool.idValue),
                  ),
                  const ToolbarDivider(),
                  ToolButton(
                    label: '画笔',
                    icon: Icons.edit_outlined,
                    selected: activeTool == PenTool.idValue,
                    onPressed: () => canvasController.setTool(PenTool.idValue),
                  ),
                  ToolButton(
                    label: '荧光笔',
                    icon: Icons.border_color_outlined,
                    selected: activeTool == HighlighterTool.idValue,
                    onPressed: () =>
                        canvasController.setTool(HighlighterTool.idValue),
                  ),
                  ToolButton(
                    label: '直线',
                    iconWidget: const LineToolIcon(polyline: false),
                    selected: activeTool == LineTool.idValue,
                    onPressed: () => canvasController.setTool(LineTool.idValue),
                  ),
                  ToolButton(
                    label: '折线',
                    iconWidget: const LineToolIcon(polyline: true),
                    selected: activeTool == PolylineTool.idValue,
                    onPressed: () =>
                        canvasController.setTool(PolylineTool.idValue),
                  ),
                  ToolButton(
                    label: '曲线',
                    icon: Icons.timeline,
                    selected: activeTool == CurveTool.idValue,
                    onPressed: () =>
                        canvasController.setTool(CurveTool.idValue),
                  ),
                  const ToolbarDivider(),
                  ToolButton(
                    label: '图形',
                    icon: Icons.category_outlined,
                    selected:
                        activeTool == RectTool.idValue ||
                        activeTool == EllipseTool.idValue ||
                        (activeTool?.startsWith(ShapeTool.idPrefix) ?? false),
                    onPressed: () => canvasController.setTool(RectTool.idValue),
                  ),
                  ToolButton(
                    label: '文字',
                    icon: Icons.text_fields,
                    selected: activeTool == TextTool.idValue,
                    onPressed: () => canvasController.setTool(TextTool.idValue),
                  ),
                  ToolButton(
                    label: '橡皮擦',
                    icon: Icons.cleaning_services_outlined,
                    selected: activeTool == EraserTool.idValue,
                    onPressed: () =>
                        canvasController.setTool(EraserTool.idValue),
                  ),
                  ToolButton(
                    label: '颜色选择器',
                    selected: false,
                    iconWidget: const SpectrumIcon(size: 18),
                    onPressed: () => showColorMenu(context, canvasController),
                  ),
                  const ToolbarDivider(),
                  ToolButton(
                    label: '撤销',
                    icon: Icons.undo,
                    selected: false,
                    enabled: canvasController.canUndo,
                    onPressed: canvasController.undo,
                  ),
                  ToolButton(
                    label: '重做',
                    icon: Icons.redo,
                    selected: false,
                    enabled: canvasController.canRedo,
                    onPressed: canvasController.redo,
                  ),
                  const ToolbarDivider(),
                  ToolButton(
                    label: '特殊组件创建',
                    icon: Icons.add,
                    selected: false,
                    onPressed: () => showComponentMenu(context),
                  ),
                  ToolButton(
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

  void showFileMenu(BuildContext context) {
    showAnchoredMenu<String>(
      context: context,
      items: const [
        PopupMenuItem(value: 'insert-image', child: Text('Insert image')),
        PopupMenuDivider(),
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
        case 'insert-image':
          onInsertImage();
        case 'import-json':
          showImportDialog(context, canvasController, importDrawio: false);
        case 'import-drawio':
          showImportDialog(context, canvasController, importDrawio: true);
        case 'export-json':
          showExportDialog(
            context,
            'JSON',
            prettyJson(CanvasSerializer.toJson(canvasController)),
          );
        case 'export-svg':
          showExportDialog(
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

  void showComponentMenu(BuildContext context) {
    showAnchoredMenu<String>(
      context: context,
      items: const [
        PopupMenuItem(value: 'note', child: Text('便签')),
        PopupMenuItem(value: 'counter', child: Text('计数器')),
        PopupMenuItem(value: 'mindmap', child: Text('思维导图')),
      ],
    ).then((value) {
      if (value == 'counter') {
        onAddCounter();
      } else if (value == 'note') {
        onAddStickyNote();
      } else if (value == 'mindmap') {
        onAddMindmap();
      }
    });
  }
}

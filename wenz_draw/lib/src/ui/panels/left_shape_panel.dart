import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import '../theme/ui_colors.dart';
import '../widgets/search_box.dart';
import '../widgets/shape_preview_icon.dart';
import '../widgets/shape_tile.dart';
import 'panel_section.dart';
import 'palette_subhead.dart';
import 'shape_palette_data.dart';
import 'shape_palette_group.dart';

class LeftShapePanel extends StatefulWidget {
  const LeftShapePanel({
    required this.canvasController,
    required this.onAddStickyNote,
  });

  final CanvasController canvasController;
  final VoidCallback onAddStickyNote;

  @override
  State<LeftShapePanel> createState() => _LeftShapePanelState();
}

class _LeftShapePanelState extends State<LeftShapePanel> {
  String _searchQuery = '';
  bool _basicToolsExpanded = true;

  List<DrawioShapePaletteEntry> get _allStencilEntries {
    return [
      ...basicSymbolShapePalette,
      ...flowchartShapePalette,
      ...arrowShapePalette,
      ...drawioShapePalette,
    ];
  }

  List<DrawioShapePaletteEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return const [];
    final q = _searchQuery.toLowerCase();
    return _allStencilEntries
        .where((e) =>
            e.label.toLowerCase().contains(q) ||
            e.shapeKey.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeTool = widget.canvasController.currentTool?.id;
    return Container(
      width: 244,
      color: UiColors.panel,
      child: SingleChildScrollView(
        child: PanelSection(
          title: '图形',
          actionLabel: '管理',
          children: [
            SearchBox(
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            if (_searchQuery.isEmpty) ...[
              PaletteSubhead(
                '基本工具',
                onTap: () => setState(
                    () => _basicToolsExpanded = !_basicToolsExpanded),
                isExpanded: _basicToolsExpanded,
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _basicToolsExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.35,
                  children: [
                    ShapeTile(
                      label: '矩形',
                      icon: Icons.crop_square,
                      selected: activeTool == RectTool.idValue,
                      onPressed: () =>
                          widget.canvasController.setTool(RectTool.idValue),
                    ),
                    ShapeTile(
                      label: '圆形',
                      icon: Icons.circle_outlined,
                      selected: activeTool == EllipseTool.idValue,
                      onPressed: () =>
                          widget.canvasController.setTool(EllipseTool.idValue),
                    ),
                    ShapeTile(
                      label: '菱形',
                      iconWidget: Transform.rotate(
                        angle: math.pi / 4,
                        child: const Icon(Icons.crop_square, size: 32),
                      ),
                      selected: activeTool == ShapeTool.idFor('rhombus'),
                      onPressed: () => widget.canvasController
                          .setTool(ShapeTool.idFor('rhombus')),
                    ),
                    ShapeTile(
                      label: '箭头',
                      icon: Icons.arrow_forward,
                      selected: activeTool == ArrowTool.idValue,
                      onPressed: () =>
                          widget.canvasController.setTool(ArrowTool.idValue),
                    ),
                    ShapeTile(
                      label: '便签',
                      icon: Icons.sticky_note_2_outlined,
                      selected: false,
                      onPressed: widget.onAddStickyNote,
                    ),
                    ShapeTile(
                      label: '文本',
                      icon: Icons.text_fields,
                      selected: activeTool == TextTool.idValue,
                      onPressed: () =>
                          widget.canvasController.setTool(TextTool.idValue),
                    ),
                  ],
                ),
                secondChild: const SizedBox(width: double.infinity),
              ),
              ShapePaletteGroup(
                title: '基本形状',
                entries: drawioShapePalette
                    .where((entry) => entry.group == 'basic')
                    .toList(growable: false),
                activeTool: activeTool,
                onSelect: widget.canvasController.setTool,
              ),
              ShapePaletteGroup(
                title: '基本符号',
                entries: basicSymbolShapePalette,
                activeTool: activeTool,
                onSelect: widget.canvasController.setTool,
              ),
              ShapePaletteGroup(
                title: '流程图',
                entries: flowchartShapePalette,
                activeTool: activeTool,
                onSelect: widget.canvasController.setTool,
              ),
              ShapePaletteGroup(
                title: '箭头',
                entries: arrowShapePalette,
                activeTool: activeTool,
                onSelect: widget.canvasController.setTool,
              ),
              ShapePaletteGroup(
                title: '容器',
                entries: drawioShapePalette
                    .where((entry) => entry.group == 'container')
                    .toList(growable: false),
                activeTool: activeTool,
                onSelect: widget.canvasController.setTool,
              ),
            ] else ...[
              PaletteSubhead('搜索结果 (${_filteredEntries.length})'),
              if (_filteredEntries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      '未找到匹配的图形',
                      style: TextStyle(color: UiColors.muted, fontSize: 13),
                    ),
                  ),
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.35,
                  children: [
                    for (final entry in _filteredEntries)
                      ShapeTile(
                        label: entry.label,
                        iconWidget:
                            ShapePreviewIcon(shapeKey: entry.shapeKey),
                        selected: activeTool == entry.toolId,
                        onPressed: () =>
                            widget.canvasController.setTool(entry.toolId),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

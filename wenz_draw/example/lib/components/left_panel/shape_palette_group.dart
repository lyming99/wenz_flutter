import 'package:flutter/material.dart';

import '../common/shape_preview_icon.dart';
import '../common/shape_tile.dart';
import 'palette_subhead.dart';
import 'shape_palette_data.dart';

class ShapePaletteGroup extends StatefulWidget {
  const ShapePaletteGroup({
    required this.title,
    required this.entries,
    required this.activeTool,
    required this.onSelect,
  });

  final String title;
  final List<DrawioShapePaletteEntry> entries;
  final String? activeTool;
  final ValueChanged<String> onSelect;

  @override
  State<ShapePaletteGroup> createState() => ShapePaletteGroupState();
}

class ShapePaletteGroupState extends State<ShapePaletteGroup> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PaletteSubhead(
          widget.title,
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          isExpanded: _isExpanded,
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _isExpanded
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
              for (final entry in widget.entries)
                ShapeTile(
                  label: entry.label,
                  iconWidget: ShapePreviewIcon(shapeKey: entry.shapeKey),
                  selected: widget.activeTool == entry.toolId,
                  onPressed: () => widget.onSelect(entry.toolId),
                ),
            ],
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

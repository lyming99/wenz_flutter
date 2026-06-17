import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import '../theme/ui_colors.dart';

class LayerRow extends StatelessWidget {
  const LayerRow({
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
        color: active ? UiColors.accentSoft : UiColors.panelSoft,
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
                      color: UiColors.muted,
                    ),
                  ),
                ),
                Icon(
                  active
                      ? Icons.check_box_outline_blank
                      : Icons.diamond_outlined,
                  size: 14,
                  color: active ? UiColors.accent : UiColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    layer.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active
                          ? UiColors.accent
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
                    color: active ? UiColors.accent : UiColors.muted,
                  ),
                  onPressed: onToggleVisible,
                ),
                IconButton(
                  tooltip: canDelete ? '删除图层' : '至少保留一个图层',
                  icon: const Icon(Icons.delete_outline, size: 15),
                  color: canDelete ? UiColors.muted : const Color(0xFFB8C2CC),
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

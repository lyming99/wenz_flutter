import 'package:flutter/material.dart';

import '../controller/slash_menu_controller.dart';

class WenzSlashMenuOverlay extends StatelessWidget {
  const WenzSlashMenuOverlay({
    super.key,
    required this.controller,
    this.maxWidth = 280,
    this.maxHeight = 320,
  });

  final SlashMenuController controller;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isOpen) {
          return const SizedBox.shrink();
        }
        final items = controller.items;
        final theme = Theme.of(context);
        return Material(
          key: const ValueKey<String>('wenz-slash-menu-overlay'),
          color: theme.colorScheme.surface,
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = index == controller.highlightedIndex;
                return _SlashMenuTile(
                  key: ValueKey<String>('wenz-slash-item-${item.id}'),
                  item: item,
                  selected: selected,
                  onTap: () {
                    controller.selectIndex(index);
                    controller.activate(item);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SlashMenuTile extends StatelessWidget {
  const _SlashMenuTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SlashMenuItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primaryContainer.withAlpha(130);
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(_iconFor(item.icon), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(item.title, style: theme.textTheme.bodyMedium),
                    if (item.description.isNotEmpty)
                      Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(String icon) {
  return switch (icon) {
    'title' => Icons.title,
    'list' => Icons.format_list_bulleted,
    'check_box' => Icons.check_box_outlined,
    'format_quote' => Icons.format_quote,
    'code' => Icons.code,
    'table_chart' => Icons.table_chart,
    'image' => Icons.image_outlined,
    _ => Icons.auto_awesome,
  };
}

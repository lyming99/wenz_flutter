import 'package:flutter/material.dart';

import '../controller/outline_controller.dart';

/// A read-only outline tree that renders the current document's heading
/// structure.
///
/// [WenzOutlineTree] is the presentation counterpart to [WenzOutlineController]:
/// it receives an immutable [OutlineItem] list (typically
/// [WenzOutlineController.items]) and renders each heading, indented by its
/// [OutlineItem.level] (H1–H6). It stays purely presentational — selection,
/// active-heading tracking, and collapse wiring are driven by the caller via
/// [activeBlockId], [onSelect], and [onToggleCollapse], so the host example can
/// keep the controller as the single source of truth.
///
/// The structural shape mirrors [WenzCommentSidebar] (`SizedBox` + `Material` +
/// `Column`: header + list + empty state) so the two side panels read as one
/// family. Tap a row to navigate ([onSelect]); the controller moves the
/// selection to that heading and a mounted [WenzRichTextEditor] scrolls it into
/// view via its existing selection handling.
class WenzOutlineTree extends StatelessWidget {
  const WenzOutlineTree({
    super.key,
    required this.items,
    this.activeBlockId,
    this.width = 260,
    this.onSelect,
    this.onToggleCollapse,
    this.emptyBuilder,
  });

  /// Heading entries to render, usually [WenzOutlineController.items].
  final List<OutlineItem> items;

  /// Block id of the currently active heading (e.g. the one covering the
  /// caret). When it matches an item's [OutlineItem.blockId] that row renders
  /// highlighted.
  final String? activeBlockId;

  /// Fixed panel width.
  final double width;

  /// Invoked with the tapped heading. The host typically forwards this to
  /// [WenzOutlineController.select], which scrolls the editor to the heading.
  final ValueChanged<OutlineItem>? onSelect;

  /// Invoked when a collapsible heading's fold toggle is pressed. The host
  /// typically forwards this to [WenzOutlineController.toggle].
  final ValueChanged<OutlineItem>? onToggleCollapse;

  /// Overrides the default empty state when [items] is empty.
  final WidgetBuilder? emptyBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      key: const ValueKey<String>('wenz-outline-tree'),
      width: width,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 1,
        shadowColor: theme.colorScheme.shadow.withAlpha(32),
        surfaceTintColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _OutlineHeader(totalCount: items.length),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            if (items.isEmpty)
              Expanded(
                child: emptyBuilder?.call(context) ?? const _EmptyOutline(),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _OutlineItemRow(
                      item: item,
                      isActive: item.blockId == activeBlockId,
                      onSelect: onSelect,
                      onToggleCollapse: onToggleCollapse,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OutlineHeader extends StatelessWidget {
  const _OutlineHeader({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.account_tree_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Outline',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            '$totalCount heading${totalCount == 1 ? '' : 's'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineItemRow extends StatelessWidget {
  const _OutlineItemRow({
    required this.item,
    required this.isActive,
    this.onSelect,
    this.onToggleCollapse,
  });

  final OutlineItem item;
  final bool isActive;
  final ValueChanged<OutlineItem>? onSelect;
  final ValueChanged<OutlineItem>? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // H1 sits at the root, each deeper level indents one step.
    const indentStep = 14.0;
    final levelIndent = (item.level - 1).clamp(0, 5) * indentStep;
    final showToggle = item.canCollapse && onToggleCollapse != null;
    return InkWell(
      onTap: onSelect == null ? null : () => onSelect!(item),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primaryContainer.withAlpha(
                  theme.brightness == Brightness.dark ? 72 : 48,
                )
              : Colors.transparent,
          border: BorderDirectional(
            start: BorderSide(
              color: isActive ? colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: 8 + levelIndent,
            top: 6,
            bottom: 6,
            end: 8,
          ),
          child: Row(
            children: <Widget>[
              if (showToggle)
                _CollapseToggle(
                  item: item,
                  onTap: () => onToggleCollapse!(item),
                )
              else
                const SizedBox(width: 24, height: 24),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: isActive ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapseToggle extends StatelessWidget {
  const _CollapseToggle({required this.item, required this.onTap});

  final OutlineItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        splashRadius: 14,
        visualDensity: VisualDensity.compact,
        color: theme.colorScheme.onSurfaceVariant,
        tooltip: item.isCollapsed ? 'Expand' : 'Collapse',
        onPressed: onTap,
        icon: Icon(
          item.isCollapsed ? Icons.chevron_right : Icons.expand_more,
        ),
      ),
    );
  }
}

class _EmptyOutline extends StatelessWidget {
  const _EmptyOutline();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'No headings',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

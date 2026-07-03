import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/outline_controller.dart';

// ---------------------------------------------------------------------------
// WenzOutlinePanel — smart wrapper that holds the controller subscription
// ---------------------------------------------------------------------------

/// Convenience widget that wraps [WenzOutlineTree] with a live
/// [WenzOutlineController] subscription.
///
/// Automatically computes [activeBlockId] from the editor selection and wires
/// [onSelect] to [WenzOutlineController.select]. Outline row collapse state is
/// kept locally by [WenzOutlineTree] so panel folding only affects the tree and
/// never changes the editor body's collapsed block projection. Keyboard
/// navigation is enabled by default.
class WenzOutlinePanel extends StatefulWidget {
  const WenzOutlinePanel({
    super.key,
    required this.controller,
    this.width = 260,
    this.emptyBuilder,
  });

  final WenzOutlineController controller;
  final double width;
  final WidgetBuilder? emptyBuilder;

  @override
  State<WenzOutlinePanel> createState() => _WenzOutlinePanelState();
}

class _WenzOutlinePanelState extends State<WenzOutlinePanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(WenzOutlinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return WenzOutlineTree(
      items: ctrl.items,
      activeBlockId: activeBlockId,
      width: widget.width,
      emptyBuilder: widget.emptyBuilder,
      enableKeyboardNavigation: true,
      onSelect: (item) => ctrl.select(item),
    );
  }

  String? get activeBlockId {
    final caretBlockIndex =
        widget.controller.editor.selection?.extent.blockIndex;
    if (caretBlockIndex == null) return null;
    final items = widget.controller.items;
    for (var i = items.length - 1; i >= 0; i--) {
      if (items[i].blockIndex <= caretBlockIndex) {
        return items[i].blockId;
      }
    }
    return null;
  }

}

// ---------------------------------------------------------------------------
// WenzOutlineTree — pure presentation component
// ---------------------------------------------------------------------------

/// A read-only outline tree that renders the current document's heading
/// structure.
///
/// [WenzOutlineTree] is the presentation counterpart to [WenzOutlineController]:
/// it receives an immutable [OutlineItem] list (typically
/// [WenzOutlineController.items]) and renders each heading, indented by its
/// [OutlineItem.level] (H1–H6). It stays purely presentational — selection,
/// active-heading tracking, and collapse wiring are driven by the caller via
/// [activeBlockId], [onSelect], and optional collapse notification callbacks.
/// Tree folding is local display state and is intentionally independent from
/// [WenzOutlineController.toggle], which controls editor body visibility.
///
/// The structural shape mirrors [WenzCommentSidebar] (`SizedBox` + `Material` +
/// `Column`: header + list + empty state) so the two side panels read as one
/// family. Tap a row to navigate ([onSelect]); the controller moves the
/// selection to that heading and a mounted [WenzRichTextEditor] scrolls it into
/// view via its existing selection handling.
///
/// When [enableKeyboardNavigation] is `true` the tree acquires [Focus] and
/// responds to ArrowUp / ArrowDown / Enter / Space for keyboard-driven
/// navigation.
class WenzOutlineTree extends StatefulWidget {
  const WenzOutlineTree({
    super.key,
    required this.items,
    this.activeBlockId,
    this.width = 260,
    this.onSelect,
    this.onToggleCollapse,
    this.emptyBuilder,
    this.onExpandAll,
    this.onCollapseAll,
    this.enableKeyboardNavigation = false,
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

  /// Invoked after a collapsible heading's tree-only fold toggle is pressed.
  /// The tree updates its own display state first; callers should treat this as
  /// an observation hook, not as editor body-collapse wiring.
  final ValueChanged<OutlineItem>? onToggleCollapse;

  /// Overrides the default empty state when [items] is empty.
  final WidgetBuilder? emptyBuilder;

  /// Called when the "expand all" button is pressed.
  final VoidCallback? onExpandAll;

  /// Called when the "collapse all" button is pressed.
  final VoidCallback? onCollapseAll;

  /// Whether to enable keyboard navigation (ArrowUp / ArrowDown / Enter /
  /// Space).  Defaults to `false` for backward compatibility.
  final bool enableKeyboardNavigation;

  @override
  State<WenzOutlineTree> createState() => _WenzOutlineTreeState();
}

class _WenzOutlineTreeState extends State<WenzOutlineTree> {
  int _focusedIndex = 0;
  final FocusNode _focusNode = FocusNode();
  Set<String> _collapsedBlockIds = const <String>{};

  @override
  void didUpdateWidget(WenzOutlineTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      final collapsibleIds = widget.items
          .where((item) => item.canCollapse)
          .map((item) => item.blockId)
          .toSet();
      _collapsedBlockIds = Set<String>.unmodifiable(
        _collapsedBlockIds.where(collapsibleIds.contains),
      );
      _focusedIndex = _clampFocusedIndex(_visibleItems.length);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    final visibleItems = _visibleItems;
    if (event is! KeyDownEvent || visibleItems.isEmpty) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        setState(() {
          _focusedIndex = _clampFocusedIndex(
            visibleItems.length,
            candidate: _focusedIndex - 1,
          );
        });
      case LogicalKeyboardKey.arrowDown:
        setState(() {
          _focusedIndex = _clampFocusedIndex(
            visibleItems.length,
            candidate: _focusedIndex + 1,
          );
        });
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.select:
        widget.onSelect?.call(visibleItems[_focusedIndex]);
      default:
        break;
    }
  }

  int _clampFocusedIndex(int itemCount, {int? candidate}) {
    if (itemCount <= 0) return 0;
    return (candidate ?? _focusedIndex).clamp(0, itemCount - 1).toInt();
  }

  List<OutlineItem> get _visibleItems {
    if (_collapsedBlockIds.isEmpty) {
      return widget.items
          .map(_itemWithTreeCollapseState)
          .toList(growable: false);
    }

    final visibleItems = <OutlineItem>[];
    for (final item in widget.items) {
      var hiddenByCollapsedAncestor = false;
      for (final visibleItem in visibleItems) {
        if (!_collapsedBlockIds.contains(visibleItem.blockId) ||
            !visibleItem.canCollapse) {
          continue;
        }
        if (visibleItem.collapseRange.containsBlockIndex(item.blockIndex)) {
          hiddenByCollapsedAncestor = true;
          break;
        }
      }
      if (!hiddenByCollapsedAncestor) {
        visibleItems.add(_itemWithTreeCollapseState(item));
      }
    }
    return visibleItems;
  }

  OutlineItem _itemWithTreeCollapseState(OutlineItem item) {
    return OutlineItem(
      blockId: item.blockId,
      blockIndex: item.blockIndex,
      level: item.level,
      title: item.title,
      anchor: item.anchor,
      collapseRange: item.collapseRange,
      isCollapsed: _collapsedBlockIds.contains(item.blockId),
    );
  }

  void _toggleTreeCollapse(OutlineItem item) {
    if (!item.canCollapse) return;
    setState(() {
      final next = Set<String>.of(_collapsedBlockIds);
      if (!next.add(item.blockId)) {
        next.remove(item.blockId);
      }
      _collapsedBlockIds = Set<String>.unmodifiable(next);
      _focusedIndex = _clampFocusedIndex(_visibleItems.length);
    });
    widget.onToggleCollapse?.call(
      _itemWithTreeCollapseState(item),
    );
  }

  void _expandAllTreeItems() {
    setState(() {
      _collapsedBlockIds = const <String>{};
      _focusedIndex = _clampFocusedIndex(_visibleItems.length);
    });
    widget.onExpandAll?.call();
  }

  void _collapseAllTreeItems() {
    setState(() {
      _collapsedBlockIds = Set<String>.unmodifiable(
        widget.items
            .where((item) => item.canCollapse)
            .map((item) => item.blockId),
      );
      _focusedIndex = _clampFocusedIndex(_visibleItems.length);
    });
    widget.onCollapseAll?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleItems = _visibleItems;
    final tree = SizedBox(
      key: const ValueKey<String>('wenz-outline-tree'),
      width: widget.width,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 1,
        shadowColor: theme.colorScheme.shadow.withAlpha(32),
        surfaceTintColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _OutlineHeader(
              totalCount: widget.items.length,
              hasCollapsibleItems:
                  widget.items.any((item) => item.canCollapse),
              onExpandAll: _expandAllTreeItems,
              onCollapseAll: _collapseAllTreeItems,
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            if (widget.items.isEmpty)
              Expanded(
                child:
                    widget.emptyBuilder?.call(context) ?? const _EmptyOutline(),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: visibleItems.length,
                  itemBuilder: (context, index) {
                    final item = visibleItems[index];
                    return _OutlineItemRow(
                      item: item,
                      isActive: item.blockId == widget.activeBlockId,
                      isFocused:
                          widget.enableKeyboardNavigation &&
                          index == _focusedIndex,
                      onSelect: widget.onSelect,
                      onToggleCollapse: _toggleTreeCollapse,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.enableKeyboardNavigation) {
      return KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: tree,
      );
    }
    return tree;
  }
}

// ---------------------------------------------------------------------------
// Private widget tree
// ---------------------------------------------------------------------------

class _OutlineHeader extends StatelessWidget {
  const _OutlineHeader({
    required this.totalCount,
    this.hasCollapsibleItems = false,
    this.onExpandAll,
    this.onCollapseAll,
  });

  final int totalCount;
  final bool hasCollapsibleItems;
  final VoidCallback? onExpandAll;
  final VoidCallback? onCollapseAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
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
          if (hasCollapsibleItems) ...[
            const SizedBox(width: 4),
            IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              splashRadius: 16,
              visualDensity: VisualDensity.compact,
              tooltip: 'Collapse all',
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: onCollapseAll,
              icon: const Icon(Icons.unfold_less),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              splashRadius: 16,
              visualDensity: VisualDensity.compact,
              tooltip: 'Expand all',
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: onExpandAll,
              icon: const Icon(Icons.unfold_more),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutlineItemRow extends StatelessWidget {
  const _OutlineItemRow({
    required this.item,
    required this.isActive,
    this.isFocused = false,
    this.onSelect,
    this.onToggleCollapse,
  });

  final OutlineItem item;
  final bool isActive;
  final bool isFocused;
  final ValueChanged<OutlineItem>? onSelect;
  final ValueChanged<OutlineItem>? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const indentStep = 14.0;
    final levelIndent = (item.level - 1).clamp(0, 5) * indentStep;
    final showToggle = item.canCollapse && onToggleCollapse != null;

    // Heading-level badge
    final levelAlpha = (32 - (item.level - 1) * 4).clamp(8, 32);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withAlpha(levelAlpha),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'H${item.level}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.2,
        ),
      ),
    );

    return InkWell(
      onTap: onSelect == null ? null : () => onSelect!(item),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primaryContainer.withAlpha(
                  theme.brightness == Brightness.dark ? 72 : 48,
                )
              : isFocused
                  ? colorScheme.onSurface.withAlpha(12)
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
              if (showToggle) ...[
                _CollapseToggle(
                  item: item,
                  onTap: () => onToggleCollapse!(item),
                ),
                const SizedBox(width: 4),
              ],
              badge,
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

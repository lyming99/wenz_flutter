import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controller/slash_menu_controller.dart';

// Keep slash menu chrome aligned with the "Electron 风格斜杆 popup 规范" section in
// docs/design/menu_toolbar_minimal_spec.md (visual source:
// ui/slash_popup_electron_design.html). Flat/restrained shadow, clear hierarchy,
// compact rhythm; all colors below stay within colorScheme (no hardcoded theme
// colors), and behavior (sizing/anchoring/keyboard routing) is unchanged.
const double _kSlashMenuSurfaceRadius = 10.0;
const double _kSlashMenuSurfaceElevation = 3.0;
const int _kSlashMenuSurfaceShadowAlpha = 24;
const int _kSlashMenuSurfaceBorderAlpha = 36;
const EdgeInsets _kSlashMenuPadding = EdgeInsets.all(6);
const double _kSlashMenuItemRadius = 8.0;
const EdgeInsets _kSlashMenuItemOuterPadding = EdgeInsets.symmetric(vertical: 1);
const EdgeInsets _kSlashMenuItemPadding = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 7,
);
const EdgeInsets _kSlashMenuEmptyPadding = EdgeInsets.symmetric(
  horizontal: 18,
  vertical: 22,
);
const double _kSlashMenuEmptyMinHeight = 132.0;
const double _kSlashMenuIconSize = 20.0;
const double _kSlashMenuIconTextGap = 10.0;
const int _kSlashMenuHoverAlpha = 13;
const int _kSlashMenuHighlightAlpha = 46;
const int _kSlashMenuSplashAlpha = 32;
const int _kSlashMenuSelectedAlphaLight = 31;
const int _kSlashMenuSelectedAlphaDark = 41;

Color _slashMenuSurfaceColor(ThemeData theme) =>
    theme.colorScheme.surfaceContainerLow;

Color _slashMenuShadowColor(ThemeData theme) =>
    theme.colorScheme.shadow.withAlpha(_kSlashMenuSurfaceShadowAlpha);

ShapeBorder _slashMenuShape(ThemeData theme) {
  return RoundedRectangleBorder(
    side: BorderSide(
      color: theme.colorScheme.outlineVariant.withAlpha(
        _kSlashMenuSurfaceBorderAlpha,
      ),
    ),
    borderRadius: BorderRadius.circular(_kSlashMenuSurfaceRadius),
  );
}

class WenzSlashMenuOverlay extends StatelessWidget {
  const WenzSlashMenuOverlay({
    super.key,
    required this.controller,
    this.minWidth = 184,
    this.maxWidth = 320,
    this.maxHeight = 320,
  });

  final SlashMenuController controller;
  final double minWidth;
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
        final colorScheme = theme.colorScheme;
        final effectiveMaxWidth = math.max(0.0, maxWidth);
        final effectiveMinWidth = math.min(
          math.max(0.0, minWidth),
          effectiveMaxWidth,
        );
        final effectiveMaxHeight = math.max(0.0, maxHeight);
        return Listener(
          behavior: HitTestBehavior.opaque,
          child: Material(
            key: const ValueKey<String>('wenz-slash-menu-overlay'),
            color: _slashMenuSurfaceColor(theme),
            elevation: _kSlashMenuSurfaceElevation,
            shadowColor: _slashMenuShadowColor(theme),
            surfaceTintColor: colorScheme.surfaceTint.withAlpha(0),
            shape: _slashMenuShape(theme),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: effectiveMinWidth,
                maxWidth: effectiveMaxWidth,
                maxHeight: effectiveMaxHeight,
              ),
              child: items.isEmpty
                  ? const _SlashMenuEmptyState()
                  : Scrollbar(
                      thumbVisibility: false,
                      child: ListView.builder(
                        padding: _kSlashMenuPadding,
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
    final colorScheme = theme.colorScheme;
    final selectedColor = colorScheme.primary.withAlpha(
      theme.brightness == Brightness.dark
          ? _kSlashMenuSelectedAlphaDark
          : _kSlashMenuSelectedAlphaLight,
    );
    final iconColor =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: selected ? colorScheme.primary : colorScheme.onSurface,
    );
    return Semantics(
      selected: selected,
      button: true,
      label: item.description.isEmpty
          ? item.title
          : '${item.title}, ${item.description}',
      child: Padding(
        padding: _kSlashMenuItemOuterPadding,
        child: InkWell(
          borderRadius: BorderRadius.circular(_kSlashMenuItemRadius),
          hoverColor: colorScheme.onSurface.withAlpha(_kSlashMenuHoverAlpha),
          highlightColor: colorScheme.primary.withAlpha(
            _kSlashMenuHighlightAlpha,
          ),
          splashColor: colorScheme.primary.withAlpha(_kSlashMenuSplashAlpha),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? selectedColor : colorScheme.surface.withAlpha(0),
              borderRadius: BorderRadius.circular(_kSlashMenuItemRadius),
            ),
            child: Padding(
              padding: _kSlashMenuItemPadding,
              child: Row(
                children: <Widget>[
                  Icon(
                    _iconFor(item.icon),
                    size: _kSlashMenuIconSize,
                    color: iconColor,
                  ),
                  const SizedBox(width: _kSlashMenuIconTextGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(item.title, style: titleStyle),
                        if (item.description.isNotEmpty)
                          Text(
                            item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlashMenuEmptyState extends StatelessWidget {
  const _SlashMenuEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      label: '未找到斜杆命令',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kSlashMenuEmptyMinHeight),
        child: Padding(
          padding: _kSlashMenuEmptyPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.search_off,
                size: _kSlashMenuIconSize,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(
                '未找到命令',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '试试输入「表格」「图片」或「代码」。',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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
    'video' => Icons.smart_display_outlined,
    _ => Icons.auto_awesome,
  };
}


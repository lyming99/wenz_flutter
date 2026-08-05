import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controller/slash_menu_controller.dart';
import 'editor_tokens.dart';

// Keep slash menu chrome aligned with docs/design/menu_toolbar_minimal_spec.md:
// flat/restrained shadow, clear hierarchy, compact rhythm; chrome colors use
// fixed neutral light/dark tokens, and behavior (sizing/anchoring/keyboard
// routing) is unchanged.
const double _kSlashMenuSurfaceRadius = 10.0;
const double _kSlashMenuSurfaceElevation = 3.0;
const int _kSlashMenuSurfaceShadowAlpha = 30;
const Color _kSlashMenuSurfaceColorLight = Color(0xFFF8F9FA);
const Color _kSlashMenuSurfaceColorDark = Color(0xFF292A2D);
const Color _kSlashMenuSurfaceBorderColorLight = Color(0xFFDADCE0);
const Color _kSlashMenuSurfaceBorderColorDark = Color(0xFF4A4C50);
const EdgeInsets _kSlashMenuPadding = EdgeInsets.all(6);
const double _kSlashMenuItemRadius = 8.0;
const EdgeInsets _kSlashMenuItemOuterPadding =
    EdgeInsets.symmetric(vertical: 1);
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
const Color _kSlashMenuHoverColorLight = Color(0xFFF1F3F4);
const Color _kSlashMenuHoverColorDark = Color(0xFF34363A);
const Color _kSlashMenuSelectedColorLight = Color(0xFFE8EAED);
const Color _kSlashMenuSelectedColorDark = Color(0xFF3C4043);
const Color _kSlashMenuHighlightColorLight = Color(0x1A000000);
const Color _kSlashMenuHighlightColorDark = Color(0x21FFFFFF);
const Color _kSlashMenuSplashColorLight = Color(0x26000000);
const Color _kSlashMenuSplashColorDark = Color(0x2EFFFFFF);

Color _slashMenuSurfaceColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kSlashMenuSurfaceColorDark
      : _kSlashMenuSurfaceColorLight;
}

Color _slashMenuShadowColor(ThemeData theme) =>
    theme.colorScheme.shadow.withAlpha(_kSlashMenuSurfaceShadowAlpha);

Color _slashMenuBorderColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kSlashMenuSurfaceBorderColorDark
      : _kSlashMenuSurfaceBorderColorLight;
}

Color _slashMenuHoverColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kSlashMenuHoverColorDark
      : _kSlashMenuHoverColorLight;
}

Color _slashMenuSelectedColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kSlashMenuSelectedColorDark
      : _kSlashMenuSelectedColorLight;
}

Color _slashMenuHighlightColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kSlashMenuHighlightColorDark
      : _kSlashMenuHighlightColorLight;
}

Color _slashMenuSplashColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kSlashMenuSplashColorDark
      : _kSlashMenuSplashColorLight;
}

ShapeBorder _slashMenuShape(ThemeData theme) {
  return RoundedRectangleBorder(
    side: BorderSide(
      color: _slashMenuBorderColor(theme),
    ),
    borderRadius: BorderRadius.circular(_kSlashMenuSurfaceRadius),
  );
}

class WenzSlashMenuOverlay extends StatefulWidget {
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
  State<WenzSlashMenuOverlay> createState() => _WenzSlashMenuOverlayState();
}

class _WenzSlashMenuOverlayState extends State<WenzSlashMenuOverlay> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};
  late int _highlightedIndex = widget.controller.highlightedIndex;
  ScrollPositionAlignmentPolicy _alignmentPolicy =
      ScrollPositionAlignmentPolicy.keepVisibleAtStart;
  bool _ensureVisibleScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant WenzSlashMenuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) {
      return;
    }
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
    _highlightedIndex = widget.controller.highlightedIndex;
    _scheduleEnsureHighlightedVisible();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final nextIndex = widget.controller.highlightedIndex;
    if (nextIndex != _highlightedIndex) {
      _alignmentPolicy = nextIndex > _highlightedIndex
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : ScrollPositionAlignmentPolicy.keepVisibleAtStart;
      _highlightedIndex = nextIndex;
    }
    _scheduleEnsureHighlightedVisible();
  }

  void _scheduleEnsureHighlightedVisible() {
    if (_ensureVisibleScheduled) {
      return;
    }
    _ensureVisibleScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVisibleScheduled = false;
      if (!mounted ||
          !widget.controller.isOpen ||
          widget.controller.items.isEmpty ||
          !_scrollController.hasClients) {
        return;
      }

      final index = widget.controller.highlightedIndex;
      final items = widget.controller.items;
      if (index < 0 || index >= items.length) {
        return;
      }
      final itemContext = _itemKeys[items[index].id]?.currentContext;
      final renderObject = itemContext?.findRenderObject();
      if (renderObject != null && renderObject.attached) {
        _scrollController.position.ensureVisible(
          renderObject,
          alignmentPolicy: _alignmentPolicy,
        );
        return;
      }

      // A lazily built boundary item may not have a context yet when keyboard
      // navigation wraps from first to last (or back). Reveal that boundary,
      // then refine the item's visibility after the list builds it.
      if (index == 0) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        _scheduleEnsureHighlightedVisible();
      } else if (index == items.length - 1) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        _scheduleEnsureHighlightedVisible();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (!widget.controller.isOpen) {
          return const SizedBox.shrink();
        }
        final items = widget.controller.items;
        final itemIds = items.map((item) => item.id).toSet();
        _itemKeys.removeWhere((id, _) => !itemIds.contains(id));
        final theme = Theme.of(context);
        final effectiveMaxWidth = math.max(0.0, widget.maxWidth);
        final effectiveMinWidth = math.min(
          math.max(0.0, widget.minWidth),
          effectiveMaxWidth,
        );
        final effectiveMaxHeight = math.max(0.0, widget.maxHeight);
        return Listener(
          behavior: HitTestBehavior.opaque,
          child: Material(
            key: const ValueKey<String>('wenz-slash-menu-overlay'),
            color: _slashMenuSurfaceColor(theme),
            elevation: _kSlashMenuSurfaceElevation,
            shadowColor: _slashMenuShadowColor(theme),
            surfaceTintColor: Colors.transparent,
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
                      controller: _scrollController,
                      thumbVisibility: false,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: _kSlashMenuPadding,
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final selected =
                              index == widget.controller.highlightedIndex;
                          return KeyedSubtree(
                            key: _itemKeys.putIfAbsent(item.id, GlobalKey.new),
                            child: _SlashMenuTile(
                              key: ValueKey<String>(
                                'wenz-slash-item-${item.id}',
                              ),
                              item: item,
                              selected: selected,
                              onTap: () {
                                widget.controller.selectIndex(index);
                                widget.controller.activate(item);
                              },
                            ),
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
    // Touch surfaces get larger tap targets and a slightly bigger icon so the
    // caret-anchored compact popup is comfortably finger-tappable on phones.
    // Desktop keeps the denser original sizing (acceptance: desktop unchanged).
    final isMobile = EditorTokens.resolve(context).isMobile;
    final tilePadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 13)
        : _kSlashMenuItemPadding;
    final iconSize = isMobile
        ? EditorTokens.mobile.minimalToolbarIconSize
        : _kSlashMenuIconSize;
    final iconColor =
        selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant;
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
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
          hoverColor: _slashMenuHoverColor(theme),
          highlightColor: _slashMenuHighlightColor(theme),
          splashColor: _slashMenuSplashColor(theme),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? _slashMenuSelectedColor(theme)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(_kSlashMenuItemRadius),
            ),
            child: Padding(
              padding: tilePadding,
              child: Row(
                children: <Widget>[
                  Icon(
                    _iconFor(item.icon),
                    size: iconSize,
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

import 'dart:async';

import 'package:flutter/material.dart';

import '../controller/toolbar_controller.dart';
import '../controller/wenz_rich_text_controller.dart';
import '../core/commands/inline_editing.dart';
import '../integration/wenz_editor_configuration.dart';
import 'default_desktop_toolbar.dart';
import 'link_edit_dialog.dart';
import 'lucide_toolbar_icons.dart';

/// Touch sizing for the mobile toolbar mirrors EditorTokens.mobile (kept in
/// sync by hand — Dart's constant evaluator on this SDK rejects
/// `EditorTokens.mobile.x` in const expressions, so the literals are duplicated
/// here). The mobile toolbar is always the mobile surface, so the mobile token
/// set is authoritative regardless of the screen it happens to be mounted on.
const double _kMobileToolbarButtonSize = 40.0; // == EditorTokens.mobile.minimalToolbarButtonSize
const double _kMobileToolbarIconSize = 22.0; // == EditorTokens.mobile.minimalToolbarIconSize
const double _kMobileToolbarRadius = 10.0;
const double _kMobileToolbarGap = 4.0;
const double _kMobileToolbarHorizontalPadding = 8.0;
const double _kMobileToolbarVerticalPadding = 6.0;
const double _kMobilePanelMaxHeight = 240.0;

const List<_MobileColorOption> _kMobileColorOptions = <_MobileColorOption>[
  _MobileColorOption('墨绿', 0xFF0F766E),
  _MobileColorOption('红', 0xFFD32F2F),
  _MobileColorOption('橙', 0xFFF57C00),
  _MobileColorOption('蓝', 0xFF1976D2),
  _MobileColorOption('紫', 0xFF7B1FA2),
  _MobileColorOption('岩灰', 0xFF455A64),
];

const List<_MobileBlockStyleOption> _kMobileBlockStyleOptions =
    <_MobileBlockStyleOption>[
  _MobileBlockStyleOption.heading('H1', 1),
  _MobileBlockStyleOption.heading('H2', 2),
  _MobileBlockStyleOption.heading('H3', 3),
  _MobileBlockStyleOption.heading('H4', 4),
  _MobileBlockStyleOption.heading('H5', 5),
  _MobileBlockStyleOption.heading('H6', 6),
  _MobileBlockStyleOption.paragraph('正文'),
];

const List<_MobileAlignmentOption> _kMobileAlignmentOptions =
    <_MobileAlignmentOption>[
  _MobileAlignmentOption('左对齐', WenzLucideToolbarIcons.alignLeft, 'left'),
  _MobileAlignmentOption('居中', WenzLucideToolbarIcons.alignCenter, 'center'),
  _MobileAlignmentOption('右对齐', WenzLucideToolbarIcons.alignRight, 'right'),
  _MobileAlignmentOption('两端', WenzLucideToolbarIcons.alignJustify, 'justify'),
  _MobileAlignmentOption('清除', WenzLucideToolbarIcons.removeFormat, null),
];

/// Host-owned resource actions surfaced by the mobile toolbar's insert section.
///
/// Mirrors [WenzDefaultDesktopToolbarActions] in shape but stays lightweight:
/// it reuses the desktop action callback/context types so a host can hand the
/// same resource handlers to both toolbars. The mobile toolbar only renders a
/// resource button when its callback is supplied.
@immutable
class WenzDefaultMobileToolbarActions {
  const WenzDefaultMobileToolbarActions({
    this.onInsertImage,
    this.onInsertVideo,
    this.onInsertFile,
    this.onInsertBlockEmbed,
    this.isPickingImage = false,
  });

  final WenzDefaultDesktopToolbarActionCallback? onInsertImage;
  final WenzDefaultDesktopToolbarActionCallback? onInsertVideo;
  final WenzDefaultDesktopToolbarActionCallback? onInsertFile;
  final WenzDefaultDesktopToolbarActionCallback? onInsertBlockEmbed;

  /// Whether an image pick/upload handoff is already in progress.
  final bool isPickingImage;
}

/// Material-ready mobile toolbar surface for [WenzRichTextController].
///
/// Like [WenzDefaultDesktopToolbar], this widget is lifecycle-neutral: it
/// receives an existing [controller] and [toolbar], reuses the same
/// [ToolbarController] and [WenzToolbarItemRegistry] (no parallel item
/// system), and never creates or disposes any controller. It is tuned for touch
/// — a single-row horizontally-scrolling primary rail of the most-used marks,
/// with a "更多" toggle that expands a second-level panel (颜色 / 对齐 / 块样式,
/// plus lists, quote, and insert actions).
///
/// Active state (bold / italic / todo / quote / …) is read from the shared
/// [ToolbarState] exactly as the desktop toolbar reads it, so the two toolbars
/// always agree. Sizes mirror EditorTokens.mobile, and the keyboard
/// strategy is controlled by [WenzMobileToolbarStyle.aboveKeyboard].
class WenzDefaultMobileToolbar extends StatefulWidget {
  const WenzDefaultMobileToolbar({
    super.key,
    required this.controller,
    required this.toolbar,
    this.toolbarItemRegistry,
    this.toolbarItems = const <WenzToolbarItem>[],
    this.includeRegistryItems = true,
    this.actions = const WenzDefaultMobileToolbarActions(),
    this.style = const WenzMobileToolbarStyle(),
  });

  /// Host-owned editor controller.
  final WenzRichTextController controller;

  /// Host-owned headless toolbar controller.
  final ToolbarController toolbar;

  /// Registry assembled by plugins and host configuration.
  final WenzToolbarItemRegistry? toolbarItemRegistry;

  /// Extra toolbar items supplied directly to this widget (override registry
  /// items with the same id).
  final Iterable<WenzToolbarItem> toolbarItems;

  /// Whether [toolbarItemRegistry] should contribute items.
  final bool includeRegistryItems;

  /// Optional host-owned resource actions for the insert section.
  final WenzDefaultMobileToolbarActions actions;

  /// Keyboard-collaboration strategy and chrome.
  final WenzMobileToolbarStyle style;

  /// Merged plugin/host toolbar descriptors in render order.
  List<WenzToolbarItem> get effectiveToolbarItems {
    final byId = <String, WenzToolbarItem>{};
    if (includeRegistryItems) {
      final registryItems =
          toolbarItemRegistry?.items ?? const <WenzToolbarItem>[];
      for (final item in registryItems) {
        byId[item.id] = item;
      }
    }
    for (final item in toolbarItems) {
      byId[item.id] = item;
    }
    final ordered = byId.values.toList()..sort(_compareToolbarItems);
    return List<WenzToolbarItem>.unmodifiable(ordered);
  }

  @override
  State<WenzDefaultMobileToolbar> createState() =>
      _WenzDefaultMobileToolbarState();

  static int _compareToolbarItems(WenzToolbarItem a, WenzToolbarItem b) {
    final byPriority = a.priority.compareTo(b.priority);
    if (byPriority != 0) {
      return byPriority;
    }
    return a.id.compareTo(b.id);
  }
}

class _WenzDefaultMobileToolbarState extends State<WenzDefaultMobileToolbar> {
  bool _expanded = false;

  Listenable get _rebuildListenable {
    final registry = widget.toolbarItemRegistry;
    if (!widget.includeRegistryItems || registry == null) {
      return widget.toolbar;
    }
    return Listenable.merge(<Listenable>[widget.toolbar, registry]);
  }

  WenzDefaultDesktopToolbarActionContext _actionContext(
    BuildContext buildContext,
  ) {
    return WenzDefaultDesktopToolbarActionContext(
      buildContext: buildContext,
      controller: widget.controller,
      toolbar: widget.toolbar,
      state: widget.toolbar.state,
    );
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    // Keyboard strategy: float the toolbar above the IME (padding up by the
    // keyboard height) when [WenzMobileToolbarStyle.aboveKeyboard]; otherwise
    // stay pinned at the host's layout position and let the resizing body
    // account for the keyboard.
    return Padding(
      padding: EdgeInsets.only(
        bottom: widget.style.aboveKeyboard ? viewInsetsBottom : 0,
      ),
      child: AnimatedBuilder(
        animation: _rebuildListenable,
        builder: (context, _) {
          final state = widget.toolbar.state;
          return Material(
            color: theme.colorScheme.surface,
            elevation: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildPrimaryRail(context, theme, state),
                if (_expanded) _buildExpandedPanel(context, theme, state),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- Primary rail: single-row horizontal scroll of the most-used actions ---

  Widget _buildPrimaryRail(
    BuildContext context,
    ThemeData theme,
    ToolbarState state,
  ) {
    final children = <Widget>[
      _MobileMarkButton(
        tooltip: '加粗',
        icon: WenzLucideToolbarIcons.bold,
        mark: TextMark.bold,
        toolbar: widget.toolbar,
        state: state,
      ),
      _MobileMarkButton(
        tooltip: '斜体',
        icon: WenzLucideToolbarIcons.italic,
        mark: TextMark.italic,
        toolbar: widget.toolbar,
        state: state,
      ),
      _MobileMarkButton(
        tooltip: '下划线',
        icon: WenzLucideToolbarIcons.underline,
        mark: TextMark.underline,
        toolbar: widget.toolbar,
        state: state,
      ),
      _MobileMarkButton(
        tooltip: '删除线',
        icon: WenzLucideToolbarIcons.strikethrough,
        mark: TextMark.lineThrough,
        toolbar: widget.toolbar,
        state: state,
      ),
      _MobileIconButton(
        tooltip: '任务列表',
        icon: WenzLucideToolbarIcons.taskList,
        selected: state.isTodo,
        enabled: state.canSetBlockType,
        onPressed: widget.toolbar.setTodo,
      ),
      _MobileIconButton(
        tooltip: '有序列表',
        icon: WenzLucideToolbarIcons.orderedList,
        selected: state.isOrderedList,
        enabled: state.canSetBlockType,
        onPressed: widget.toolbar.setOrderedList,
      ),
      _MobileIconButton(
        tooltip: '无序列表',
        icon: WenzLucideToolbarIcons.unorderedList,
        selected: state.isUnorderedList,
        enabled: state.canSetBlockType,
        onPressed: widget.toolbar.setUnorderedList,
      ),
      _MobileIconButton(
        tooltip: '撤销',
        icon: WenzLucideToolbarIcons.undo,
        enabled: state.canUndo,
        onPressed: widget.toolbar.undo,
      ),
      _MobileIconButton(
        tooltip: '重做',
        icon: WenzLucideToolbarIcons.redo,
        enabled: state.canRedo,
        onPressed: widget.toolbar.redo,
      ),
      _MobileIconButton(
        tooltip: _expanded ? '收起' : '更多',
        icon: _expanded
            ? WenzLucideToolbarIcons.chevronUp
            : WenzLucideToolbarIcons.chevronDown,
        selected: _expanded,
        enabled: true,
        onPressed: _toggleExpanded,
      ),
    ];
    return SizedBox(
      height: _kMobileToolbarButtonSize + _kMobileToolbarVerticalPadding * 2,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: _kMobileToolbarHorizontalPadding,
          vertical: _kMobileToolbarVerticalPadding,
        ),
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: _kMobileToolbarGap),
            children[i],
          ],
        ],
      ),
    );
  }

  // ---- Expanded panel: color / alignment / block style (+ lists/quote/insert)

  Widget _buildExpandedPanel(
    BuildContext context,
    ThemeData theme,
    ToolbarState state,
  ) {
    final extraItems = widget.effectiveToolbarItems;
    return Container(
      constraints: const BoxConstraints(maxHeight: _kMobilePanelMaxHeight),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: _kMobileToolbarHorizontalPadding,
          vertical: _kMobileToolbarVerticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PanelSection(
              label: '块样式',
              child: _BlockStyleRow(toolbar: widget.toolbar, state: state),
            ),
            _PanelSection(
              label: '对齐',
              child: _AlignmentRow(toolbar: widget.toolbar, state: state),
            ),
            _PanelSection(
              label: '颜色',
              child: _ColorRow(toolbar: widget.toolbar, state: state),
            ),
            _PanelSection(
              label: '段落',
              child: Wrap(
                spacing: _kMobileToolbarGap,
                runSpacing: _kMobileToolbarGap,
                children: <Widget>[
                  _MobileIconButton(
                    tooltip: '引用',
                    icon: WenzLucideToolbarIcons.quote,
                    selected: state.isQuoteBlock,
                    enabled: state.canToggleQuote,
                    onPressed: widget.toolbar.toggleQuoteBlock,
                  ),
                  _MobileIconButton(
                    tooltip: '清除样式',
                    icon: WenzLucideToolbarIcons.removeFormat,
                    enabled: state.canFormatInline,
                    onPressed: widget.toolbar.clearStyle,
                  ),
                ],
              ),
            ),
            _PanelSection(
              label: '插入',
              child: _InsertRow(
                controller: widget.controller,
                toolbar: widget.toolbar,
                actions: widget.actions,
                state: state,
                actionContext: _actionContext,
                onShowLinkDialog: () => _showLinkDialog(context, state),
              ),
            ),
            if (extraItems.isNotEmpty)
              _PanelSection(
                label: '扩展',
                child: Wrap(
                  spacing: _kMobileToolbarGap,
                  runSpacing: _kMobileToolbarGap,
                  children: <Widget>[
                    for (final item in extraItems)
                      _MobileRegistryItemButton(
                        item: item,
                        controller: widget.controller,
                        state: state,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLinkDialog(BuildContext context, ToolbarState state) async {
    final result = await showWenzLinkEditDialog(
      context: context,
      initialUrl: state.linkUrl ?? '',
      canRemove: state.linkUrl != null,
    );
    if (!mounted || result == null) {
      return;
    }
    widget.toolbar.setLink(result.isEmpty ? null : result);
  }
}

// ---- Section header ---------------------------------------------------------

class _PanelSection extends StatelessWidget {
  const _PanelSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: _kMobileToolbarVerticalPadding + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              left: 2,
              bottom: 4,
            ),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ---- Buttons ----------------------------------------------------------------

/// Token-sized IconButton used throughout the mobile toolbar. `selected`
/// reflects the active state sourced from [ToolbarState], matching the desktop
/// toolbar's highlight semantics.
class _MobileIconButton extends StatelessWidget {
  const _MobileIconButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.selected = false,
    this.iconColor,
    this.iconWidget,
  });

  final String tooltip;
  final String icon;
  final bool enabled;
  final bool selected;
  final Color? iconColor;
  final Widget? iconWidget;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      iconSize: _kMobileToolbarIconSize,
      isSelected: selected,
      style: _mobileButtonStyle(theme),
      onPressed: enabled ? onPressed : null,
      icon: iconWidget ??
          WenzLucideToolbarIcon(
            icon,
            color: enabled ? iconColor : null,
            enabled: enabled,
          ),
    );
  }
}

class _MobileMarkButton extends StatelessWidget {
  const _MobileMarkButton({
    required this.tooltip,
    required this.icon,
    required this.mark,
    required this.toolbar,
    required this.state,
  });

  final String tooltip;
  final String icon;
  final TextMark mark;
  final ToolbarController toolbar;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    return _MobileIconButton(
      tooltip: tooltip,
      icon: icon,
      selected: state.isMarkActive(mark),
      enabled: state.canToggleMark,
      onPressed: () => toolbar.toggleMark(mark),
    );
  }
}

class _MobileRegistryItemButton extends StatelessWidget {
  const _MobileRegistryItemButton({
    required this.item,
    required this.controller,
    required this.state,
  });

  final WenzToolbarItem item;
  final WenzRichTextController controller;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    return _MobileIconButton(
      tooltip: item.tooltip ?? item.title,
      icon: _mobileToolbarItemIcon(item.icon),
      selected: item.activeFor(state),
      enabled: item.enabledFor(state),
      onPressed: () => item.action(controller, state),
    );
  }
}

// ---- Expanded-panel rows ----------------------------------------------------

class _BlockStyleRow extends StatelessWidget {
  const _BlockStyleRow({required this.toolbar, required this.state});

  final ToolbarController toolbar;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _kMobileToolbarGap,
      runSpacing: _kMobileToolbarGap,
      children: <Widget>[
        for (final option in _kMobileBlockStyleOptions)
          _BlockStyleChip(
            option: option,
            selected: option.isActive(state),
            enabled: state.canSetBlockType,
            onPressed: () => option.apply(toolbar),
          ),
      ],
    );
  }
}

class _BlockStyleChip extends StatelessWidget {
  const _BlockStyleChip({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final _MobileBlockStyleOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        minimumSize: const Size.square(_kMobileToolbarButtonSize),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kMobileToolbarRadius),
        ),
        backgroundColor: selected ? colorScheme.primaryContainer : null,
        foregroundColor: selected
            ? colorScheme.onPrimaryContainer
            : (enabled
                ? colorScheme.onSurfaceVariant
                : colorScheme.onSurface.withAlpha(96)),
      ),
      child: Text(option.label),
    );
  }
}

class _AlignmentRow extends StatelessWidget {
  const _AlignmentRow({required this.toolbar, required this.state});

  final ToolbarController toolbar;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _kMobileToolbarGap,
      runSpacing: _kMobileToolbarGap,
      children: <Widget>[
        for (final option in _kMobileAlignmentOptions)
          _MobileIconButton(
            tooltip: option.label,
            icon: option.icon,
            selected: !state.alignmentMixed && option.alignment == state.alignment,
            enabled: state.canSetAlignment,
            onPressed: () => option.apply(toolbar),
          ),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.toolbar, required this.state});

  final ToolbarController toolbar;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = state.textColor;
    return Wrap(
      spacing: _kMobileToolbarGap,
      runSpacing: _kMobileToolbarGap,
      children: <Widget>[
        for (final option in _kMobileColorOptions)
          _ColorSwatchButton(
            color: option.color,
            selected: current == option.colorValue && !state.textColorMixed,
            enabled: state.canFormatInline,
            outlineColor: theme.colorScheme.outline,
            onPressed: () => toolbar.setTextColorValue(option.colorValue),
          ),
        _MobileIconButton(
          tooltip: '清除文字颜色',
          icon: WenzLucideToolbarIcons.clearTextColor,
          iconColor: current == null ? null : Color(current),
          enabled: state.canFormatInline,
          onPressed: toolbar.clearTextColor,
        ),
      ],
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.color,
    required this.selected,
    required this.enabled,
    required this.outlineColor,
    required this.onPressed,
  });

  final Color color;
  final bool selected;
  final bool enabled;
  final Color outlineColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '文字颜色',
      iconSize: _kMobileToolbarIconSize,
      isSelected: selected,
      style: _mobileButtonStyle(Theme.of(context)),
      onPressed: enabled ? onPressed : null,
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: outlineColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: const SizedBox.square(dimension: _kMobileToolbarIconSize),
      ),
    );
  }
}

class _InsertRow extends StatelessWidget {
  const _InsertRow({
    required this.controller,
    required this.toolbar,
    required this.actions,
    required this.state,
    required this.actionContext,
    required this.onShowLinkDialog,
  });

  final WenzRichTextController controller;
  final ToolbarController toolbar;
  final WenzDefaultMobileToolbarActions actions;
  final ToolbarState state;
  final WenzDefaultDesktopToolbarActionContext Function(BuildContext)
      actionContext;
  final Future<void> Function() onShowLinkDialog;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _MobileIconButton(
        tooltip: state.linkUrl == null ? '添加链接' : '编辑链接',
        icon: WenzLucideToolbarIcons.link,
        selected: state.linkUrl != null,
        enabled: state.canSetLink,
        onPressed: onShowLinkDialog,
      ),
      _MobileIconButton(
        tooltip: '公式',
        icon: WenzLucideToolbarIcons.formula,
        enabled: state.canFormatInline,
        onPressed: () => controller.insertFormula(''),
      ),
      _MobileIconButton(
        tooltip: '代码块',
        icon: WenzLucideToolbarIcons.code,
        enabled: toolbar.canInsertBlock,
        onPressed: () => toolbar.insertCodeBlock(),
      ),
      _MobileIconButton(
        tooltip: '标注',
        icon: WenzLucideToolbarIcons.callout,
        enabled: toolbar.canInsertBlock,
        onPressed: () => toolbar.insertCallout(),
      ),
      _MobileIconButton(
        tooltip: '表格',
        icon: WenzLucideToolbarIcons.table,
        enabled: toolbar.canInsertBlock,
        onPressed: () => toolbar.insertTable(),
      ),
      if (actions.onInsertImage != null)
        _MobileIconButton(
          tooltip: actions.isPickingImage ? '正在选择图片' : '插入图片',
          icon: WenzLucideToolbarIcons.image,
          iconWidget: actions.isPickingImage
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          enabled: !actions.isPickingImage && toolbar.canInsertImage,
          onPressed: () =>
              _run(actions.onInsertImage!(actionContext(context))),
        ),
      if (actions.onInsertVideo != null)
        _MobileIconButton(
          tooltip: '插入视频',
          icon: WenzLucideToolbarIcons.video,
          enabled: toolbar.canInsertVideo,
          onPressed: () =>
              _run(actions.onInsertVideo!(actionContext(context))),
        ),
      if (actions.onInsertFile != null)
        _MobileIconButton(
          tooltip: '插入文件',
          icon: WenzLucideToolbarIcons.file,
          enabled: controller.canEdit,
          onPressed: () =>
              _run(actions.onInsertFile!(actionContext(context))),
        ),
      if (actions.onInsertBlockEmbed != null)
        _MobileIconButton(
          tooltip: '业务嵌入',
          icon: WenzLucideToolbarIcons.badge,
          enabled: controller.canEdit,
          onPressed: () =>
              _run(actions.onInsertBlockEmbed!(actionContext(context))),
        ),
    ];
    return Wrap(
      spacing: _kMobileToolbarGap,
      runSpacing: _kMobileToolbarGap,
      children: children,
    );
  }
}

void _run(FutureOr<void> result) {
  if (result is Future<void>) {
    unawaited(result);
  }
}

// ---- Option data + style helpers -------------------------------------------

class _MobileColorOption {
  const _MobileColorOption(this.label, this.colorValue);

  final String label;
  final int colorValue;

  Color get color => Color(colorValue);
}

class _MobileBlockStyleOption {
  const _MobileBlockStyleOption.heading(this.label, this.headingLevel);

  const _MobileBlockStyleOption.paragraph(this.label) : headingLevel = null;

  final String label;
  final int? headingLevel;

  bool isActive(ToolbarState state) {
    final level = headingLevel;
    return level == null ? state.isParagraph : state.isHeading(level);
  }

  void apply(ToolbarController toolbar) {
    final level = headingLevel;
    if (level == null) {
      toolbar.setParagraph();
    } else {
      toolbar.setHeading(level);
    }
  }
}

class _MobileAlignmentOption {
  const _MobileAlignmentOption(this.label, this.icon, this.alignment);

  final String label;
  final String icon;
  final String? alignment;

  void apply(ToolbarController toolbar) => toolbar.setAlignment(alignment);
}

ButtonStyle _mobileButtonStyle(ThemeData theme) {
  final colorScheme = theme.colorScheme;
  return IconButton.styleFrom(
    minimumSize: const Size.square(_kMobileToolbarButtonSize),
    fixedSize: const Size.square(_kMobileToolbarButtonSize),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    foregroundColor: colorScheme.onSurfaceVariant,
    disabledForegroundColor: colorScheme.onSurface.withAlpha(96),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_kMobileToolbarRadius),
    ),
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.onSurface.withAlpha(96);
      }
      if (states.contains(WidgetState.selected)) {
        return colorScheme.onPrimaryContainer;
      }
      return colorScheme.onSurfaceVariant;
    }),
    backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.transparent;
      }
      if (states.contains(WidgetState.selected)) {
        return colorScheme.primaryContainer;
      }
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.surfaceContainerHighest;
      }
      return Colors.transparent;
    }),
  );
}

/// Maps a plugin/host [WenzToolbarItem.icon] string to the shared Lucide
/// toolbar icon name so a shared registry renders the same glyph on both
/// surfaces.
String _mobileToolbarItemIcon(String? icon) => wenzLucideToolbarIconName(icon);

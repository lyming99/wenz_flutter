import 'dart:async';

import 'package:flutter/material.dart';

import '../controller/toolbar_controller.dart';
import '../controller/wenz_rich_text_controller.dart';
import '../core/commands/inline_editing.dart';
import 'link_edit_dialog.dart';
import 'lucide_toolbar_icons.dart';

const double _kToolbarHorizontalPadding = 12.0;
const double _kToolbarVerticalPadding = 8.0;
const double _kToolbarSpacing = 6.0;
const double _kToolbarButtonExtent = 34.0;
const double _kToolbarIconSize = 19.0;
const double _kToolbarRadius = 6.0;
const double _kToolbarDividerWidth = 8.0;
const double _kToolbarDividerHeight = 18.0;
const double _kBlockStyleButtonWidth = 92.0;
const double _kAlignmentButtonWidth = 112.0;
const double _kToolbarMenuPanelPadding = 6.0;
const double _kToolbarMenuItemHeight = 36.0;
const double _kToolbarMenuPanelRadius = 10.0;
const double _kToolbarMenuItemRadius = 8.0;
const double _kBlockStyleMenuWidth = 152.0;
const double _kAlignmentMenuWidth = 176.0;
const double _kTextColorMenuWidth = 208.0;
const double _kInsertMenuWidth = 216.0;

const List<_BlockStyleOption> _kBlockStyleOptions = <_BlockStyleOption>[
  _BlockStyleOption.heading('H1', 1),
  _BlockStyleOption.heading('H2', 2),
  _BlockStyleOption.heading('H3', 3),
  _BlockStyleOption.heading('H4', 4),
  _BlockStyleOption.heading('H5', 5),
  _BlockStyleOption.heading('H6', 6),
  _BlockStyleOption.paragraph('正文'),
];

const List<_AlignmentOption> _kAlignmentOptions = <_AlignmentOption>[
  _AlignmentOption('左对齐', WenzLucideToolbarIcons.alignLeft, 'left'),
  _AlignmentOption('居中对齐', WenzLucideToolbarIcons.alignCenter, 'center'),
  _AlignmentOption('右对齐', WenzLucideToolbarIcons.alignRight, 'right'),
  _AlignmentOption('两端对齐', WenzLucideToolbarIcons.alignJustify, 'justify'),
  _AlignmentOption('清除对齐', WenzLucideToolbarIcons.removeFormat, null),
];

const List<_ToolbarColorOption> _kTextColorOptions = <_ToolbarColorOption>[
  _ToolbarColorOption('Default green', 0xFF0F766E),
  _ToolbarColorOption('Red', 0xFFD32F2F),
  _ToolbarColorOption('Orange', 0xFFF57C00),
  _ToolbarColorOption('Blue', 0xFF1976D2),
  _ToolbarColorOption('Purple', 0xFF7B1FA2),
  _ToolbarColorOption('Slate', 0xFF455A64),
];

/// Visual switches for [WenzDefaultDesktopToolbar].
@immutable
class WenzDefaultDesktopToolbarStyle {
  const WenzDefaultDesktopToolbarStyle({
    this.showBackground = true,
    this.showBottomBorder = true,
    this.showGroupDividers = true,
    this.padding = const EdgeInsets.symmetric(
      horizontal: _kToolbarHorizontalPadding,
      vertical: _kToolbarVerticalPadding,
    ),
  });

  /// Whether the toolbar paints its themed surface background.
  final bool showBackground;

  /// Whether the toolbar paints a bottom outline separator.
  final bool showBottomBorder;

  /// Whether button groups are separated by vertical dividers.
  final bool showGroupDividers;

  /// Outer toolbar padding.
  final EdgeInsetsGeometry padding;
}

/// Callback used by host-owned resource actions in
/// [WenzDefaultDesktopToolbarActions].
///
/// The default toolbar owns only UI and state binding. Resource acquisition
/// such as file picking, upload orchestration, and business embed creation
/// stays in the host app and is invoked through this callback.
typedef WenzDefaultDesktopToolbarActionCallback = FutureOr<void> Function(
  WenzDefaultDesktopToolbarActionContext context,
);

/// What the default toolbar should do when a resource action has no callback.
enum WenzDefaultDesktopToolbarUnavailablePolicy {
  /// Do not render the button when the matching callback is absent.
  hide,

  /// Render the button disabled when the matching callback is absent.
  disable,
}

/// Runtime context passed to resource action callbacks.
@immutable
class WenzDefaultDesktopToolbarActionContext {
  const WenzDefaultDesktopToolbarActionContext({
    required this.buildContext,
    required this.controller,
    required this.toolbar,
    required this.state,
  });

  /// Build context of the toolbar button that invoked the action.
  final BuildContext buildContext;

  /// Host-owned editor controller. The toolbar never creates or disposes it.
  final WenzRichTextController controller;

  /// Host-owned toolbar controller. The toolbar never creates or disposes it.
  final ToolbarController toolbar;

  /// Toolbar state snapshot captured at action invocation time.
  final ToolbarState state;
}

/// Host-owned resource actions surfaced by [WenzDefaultDesktopToolbar].
///
/// Formatting and structure commands that need no business resource can be
/// implemented directly by the default toolbar. Actions that require host
/// policy, such as picking or uploading an image/video/file, stay optional
/// here. If a callback is omitted, helper methods below report the button as
/// hidden or disabled according to the matching unavailable policy and never
/// invoke a no-op insertion.
@immutable
class WenzDefaultDesktopToolbarActions {
  const WenzDefaultDesktopToolbarActions({
    this.onInsertImage,
    this.onInsertVideo,
    this.onInsertFile,
    this.onInsertBlockEmbed,
    this.isPickingImage = false,
    this.imageUnavailablePolicy =
        WenzDefaultDesktopToolbarUnavailablePolicy.hide,
    this.videoUnavailablePolicy =
        WenzDefaultDesktopToolbarUnavailablePolicy.hide,
    this.fileUnavailablePolicy =
        WenzDefaultDesktopToolbarUnavailablePolicy.hide,
    this.blockEmbedUnavailablePolicy =
        WenzDefaultDesktopToolbarUnavailablePolicy.hide,
  });

  /// Host callback for inserting an image block.
  final WenzDefaultDesktopToolbarActionCallback? onInsertImage;

  /// Host callback for inserting a video block.
  final WenzDefaultDesktopToolbarActionCallback? onInsertVideo;

  /// Host callback for inserting a file block.
  final WenzDefaultDesktopToolbarActionCallback? onInsertFile;

  /// Host callback for inserting a business block embed.
  final WenzDefaultDesktopToolbarActionCallback? onInsertBlockEmbed;

  /// Whether an image picker/upload handoff is already in progress.
  ///
  /// Future toolbar rendering uses this to disable the image action and show a
  /// pending affordance instead of triggering duplicate host pickers.
  final bool isPickingImage;

  /// Display policy when [onInsertImage] is absent.
  final WenzDefaultDesktopToolbarUnavailablePolicy imageUnavailablePolicy;

  /// Display policy when [onInsertVideo] is absent.
  final WenzDefaultDesktopToolbarUnavailablePolicy videoUnavailablePolicy;

  /// Display policy when [onInsertFile] is absent.
  final WenzDefaultDesktopToolbarUnavailablePolicy fileUnavailablePolicy;

  /// Display policy when [onInsertBlockEmbed] is absent.
  final WenzDefaultDesktopToolbarUnavailablePolicy blockEmbedUnavailablePolicy;

  bool get shouldShowImageButton =>
      _shouldShow(onInsertImage, imageUnavailablePolicy);

  bool get shouldShowVideoButton =>
      _shouldShow(onInsertVideo, videoUnavailablePolicy);

  bool get shouldShowFileButton =>
      _shouldShow(onInsertFile, fileUnavailablePolicy);

  bool get shouldShowBlockEmbedButton =>
      _shouldShow(onInsertBlockEmbed, blockEmbedUnavailablePolicy);

  bool get isImagePending => onInsertImage != null && isPickingImage;

  bool canInsertImage(ToolbarController toolbar) {
    return onInsertImage != null && !isImagePending && toolbar.canInsertImage;
  }

  bool canInsertVideo(ToolbarController toolbar) {
    return onInsertVideo != null && toolbar.canInsertVideo;
  }

  bool canInsertFile(WenzRichTextController controller) {
    return onInsertFile != null && controller.canEdit;
  }

  bool canInsertBlockEmbed(WenzRichTextController controller) {
    return onInsertBlockEmbed != null && controller.canEdit;
  }

  FutureOr<void> insertImage(
    WenzDefaultDesktopToolbarActionContext context,
  ) {
    if (!canInsertImage(context.toolbar)) {
      return Future<void>.value();
    }
    return onInsertImage!(context);
  }

  FutureOr<void> insertVideo(
    WenzDefaultDesktopToolbarActionContext context,
  ) {
    if (!canInsertVideo(context.toolbar)) {
      return Future<void>.value();
    }
    return onInsertVideo!(context);
  }

  FutureOr<void> insertFile(
    WenzDefaultDesktopToolbarActionContext context,
  ) {
    if (!canInsertFile(context.controller)) {
      return Future<void>.value();
    }
    return onInsertFile!(context);
  }

  FutureOr<void> insertBlockEmbed(
    WenzDefaultDesktopToolbarActionContext context,
  ) {
    if (!canInsertBlockEmbed(context.controller)) {
      return Future<void>.value();
    }
    return onInsertBlockEmbed!(context);
  }

  static bool _shouldShow(
    WenzDefaultDesktopToolbarActionCallback? action,
    WenzDefaultDesktopToolbarUnavailablePolicy policy,
  ) {
    return action != null ||
        policy == WenzDefaultDesktopToolbarUnavailablePolicy.disable;
  }
}

/// Public Material-ready desktop toolbar surface for [WenzRichTextController].
///
/// The widget is intentionally lifecycle-neutral: it receives an existing
/// [controller], an existing [toolbar], and optional plugin/host toolbar item
/// descriptors, but it never creates or disposes any controller.
class WenzDefaultDesktopToolbar extends StatelessWidget {
  const WenzDefaultDesktopToolbar({
    super.key,
    required this.controller,
    required this.toolbar,
    this.toolbarItemRegistry,
    this.toolbarItems = const <WenzToolbarItem>[],
    this.includeRegistryItems = true,
    this.actions = const WenzDefaultDesktopToolbarActions(),
    this.style = const WenzDefaultDesktopToolbarStyle(),
  });

  /// Host-owned editor controller.
  final WenzRichTextController controller;

  /// Host-owned headless toolbar controller.
  final ToolbarController toolbar;

  /// Registry assembled by plugins and host configuration.
  final WenzToolbarItemRegistry? toolbarItemRegistry;

  /// Extra toolbar items supplied directly to this widget.
  ///
  /// Items here override registry items with the same id and are sorted with
  /// the same priority/id rule as [WenzToolbarItemRegistry.items].
  final Iterable<WenzToolbarItem> toolbarItems;

  /// Whether [toolbarItemRegistry] should contribute items.
  final bool includeRegistryItems;

  /// Optional host-owned resource actions.
  final WenzDefaultDesktopToolbarActions actions;

  /// Visual switches for the default toolbar chrome.
  final WenzDefaultDesktopToolbarStyle style;

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

  /// Creates the callback context used by resource actions.
  WenzDefaultDesktopToolbarActionContext actionContext(
    BuildContext buildContext,
  ) {
    return WenzDefaultDesktopToolbarActionContext(
      buildContext: buildContext,
      controller: controller,
      toolbar: toolbar,
      state: toolbar.state,
    );
  }

  Listenable get _rebuildListenable {
    final registry = toolbarItemRegistry;
    if (!includeRegistryItems || registry == null) {
      return toolbar;
    }
    return Listenable.merge(<Listenable>[toolbar, registry]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _rebuildListenable,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final state = toolbar.state;
        final extraItems = effectiveToolbarItems;
        final toolbarChildren = <Widget>[
          _MarkButton(
            tooltip: '加粗',
            icon: WenzLucideToolbarIcons.bold,
            mark: TextMark.bold,
            toolbar: toolbar,
            state: state,
          ),
          _MarkButton(
            tooltip: '斜体',
            icon: WenzLucideToolbarIcons.italic,
            mark: TextMark.italic,
            toolbar: toolbar,
            state: state,
          ),
          _MarkButton(
            tooltip: '下划线',
            icon: WenzLucideToolbarIcons.underline,
            mark: TextMark.underline,
            toolbar: toolbar,
            state: state,
          ),
          _MarkButton(
            tooltip: '删除线',
            icon: WenzLucideToolbarIcons.strikethrough,
            mark: TextMark.lineThrough,
            toolbar: toolbar,
            state: state,
          ),
          _TextColorMenuButton(
            toolbar: toolbar,
            state: state,
          ),
          _ToolbarIconButton(
            tooltip: _clearTextColorTooltip(state),
            icon: WenzLucideToolbarIcons.clearTextColor,
            enabled: state.canFormatInline,
            iconColor: state.textColor == null
                ? null
                : Color(state.textColor!),
            onPressed: toolbar.clearTextColor,
          ),
          _ToolbarIconButton(
            tooltip: '清除样式',
            icon: WenzLucideToolbarIcons.removeFormat,
            enabled: state.canFormatInline,
            onPressed: toolbar.clearStyle,
          ),
          _ToolbarDivider(visible: style.showGroupDividers),
          _BlockStyleMenuButton(
            toolbar: toolbar,
            state: state,
          ),
          _BlockTypeButton(
            tooltip: '引用',
            icon: WenzLucideToolbarIcons.quote,
            selected: state.isQuoteBlock,
            enabled: state.canToggleQuote,
            onPressed: toolbar.toggleQuoteBlock,
          ),
          _BlockTypeButton(
            tooltip: '任务列表',
            icon: WenzLucideToolbarIcons.taskList,
            selected: state.isTodo,
            enabled: state.canSetBlockType,
            onPressed: toolbar.setTodo,
          ),
          _BlockTypeButton(
            tooltip: '有序列表',
            icon: WenzLucideToolbarIcons.orderedList,
            selected: state.isOrderedList,
            enabled: state.canSetBlockType,
            onPressed: toolbar.setOrderedList,
          ),
          if (state.canTableStruct) ...<Widget>[
            _ToolbarDivider(visible: style.showGroupDividers),
            _ToolbarIconButton(
              tooltip: '下方插入行',
              icon: WenzLucideToolbarIcons.tableRowInsert,
              enabled: state.canTableStruct,
              onPressed: toolbar.insertTableRow,
            ),
            _ToolbarIconButton(
              tooltip: '右侧插入列',
              icon: WenzLucideToolbarIcons.tableColumnInsert,
              enabled: state.canTableStruct,
              onPressed: toolbar.insertTableColumn,
            ),
            _ToolbarIconButton(
              tooltip: '删除行',
              icon: WenzLucideToolbarIcons.tableDelete,
              enabled: state.canTableStruct,
              onPressed: toolbar.deleteTableRow,
            ),
            _ToolbarIconButton(
              tooltip: '删除列',
              icon: WenzLucideToolbarIcons.tableDelete,
              enabled: state.canTableStruct,
              onPressed: toolbar.deleteTableColumn,
            ),
            _ToolbarIconButton(
              tooltip: '合并单元格',
              icon: WenzLucideToolbarIcons.tableMerge,
              enabled: state.canTableStruct,
              onPressed: toolbar.mergeTableCells,
            ),
            _ToolbarIconButton(
              tooltip: '拆分单元格',
              icon: WenzLucideToolbarIcons.tableSplit,
              enabled: state.canTableStruct,
              onPressed: toolbar.splitTableCell,
            ),
          ],
          if (extraItems.isNotEmpty) ...<Widget>[
            _ToolbarDivider(visible: style.showGroupDividers),
            for (final item in extraItems)
              _RegistryToolbarItemButton(
                item: item,
                controller: controller,
                state: state,
              ),
          ],
          _BlockTypeButton(
            tooltip: '无序列表',
            icon: WenzLucideToolbarIcons.unorderedList,
            selected: state.isUnorderedList,
            enabled: state.canSetBlockType,
            onPressed: toolbar.setUnorderedList,
          ),
          _ToolbarDivider(
            visible: style.showGroupDividers,
            preserveWidth: true,
          ),
          _AlignmentMenuButton(
            toolbar: toolbar,
            state: state,
          ),
          _ToolbarDivider(
            visible: style.showGroupDividers,
            preserveWidth: true,
          ),
          _InsertMenuButton(
            controller: controller,
            toolbar: toolbar,
            actions: actions,
            state: state,
            actionContext: actionContext,
            onShowLinkDialog: () => _showLinkDialog(context, state),
          ),
        ];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: style.showBackground ? colorScheme.surface : null,
            border: Border(
              bottom: style.showBottomBorder
                  ? BorderSide(color: colorScheme.outlineVariant)
                  : BorderSide.none,
            ),
          ),
          child: Padding(
            padding: style.padding,
            child: _DefaultDesktopToolbarLayout(
              children: toolbarChildren,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLinkDialog(
    BuildContext context,
    ToolbarState state,
  ) async {
    final result = await showWenzLinkEditDialog(
      context: context,
      initialUrl: state.linkUrl ?? '',
      canRemove: state.linkUrl != null,
    );
    if (!context.mounted || result == null) {
      return;
    }
    toolbar.setLink(result.isEmpty ? null : result);
  }

  static int _compareToolbarItems(WenzToolbarItem a, WenzToolbarItem b) {
    final byPriority = a.priority.compareTo(b.priority);
    if (byPriority != 0) {
      return byPriority;
    }
    return a.id.compareTo(b.id);
  }
}

class _DefaultDesktopToolbarLayout extends StatelessWidget {
  const _DefaultDesktopToolbarLayout({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          for (var index = 0; index < children.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: _kToolbarSpacing),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.selected = false,
    this.iconColor,
  });

  final String tooltip;
  final String icon;
  final bool enabled;
  final bool selected;
  final Color? iconColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      iconSize: _kToolbarIconSize,
      isSelected: selected,
      style: _toolbarButtonStyle(theme),
      onPressed: enabled ? onPressed : null,
      icon: WenzLucideToolbarIcon(
        icon,
        color: enabled ? iconColor : null,
        enabled: enabled,
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
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
    return _ToolbarIconButton(
      tooltip: tooltip,
      icon: icon,
      selected: state.isMarkActive(mark),
      enabled: state.canToggleMark,
      onPressed: () => toolbar.toggleMark(mark),
    );
  }
}

class _BlockStyleMenuButton extends StatelessWidget {
  const _BlockStyleMenuButton({
    required this.toolbar,
    required this.state,
  });

  final ToolbarController toolbar;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _blockStyleLabel(state);
    final tooltip = _blockStyleTooltip(state);
    final isExplicitStyle = _isExplicitBlockStyle(state);
    return MenuAnchor(
      style: _toolbarMenuPanelStyle(
        context,
        width: _kBlockStyleMenuWidth,
      ),
      menuChildren: _kBlockStyleOptions.map((option) {
        final active = option.isActive(state);
        return MenuItemButton(
          closeOnActivate: true,
          style: _toolbarMenuItemStyle(
            context,
            width: _kBlockStyleMenuWidth,
          ),
          onPressed: state.canSetBlockType ? () => option.apply(toolbar) : null,
          child: SizedBox(
            width: _toolbarMenuContentWidth(_kBlockStyleMenuWidth),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(option.label)),
                if (active)
                  const WenzLucideToolbarIcon(
                    WenzLucideToolbarIcons.check,
                    size: 18,
                  ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
      builder: (context, menuController, _) {
        return Tooltip(
          message: tooltip,
          child: TextButton(
            style: _blockStyleButtonStyle(
              theme,
              muted: !isExplicitStyle,
            ),
            onPressed: state.canSetBlockType
                ? () {
                    if (menuController.isOpen) {
                      menuController.close();
                    } else {
                      menuController.open();
                    }
                  }
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 2),
                const WenzLucideToolbarIcon(
                  WenzLucideToolbarIcons.chevronDown,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BlockTypeButton extends StatelessWidget {
  const _BlockTypeButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final String icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      tooltip: tooltip,
      icon: icon,
      selected: selected,
      enabled: enabled,
      onPressed: onPressed,
    );
  }
}

class _AlignmentMenuButton extends StatelessWidget {
  const _AlignmentMenuButton({
    required this.toolbar,
    required this.state,
  });

  final ToolbarController toolbar;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeOption = _activeAlignmentOption(state);
    final label = _alignmentLabel(state);
    final tooltip = _alignmentTooltip(state);
    final icon = state.alignmentMixed
        ? WenzLucideToolbarIcons.alignLeft
        : activeOption.icon;
    return MenuAnchor(
      style: _toolbarMenuPanelStyle(
        context,
        width: _kAlignmentMenuWidth,
      ),
      menuChildren: _kAlignmentOptions.map((option) {
        final active =
            !state.alignmentMixed && option.alignment == state.alignment;
        return MenuItemButton(
          closeOnActivate: true,
          style: _toolbarMenuItemStyle(
            context,
            width: _kAlignmentMenuWidth,
          ),
          onPressed:
              state.canSetAlignment ? () => option.apply(toolbar) : null,
          child: SizedBox(
            width: _toolbarMenuContentWidth(_kAlignmentMenuWidth),
            child: Row(
              children: <Widget>[
                WenzLucideToolbarIcon(option.icon, size: _kToolbarIconSize),
                const SizedBox(width: 10),
                Expanded(child: Text(option.label)),
                if (active)
                  const WenzLucideToolbarIcon(
                    WenzLucideToolbarIcons.check,
                    size: 18,
                  ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
      builder: (context, menuController, _) {
        return Tooltip(
          message: tooltip,
          child: TextButton(
            style: _toolbarTextButtonStyle(
              theme,
              width: _kAlignmentButtonWidth,
            ),
            onPressed: state.canSetAlignment
                ? () {
                    if (menuController.isOpen) {
                      menuController.close();
                    } else {
                      menuController.open();
                    }
                  }
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                WenzLucideToolbarIcon(icon, size: _kToolbarIconSize),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 2),
                const WenzLucideToolbarIcon(
                  WenzLucideToolbarIcons.chevronDown,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InsertMenuButton extends StatelessWidget {
  const _InsertMenuButton({
    required this.controller,
    required this.toolbar,
    required this.actions,
    required this.state,
    required this.actionContext,
    required this.onShowLinkDialog,
  });

  final WenzRichTextController controller;
  final ToolbarController toolbar;
  final WenzDefaultDesktopToolbarActions actions;
  final ToolbarState state;
  final WenzDefaultDesktopToolbarActionContext Function(BuildContext)
      actionContext;
  final Future<void> Function() onShowLinkDialog;

  @override
  Widget build(BuildContext context) {
    final hasResourceActions = actions.shouldShowImageButton ||
        actions.shouldShowVideoButton ||
        actions.shouldShowFileButton ||
        actions.shouldShowBlockEmbedButton;
    final menuChildren = <Widget>[
      _InsertMenuItem(
        label: state.linkUrl == null ? '添加链接' : '编辑链接',
        icon: WenzLucideToolbarIcons.link,
        selected: state.linkUrl != null,
        enabled: state.canSetLink,
        action: onShowLinkDialog,
      ),
      _InsertMenuItem(
        label: '公式',
        icon: WenzLucideToolbarIcons.formula,
        enabled: state.canFormatInline,
        action: () {
          controller.insertFormula('');
        },
      ),
      const Divider(height: 1),
      _InsertMenuItem(
        label: '插入代码块',
        icon: WenzLucideToolbarIcons.code,
        enabled: toolbar.canInsertBlock,
        action: () => toolbar.insertCodeBlock(),
      ),
      _InsertMenuItem(
        label: '插入标注',
        icon: WenzLucideToolbarIcons.callout,
        enabled: toolbar.canInsertBlock,
        action: () => toolbar.insertCallout(),
      ),
      _InsertMenuItem(
        label: '插入表格',
        icon: WenzLucideToolbarIcons.table,
        enabled: toolbar.canInsertBlock,
        action: () => toolbar.insertTable(),
      ),
      if (hasResourceActions) const Divider(height: 1),
      if (actions.shouldShowImageButton)
        _InsertMenuItem(
          label: actions.isImagePending
              ? '正在选择图片'
              : _resourceTooltip('插入图片', actions.onInsertImage),
          icon: WenzLucideToolbarIcons.image,
          iconWidget: actions.isImagePending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          enabled: actions.canInsertImage(toolbar),
          action: () => actions.insertImage(actionContext(context)),
        ),
      if (actions.shouldShowVideoButton)
        _InsertMenuItem(
          label: _resourceTooltip('插入视频', actions.onInsertVideo),
          icon: WenzLucideToolbarIcons.video,
          enabled: actions.canInsertVideo(toolbar),
          action: () => actions.insertVideo(actionContext(context)),
        ),
      if (actions.shouldShowFileButton)
        _InsertMenuItem(
          label: _resourceTooltip('插入文件', actions.onInsertFile),
          icon: WenzLucideToolbarIcons.file,
          enabled: actions.canInsertFile(controller),
          action: () => actions.insertFile(actionContext(context)),
        ),
      if (actions.shouldShowBlockEmbedButton)
        _InsertMenuItem(
          label: _resourceTooltip('插入业务嵌入', actions.onInsertBlockEmbed),
          icon: WenzLucideToolbarIcons.badge,
          enabled: actions.canInsertBlockEmbed(controller),
          action: () => actions.insertBlockEmbed(actionContext(context)),
        ),
    ];

    return MenuAnchor(
      style: _toolbarMenuPanelStyle(context, width: _kInsertMenuWidth),
      menuChildren: menuChildren,
      builder: (context, menuController, _) {
        return _ToolbarIconButton(
          tooltip: '插入元素',
          icon: WenzLucideToolbarIcons.insert,
          selected: menuController.isOpen,
          enabled: true,
          onPressed: () {
            if (menuController.isOpen) {
              menuController.close();
            } else {
              menuController.open();
            }
          },
        );
      },
    );
  }
}

class _InsertMenuItem extends StatelessWidget {
  const _InsertMenuItem({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.action,
    this.selected = false,
    this.iconWidget,
  });

  final String label;
  final String icon;
  final bool enabled;
  final bool selected;
  final Widget? iconWidget;
  final FutureOr<void> Function() action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = enabled
        ? _toolbarMenuMutedColor(theme)
        : _toolbarMenuFaintColor(theme).withAlpha(148);
    return MenuItemButton(
      closeOnActivate: true,
      style: _toolbarMenuItemStyle(context, width: _kInsertMenuWidth),
      onPressed: enabled ? () => _runToolbarAction(action()) : null,
      child: SizedBox(
        width: _toolbarMenuContentWidth(_kInsertMenuWidth),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 20,
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: iconColor,
                    size: _kToolbarIconSize,
                  ),
                  child: iconWidget ?? WenzLucideToolbarIcon(icon),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            if (selected)
              const WenzLucideToolbarIcon(
                WenzLucideToolbarIcons.check,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _TextColorMenuButton extends StatelessWidget {
  const _TextColorMenuButton({
    required this.toolbar,
    required this.state,
  });

  final ToolbarController toolbar;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentColor = state.textColor;
    final selected = currentColor != null || state.textColorMixed;
    final customColorActive = currentColor != null &&
        !state.textColorMixed &&
        !_kTextColorOptions.any((option) => option.colorValue == currentColor);
    return MenuAnchor(
      style: _toolbarMenuPanelStyle(context, width: _kTextColorMenuWidth),
      menuChildren: <Widget>[
        for (final option in _kTextColorOptions)
          MenuItemButton(
            closeOnActivate: true,
            style: _toolbarMenuItemStyle(
              context,
              width: _kTextColorMenuWidth,
            ),
            onPressed: state.canFormatInline
                ? () => toolbar.setTextColorValue(option.colorValue)
                : null,
            child: SizedBox(
              width: _toolbarMenuContentWidth(_kTextColorMenuWidth),
              child: Row(
                children: <Widget>[
                  _ColorSwatch(color: option.color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(option.label)),
                  if (currentColor == option.colorValue &&
                      !state.textColorMixed)
                    const WenzLucideToolbarIcon(
                      WenzLucideToolbarIcons.check,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
        const Divider(height: 1),
        MenuItemButton(
          closeOnActivate: true,
          style: _toolbarMenuItemStyle(
            context,
            width: _kTextColorMenuWidth,
          ),
          onPressed: state.canFormatInline
              ? () => _runToolbarAction(
                    _showCustomTextColorDialog(context, currentColor).then(
                      (colorValue) {
                        if (colorValue != null) {
                          toolbar.setTextColorValue(colorValue);
                        }
                      },
                    ),
                  )
              : null,
          child: SizedBox(
            width: _toolbarMenuContentWidth(_kTextColorMenuWidth),
            child: Row(
              children: <Widget>[
                if (currentColor == null || state.textColorMixed)
                  const WenzLucideToolbarIcon(
                    WenzLucideToolbarIcons.palette,
                    size: _kToolbarIconSize,
                  )
                else
                  _ColorSwatch(color: Color(currentColor)),
                const SizedBox(width: 10),
                Expanded(child: Text(_customTextColorLabel(currentColor))),
                if (customColorActive)
                  const WenzLucideToolbarIcon(
                    WenzLucideToolbarIcons.check,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, menuController, _) {
        return IconButton(
          tooltip: _textColorTooltip(state),
          iconSize: _kToolbarIconSize,
          isSelected: selected,
          style: _toolbarButtonStyle(theme),
          onPressed: state.canFormatInline
              ? () {
                  if (menuController.isOpen) {
                    menuController.close();
                  } else {
                    menuController.open();
                  }
                }
              : null,
          icon: WenzLucideToolbarIcon(
            WenzLucideToolbarIcons.textColor,
            color: state.canFormatInline && currentColor != null
                ? Color(currentColor)
                : null,
            enabled: state.canFormatInline,
          ),
        );
      },
    );
  }
}

class _RegistryToolbarItemButton extends StatelessWidget {
  const _RegistryToolbarItemButton({
    required this.item,
    required this.controller,
    required this.state,
  });

  final WenzToolbarItem item;
  final WenzRichTextController controller;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      tooltip: item.tooltip ?? item.title,
      icon: _toolbarItemIcon(item.icon),
      selected: item.activeFor(state),
      enabled: item.enabledFor(state),
      onPressed: () => item.action(controller, state),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const SizedBox.square(dimension: 18),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider({
    required this.visible,
    this.preserveWidth = false,
  });

  final bool visible;
  final bool preserveWidth;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      if (preserveWidth) {
        return const SizedBox(
          width: _kToolbarDividerWidth,
          height: _kToolbarButtonExtent,
        );
      }
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: _kToolbarButtonExtent,
      width: _kToolbarDividerWidth,
      child: Center(
        child: SizedBox(
          height: _kToolbarDividerHeight,
          child: VerticalDivider(
            width: _kToolbarDividerWidth,
            thickness: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _ToolbarColorOption {
  const _ToolbarColorOption(this.label, this.colorValue);

  final String label;
  final int colorValue;

  Color get color => Color(colorValue);
}

class _BlockStyleOption {
  const _BlockStyleOption.heading(this.label, this.headingLevel);

  const _BlockStyleOption.paragraph(this.label) : headingLevel = null;

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

class _AlignmentOption {
  const _AlignmentOption(this.label, this.icon, this.alignment);

  final String label;
  final String icon;
  final String? alignment;

  void apply(ToolbarController toolbar) {
    toolbar.setAlignment(alignment);
  }
}

String _blockStyleLabel(ToolbarState state) {
  for (final option in _kBlockStyleOptions) {
    if (option.isActive(state)) {
      return option.label;
    }
  }
  return '正文';
}

String _blockStyleTooltip(ToolbarState state) {
  return _blockStyleLabel(state);
}

bool _isExplicitBlockStyle(ToolbarState state) {
  for (final option in _kBlockStyleOptions) {
    if (option.isActive(state)) {
      return true;
    }
  }
  return false;
}

ButtonStyle _blockStyleButtonStyle(
  ThemeData theme, {
  required bool muted,
}) {
  final baseStyle = _toolbarTextButtonStyle(theme);
  if (!muted) {
    return baseStyle;
  }
  final colorScheme = theme.colorScheme;
  return baseStyle.copyWith(
    foregroundColor: WidgetStatePropertyAll<Color>(
      colorScheme.onSurface.withAlpha(96),
    ),
  );
}

_AlignmentOption _activeAlignmentOption(ToolbarState state) {
  return _kAlignmentOptions.firstWhere(
    (option) => option.alignment == state.alignment,
    orElse: () => _kAlignmentOptions.last,
  );
}

String _alignmentLabel(ToolbarState state) {
  if (state.alignmentMixed) {
    return '混合对齐';
  }
  final option = _activeAlignmentOption(state);
  return option.alignment == null ? '无对齐' : option.label;
}

String _alignmentTooltip(ToolbarState state) {
  return '对齐方式：${_alignmentLabel(state)}';
}

String _customTextColorLabel(int? currentColor) {
  if (currentColor == null) {
    return '自定义颜色';
  }
  return '自定义颜色 #${_hexColor(currentColor)}';
}

Future<int?> _showCustomTextColorDialog(
  BuildContext context,
  int? currentColor,
) async {
  final controller = TextEditingController(
    text: currentColor == null ? '' : '#${_hexColor(currentColor)}',
  );
  String? errorText;
  final result = await showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final colorValue = _parseHexColor(controller.text);
            if (colorValue == null) {
              setState(() {
                errorText = '请输入 #RRGGBB 或 #AARRGGBB';
              });
              return;
            }
            Navigator.of(dialogContext).pop(colorValue);
          }

          return AlertDialog(
            title: const Text('自定义文字颜色'),
            content: TextField(
              autofocus: true,
              controller: controller,
              decoration: InputDecoration(
                labelText: '十六进制颜色',
                hintText: '#336699',
                errorText: errorText,
              ),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => submit(),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: submit,
                child: const Text('Apply'),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  return result;
}

int? _parseHexColor(String input) {
  var value = input.trim();
  if (value.startsWith('#')) {
    value = value.substring(1);
  } else if (value.toLowerCase().startsWith('0x')) {
    value = value.substring(2);
  }
  if (value.length == 6) {
    value = 'FF$value';
  }
  if (value.length != 8 || !RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(value)) {
    return null;
  }
  return int.tryParse(value, radix: 16);
}

MenuStyle _toolbarMenuPanelStyle(
  BuildContext context, {
  required double width,
}) {
  final theme = Theme.of(context);
  return MenuStyle(
    minimumSize: WidgetStatePropertyAll(Size(width, 0)),
    fixedSize: WidgetStatePropertyAll(Size.fromWidth(width)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.all(_kToolbarMenuPanelPadding),
    ),
    backgroundColor: WidgetStatePropertyAll(_toolbarMenuPanelColor(theme)),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(8),
    shadowColor: WidgetStatePropertyAll(_toolbarMenuShadowColor(theme)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kToolbarMenuPanelRadius),
        side: BorderSide(color: _toolbarMenuLineColor(theme)),
      ),
    ),
  );
}

ButtonStyle _toolbarMenuItemStyle(
  BuildContext context, {
  required double width,
  bool danger = false,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final itemWidth = width - _kToolbarMenuPanelPadding * 2;
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll(
      Size(itemWidth, _kToolbarMenuItemHeight),
    ),
    fixedSize: WidgetStatePropertyAll(
      Size(itemWidth, _kToolbarMenuItemHeight),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 10),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    alignment: AlignmentDirectional.centerStart,
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kToolbarMenuItemRadius),
      ),
    ),
    backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.transparent;
      }
      if (states.contains(WidgetState.pressed)) {
        return danger
            ? colorScheme.error.withAlpha(31)
            : _toolbarMenuPressedColor(theme);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return danger
            ? colorScheme.error.withAlpha(26)
            : _toolbarMenuHoverColor(theme);
      }
      return Colors.transparent;
    }),
    foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return _toolbarMenuFaintColor(theme).withAlpha(148);
      }
      if (danger) {
        return colorScheme.error;
      }
      return _toolbarMenuTextColor(theme);
    }),
    iconColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return _toolbarMenuFaintColor(theme).withAlpha(148);
      }
      if (danger) {
        return colorScheme.error;
      }
      return _toolbarMenuMutedColor(theme);
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

double _toolbarMenuContentWidth(double menuWidth) {
  return menuWidth - _kToolbarMenuPanelPadding * 2 - 20;
}

Color _toolbarMenuPanelColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0xFF101010)
      : const Color(0xFFF7F7F8);
}

Color _toolbarMenuHoverColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0xFF2A2A2A)
      : const Color(0xFFEFF1F3);
}

Color _toolbarMenuPressedColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0xFF303030)
      : const Color(0xFFE5E7EA);
}

Color _toolbarMenuTextColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0xFFF2F2F2)
      : const Color(0xFF191919);
}

Color _toolbarMenuMutedColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0xFFB8B8B8)
      : const Color(0xFF5F6368);
}

Color _toolbarMenuFaintColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0xFF7A7A7A)
      : const Color(0xFF9AA0A6);
}

Color _toolbarMenuShadowColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0x8A000000)
      : const Color(0x24182639);
}

Color _toolbarMenuLineColor(ThemeData theme) {
  return (theme.brightness == Brightness.dark ? Colors.white : Colors.black)
      .withAlpha(20);
}

ButtonStyle _toolbarButtonStyle(ThemeData theme) {
  final colorScheme = theme.colorScheme;
  return IconButton.styleFrom(
    minimumSize: const Size.square(_kToolbarButtonExtent),
    fixedSize: const Size.square(_kToolbarButtonExtent),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    foregroundColor: colorScheme.onSurfaceVariant,
    disabledForegroundColor: colorScheme.onSurface.withAlpha(96),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_kToolbarRadius),
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
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return colorScheme.surfaceContainerHigh;
      }
      return Colors.transparent;
    }),
    overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.transparent;
      }
      return colorScheme.primary.withAlpha(20);
    }),
  );
}

ButtonStyle _toolbarTextButtonStyle(
  ThemeData theme, {
  double width = _kBlockStyleButtonWidth,
}) {
  final colorScheme = theme.colorScheme;
  return TextButton.styleFrom(
    minimumSize: Size(width, _kToolbarButtonExtent),
    fixedSize: Size(width, _kToolbarButtonExtent),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_kToolbarRadius),
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
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return colorScheme.surfaceContainerHigh;
      }
      return Colors.transparent;
    }),
    overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.transparent;
      }
      return colorScheme.primary.withAlpha(20);
    }),
  );
}

String _textColorTooltip(ToolbarState state) {
  if (state.textColorMixed) {
    return '文字颜色（混合）';
  }
  if (state.textColor == null) {
    return '文字颜色';
  }
  return '文字颜色 #${_hexColor(state.textColor!)}';
}

String _clearTextColorTooltip(ToolbarState state) {
  if (state.textColorMixed) {
    return '清除混合文字颜色';
  }
  if (state.textColor == null) {
    return '无文字颜色';
  }
  return '清除文字颜色 #${_hexColor(state.textColor!)}';
}

String _hexColor(int value) {
  return value.toRadixString(16).padLeft(8, '0').toUpperCase();
}

String _resourceTooltip(
  String label,
  WenzDefaultDesktopToolbarActionCallback? action,
) {
  return action == null ? '$label不可用' : label;
}

void _runToolbarAction(FutureOr<void> result) {
  if (result is Future<void>) {
    unawaited(result);
  }
}

String _toolbarItemIcon(String? icon) => wenzLucideToolbarIconName(icon);

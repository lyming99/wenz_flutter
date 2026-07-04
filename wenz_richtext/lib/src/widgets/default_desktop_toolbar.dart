import 'dart:async';

import 'package:flutter/material.dart';

import '../controller/toolbar_controller.dart';
import '../controller/wenz_rich_text_controller.dart';
import '../core/commands/inline_editing.dart';
import 'link_edit_dialog.dart';

const double _kToolbarHorizontalPadding = 12.0;
const double _kToolbarVerticalPadding = 8.0;
const double _kToolbarSpacing = 6.0;
const double _kToolbarRunSpacing = 6.0;
const double _kToolbarButtonExtent = 34.0;
const double _kToolbarIconSize = 19.0;
const double _kToolbarRadius = 6.0;

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

  bool canInsertImage(ToolbarController toolbar) {
    return onInsertImage != null && !isPickingImage && toolbar.canInsertImage;
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: toolbar,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final state = toolbar.state;
        final extraItems = effectiveToolbarItems;
        final showResourceActions = actions.shouldShowImageButton ||
            actions.shouldShowVideoButton ||
            actions.shouldShowFileButton ||
            actions.shouldShowBlockEmbedButton;
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
            child: Wrap(
              spacing: _kToolbarSpacing,
              runSpacing: _kToolbarRunSpacing,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _ToolbarIconButton(
                  tooltip: 'Undo',
                  icon: Icons.undo,
                  enabled: state.canUndo,
                  onPressed: toolbar.undo,
                ),
                _ToolbarIconButton(
                  tooltip: 'Redo',
                  icon: Icons.redo,
                  enabled: state.canRedo,
                  onPressed: toolbar.redo,
                ),
                _ToolbarDivider(visible: style.showGroupDividers),
                _MarkButton(
                  tooltip: 'Bold',
                  icon: Icons.format_bold,
                  mark: TextMark.bold,
                  toolbar: toolbar,
                  state: state,
                ),
                _MarkButton(
                  tooltip: 'Italic',
                  icon: Icons.format_italic,
                  mark: TextMark.italic,
                  toolbar: toolbar,
                  state: state,
                ),
                _MarkButton(
                  tooltip: 'Underline',
                  icon: Icons.format_underline,
                  mark: TextMark.underline,
                  toolbar: toolbar,
                  state: state,
                ),
                _MarkButton(
                  tooltip: 'Strikethrough',
                  icon: Icons.format_strikethrough,
                  mark: TextMark.lineThrough,
                  toolbar: toolbar,
                  state: state,
                ),
                _MarkButton(
                  tooltip: 'Remark',
                  icon: Icons.comment_outlined,
                  mark: TextMark.remark,
                  toolbar: toolbar,
                  state: state,
                ),
                _TextColorMenuButton(
                  toolbar: toolbar,
                  state: state,
                ),
                _ToolbarIconButton(
                  tooltip: _clearTextColorTooltip(state),
                  icon: Icons.format_color_reset,
                  enabled: state.canFormatInline,
                  iconColor: state.textColor == null
                      ? null
                      : Color(state.textColor!),
                  onPressed: toolbar.clearTextColor,
                ),
                _ToolbarIconButton(
                  tooltip: 'Clear style',
                  icon: Icons.format_clear,
                  enabled: state.canFormatInline,
                  onPressed: toolbar.clearStyle,
                ),
                _ToolbarIconButton(
                  tooltip: state.linkUrl == null ? 'Add link' : 'Edit link',
                  icon: Icons.link,
                  selected: state.linkUrl != null,
                  enabled: state.canSetLink,
                  onPressed: () => _showLinkDialog(context, state),
                ),
                _ToolbarIconButton(
                  tooltip: 'Formula',
                  icon: Icons.functions,
                  enabled: state.canFormatInline,
                  onPressed: () => controller.insertFormula(''),
                ),
                _ToolbarIconButton(
                  tooltip: 'Emoji',
                  icon: Icons.emoji_emotions_outlined,
                  enabled: state.canFormatInline,
                  onPressed: () => controller.insertEmoji(
                    '😀',
                    shortName: 'grinning',
                  ),
                ),
                _ToolbarDivider(visible: style.showGroupDividers),
                _BlockTypeButton(
                  tooltip: 'Heading 1',
                  icon: Icons.looks_one,
                  selected: state.isHeading(1),
                  enabled: state.canSetBlockType,
                  onPressed: () => toolbar.setHeading(1),
                ),
                _BlockTypeButton(
                  tooltip: 'Heading 2',
                  icon: Icons.looks_two,
                  selected: state.isHeading(2),
                  enabled: state.canSetBlockType,
                  onPressed: () => toolbar.setHeading(2),
                ),
                _BlockTypeButton(
                  tooltip: 'Heading 3',
                  icon: Icons.looks_3,
                  selected: state.isHeading(3),
                  enabled: state.canSetBlockType,
                  onPressed: () => toolbar.setHeading(3),
                ),
                _BlockTypeButton(
                  tooltip: 'Paragraph',
                  icon: Icons.notes,
                  selected: state.isParagraph,
                  enabled: state.canSetBlockType,
                  onPressed: toolbar.setParagraph,
                ),
                _BlockTypeButton(
                  tooltip: 'Quote',
                  icon: Icons.format_quote,
                  selected: state.isQuoteBlock,
                  enabled: state.canToggleQuote,
                  onPressed: toolbar.toggleQuoteBlock,
                ),
                _BlockTypeButton(
                  tooltip: 'Task list',
                  icon: Icons.checklist,
                  selected: state.isTodo,
                  enabled: state.canSetBlockType,
                  onPressed: toolbar.setTodo,
                ),
                _BlockTypeButton(
                  tooltip: 'Ordered list',
                  icon: Icons.format_list_numbered,
                  selected: state.isOrderedList,
                  enabled: state.canSetBlockType,
                  onPressed: toolbar.setOrderedList,
                ),
                _BlockTypeButton(
                  tooltip: 'Unordered list',
                  icon: Icons.format_list_bulleted,
                  selected: state.isUnorderedList,
                  enabled: state.canSetBlockType,
                  onPressed: toolbar.setUnorderedList,
                ),
                _ToolbarDivider(visible: style.showGroupDividers),
                _AlignmentButton(
                  tooltip: 'Align left',
                  icon: Icons.format_align_left,
                  alignment: 'left',
                  toolbar: toolbar,
                  state: state,
                ),
                _AlignmentButton(
                  tooltip: 'Align center',
                  icon: Icons.format_align_center,
                  alignment: 'center',
                  toolbar: toolbar,
                  state: state,
                ),
                _AlignmentButton(
                  tooltip: 'Align right',
                  icon: Icons.format_align_right,
                  alignment: 'right',
                  toolbar: toolbar,
                  state: state,
                ),
                _AlignmentButton(
                  tooltip: 'Justify',
                  icon: Icons.format_align_justify,
                  alignment: 'justify',
                  toolbar: toolbar,
                  state: state,
                ),
                _AlignmentButton(
                  tooltip: 'Clear alignment',
                  icon: Icons.format_clear,
                  alignment: null,
                  toolbar: toolbar,
                  state: state,
                ),
                _ToolbarDivider(visible: style.showGroupDividers),
                _ToolbarIconButton(
                  tooltip: 'Increase indent',
                  icon: Icons.format_indent_increase,
                  enabled: state.canIndent,
                  onPressed: toolbar.indent,
                ),
                _ToolbarIconButton(
                  tooltip: 'Decrease indent',
                  icon: Icons.format_indent_decrease,
                  enabled: state.canOutdent,
                  onPressed: toolbar.outdent,
                ),
                _ToolbarDivider(visible: style.showGroupDividers),
                _ToolbarIconButton(
                  tooltip: 'Insert code block',
                  icon: Icons.code,
                  enabled: toolbar.canInsertBlock,
                  onPressed: () => toolbar.insertCodeBlock(),
                ),
                _ToolbarIconButton(
                  tooltip: 'Insert callout',
                  icon: Icons.tips_and_updates_outlined,
                  enabled: toolbar.canInsertBlock,
                  onPressed: () => toolbar.insertCallout(),
                ),
                _ToolbarIconButton(
                  tooltip: 'Insert table',
                  icon: Icons.table_chart_outlined,
                  enabled: toolbar.canInsertBlock,
                  onPressed: () => toolbar.insertTable(),
                ),
                if (showResourceActions) ...<Widget>[
                  _ToolbarDivider(visible: style.showGroupDividers),
                  if (actions.shouldShowImageButton)
                    _ToolbarIconButton(
                      tooltip: actions.isPickingImage
                          ? 'Picking image'
                          : _resourceTooltip(
                              'Insert image',
                              actions.onInsertImage,
                            ),
                      icon: Icons.image_outlined,
                      iconWidget: actions.isPickingImage
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      enabled: actions.canInsertImage(toolbar),
                      onPressed: () => _runToolbarAction(
                        actions.insertImage(actionContext(context)),
                      ),
                    ),
                  if (actions.shouldShowVideoButton)
                    _ToolbarIconButton(
                      tooltip: _resourceTooltip(
                        'Insert video',
                        actions.onInsertVideo,
                      ),
                      icon: Icons.smart_display_outlined,
                      enabled: actions.canInsertVideo(toolbar),
                      onPressed: () => _runToolbarAction(
                        actions.insertVideo(actionContext(context)),
                      ),
                    ),
                  if (actions.shouldShowFileButton)
                    _ToolbarIconButton(
                      tooltip: _resourceTooltip(
                        'Insert file',
                        actions.onInsertFile,
                      ),
                      icon: Icons.attach_file,
                      enabled: actions.canInsertFile(controller),
                      onPressed: () => _runToolbarAction(
                        actions.insertFile(actionContext(context)),
                      ),
                    ),
                  if (actions.shouldShowBlockEmbedButton)
                    _ToolbarIconButton(
                      tooltip: _resourceTooltip(
                        'Insert embed',
                        actions.onInsertBlockEmbed,
                      ),
                      icon: Icons.badge_outlined,
                      enabled: actions.canInsertBlockEmbed(controller),
                      onPressed: () => _runToolbarAction(
                        actions.insertBlockEmbed(actionContext(context)),
                      ),
                    ),
                ],
                if (state.canTableStruct) ...<Widget>[
                  _ToolbarDivider(visible: style.showGroupDividers),
                  _ToolbarIconButton(
                    tooltip: 'Insert row below',
                    icon: Icons.table_rows_outlined,
                    enabled: state.canTableStruct,
                    onPressed: toolbar.insertTableRow,
                  ),
                  _ToolbarIconButton(
                    tooltip: 'Insert column right',
                    icon: Icons.view_column_outlined,
                    enabled: state.canTableStruct,
                    onPressed: toolbar.insertTableColumn,
                  ),
                  _ToolbarIconButton(
                    tooltip: 'Delete row',
                    icon: Icons.remove_circle_outline,
                    enabled: state.canTableStruct,
                    onPressed: toolbar.deleteTableRow,
                  ),
                  _ToolbarIconButton(
                    tooltip: 'Delete column',
                    icon: Icons.highlight_remove_outlined,
                    enabled: state.canTableStruct,
                    onPressed: toolbar.deleteTableColumn,
                  ),
                  _ToolbarIconButton(
                    tooltip: 'Merge cells',
                    icon: Icons.call_merge,
                    enabled: state.canTableStruct,
                    onPressed: toolbar.mergeTableCells,
                  ),
                  _ToolbarIconButton(
                    tooltip: 'Split cell',
                    icon: Icons.call_split,
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
              ],
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

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.selected = false,
    this.iconColor,
    this.iconWidget,
  });

  final String tooltip;
  final IconData icon;
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
      iconSize: _kToolbarIconSize,
      isSelected: selected,
      style: _toolbarButtonStyle(theme),
      onPressed: enabled ? onPressed : null,
      icon: iconWidget ?? Icon(icon, color: enabled ? iconColor : null),
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
  final IconData icon;
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

class _BlockTypeButton extends StatelessWidget {
  const _BlockTypeButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
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

class _AlignmentButton extends StatelessWidget {
  const _AlignmentButton({
    required this.tooltip,
    required this.icon,
    required this.alignment,
    required this.toolbar,
    required this.state,
  });

  final String tooltip;
  final IconData icon;
  final String? alignment;
  final ToolbarController toolbar;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      tooltip: state.alignmentMixed ? '$tooltip (mixed)' : tooltip,
      icon: icon,
      selected: state.canSetAlignment && state.isAlignment(alignment),
      enabled: state.canSetAlignment,
      onPressed: () => toolbar.setAlignment(alignment),
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
    return MenuAnchor(
      menuChildren: _kTextColorOptions.map((option) {
        final active =
            currentColor == option.colorValue && !state.textColorMixed;
        return MenuItemButton(
          closeOnActivate: true,
          onPressed: state.canFormatInline
              ? () => toolbar.setTextColorValue(option.colorValue)
              : null,
          child: SizedBox(
            width: 160,
            child: Row(
              children: <Widget>[
                _ColorSwatch(color: option.color),
                const SizedBox(width: 10),
                Expanded(child: Text(option.label)),
                if (active) const Icon(Icons.check, size: 18),
              ],
            ),
          ),
        );
      }).toList(growable: false),
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
          icon: Icon(
            Icons.format_color_text,
            color: state.canFormatInline && currentColor != null
                ? Color(currentColor)
                : null,
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
  const _ToolbarDivider({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: _kToolbarButtonExtent,
      child: VerticalDivider(
        width: 8,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
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

String _textColorTooltip(ToolbarState state) {
  if (state.textColorMixed) {
    return 'Text color (mixed)';
  }
  if (state.textColor == null) {
    return 'Text color';
  }
  return 'Text color #${_hexColor(state.textColor!)}';
}

String _clearTextColorTooltip(ToolbarState state) {
  if (state.textColorMixed) {
    return 'Clear mixed text color';
  }
  if (state.textColor == null) {
    return 'No text color';
  }
  return 'Clear text color #${_hexColor(state.textColor!)}';
}

String _hexColor(int value) {
  return value.toRadixString(16).padLeft(8, '0').toUpperCase();
}

String _resourceTooltip(
  String label,
  WenzDefaultDesktopToolbarActionCallback? action,
) {
  return action == null ? '$label unavailable' : label;
}

void _runToolbarAction(FutureOr<void> result) {
  if (result is Future<void>) {
    unawaited(result);
  }
}

IconData _toolbarItemIcon(String? icon) {
  switch (icon?.trim().toLowerCase()) {
    case 'account_tree':
    case 'account_tree_outlined':
    case 'flowchart':
      return Icons.account_tree_outlined;
    case 'extension':
    case 'extension_outlined':
      return Icons.extension_outlined;
    case 'badge':
    case 'badge_outlined':
      return Icons.badge_outlined;
    case 'code':
      return Icons.code;
    case 'table':
    case 'table_chart':
      return Icons.table_chart_outlined;
    case 'image':
      return Icons.image_outlined;
    case 'video':
    case 'smart_display':
      return Icons.smart_display_outlined;
    case 'file':
    case 'attach_file':
      return Icons.attach_file;
    case 'link':
      return Icons.link;
    case 'formula':
    case 'functions':
      return Icons.functions;
    case 'emoji':
      return Icons.emoji_emotions_outlined;
    case 'callout':
    case 'tips':
      return Icons.tips_and_updates_outlined;
    default:
      return Icons.extension_outlined;
  }
}

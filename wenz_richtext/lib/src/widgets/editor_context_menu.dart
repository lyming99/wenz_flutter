import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/wenz_rich_text_controller.dart';
import '../core/commands/inline_commands.dart';
import '../core/commands/inline_editing.dart';
import '../core/position/document_position.dart';
import 'editor_tokens.dart';

/// Action callback for an editor context-menu item.
///
/// Implementations may finish synchronously or return a [Future]. Mutating
/// actions should still go through [WenzRichTextController] so controller-level
/// permissions, command merging, history, and change notifications stay intact.
typedef WenzEditorContextMenuAction = FutureOr<void> Function(
  WenzEditorContextMenuContext context,
);

/// Predicate used by context-menu items to compute dynamic state.
typedef WenzEditorContextMenuPredicate = bool Function(
  WenzEditorContextMenuContext context,
);

/// Builds the final list of context-menu entries from the current editor
/// context and the editor-provided default entries.
///
/// Return [defaultEntries] unchanged to keep the built-ins, append entries to
/// extend them, or return a completely new list to replace the default menu.
typedef WenzEditorContextMenuBuilder = List<WenzEditorContextMenuEntry>
    Function(
  WenzEditorContextMenuContext context,
  List<WenzEditorContextMenuEntry> defaultEntries,
);

/// Built-in editor context-menu actions.
///
/// These values identify editor-owned menu items without exposing private
/// command handlers. The editor is responsible for dispatching them through its
/// existing clipboard, selection, and command paths.
enum WenzEditorContextMenuDefaultAction {
  copy,
  cut,
  paste,
  delete,
  selectAll,
  insertParagraph,
  insertHeading,
  insertQuote,
  insertCodeBlock,
  insertDivider,
  insertTable,
  insertImage,
  insertVideo,
  insertFile,
  insertFormula,
  insertCallout,
}

/// Controls whether [WenzEditorContextMenuConfiguration.items] are appended to
/// the editor defaults or replace them.
enum WenzEditorContextMenuDefaultItemsPolicy {
  include,
  customOnly,
}

/// Immutable snapshot passed to context-menu builders and actions.
class WenzEditorContextMenuContext {
  const WenzEditorContextMenuContext({
    required this.controller,
    required this.selection,
    required this.hitPosition,
    required this.globalPosition,
    required this.readOnly,
    required this.canEdit,
    required this.hitInsideSelection,
    this.buildContext,
  });

  /// Editor controller that owns the document and selection.
  final WenzRichTextController controller;

  /// Selection at the moment the context menu was requested.
  final DocumentSelection? selection;

  /// Document position hit by the pointer, when hit testing resolved one.
  final DocumentPosition? hitPosition;

  /// Global pointer location used as the menu anchor.
  final Offset globalPosition;

  /// Whether the editor widget is currently in read-only mode.
  final bool readOnly;

  /// Whether document-mutating menu actions may currently run.
  ///
  /// Editors should compute this after both widget read-only state and
  /// controller permission gates have been considered.
  final bool canEdit;

  /// Whether [hitPosition] fell inside the existing non-collapsed selection.
  final bool hitInsideSelection;

  /// Flutter build context for UI work initiated by custom actions.
  ///
  /// Actions should treat this as short-lived because asynchronous work can
  /// outlive the editor widget.
  final BuildContext? buildContext;

  bool get hasSelection => selection != null;

  bool get hasExpandedSelection => selection?.isCollapsed == false;
}

/// Base type for editor context-menu descriptors.
abstract class WenzEditorContextMenuEntry {
  const WenzEditorContextMenuEntry({
    this.key,
    this.semanticLabel,
  });

  /// Optional stable key used by menu widgets and widget tests.
  final Key? key;

  /// Optional accessibility label. When omitted, item renderers may use the
  /// visible title for actionable entries.
  final String? semanticLabel;
}

/// Actionable context-menu item.
class WenzEditorContextMenuItem extends WenzEditorContextMenuEntry {
  const WenzEditorContextMenuItem({
    required this.id,
    required this.title,
    this.icon,
    this.shortcut,
    this.defaultAction,
    this.action,
    this.enabled = true,
    this.isEnabled,
    this.visible = true,
    this.isVisible,
    this.destructive = false,
    super.key,
    super.semanticLabel,
  });

  /// Stable item id. Custom integrations should namespace business actions.
  ///
  /// Renderers use this id to derive a fallback widget key when [key] is omitted;
  /// duplicate ids remain valid, but tests should prefer unique ids or explicit
  /// keys for the most precise lookup.
  final String id;

  /// Visible menu title.
  final String title;

  /// Optional icon hint for Material/Cupertino renderers.
  final IconData? icon;

  /// Optional shortcut label, for example `Ctrl+C` or `Cmd+V`.
  ///
  /// Renderers may include this in both visible menu chrome and accessibility
  /// labels.
  final String? shortcut;

  /// Built-in action identifier when this item is editor-owned.
  final WenzEditorContextMenuDefaultAction? defaultAction;

  /// Custom callback invoked when the item is selected.
  final WenzEditorContextMenuAction? action;

  /// Static enabled state.
  final bool enabled;

  /// Optional context-sensitive enabled predicate.
  final WenzEditorContextMenuPredicate? isEnabled;

  /// Static visibility state.
  final bool visible;

  /// Optional context-sensitive visibility predicate.
  final WenzEditorContextMenuPredicate? isVisible;

  /// Whether renderers should use destructive styling.
  final bool destructive;

  bool enabledFor(WenzEditorContextMenuContext context) {
    return enabled && (isEnabled?.call(context) ?? true);
  }

  bool visibleFor(WenzEditorContextMenuContext context) {
    return visible && (isVisible?.call(context) ?? true);
  }

  FutureOr<void> invoke(WenzEditorContextMenuContext context) {
    if (!enabledFor(context)) {
      return Future<void>.value();
    }
    final callback = action;
    if (callback == null) {
      return Future<void>.value();
    }
    return callback(context);
  }
}

/// Visual separator between context-menu groups.
class WenzEditorContextMenuDivider extends WenzEditorContextMenuEntry {
  const WenzEditorContextMenuDivider({
    super.key,
    super.semanticLabel,
  });
}

/// Public configuration for the editor-owned desktop context menu.
class WenzEditorContextMenuConfiguration {
  const WenzEditorContextMenuConfiguration({
    this.items = const <WenzEditorContextMenuEntry>[],
    this.builder,
    this.defaultItemsPolicy = WenzEditorContextMenuDefaultItemsPolicy.include,
  });

  /// Additional entries used when [builder] is omitted.
  final List<WenzEditorContextMenuEntry> items;

  /// Optional builder with full control over the final menu.
  ///
  /// When supplied, [items] and [defaultItemsPolicy] are ignored; callers can
  /// append to or replace [defaultEntries] directly.
  final WenzEditorContextMenuBuilder? builder;

  /// Policy used to combine [items] with editor-provided defaults.
  final WenzEditorContextMenuDefaultItemsPolicy defaultItemsPolicy;

  List<WenzEditorContextMenuEntry> resolveEntries(
    WenzEditorContextMenuContext context,
    Iterable<WenzEditorContextMenuEntry> defaultEntries,
  ) {
    final defaults = List<WenzEditorContextMenuEntry>.unmodifiable(
      defaultEntries,
    );
    final customBuilder = builder;
    if (customBuilder != null) {
      return List<WenzEditorContextMenuEntry>.unmodifiable(
        customBuilder(context, defaults),
      );
    }
    return List<WenzEditorContextMenuEntry>.unmodifiable(
      <WenzEditorContextMenuEntry>[
        if (defaultItemsPolicy ==
            WenzEditorContextMenuDefaultItemsPolicy.include)
          ...defaults,
        ...items,
      ],
    );
  }

  WenzEditorContextMenuConfiguration copyWith({
    List<WenzEditorContextMenuEntry>? items,
    WenzEditorContextMenuBuilder? builder,
    bool clearBuilder = false,
    WenzEditorContextMenuDefaultItemsPolicy? defaultItemsPolicy,
  }) {
    assert(!clearBuilder || builder == null);
    return WenzEditorContextMenuConfiguration(
      items: items ?? this.items,
      builder: clearBuilder ? null : builder ?? this.builder,
      defaultItemsPolicy: defaultItemsPolicy ?? this.defaultItemsPolicy,
    );
  }
}

// Compact floating-toolbar chrome for the mobile selection toolbar. These
// mirror the editor's private `_kMinimalFloatingToolbar*` tokens
// (wenz_rich_text_editor.dart); duplicated here because the selection toolbar
// lives outside that file. Keep the values in sync.
const double _kSelectionToolbarRadius = 10.0;
const double _kSelectionToolbarElevation = 3.0;
const EdgeInsets _kSelectionToolbarPadding = EdgeInsets.symmetric(
  horizontal: 4,
  vertical: 2,
);
const double _kSelectionToolbarButtonGap = 2.0;

/// Compact touch selection toolbar shown above a non-collapsed selection on
/// mobile surfaces.
///
/// The action set (复制 / 剪切 / 全选 / 加粗 / 斜体) reuses the editor's
/// [WenzEditorContextMenuDefaultAction] action system and the controller's
/// existing clipboard / selection / command paths — no command logic is
/// re-implemented. Copy / cut read the payload through
/// [WenzRichTextController.copySelection] / [WenzRichTextController.cutSelection]
/// and write it to the clipboard; 全选 calls [WenzRichTextController.selectAll];
/// the format toggles dispatch [ToggleMarkCommand] via
/// [WenzRichTextController.execute]. Button / icon sizes come from
/// [EditorTokens.mobile]; the surface chrome uses the `_kSelectionToolbar*`
/// tokens above (mirrors of the editor's `_kMinimalFloatingToolbar*` family).
class WenzMobileSelectionToolbar extends StatelessWidget {
  const WenzMobileSelectionToolbar({
    super.key,
    required this.controller,
  });

  final WenzRichTextController controller;

  bool get _canEdit => controller.canEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEdit = _canEdit;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      elevation: _kSelectionToolbarElevation,
      shadowColor: theme.colorScheme.shadow.withAlpha(30),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(_kSelectionToolbarRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: _kSelectionToolbarPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _SelectionToolbarButton(
              icon: Icons.copy_all_outlined,
              tooltip: '复制',
              onTap: _copy,
            ),
            _SelectionToolbarButton(
              icon: Icons.content_cut,
              tooltip: '剪切',
              enabled: canEdit,
              onTap: _cut,
            ),
            _SelectionToolbarButton(
              icon: Icons.select_all_outlined,
              tooltip: '全选',
              onTap: _selectAll,
            ),
            const _SelectionToolbarDivider(),
            _SelectionToolbarButton(
              icon: Icons.format_bold,
              tooltip: '加粗',
              enabled: canEdit,
              onTap: _toggleBold,
            ),
            _SelectionToolbarButton(
              icon: Icons.format_italic,
              tooltip: '斜体',
              enabled: canEdit,
              onTap: _toggleItalic,
            ),
          ],
        ),
      ),
    );
  }

  // Action dispatch — reuses [WenzEditorContextMenuDefaultAction] identifiers
  // and the controller's existing clipboard/selection logic.

  void _copy() => _runDefault(WenzEditorContextMenuDefaultAction.copy);

  void _cut() => _runDefault(WenzEditorContextMenuDefaultAction.cut);

  void _selectAll() =>
      _runDefault(WenzEditorContextMenuDefaultAction.selectAll);

  void _runDefault(WenzEditorContextMenuDefaultAction action) {
    switch (action) {
      case WenzEditorContextMenuDefaultAction.copy:
        {
          final payload = controller.copySelection();
          if (payload != null) {
            unawaited(Clipboard.setData(ClipboardData(text: payload)));
          }
          break;
        }
      case WenzEditorContextMenuDefaultAction.cut:
        if (_canEdit) {
          final payload = controller.cutSelection();
          if (payload != null) {
            unawaited(Clipboard.setData(ClipboardData(text: payload)));
          }
        }
        break;
      case WenzEditorContextMenuDefaultAction.selectAll:
        controller.selectAll();
        break;
      default:
        // The selection toolbar only surfaces clipboard/selection actions;
        // insert* actions are not reachable here.
        break;
    }
  }

  void _toggleBold() {
    if (_canEdit) {
      controller.execute(const ToggleMarkCommand(TextMark.bold));
    }
  }

  void _toggleItalic() {
    if (_canEdit) {
      controller.execute(const ToggleMarkCommand(TextMark.italic));
    }
  }
}

class _SelectionToolbarButton extends StatelessWidget {
  const _SelectionToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = EditorTokens.mobile.minimalToolbarButtonSize;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _kSelectionToolbarButtonGap / 2,
      ),
      child: IconButton(
        tooltip: tooltip,
        iconSize: EditorTokens.mobile.minimalToolbarIconSize,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: size, height: size),
        onPressed: enabled ? onTap : null,
        icon: Icon(
          icon,
          color: enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withAlpha(96),
        ),
      ),
    );
  }
}

class _SelectionToolbarDivider extends StatelessWidget {
  const _SelectionToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _kSelectionToolbarButtonGap,
      ),
      child: SizedBox(
        height: EditorTokens.mobile.minimalToolbarButtonSize * 0.6,
        child: VerticalDivider(
          width: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

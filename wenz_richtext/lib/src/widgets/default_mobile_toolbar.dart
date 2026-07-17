import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
const double _kMobilePanelMinHeight = 120.0;
const double _kMobileColorActionMinHeight = 40.0;
const int _kMobileColorGridMinColumns = 4;
const int _kMobileColorGridMaxColumns = 6;

const List<WenzDefaultToolbarTextColorOption> _kMobileColorOptions =
    wenzDefaultToolbarTextColorOptions;

const List<WenzDefaultToolbarTextColorOption>
    _kMobileBackgroundColorOptions = <WenzDefaultToolbarTextColorOption>[
  WenzDefaultToolbarTextColorOption('浅黄', 0xFFFFF59D),
  WenzDefaultToolbarTextColorOption('浅绿', 0xFFC8E6C9),
  WenzDefaultToolbarTextColorOption('浅蓝', 0xFFBBDEFB),
  WenzDefaultToolbarTextColorOption('浅紫', 0xFFE1BEE7),
  WenzDefaultToolbarTextColorOption('浅红', 0xFFFFCDD2),
  WenzDefaultToolbarTextColorOption('浅灰', 0xFFE5E7EB),
];

const List<_MobileBlockStyleOption> _kMobileBlockStyleOptions =
    <_MobileBlockStyleOption>[
  _MobileBlockStyleOption.paragraph('正文'),
  _MobileBlockStyleOption.heading('H1', 1),
  _MobileBlockStyleOption.heading('H2', 2),
  _MobileBlockStyleOption.heading('H3', 3),
  _MobileBlockStyleOption.heading('H4', 4),
  _MobileBlockStyleOption.heading('H5', 5),
  _MobileBlockStyleOption.heading('H6', 6),
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

/// Material-ready bottom mobile toolbar surface for [WenzRichTextController].
///
/// Like [WenzDefaultDesktopToolbar], this widget is lifecycle-neutral: it
/// receives an existing [controller] and [toolbar], reuses the same
/// [ToolbarController] and [WenzToolbarItemRegistry] (no parallel item
/// system), and never creates or disposes any controller. The surface is a
/// bottom carrier: a fixed-height main bar stays at the top edge of the current
/// keyboard/panel occupancy, while the area below it switches between insert
/// and format panels.
///
/// Active state (bold / italic / todo / quote / …) is read from the shared
/// [ToolbarState] exactly as the desktop toolbar reads it, so the two toolbars
/// always agree. [WenzMobileToolbarStyle] controls keyboard avoidance, panel
/// height, and whether closing a panel restores editor focus.
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

enum _MobileToolbarPanel { insert, format }

class _WenzDefaultMobileToolbarState extends State<WenzDefaultMobileToolbar> {
  _MobileToolbarPanel? _activePanel;
  double _lastKeyboardHeight = 0.0;
  double _lastViewInsetsBottom = 0.0;
  bool _isWaitingForKeyboardDismiss = false;
  bool _isRestoringKeyboard = false;
  Timer? _focusRestoreFallback;
  int _focusRestoreRequestId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _synchronizeKeyboardInset(MediaQuery.of(context));
  }

  @override
  void didUpdateWidget(covariant WenzDefaultMobileToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final keyboardStrategyChanged =
        oldWidget.style.aboveKeyboard != widget.style.aboveKeyboard ||
        oldWidget.style.dismissKeyboardOnPanelOpen !=
            widget.style.dismissKeyboardOnPanelOpen ||
        oldWidget.style.restoreFocusOnPanelClose !=
            widget.style.restoreFocusOnPanelClose;
    if (oldWidget.controller != widget.controller ||
        oldWidget.toolbar != widget.toolbar ||
        keyboardStrategyChanged) {
      _cancelFocusRestore();
      _activePanel = null;
      _lastKeyboardHeight = 0.0;
      _lastViewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
      _isWaitingForKeyboardDismiss = false;
    }
  }

  @override
  void dispose() {
    _cancelFocusRestore();
    super.dispose();
  }

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

  void _togglePanel(_MobileToolbarPanel panel) {
    if (_activePanel == panel) {
      _closePanel(restoreFocus: true);
      return;
    }
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    _cancelFocusRestore();
    setState(() {
      if (keyboardHeight > 0) {
        _lastKeyboardHeight = keyboardHeight;
      }
      _lastViewInsetsBottom = keyboardHeight;
      _activePanel = panel;
      _isWaitingForKeyboardDismiss =
          widget.style.dismissKeyboardOnPanelOpen && keyboardHeight > 0;
    });
    if (widget.style.dismissKeyboardOnPanelOpen) {
      _hideKeyboardForPanel();
    }
  }

  void _closePanel({required bool restoreFocus}) {
    if (_activePanel == null) {
      if (restoreFocus && widget.style.restoreFocusOnPanelClose) {
        _restoreEditorFocus();
      }
      return;
    }
    if (restoreFocus && widget.style.restoreFocusOnPanelClose) {
      setState(() {
        _isWaitingForKeyboardDismiss = false;
        _isRestoringKeyboard = true;
      });
      _restoreEditorFocus();
      return;
    }
    _clearPanelState(clearKeyboardHeight: _lastViewInsetsBottom == 0);
  }

  void _hideKeyboardForPanel() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }

  void _hideKeyboardAndPanel() {
    _cancelFocusRestore();
    if (_activePanel != null ||
        _lastKeyboardHeight != 0 ||
        _isWaitingForKeyboardDismiss) {
      setState(() {
        _activePanel = null;
        _lastKeyboardHeight = 0.0;
        _isWaitingForKeyboardDismiss = false;
      });
    }
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }

  void _restoreEditorFocus() {
    final requestId = ++_focusRestoreRequestId;
    _focusRestoreFallback?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || requestId != _focusRestoreRequestId) {
        return;
      }
      if (!widget.controller.requestFocus()) {
        _clearPanelState(clearKeyboardHeight: true);
        return;
      }
      _focusRestoreFallback = Timer(
        widget.style.animationDuration + const Duration(milliseconds: 240),
        () {
          if (!mounted ||
              requestId != _focusRestoreRequestId ||
              !_isRestoringKeyboard) {
            return;
          }
          _clearPanelState(
            clearKeyboardHeight: _lastViewInsetsBottom == 0,
          );
        },
      );
    });
  }

  void _cancelFocusRestore() {
    _focusRestoreRequestId += 1;
    _focusRestoreFallback?.cancel();
    _focusRestoreFallback = null;
    _isRestoringKeyboard = false;
  }

  void _clearPanelState({required bool clearKeyboardHeight}) {
    _cancelFocusRestore();
    if (!mounted) {
      return;
    }
    setState(() {
      _activePanel = null;
      _isWaitingForKeyboardDismiss = false;
      if (clearKeyboardHeight) {
        _lastKeyboardHeight = 0.0;
      } else if (_lastViewInsetsBottom > 0) {
        _lastKeyboardHeight = _lastViewInsetsBottom;
      }
    });
  }

  void _synchronizeKeyboardInset(MediaQueryData media) {
    final keyboardHeight = media.viewInsets.bottom;
    final previousKeyboardHeight = _lastViewInsetsBottom;

    if (keyboardHeight > 0) {
      if (_activePanel == null) {
        _cancelFocusRestore();
        _lastKeyboardHeight = keyboardHeight;
      } else if (_isWaitingForKeyboardDismiss) {
        if (keyboardHeight > previousKeyboardHeight + 0.5) {
          _isWaitingForKeyboardDismiss = false;
          _isRestoringKeyboard = true;
        } else {
          _lastKeyboardHeight =
              keyboardHeight > _lastKeyboardHeight
                  ? keyboardHeight
                  : _lastKeyboardHeight;
        }
      } else if (_isRestoringKeyboard ||
          widget.style.dismissKeyboardOnPanelOpen) {
        _cancelFocusRestore();
        _activePanel = null;
        _lastKeyboardHeight = keyboardHeight;
      }
    } else if (previousKeyboardHeight > 0) {
      if (_isWaitingForKeyboardDismiss) {
        _isWaitingForKeyboardDismiss = false;
      } else {
        // Only an explicit panel handoff is allowed to retain the toolbar
        // after the IME disappears. Every other zero inset is a system
        // dismissal and must release all keyboard-owned toolbar state.
        _cancelFocusRestore();
        _activePanel = null;
        _lastKeyboardHeight = 0.0;
        _isWaitingForKeyboardDismiss = false;
      }
    }

    _lastViewInsetsBottom = keyboardHeight;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final viewInsetsBottom = media.viewInsets.bottom;
    // The main bar is keyboard-owned unless an insert/format panel has taken
    // over that occupancy. Returning no layout avoids a stale bottom gap.
    if (viewInsetsBottom == 0 && _activePanel == null) {
      return const SizedBox.shrink();
    }
    final panelReplacesKeyboard =
        _activePanel != null && widget.style.dismissKeyboardOnPanelOpen;
    final bottomInset = widget.style.aboveKeyboard && !panelReplacesKeyboard
        ? viewInsetsBottom
        : 0.0;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: viewInsetsBottom == 0 && _activePanel == null,
        child: AnimatedBuilder(
          animation: _rebuildListenable,
          builder: (context, _) {
            final state = widget.toolbar.state;
            return Material(
              color: theme.colorScheme.surface,
              elevation: widget.style.elevation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildMainBar(context, theme, state),
                  AnimatedSize(
                    alignment: Alignment.topCenter,
                    duration: _lastKeyboardHeight > 0
                        ? Duration.zero
                        : widget.style.animationDuration,
                    curve: Curves.easeOutCubic,
                    child: _activePanel == null
                        ? const SizedBox.shrink()
                        : SizedBox(
                            height: _effectivePanelHeight(media),
                            child: _buildPanel(context, theme, media, state),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  double _effectivePanelHeight(MediaQueryData media) {
    final available = media.size.height -
        media.padding.top -
        widget.style.mainBarHeight;
    if (available <= 0) {
      return 0.0;
    }
    if (_lastKeyboardHeight > 0 &&
        widget.style.dismissKeyboardOnPanelOpen) {
      return _lastKeyboardHeight.clamp(0.0, available).toDouble();
    }
    if (available < _kMobilePanelMinHeight) {
      return available;
    }
    return widget.style.panelHeight
        .clamp(_kMobilePanelMinHeight, available)
        .toDouble();
  }

  Widget _buildMainBar(
    BuildContext context,
    ThemeData theme,
    ToolbarState state,
  ) {
    final verticalPadding = ((widget.style.mainBarHeight -
                _kMobileToolbarButtonSize) /
            2)
        .clamp(0.0, _kMobileToolbarVerticalPadding)
        .toDouble();
    final children = _buildPrimaryRailActions(state);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SizedBox(
        height: widget.style.mainBarHeight,
        child: Row(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(
                left: _kMobileToolbarHorizontalPadding,
                top: verticalPadding,
                bottom: verticalPadding,
                right: _kMobileToolbarGap,
              ),
              child: _MobileIconButton(
                tooltip: _activePanel == _MobileToolbarPanel.insert
                    ? '收起插入面板'
                    : '打开插入面板',
                icon: WenzLucideToolbarIcons.insert,
                selected: _activePanel == _MobileToolbarPanel.insert,
                enabled: true,
                onPressed: () => _togglePanel(_MobileToolbarPanel.insert),
              ),
            ),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: _kMobileToolbarGap,
                  vertical: verticalPadding,
                ),
                children: <Widget>[
                  for (var i = 0; i < children.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: _kMobileToolbarGap),
                    children[i],
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: _kMobileToolbarGap,
                top: verticalPadding,
                bottom: verticalPadding,
                right: _kMobileToolbarHorizontalPadding,
              ),
              child: _MobileIconButton(
                tooltip: '收起键盘',
                icon: WenzLucideToolbarIcons.arrowDown,
                enabled: true,
                onPressed: _hideKeyboardAndPanel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPrimaryRailActions(ToolbarState state) {
    return <Widget>[
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
        tooltip: _activePanel == _MobileToolbarPanel.format
            ? '收起格式面板'
            : '打开格式面板',
        icon: WenzLucideToolbarIcons.palette,
        selected: _activePanel == _MobileToolbarPanel.format,
        enabled: true,
        onPressed: () => _togglePanel(_MobileToolbarPanel.format),
      ),
    ];
  }

  Widget _buildPanel(
    BuildContext context,
    ThemeData theme,
    MediaQueryData media,
    ToolbarState state,
  ) {
    return DecoratedBox(
      key: ValueKey<_MobileToolbarPanel?>(_activePanel),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          _kMobileToolbarHorizontalPadding,
          _kMobileToolbarVerticalPadding,
          _kMobileToolbarHorizontalPadding,
          _kMobileToolbarVerticalPadding + media.padding.bottom,
        ),
        child: switch (_activePanel) {
          _MobileToolbarPanel.insert => _buildInsertPanel(context, state),
          _MobileToolbarPanel.format => _buildFormatPanel(state),
          null => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _buildFormatPanel(ToolbarState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PanelSection(
          label: '块样式',
          child: _BlockStyleRow(toolbar: widget.toolbar, state: state),
        ),
        _PanelSection(
          label: '列表',
          child: _ListStyleRow(toolbar: widget.toolbar, state: state),
        ),
        _PanelSection(
          label: '缩进',
          child: _IndentRow(toolbar: widget.toolbar, state: state),
        ),
        _PanelSection(
          label: '对齐',
          child: _AlignmentRow(toolbar: widget.toolbar, state: state),
        ),
        _PanelSection(
          label: '文字颜色',
          child: _ColorRow(toolbar: widget.toolbar, state: state),
        ),
        _PanelSection(
          label: '背景/高亮',
          child: _BackgroundColorRow(toolbar: widget.toolbar, state: state),
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
      ],
    );
  }

  Widget _buildInsertPanel(BuildContext context, ToolbarState state) {
    final extraItems = widget.effectiveToolbarItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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

class _ListStyleRow extends StatelessWidget {
  const _ListStyleRow({required this.toolbar, required this.state});

  final ToolbarController toolbar;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _kMobileToolbarGap,
      runSpacing: _kMobileToolbarGap,
      children: <Widget>[
        _MobileIconButton(
          tooltip: '任务列表',
          icon: WenzLucideToolbarIcons.taskList,
          selected: state.isTodo,
          enabled: state.canSetBlockType,
          onPressed: toolbar.setTodo,
        ),
        _MobileIconButton(
          tooltip: '有序列表',
          icon: WenzLucideToolbarIcons.orderedList,
          selected: state.isOrderedList,
          enabled: state.canSetBlockType,
          onPressed: toolbar.setOrderedList,
        ),
        _MobileIconButton(
          tooltip: '无序列表',
          icon: WenzLucideToolbarIcons.unorderedList,
          selected: state.isUnorderedList,
          enabled: state.canSetBlockType,
          onPressed: toolbar.setUnorderedList,
        ),
      ],
    );
  }
}

class _IndentRow extends StatelessWidget {
  const _IndentRow({required this.toolbar, required this.state});

  final ToolbarController toolbar;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _kMobileToolbarGap,
      runSpacing: _kMobileToolbarGap,
      children: <Widget>[
        _MobileIconButton(
          tooltip: '减少缩进',
          icon: WenzLucideToolbarIcons.indentDecrease,
          enabled: state.canOutdent,
          onPressed: toolbar.outdent,
        ),
        _MobileIconButton(
          tooltip: '增加缩进',
          icon: WenzLucideToolbarIcons.indentIncrease,
          enabled: state.canIndent,
          onPressed: toolbar.indent,
        ),
      ],
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
    final current = state.textColor;
    final customColorActive = _mobileIsCustomTextColorActive(state);
    final customColor = customColorActive ? Color(current!) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _MobileTextColorPalette(
          toolbar: toolbar,
          state: state,
        ),
        const SizedBox(height: _kMobileToolbarGap),
        _MobileTextColorActionButton(
          tooltip: _mobileClearTextColorTooltip(state),
          label: _mobileClearTextColorTooltip(state),
          icon: WenzLucideToolbarIcons.clearTextColor,
          iconColor: current == null || state.textColorMixed
              ? null
              : Color(current),
          enabled: state.canFormatInline,
          onPressed: toolbar.clearTextColor,
        ),
        const SizedBox(height: _kMobileToolbarGap),
        _MobileTextColorActionButton(
          tooltip: _mobileCustomTextColorTooltip(state),
          label: _mobileCustomTextColorLabel(state),
          icon: customColor == null ? WenzLucideToolbarIcons.palette : null,
          leading: customColor == null
              ? null
              : _MobileColorPreview(
                  color: customColor,
                  enabled: state.canFormatInline,
                ),
          trailing: customColorActive
              ? WenzLucideToolbarIcon(
                  WenzLucideToolbarIcons.check,
                  size: 18,
                  enabled: state.canFormatInline,
                )
              : null,
          selected: customColorActive,
          enabled: state.canFormatInline,
          onPressed: () async {
            final colorValue = await _showMobileCustomTextColorDialog(
              context,
              state.textColorMixed ? null : current,
            );
            if (!context.mounted || colorValue == null) {
              return;
            }
            toolbar.setTextColorValue(colorValue);
          },
        ),
      ],
    );
  }
}

class _MobileTextColorPalette extends StatelessWidget {
  const _MobileTextColorPalette({
    required this.toolbar,
    required this.state,
  });

  final ToolbarController toolbar;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (_kMobileToolbarButtonSize + _kMobileToolbarGap) *
                _kMobileColorGridMinColumns;
        final columnCount = _mobileTextColorGridColumnCount(maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _kMobileColorOptions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: _kMobileToolbarGap,
            mainAxisSpacing: _kMobileToolbarGap,
            mainAxisExtent: _kMobileToolbarButtonSize,
          ),
          itemBuilder: (context, index) {
            final option = _kMobileColorOptions[index];
            return _MobileTextColorSwatchButton(
              tooltip: _mobileTextColorOptionTooltip(option),
              color: option.color,
              selected: state.textColor == option.colorValue &&
                  !state.textColorMixed,
              enabled: state.canFormatInline,
              onPressed: () => toolbar.setTextColorValue(option.colorValue),
            );
          },
        );
      },
    );
  }
}

class _BackgroundColorRow extends StatelessWidget {
  const _BackgroundColorRow({required this.toolbar, required this.state});

  final ToolbarController toolbar;
  final ToolbarState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = state.textBackgroundColor;
    return Wrap(
      spacing: _kMobileToolbarGap,
      runSpacing: _kMobileToolbarGap,
      children: <Widget>[
        for (final option in _kMobileBackgroundColorOptions)
          _ColorSwatchButton(
            tooltip: _mobileBackgroundColorOptionTooltip(option),
            color: option.color,
            selected: current == option.colorValue &&
                !state.textBackgroundColorMixed,
            enabled: state.canFormatInline,
            outlineColor: theme.colorScheme.outline,
            onPressed: () => toolbar.setTextBackgroundValue(option.colorValue),
          ),
        _MobileIconButton(
          tooltip: _mobileClearBackgroundColorTooltip(state),
          icon: WenzLucideToolbarIcons.tableBackgroundClear,
          iconColor: current == null || state.textBackgroundColorMixed
              ? null
              : Color(current),
          enabled: state.canFormatInline,
          onPressed: toolbar.clearTextBackground,
        ),
      ],
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.tooltip,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.outlineColor,
    required this.onPressed,
  });

  final String tooltip;
  final Color color;
  final bool selected;
  final bool enabled;
  final Color outlineColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
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

class _MobileTextColorSwatchButton extends StatelessWidget {
  const _MobileTextColorSwatchButton({
    required this.tooltip,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        iconSize: _kMobileToolbarIconSize,
        isSelected: selected,
        style: _mobileButtonStyle(Theme.of(context)),
        onPressed: enabled ? onPressed : null,
        icon: _MobileTextColorSwatch(
          color: color,
          selected: selected,
          enabled: enabled,
        ),
      ),
    );
  }
}

class _MobileTextColorSwatch extends StatelessWidget {
  const _MobileTextColorSwatch({
    required this.color,
    required this.selected,
    required this.enabled,
  });

  final Color color;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.44,
      child: SizedBox.square(
        dimension: _kMobileToolbarIconSize,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            if (selected)
              Center(
                child: WenzLucideToolbarIcon(
                  WenzLucideToolbarIcons.check,
                  size: 14,
                  color: _mobileTextColorCheckColor(color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileColorPreview extends StatelessWidget {
  const _MobileColorPreview({
    required this.color,
    required this.enabled,
  });

  final Color color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const SizedBox.square(dimension: 18),
      ),
    );
  }
}

class _MobileTextColorActionButton extends StatelessWidget {
  const _MobileTextColorActionButton({
    required this.tooltip,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailing,
    this.selected = false,
  }) : assert(icon != null || leading != null);

  final String tooltip;
  final String label;
  final bool enabled;
  final bool selected;
  final String? icon;
  final Color? iconColor;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(_kMobileColorActionMinHeight),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_kMobileToolbarRadius),
            ),
          ).copyWith(
            foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.disabled)) {
                return colorScheme.onSurface.withAlpha(96);
              }
              if (selected) {
                return colorScheme.onPrimaryContainer;
              }
              return colorScheme.onSurfaceVariant;
            }),
            backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.disabled)) {
                return Colors.transparent;
              }
              if (selected) {
                return colorScheme.primaryContainer;
              }
              if (states.contains(WidgetState.pressed)) {
                return colorScheme.surfaceContainerHighest;
              }
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return colorScheme.surfaceContainerHighest;
              }
              return colorScheme.surfaceContainerHigh;
            }),
          ),
          child: Row(
            children: <Widget>[
              leading ??
                  WenzLucideToolbarIcon(
                    icon!,
                    size: 18,
                    color: enabled ? iconColor : null,
                    enabled: enabled,
                  ),
              const SizedBox(width: 10),
              Expanded(child: Text(label)),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
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
        tooltip: '添加文本块',
        icon: WenzLucideToolbarIcons.textBlock,
        enabled: toolbar.canInsertBlock,
        onPressed: () => controller.insertTextBlockBelow(),
      ),
      _MobileIconButton(
        tooltip: '引用',
        icon: WenzLucideToolbarIcons.quote,
        selected: state.isQuoteBlock,
        enabled: state.canToggleQuote,
        onPressed: toolbar.toggleQuoteBlock,
      ),
      _MobileIconButton(
        tooltip: '分割线',
        icon: WenzLucideToolbarIcons.divider,
        enabled: toolbar.canInsertBlock,
        onPressed: toolbar.insertDivider,
      ),
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

String _mobileTextColorOptionTooltip(
  WenzDefaultToolbarTextColorOption option,
) {
  return '${option.label} #${_mobileHexColor(option.colorValue)}';
}

Color _mobileTextColorCheckColor(Color color) {
  return color.computeLuminance() > 0.55 ? Colors.black : Colors.white;
}

bool _mobileIsPresetTextColor(int? colorValue) {
  if (colorValue == null) {
    return false;
  }
  return _kMobileColorOptions.any((option) => option.colorValue == colorValue);
}

bool _mobileIsCustomTextColorActive(ToolbarState state) {
  final currentColor = state.textColor;
  return currentColor != null &&
      !state.textColorMixed &&
      !_mobileIsPresetTextColor(currentColor);
}

String _mobileClearTextColorTooltip(ToolbarState state) {
  if (!state.canFormatInline) {
    return '清除文字颜色不可用';
  }
  if (state.textColorMixed) {
    return '清除混合文字颜色';
  }
  if (state.textColor == null) {
    return '无文字颜色';
  }
  return '清除文字颜色 #${_mobileHexColor(state.textColor!)}';
}

String _mobileCustomTextColorLabel(ToolbarState state) {
  if (state.textColorMixed) {
    return '自定义颜色（混合）';
  }
  final currentColor = state.textColor;
  if (currentColor == null || _mobileIsPresetTextColor(currentColor)) {
    return '自定义颜色';
  }
  return '自定义颜色 #${_mobileHexColor(currentColor)}';
}

String _mobileCustomTextColorTooltip(ToolbarState state) {
  if (!state.canFormatInline) {
    return '自定义文字颜色不可用';
  }
  if (state.textColorMixed) {
    return '自定义文字颜色（混合）';
  }
  final currentColor = state.textColor;
  if (currentColor == null || _mobileIsPresetTextColor(currentColor)) {
    return '自定义文字颜色';
  }
  return '自定义文字颜色 #${_mobileHexColor(currentColor)}';
}

String _mobileBackgroundColorOptionTooltip(
  WenzDefaultToolbarTextColorOption option,
) {
  return '${option.label}背景 #${_mobileHexColor(option.colorValue)}';
}

String _mobileClearBackgroundColorTooltip(ToolbarState state) {
  if (!state.canFormatInline) {
    return '清除背景色不可用';
  }
  if (state.textBackgroundColorMixed) {
    return '清除混合背景色';
  }
  if (state.textBackgroundColor == null) {
    return '无背景色';
  }
  return '清除背景色 #${_mobileHexColor(state.textBackgroundColor!)}';
}

String _mobileHexColor(int value) {
  return value.toRadixString(16).padLeft(8, '0').toUpperCase();
}

int _mobileTextColorGridColumnCount(double maxWidth) {
  final columns = ((maxWidth + _kMobileToolbarGap) /
          (_kMobileToolbarButtonSize + _kMobileToolbarGap))
      .floor();
  if (columns < _kMobileColorGridMinColumns) {
    return _kMobileColorGridMinColumns;
  }
  if (columns > _kMobileColorGridMaxColumns) {
    return _kMobileColorGridMaxColumns;
  }
  return columns;
}

int? _parseMobileHexColor(String input) {
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

Future<int?> _showMobileCustomTextColorDialog(
  BuildContext context,
  int? currentColor,
) async {
  final controller = TextEditingController(
    text: currentColor == null ? '' : '#${_mobileHexColor(currentColor)}',
  );
  String? errorText;
  final result = await showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final colorValue = _parseMobileHexColor(controller.text);
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
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(
                  RegExp(r'[#0-9a-fA-FxX]'),
                ),
              ],
              onSubmitted: (_) => submit(),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: submit,
                child: const Text('应用'),
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

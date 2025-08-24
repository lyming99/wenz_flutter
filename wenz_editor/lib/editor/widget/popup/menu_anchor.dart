import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const bool _kDebugMenus = false;

const double _kDefaultSubmenuIconSize = 24;

const double _kLabelItemDefaultSpacing = 12;

const double _kLabelItemMinSpacing = 4;

const Map<ShortcutActivator, Intent> _kMenuTraversalShortcuts =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
  SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
  SingleActivator(LogicalKeyboardKey.tab, shift: true): PreviousFocusIntent(),
  SingleActivator(LogicalKeyboardKey.arrowDown):
      DirectionalFocusIntent(TraversalDirection.down),
  SingleActivator(LogicalKeyboardKey.arrowUp):
      DirectionalFocusIntent(TraversalDirection.up),
  SingleActivator(LogicalKeyboardKey.arrowLeft):
      DirectionalFocusIntent(TraversalDirection.left),
  SingleActivator(LogicalKeyboardKey.arrowRight):
      DirectionalFocusIntent(TraversalDirection.right),
};

const double _kMenuVerticalMinPadding = 8;

const double _kMenuViewPadding = 8;

const double _kTopLevelMenuHorizontalMinPadding = 4;

typedef MenuAnchorChildBuilder = Widget Function(
  BuildContext context,
  MenuController controller,
  Widget? child,
);

class MenuAnchor extends StatefulWidget {
  const MenuAnchor({
    super.key,
    this.controller,
    this.childFocusNode,
    this.style,
    this.alignmentOffset = Offset.zero,
    this.clipBehavior = Clip.hardEdge,
    @Deprecated(
      'Use consumeOutsideTap instead. '
      'This feature was deprecated after v3.16.0-8.0.pre.',
    )
    this.anchorTapClosesMenu = false,
    this.consumeOutsideTap = false,
    this.onOpen,
    this.onClose,
    this.crossAxisUnconstrained = true,
    required this.menuChildren,
    this.builder,
    this.child,
  });

  final MenuController? controller;

  final FocusNode? childFocusNode;

  final MenuStyle? style;

  final Offset? alignmentOffset;

  final Clip clipBehavior;

  @Deprecated(
    'Use consumeOutsideTap instead. '
    'This feature was deprecated after v3.16.0-8.0.pre.',
  )
  final bool anchorTapClosesMenu;

  final bool consumeOutsideTap;

  final VoidCallback? onOpen;

  final VoidCallback? onClose;

  final bool crossAxisUnconstrained;

  final List<Widget> menuChildren;

  final MenuAnchorChildBuilder? builder;

  final Widget? child;

  @override
  State<MenuAnchor> createState() => _MenuAnchorState();

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return menuChildren
        .map<DiagnosticsNode>((Widget child) => child.toDiagnosticsNode())
        .toList();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('anchorTapClosesMenu',
        value: anchorTapClosesMenu, ifTrue: 'AUTO-CLOSE'));
    properties
        .add(DiagnosticsProperty<FocusNode?>('focusNode', childFocusNode));
    properties.add(DiagnosticsProperty<MenuStyle?>('style', style));
    properties.add(EnumProperty<Clip>('clipBehavior', clipBehavior));
    properties
        .add(DiagnosticsProperty<Offset?>('alignmentOffset', alignmentOffset));
  }
}

class _MenuAnchorState extends State<MenuAnchor> {
  final GlobalKey<_MenuAnchorState> _anchorKey = GlobalKey<_MenuAnchorState>(
      debugLabel: kReleaseMode ? null : 'MenuAnchor');
  _MenuAnchorState? _parent;
  late final FocusScopeNode _menuScopeNode;
  MenuController? _internalMenuController;
  final List<_MenuAnchorState> _anchorChildren = <_MenuAnchorState>[];
  ScrollPosition? _scrollPosition;
  Size? _viewSize;
  final OverlayPortalController _overlayController = OverlayPortalController(
      debugLabel: kReleaseMode ? null : 'MenuAnchor controller');
  Offset? _menuPosition;

  Axis get _orientation => Axis.vertical;

  bool get _isOpen => _overlayController.isShowing;

  bool get _isRoot => _parent == null;

  bool get _isTopLevel => _parent?._isRoot ?? false;

  MenuController get _menuController =>
      widget.controller ?? _internalMenuController!;

  @override
  void initState() {
    super.initState();
    _menuScopeNode = FocusScopeNode(
        debugLabel: kReleaseMode ? null : '${describeIdentity(this)} Sub Menu');
    if (widget.controller == null) {
      _internalMenuController = MenuController();
    }
    _menuController._attach(this);
  }

  @override
  void dispose() {
    assert(_debugMenuInfo('Disposing of $this'));
    if (_isOpen) {
      _close(inDispose: true);
      _parent?._removeChild(this);
    }
    _anchorChildren.clear();
    _menuController._detach(this);
    _internalMenuController = null;
    _menuScopeNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final _MenuAnchorState? newParent = _MenuAnchorState._maybeOf(context);
    if (newParent != _parent) {
      _parent?._removeChild(this);
      _parent = newParent;
      _parent?._addChild(this);
    }
    _scrollPosition?.isScrollingNotifier.removeListener(_handleScroll);
    _scrollPosition = Scrollable.maybeOf(context)?.position;
    _scrollPosition?.isScrollingNotifier.addListener(_handleScroll);
    final Size newSize = MediaQuery.sizeOf(context);
    if (_viewSize != null && newSize != _viewSize) {
      _root._close();
    }
    _viewSize = newSize;
  }

  @override
  void didUpdateWidget(MenuAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      if (widget.controller != null) {
        _internalMenuController?._detach(this);
        _internalMenuController = null;
        widget.controller?._attach(this);
      } else {
        assert(_internalMenuController == null);
        _internalMenuController = MenuController().._attach(this);
      }
    }
    assert(_menuController._anchor == this);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (BuildContext context) {
        return _Submenu(
          anchor: this,
          menuStyle: widget.style,
          alignmentOffset: widget.alignmentOffset ?? Offset.zero,
          menuPosition: _menuPosition,
          clipBehavior: widget.clipBehavior,
          menuChildren: widget.menuChildren,
          crossAxisUnconstrained: widget.crossAxisUnconstrained,
        );
      },
      child: _buildContents(context),
    );

    if (!widget.anchorTapClosesMenu) {
      child = TapRegion(
        groupId: _root,
        consumeOutsideTaps: _root._isOpen && widget.consumeOutsideTap,
        onTapOutside: (PointerDownEvent event) {
          assert(_debugMenuInfo('Tapped Outside ${widget.controller}'));
          _closeChildren();
        },
        child: child,
      );
    }

    return _MenuAnchorScope(
      anchorKey: _anchorKey,
      anchor: this,
      isOpen: _isOpen,
      child: child,
    );
  }

  Widget _buildContents(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        DirectionalFocusIntent: _MenuDirectionalFocusAction(),
        PreviousFocusIntent: _MenuPreviousFocusAction(),
        NextFocusIntent: _MenuNextFocusAction(),
        DismissIntent: DismissMenuAction(controller: _menuController),
      },
      child: Builder(
        key: _anchorKey,
        builder: (BuildContext context) {
          return widget.builder?.call(context, _menuController, widget.child) ??
              widget.child ??
              const SizedBox();
        },
      ),
    );
  }

  FocusNode? get _firstItemFocusNode {
    if (_menuScopeNode.context == null) {
      return null;
    }
    final FocusTraversalPolicy policy =
        FocusTraversalGroup.maybeOf(_menuScopeNode.context!) ??
            ReadingOrderTraversalPolicy();
    return policy.findFirstFocus(_menuScopeNode, ignoreCurrentFocus: true);
  }

  void _addChild(_MenuAnchorState child) {
    assert(_isRoot || _debugMenuInfo('Added root child: $child'));
    assert(!_anchorChildren.contains(child));
    _anchorChildren.add(child);
    assert(_debugMenuInfo('Added:\n${child.widget.toStringDeep()}'));
    assert(_debugMenuInfo('Tree:\n${widget.toStringDeep()}'));
  }

  void _removeChild(_MenuAnchorState child) {
    assert(_isRoot || _debugMenuInfo('Removed root child: $child'));
    assert(_anchorChildren.contains(child));
    assert(_debugMenuInfo('Removing:\n${child.widget.toStringDeep()}'));
    _anchorChildren.remove(child);
    assert(_debugMenuInfo('Tree:\n${widget.toStringDeep()}'));
  }

  List<_MenuAnchorState> _getFocusableChildren() {
    if (_parent == null) {
      return <_MenuAnchorState>[];
    }
    return _parent!._anchorChildren.where(
      (_MenuAnchorState menu) {
        return menu.widget.childFocusNode?.canRequestFocus ?? false;
      },
    ).toList();
  }

  _MenuAnchorState? get _nextFocusableSibling {
    final List<_MenuAnchorState> focusable = _getFocusableChildren();
    if (focusable.isEmpty) {
      return null;
    }
    return focusable[(focusable.indexOf(this) + 1) % focusable.length];
  }

  _MenuAnchorState? get _previousFocusableSibling {
    final List<_MenuAnchorState> focusable = _getFocusableChildren();
    if (focusable.isEmpty) {
      return null;
    }
    return focusable[
        (focusable.indexOf(this) - 1 + focusable.length) % focusable.length];
  }

  _MenuAnchorState get _root {
    _MenuAnchorState anchor = this;
    while (anchor._parent != null) {
      anchor = anchor._parent!;
    }
    return anchor;
  }

  _MenuAnchorState get _topLevel {
    _MenuAnchorState handle = this;
    while (handle._parent != null && !handle._parent!._isTopLevel) {
      handle = handle._parent!;
    }
    return handle;
  }

  void _childChangedOpenState() {
    _parent?._childChangedOpenState();
    assert(mounted);
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      setState(() {});
    } else {
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        setState(() {});
      });
    }
  }

  void _focusButton() {
    if (widget.childFocusNode == null) {
      return;
    }
    assert(_debugMenuInfo('Requesting focus for ${widget.childFocusNode}'));
    widget.childFocusNode!.requestFocus();
  }

  void _handleScroll() {
    if (_isRoot) {
      _close();
    }
  }

  KeyEventResult _checkForEscape(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _open({Offset? position}) {
    assert(_menuController._anchor == this);
    if (_isOpen && position == null) {
      assert(_debugMenuInfo("Not opening $this because it's already open"));
      return;
    }
    if (_isOpen && position != null) {
      _close();
    }
    assert(_debugMenuInfo(
        'Opening $this at ${position ?? Offset.zero} with alignment offset ${widget.alignmentOffset ?? Offset.zero}'));
    _parent?._closeChildren();
    assert(!_overlayController.isShowing);

    _parent?._childChangedOpenState();
    _menuPosition = position;
    _overlayController.show();

    widget.onOpen?.call();
  }

  void _close({bool inDispose = false}) {
    assert(_debugMenuInfo('Closing $this'));
    if (!_isOpen) {
      return;
    }
    if (_isRoot) {
      FocusManager.instance.removeEarlyKeyEventHandler(_checkForEscape);
    }
    _closeChildren(inDispose: inDispose);
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      _overlayController.hide();
    } else if (!inDispose) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _overlayController.hide();
      }, debugLabel: 'MenuAnchor.hide');
    }
    if (!inDispose) {
      _parent?._childChangedOpenState();
      widget.onClose?.call();
      if (mounted &&
          SchedulerBinding.instance.schedulerPhase !=
              SchedulerPhase.persistentCallbacks) {
        setState(() {});
      }
    }
  }

  void _closeChildren({bool inDispose = false}) {
    assert(_debugMenuInfo(
        'Closing children of $this${inDispose ? ' (dispose)' : ''}'));
    for (final _MenuAnchorState child
        in List<_MenuAnchorState>.from(_anchorChildren)) {
      child._close(inDispose: inDispose);
    }
  }

  static _MenuAnchorState? _maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_MenuAnchorScope>()
        ?.anchor;
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) {
    return describeIdentity(this);
  }
}

class MenuController {
  _MenuAnchorState? _anchor;

  bool get isOpen {
    assert(_anchor != null);
    return _anchor!._isOpen;
  }

  void close() {
    assert(_anchor != null);
    _anchor!._close();
  }

  void open({Offset? position}) {
    assert(_anchor != null);
    _anchor!._open(position: position);
  }

  void _attach(_MenuAnchorState anchor) {
    _anchor = anchor;
  }

  void _detach(_MenuAnchorState anchor) {
    if (_anchor == anchor) {
      _anchor = null;
    }
  }
}

class MenuBar extends StatelessWidget {
  const MenuBar({
    super.key,
    this.style,
    this.clipBehavior = Clip.none,
    this.controller,
    required this.children,
  });

  final MenuStyle? style;

  final Clip clipBehavior;

  final MenuController? controller;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasOverlay(context));
    return _MenuBarAnchor(
      controller: controller,
      clipBehavior: clipBehavior,
      style: style,
      menuChildren: children,
    );
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return <DiagnosticsNode>[
      ...children.map<DiagnosticsNode>(
        (Widget item) => item.toDiagnosticsNode(),
      ),
    ];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        DiagnosticsProperty<MenuStyle?>('style', style, defaultValue: null));
    properties.add(DiagnosticsProperty<Clip>('clipBehavior', clipBehavior,
        defaultValue: null));
  }
}

class MenuItemButton extends StatefulWidget {
  const MenuItemButton({
    super.key,
    this.onPressed,
    this.onHover,
    this.requestFocusOnHover = true,
    this.onFocusChange,
    this.focusNode,
    this.shortcut,
    this.style,
    this.statesController,
    this.clipBehavior = Clip.none,
    this.leadingIcon,
    this.trailingIcon,
    this.closeOnActivate = true,
    required this.child,
  });

  final VoidCallback? onPressed;

  final ValueChanged<bool>? onHover;

  final bool requestFocusOnHover;

  final ValueChanged<bool>? onFocusChange;

  final FocusNode? focusNode;

  final MenuSerializableShortcut? shortcut;

  final ButtonStyle? style;

  final MaterialStatesController? statesController;

  final Clip clipBehavior;

  final Widget? leadingIcon;

  final Widget? trailingIcon;

  final bool closeOnActivate;

  final Widget? child;

  bool get enabled => onPressed != null;

  @override
  State<MenuItemButton> createState() => _MenuItemButtonState();

  ButtonStyle defaultStyleOf(BuildContext context) {
    return _MenuButtonDefaultsM3(context);
  }

  ButtonStyle? themeStyleOf(BuildContext context) {
    return MenuButtonTheme.of(context).style;
  }

  static ButtonStyle styleFrom({
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    Color? shadowColor,
    Color? surfaceTintColor,
    Color? iconColor,
    TextStyle? textStyle,
    double? elevation,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    Size? maximumSize,
    MouseCursor? enabledMouseCursor,
    MouseCursor? disabledMouseCursor,
    BorderSide? side,
    OutlinedBorder? shape,
    VisualDensity? visualDensity,
    MaterialTapTargetSize? tapTargetSize,
    Duration? animationDuration,
    bool? enableFeedback,
    AlignmentGeometry? alignment,
    InteractiveInkFeatureFactory? splashFactory,
  }) {
    return TextButton.styleFrom(
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      disabledBackgroundColor: disabledBackgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      iconColor: iconColor,
      textStyle: textStyle,
      elevation: elevation,
      padding: padding,
      minimumSize: minimumSize,
      fixedSize: fixedSize,
      maximumSize: maximumSize,
      enabledMouseCursor: enabledMouseCursor,
      disabledMouseCursor: disabledMouseCursor,
      side: side,
      shape: shape,
      visualDensity: visualDensity,
      tapTargetSize: tapTargetSize,
      animationDuration: animationDuration,
      enableFeedback: enableFeedback,
      alignment: alignment,
      splashFactory: splashFactory,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        FlagProperty('enabled', value: onPressed != null, ifFalse: 'DISABLED'));
    properties.add(
        DiagnosticsProperty<ButtonStyle?>('style', style, defaultValue: null));
    properties.add(DiagnosticsProperty<MenuSerializableShortcut?>(
        'shortcut', shortcut,
        defaultValue: null));
    properties.add(DiagnosticsProperty<FocusNode?>('focusNode', focusNode,
        defaultValue: null));
    properties.add(EnumProperty<Clip>('clipBehavior', clipBehavior,
        defaultValue: Clip.none));
    properties.add(DiagnosticsProperty<MaterialStatesController?>(
        'statesController', statesController,
        defaultValue: null));
  }
}

class _MenuItemButtonState extends State<MenuItemButton> {
  FocusNode? _internalFocusNode;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    _createInternalFocusNodeIfNeeded();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    _internalFocusNode = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(MenuItemButton oldWidget) {
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)
          ?.removeListener(_handleFocusChange);
      if (widget.focusNode != null) {
        _internalFocusNode?.dispose();
        _internalFocusNode = null;
      }
      _createInternalFocusNodeIfNeeded();
      _focusNode.addListener(_handleFocusChange);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    ButtonStyle mergedStyle =
        widget.themeStyleOf(context)?.merge(widget.defaultStyleOf(context)) ??
            widget.defaultStyleOf(context);
    if (widget.style != null) {
      mergedStyle = widget.style!.merge(mergedStyle);
    }

    Widget child = TextButton(
      onPressed: widget.enabled ? _handleSelect : null,
      onHover: widget.enabled ? _handleHover : null,
      onFocusChange: widget.enabled ? widget.onFocusChange : null,
      focusNode: _focusNode,
      style: mergedStyle,
      statesController: widget.statesController,
      clipBehavior: widget.clipBehavior,
      isSemanticButton: null,
      child: _MenuItemLabel(
        leadingIcon: widget.leadingIcon,
        shortcut: widget.shortcut,
        trailingIcon: widget.trailingIcon,
        hasSubmenu: false,
        child: widget.child!,
      ),
    );

    if (_platformSupportsAccelerators && widget.enabled) {
      child = MenuAcceleratorCallbackBinding(
        onInvoke: _handleSelect,
        child: child,
      );
    }

    return MergeSemantics(child: child);
  }

  void _handleFocusChange() {
    if (!_focusNode.hasPrimaryFocus) {
      _MenuAnchorState._maybeOf(context)?._closeChildren();
    }
  }

  void _handleHover(bool hovering) {
    widget.onHover?.call(hovering);
    if (hovering && widget.requestFocusOnHover) {
      assert(_debugMenuInfo('Requesting focus for $_focusNode from hover'));
      _focusNode.requestFocus();
    }
  }

  void _handleSelect() {
    assert(_debugMenuInfo('Selected ${widget.child} menu'));
    if (widget.closeOnActivate) {
      _MenuAnchorState._maybeOf(context)?._root._close();
    }
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      FocusManager.instance.applyFocusChangesIfNeeded();
      widget.onPressed?.call();
    }, debugLabel: 'MenuAnchor.onPressed');
  }

  void _createInternalFocusNodeIfNeeded() {
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
      assert(() {
        if (_internalFocusNode != null) {
          _internalFocusNode!.debugLabel = '$MenuItemButton(${widget.child})';
        }
        return true;
      }());
    }
  }
}

class CheckboxMenuButton extends StatelessWidget {
  const CheckboxMenuButton({
    super.key,
    required this.value,
    this.tristate = false,
    this.isError = false,
    required this.onChanged,
    this.onHover,
    this.onFocusChange,
    this.focusNode,
    this.shortcut,
    this.style,
    this.statesController,
    this.clipBehavior = Clip.none,
    this.trailingIcon,
    this.closeOnActivate = true,
    required this.child,
  });

  final bool? value;

  final bool tristate;

  final bool isError;

  final ValueChanged<bool?>? onChanged;

  final ValueChanged<bool>? onHover;

  final ValueChanged<bool>? onFocusChange;

  final FocusNode? focusNode;

  final MenuSerializableShortcut? shortcut;

  final ButtonStyle? style;

  final MaterialStatesController? statesController;

  final Clip clipBehavior;

  final Widget? trailingIcon;

  final bool closeOnActivate;

  final Widget? child;

  bool get enabled => onChanged != null;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      key: key,
      onPressed: onChanged == null
          ? null
          : () {
              switch (value) {
                case false:
                  onChanged!.call(true);
                case true:
                  onChanged!.call(tristate ? null : false);
                case null:
                  onChanged!.call(false);
              }
            },
      onHover: onHover,
      onFocusChange: onFocusChange,
      focusNode: focusNode,
      style: style,
      shortcut: shortcut,
      statesController: statesController,
      leadingIcon: ExcludeFocus(
        child: IgnorePointer(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: Checkbox.width,
              maxWidth: Checkbox.width,
            ),
            child: Checkbox(
              tristate: tristate,
              value: value,
              onChanged: onChanged,
              isError: isError,
            ),
          ),
        ),
      ),
      clipBehavior: clipBehavior,
      trailingIcon: trailingIcon,
      closeOnActivate: closeOnActivate,
      child: child,
    );
  }
}

class RadioMenuButton<T> extends StatelessWidget {
  const RadioMenuButton({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.toggleable = false,
    this.onHover,
    this.onFocusChange,
    this.focusNode,
    this.shortcut,
    this.style,
    this.statesController,
    this.clipBehavior = Clip.none,
    this.trailingIcon,
    this.closeOnActivate = true,
    required this.child,
  });

  final T value;

  final T? groupValue;

  final bool toggleable;

  final ValueChanged<T?>? onChanged;

  final ValueChanged<bool>? onHover;

  final ValueChanged<bool>? onFocusChange;

  final FocusNode? focusNode;

  final MenuSerializableShortcut? shortcut;

  final ButtonStyle? style;

  final MaterialStatesController? statesController;

  final Clip clipBehavior;

  final Widget? trailingIcon;

  final bool closeOnActivate;

  final Widget? child;

  bool get enabled => onChanged != null;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      key: key,
      onPressed: onChanged == null
          ? null
          : () {
              if (toggleable && groupValue == value) {
                onChanged!.call(null);
                return;
              }
              onChanged!.call(value);
            },
      onHover: onHover,
      onFocusChange: onFocusChange,
      focusNode: focusNode,
      style: style,
      shortcut: shortcut,
      statesController: statesController,
      leadingIcon: ExcludeFocus(
        child: IgnorePointer(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: Checkbox.width,
              maxWidth: Checkbox.width,
            ),
            child: Radio<T>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              toggleable: toggleable,
            ),
          ),
        ),
      ),
      clipBehavior: clipBehavior,
      trailingIcon: trailingIcon,
      closeOnActivate: closeOnActivate,
      child: child,
    );
  }
}

class SubmenuButton extends StatefulWidget {
  const SubmenuButton({
    super.key,
    this.onHover,
    this.onFocusChange,
    this.onOpen,
    this.onClose,
    this.controller,
    this.style,
    this.menuStyle,
    this.alignmentOffset,
    this.clipBehavior = Clip.hardEdge,
    this.focusNode,
    this.statesController,
    this.leadingIcon,
    this.trailingIcon,
    required this.menuChildren,
    required this.child,
  });

  final ValueChanged<bool>? onHover;

  final ValueChanged<bool>? onFocusChange;

  final VoidCallback? onOpen;

  final VoidCallback? onClose;

  final MenuController? controller;

  final ButtonStyle? style;

  final MenuStyle? menuStyle;

  final Offset? alignmentOffset;

  final Clip clipBehavior;

  final FocusNode? focusNode;

  final MaterialStatesController? statesController;

  final Widget? leadingIcon;

  final Widget? trailingIcon;

  final List<Widget> menuChildren;

  final Widget? child;

  @override
  State<SubmenuButton> createState() => _SubmenuButtonState();

  ButtonStyle defaultStyleOf(BuildContext context) {
    return _MenuButtonDefaultsM3(context);
  }

  ButtonStyle? themeStyleOf(BuildContext context) {
    return MenuButtonTheme.of(context).style;
  }

  static ButtonStyle styleFrom({
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    Color? shadowColor,
    Color? surfaceTintColor,
    Color? iconColor,
    TextStyle? textStyle,
    double? elevation,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    Size? maximumSize,
    MouseCursor? enabledMouseCursor,
    MouseCursor? disabledMouseCursor,
    BorderSide? side,
    OutlinedBorder? shape,
    VisualDensity? visualDensity,
    MaterialTapTargetSize? tapTargetSize,
    Duration? animationDuration,
    bool? enableFeedback,
    AlignmentGeometry? alignment,
    InteractiveInkFeatureFactory? splashFactory,
  }) {
    return TextButton.styleFrom(
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      disabledBackgroundColor: disabledBackgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      iconColor: iconColor,
      textStyle: textStyle,
      elevation: elevation,
      padding: padding,
      minimumSize: minimumSize,
      fixedSize: fixedSize,
      maximumSize: maximumSize,
      enabledMouseCursor: enabledMouseCursor,
      disabledMouseCursor: disabledMouseCursor,
      side: side,
      shape: shape,
      visualDensity: visualDensity,
      tapTargetSize: tapTargetSize,
      animationDuration: animationDuration,
      enableFeedback: enableFeedback,
      alignment: alignment,
      splashFactory: splashFactory,
    );
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return <DiagnosticsNode>[
      ...menuChildren.map<DiagnosticsNode>((Widget child) {
        return child.toDiagnosticsNode();
      })
    ];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<FocusNode?>('focusNode', focusNode));
    properties.add(DiagnosticsProperty<MenuStyle>('menuStyle', menuStyle,
        defaultValue: null));
    properties
        .add(DiagnosticsProperty<Offset>('alignmentOffset', alignmentOffset));
    properties.add(EnumProperty<Clip>('clipBehavior', clipBehavior));
  }
}

class _SubmenuButtonState extends State<SubmenuButton> {
  FocusNode? _internalFocusNode;
  bool _waitingToFocusMenu = false;
  MenuController? _internalMenuController;

  MenuController get _menuController =>
      widget.controller ?? _internalMenuController!;

  _MenuAnchorState? get _anchor => _MenuAnchorState._maybeOf(context);

  FocusNode get _buttonFocusNode => widget.focusNode ?? _internalFocusNode!;

  bool get _enabled => widget.menuChildren.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
      assert(() {
        if (_internalFocusNode != null) {
          _internalFocusNode!.debugLabel = '$SubmenuButton(${widget.child})';
        }
        return true;
      }());
    }
    if (widget.controller == null) {
      _internalMenuController = MenuController();
    }
    _buttonFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _buttonFocusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    _internalFocusNode = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(SubmenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _internalFocusNode?.removeListener(_handleFocusChange);
        _internalFocusNode?.dispose();
        _internalFocusNode = null;
      } else {
        oldWidget.focusNode!.removeListener(_handleFocusChange);
      }
      if (widget.focusNode == null) {
        _internalFocusNode ??= FocusNode();
        assert(() {
          if (_internalFocusNode != null) {
            _internalFocusNode!.debugLabel = '$SubmenuButton(${widget.child})';
          }
          return true;
        }());
      }
      _buttonFocusNode.addListener(_handleFocusChange);
    }
    if (widget.controller != oldWidget.controller) {
      _internalMenuController =
          (oldWidget.controller == null) ? null : MenuController();
    }
  }

  @override
  Widget build(BuildContext context) {
    Offset menuPaddingOffset = widget.alignmentOffset ?? Offset.zero;
    final EdgeInsets menuPadding = _computeMenuPadding(context);
    final Axis orientation = _anchor?._orientation ?? Axis.vertical;
    menuPaddingOffset += switch ((orientation, Directionality.of(context))) {
      (Axis.horizontal, TextDirection.rtl) => Offset(menuPadding.right, 0),
      (Axis.horizontal, TextDirection.ltr) => Offset(-menuPadding.left, 0),
      (Axis.vertical, TextDirection.rtl) => Offset(0, -menuPadding.top),
      (Axis.vertical, TextDirection.ltr) => Offset(0, -menuPadding.top),
    };

    return MenuAnchor(
      controller: _menuController,
      childFocusNode: _buttonFocusNode,
      alignmentOffset: menuPaddingOffset,
      clipBehavior: widget.clipBehavior,
      onClose: widget.onClose,
      onOpen: () {
        if (!_waitingToFocusMenu) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _menuController._anchor?._focusButton();
            _waitingToFocusMenu = false;
          }, debugLabel: 'MenuAnchor.focus');
          _waitingToFocusMenu = true;
        }
        setState(() {
          /* Rebuild with updated controller.isOpen value */
        });
        widget.onOpen?.call();
      },
      style: widget.menuStyle,
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
        ButtonStyle mergedStyle = widget
                .themeStyleOf(context)
                ?.merge(widget.defaultStyleOf(context)) ??
            widget.defaultStyleOf(context);
        mergedStyle = widget.style?.merge(mergedStyle) ?? mergedStyle;

        void toggleShowMenu(BuildContext context) {
          if (controller._anchor == null) {
            return;
          }
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }

        void handleHover(bool hovering, BuildContext context) {
          widget.onHover?.call(hovering);
          if (controller._anchor!._root._orientation == Axis.horizontal &&
              !controller._anchor!._root._isOpen) {
            return;
          }

          if (hovering) {
            controller.open();
            controller._anchor!._focusButton();
          }
        }

        child = MergeSemantics(
          child: Semantics(
            expanded: _enabled && controller.isOpen,
            child: TextButton(
              style: mergedStyle,
              focusNode: _buttonFocusNode,
              onFocusChange: _enabled ? widget.onFocusChange : null,
              onHover: _enabled
                  ? (bool hovering) => handleHover(hovering, context)
                  : null,
              onPressed: _enabled ? () => toggleShowMenu(context) : null,
              isSemanticButton: null,
              child: _MenuItemLabel(
                leadingIcon: widget.leadingIcon,
                trailingIcon: widget.trailingIcon,
                hasSubmenu: true,
                showDecoration: (controller._anchor!._parent?._orientation ??
                        Axis.horizontal) ==
                    Axis.vertical,
                child: child ?? const SizedBox(),
              ),
            ),
          ),
        );

        if (_enabled && _platformSupportsAccelerators) {
          return MenuAcceleratorCallbackBinding(
            onInvoke: () => toggleShowMenu(context),
            hasSubmenu: true,
            child: child,
          );
        }
        return child;
      },
      menuChildren: widget.menuChildren,
      child: widget.child,
    );
  }

  EdgeInsets _computeMenuPadding(BuildContext context) {
    final MaterialStateProperty<EdgeInsetsGeometry?> insets =
        widget.menuStyle?.padding ??
            MenuTheme.of(context).style?.padding ??
            _MenuDefaultsM3(context).padding!;
    return insets
        .resolve(widget.statesController?.value ?? const <MaterialState>{})!
        .resolve(Directionality.of(context));
  }

  void _handleFocusChange() {
    if (_buttonFocusNode.hasPrimaryFocus) {
      if (!_menuController.isOpen) {
        _menuController.open();
      }
    } else {
      if (!_menuController._anchor!._menuScopeNode.hasFocus &&
          _menuController.isOpen) {
        _menuController.close();
      }
    }
  }
}

class DismissMenuAction extends DismissAction {
  DismissMenuAction({required this.controller});

  final MenuController controller;

  @override
  void invoke(DismissIntent intent) {
    assert(_debugMenuInfo('$runtimeType: Dismissing all open menus.'));
    controller._anchor!._root._close();
  }

  @override
  bool isEnabled(DismissIntent intent) {
    return controller.isOpen;
  }
}

class _LocalizedShortcutLabeler {
  _LocalizedShortcutLabeler._();

  static _LocalizedShortcutLabeler? _instance;

  static final Map<LogicalKeyboardKey, String> _shortcutGraphicEquivalents =
      <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.arrowLeft: '←',
    LogicalKeyboardKey.arrowRight: '→',
    LogicalKeyboardKey.arrowUp: '↑',
    LogicalKeyboardKey.arrowDown: '↓',
    LogicalKeyboardKey.enter: '↵',
  };

  static final Set<LogicalKeyboardKey> _modifiers = <LogicalKeyboardKey>{
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.shiftRight,
  };

  static _LocalizedShortcutLabeler get instance {
    return _instance ??= _LocalizedShortcutLabeler._();
  }

  final Map<MaterialLocalizations, Map<LogicalKeyboardKey, String>>
      _cachedShortcutKeys =
      <MaterialLocalizations, Map<LogicalKeyboardKey, String>>{};

  String getShortcutLabel(
      MenuSerializableShortcut shortcut, MaterialLocalizations localizations) {
    final ShortcutSerialization serialized = shortcut.serializeForMenu();
    final String keySeparator;
    if (_usesSymbolicModifiers) {
      keySeparator = ' ';
    } else {
      keySeparator = '+';
    }
    if (serialized.trigger != null) {
      final List<String> modifiers = <String>[];
      final LogicalKeyboardKey trigger = serialized.trigger!;
      if (_usesSymbolicModifiers) {
        if (serialized.control!) {
          modifiers.add(
              _getModifierLabel(LogicalKeyboardKey.control, localizations));
        }
        if (serialized.alt!) {
          modifiers
              .add(_getModifierLabel(LogicalKeyboardKey.alt, localizations));
        }
        if (serialized.shift!) {
          modifiers
              .add(_getModifierLabel(LogicalKeyboardKey.shift, localizations));
        }
        if (serialized.meta!) {
          modifiers
              .add(_getModifierLabel(LogicalKeyboardKey.meta, localizations));
        }
      } else {
        if (serialized.alt!) {
          modifiers
              .add(_getModifierLabel(LogicalKeyboardKey.alt, localizations));
        }
        if (serialized.control!) {
          modifiers.add(
              _getModifierLabel(LogicalKeyboardKey.control, localizations));
        }
        if (serialized.meta!) {
          modifiers
              .add(_getModifierLabel(LogicalKeyboardKey.meta, localizations));
        }
        if (serialized.shift!) {
          modifiers
              .add(_getModifierLabel(LogicalKeyboardKey.shift, localizations));
        }
      }
      String? shortcutTrigger;
      final int logicalKeyId = trigger.keyId;
      if (_shortcutGraphicEquivalents.containsKey(trigger)) {
        shortcutTrigger = _shortcutGraphicEquivalents[trigger];
      } else {
        shortcutTrigger = _getLocalizedName(trigger, localizations);
        if (shortcutTrigger == null &&
            logicalKeyId & LogicalKeyboardKey.planeMask == 0x0) {
          shortcutTrigger =
              String.fromCharCode(logicalKeyId & LogicalKeyboardKey.valueMask)
                  .toUpperCase();
        }
        shortcutTrigger ??= trigger.keyLabel;
      }
      return <String>[
        ...modifiers,
        if (shortcutTrigger != null && shortcutTrigger.isNotEmpty)
          shortcutTrigger,
      ].join(keySeparator);
    } else if (serialized.character != null) {
      return serialized.character!;
    }
    throw UnimplementedError(
        'Shortcut labels for ShortcutActivators that do not implement '
        'MenuSerializableShortcut (e.g. ShortcutActivators other than SingleActivator or '
        'CharacterActivator) are not supported.');
  }

  String? _getLocalizedName(
      LogicalKeyboardKey key, MaterialLocalizations localizations) {
    _cachedShortcutKeys[localizations] ??= <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.altGraph: localizations.keyboardKeyAltGraph,
      LogicalKeyboardKey.backspace: localizations.keyboardKeyBackspace,
      LogicalKeyboardKey.capsLock: localizations.keyboardKeyCapsLock,
      LogicalKeyboardKey.channelDown: localizations.keyboardKeyChannelDown,
      LogicalKeyboardKey.channelUp: localizations.keyboardKeyChannelUp,
      LogicalKeyboardKey.delete: localizations.keyboardKeyDelete,
      LogicalKeyboardKey.eject: localizations.keyboardKeyEject,
      LogicalKeyboardKey.end: localizations.keyboardKeyEnd,
      LogicalKeyboardKey.escape: localizations.keyboardKeyEscape,
      LogicalKeyboardKey.fn: localizations.keyboardKeyFn,
      LogicalKeyboardKey.home: localizations.keyboardKeyHome,
      LogicalKeyboardKey.insert: localizations.keyboardKeyInsert,
      LogicalKeyboardKey.numLock: localizations.keyboardKeyNumLock,
      LogicalKeyboardKey.numpad1: localizations.keyboardKeyNumpad1,
      LogicalKeyboardKey.numpad2: localizations.keyboardKeyNumpad2,
      LogicalKeyboardKey.numpad3: localizations.keyboardKeyNumpad3,
      LogicalKeyboardKey.numpad4: localizations.keyboardKeyNumpad4,
      LogicalKeyboardKey.numpad5: localizations.keyboardKeyNumpad5,
      LogicalKeyboardKey.numpad6: localizations.keyboardKeyNumpad6,
      LogicalKeyboardKey.numpad7: localizations.keyboardKeyNumpad7,
      LogicalKeyboardKey.numpad8: localizations.keyboardKeyNumpad8,
      LogicalKeyboardKey.numpad9: localizations.keyboardKeyNumpad9,
      LogicalKeyboardKey.numpad0: localizations.keyboardKeyNumpad0,
      LogicalKeyboardKey.numpadAdd: localizations.keyboardKeyNumpadAdd,
      LogicalKeyboardKey.numpadComma: localizations.keyboardKeyNumpadComma,
      LogicalKeyboardKey.numpadDecimal: localizations.keyboardKeyNumpadDecimal,
      LogicalKeyboardKey.numpadDivide: localizations.keyboardKeyNumpadDivide,
      LogicalKeyboardKey.numpadEnter: localizations.keyboardKeyNumpadEnter,
      LogicalKeyboardKey.numpadEqual: localizations.keyboardKeyNumpadEqual,
      LogicalKeyboardKey.numpadMultiply:
          localizations.keyboardKeyNumpadMultiply,
      LogicalKeyboardKey.numpadParenLeft:
          localizations.keyboardKeyNumpadParenLeft,
      LogicalKeyboardKey.numpadParenRight:
          localizations.keyboardKeyNumpadParenRight,
      LogicalKeyboardKey.numpadSubtract:
          localizations.keyboardKeyNumpadSubtract,
      LogicalKeyboardKey.pageDown: localizations.keyboardKeyPageDown,
      LogicalKeyboardKey.pageUp: localizations.keyboardKeyPageUp,
      LogicalKeyboardKey.power: localizations.keyboardKeyPower,
      LogicalKeyboardKey.powerOff: localizations.keyboardKeyPowerOff,
      LogicalKeyboardKey.printScreen: localizations.keyboardKeyPrintScreen,
      LogicalKeyboardKey.scrollLock: localizations.keyboardKeyScrollLock,
      LogicalKeyboardKey.select: localizations.keyboardKeySelect,
      LogicalKeyboardKey.space: localizations.keyboardKeySpace,
    };
    return _cachedShortcutKeys[localizations]![key];
  }

  String _getModifierLabel(
      LogicalKeyboardKey modifier, MaterialLocalizations localizations) {
    assert(_modifiers.contains(modifier),
        '${modifier.keyLabel} is not a modifier key');
    if (modifier == LogicalKeyboardKey.meta ||
        modifier == LogicalKeyboardKey.metaLeft ||
        modifier == LogicalKeyboardKey.metaRight) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
          return localizations.keyboardKeyMeta;
        case TargetPlatform.windows:
          return localizations.keyboardKeyMetaWindows;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          return '⌘';
      }
    }
    if (modifier == LogicalKeyboardKey.alt ||
        modifier == LogicalKeyboardKey.altLeft ||
        modifier == LogicalKeyboardKey.altRight) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          return localizations.keyboardKeyAlt;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          return '⌥';
      }
    }
    if (modifier == LogicalKeyboardKey.control ||
        modifier == LogicalKeyboardKey.controlLeft ||
        modifier == LogicalKeyboardKey.controlRight) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          return localizations.keyboardKeyControl;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          return '⌃';
      }
    }
    if (modifier == LogicalKeyboardKey.shift ||
        modifier == LogicalKeyboardKey.shiftLeft ||
        modifier == LogicalKeyboardKey.shiftRight) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          return localizations.keyboardKeyShift;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          return '⇧';
      }
    }
    throw ArgumentError('Keyboard key ${modifier.keyLabel} is not a modifier.');
  }
}

class _MenuAnchorScope extends InheritedWidget {
  const _MenuAnchorScope({
    required super.child,
    required this.anchorKey,
    required this.anchor,
    required this.isOpen,
  });

  final GlobalKey anchorKey;
  final _MenuAnchorState anchor;
  final bool isOpen;

  @override
  bool updateShouldNotify(_MenuAnchorScope oldWidget) {
    return anchorKey != oldWidget.anchorKey ||
        anchor != oldWidget.anchor ||
        isOpen != oldWidget.isOpen;
  }
}

class _MenuBarAnchor extends MenuAnchor {
  const _MenuBarAnchor({
    required super.menuChildren,
    super.controller,
    super.clipBehavior,
    super.style,
  });

  @override
  State<MenuAnchor> createState() => _MenuBarAnchorState();
}

class _MenuBarAnchorState extends _MenuAnchorState {
  @override
  bool get _isOpen {
    for (final _MenuAnchorState child in _anchorChildren) {
      if (child._isOpen) {
        return true;
      }
    }
    return false;
  }

  @override
  Axis get _orientation => Axis.horizontal;

  @override
  Widget _buildContents(BuildContext context) {
    final bool isOpen = _isOpen;
    return FocusScope(
      node: _menuScopeNode,
      skipTraversal: !isOpen,
      canRequestFocus: isOpen,
      child: ExcludeFocus(
        excluding: !isOpen,
        child: Shortcuts(
          shortcuts: _kMenuTraversalShortcuts,
          child: Actions(
            actions: <Type, Action<Intent>>{
              DirectionalFocusIntent: _MenuDirectionalFocusAction(),
              PreviousFocusIntent: _MenuPreviousFocusAction(),
              NextFocusIntent: _MenuNextFocusAction(),
              DismissIntent: DismissMenuAction(controller: _menuController),
            },
            child: Builder(builder: (BuildContext context) {
              return _MenuPanel(
                menuStyle: widget.style,
                clipBehavior: widget.clipBehavior,
                orientation: Axis.horizontal,
                children: widget.menuChildren,
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  void _open({Offset? position}) {
    assert(_menuController._anchor == this);
    return;
  }
}

class _MenuPreviousFocusAction extends PreviousFocusAction {
  @override
  bool invoke(PreviousFocusIntent intent) {
    assert(_debugMenuInfo('_MenuNextFocusAction invoked with $intent'));
    final BuildContext? context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      return super.invoke(intent);
    }
    final _MenuAnchorState? anchor = _MenuAnchorState._maybeOf(context);
    if (anchor == null || !anchor._root._isOpen) {
      return super.invoke(intent);
    }

    return _moveToPreviousFocusable(anchor);
  }

  static bool _moveToPreviousFocusable(_MenuAnchorState currentMenu) {
    final _MenuAnchorState? sibling = currentMenu._previousFocusableSibling;
    sibling?._focusButton();
    return true;
  }
}

class _MenuNextFocusAction extends NextFocusAction {
  @override
  bool invoke(NextFocusIntent intent) {
    assert(_debugMenuInfo('_MenuNextFocusAction invoked with $intent'));
    final BuildContext? context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      return super.invoke(intent);
    }
    final _MenuAnchorState? anchor = _MenuAnchorState._maybeOf(context);
    if (anchor == null || !anchor._root._isOpen) {
      return super.invoke(intent);
    }

    return _moveToNextFocusable(anchor);
  }

  static bool _moveToNextFocusable(_MenuAnchorState currentMenu) {
    final _MenuAnchorState? sibling = currentMenu._nextFocusableSibling;
    sibling?._focusButton();
    return true;
  }
}

class _MenuDirectionalFocusAction extends DirectionalFocusAction {
  _MenuDirectionalFocusAction();

  @override
  void invoke(DirectionalFocusIntent intent) {
    assert(_debugMenuInfo('_MenuDirectionalFocusAction invoked with $intent'));
    final BuildContext? context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      super.invoke(intent);
      return;
    }
    final _MenuAnchorState? anchor = _MenuAnchorState._maybeOf(context);
    if (anchor == null || !anchor._root._isOpen) {
      super.invoke(intent);
      return;
    }
    final bool buttonIsFocused =
        anchor.widget.childFocusNode?.hasPrimaryFocus ?? false;
    final Axis? parentOrientation = anchor._parent?._orientation;
    final Axis orientation =
        (buttonIsFocused ? parentOrientation : null) ?? anchor._orientation;
    final bool differentParent = orientation != parentOrientation;
    final bool firstItemIsFocused =
        anchor._firstItemFocusNode?.hasPrimaryFocus ?? false;
    final bool rtl = switch (Directionality.of(context)) {
      TextDirection.rtl => true,
      TextDirection.ltr => false,
    };

    assert(_debugMenuInfo(
        'In _MenuDirectionalFocusAction, current node is ${anchor.widget.childFocusNode?.debugLabel}, '
        'button is${buttonIsFocused ? '' : ' not'} focused. Assuming ${orientation.name} orientation.'));

    final bool Function(_MenuAnchorState) traversal =
        switch ((intent.direction, orientation)) {
      (TraversalDirection.up, Axis.horizontal) => _moveToParent,
      (TraversalDirection.up, Axis.vertical) =>
        firstItemIsFocused ? _moveToParent : _moveToPrevious,
      (TraversalDirection.down, Axis.horizontal) => _moveToSubmenu,
      (TraversalDirection.down, Axis.vertical) => _moveToNext,
      (TraversalDirection.left, Axis.horizontal) =>
        rtl ? _moveToNext : _moveToPrevious,
      (TraversalDirection.right, Axis.horizontal) =>
        rtl ? _moveToPrevious : _moveToNext,
      (TraversalDirection.left, Axis.vertical) when rtl =>
        buttonIsFocused ? _moveToSubmenu : _moveToNextFocusableTopLevel,
      (TraversalDirection.left, Axis.vertical) when differentParent =>
        _moveToPreviousFocusableTopLevel,
      (TraversalDirection.left, Axis.vertical) =>
        buttonIsFocused ? _moveToPreviousFocusableTopLevel : _moveToParent,
      (TraversalDirection.right, Axis.vertical) when !rtl =>
        buttonIsFocused ? _moveToSubmenu : _moveToNextFocusableTopLevel,
      (TraversalDirection.right, Axis.vertical) when differentParent =>
        _moveToPreviousFocusableTopLevel,
      (TraversalDirection.right, Axis.vertical) =>
        buttonIsFocused ? _moveToPreviousFocusableTopLevel : _moveToParent,
    };
    if (!traversal(anchor)) {
      super.invoke(intent);
    }
  }

  bool _moveToNext(_MenuAnchorState currentMenu) {
    assert(_debugMenuInfo('Moving focus to next item in menu'));
    if (currentMenu.widget.childFocusNode != null) {
      if (currentMenu.widget.childFocusNode!.nearestScope != null) {
        final FocusTraversalPolicy? policy =
            FocusTraversalGroup.maybeOf(primaryFocus!.context!);
        policy?.invalidateScopeData(
            currentMenu.widget.childFocusNode!.nearestScope!);
      }
    }
    return false;
  }

  bool _moveToNextFocusableTopLevel(_MenuAnchorState currentMenu) {
    final _MenuAnchorState? sibling =
        currentMenu._topLevel._nextFocusableSibling;
    sibling?._focusButton();
    return true;
  }

  bool _moveToParent(_MenuAnchorState currentMenu) {
    assert(_debugMenuInfo('Moving focus to parent menu button'));
    if (!(currentMenu.widget.childFocusNode?.hasPrimaryFocus ?? true)) {
      currentMenu._focusButton();
    }
    return true;
  }

  bool _moveToPrevious(_MenuAnchorState currentMenu) {
    assert(_debugMenuInfo('Moving focus to previous item in menu'));
    if (currentMenu.widget.childFocusNode != null) {
      if (currentMenu.widget.childFocusNode!.nearestScope != null) {
        final FocusTraversalPolicy? policy =
            FocusTraversalGroup.maybeOf(primaryFocus!.context!);
        policy?.invalidateScopeData(
            currentMenu.widget.childFocusNode!.nearestScope!);
      }
    }
    return false;
  }

  bool _moveToPreviousFocusableTopLevel(_MenuAnchorState currentMenu) {
    final _MenuAnchorState? sibling =
        currentMenu._topLevel._previousFocusableSibling;
    sibling?._focusButton();
    return true;
  }

  bool _moveToSubmenu(_MenuAnchorState currentMenu) {
    assert(_debugMenuInfo('Opening submenu'));
    if (!currentMenu._isOpen) {
      currentMenu._open();
      return true;
    } else {
      final FocusNode? firstNode = currentMenu._firstItemFocusNode;
      if (firstNode != null && firstNode.nearestScope != firstNode) {
        firstNode.requestFocus();
      }
      return true;
    }
  }
}

class MenuAcceleratorCallbackBinding extends InheritedWidget {
  const MenuAcceleratorCallbackBinding({
    super.key,
    this.onInvoke,
    this.hasSubmenu = false,
    required super.child,
  });

  final VoidCallback? onInvoke;

  final bool hasSubmenu;

  @override
  bool updateShouldNotify(MenuAcceleratorCallbackBinding oldWidget) {
    return onInvoke != oldWidget.onInvoke || hasSubmenu != oldWidget.hasSubmenu;
  }

  static MenuAcceleratorCallbackBinding? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MenuAcceleratorCallbackBinding>();
  }

  static MenuAcceleratorCallbackBinding of(BuildContext context) {
    final MenuAcceleratorCallbackBinding? result = maybeOf(context);
    assert(() {
      if (result == null) {
        throw FlutterError(
          'MenuAcceleratorWrapper.of() was called with a context that does not '
          'contain a MenuAcceleratorWrapper in the given context.\n'
          'No MenuAcceleratorWrapper ancestor could be found in the context that '
          'was passed to MenuAcceleratorWrapper.of(). This can happen because '
          'you are using a widget that looks for a MenuAcceleratorWrapper '
          'ancestor, and do not have a MenuAcceleratorWrapper widget ancestor.\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return result!;
  }
}

typedef MenuAcceleratorChildBuilder = Widget Function(
  BuildContext context,
  String label,
  int index,
);

class MenuAcceleratorLabel extends StatefulWidget {
  const MenuAcceleratorLabel(
    this.label, {
    super.key,
    this.builder = defaultLabelBuilder,
  });

  final String label;

  String get displayLabel => stripAcceleratorMarkers(label);

  final MenuAcceleratorChildBuilder builder;

  bool get hasAccelerator => RegExp(r'&(?!([&\s]|$))').hasMatch(label);

  static Widget defaultLabelBuilder(
    BuildContext context,
    String label,
    int index,
  ) {
    if (index < 0) {
      return Text(label);
    }
    final TextStyle defaultStyle = DefaultTextStyle.of(context).style;
    final Characters characters = label.characters;
    return RichText(
      text: TextSpan(
        children: <TextSpan>[
          if (index > 0)
            TextSpan(
                text: characters.getRange(0, index).toString(),
                style: defaultStyle),
          TextSpan(
            text: characters.getRange(index, index + 1).toString(),
            style: defaultStyle.copyWith(decoration: TextDecoration.underline),
          ),
          if (index < characters.length - 1)
            TextSpan(
                text: characters.getRange(index + 1).toString(),
                style: defaultStyle),
        ],
      ),
    );
  }

  static String stripAcceleratorMarkers(String label,
      {void Function(int index)? setIndex}) {
    int quotedAmpersands = 0;
    final StringBuffer displayLabel = StringBuffer();
    int acceleratorIndex = -1;
    final Characters labelChars = label.characters;
    final Characters ampersand = '&'.characters;
    bool lastWasAmpersand = false;
    for (int i = 0; i < labelChars.length; i += 1) {
      final Characters character = labelChars.characterAt(i);
      if (lastWasAmpersand) {
        lastWasAmpersand = false;
        displayLabel.write(character);
        continue;
      }
      if (character != ampersand) {
        displayLabel.write(character);
        continue;
      }
      if (i == labelChars.length - 1) {
        break;
      }
      lastWasAmpersand = true;
      final Characters acceleratorCharacter = labelChars.characterAt(i + 1);
      if (acceleratorIndex == -1 &&
          acceleratorCharacter != ampersand &&
          acceleratorCharacter.toString().trim().isNotEmpty) {
        acceleratorIndex = i - quotedAmpersands;
      }
      quotedAmpersands += 1;
    }
    setIndex?.call(acceleratorIndex);
    return displayLabel.toString();
  }

  @override
  State<MenuAcceleratorLabel> createState() => _MenuAcceleratorLabelState();

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return '$MenuAcceleratorLabel("$label")';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
  }
}

class _MenuAcceleratorLabelState extends State<MenuAcceleratorLabel> {
  late String _displayLabel;
  int _acceleratorIndex = -1;
  MenuAcceleratorCallbackBinding? _binding;
  _MenuAnchorState? _anchor;
  ShortcutRegistry? _shortcutRegistry;
  ShortcutRegistryEntry? _shortcutRegistryEntry;
  bool _showAccelerators = false;

  @override
  void initState() {
    super.initState();
    if (_platformSupportsAccelerators) {
      _showAccelerators = _altIsPressed();
      HardwareKeyboard.instance.addHandler(_listenToKeyEvent);
    }
    _updateDisplayLabel();
  }

  @override
  void dispose() {
    assert(_platformSupportsAccelerators || _shortcutRegistryEntry == null);
    _displayLabel = '';
    if (_platformSupportsAccelerators) {
      _shortcutRegistryEntry?.dispose();
      _shortcutRegistryEntry = null;
      _shortcutRegistry = null;
      _anchor = null;
      HardwareKeyboard.instance.removeHandler(_listenToKeyEvent);
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_platformSupportsAccelerators) {
      return;
    }
    _binding = MenuAcceleratorCallbackBinding.maybeOf(context);
    _anchor = _MenuAnchorState._maybeOf(context);
    _shortcutRegistry = ShortcutRegistry.maybeOf(context);
    _updateAcceleratorShortcut();
  }

  @override
  void didUpdateWidget(MenuAcceleratorLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.label != oldWidget.label) {
      _updateDisplayLabel();
    }
  }

  static bool _altIsPressed() {
    return HardwareKeyboard.instance.logicalKeysPressed.intersection(
      <LogicalKeyboardKey>{
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.altRight,
        LogicalKeyboardKey.alt,
      },
    ).isNotEmpty;
  }

  bool _listenToKeyEvent(KeyEvent event) {
    assert(_platformSupportsAccelerators);
    setState(() {
      _showAccelerators = _altIsPressed();
      _updateAcceleratorShortcut();
    });
    return false;
  }

  void _updateAcceleratorShortcut() {
    assert(_platformSupportsAccelerators);
    _shortcutRegistryEntry?.dispose();
    _shortcutRegistryEntry = null;
    if (_showAccelerators &&
        _acceleratorIndex != -1 &&
        _binding?.onInvoke != null &&
        (!_binding!.hasSubmenu || !(_anchor?._isOpen ?? false))) {
      final String acceleratorCharacter =
          _displayLabel[_acceleratorIndex].toLowerCase();
      _shortcutRegistryEntry = _shortcutRegistry?.addAll(
        <ShortcutActivator, Intent>{
          CharacterActivator(acceleratorCharacter, alt: true):
              VoidCallbackIntent(_binding!.onInvoke!),
        },
      );
    }
  }

  void _updateDisplayLabel() {
    _displayLabel = MenuAcceleratorLabel.stripAcceleratorMarkers(
      widget.label,
      setIndex: (int index) {
        _acceleratorIndex = index;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int index = _showAccelerators ? _acceleratorIndex : -1;
    return widget.builder(context, _displayLabel, index);
  }
}

class _MenuItemLabel extends StatelessWidget {
  const _MenuItemLabel({
    required this.hasSubmenu,
    this.showDecoration = true,
    this.leadingIcon,
    this.trailingIcon,
    this.shortcut,
    required this.child,
  });

  final bool hasSubmenu;

  final bool showDecoration;

  final Widget? leadingIcon;

  final Widget? trailingIcon;

  final MenuSerializableShortcut? shortcut;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final VisualDensity density = Theme.of(context).visualDensity;
    final double horizontalPadding = math.max(
      _kLabelItemMinSpacing,
      _kLabelItemDefaultSpacing + density.horizontal * 2,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leadingIcon != null) leadingIcon!,
            Padding(
              padding: leadingIcon != null
                  ? EdgeInsetsDirectional.only(start: horizontalPadding)
                  : EdgeInsets.zero,
              child: child,
            ),
          ],
        ),
        if (trailingIcon != null)
          Padding(
            padding: EdgeInsetsDirectional.only(start: horizontalPadding),
            child: trailingIcon,
          ),
        if (showDecoration && shortcut != null)
          Padding(
            padding: EdgeInsetsDirectional.only(start: horizontalPadding),
            child: Text(
              _LocalizedShortcutLabeler.instance.getShortcutLabel(
                shortcut!,
                MaterialLocalizations.of(context),
              ),
            ),
          ),
        if (showDecoration && hasSubmenu)
          Padding(
            padding: EdgeInsetsDirectional.only(start: horizontalPadding),
            child: const Icon(
              Icons.arrow_right,
              size: _kDefaultSubmenuIconSize,
            ),
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MenuSerializableShortcut>(
        'shortcut', shortcut,
        defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('hasSubmenu', hasSubmenu));
    properties.add(DiagnosticsProperty<bool>('showDecoration', showDecoration));
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout({
    required this.anchorRect,
    required this.textDirection,
    required this.alignment,
    required this.alignmentOffset,
    required this.menuPosition,
    required this.menuPadding,
    required this.avoidBounds,
    required this.orientation,
    required this.parentOrientation,
  });

  final Rect anchorRect;

  final TextDirection textDirection;

  final AlignmentGeometry alignment;

  final Offset alignmentOffset;

  final Offset? menuPosition;

  final EdgeInsetsGeometry menuPadding;

  final Set<Rect> avoidBounds;

  final Axis orientation;

  final Axis parentOrientation;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest).deflate(
      const EdgeInsets.all(_kMenuViewPadding),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final Rect overlayRect = Offset.zero & size;
    double x;
    double y;
    if (menuPosition == null) {
      Offset desiredPosition =
          alignment.resolve(textDirection).withinRect(anchorRect);
      final Offset directionalOffset;
      if (alignment is AlignmentDirectional) {
        directionalOffset = switch (textDirection) {
          TextDirection.rtl => Offset(-alignmentOffset.dx, alignmentOffset.dy),
          TextDirection.ltr => alignmentOffset,
        };
      } else {
        directionalOffset = alignmentOffset;
      }
      desiredPosition += directionalOffset;
      x = desiredPosition.dx;
      y = desiredPosition.dy;
      switch (textDirection) {
        case TextDirection.rtl:
          x -= childSize.width;
        case TextDirection.ltr:
          break;
      }
    } else {
      final Offset adjustedPosition = menuPosition! + anchorRect.topLeft;
      x = adjustedPosition.dx;
      y = adjustedPosition.dy;
    }

    final Iterable<Rect> subScreens =
        DisplayFeatureSubScreen.subScreensInBounds(overlayRect, avoidBounds);
    final Rect allowedRect = _closestScreen(subScreens, anchorRect.center);
    bool offLeftSide(double x) => x < allowedRect.left;
    bool offRightSide(double x) => x + childSize.width > allowedRect.right;
    bool offTop(double y) => y < allowedRect.top;
    bool offBottom(double y) => y + childSize.height > allowedRect.bottom;
    if (childSize.width >= allowedRect.width) {
      x = allowedRect.left;
    } else {
      if (offLeftSide(x)) {
        if (parentOrientation != orientation) {
          x = allowedRect.left;
        } else {
          final double newX = anchorRect.right + alignmentOffset.dx;
          if (!offRightSide(newX)) {
            x = newX;
          } else {
            x = allowedRect.left;
          }
        }
      } else if (offRightSide(x)) {
        if (parentOrientation != orientation) {
          x = allowedRect.right - childSize.width;
        } else {
          final double newX =
              anchorRect.left - childSize.width - alignmentOffset.dx;
          if (!offLeftSide(newX)) {
            x = newX;
          } else {
            x = allowedRect.right - childSize.width;
          }
        }
      }
    }
    if (childSize.height >= allowedRect.height) {
      y = allowedRect.top;
    } else {
      if (offTop(y)) {
        final double newY = anchorRect.bottom;
        if (!offBottom(newY)) {
          y = newY;
        } else {
          y = allowedRect.top;
        }
      } else if (offBottom(y)) {
        final double newY = anchorRect.top - childSize.height;
        if (!offTop(newY)) {
          if (parentOrientation == Axis.horizontal) {
            y = newY - alignmentOffset.dy;
          } else {
            y = newY;
          }
        } else {
          y = allowedRect.bottom - childSize.height;
        }
      }
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) {
    return anchorRect != oldDelegate.anchorRect ||
        textDirection != oldDelegate.textDirection ||
        alignment != oldDelegate.alignment ||
        alignmentOffset != oldDelegate.alignmentOffset ||
        menuPosition != oldDelegate.menuPosition ||
        menuPadding != oldDelegate.menuPadding ||
        orientation != oldDelegate.orientation ||
        parentOrientation != oldDelegate.parentOrientation ||
        !setEquals(avoidBounds, oldDelegate.avoidBounds);
  }

  Rect _closestScreen(Iterable<Rect> screens, Offset point) {
    Rect closest = screens.first;
    for (final Rect screen in screens) {
      if ((screen.center - point).distance <
          (closest.center - point).distance) {
        closest = screen;
      }
    }
    return closest;
  }
}

class _MenuPanel extends StatefulWidget {
  const _MenuPanel({
    required this.menuStyle,
    this.clipBehavior = Clip.none,
    required this.orientation,
    this.crossAxisUnconstrained = true,
    required this.children,
  });

  final MenuStyle? menuStyle;

  final Clip clipBehavior;

  final bool crossAxisUnconstrained;

  final Axis orientation;

  final List<Widget> children;

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<_MenuPanel> {
  ScrollController scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (MenuStyle? themeStyle, MenuStyle defaultStyle) =
        switch (widget.orientation) {
      Axis.horizontal => (
          MenuBarTheme.of(context).style,
          _MenuBarDefaultsM3(context)
        ),
      Axis.vertical => (MenuTheme.of(context).style, _MenuDefaultsM3(context)),
    };
    final MenuStyle? widgetStyle = widget.menuStyle;

    T? effectiveValue<T>(T? Function(MenuStyle? style) getProperty) {
      return getProperty(widgetStyle) ??
          getProperty(themeStyle) ??
          getProperty(defaultStyle);
    }

    T? resolve<T>(
        MaterialStateProperty<T>? Function(MenuStyle? style) getProperty) {
      return effectiveValue(
        (MenuStyle? style) {
          return getProperty(style)?.resolve(<MaterialState>{});
        },
      );
    }

    final Color? backgroundColor =
        resolve<Color?>((MenuStyle? style) => style?.backgroundColor);
    final Color? shadowColor =
        resolve<Color?>((MenuStyle? style) => style?.shadowColor);
    final Color? surfaceTintColor =
        resolve<Color?>((MenuStyle? style) => style?.surfaceTintColor);
    final double elevation =
        resolve<double?>((MenuStyle? style) => style?.elevation) ?? 0;
    final Size? minimumSize =
        resolve<Size?>((MenuStyle? style) => style?.minimumSize);
    final Size? fixedSize =
        resolve<Size?>((MenuStyle? style) => style?.fixedSize);
    final Size? maximumSize =
        resolve<Size?>((MenuStyle? style) => style?.maximumSize);
    final BorderSide? side =
        resolve<BorderSide?>((MenuStyle? style) => style?.side);
    final OutlinedBorder shape =
        resolve<OutlinedBorder?>((MenuStyle? style) => style?.shape)!
            .copyWith(side: side);
    final VisualDensity visualDensity =
        effectiveValue((MenuStyle? style) => style?.visualDensity) ??
            VisualDensity.standard;
    final EdgeInsetsGeometry padding =
        resolve<EdgeInsetsGeometry?>((MenuStyle? style) => style?.padding) ??
            EdgeInsets.zero;
    final Offset densityAdjustment = visualDensity.baseSizeAdjustment;
    final double dy = densityAdjustment.dy;
    final double dx = math.max(0, densityAdjustment.dx);
    final EdgeInsetsGeometry resolvedPadding = padding
        .add(EdgeInsets.symmetric(horizontal: dx, vertical: dy))
        .clamp(EdgeInsets.zero, EdgeInsetsGeometry.infinity);

    BoxConstraints effectiveConstraints = visualDensity.effectiveConstraints(
      BoxConstraints(
        minWidth: minimumSize?.width ?? 0,
        minHeight: minimumSize?.height ?? 0,
        maxWidth: maximumSize?.width ?? double.infinity,
        maxHeight: maximumSize?.height ?? double.infinity,
      ),
    );
    if (fixedSize != null) {
      final Size size = effectiveConstraints.constrain(fixedSize);
      if (size.width.isFinite) {
        effectiveConstraints = effectiveConstraints.copyWith(
          minWidth: size.width,
          maxWidth: size.width,
        );
      }
      if (size.height.isFinite) {
        effectiveConstraints = effectiveConstraints.copyWith(
          minHeight: size.height,
          maxHeight: size.height,
        );
      }
    }

    Widget menuPanel = _intrinsicCrossSize(
      child: Material(
        elevation: elevation,
        shape: shape,
        color: backgroundColor,
        shadowColor: shadowColor,
        surfaceTintColor: surfaceTintColor,
        type: backgroundColor == null
            ? MaterialType.transparency
            : MaterialType.canvas,
        clipBehavior: widget.clipBehavior,
        child: Padding(
          padding: resolvedPadding,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              overscroll: false,
              physics: const ClampingScrollPhysics(),
            ),
            child: PrimaryScrollController(
              controller: scrollController,
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: widget.orientation,
                  child: Flex(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: Directionality.of(context),
                    direction: widget.orientation,
                    mainAxisSize: MainAxisSize.min,
                    children: widget.children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.crossAxisUnconstrained) {
      menuPanel = UnconstrainedBox(
        constrainedAxis: widget.orientation,
        clipBehavior: Clip.hardEdge,
        alignment: AlignmentDirectional.centerStart,
        child: menuPanel,
      );
    }

    return ConstrainedBox(
      constraints: effectiveConstraints,
      child: menuPanel,
    );
  }

  Widget _intrinsicCrossSize({required Widget child}) {
    return switch (widget.orientation) {
      Axis.horizontal => IntrinsicHeight(child: child),
      Axis.vertical => IntrinsicWidth(child: child),
    };
  }
}

class _Submenu extends StatelessWidget {
  const _Submenu({
    required this.anchor,
    required this.menuStyle,
    required this.menuPosition,
    required this.alignmentOffset,
    required this.clipBehavior,
    this.crossAxisUnconstrained = true,
    required this.menuChildren,
  });

  final _MenuAnchorState anchor;
  final MenuStyle? menuStyle;
  final Offset? menuPosition;
  final Offset alignmentOffset;
  final Clip clipBehavior;
  final bool crossAxisUnconstrained;
  final List<Widget> menuChildren;

  @override
  Widget build(BuildContext context) {
    final TextDirection textDirection = Directionality.of(context);
    final (MenuStyle? themeStyle, MenuStyle defaultStyle) =
        switch (anchor._parent?._orientation) {
      Axis.horizontal || null => (
          MenuBarTheme.of(context).style,
          _MenuBarDefaultsM3(context)
        ),
      Axis.vertical => (MenuTheme.of(context).style, _MenuDefaultsM3(context)),
    };
    T? effectiveValue<T>(T? Function(MenuStyle? style) getProperty) {
      return getProperty(menuStyle) ??
          getProperty(themeStyle) ??
          getProperty(defaultStyle);
    }

    T? resolve<T>(
        MaterialStateProperty<T>? Function(MenuStyle? style) getProperty) {
      return effectiveValue(
        (MenuStyle? style) {
          return getProperty(style)?.resolve(<MaterialState>{});
        },
      );
    }

    final MaterialStateMouseCursor mouseCursor = _MouseCursor(
      (Set<MaterialState> states) => effectiveValue(
          (MenuStyle? style) => style?.mouseCursor?.resolve(states)),
    );

    final VisualDensity visualDensity =
        effectiveValue((MenuStyle? style) => style?.visualDensity) ??
            Theme.of(context).visualDensity;
    final AlignmentGeometry alignment =
        effectiveValue((MenuStyle? style) => style?.alignment)!;
    final BuildContext anchorContext = anchor._anchorKey.currentContext!;
    final RenderBox overlay =
        Overlay.of(anchorContext).context.findRenderObject()! as RenderBox;
    final RenderBox anchorBox = anchorContext.findRenderObject()! as RenderBox;
    final Offset upperLeft =
        anchorBox.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = anchorBox
        .localToGlobal(anchorBox.paintBounds.bottomRight, ancestor: overlay);
    final Rect anchorRect = Rect.fromPoints(upperLeft, bottomRight);
    final EdgeInsetsGeometry padding =
        resolve<EdgeInsetsGeometry?>((MenuStyle? style) => style?.padding) ??
            EdgeInsets.zero;
    final Offset densityAdjustment = visualDensity.baseSizeAdjustment;
    final double dy = densityAdjustment.dy;
    final double dx = math.max(0, densityAdjustment.dx);
    final EdgeInsetsGeometry resolvedPadding = padding
        .add(EdgeInsets.fromLTRB(dx, dy, dx, dy))
        .clamp(EdgeInsets.zero, EdgeInsetsGeometry.infinity);

    return Theme(
      data: Theme.of(context).copyWith(
        visualDensity: visualDensity,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints.loose(overlay.paintBounds.size),
        child: CustomSingleChildLayout(
          delegate: _MenuLayout(
            anchorRect: anchorRect,
            textDirection: textDirection,
            avoidBounds:
                DisplayFeatureSubScreen.avoidBounds(MediaQuery.of(context))
                    .toSet(),
            menuPadding: resolvedPadding,
            alignment: alignment,
            alignmentOffset: alignmentOffset,
            menuPosition: menuPosition,
            orientation: anchor._orientation,
            parentOrientation: anchor._parent?._orientation ?? Axis.horizontal,
          ),
          child: TapRegion(
            groupId: anchor._root,
            consumeOutsideTaps:
                anchor._root._isOpen && anchor.widget.consumeOutsideTap,
            onTapOutside: (PointerDownEvent event) {
              anchor._close();
            },
            child: MouseRegion(
              cursor: mouseCursor,
              hitTestBehavior: HitTestBehavior.deferToChild,
              child: FocusScope(
                node: anchor._menuScopeNode,
                skipTraversal: true,
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    DirectionalFocusIntent: _MenuDirectionalFocusAction(),
                    DismissIntent:
                        DismissMenuAction(controller: anchor._menuController),
                  },
                  child: Shortcuts(
                    shortcuts: _kMenuTraversalShortcuts,
                    child: _MenuPanel(
                      menuStyle: menuStyle,
                      clipBehavior: clipBehavior,
                      orientation: anchor._orientation,
                      crossAxisUnconstrained: crossAxisUnconstrained,
                      children: menuChildren,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MouseCursor extends MaterialStateMouseCursor {
  const _MouseCursor(this.resolveCallback);

  final MaterialPropertyResolver<MouseCursor?> resolveCallback;

  @override
  MouseCursor resolve(Set<MaterialState> states) =>
      resolveCallback(states) ?? MouseCursor.uncontrolled;

  @override
  String get debugDescription => 'Menu_MouseCursor';
}

bool _debugMenuInfo(String message, [Iterable<String>? details]) {
  assert(() {
    if (_kDebugMenus) {
      debugPrint('MENU: $message');
      if (details != null && details.isNotEmpty) {
        for (final String detail in details) {
          debugPrint('    $detail');
        }
      }
    }
    return true;
  }());
  return true;
}

bool get _isApple {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return false;
  }
}

bool get _usesSymbolicModifiers {
  return _isApple;
}

bool get _platformSupportsAccelerators {
  return !_isApple;
}

class _MenuBarDefaultsM3 extends MenuStyle {
  _MenuBarDefaultsM3(this.context)
      : super(
          elevation: const MaterialStatePropertyAll<double?>(3.0),
          shape: const MaterialStatePropertyAll<OutlinedBorder>(
              _defaultMenuBorder),
          alignment: AlignmentDirectional.bottomStart,
        );

  static const RoundedRectangleBorder _defaultMenuBorder =
      RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4.0)));

  final BuildContext context;

  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  MaterialStateProperty<Color?> get backgroundColor {
    return MaterialStatePropertyAll<Color?>(_colors.surfaceContainer);
  }

  @override
  MaterialStateProperty<Color?>? get shadowColor {
    return MaterialStatePropertyAll<Color?>(_colors.shadow);
  }

  @override
  MaterialStateProperty<Color?>? get surfaceTintColor {
    return const MaterialStatePropertyAll<Color?>(Colors.transparent);
  }

  @override
  MaterialStateProperty<EdgeInsetsGeometry?>? get padding {
    return const MaterialStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsetsDirectional.symmetric(
          horizontal: _kTopLevelMenuHorizontalMinPadding),
    );
  }

  @override
  VisualDensity get visualDensity => Theme.of(context).visualDensity;
}

class _MenuButtonDefaultsM3 extends ButtonStyle {
  _MenuButtonDefaultsM3(this.context)
      : super(
          animationDuration: kThemeChangeDuration,
          enableFeedback: true,
          alignment: AlignmentDirectional.centerStart,
        );

  final BuildContext context;

  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  MaterialStateProperty<Color?>? get backgroundColor {
    return ButtonStyleButton.allOrNull<Color>(Colors.transparent);
  }

  @override
  MaterialStateProperty<double>? get elevation {
    return ButtonStyleButton.allOrNull<double>(0.0);
  }

  @override
  MaterialStateProperty<Color?>? get foregroundColor {
    return MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.disabled)) {
        return _colors.onSurface.withOpacity(0.38);
      }
      if (states.contains(MaterialState.pressed)) {
        return _colors.onSurface;
      }
      if (states.contains(MaterialState.hovered)) {
        return _colors.onSurface;
      }
      if (states.contains(MaterialState.focused)) {
        return _colors.onSurface;
      }
      return _colors.onSurface;
    });
  }

  @override
  MaterialStateProperty<Color?>? get iconColor {
    return MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.disabled)) {
        return _colors.onSurface.withOpacity(0.38);
      }
      if (states.contains(MaterialState.pressed)) {
        return _colors.onSurfaceVariant;
      }
      if (states.contains(MaterialState.hovered)) {
        return _colors.onSurfaceVariant;
      }
      if (states.contains(MaterialState.focused)) {
        return _colors.onSurfaceVariant;
      }
      return _colors.onSurfaceVariant;
    });
  }

  @override
  MaterialStateProperty<Size>? get maximumSize {
    return ButtonStyleButton.allOrNull<Size>(Size.infinite);
  }

  @override
  MaterialStateProperty<Size>? get minimumSize {
    return ButtonStyleButton.allOrNull<Size>(const Size(64.0, 48.0));
  }

  @override
  MaterialStateProperty<MouseCursor?>? get mouseCursor {
    return MaterialStateProperty.resolveWith(
      (Set<MaterialState> states) {
        if (states.contains(MaterialState.disabled)) {
          return SystemMouseCursors.basic;
        }
        return SystemMouseCursors.click;
      },
    );
  }

  @override
  MaterialStateProperty<Color?>? get overlayColor {
    return MaterialStateProperty.resolveWith(
      (Set<MaterialState> states) {
        if (states.contains(MaterialState.pressed)) {
          return _colors.onSurface.withOpacity(0.1);
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.onSurface.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.onSurface.withOpacity(0.1);
        }
        return Colors.transparent;
      },
    );
  }

  @override
  MaterialStateProperty<EdgeInsetsGeometry>? get padding {
    return ButtonStyleButton.allOrNull<EdgeInsetsGeometry>(
        _scaledPadding(context));
  }

  @override
  MaterialStateProperty<OutlinedBorder>? get shape {
    return ButtonStyleButton.allOrNull<OutlinedBorder>(
        const RoundedRectangleBorder());
  }

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory;

  @override
  MaterialTapTargetSize? get tapTargetSize =>
      Theme.of(context).materialTapTargetSize;

  @override
  MaterialStateProperty<TextStyle?> get textStyle {
    return MaterialStatePropertyAll<TextStyle?>(_textTheme.labelLarge);
  }

  @override
  VisualDensity? get visualDensity => Theme.of(context).visualDensity;

  EdgeInsetsGeometry _scaledPadding(BuildContext context) {
    VisualDensity visualDensity = Theme.of(context).visualDensity;
    if (visualDensity.horizontal > 0) {
      visualDensity = VisualDensity(vertical: visualDensity.vertical);
    }
    final double fontSize =
        Theme.of(context).textTheme.labelLarge?.fontSize ?? 14.0;
    final double fontSizeRatio =
        MediaQuery.textScalerOf(context).scale(fontSize) / 14.0;
    return ButtonStyleButton.scaledPadding(
      EdgeInsets.symmetric(
          horizontal: math.max(
        _kMenuViewPadding,
        _kLabelItemDefaultSpacing + visualDensity.baseSizeAdjustment.dx,
      )),
      EdgeInsets.symmetric(
          horizontal: math.max(
        _kMenuViewPadding,
        8 + visualDensity.baseSizeAdjustment.dx,
      )),
      const EdgeInsets.symmetric(horizontal: _kMenuViewPadding),
      fontSizeRatio,
    );
  }
}

class _MenuDefaultsM3 extends MenuStyle {
  _MenuDefaultsM3(this.context)
      : super(
          elevation: const MaterialStatePropertyAll<double?>(3.0),
          shape: const MaterialStatePropertyAll<OutlinedBorder>(
              _defaultMenuBorder),
          alignment: AlignmentDirectional.topEnd,
        );

  static const RoundedRectangleBorder _defaultMenuBorder =
      RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4.0)));

  final BuildContext context;

  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  MaterialStateProperty<Color?> get backgroundColor {
    return MaterialStatePropertyAll<Color?>(_colors.surfaceContainer);
  }

  @override
  MaterialStateProperty<Color?>? get surfaceTintColor {
    return const MaterialStatePropertyAll<Color?>(Colors.transparent);
  }

  @override
  MaterialStateProperty<Color?>? get shadowColor {
    return MaterialStatePropertyAll<Color?>(_colors.shadow);
  }

  @override
  MaterialStateProperty<EdgeInsetsGeometry?>? get padding {
    return const MaterialStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsetsDirectional.symmetric(vertical: _kMenuVerticalMinPadding),
    );
  }

  @override
  VisualDensity get visualDensity => Theme.of(context).visualDensity;
}

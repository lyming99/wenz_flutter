import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const bool _kDebugMenus = false;

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

typedef CustomMenuAnchorChildBuilder = Widget Function(
  BuildContext context,
  CustomMenuController controller,
  Widget? child,
);
typedef MenuStyleBuilder = MenuStyle? Function(
    BuildContext context, bool isBottom);

class CustomMenuAnchor extends StatefulWidget {
  const CustomMenuAnchor({
    super.key,
    this.controller,
    this.childFocusNode,
    this.styleBuilder,
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

  final CustomMenuController? controller;

  final FocusNode? childFocusNode;

  final MenuStyleBuilder? styleBuilder;

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

  final CustomMenuAnchorChildBuilder? builder;

  final Widget? child;

  @override
  State<CustomMenuAnchor> createState() => _CustomMenuAnchorState();

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
    properties.add(EnumProperty<Clip>('clipBehavior', clipBehavior));
    properties
        .add(DiagnosticsProperty<Offset?>('alignmentOffset', alignmentOffset));
  }
}

class _CustomMenuAnchorState extends State<CustomMenuAnchor> {
  final GlobalKey<_CustomMenuAnchorState> _anchorKey =
      GlobalKey<_CustomMenuAnchorState>(
          debugLabel: kReleaseMode ? null : 'MenuAnchor');
  _CustomMenuAnchorState? _parent;
  late final FocusScopeNode _menuScopeNode;
  CustomMenuController? _internalMenuController;
  final List<_CustomMenuAnchorState> _anchorChildren =
      <_CustomMenuAnchorState>[];
  ScrollPosition? _scrollPosition;
  Size? _viewSize;
  final OverlayPortalController _overlayController = OverlayPortalController(
      debugLabel: kReleaseMode ? null : 'MenuAnchor controller');
  Offset? _menuPosition;

  Axis get _orientation => Axis.vertical;

  bool get _isOpen => _overlayController.isShowing;

  bool get _isRoot => _parent == null;

  bool get _isTopLevel => _parent?._isRoot ?? false;

  CustomMenuController get _menuController =>
      widget.controller ?? _internalMenuController!;

  @override
  void initState() {
    super.initState();
    _menuScopeNode = FocusScopeNode(
        debugLabel: kReleaseMode ? null : '${describeIdentity(this)} Sub Menu');
    if (widget.controller == null) {
      _internalMenuController = CustomMenuController();
    }
    _menuController._attach(this);
  }

  @override
  void dispose() {
    assert(_debugMenuInfo('Disposing of $this'));
    if (_isOpen) {
      _close(inDispose: true);
    }

    _parent?._removeChild(this);
    _parent = null;
    _anchorChildren.clear();
    _menuController._detach(this);
    _internalMenuController = null;
    _menuScopeNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final _CustomMenuAnchorState? newParent =
        _CustomMenuAnchorState._maybeOf(context);
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
  void didUpdateWidget(CustomMenuAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      if (widget.controller != null) {
        _internalMenuController?._detach(this);
        _internalMenuController = null;
        widget.controller?._attach(this);
      } else {
        assert(_internalMenuController == null);
        _internalMenuController = CustomMenuController().._attach(this);
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
          menuStyleBuilder: widget.styleBuilder,
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
        DismissIntent: CustomDismissMenuAction(controller: _menuController),
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

  void _addChild(_CustomMenuAnchorState child) {
    assert(_isRoot || _debugMenuInfo('Added root child: $child'));
    assert(!_anchorChildren.contains(child));
    _anchorChildren.add(child);
    assert(_debugMenuInfo('Added:\n${child.widget.toStringDeep()}'));
    assert(_debugMenuInfo('Tree:\n${widget.toStringDeep()}'));
  }

  void _removeChild(_CustomMenuAnchorState child) {
    assert(_isRoot || _debugMenuInfo('Removed root child: $child'));
    assert(_anchorChildren.contains(child));
    assert(_debugMenuInfo('Removing:\n${child.widget.toStringDeep()}'));
    _anchorChildren.remove(child);
    assert(_debugMenuInfo('Tree:\n${widget.toStringDeep()}'));
  }

  List<_CustomMenuAnchorState> _getFocusableChildren() {
    if (_parent == null) {
      return <_CustomMenuAnchorState>[];
    }
    return _parent!._anchorChildren.where(
      (_CustomMenuAnchorState menu) {
        return menu.widget.childFocusNode?.canRequestFocus ?? false;
      },
    ).toList();
  }

  _CustomMenuAnchorState? get _nextFocusableSibling {
    final List<_CustomMenuAnchorState> focusable = _getFocusableChildren();
    if (focusable.isEmpty) {
      return null;
    }
    return focusable[(focusable.indexOf(this) + 1) % focusable.length];
  }

  _CustomMenuAnchorState? get _previousFocusableSibling {
    final List<_CustomMenuAnchorState> focusable = _getFocusableChildren();
    if (focusable.isEmpty) {
      return null;
    }
    return focusable[
        (focusable.indexOf(this) - 1 + focusable.length) % focusable.length];
  }

  _CustomMenuAnchorState get _root {
    _CustomMenuAnchorState anchor = this;
    while (anchor._parent != null) {
      anchor = anchor._parent!;
    }
    return anchor;
  }

  _CustomMenuAnchorState get _topLevel {
    _CustomMenuAnchorState handle = this;
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
    for (final _CustomMenuAnchorState child
        in List<_CustomMenuAnchorState>.from(_anchorChildren)) {
      child._close(inDispose: inDispose);
    }
  }

  static _CustomMenuAnchorState? _maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_MenuAnchorScope>()
        ?.anchor;
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) {
    return describeIdentity(this);
  }
}

class CustomMenuController {
  _CustomMenuAnchorState? _anchor;

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

  void _attach(_CustomMenuAnchorState anchor) {
    _anchor = anchor;
  }

  void _detach(_CustomMenuAnchorState anchor) {
    if (_anchor == anchor) {
      _anchor = null;
    }
  }
}

class CustomDismissMenuAction extends DismissAction {
  CustomDismissMenuAction({required this.controller});

  final CustomMenuController controller;

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

class _MenuAnchorScope extends InheritedWidget {
  const _MenuAnchorScope({
    required super.child,
    required this.anchorKey,
    required this.anchor,
    required this.isOpen,
  });

  final GlobalKey anchorKey;
  final _CustomMenuAnchorState anchor;
  final bool isOpen;

  @override
  bool updateShouldNotify(_MenuAnchorScope oldWidget) {
    return anchorKey != oldWidget.anchorKey ||
        anchor != oldWidget.anchor ||
        isOpen != oldWidget.isOpen;
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
    final _CustomMenuAnchorState? anchor =
        _CustomMenuAnchorState._maybeOf(context);
    if (anchor == null || !anchor._root._isOpen) {
      return super.invoke(intent);
    }

    return _moveToPreviousFocusable(anchor);
  }

  static bool _moveToPreviousFocusable(_CustomMenuAnchorState currentMenu) {
    final _CustomMenuAnchorState? sibling =
        currentMenu._previousFocusableSibling;
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
    final _CustomMenuAnchorState? anchor =
        _CustomMenuAnchorState._maybeOf(context);
    if (anchor == null || !anchor._root._isOpen) {
      return super.invoke(intent);
    }

    return _moveToNextFocusable(anchor);
  }

  static bool _moveToNextFocusable(_CustomMenuAnchorState currentMenu) {
    final _CustomMenuAnchorState? sibling = currentMenu._nextFocusableSibling;
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
    final _CustomMenuAnchorState? anchor =
        _CustomMenuAnchorState._maybeOf(context);
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

    final bool Function(_CustomMenuAnchorState) traversal =
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

  bool _moveToNext(_CustomMenuAnchorState currentMenu) {
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

  bool _moveToNextFocusableTopLevel(_CustomMenuAnchorState currentMenu) {
    final _CustomMenuAnchorState? sibling =
        currentMenu._topLevel._nextFocusableSibling;
    sibling?._focusButton();
    return true;
  }

  bool _moveToParent(_CustomMenuAnchorState currentMenu) {
    assert(_debugMenuInfo('Moving focus to parent menu button'));
    if (!(currentMenu.widget.childFocusNode?.hasPrimaryFocus ?? true)) {
      currentMenu._focusButton();
    }
    return true;
  }

  bool _moveToPrevious(_CustomMenuAnchorState currentMenu) {
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

  bool _moveToPreviousFocusableTopLevel(_CustomMenuAnchorState currentMenu) {
    final _CustomMenuAnchorState? sibling =
        currentMenu._topLevel._previousFocusableSibling;
    sibling?._focusButton();
    return true;
  }

  bool _moveToSubmenu(_CustomMenuAnchorState currentMenu) {
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

class CustomMenuAcceleratorCallbackBinding extends InheritedWidget {
  const CustomMenuAcceleratorCallbackBinding({
    super.key,
    this.onInvoke,
    this.hasSubmenu = false,
    required super.child,
  });

  final VoidCallback? onInvoke;

  final bool hasSubmenu;

  @override
  bool updateShouldNotify(CustomMenuAcceleratorCallbackBinding oldWidget) {
    return onInvoke != oldWidget.onInvoke || hasSubmenu != oldWidget.hasSubmenu;
  }

  static CustomMenuAcceleratorCallbackBinding? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<
        CustomMenuAcceleratorCallbackBinding>();
  }

  static CustomMenuAcceleratorCallbackBinding of(BuildContext context) {
    final CustomMenuAcceleratorCallbackBinding? result = maybeOf(context);
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

typedef _OnMenuLayout = void Function(Rect anchorRect, Rect childRect);

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
    this.onMenuLayout,
  });

  final _OnMenuLayout? onMenuLayout;

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

    var offset = Offset(x, y);
    var childRect =
        Rect.fromLTWH(offset.dx, offset.dy, childSize.width, childSize.height);
    onMenuLayout?.call(anchorRect, childRect);
    return offset;
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

    List<Widget> children = widget.children;
    if (widget.orientation == Axis.horizontal) {
      children = children.map<Widget>((Widget child) {
        return IntrinsicWidth(child: child);
      }).toList();
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
                    children: children,
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

class _Submenu extends StatefulWidget {
  const _Submenu({
    required this.anchor,
    required this.menuStyleBuilder,
    required this.menuPosition,
    required this.alignmentOffset,
    required this.clipBehavior,
    this.crossAxisUnconstrained = true,
    required this.menuChildren,
  });

  final _CustomMenuAnchorState anchor;
  final MenuStyleBuilder? menuStyleBuilder;
  final Offset? menuPosition;
  final Offset alignmentOffset;
  final Clip clipBehavior;
  final bool crossAxisUnconstrained;
  final List<Widget> menuChildren;

  @override
  State<_Submenu> createState() => _SubmenuState();
}

class _SubmenuState extends State<_Submenu> {
  bool isBottom = true;
  double opacity = 0;

  void onMenuLayout(Rect anchorRect, Rect childRect) {
    var isBottom = true;
    if (anchorRect.top > childRect.top) {
      isBottom = false;
    }
    var opacity = 1.0;
    if (isBottom != this.isBottom || opacity != this.opacity) {
      this.opacity = opacity;
      this.isBottom = isBottom;
      WidgetsBinding.instance.scheduleFrameCallback((time) {
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var menuStyle = widget.menuStyleBuilder?.call(context, isBottom);
    final TextDirection textDirection = Directionality.of(context);
    final (MenuStyle? themeStyle, MenuStyle defaultStyle) =
        switch (widget.anchor._parent?._orientation) {
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
    final BuildContext anchorContext = widget.anchor._anchorKey.currentContext!;
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
            alignmentOffset: widget.alignmentOffset,
            menuPosition: widget.menuPosition,
            orientation: widget.anchor._orientation,
            parentOrientation:
                widget.anchor._parent?._orientation ?? Axis.horizontal,
            onMenuLayout: onMenuLayout,
          ),
          child: Opacity(
            key: ValueKey(opacity),
            opacity: opacity,
            child: TapRegion(
              groupId: widget.anchor._root,
              consumeOutsideTaps: widget.anchor._root._isOpen &&
                  widget.anchor.widget.consumeOutsideTap,
              onTapOutside: (PointerDownEvent event) {
                widget.anchor._close();
              },
              child: MouseRegion(
                cursor: mouseCursor,
                hitTestBehavior: HitTestBehavior.deferToChild,
                child: FocusScope(
                  node: widget.anchor._menuScopeNode,
                  skipTraversal: true,
                  child: Actions(
                    actions: <Type, Action<Intent>>{
                      DirectionalFocusIntent: _MenuDirectionalFocusAction(),
                      DismissIntent: CustomDismissMenuAction(
                          controller: widget.anchor._menuController),
                    },
                    child: Shortcuts(
                      shortcuts: _kMenuTraversalShortcuts,
                      child: _MenuPanel(
                        menuStyle: menuStyle,
                        clipBehavior: widget.clipBehavior,
                        orientation: widget.anchor._orientation,
                        crossAxisUnconstrained: widget.crossAxisUnconstrained,
                        children: widget.menuChildren,
                      ),
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

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/position/document_position.dart';
import 'block_geometry_registry.dart';
import 'link_hover_overlay.dart';

typedef SelectionContextMenuRequestHandler = void Function(
  SelectionContextMenuRequest request,
);

typedef TapSelectionDeferPredicate = bool Function(
  DocumentPosition anchor,
  Offset globalPosition,
);

typedef TapSelectionCommitPredicate = bool Function(
  DocumentPosition anchor,
  Offset globalPosition,
);

typedef TapSelectionFocusPredicate = bool Function(
  DocumentPosition anchor,
  Offset globalPosition,
);

/// Reports a qualifying mobile tap or long-press after it has placed a
/// collapsed caret. The editor owns toolbar eligibility and lifecycle.
typedef MobileCaretToolbarRequestHandler = void Function(
  DocumentPosition caret,
  Offset globalPosition,
);

/// Notifies the editor that a new mobile touch sequence has begun on the
/// document surface. A previously shown caret toolbar must close before this
/// gesture is resolved so excluded block chrome and link interactions cannot
/// leave it behind.
typedef MobileCaretToolbarDismissHandler = void Function();

typedef SelectionMoveRequestHandler = void Function(
  DocumentSelection selection,
  DocumentPosition destination,
);

class SelectionContextMenuRequest {
  const SelectionContextMenuRequest({
    required this.globalPosition,
    required this.hitPosition,
  });

  final Offset globalPosition;
  final DocumentPosition? hitPosition;
}

/// Document-level gesture surface that owns mouse/touch selection across all
/// editable blocks.
///
/// Wraps the scrollable editor content. Pointer events are translated to
/// [DocumentPosition]s via the [BlockGeometryRegistry], so a drag that starts
/// in one block can extend the selection into a neighbouring block. This
/// replaces the per-block gesture detectors that previously trapped drags
/// inside a single [TextSelectionSurface].
///
/// Supports:
/// - tap → place collapsed caret. Empty text surfaces follow the same tap
///   semantics: when their visible line area resolves to a text anchor, focus is
///   requested and the selection collapses to that block/path at offset 0.
/// - mouse/stylus drag → extend selection (cross-block), with auto-scroll
///   near viewport edges
/// - touch drag → leave selection unchanged so the descendant scrollable
///   exclusively owns ordinary finger scrolling; selection extension starts
///   only after a touch long-press has selected a word
/// - auto-scroll → every drag (touch or mouse) synchronously scrolls one step
///   when the pointer enters the viewport edge band, so the list follows the
///   drag. A per-frame [Ticker] *additionally* keeps scrolling (for every
///   pointer kind) while the pointer is held still near an edge, letting the
///   user scroll past the visible area — touch drags no longer stall at the
///   viewport edge.
/// - double-tap → select word
/// - long-press (touch only) → select word (mobile counterpart of double-tap),
///   reusing the same word-selection path and seeding a drag from the word so
///   the selection can be extended immediately
/// - triple-tap → select block (paragraph)
/// Selection exclusions and the scrollbar gutter are checked before resolving a
/// text anchor, so block chrome (handles, checkboxes, collapse buttons, menus)
/// cannot be claimed as an empty-line text tap.
class SelectionGestureOverlay extends StatefulWidget {
  const SelectionGestureOverlay({
    super.key,
    required this.registry,
    required this.scrollController,
    required this.focusNode,
    required this.readOnly,
    required this.onSelectionChanged,
    this.useMobileTouchGestures = false,
    this.currentSelection,
    this.onSelectionMovePreviewChanged,
    this.onSelectionMoveRequested,
    this.shouldDeferTapSelection,
    this.shouldCommitDeferredTapSelection,
    this.shouldRequestFocusForTapSelection,
    this.onMobileCaretToolbarRequested,
    this.onMobileCaretToolbarDismissed,
    this.onTapBeyondContent,
    this.onContextMenuRequested,
    this.linkProbe,
    this.onLinkHover,
    this.onLinkOpen,
    required this.child,
  });

  final BlockGeometryRegistry registry;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final bool readOnly;
  final ValueChanged<DocumentSelection> onSelectionChanged;

  /// Whether ordinary touch drags should be reserved for scrolling and text
  /// range selection should start only after long-press. Desktop touchscreens
  /// leave this disabled to preserve their mouse-like drag-selection model.
  final bool useMobileTouchGestures;

  /// Current editor selection used as the fixed base for Shift+mouse
  /// extension gestures. When absent, pointer selection keeps the normal
  /// click/drag semantics.
  final DocumentSelection? currentSelection;

  /// Reports the current insertion target while selected text is being moved.
  final ValueChanged<DocumentPosition?>? onSelectionMovePreviewChanged;

  /// Moves the current non-collapsed selection to a mouse drop position.
  final SelectionMoveRequestHandler? onSelectionMoveRequested;

  /// Allows a block renderer with its own tap recognizers to delay the editor's
  /// tap selection update until after the current pointer sequence finishes.
  final TapSelectionDeferPredicate? shouldDeferTapSelection;

  /// Decides whether a deferred tap still belongs to editor selection after
  /// descendant gesture recognizers have resolved the pointer sequence.
  final TapSelectionCommitPredicate? shouldCommitDeferredTapSelection;

  /// Controls whether a tap selection should also request text-input focus.
  final TapSelectionFocusPredicate? shouldRequestFocusForTapSelection;

  /// Called after a qualifying single-finger tap on the existing collapsed
  /// caret, or a long-press whose word range is empty, on an editable text path.
  /// The first tap that only places/moves the caret does not request a toolbar.
  /// Object blocks, links, selection drags, multi-taps, mouse input, and
  /// excluded chrome never reach this callback.
  final MobileCaretToolbarRequestHandler? onMobileCaretToolbarRequested;

  /// Called at the start of every touch sequence on a mobile selection
  /// surface. Toolbar widgets are layered above this surface, so touches on a
  /// toolbar action do not invoke it.
  final MobileCaretToolbarDismissHandler? onMobileCaretToolbarDismissed;

  final bool Function(Offset globalPosition)? onTapBeyondContent;
  final SelectionContextMenuRequestHandler? onContextMenuRequested;

  /// Resolves a global pointer position to the hovered inline link run, or
  /// `null` when the position is not over a link. Supplied by the editor (which
  /// owns the position→link resolver). Consulted on mouse/pen hover and to
  /// suppress the mobile caret toolbar for a touch on a link.
  final WenzLinkHoverInfo? Function(Offset global)? linkProbe;

  /// Reports the link currently under the hovering pointer (`null` when the
  /// pointer is over non-link content or leaves the surface). The editor uses
  /// this to show / hide / position [WenzLinkHoverOverlay], applying the hide
  /// delay itself so the popup can keep itself alive while the pointer rests on
  /// it. Reported only while [linkProbe] is supplied.
  final ValueChanged<WenzLinkHoverInfo?>? onLinkHover;

  /// Invoked when the user activates an inline link with a mouse or stylus:
  /// Ctrl/Cmd+click while editing, or a plain click while [readOnly]. The host
  /// forwards the URL to [WenzRichTextEditor.onOpenLink]. Activation is
  /// resolved in [_onPointerDown] via [linkProbe]; when it hits a link the
  /// caret/selection logic is suppressed so the editor's selection stays put,
  /// and pointer-up opens the link instead. When this is `null` (the host
  /// supplied no open handler), the click falls through to normal selection
  /// handling. Touch never reaches this path.
  final ValueChanged<WenzLinkHoverInfo>? onLinkOpen;

  final Widget child;

  /// The mouse cursor shown while hovering selectable text.
  ///
  /// Read-only documents still support range selection and copy, so they use
  /// the same I-beam affordance as editable documents. Nested links, media
  /// controls and scrollbars continue to override this cursor for their own
  /// hit regions.
  MouseCursor get cursor => SystemMouseCursors.text;

  @override
  State<SelectionGestureOverlay> createState() =>
      _SelectionGestureOverlayState();
}

class _SelectionGestureOverlayState extends State<SelectionGestureOverlay> {
  // Multi-click tracking.
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  int _tapCount = 0;

  // Drag tracking.
  //
  // _dragBase holds the pointer-down position (resolved via
  // BlockGeometryRegistry.positionFromGlobalOffset) and is preserved for the
  // entire drag. For table cells it includes a PositionPath.tableCellText
  // path with correct tableRowIndex/tableColumnIndex, so a drag from one cell
  // to another produces a DocumentSelection whose tableCellRange getter
  // computes the proper bounding-box rectangle.
  DocumentPosition? _dragBase;
  bool _isDragging = false;
  bool _isMovingSelection = false;
  DocumentSelection? _selectionMoveSource;
  Offset? _dragOrigin;
  Offset? _lastDragPosition;
  int? _selectionExcludedPointer;
  int? _touchScrollPointer;
  bool _isShiftSelecting = false;
  // Anchor position from the most recent pointer down, used for tap /
  // multi-click selection regardless of whether a drag starts.
  DocumentPosition? _tapAnchor;

  // Set when a touch long-press selected a word (the mobile counterpart of the
  // desktop double-click word select). Pointer-up consults it to skip caret
  // placement so the word selection survives a long-press-and-release.
  bool _longPressWordSelected = false;

  // Touch long-press recognizer (word select). Built once in initState; mouse
  // and pen are excluded via [LongPressGestureRecognizer.supportedDevices] so
  // the desktop double-click path is untouched.
  late final Map<Type, GestureRecognizerFactory> _gestureRecognizers;

  // When non-null, the in-progress pointer-down activated an inline link: the
  // caret/selection setup was suppressed on down, and pointer-up opens the link
  // instead of placing the caret.
  // Cleared on up, cancel, and exit.
  WenzLinkHoverInfo? _linkOpenPending;

  // Continuous auto-scroll for active selection drags. While the pointer is
  // held near a viewport edge, a ticker advances the scroll offset every frame.
  // Ordinary touch scrolling never enters this path; touch selection does so
  // only after long-press has selected a word.
  Ticker? _autoScrollTicker;
  bool _autoScrollActive = false;
  bool _autoScrollExtendPending = false;
  // Signed pixels-per-frame velocity: >0 scrolls down, <0 up, 0 stops. Scaled
  // by proximity to the viewport edge (capped at [_maxAutoScrollPerFrame]).
  double _autoScrollVelocity = 0;

  static const Duration _multiClickWindow = Duration(milliseconds: 300);
  static const double _dragSlop = 18.0; // kTouchSlop-ish; generous for mouse.
  static const double _autoScrollEdge = 48.0;
  static const double _maxAutoScrollPerFrame = 24.0;

  /// Width of the trailing-edge band treated as the scrollbar gutter. Hovering
  /// here switches the cursor away from the text (I-beam) so the scrollbar
  /// thumb does not inherit the editing cursor. Sized to cover a typical
  /// desktop scrollbar (Material's ~8px thumb plus its cross-axis margin).
  static const double _kScrollbarGutterWidth = 16.0;

  /// Whether the mouse currently hovers the scrollbar gutter. Drives
  /// [_resolvedCursor] so the scrollbar shows a click cursor instead of the
  /// text cursor. Toggled only on gutter crossings to avoid rebuilding on
  /// every hover move.
  bool _overScrollbar = false;

  @override
  void initState() {
    super.initState();
    _gestureRecognizers = <Type, GestureRecognizerFactory>{
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
        () => LongPressGestureRecognizer(
          // Touch-only: mouse/pen keep their double-click word select.
          supportedDevices: const <PointerDeviceKind>{
            PointerDeviceKind.touch,
          },
        ),
        (LongPressGestureRecognizer instance) {
          instance.onLongPressStart = _onLongPressStart;
        },
      ),
    };
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _autoScrollTicker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _resolvedCursor(),
      onHover: _onPointerHover,
      onExit: _onPointerExit,
      child: RawGestureDetector(
        // Touch long-press → word select. The recognizers live in the gesture
        // arena; the raw [Listener] below still drives tap/drag selection, and
        // the long-press recognizer cancels on movement so it never competes
        // with a drag.
        behavior: HitTestBehavior.translucent,
        gestures: _gestureRecognizers,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: widget.child,
        ),
      ),
    );
  }

  /// Tracks whether the pointer sits over the scrollbar gutter so the thumb
  /// does not show the text (I-beam) cursor. The gutter is the trailing-edge
  /// band when the list is scrollable; hovering it toggles [_overScrollbar].
  void _onPointerHover(PointerHoverEvent event) {
    final overScrollbar = _isOverScrollbar(event.position);
    if (overScrollbar != _overScrollbar) {
      _overScrollbar = overScrollbar;
      setState(() {});
    }
    // Probe for an inline link under the pointer and report it (or its absence)
    // to the editor, which owns the hover popup and the hide delay. Hover events
    // are mouse/pen only, so touch never reaches here.
    _reportLinkHover(event.position);
  }

  /// When the pointer leaves the editing surface entirely (e.g. onto the link
  /// hover popup, which is a sibling overlay, or off the editor), report the
  /// absence of a hovered link so the editor can schedule the popup hide.
  void _onPointerExit(PointerExitEvent event) {
    _reportLinkHover(null);
  }

  void _reportLinkHover(Offset? global) {
    final probe = widget.linkProbe;
    final report = widget.onLinkHover;
    if (probe == null || report == null) {
      return;
    }
    report(global == null ? null : probe(global));
  }

  /// The cursor for the current hover region. Over the scrollbar gutter we
  /// show a click cursor (so the thumb does not inherit the editing cursor);
  /// elsewhere selectable text shows the text (I-beam) cursor in both editable
  /// and read-only documents.
  MouseCursor _resolvedCursor() {
    if (_isMovingSelection) {
      return SystemMouseCursors.grabbing;
    }
    if (_overScrollbar) {
      return SystemMouseCursors.click;
    }
    return widget.cursor;
  }

  /// Whether [global] sits inside the scrollbar gutter — the trailing-edge
  /// band of a vertically scrollable list. The list's own scrollbar is added by
  /// the ambient scroll behaviour and its MouseRegion defers its cursor to us,
  /// so without this check the thumb would show the text cursor.
  bool _isOverScrollbar(Offset global) {
    final scrollable = widget.scrollController;
    if (!scrollable.hasClients) {
      return false;
    }
    // Only intercept when there is actually something to scroll; a fully
    // visible list has no scrollbar thumb to hover.
    if (scrollable.position.maxScrollExtent <= 0) {
      return false;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return false;
    }
    final local = renderBox.globalToLocal(global);
    if (local.dx < 0 || local.dy < 0) {
      return false;
    }
    final size = renderBox.size;
    if (local.dx > size.width || local.dy > size.height) {
      return false;
    }
    final isRtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final gutterStart = isRtl ? 0.0 : size.width - _kScrollbarGutterWidth;
    final gutterEnd = isRtl ? _kScrollbarGutterWidth : size.width;
    return local.dx >= gutterStart && local.dx <= gutterEnd;
  }

  void _onPointerDown(PointerDownEvent event) {
    _clearSelectionMoveState();
    if (widget.useMobileTouchGestures &&
        event.kind == PointerDeviceKind.touch) {
      widget.onMobileCaretToolbarDismissed?.call();
    }
    // A new pointer down starts a fresh gesture; clear any long-press word
    // selection flag left by a previous (interrupted) sequence so it cannot
    // suppress this press's caret placement.
    _longPressWordSelected = false;
    _isShiftSelecting = false;
    _touchScrollPointer = null;
    if (widget.registry.isSelectionExcluded(event.position)) {
      _selectionExcludedPointer = event.pointer;
      _stopAutoScroll();
      _dragBase = null;
      _dragOrigin = null;
      _lastDragPosition = null;
      _tapAnchor = null;
      _isDragging = false;
      return;
    }
    _selectionExcludedPointer = null;
    // A press on the scrollbar gutter (desktop) is a scroll gesture, not a
    // content selection. Bail before resolving a content position so dragging
    // the thumb does not also start a selection drag.
    if (_isOverScrollbar(event.position)) {
      _dragBase = null;
      _dragOrigin = null;
      _tapAnchor = null;
      _isDragging = false;
      return;
    }
    if (_isContextMenuButton(event)) {
      _selectionExcludedPointer = event.pointer;
      _stopAutoScroll();
      _dragBase = null;
      _dragOrigin = null;
      _lastDragPosition = null;
      _tapAnchor = null;
      _linkOpenPending = null;
      _isDragging = false;
      widget.onContextMenuRequested?.call(
        SelectionContextMenuRequest(
          globalPosition: event.position,
          hitPosition: widget.registry.positionFromGlobalOffset(event.position),
        ),
      );
      return;
    }
    // Ctrl/Cmd+click while editing, or a plain click while read-only, opens an
    // inline link instead of placing the caret. Resolve it before the
    // tap/multi-click/drag setup so none of that state is recorded — pointer-up
    // just opens and returns, leaving the editor's selection untouched.
    final linkOpen = _linkOpenFromDown(event);
    if (linkOpen != null) {
      _linkOpenPending = linkOpen;
      _dragBase = null;
      _dragOrigin = null;
      _lastDragPosition = null;
      _tapAnchor = null;
      _isDragging = false;
      return;
    }
    final now = DateTime.now();
    final position = event.position;
    _tapAnchor = widget.registry.positionFromGlobalOffset(position);
    final shiftBase = _tapAnchor == null ? null : _shiftBaseFor(event);

    if (shiftBase != null) {
      _tapCount = 1;
      _lastTapTime = null;
      _lastTapPosition = null;
    } else {
      final isMultiClick = _lastTapTime != null &&
          _lastTapPosition != null &&
          now.difference(_lastTapTime!) < _multiClickWindow &&
          (position - _lastTapPosition!).distance <= _dragSlop;

      if (isMultiClick) {
        _tapCount += 1;
      } else {
        _tapCount = 1;
      }
      _lastTapTime = now;
      _lastTapPosition = position;
    }
    _selectionMoveSource = shiftBase == null
        ? _selectionMoveCandidateFor(event, _tapAnchor)
        : null;
    if (_tapCount < 2) {
      _dragOrigin = position;
      _dragBase = shiftBase ?? _tapAnchor;
      _isShiftSelecting = shiftBase != null;
    } else {
      _dragOrigin = null;
      _dragBase = null;
      _isShiftSelecting = false;
    }
    _isDragging = false;
    _lastDragPosition = null;
  }

  bool _isContextMenuButton(PointerDownEvent event) {
    return event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kSecondaryMouseButton) != 0;
  }

  DocumentPosition? _shiftBaseFor(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        (event.buttons & kPrimaryMouseButton) == 0 ||
        !HardwareKeyboard.instance.isShiftPressed) {
      return null;
    }
    return widget.currentSelection?.base;
  }

  DocumentSelection? _selectionMoveCandidateFor(
    PointerDownEvent event,
    DocumentPosition? hit,
  ) {
    if (widget.readOnly ||
        widget.onSelectionMoveRequested == null ||
        _tapCount != 1 ||
        hit == null ||
        (event.kind != PointerDeviceKind.mouse &&
            event.kind != PointerDeviceKind.stylus) ||
        (event.buttons & kPrimaryMouseButton) == 0) {
      return null;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return null;
    }
    final selection = widget.currentSelection;
    if (selection == null ||
        selection.isCollapsed ||
        !_isMovableTextSelection(selection)) {
      return null;
    }
    return hit.compareTo(selection.start) >= 0 &&
            hit.compareTo(selection.end) < 0
        ? selection
        : null;
  }

  bool _isMovableTextSelection(DocumentSelection selection) {
    final basePath = selection.base.path;
    final extentPath = selection.extent.path;
    if (!_isTextInputPath(basePath) || !_isTextInputPath(extentPath)) {
      return false;
    }
    final tableRange = selection.tableCellRange;
    if (tableRange != null) {
      return tableRange.isSingleCell && basePath == extentPath;
    }
    if (basePath.isTableCellText || extentPath.isTableCellText) {
      return false;
    }
    return selection.base.blockIndex != selection.extent.blockIndex ||
        basePath == extentPath;
  }

  /// Resolves whether a mouse/stylus pointer-down at [event] should open the
  /// inline link under it instead of placing the caret.
  ///
  /// Returns the hovered link run when the editor is read-only or the platform
  /// modifier is held — Ctrl on all platforms, Cmd on macOS (matching browser
  /// link-opening: Ctrl+click on Windows/Linux, Cmd+click on Mac) — and
  /// [widget.linkProbe] resolves a link at the position; otherwise `null`.
  /// Touch is excluded, and a qualifying click on non-link text falls through
  /// to the regular tap flow (the probe returns `null`).
  WenzLinkHoverInfo? _linkOpenFromDown(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse &&
        event.kind != PointerDeviceKind.stylus) {
      return null;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!widget.readOnly &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed) {
      return null;
    }
    // Only treat this as an open-click when the host can actually open a link;
    // otherwise it falls through to normal selection handling (mirroring the
    // hover popup's disabled "Open").
    final probe = widget.linkProbe;
    final open = widget.onLinkOpen;
    if (probe == null || open == null) {
      return null;
    }
    return probe(event.position);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_touchScrollPointer == event.pointer) {
      return;
    }
    if (_selectionExcludedPointer == event.pointer) {
      return;
    }
    if (_dragBase == null || _dragOrigin == null) {
      return;
    }
    final position = event.position;
    if (!_isDragging) {
      final moved = (position - _dragOrigin!).distance;
      if (moved < _dragSlop) {
        return;
      }
      // A normal finger drag belongs to the editor's Scrollable. Do not turn
      // it into a selection drag or request focus on pointer-up; touch range
      // selection is intentionally entered only through long-press.
      if (widget.useMobileTouchGestures &&
          event.kind == PointerDeviceKind.touch &&
          !_longPressWordSelected) {
        _touchScrollPointer = event.pointer;
        _stopAutoScroll();
        _dragBase = null;
        _dragOrigin = null;
        _lastDragPosition = null;
        _tapAnchor = null;
        _tapCount = 0;
        _lastTapTime = null;
        _lastTapPosition = null;
        _isDragging = false;
        return;
      }
      _isDragging = true;
      if (_selectionMoveSource != null) {
        _isMovingSelection = true;
        setState(() {});
      }
    }
    _lastDragPosition = position;
    _updateActiveDrag(position);
    _syncScrollToEdge(position);
    _maybeStartAutoScroll(position);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_selectionExcludedPointer == event.pointer) {
      _selectionExcludedPointer = null;
      _isShiftSelecting = false;
      _clearSelectionMoveState();
      return;
    }
    if (_touchScrollPointer == event.pointer) {
      _touchScrollPointer = null;
      _stopAutoScroll();
      _isDragging = false;
      _isShiftSelecting = false;
      _longPressWordSelected = false;
      _dragBase = null;
      _dragOrigin = null;
      _lastDragPosition = null;
      _tapAnchor = null;
      _clearSelectionMoveState();
      return;
    }
    _stopAutoScroll();
    final position = event.position;
    final wasDragging = _isDragging;
    final wasMovingSelection = _isMovingSelection;
    final selectionMoveSource = _selectionMoveSource;
    final tapCount = _tapCount;
    final longPressSelected = _longPressWordSelected;
    final isShiftSelecting = _isShiftSelecting;
    final shiftBase = _dragBase;
    _isDragging = false;
    _isMovingSelection = false;
    _selectionMoveSource = null;
    _longPressWordSelected = false;
    _dragOrigin = null;
    _lastDragPosition = null;
    widget.onSelectionMovePreviewChanged?.call(null);
    if (wasMovingSelection) {
      setState(() {});
    }

    // A qualifying link click: open it and bail before the tap/selection
    // placement below, so neither requestFocus nor onSelectionChanged fires
    // and the caret stays where it was.
    final pendingLink = _linkOpenPending;
    if (pendingLink != null) {
      _linkOpenPending = null;
      _dragBase = null;
      _tapAnchor = null;
      _isShiftSelecting = false;
      widget.onLinkOpen?.call(pendingLink);
      return;
    }

    if (wasMovingSelection && selectionMoveSource != null) {
      final destination = widget.registry.positionFromGlobalOffset(position);
      _dragBase = null;
      _tapAnchor = null;
      _isShiftSelecting = false;
      if (destination != null &&
          _isTextInputPath(destination.path) &&
          !_positionIsInsideOrAtSelection(
            destination,
            selectionMoveSource,
          )) {
        widget.focusNode.requestFocus();
        widget.onSelectionMoveRequested?.call(
          selectionMoveSource,
          destination,
        );
      }
      return;
    }

    if (wasDragging) {
      final extent = widget.registry.positionFromGlobalOffset(position);
      final base = _dragBase;
      _dragBase = null;
      _isShiftSelecting = false;
      if (base != null && extent != null) {
        widget.focusNode.requestFocus();
        widget.onSelectionChanged(
          DocumentSelection(base: base, extent: extent),
        );
      }
      return;
    }

    // A touch long-press already selected a word (and any drag extension was
    // handled by the branch above). Keep that selection instead of placing the
    // caret, which would collapse it back to a single position.
    if (longPressSelected) {
      _dragBase = null;
      _tapAnchor = null;
      _isShiftSelecting = false;
      return;
    }

    final handledBeyondContent =
        tapCount == 1 && _handleTapBeyondContent(position);
    if (handledBeyondContent) {
      _dragBase = null;
      _tapAnchor = null;
      _isShiftSelecting = false;
      return;
    }

    final anchor = _tapAnchor;
    if (anchor != null) {
      if (!isShiftSelecting &&
          anchor.path.isBlockObject &&
          _shouldDeferTapSelection(anchor, position)) {
        _deferTapSelection(anchor, position);
      } else {
        _requestFocusForTapSelection(anchor, position);
        if (tapCount >= 3) {
          _selectBlock(anchor);
        } else if (tapCount == 2) {
          _selectWord(anchor, position);
        } else if (isShiftSelecting && shiftBase != null) {
          widget.onSelectionChanged(
            DocumentSelection(base: shiftBase, extent: anchor),
          );
        } else if (anchor.path.isBlockObject) {
          _selectBlock(anchor);
        } else {
          final tappedCurrentCaret = _isCurrentCollapsedCaret(anchor);
          widget.onSelectionChanged(
            DocumentSelection(base: anchor, extent: anchor),
          );
          if (_shouldRequestMobileCaretToolbarForTap(
            event,
            anchor,
            position,
            tapCount: tapCount,
            isShiftSelecting: isShiftSelecting,
            tappedCurrentCaret: tappedCurrentCaret,
          )) {
            widget.onMobileCaretToolbarRequested?.call(anchor, position);
          }
        }
      }
    }
    _dragBase = null;
    _tapAnchor = null;
    _isShiftSelecting = false;
  }

  bool _shouldRequestMobileCaretToolbarForTap(
    PointerUpEvent event,
    DocumentPosition anchor,
    Offset globalPosition, {
    required int tapCount,
    required bool isShiftSelecting,
    required bool tappedCurrentCaret,
  }) {
    if (!widget.useMobileTouchGestures ||
        event.kind != PointerDeviceKind.touch ||
        tapCount != 1 ||
        isShiftSelecting ||
        !tappedCurrentCaret) {
      return false;
    }
    return _canRequestMobileCaretToolbar(anchor, globalPosition);
  }

  bool _isCurrentCollapsedCaret(DocumentPosition anchor) {
    final selection = widget.currentSelection;
    return selection != null &&
        selection.isCollapsed &&
        selection.extent == anchor;
  }

  bool _canRequestMobileCaretToolbar(
    DocumentPosition anchor,
    Offset globalPosition,
  ) {
    if (!widget.useMobileTouchGestures || !_isTextInputPath(anchor.path)) {
      return false;
    }
    // A link owns its touch interaction. It may still place a caret through the
    // normal selection path, but must not expose the editable caret toolbar.
    return widget.linkProbe?.call(globalPosition) == null;
  }

  bool _isTextInputPath(PositionPath path) {
    return path.isBlockText || path.isBlockCode || path.isTableCellText;
  }

  bool _shouldDeferTapSelection(
    DocumentPosition anchor,
    Offset globalPosition,
  ) {
    final predicate = widget.shouldDeferTapSelection;
    return predicate != null && predicate(anchor, globalPosition);
  }

  void _deferTapSelection(DocumentPosition anchor, Offset globalPosition) {
    final scheduler = SchedulerBinding.instance;
    scheduler.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final current = widget.registry.positionFromGlobalOffset(globalPosition);
      if (current == null ||
          current.blockId != anchor.blockId ||
          current.blockIndex != anchor.blockIndex ||
          current.path != anchor.path) {
        return;
      }
      final shouldCommit = widget.shouldCommitDeferredTapSelection;
      if (shouldCommit != null && !shouldCommit(anchor, globalPosition)) {
        return;
      }
      _requestFocusForTapSelection(anchor, globalPosition);
      _selectBlock(anchor);
    });
    // A resolver control normally schedules a frame when it changes playback
    // state, but a tap on a non-interactive part of the same video frame does
    // not. Ensure the deferred object selection is delivered in both cases.
    scheduler.scheduleFrame();
  }

  void _requestFocusForTapSelection(
    DocumentPosition anchor,
    Offset globalPosition,
  ) {
    final predicate = widget.shouldRequestFocusForTapSelection;
    if (predicate == null || predicate(anchor, globalPosition)) {
      widget.focusNode.requestFocus();
    }
  }

  bool _handleTapBeyondContent(Offset globalPosition) {
    final contentBottom = widget.registry.contentExtent();
    if (contentBottom == null || globalPosition.dy <= contentBottom) {
      return false;
    }
    final handler = widget.onTapBeyondContent;
    if (handler == null) {
      return false;
    }
    widget.focusNode.requestFocus();
    return handler(globalPosition);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_selectionExcludedPointer == event.pointer) {
      _selectionExcludedPointer = null;
    }
    if (_touchScrollPointer == event.pointer) {
      _touchScrollPointer = null;
    }
    _stopAutoScroll();
    _isDragging = false;
    _isShiftSelecting = false;
    _longPressWordSelected = false;
    _dragBase = null;
    _dragOrigin = null;
    _lastDragPosition = null;
    _tapAnchor = null;
    _linkOpenPending = null;
    _clearSelectionMoveState();
  }

  void _clearSelectionMoveState() {
    final wasMoving = _isMovingSelection;
    _isMovingSelection = false;
    _selectionMoveSource = null;
    widget.onSelectionMovePreviewChanged?.call(null);
    if (wasMoving && mounted) {
      setState(() {});
    }
  }

  void _updateActiveDrag(Offset global) {
    if (_isMovingSelection) {
      final source = _selectionMoveSource;
      final destination = widget.registry.positionFromGlobalOffset(global);
      widget.onSelectionMovePreviewChanged?.call(
        source == null ||
                destination == null ||
                !_isTextInputPath(destination.path) ||
                _positionIsInsideOrAtSelection(destination, source)
            ? null
            : destination,
      );
      return;
    }
    _extendSelection(global);
  }

  bool _positionIsInsideOrAtSelection(
    DocumentPosition position,
    DocumentSelection selection,
  ) {
    return position.compareTo(selection.start) >= 0 &&
        position.compareTo(selection.end) <= 0;
  }

  /// Extends the selection from [_dragBase] to the position resolved at
  /// [global].
  ///
  /// Both base and extent are obtained from [BlockGeometryRegistry]
  /// .positionFromGlobalOffset, which preserves [PositionPath] type
  /// information — when the pointer is inside a table cell, the resolved
  /// [DocumentPosition] carries a [PositionPath.tableCellText] path with
  /// correct [PositionPath.tableRowIndex]/[PositionPath.tableColumnIndex].
  /// The editor then uses [DocumentSelection.tableCellRange] (which applies
  /// min/max normalization) to determine the highlight rectangle.
  void _extendSelection(Offset global) {
    final base = _dragBase;
    if (base == null) {
      return;
    }
    final extent = widget.registry.positionFromGlobalOffset(global);
    if (extent == null) {
      return;
    }
    widget.onSelectionChanged(
      DocumentSelection(base: base, extent: extent),
    );
  }

  void _selectWord(DocumentPosition anchor, Offset global) {
    final range = widget.registry.wordRangeAt(
      anchor.blockId,
      anchor.offset,
      path: anchor.path,
    );
    if (range == null || range.isCollapsed) {
      widget.onSelectionChanged(
        DocumentSelection(base: anchor, extent: anchor),
      );
      return;
    }
    final start = anchor.copyWith(offset: range.start);
    final end = anchor.copyWith(offset: range.end);
    widget.onSelectionChanged(DocumentSelection(base: start, extent: end));
  }

  void _selectBlock(DocumentPosition anchor) {
    final length = widget.registry
            .paragraphRange(
              anchor.blockId,
              path: anchor.path,
            )
            ?.end ??
        anchor.offset;
    final start = anchor.copyWith(offset: 0);
    final end = anchor.copyWith(offset: length);
    widget.onSelectionChanged(DocumentSelection(base: start, extent: end));
  }

  /// Touch long-press handler: selects the word at the press point — the mobile
  /// counterpart of the desktop double-click word select, reusing [_selectWord].
  ///
  /// It then seeds a drag from the word's start (overriding the collapsed caret
  /// anchor set on pointer-down) so the user can immediately drag to extend the
  /// selection. [_isDragging] stays `false` until a subsequent move crosses slop
  /// in [_onPointerMove], and [_longPressWordSelected] tells [_onPointerUp] to
  /// keep the word selection when the press is released without a drag.
  ///
  /// The recognizer is touch-only (see [_gestureRecognizers]); mouse/pen never
  /// reach this path and keep their double-click word select.
  void _onLongPressStart(LongPressStartDetails details) {
    final global = details.globalPosition;
    // Mirror the tap/drag surface: never claim block chrome (handles,
    // checkboxes, collapse buttons) as a word selection.
    if (widget.registry.isSelectionExcluded(global)) {
      return;
    }
    final anchor = widget.registry.positionFromGlobalOffset(global);
    if (anchor == null) {
      return;
    }
    final range = widget.registry.wordRangeAt(
      anchor.blockId,
      anchor.offset,
      path: anchor.path,
    );
    final selectedRangeIsCollapsed = range == null || range.isCollapsed;
    _longPressWordSelected = true;
    widget.focusNode.requestFocus();
    _selectWord(anchor, global);
    if (selectedRangeIsCollapsed &&
        _canRequestMobileCaretToolbar(anchor, global)) {
      widget.onMobileCaretToolbarRequested?.call(anchor, global);
    }
    final baseOffset =
        range != null && !range.isCollapsed ? range.start : anchor.offset;
    _dragBase = anchor.copyWith(offset: baseOffset);
    _dragOrigin = global;
    _lastDragPosition = global;
  }

  /// Synchronously advances the scroll offset by one step when [global] is in
  /// the viewport edge band. This runs on every pointer-move for *every* device
  /// — it is the primary driver that keeps the list scrolling under a drag
  /// (the scrollable's own pan recognizer does not win the gesture arena here).
  /// All pointer kinds additionally get continuous scrolling via
  /// [_maybeStartAutoScroll] so a drag held still at the edge keeps going.
  void _syncScrollToEdge(Offset global) {
    final scrollable = widget.scrollController;
    if (!scrollable.hasClients) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    final viewportOrigin = renderBox.localToGlobal(Offset.zero);
    final viewportHeight = renderBox.size.height;
    final localY = global.dy - viewportOrigin.dy;

    double delta = 0;
    if (localY < _autoScrollEdge) {
      delta = -(_autoScrollEdge - localY).clamp(0.0, _maxAutoScrollPerFrame);
    } else if (localY > viewportHeight - _autoScrollEdge) {
      delta = (localY - (viewportHeight - _autoScrollEdge))
          .clamp(0.0, _maxAutoScrollPerFrame);
    }
    if (delta == 0) {
      return;
    }
    final next = (scrollable.offset + delta)
        .clamp(0.0, scrollable.position.maxScrollExtent);
    scrollable.position.jumpTo(next);
  }

  /// For drags of any pointer kind (mouse/pen/touch), starts (or stops) a
  /// continuous auto-scroll ticker so that holding the pointer still near an
  /// edge keeps scrolling and extending the selection past the visible area.
  ///
  /// The per-move [_syncScrollToEdge] only fires while the pointer is actually
  /// moving, so without this ticker a touch drag held still at the viewport edge
  /// would stop scrolling (the former C9 gap). The ticker closes that gap; touch
  /// and mouse now behave the same.
  void _maybeStartAutoScroll(Offset global) {
    final scrollable = widget.scrollController;
    if (!scrollable.hasClients) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    final viewportOrigin = renderBox.localToGlobal(Offset.zero);
    final viewportHeight = renderBox.size.height;
    final localY = global.dy - viewportOrigin.dy;

    // Compute the signed pixels-per-frame velocity. The closer the pointer is
    // to an edge, the faster we scroll (linear ramp up to the cap).
    double velocity = 0;
    if (localY < _autoScrollEdge) {
      final proximity = (_autoScrollEdge - localY) / _autoScrollEdge;
      velocity = -(_maxAutoScrollPerFrame * proximity);
    } else if (localY > viewportHeight - _autoScrollEdge) {
      final proximity =
          (localY - (viewportHeight - _autoScrollEdge)) / _autoScrollEdge;
      velocity = _maxAutoScrollPerFrame * proximity;
    }

    if (velocity.abs() < 0.5) {
      // Pointer left the edge band: stop continuous auto-scroll. The synchronous
      // edge scroll above still handled this move.
      _stopAutoScroll();
      return;
    }
    _autoScrollVelocity = velocity;
    _autoScrollTicker ??= Ticker(_onAutoScrollTick);
    if (!_autoScrollActive) {
      _autoScrollActive = true;
      _autoScrollTicker!.start();
    }
  }

  void _onAutoScrollTick(Duration elapsed) {
    final scrollable = widget.scrollController;
    if (!scrollable.hasClients) {
      _stopAutoScroll();
      return;
    }
    // Advance the scroll offset by one frame's worth of velocity and clamp to
    // the scroll bounds. When we reach a bound there is nothing more to scroll,
    // so stop the ticker to avoid burning frames.
    final maxExtent = scrollable.position.maxScrollExtent;
    final current = scrollable.offset;
    final next = (current + _autoScrollVelocity).clamp(0.0, maxExtent);
    if ((next - current).abs() < 0.1) {
      // Already at the scroll bound in the requested direction.
      _stopAutoScroll();
      return;
    }
    scrollable.position.jumpTo(next);
    // As content scrolls under a stationary mouse/stylus pointer, keep resolving
    // the extent at that same global coordinate so the visible highlight grows
    // with the scroll instead of jumping only on pointer-up.
    _scheduleAutoScrollSelectionExtend();
  }

  void _scheduleAutoScrollSelectionExtend() {
    if (_autoScrollExtendPending) {
      return;
    }
    _autoScrollExtendPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollExtendPending = false;
      if (!mounted || !_isDragging) {
        return;
      }
      final pointer = _lastDragPosition;
      if (pointer != null) {
        _updateActiveDrag(pointer);
      }
    });
  }

  void _stopAutoScroll() {
    if (_autoScrollActive) {
      _autoScrollActive = false;
      _autoScrollTicker?.stop();
    }
    _autoScrollVelocity = 0;
  }
}

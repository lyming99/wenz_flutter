import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/position/document_position.dart';
import 'block_geometry_registry.dart';
import 'link_hover_overlay.dart';

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
/// - drag → extend selection (cross-block), with auto-scroll near viewport edges
/// - auto-scroll → every drag (touch or mouse) synchronously scrolls one step
///   when the pointer enters the viewport edge band, so the list follows the
///   drag. For mouse/pen, a per-frame [Ticker] *additionally* keeps scrolling
///   while the pointer is held still near an edge, letting the user scroll
///   past the visible area. (Touch selection past the viewport uses dedicated
///   handles, tracked separately as C9.)
/// - double-tap → select word
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
    this.onTapBeyondContent,
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
  final bool Function(Offset globalPosition)? onTapBeyondContent;

  /// Resolves a global pointer position to the hovered inline link run, or
  /// `null` when the position is not over a link. Supplied by the editor (which
  /// owns the position→link resolver). Only consulted on mouse/pen hover, since
  /// [PointerHoverEvent] is never delivered for touch.
  final WenzLinkHoverInfo? Function(Offset global)? linkProbe;

  /// Reports the link currently under the hovering pointer (`null` when the
  /// pointer is over non-link content or leaves the surface). The editor uses
  /// this to show / hide / position [WenzLinkHoverOverlay], applying the hide
  /// delay itself so the popup can keep itself alive while the pointer rests on
  /// it. Reported only while [linkProbe] is supplied.
  final ValueChanged<WenzLinkHoverInfo?>? onLinkHover;

  /// Invoked when the user Ctrl/Cmd+clicks (mouse/stylus only) an inline link
  /// run, asking the host to open it. The host forwards the URL to
  /// [WenzRichTextEditor.onOpenLink]. The modifier-click is resolved in
  /// [_onPointerDown] via [linkProbe]; when it hits a link the caret/selection
  /// logic is suppressed so the editor's selection stays put, and pointer-up
  /// opens the link instead. When this is `null` (the host supplied no open
  /// handler) a modifier-click on a link falls through to normal caret
  /// placement. Touch never reaches this path (it requires a mouse/stylus
  /// pointer with a platform modifier held).
  final ValueChanged<WenzLinkHoverInfo>? onLinkOpen;

  final Widget child;

  /// The mouse cursor shown while hovering the editing surface. Editable
  /// surfaces show the text (I-beam) cursor so users know they can click to
  /// place the caret; read-only surfaces keep the default arrow.
  MouseCursor get cursor =>
      readOnly ? SystemMouseCursors.basic : SystemMouseCursors.text;

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
  DocumentPosition? _dragBase;
  bool _isDragging = false;
  Offset? _dragOrigin;
  Offset? _lastDragPosition;
  int? _selectionExcludedPointer;
  // Anchor position from the most recent pointer down, used for tap /
  // multi-click selection regardless of whether a drag starts.
  DocumentPosition? _tapAnchor;

  // When non-null, the in-progress pointer-down is a Ctrl/Cmd+click
  // (mouse/stylus) on an inline link: the caret/selection setup was suppressed
  // on down, and pointer-up opens the link instead of placing the caret.
  // Cleared on up, cancel, and exit.
  WenzLinkHoverInfo? _linkOpenPending;

  // Continuous auto-scroll (mouse/pen only). While the pointer is held near a
  // viewport edge, a ticker advances the scroll offset every frame, so a mouse
  // drag can scroll past the visible area without moving the pointer. Touch
  // relies on the per-move synchronous edge scroll plus its own pan recognizer.
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
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: widget.child,
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
  /// elsewhere the editable surface shows the text (I-beam) cursor and a
  /// read-only surface keeps the default arrow.
  MouseCursor _resolvedCursor() {
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
    // Ctrl/Cmd+click (mouse/stylus) on an inline link opens it instead of
    // placing the caret. Resolve it before the tap/multi-click/drag setup so
    // none of that state is recorded — pointer-up just opens and returns,
    // leaving the editor's selection untouched.
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

    _tapAnchor = widget.registry.positionFromGlobalOffset(position);
    if (_tapCount < 2) {
      _dragOrigin = position;
      _dragBase = _tapAnchor;
    } else {
      _dragOrigin = null;
      _dragBase = null;
    }
    _isDragging = false;
    _lastDragPosition = null;
  }

  /// Resolves whether a mouse/stylus pointer-down at [event] should open the
  /// inline link under it instead of placing the caret.
  ///
  /// Returns the hovered link run when the platform modifier is held — Ctrl on
  /// all platforms, Cmd on macOS (matching browser link-opening: Ctrl+click on
  /// Windows/Linux, Cmd+click on Mac) — and [widget.linkProbe] resolves a link
  /// at the position; otherwise `null`. Touch is excluded so a finger tap keeps
  /// its normal caret placement, and a modifier-click on non-link text falls
  /// through to the regular tap flow (the probe returns `null`).
  WenzLinkHoverInfo? _linkOpenFromDown(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse &&
        event.kind != PointerDeviceKind.stylus) {
      return null;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) {
      return null;
    }
    // Only treat this as an open-click when the host can actually open a link;
    // otherwise a Ctrl/Cmd+click on a link falls through to caret placement so
    // the text stays editable (mirroring the hover popup's disabled "Open").
    final probe = widget.linkProbe;
    final open = widget.onLinkOpen;
    if (probe == null || open == null) {
      return null;
    }
    return probe(event.position);
  }

  void _onPointerMove(PointerMoveEvent event) {
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
      _isDragging = true;
    }
    _lastDragPosition = position;
    _extendSelection(position);
    _syncScrollToEdge(position);
    _maybeStartAutoScroll(event.kind, position);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_selectionExcludedPointer == event.pointer) {
      _selectionExcludedPointer = null;
      return;
    }
    _stopAutoScroll();
    final position = event.position;
    final wasDragging = _isDragging;
    final tapCount = _tapCount;
    _isDragging = false;
    _dragOrigin = null;
    _lastDragPosition = null;

    // A Ctrl/Cmd+click on a link: open it and bail before the tap/selection
    // placement below, so neither requestFocus nor onSelectionChanged fires and
    // the caret stays where it was.
    final pendingLink = _linkOpenPending;
    if (pendingLink != null) {
      _linkOpenPending = null;
      _dragBase = null;
      _tapAnchor = null;
      widget.onLinkOpen?.call(pendingLink);
      return;
    }

    if (wasDragging) {
      final extent = widget.registry.positionFromGlobalOffset(position);
      final base = _dragBase;
      _dragBase = null;
      if (base != null && extent != null) {
        widget.focusNode.requestFocus();
        widget.onSelectionChanged(
          DocumentSelection(base: base, extent: extent),
        );
      }
      return;
    }

    final handledBeyondContent =
        tapCount == 1 && _handleTapBeyondContent(position);
    if (handledBeyondContent) {
      _dragBase = null;
      _tapAnchor = null;
      return;
    }

    final anchor = _tapAnchor;
    if (anchor != null) {
      widget.focusNode.requestFocus();
      if (tapCount >= 3) {
        _selectBlock(anchor);
      } else if (tapCount == 2) {
        _selectWord(anchor, position);
      } else if (anchor.path.isBlockObject) {
        _selectBlock(anchor);
      } else {
        widget.onSelectionChanged(
          DocumentSelection(base: anchor, extent: anchor),
        );
      }
    }
    _dragBase = null;
    _tapAnchor = null;
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
    _stopAutoScroll();
    _isDragging = false;
    _dragBase = null;
    _dragOrigin = null;
    _lastDragPosition = null;
    _tapAnchor = null;
    _linkOpenPending = null;
  }

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

  /// Synchronously advances the scroll offset by one step when [global] is in
  /// the viewport edge band. This runs on every pointer-move for *every* device
  /// — it is the primary driver that keeps the list scrolling under a drag
  /// (the scrollable's own pan recognizer does not win the gesture arena here).
  /// Mouse/pen get additional continuous scrolling via [_maybeStartAutoScroll].
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

  /// For mouse/pen drags, starts (or stops) a continuous auto-scroll ticker so
  /// that holding the pointer still near an edge keeps scrolling and extending
  /// the selection. Touch is left out: a touch drag's continuous motion already
  /// drives [_syncScrollToEdge] per move, and touch selection past the viewport
  /// uses dedicated handles (C9).
  void _maybeStartAutoScroll(PointerDeviceKind kind, Offset global) {
    if (kind != PointerDeviceKind.mouse && kind != PointerDeviceKind.stylus) {
      _stopAutoScroll();
      return;
    }
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
        _extendSelection(pointer);
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

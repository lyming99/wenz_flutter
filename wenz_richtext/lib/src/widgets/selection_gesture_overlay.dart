import 'package:flutter/widgets.dart';

import '../core/position/document_position.dart';
import 'block_geometry_registry.dart';

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
/// - tap → place collapsed caret
/// - drag → extend selection (cross-block), with auto-scroll near viewport edges
/// - double-tap → select word
/// - triple-tap → select block (paragraph)
class SelectionGestureOverlay extends StatefulWidget {
  const SelectionGestureOverlay({
    super.key,
    required this.registry,
    required this.scrollController,
    required this.focusNode,
    required this.readOnly,
    required this.onSelectionChanged,
    required this.child,
  });

  final BlockGeometryRegistry registry;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final bool readOnly;
  final ValueChanged<DocumentSelection> onSelectionChanged;
  final Widget child;

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
  // Anchor position from the most recent pointer down, used for tap /
  // multi-click selection regardless of whether a drag starts.
  DocumentPosition? _tapAnchor;

  static const Duration _multiClickWindow = Duration(milliseconds: 300);
  static const double _dragSlop = 18.0; // kTouchSlop-ish; generous for mouse.
  static const double _autoScrollEdge = 48.0;
  static const double _maxAutoScrollPerFrame = 24.0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
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

    // Always record the tap anchor so single/double/triple-tap can resolve a
    // position even when a drag is suppressed (multi-clicks suppress drag).
    _tapAnchor = widget.registry.positionFromGlobalOffset(position);
    // Start a potential drag from this point. Whether it becomes a tap or a
    // drag is decided on move/up. Multi-clicks (>=2) suppress drag start so
    // that double/triple-tap doesn't initiate a drag.
    if (_tapCount < 2) {
      _dragOrigin = position;
      _dragBase = _tapAnchor;
    } else {
      _dragOrigin = null;
      _dragBase = null;
    }
    _isDragging = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
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
    _extendSelection(position);
    _maybeAutoScroll(position);
  }

  void _onPointerUp(PointerUpEvent event) {
    final position = event.position;
    final wasDragging = _isDragging;
    final tapCount = _tapCount;
    _isDragging = false;
    _dragOrigin = null;

    if (wasDragging) {
      // Finalise the drag extent at the release point.
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

    // Tap handling (no drag crossed the slop threshold).
    final anchor = _tapAnchor;
    if (anchor != null) {
      widget.focusNode.requestFocus();
      if (tapCount >= 3) {
        _selectBlock(anchor);
      } else if (tapCount == 2) {
        _selectWord(anchor, position);
      } else {
        // Single tap: collapsed caret at the tap position.
        widget.onSelectionChanged(
          DocumentSelection(base: anchor, extent: anchor),
        );
      }
    }
    _dragBase = null;
    _tapAnchor = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _isDragging = false;
    _dragBase = null;
    _dragOrigin = null;
    _tapAnchor = null;
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
      // Fallback: collapsed caret.
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
    final length = widget.registry.paragraphRange(
          anchor.blockId,
          path: anchor.path,
        )?.end ??
        anchor.offset;
    final start = anchor.copyWith(offset: 0);
    final end = anchor.copyWith(offset: length);
    widget.onSelectionChanged(DocumentSelection(base: start, extent: end));
  }

  void _maybeAutoScroll(Offset global) {
    final scrollable = widget.scrollController;
    if (!scrollable.hasClients) {
      return;
    }
    // The overlay wraps the scrollable, so its own render box approximates the
    // viewport bounds used for edge detection.
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
}

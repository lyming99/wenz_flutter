import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controller/wenz_rich_text_controller.dart';
import '../core/position/document_position.dart';
import 'block_geometry_registry.dart';
import 'editor_context_menu.dart';

const double _kHandleRadius = 6.0;
const double _kHandleDiameter = _kHandleRadius * 2;
// Touch-friendly drag target around each handle circle.
const double _kHandleHitExtent = 36.0;
// Gap between the selection toolbar and the nearest handle, and a first-frame
// height estimate used until the toolbar is measured.
const double _kSelectionToolbarGap = 8.0;
const double _kEstimatedToolbarHeight = 56.0;
const double _kEstimatedCaretToolbarWidth = 168.0;

/// Builds the action content for the mobile toolbar shown beside a collapsed
/// caret. The editor owns eligibility and close state; this overlay owns only
/// placement, measurement, and pointer isolation.
typedef MobileCaretToolbarBuilder = Widget Function(
  BuildContext context,
  WenzRichTextController controller,
);

/// Builds the action content for the mobile toolbar shown beside an expanded
/// text selection. The editor provides callbacks so the toolbar can reuse its
/// established clipboard, selection, and input synchronization paths.
typedef MobileSelectionToolbarBuilder = Widget Function(
  BuildContext context,
  WenzRichTextController controller,
);

/// Touch selection handles for a non-capsed [DocumentSelection].
///
/// Draws a draggable round handle at each end of the current selection (the
/// start handle above the start caret, the end handle below the end caret).
/// Dragging a handle resolves the pointer position to a [DocumentPosition] via
/// the [BlockGeometryRegistry] and updates the selection through
/// [WenzRichTextController.setSelection], keeping the opposite edge fixed.
///
/// The overlay is mounted by the editor only on mobile surfaces (see
/// [WenzRichTextEditor.enableMobileSelectionHandles]); desktop selection keeps
/// its mouse-driven behaviour and never shows handles. Handle positions are
/// recomputed on every selection change and on every scroll frame (the carets
/// are read in global coordinates then mapped into [containerKey]'s local
/// space), so the handles follow the selection as the document scrolls or
/// reflows.
class MobileSelectionHandlesOverlay extends StatefulWidget {
  const MobileSelectionHandlesOverlay({
    super.key,
    required this.registry,
    required this.controller,
    required this.scrollController,
    required this.containerKey,
    this.caretToolbarPosition,
    this.caretToolbarBuilder,
    this.selectionToolbarBuilder,
  });

  /// Document geometry used to resolve caret rects and drag positions.
  final BlockGeometryRegistry registry;

  /// Editor controller whose selection the handles reflect and mutate.
  final WenzRichTextController controller;

  /// Scroll controller of the editor viewport — listened to so the handles
  /// reposition as content scrolls under them.
  final ScrollController scrollController;

  /// [GlobalKey] on the editor overlay [Stack] whose local coordinate space the
  /// handles are positioned in.
  final GlobalKey containerKey;

  /// The collapsed caret for which a toolbar was explicitly requested by a
  /// finger tap. `null` leaves collapsed selections free of a toolbar.
  final DocumentPosition? caretToolbarPosition;

  /// Supplies the caret-toolbar actions. It is optional so the positioning
  /// layer can be reused independently of a particular action set.
  final MobileCaretToolbarBuilder? caretToolbarBuilder;

  /// Supplies the expanded-selection toolbar actions. When omitted, the
  /// overlay keeps its standalone controller-backed copy/cut/select-all
  /// fallback toolbar for backwards compatibility.
  final MobileSelectionToolbarBuilder? selectionToolbarBuilder;

  @override
  State<MobileSelectionHandlesOverlay> createState() =>
      _MobileSelectionHandlesOverlayState();
}

class _MobileSelectionHandlesOverlayState
    extends State<MobileSelectionHandlesOverlay> {
  // The opposite selection edge captured when a handle drag starts, kept fixed
  // while the dragged edge follows the pointer. Cleared on pan end/cancel.
  DocumentPosition? _fixedEdge;

  // Selection toolbar measurement (post-frame) for accurate placement.
  final GlobalKey _toolbarKey = GlobalKey();
  Size? _toolbarSize;
  bool _toolbarMeasureScheduled = false;
  final GlobalKey _caretToolbarKey = GlobalKey();
  Size? _caretToolbarSize;
  bool _caretToolbarMeasureScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
    widget.scrollController.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant MobileSelectionHandlesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleChanged);
      widget.controller.addListener(_handleChanged);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleChanged);
      widget.scrollController.addListener(_handleChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);
    widget.scrollController.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  RenderBox? get _containerBox {
    final object = widget.containerKey.currentContext?.findRenderObject();
    return object is RenderBox ? object : null;
  }

  void _onHandlePanStart(bool isStart) {
    if (!mounted) {
      return;
    }
    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) {
      return;
    }
    setState(() {
      // Keep the opposite visual edge fixed while this handle moves.
      _fixedEdge = isStart ? selection.end : selection.start;
    });
  }

  void _onHandlePanUpdate(bool isStart, Offset global) {
    if (!mounted) {
      return;
    }
    final fixedEdge = _fixedEdge;
    if (fixedEdge == null) {
      return;
    }
    final dragged = widget.registry.positionFromGlobalOffset(global);
    if (dragged == null) {
      return;
    }
    widget.controller.setSelection(
      DocumentSelection(
        base: isStart ? dragged : fixedEdge,
        extent: isStart ? fixedEdge : dragged,
      ),
    );
  }

  void _onHandlePanEnd() {
    if (!mounted || _fixedEdge == null) {
      return;
    }
    setState(() {
      _fixedEdge = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.controller.selection;
    if (selection == null) {
      return const SizedBox.shrink();
    }
    final containerBox = _containerBox;
    if (containerBox == null || !containerBox.hasSize) {
      return const SizedBox.shrink();
    }
    if (selection.isCollapsed) {
      return _buildCollapsedCaretToolbar(selection, containerBox);
    }
    final startCaret = widget.registry.caretRectForPosition(selection.start);
    final endCaret = widget.registry.caretRectForPosition(selection.end);
    if (startCaret == null || endCaret == null) {
      return const SizedBox.shrink();
    }
    final handleColor = Theme.of(context).colorScheme.primary;
    // Caret rects are global; map them into the container Stack's local space.
    final startTip = containerBox.globalToLocal(
      Offset(startCaret.left, startCaret.top),
    );
    final endTip = containerBox.globalToLocal(
      Offset(endCaret.left, endCaret.bottom),
    );
    // Hide the toolbar while a handle is being dragged so it does not jump
    // around or overlap the moving selection edge.
    final showToolbar = _fixedEdge == null;
    if (showToolbar) {
      _scheduleToolbarMeasure();
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        _buildHandle(tip: startTip, isStart: true, color: handleColor),
        _buildHandle(tip: endTip, isStart: false, color: handleColor),
        if (showToolbar)
          _buildSelectionToolbar(startTip, endTip, containerBox),
      ],
    );
  }

  Widget _buildCollapsedCaretToolbar(
    DocumentSelection selection,
    RenderBox containerBox,
  ) {
    final caretPosition = widget.caretToolbarPosition;
    final builder = widget.caretToolbarBuilder;
    if (caretPosition == null ||
        builder == null ||
        selection.extent != caretPosition) {
      return const SizedBox.shrink();
    }
    final caretRect = widget.registry.caretRectForPosition(caretPosition);
    if (caretRect == null) {
      return const SizedBox.shrink();
    }
    final caretTop = containerBox.globalToLocal(
      Offset(caretRect.left, caretRect.top),
    );
    final caretBottom = containerBox.globalToLocal(
      Offset(caretRect.right, caretRect.bottom),
    );
    final media = MediaQuery.maybeOf(context);
    final keyboardTop = media == null
        ? containerBox.size.height
        : containerBox
            .globalToLocal(
              Offset(0, media.size.height - media.viewInsets.bottom),
            )
            .dy;
    final visibleTop = 0.0;
    final visibleBottom = math.min(containerBox.size.height, keyboardTop);
    if (!visibleBottom.isFinite ||
        visibleBottom <= visibleTop ||
        caretBottom.dy < visibleTop ||
        caretTop.dy > visibleBottom) {
      return const SizedBox.shrink();
    }

    _scheduleCaretToolbarMeasure();
    final measuredSize = _caretToolbarSize;
    if (measuredSize != null && measuredSize.width > containerBox.size.width) {
      return const SizedBox.shrink();
    }
    final toolbarHeight = measuredSize?.height ?? _kEstimatedToolbarHeight;
    final toolbarWidth = measuredSize?.width ??
        math.min(_kEstimatedCaretToolbarWidth, containerBox.size.width);
    final aboveSpace = caretTop.dy - visibleTop - _kSelectionToolbarGap;
    final belowSpace =
        visibleBottom - caretBottom.dy - _kSelectionToolbarGap;
    final double top;
    if (aboveSpace >= toolbarHeight) {
      top = caretTop.dy - _kSelectionToolbarGap - toolbarHeight;
    } else if (belowSpace >= toolbarHeight) {
      top = caretBottom.dy + _kSelectionToolbarGap;
    } else {
      // Do not cover the tap target when neither side can fit the toolbar.
      return const SizedBox.shrink();
    }
    final maxLeft = math.max(0.0, containerBox.size.width - toolbarWidth);
    final left = (caretTop.dx + caretBottom.dx - toolbarWidth) / 2;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: left.clamp(0.0, maxLeft).toDouble(),
          top: top,
          child: Listener(
            // This overlay is above SelectionGestureOverlay in the editor
            // Stack. An opaque listener prevents toolbar taps from reaching
            // document selection/focus/IME gesture handling underneath.
            behavior: HitTestBehavior.opaque,
            child: KeyedSubtree(
              key: _caretToolbarKey,
              child: builder(context, widget.controller),
            ),
          ),
        ),
      ],
    );
  }

  /// Measures the selection toolbar after layout so its placement (computed in
  /// [build]) is exact on the next frame. Mirrors the link-hover / table
  /// toolbar measure-then-place pattern.
  void _scheduleToolbarMeasure() {
    if (_toolbarMeasureScheduled) {
      return;
    }
    _toolbarMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toolbarMeasureScheduled = false;
      if (!mounted) {
        return;
      }
      final render = _toolbarKey.currentContext?.findRenderObject();
      if (render is! RenderBox || !render.hasSize) {
        return;
      }
      final next = render.size;
      final current = _toolbarSize;
      if (current != null &&
          (current.width - next.width).abs() < 0.5 &&
          (current.height - next.height).abs() < 0.5) {
        return;
      }
      setState(() {
        _toolbarSize = next;
      });
    });
  }

  void _scheduleCaretToolbarMeasure() {
    if (_caretToolbarMeasureScheduled) {
      return;
    }
    _caretToolbarMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _caretToolbarMeasureScheduled = false;
      if (!mounted) {
        return;
      }
      final render = _caretToolbarKey.currentContext?.findRenderObject();
      if (render is! RenderBox || !render.hasSize) {
        return;
      }
      final next = render.size;
      final current = _caretToolbarSize;
      if (current != null &&
          (current.width - next.width).abs() < 0.5 &&
          (current.height - next.height).abs() < 0.5) {
        return;
      }
      setState(() {
        _caretToolbarSize = next;
      });
    });
  }

  /// Builds the compact selection toolbar positioned above the selection
  /// (clear of the handles), flipping below when there is no room above.
  Widget _buildSelectionToolbar(
    Offset startTip,
    Offset endTip,
    RenderBox containerBox,
  ) {
    final size = _toolbarSize;
    final toolbarHeight = size?.height ?? _kEstimatedToolbarHeight;
    final toolbarWidth = size?.width ?? 0.0;
    final containerWidth = containerBox.size.width;
    final media = MediaQuery.maybeOf(context);
    final keyboardTop = media == null
        ? containerBox.size.height
        : containerBox
            .globalToLocal(
              Offset(0, media.size.height - media.viewInsets.bottom),
            )
            .dy;
    final visibleTop = 0.0;
    final visibleBottom = math.min(containerBox.size.height, keyboardTop);
    if (!visibleBottom.isFinite ||
        visibleBottom <= visibleTop ||
        startTip.dy > visibleBottom ||
        endTip.dy < visibleTop) {
      return const SizedBox.shrink();
    }
    // Prefer above the start handle; flip below the end handle if no room.
    final aboveBottom = startTip.dy - _kHandleDiameter - _kSelectionToolbarGap;
    final aboveTop = aboveBottom - toolbarHeight;
    final belowTop = endTip.dy + _kHandleDiameter + _kSelectionToolbarGap;
    final belowBottom = belowTop + toolbarHeight;
    final double top;
    if (aboveTop >= visibleTop && aboveBottom <= visibleBottom) {
      top = aboveTop;
    } else if (belowTop >= visibleTop && belowBottom <= visibleBottom) {
      top = belowTop;
    } else {
      // A short viewport (for example while the keyboard animates) cannot fit
      // the full toolbar on either side. Keep it visible and horizontally
      // bounded instead of letting it escape under the keyboard.
      final maxTop = visibleBottom - toolbarHeight;
      if (maxTop < visibleTop) {
        return const SizedBox.shrink();
      }
      top = aboveTop.clamp(visibleTop, maxTop).toDouble();
    }
    // Centre on the selection midpoint and clamp into the container so long
    // selections near an edge do not overflow the editor.
    final center = (startTip.dx + endTip.dx) / 2;
    final maxLeft = math.max(0.0, containerWidth - toolbarWidth);
    final left = (center - toolbarWidth / 2).clamp(0.0, maxLeft).toDouble();
    return Positioned(
      left: left,
      top: top,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: containerWidth),
        child: Listener(
          // This overlay is above SelectionGestureOverlay in the editor Stack.
          // Keeping the whole toolbar opaque prevents its taps and horizontal
          // scrolling gestures from reaching document selection underneath.
          behavior: HitTestBehavior.opaque,
          child: KeyedSubtree(
            key: _toolbarKey,
            child: widget.selectionToolbarBuilder?.call(
                  context,
                  widget.controller,
                ) ??
                WenzMobileSelectionToolbar(controller: widget.controller),
          ),
        ),
      ),
    );
  }

  /// Builds one draggable handle. The circle sits one radius away from [tip]
  /// (above for the start handle so it points down at the caret, below for the
  /// end handle so it points up); the [GestureDetector]'s hit area is the
  /// larger [_kHandleHitExtent] square centred on the circle for easy dragging.
  Widget _buildHandle({
    required Offset tip,
    required bool isStart,
    required Color color,
  }) {
    final centerDy = isStart ? tip.dy - _kHandleRadius : tip.dy + _kHandleRadius;
    final center = Offset(tip.dx, centerDy);
    final left = center.dx - _kHandleHitExtent / 2;
    final top = center.dy - _kHandleHitExtent / 2;
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        // Opaque so a drag that starts on the handle is claimed by the handle
        // and does not also drive the editor's content selection drag.
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _onHandlePanStart(isStart),
        onPanUpdate: (details) => _onHandlePanUpdate(isStart, details.globalPosition),
        onPanEnd: (_) => _onHandlePanEnd(),
        onPanCancel: _onHandlePanEnd,
        child: SizedBox(
          width: _kHandleHitExtent,
          height: _kHandleHitExtent,
          child: Center(
            child: Container(
              width: _kHandleDiameter,
              height: _kHandleDiameter,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

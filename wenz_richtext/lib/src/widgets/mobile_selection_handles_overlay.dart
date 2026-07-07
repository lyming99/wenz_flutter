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
const double _kEstimatedToolbarHeight = 48.0;

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
    final selection = widget.controller.selection;
    if (selection == null) {
      _fixedEdge = null;
      return;
    }
    // Keep the opposite visual edge fixed while this handle moves.
    _fixedEdge = isStart ? selection.end : selection.start;
  }

  void _onHandlePanUpdate(bool isStart, Offset global) {
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
    _fixedEdge = null;
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) {
      return const SizedBox.shrink();
    }
    final containerBox = _containerBox;
    if (containerBox == null || !containerBox.hasSize) {
      return const SizedBox.shrink();
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
    // Prefer above the start handle; flip below the end handle if no room.
    final aboveBottom = startTip.dy - _kHandleDiameter - _kSelectionToolbarGap;
    final double top;
    if (aboveBottom - toolbarHeight >= 0) {
      top = aboveBottom - toolbarHeight;
    } else {
      top = endTip.dy + _kHandleDiameter + _kSelectionToolbarGap;
    }
    // Centre on the selection midpoint and clamp into the container so long
    // selections near an edge do not overflow the editor.
    final center = (startTip.dx + endTip.dx) / 2;
    final maxLeft = math.max(0.0, containerWidth - toolbarWidth);
    final left = (center - toolbarWidth / 2).clamp(0.0, maxLeft).toDouble();
    return Positioned(
      left: left,
      top: top,
      child: WenzMobileSelectionToolbar(
        key: _toolbarKey,
        controller: widget.controller,
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

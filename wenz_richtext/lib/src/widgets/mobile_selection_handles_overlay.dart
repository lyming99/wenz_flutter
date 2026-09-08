import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
const double _kEstimatedSelectionToolbarWidth = 320.0;
const double _kToolbarScreenMargin = 8.0;

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

/// Touch selection handles for a non-collapsed [DocumentSelection].
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

  // Toolbars are route-level popups. Selection handles remain in the editor's
  // local Stack because their drag hit targets belong to the document surface.
  OverlayEntry? _toolbarOverlayEntry;
  OverlayState? _toolbarOverlay;
  _MobileSelectionToolbarAnchor? _toolbarAnchor;
  Rect? _toolbarVisibleRect;
  Rect? _toolbarSourceRect;
  ScrollPosition? _ancestorScrollPosition;
  bool _overlaySyncScheduled = false;
  bool _overlayShouldShow = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAncestorScrollPosition(Scrollable.maybeOf(context)?.position);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);
    widget.scrollController.removeListener(_handleChanged);
    _ancestorScrollPosition?.removeListener(_handleChanged);
    _removeToolbarOverlay();
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      final shouldShow = _refreshToolbarSnapshot();
      _overlayShouldShow = shouldShow;
      if (SchedulerBinding.instance.schedulerPhase !=
          SchedulerPhase.persistentCallbacks) {
        _toolbarOverlayEntry?.markNeedsBuild();
      }
      setState(() {});
    }
  }

  RenderBox? get _containerBox {
    final object = widget.containerKey.currentContext?.findRenderObject();
    return object is RenderBox ? object : null;
  }

  RenderBox? get _overlayBox {
    final object = Overlay.maybeOf(context)?.context.findRenderObject();
    return object is RenderBox && object.attached && object.hasSize
        ? object
        : null;
  }

  void _syncAncestorScrollPosition(ScrollPosition? position) {
    if (identical(_ancestorScrollPosition, position)) {
      return;
    }
    _ancestorScrollPosition?.removeListener(_handleChanged);
    _ancestorScrollPosition = position;
    _ancestorScrollPosition?.addListener(_handleChanged);
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
    final shouldShow = _refreshToolbarSnapshot();
    _scheduleOverlaySync(shouldShow);
    return _buildInlineHandles(widget.controller.selection, _containerBox);
  }

  bool _refreshToolbarSnapshot() {
    final selection = widget.controller.selection;
    final containerBox = _containerBox;
    final overlayBox = _overlayBox;
    final anchor = selection == null || overlayBox == null
        ? null
        : _toolbarAnchorFor(selection, overlayBox);
    final visibleRect =
        overlayBox == null ? null : _popupVisibleRect(overlayBox);
    final sourceRect = containerBox == null ||
            !containerBox.hasSize ||
            overlayBox == null
        ? null
        : Rect.fromPoints(
            overlayBox.globalToLocal(containerBox.localToGlobal(Offset.zero)),
            overlayBox.globalToLocal(
              containerBox.localToGlobal(
                (Offset.zero & containerBox.size).bottomRight,
              ),
            ),
          );
    _toolbarAnchor = anchor;
    _toolbarVisibleRect = visibleRect;
    _toolbarSourceRect = sourceRect;
    return anchor != null && visibleRect != null && sourceRect != null;
  }

  Rect? _popupVisibleRect(RenderBox overlayObject) {
    final overlayOrigin = overlayObject.localToGlobal(Offset.zero);
    final overlayRect = overlayOrigin & overlayObject.size;
    final media = MediaQuery.maybeOf(context);
    final mediaSize = media?.size ?? overlayObject.size;
    final padding = media?.padding ?? EdgeInsets.zero;
    final viewInsets = media?.viewInsets ?? EdgeInsets.zero;
    final screenRect = Rect.fromLTRB(
      padding.left + _kToolbarScreenMargin,
      padding.top + _kToolbarScreenMargin,
      math.max(
        padding.left + _kToolbarScreenMargin,
        mediaSize.width - padding.right - _kToolbarScreenMargin,
      ),
      math.max(
        padding.top + _kToolbarScreenMargin,
        math.min(
          mediaSize.height - padding.bottom - _kToolbarScreenMargin,
          mediaSize.height - viewInsets.bottom - _kToolbarScreenMargin,
        ),
      ),
    );
    final visibleGlobalRect = overlayRect.intersect(screenRect);
    if (visibleGlobalRect.isEmpty) {
      return null;
    }
    return Rect.fromPoints(
      overlayObject.globalToLocal(visibleGlobalRect.topLeft),
      overlayObject.globalToLocal(visibleGlobalRect.bottomRight),
    );
  }

  _MobileSelectionToolbarAnchor? _toolbarAnchorFor(
    DocumentSelection selection,
    RenderBox overlayBox,
  ) {
    if (selection.isCollapsed) {
      final caretPosition = widget.caretToolbarPosition;
      final builder = widget.caretToolbarBuilder;
      if (caretPosition == null ||
          builder == null ||
          selection.extent != caretPosition) {
        return null;
      }
      final caretRect = widget.registry.caretRectForPosition(caretPosition);
      if (caretRect == null) {
        return null;
      }
      return _MobileSelectionToolbarAnchor(
        kind: _MobileSelectionToolbarKind.caret,
        start: overlayBox.globalToLocal(caretRect.topLeft),
        end: overlayBox.globalToLocal(caretRect.bottomRight),
        toolbarBuilder: (context) => builder(context, widget.controller),
      );
    }

    // Suppress the popup while a handle is moving. Its route-level coordinate
    // space intentionally differs from the handle's editor-local drag space,
    // so keeping it mounted during the drag would create a distracting jump.
    if (_fixedEdge != null) {
      return null;
    }
    final startCaret = widget.registry.caretRectForPosition(selection.start);
    final endCaret = widget.registry.caretRectForPosition(selection.end);
    if (startCaret == null || endCaret == null) {
      return null;
    }
    return _MobileSelectionToolbarAnchor(
      kind: _MobileSelectionToolbarKind.selection,
      start: overlayBox.globalToLocal(
        Offset(startCaret.left, startCaret.top),
      ),
      end: overlayBox.globalToLocal(
        Offset(endCaret.left, endCaret.bottom),
      ),
      toolbarBuilder: (context) =>
          widget.selectionToolbarBuilder?.call(context, widget.controller) ??
          WenzMobileSelectionToolbar(controller: widget.controller),
    );
  }

  Widget _buildInlineHandles(
    DocumentSelection? selection,
    RenderBox? containerBox,
  ) {
    if (selection == null ||
        selection.isCollapsed ||
        containerBox == null ||
        !containerBox.hasSize) {
      return const SizedBox.expand();
    }
    final startCaret = widget.registry.caretRectForPosition(selection.start);
    final endCaret = widget.registry.caretRectForPosition(selection.end);
    if (startCaret == null || endCaret == null) {
      return const SizedBox.expand();
    }
    final handleColor = Theme.of(context).colorScheme.primary;
    final startTip = containerBox.globalToLocal(
      Offset(startCaret.left, startCaret.top),
    );
    final endTip = containerBox.globalToLocal(
      Offset(endCaret.left, endCaret.bottom),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        _buildHandle(tip: startTip, isStart: true, color: handleColor),
        _buildHandle(tip: endTip, isStart: false, color: handleColor),
      ],
    );
  }

  void _scheduleOverlaySync(bool shouldShow) {
    _overlayShouldShow = shouldShow;
    if (_overlaySyncScheduled) {
      return;
    }
    _overlaySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlaySyncScheduled = false;
      if (!mounted) {
        return;
      }
      _overlayShouldShow = _refreshToolbarSnapshot();
      if (_overlayShouldShow) {
        final overlay = Overlay.maybeOf(context);
        if (overlay == null) {
          _removeToolbarOverlay();
          return;
        }
        if (!identical(_toolbarOverlay, overlay)) {
          _removeToolbarOverlay();
        }
        if (_toolbarOverlayEntry == null) {
          final entry = OverlayEntry(builder: _buildToolbarOverlay);
          _toolbarOverlay = overlay;
          _toolbarOverlayEntry = entry;
          overlay.insert(entry);
        } else {
          _toolbarOverlayEntry!.markNeedsBuild();
        }
      } else {
        _removeToolbarOverlay();
      }
    });
  }

  Widget _buildToolbarOverlay(BuildContext context) {
    final anchor = _toolbarAnchor;
    final visibleRect = _toolbarVisibleRect;
    final sourceRect = _toolbarSourceRect;
    if (anchor == null || visibleRect == null || sourceRect == null) {
      return const SizedBox.shrink();
    }
    final popup = _MobileSelectionToolbarPopup(
      key: ValueKey<_MobileSelectionToolbarKind>(anchor.kind),
      kind: anchor.kind,
      startAnchor: anchor.start,
      endAnchor: anchor.end,
      sourceRect: sourceRect,
      visibleRect: visibleRect,
      toolbarBuilder: anchor.toolbarBuilder,
    );
    return InheritedTheme.captureAll(this.context, popup);
  }

  void _removeToolbarOverlay() {
    final entry = _toolbarOverlayEntry;
    _toolbarOverlayEntry = null;
    _toolbarOverlay = null;
    if (entry == null) {
      return;
    }
    entry.remove();
    entry.dispose();
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
    final centerDy =
        isStart ? tip.dy - _kHandleRadius : tip.dy + _kHandleRadius;
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
        onPanUpdate: (details) =>
            _onHandlePanUpdate(isStart, details.globalPosition),
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

enum _MobileSelectionToolbarKind { caret, selection }

class _MobileSelectionToolbarAnchor {
  const _MobileSelectionToolbarAnchor({
    required this.kind,
    required this.start,
    required this.end,
    required this.toolbarBuilder,
  });

  final _MobileSelectionToolbarKind kind;
  final Offset start;
  final Offset end;
  final WidgetBuilder toolbarBuilder;
}

/// Route-overlay popup for the mobile caret/selection actions.
///
/// The anchor, source and visible-route coordinates use the route Overlay's
/// space, so the popup can use the whole route instead of the editor/card's
/// bounds. This lets a toolbar near the top of a chat bubble sit above it
/// instead of covering text.
class _MobileSelectionToolbarPopup extends StatefulWidget {
  const _MobileSelectionToolbarPopup({
    super.key,
    required this.kind,
    required this.startAnchor,
    required this.endAnchor,
    required this.sourceRect,
    required this.visibleRect,
    required this.toolbarBuilder,
  });

  final _MobileSelectionToolbarKind kind;
  final Offset startAnchor;
  final Offset endAnchor;
  final Rect sourceRect;
  final Rect visibleRect;
  final WidgetBuilder toolbarBuilder;

  @override
  State<_MobileSelectionToolbarPopup> createState() =>
      _MobileSelectionToolbarPopupState();
}

class _MobileSelectionToolbarPopupState
    extends State<_MobileSelectionToolbarPopup> {
  final GlobalKey _toolbarKey = GlobalKey();
  Size? _toolbarSize;
  bool _measureScheduled = false;

  @override
  Widget build(BuildContext context) {
    final visibleLeft = widget.visibleRect.left;
    final visibleRight = widget.visibleRect.right;
    final visibleTop = widget.visibleRect.top;
    final visibleBottom = widget.visibleRect.bottom;

    final selectionTop = math.min(
      widget.startAnchor.dy,
      widget.endAnchor.dy,
    );
    final selectionBottom = math.max(
      widget.startAnchor.dy,
      widget.endAnchor.dy,
    );
    final sourceVisibleTop = math.max(visibleTop, widget.sourceRect.top);
    final sourceVisibleBottom =
        math.min(visibleBottom, widget.sourceRect.bottom);
    if (!selectionTop.isFinite ||
        !selectionBottom.isFinite ||
        sourceVisibleBottom <= sourceVisibleTop ||
        selectionBottom < sourceVisibleTop ||
        selectionTop > sourceVisibleBottom) {
      return const SizedBox.shrink();
    }

    _scheduleMeasure();
    final availableWidth = math.max(0.0, visibleRight - visibleLeft);
    if (availableWidth <= 0 || visibleBottom <= visibleTop) {
      return const SizedBox.shrink();
    }
    final estimatedWidth = widget.kind == _MobileSelectionToolbarKind.caret
        ? _kEstimatedCaretToolbarWidth
        : _kEstimatedSelectionToolbarWidth;
    final toolbarWidth = (_toolbarSize?.width ?? estimatedWidth)
        .clamp(0.0, availableWidth)
        .toDouble();
    final toolbarHeight = _toolbarSize?.height ?? _kEstimatedToolbarHeight;
    if (toolbarHeight > visibleBottom - visibleTop) {
      return const SizedBox.shrink();
    }

    final handleClearance = widget.kind == _MobileSelectionToolbarKind.selection
        ? _kHandleDiameter
        : 0.0;
    final aboveBottom =
        widget.startAnchor.dy - handleClearance - _kSelectionToolbarGap;
    final aboveTop = aboveBottom - toolbarHeight;
    final belowTop =
        widget.endAnchor.dy + handleClearance + _kSelectionToolbarGap;
    final belowBottom = belowTop + toolbarHeight;
    final double top;
    if (aboveTop >= visibleTop && aboveBottom <= visibleBottom) {
      top = aboveTop;
    } else if (belowTop >= visibleTop && belowBottom <= visibleBottom) {
      top = belowTop;
    } else {
      // During keyboard animation or near a screen edge, keep the popup inside
      // the visible route. Prefer the side with more free space so it obscures
      // as little selected content as possible.
      final aboveSpace = math.max(0.0, aboveBottom - visibleTop);
      final belowSpace = math.max(0.0, visibleBottom - belowTop);
      top = (aboveSpace >= belowSpace ? aboveTop : belowTop)
          .clamp(visibleTop, visibleBottom - toolbarHeight)
          .toDouble();
    }

    final anchorCenter = (widget.startAnchor.dx + widget.endAnchor.dx) / 2;
    final maxLeft = visibleRight - toolbarWidth;
    final left = (anchorCenter - toolbarWidth / 2)
        .clamp(visibleLeft, maxLeft)
        .toDouble();
    return Positioned(
      left: left,
      top: top,
      child: ConstrainedBox(
        key: _toolbarKey,
        constraints: BoxConstraints(maxWidth: availableWidth),
        child: Listener(
          key: const ValueKey<String>('wenz.mobile-selection-toolbar-popup'),
          // The popup is in the route Overlay, above the document gesture
          // surface. Opaque hit testing keeps taps and horizontal scrolling on
          // the toolbar from moving the selection underneath.
          behavior: HitTestBehavior.opaque,
          child: widget.toolbarBuilder(context),
        ),
      ),
    );
  }

  void _scheduleMeasure() {
    if (_measureScheduled) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) {
        return;
      }
      final renderObject = _toolbarKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        return;
      }
      final next = renderObject.size;
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
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controller/wenz_rich_text_controller.dart';
import '../core/position/document_position.dart';
import 'block_geometry_registry.dart';

const double _kToolbarGap = 8.0;
const double _kViewportInset = 8.0;
const double _kToolbarMaxWidth = 720.0;
const double _kEstimatedToolbarHeight = 52.0;
const double _kToolbarRadius = 10.0;
const double _kToolbarElevation = 3.0;

/// Selects how the default desktop toolbar is presented.
enum WenzDesktopToolbarMode {
  /// Keeps the existing host-owned toolbar in a fixed layout position.
  ///
  /// The editor does not mount an internal toolbar in this mode. Hosts keep
  /// rendering [WenzEditorBootstrap.buildDefaultDesktopToolbar] where desired.
  fixed,

  /// Shows the desktop toolbar beside an expanded ordinary text selection.
  ///
  /// The toolbar follows selection and scroll geometry, preferring the space
  /// above the selection and flipping below when needed.
  selectionFloating,
}

/// Builds the command surface placed by [WenzDesktopSelectionToolbarOverlay].
typedef WenzDesktopSelectionToolbarBuilder = Widget Function(
  BuildContext context,
);

/// Positions a desktop toolbar beside the current expanded text selection.
///
/// This widget owns placement and pointer isolation only. It does not create or
/// dispose editor/toolbar controllers, and it does not decide whether the host
/// is currently using desktop UI. [WenzRichTextEditor] performs those policy
/// checks before mounting it.
class WenzDesktopSelectionToolbarOverlay extends StatefulWidget {
  const WenzDesktopSelectionToolbarOverlay({
    super.key,
    required this.registry,
    required this.controller,
    required this.scrollController,
    required this.containerKey,
    required this.toolbarBuilder,
    this.maxWidth = _kToolbarMaxWidth,
    this.gap = _kToolbarGap,
    this.viewportInset = _kViewportInset,
  })  : assert(maxWidth > 0),
        assert(gap >= 0),
        assert(viewportInset >= 0);

  final BlockGeometryRegistry registry;
  final WenzRichTextController controller;
  final ScrollController scrollController;
  final GlobalKey containerKey;
  final WenzDesktopSelectionToolbarBuilder toolbarBuilder;

  /// Maximum width of the floating surface before its toolbar scrolls.
  final double maxWidth;

  /// Space between the toolbar and the selection.
  final double gap;

  /// Minimum distance from the editor viewport edges.
  final double viewportInset;

  @override
  State<WenzDesktopSelectionToolbarOverlay> createState() =>
      _WenzDesktopSelectionToolbarOverlayState();
}

class _WenzDesktopSelectionToolbarOverlayState
    extends State<WenzDesktopSelectionToolbarOverlay> {
  final GlobalKey _toolbarKey = GlobalKey();
  Size? _toolbarSize;
  bool _measureScheduled = false;
  bool _geometryRetryScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
    widget.scrollController.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(
    covariant WenzDesktopSelectionToolbarOverlay oldWidget,
  ) {
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
    final renderObject = widget.containerKey.currentContext?.findRenderObject();
    return renderObject is RenderBox ? renderObject : null;
  }

  bool _supportsSelection(DocumentSelection selection) {
    if (selection.isCollapsed) {
      return false;
    }
    final startPath = selection.start.path;
    final endPath = selection.end.path;
    final startIsOrdinaryText = startPath.isBlockText || startPath.isBlockCode;
    final endIsOrdinaryText = endPath.isBlockText || endPath.isBlockCode;
    return startIsOrdinaryText && endIsOrdinaryText;
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.controller.selection;
    if (selection == null || !_supportsSelection(selection)) {
      return const SizedBox.shrink();
    }

    final containerBox = _containerBox;
    if (containerBox == null || !containerBox.hasSize) {
      _scheduleGeometryRetry();
      return const SizedBox.shrink();
    }
    final startCaret = widget.registry.caretRectForPosition(selection.start);
    final endCaret = widget.registry.caretRectForPosition(selection.end);
    if (startCaret == null || endCaret == null) {
      _scheduleGeometryRetry();
      return const SizedBox.shrink();
    }

    final startTop = containerBox.globalToLocal(startCaret.topLeft);
    final endBottom = containerBox.globalToLocal(endCaret.bottomRight);
    final visibleTop = widget.viewportInset;
    final visibleBottom = containerBox.size.height - widget.viewportInset;
    if (visibleBottom <= visibleTop ||
        startTop.dy > visibleBottom ||
        endBottom.dy < visibleTop) {
      return const SizedBox.shrink();
    }

    final availableWidth = math.max(
      0.0,
      containerBox.size.width - widget.viewportInset * 2,
    );
    if (availableWidth <= 0) {
      return const SizedBox.shrink();
    }
    final toolbarWidth = math.min(widget.maxWidth, availableWidth);
    final toolbarHeight = _toolbarSize?.height ?? _kEstimatedToolbarHeight;
    final aboveTop = startTop.dy - widget.gap - toolbarHeight;
    final belowTop = endBottom.dy + widget.gap;
    final maxTop = visibleBottom - toolbarHeight;
    if (maxTop < visibleTop) {
      return const SizedBox.shrink();
    }

    final double top;
    if (aboveTop >= visibleTop) {
      top = aboveTop;
    } else if (belowTop + toolbarHeight <= visibleBottom) {
      top = belowTop;
    } else {
      top = aboveTop.clamp(visibleTop, maxTop).toDouble();
    }

    final selectionCenterX = (startTop.dx + endBottom.dx) / 2;
    final minLeft = widget.viewportInset;
    final maxLeft =
        containerBox.size.width - widget.viewportInset - toolbarWidth;
    final left = (selectionCenterX - toolbarWidth / 2)
        .clamp(minLeft, math.max(minLeft, maxLeft))
        .toDouble();

    _scheduleMeasure();
    return Positioned(
      left: left,
      top: top,
      width: toolbarWidth,
      child: Listener(
        key: const ValueKey<String>(
          'wenz-richtext-desktop-selection-toolbar',
        ),
        behavior: HitTestBehavior.opaque,
        child: Material(
          key: _toolbarKey,
          color: Theme.of(context).colorScheme.surface,
          elevation: _kToolbarElevation,
          shadowColor: Theme.of(context).colorScheme.shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kToolbarRadius),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
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

  void _scheduleGeometryRetry() {
    if (_geometryRetryScheduled) {
      return;
    }
    _geometryRetryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geometryRetryScheduled = false;
      if (mounted) {
        setState(() {});
      }
    });
  }
}

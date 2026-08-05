import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/position/document_position.dart';

// Visual chrome is owned by toolbar builders; this host only measures, clamps,
// and positions overlays per docs/design/menu_toolbar_minimal_spec.md.
const double _kTableFloatingToolbarDefaultMinWidth = 0.0;
const double _kTableFloatingToolbarDefaultGap = 4.0;
const double _kTableFloatingToolbarDefaultFallbackHeight = 36.0;

/// Builds the visible table toolbar for an overlay request.
typedef TableFloatingToolbarOverlayBuilder = Widget Function(
  BuildContext context,
);

/// Creates a request after the table anchor owns a [LayerLink] and overlay rect.
typedef TableFloatingToolbarOverlayRequestBuilder
    = TableFloatingToolbarOverlayRequest Function({
  required Object owner,
  required LayerLink anchorLink,
  required Rect anchorRect,
  required double visibleTop,
  required double visibleBottom,
});

/// Immutable payload sent from a table renderer to the editor-owned overlay host.
///
/// The table renderer owns only the anchor and the current toolbar payload. The
/// editor owns [TableFloatingToolbarOverlayHost], which renders this payload with
/// Flutter's system [OverlayPortal]. This keeps the toolbar outside the table
/// block's internal [Stack], so it can cross parent bounds and participate in
/// overlay hit testing without making renderers manage overlay entries directly.
@immutable
class TableFloatingToolbarOverlayRequest {
  const TableFloatingToolbarOverlayRequest({
    required this.owner,
    required this.anchorLink,
    required this.anchorRect,
    required this.visibleTop,
    required this.tableBlockId,
    required this.blockIndex,
    required this.selectionRange,
    required this.toolbarBuilder,
    this.enabled = true,
    this.minWidth = _kTableFloatingToolbarDefaultMinWidth,
    this.gap = _kTableFloatingToolbarDefaultGap,
    this.fallbackHeight = _kTableFloatingToolbarDefaultFallbackHeight,
    this.visibleBottom = double.infinity,
  });

  /// Opaque identity of the renderer anchor that published this request.
  final Object owner;

  /// Link followed by the system overlay entry.
  final LayerLink anchorLink;

  /// Current rect of the table block anchor in the target overlay coordinates.
  final Rect anchorRect;

  /// Top edge of the visible editor viewport in target overlay coordinates.
  final double visibleTop;

  /// Bottom edge of the visible editor viewport in target overlay coordinates.
  final double visibleBottom;

  /// Active table identity used by hosts/tests to reason about request staleness.
  final String tableBlockId;

  /// Active table block index in the source document.
  final int blockIndex;

  /// Current table-cell selection range that the toolbar actions target.
  final TableCellRange selectionRange;

  /// Builds toolbar chrome. The renderer captures the table action callback here
  /// so the overlay host never calls back into renderer state directly.
  final TableFloatingToolbarOverlayBuilder toolbarBuilder;

  /// Whether this request may be shown. Hosts hide disabled requests.
  final bool enabled;

  /// Minimum toolbar width, independent from the table block's layout width.
  final double minWidth;

  /// Gap between the toolbar bottom and the table anchor top.
  final double gap;

  /// Height used until the overlay measures its real toolbar child.
  final double fallbackHeight;
}

/// Last known geometry for a rendered table toolbar anchor.
@immutable
class TableFloatingToolbarAnchorSnapshot {
  const TableFloatingToolbarAnchorSnapshot({
    required this.owner,
    required this.anchorLink,
    required this.anchorRect,
    required this.visibleTop,
    required this.visibleBottom,
    required this.tableBlockId,
    required this.blockIndex,
  });

  final Object owner;
  final LayerLink anchorLink;
  final Rect anchorRect;
  final double visibleTop;
  final double visibleBottom;
  final String tableBlockId;
  final int blockIndex;
}

/// Editor-owned controller for the active table toolbar overlay request.
class TableFloatingToolbarOverlayController extends ChangeNotifier {
  TableFloatingToolbarOverlayRequest? _request;
  final Map<String, TableFloatingToolbarAnchorSnapshot> _anchors =
      <String, TableFloatingToolbarAnchorSnapshot>{};

  TableFloatingToolbarOverlayRequest? get request => _request;

  TableFloatingToolbarAnchorSnapshot? anchorFor(
    String tableBlockId, {
    int? blockIndex,
  }) {
    final anchor = _anchors[tableBlockId];
    if (anchor == null ||
        (blockIndex != null && anchor.blockIndex != blockIndex)) {
      return null;
    }
    return anchor;
  }

  void updateAnchor(TableFloatingToolbarAnchorSnapshot anchor) {
    _anchors[anchor.tableBlockId] = anchor;
  }

  void unregisterAnchor({required Object owner}) {
    _anchors.removeWhere((_, anchor) => identical(anchor.owner, owner));
    hide(owner: owner);
  }

  void show(
    TableFloatingToolbarOverlayRequest request, {
    bool replaceDifferentRequest = true,
  }) {
    final current = _request;
    if (!replaceDifferentRequest &&
        current != null &&
        !_targetsSameActiveSelection(current, request)) {
      return;
    }
    _request = request;
    notifyListeners();
  }

  bool _targetsSameActiveSelection(
    TableFloatingToolbarOverlayRequest current,
    TableFloatingToolbarOverlayRequest next,
  ) {
    return identical(current.owner, next.owner) ||
        (current.tableBlockId == next.tableBlockId &&
            current.blockIndex == next.blockIndex &&
            current.selectionRange == next.selectionRange);
  }

  void hide({Object? owner}) {
    final current = _request;
    if (current == null) {
      return;
    }
    if (owner != null && !identical(current.owner, owner)) {
      return;
    }
    _request = null;
    notifyListeners();
  }
}

/// Editor-level host that renders table toolbar requests into the system overlay.
class TableFloatingToolbarOverlayHost extends StatefulWidget {
  const TableFloatingToolbarOverlayHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final TableFloatingToolbarOverlayController controller;
  final Widget child;

  @override
  State<TableFloatingToolbarOverlayHost> createState() =>
      _TableFloatingToolbarOverlayHostState();
}

class _TableFloatingToolbarOverlayHostState
    extends State<TableFloatingToolbarOverlayHost> {
  final OverlayPortalController _portalController = OverlayPortalController();
  TableFloatingToolbarOverlayRequest? _request;

  @override
  void initState() {
    super.initState();
    _request = widget.controller.request;
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPortal());
  }

  @override
  void didUpdateWidget(covariant TableFloatingToolbarOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleControllerChanged);
    _request = widget.controller.request;
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPortal());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portalController,
      overlayChildBuilder: (context, info) {
        final request = _request;
        if (request == null || !request.enabled) {
          return const SizedBox.shrink();
        }
        return _TableFloatingToolbarOverlayEntry(
          request: request,
          overlaySize: info.overlaySize,
        );
      },
      child: widget.child,
    );
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _handleControllerChanged());
      return;
    }
    setState(() {
      _request = widget.controller.request;
    });
    _syncPortal();
  }

  void _syncPortal() {
    if (!mounted) {
      return;
    }
    final shouldShow = _request?.enabled == true;
    if (shouldShow) {
      if (!_portalController.isShowing) {
        _portalController.show();
      }
    } else if (_portalController.isShowing) {
      _portalController.hide();
    }
  }
}

/// Anchor installed by table renderers. It publishes or withdraws requests while
/// leaving overlay ownership with [TableFloatingToolbarOverlayHost].
class TableFloatingToolbarOverlayAnchor extends StatefulWidget {
  const TableFloatingToolbarOverlayAnchor({
    super.key,
    required this.controller,
    required this.requestBuilder,
    required this.tableBlockId,
    required this.blockIndex,
    required this.child,
  });

  final TableFloatingToolbarOverlayController? controller;
  final TableFloatingToolbarOverlayRequestBuilder? requestBuilder;
  final String tableBlockId;
  final int blockIndex;
  final Widget child;

  @override
  State<TableFloatingToolbarOverlayAnchor> createState() =>
      _TableFloatingToolbarOverlayAnchorState();
}

class _TableFloatingToolbarOverlayAnchorState
    extends State<TableFloatingToolbarOverlayAnchor>
    with WidgetsBindingObserver {
  final LayerLink _anchorLink = LayerLink();
  final Object _owner = Object();
  ScrollPosition? _scrollPosition;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant TableFloatingToolbarOverlayAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.tableBlockId != widget.tableBlockId) {
      oldWidget.controller?.unregisterAnchor(owner: _owner);
    }
    _scheduleSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncScrollPosition(Scrollable.maybeOf(context)?.position);
    _scheduleSync();
  }

  @override
  void didChangeMetrics() {
    _scheduleSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_scheduleSync);
    widget.controller?.unregisterAnchor(owner: _owner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _scheduleSync();
        return false;
      },
      child: CompositedTransformTarget(
        link: _anchorLink,
        child: widget.child,
      ),
    );
  }

  void _scheduleSync() {
    if (_syncScheduled) {
      return;
    }
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      _syncRequest();
    });
  }

  void _syncScrollPosition(ScrollPosition? position) {
    if (identical(_scrollPosition, position)) {
      return;
    }
    _scrollPosition?.removeListener(_scheduleSync);
    _scrollPosition = position;
    _scrollPosition?.addListener(_scheduleSync);
  }

  void _syncRequest() {
    if (!mounted) {
      return;
    }
    final controller = widget.controller;
    if (controller == null) {
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      controller.unregisterAnchor(owner: _owner);
      return;
    }
    final overlayBox = _overlayRenderBoxFor(context);
    final anchorTopLeft = renderObject.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final anchorRect = anchorTopLeft & renderObject.size;
    final visibleBounds = _visibleBoundsFor(context, overlayBox);
    controller.updateAnchor(
      TableFloatingToolbarAnchorSnapshot(
        owner: _owner,
        anchorLink: _anchorLink,
        anchorRect: anchorRect,
        visibleTop: visibleBounds.top,
        visibleBottom: visibleBounds.bottom,
        tableBlockId: widget.tableBlockId,
        blockIndex: widget.blockIndex,
      ),
    );
    if (!_anchorIntersectsVisibleBounds(anchorRect, visibleBounds)) {
      controller.hide(owner: _owner);
      return;
    }
    final requestBuilder = widget.requestBuilder;
    if (requestBuilder == null) {
      controller.hide(owner: _owner);
      return;
    }
    final request = requestBuilder(
      owner: _owner,
      anchorLink: _anchorLink,
      anchorRect: anchorRect,
      visibleTop: visibleBounds.top,
      visibleBottom: visibleBounds.bottom,
    );
    controller.show(
      _withVisibleBounds(
        request,
        anchorRect: anchorRect,
        visibleBounds: visibleBounds,
      ),
      replaceDifferentRequest: false,
    );
  }

  RenderBox? _overlayRenderBoxFor(BuildContext context) {
    final renderObject = Overlay.maybeOf(context)?.context.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.attached &&
        renderObject.hasSize) {
      return renderObject;
    }
    return null;
  }

  ({double top, double bottom}) _visibleBoundsFor(
    BuildContext context,
    RenderBox? overlayBox,
  ) {
    final scrollable = Scrollable.maybeOf(context);
    final viewportObject = scrollable?.context.findRenderObject();
    if (viewportObject is RenderBox &&
        viewportObject.attached &&
        viewportObject.hasSize) {
      final viewportTopLeft = viewportObject.localToGlobal(
        Offset.zero,
        ancestor: overlayBox,
      );
      return (
        top: viewportTopLeft.dy,
        bottom: viewportTopLeft.dy + viewportObject.size.height,
      );
    }
    final mediaQuery = MediaQuery.maybeOf(context);
    // Stack the soft-keyboard inset on top of the status-bar padding so the
    // floating toolbar clears the IME on mobile. Desktop has no IME, so
    // viewInsets.bottom is 0 and the result matches the legacy top-only
    // padding exactly.
    final paddingTop =
        (mediaQuery?.padding.top ?? 0) + (mediaQuery?.viewInsets.bottom ?? 0);
    if (overlayBox == null) {
      return (top: paddingTop, bottom: double.infinity);
    }
    final visibleTop = overlayBox.globalToLocal(Offset(0, paddingTop)).dy;
    return (top: visibleTop, bottom: overlayBox.size.height);
  }

  bool _anchorIntersectsVisibleBounds(
    Rect anchorRect,
    ({double top, double bottom}) visibleBounds,
  ) {
    if (visibleBounds.bottom < visibleBounds.top) {
      return true;
    }
    return anchorRect.bottom >= visibleBounds.top &&
        anchorRect.top <= visibleBounds.bottom;
  }

  TableFloatingToolbarOverlayRequest _withVisibleBounds(
    TableFloatingToolbarOverlayRequest request, {
    required Rect anchorRect,
    required ({double top, double bottom}) visibleBounds,
  }) {
    return TableFloatingToolbarOverlayRequest(
      owner: request.owner,
      anchorLink: request.anchorLink,
      anchorRect: anchorRect,
      visibleTop: visibleBounds.top,
      visibleBottom: visibleBounds.bottom,
      tableBlockId: request.tableBlockId,
      blockIndex: request.blockIndex,
      selectionRange: request.selectionRange,
      toolbarBuilder: request.toolbarBuilder,
      enabled: request.enabled,
      minWidth: request.minWidth,
      gap: request.gap,
      fallbackHeight: request.fallbackHeight,
    );
  }
}

class _TableFloatingToolbarOverlayEntry extends StatefulWidget {
  const _TableFloatingToolbarOverlayEntry({
    required this.request,
    required this.overlaySize,
  });

  final TableFloatingToolbarOverlayRequest request;
  final Size overlaySize;

  @override
  State<_TableFloatingToolbarOverlayEntry> createState() =>
      _TableFloatingToolbarOverlayEntryState();
}

class _TableFloatingToolbarOverlayEntryState
    extends State<_TableFloatingToolbarOverlayEntry> {
  final GlobalKey _toolbarKey = GlobalKey();
  Size? _toolbarSize;
  bool _measureScheduled = false;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    if (!_requestAnchorIntersectsVisibleViewport(request)) {
      return const SizedBox.shrink();
    }
    _scheduleMeasure();
    final toolbarHeight = _toolbarSize?.height ?? request.fallbackHeight;
    final overlayWidth = math.max(0.0, widget.overlaySize.width);
    final maxWidth = overlayWidth;
    final minWidth = math.min(request.minWidth, maxWidth);
    final toolbarWidth = (_toolbarSize?.width ?? minWidth).clamp(
      0.0,
      maxWidth,
    );
    final maxLeft = math.max(0.0, overlayWidth - toolbarWidth);
    final left = (request.anchorRect.right - toolbarWidth)
        .clamp(0.0, maxLeft)
        .toDouble();
    final top = math.max(
      request.anchorRect.top - toolbarHeight - request.gap,
      request.visibleTop,
    );

    return Positioned(
      left: left,
      top: top,
      child: ConstrainedBox(
        key: _toolbarKey,
        constraints: BoxConstraints(
          minWidth: minWidth,
          maxWidth: maxWidth,
        ),
        child: Listener(
          key: const ValueKey<String>(
            'table-floating-toolbar-hit-test-blocker',
          ),
          behavior: HitTestBehavior.opaque,
          child: request.toolbarBuilder(context),
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
      _syncToolbarHeight();
    });
  }

  void _syncToolbarHeight() {
    if (!mounted) {
      return;
    }
    final renderObject = _toolbarKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }
    final nextSize = renderObject.size;
    final currentSize = _toolbarSize;
    if (currentSize != null &&
        (currentSize.width - nextSize.width).abs() < 0.5 &&
        (currentSize.height - nextSize.height).abs() < 0.5) {
      return;
    }
    setState(() {
      _toolbarSize = nextSize;
    });
  }

  bool _requestAnchorIntersectsVisibleViewport(
    TableFloatingToolbarOverlayRequest request,
  ) {
    if (request.visibleBottom < request.visibleTop) {
      return true;
    }
    return request.anchorRect.bottom >= request.visibleTop &&
        request.anchorRect.top <= request.visibleBottom;
  }
}

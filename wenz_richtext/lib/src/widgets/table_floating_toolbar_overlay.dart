import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/position/document_position.dart';

/// Builds the visible table toolbar for an overlay request.
typedef TableFloatingToolbarOverlayBuilder = Widget Function(
  BuildContext context,
);

/// Creates a request after the table anchor owns a [LayerLink] and global rect.
typedef TableFloatingToolbarOverlayRequestBuilder
    = TableFloatingToolbarOverlayRequest Function({
  required Object owner,
  required LayerLink anchorLink,
  required Rect anchorRect,
  required double visibleTop,
});

/// Immutable payload sent from a table renderer to the editor-owned overlay host.
///
/// The table renderer owns only the anchor and the current toolbar payload. The
/// editor owns [TableFloatingToolbarOverlayHost], which renders this payload with
/// Flutter's system [OverlayPortal] plus [CompositedTransformFollower]. This
/// keeps the toolbar outside the table block's internal [Stack], so it can cross
/// parent bounds and participate in overlay hit testing without making renderers
/// manage overlay entries directly.
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
    this.minWidth = 0,
    this.gap = 4,
    this.fallbackHeight = 40,
  });

  /// Opaque identity of the renderer anchor that published this request.
  final Object owner;

  /// Link followed by the system overlay entry.
  final LayerLink anchorLink;

  /// Current global rect of the table block anchor.
  final Rect anchorRect;

  /// Top edge of the visible editor viewport in global coordinates.
  final double visibleTop;

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
    required this.tableBlockId,
    required this.blockIndex,
  });

  final Object owner;
  final LayerLink anchorLink;
  final Rect anchorRect;
  final double visibleTop;
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
    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: (context) {
        final request = _request;
        if (request == null || !request.enabled) {
          return const SizedBox.shrink();
        }
        return _TableFloatingToolbarOverlayEntry(request: request);
      },
      child: widget.child,
    );
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _request = widget.controller.request;
    });
    _syncPortalSafely();
  }

  void _syncPortalSafely() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPortal());
      return;
    }
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
    _scheduleSync();
    return CompositedTransformTarget(
      link: _anchorLink,
      child: widget.child,
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
    final anchorTopLeft = renderObject.localToGlobal(Offset.zero);
    final anchorRect = anchorTopLeft & renderObject.size;
    final visibleTop = _visibleTopFor(context);
    controller.updateAnchor(
      TableFloatingToolbarAnchorSnapshot(
        owner: _owner,
        anchorLink: _anchorLink,
        anchorRect: anchorRect,
        visibleTop: visibleTop,
        tableBlockId: widget.tableBlockId,
        blockIndex: widget.blockIndex,
      ),
    );
    final requestBuilder = widget.requestBuilder;
    if (requestBuilder == null) {
      controller.hide(owner: _owner);
      return;
    }
    controller.show(
      requestBuilder(
        owner: _owner,
        anchorLink: _anchorLink,
        anchorRect: anchorRect,
        visibleTop: visibleTop,
      ),
      replaceDifferentRequest: false,
    );
  }

  double _visibleTopFor(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    final viewportObject = scrollable?.context.findRenderObject();
    if (viewportObject is RenderBox &&
        viewportObject.attached &&
        viewportObject.hasSize) {
      return viewportObject.localToGlobal(Offset.zero).dy;
    }
    return MediaQuery.maybeOf(context)?.padding.top ?? 0;
  }
}

class _TableFloatingToolbarOverlayEntry extends StatefulWidget {
  const _TableFloatingToolbarOverlayEntry({required this.request});

  final TableFloatingToolbarOverlayRequest request;

  @override
  State<_TableFloatingToolbarOverlayEntry> createState() =>
      _TableFloatingToolbarOverlayEntryState();
}

class _TableFloatingToolbarOverlayEntryState
    extends State<_TableFloatingToolbarOverlayEntry> {
  final GlobalKey _toolbarKey = GlobalKey();
  double? _toolbarHeight;
  bool _measureScheduled = false;

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    final request = widget.request;
    final toolbarHeight = _toolbarHeight ?? request.fallbackHeight;
    final preferredTop = -(toolbarHeight + request.gap);
    final visibleTop = request.visibleTop - request.anchorRect.top;
    final top = math.max(preferredTop, visibleTop);
    final minWidth = math.max(request.minWidth, request.anchorRect.width);

    return Positioned.fill(
      child: CompositedTransformFollower(
        link: request.anchorLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.topLeft,
        offset: Offset(0, top),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          widthFactor: 1,
          heightFactor: 1,
          child: ConstrainedBox(
            key: _toolbarKey,
            constraints: BoxConstraints(minWidth: minWidth),
            child: Listener(
              key: const ValueKey<String>(
                'table-floating-toolbar-hit-test-blocker',
              ),
              behavior: HitTestBehavior.opaque,
              child: request.toolbarBuilder(context),
            ),
          ),
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
    final nextHeight = renderObject.size.height;
    if (_toolbarHeight != null && (_toolbarHeight! - nextHeight).abs() < 0.5) {
      return;
    }
    setState(() {
      _toolbarHeight = nextHeight;
    });
  }
}

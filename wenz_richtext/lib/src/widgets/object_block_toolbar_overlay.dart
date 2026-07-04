import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

const double _kObjectBlockToolbarDefaultMinWidth = 0.0;
const double _kObjectBlockToolbarDefaultGap = 6.0;
const double _kObjectBlockToolbarDefaultFallbackHeight = 36.0;

/// Builds the visible toolbar for an object-block overlay request.
typedef ObjectBlockToolbarOverlayBuilder = Widget Function(
  BuildContext context,
);

/// Creates a request after the object-block anchor owns a [LayerLink] and
/// current overlay-space rect.
typedef ObjectBlockToolbarOverlayRequestBuilder
    = ObjectBlockToolbarOverlayRequest Function({
  required Object owner,
  required LayerLink anchorLink,
  required Rect anchorRect,
  required double visibleTop,
});

/// Immutable payload sent from an object-block renderer to the editor-owned
/// overlay host.
///
/// Renderers own only an anchor and the current toolbar payload. The editor
/// owns [ObjectBlockToolbarOverlayHost], which renders this payload via
/// [OverlayPortal] so object toolbars can float above media/object frames
/// without participating in the block's layout.
@immutable
class ObjectBlockToolbarOverlayRequest {
  const ObjectBlockToolbarOverlayRequest({
    required this.owner,
    required this.anchorLink,
    required this.anchorRect,
    required this.visibleTop,
    required this.blockId,
    required this.blockIndex,
    required this.toolbarBuilder,
    this.enabled = true,
    this.minWidth = _kObjectBlockToolbarDefaultMinWidth,
    this.gap = _kObjectBlockToolbarDefaultGap,
    this.fallbackHeight = _kObjectBlockToolbarDefaultFallbackHeight,
    this.visibleBottom = double.infinity,
  });

  /// Opaque identity of the renderer anchor that published this request.
  final Object owner;

  /// Link owned by the renderer anchor.
  final LayerLink anchorLink;

  /// Current rect of the object-block anchor in target overlay coordinates.
  final Rect anchorRect;

  /// Top edge of the visible editor viewport in target overlay coordinates.
  final double visibleTop;

  /// Bottom edge of the visible editor viewport in target overlay coordinates.
  final double visibleBottom;

  /// Active object block identity used to reject stale requests.
  final String blockId;

  /// Active object block index in the source document.
  final int blockIndex;

  /// Builds toolbar chrome. The renderer captures callbacks here so the host
  /// does not call back into renderer state directly.
  final ObjectBlockToolbarOverlayBuilder toolbarBuilder;

  /// Whether this request may be shown. Hosts hide disabled requests.
  final bool enabled;

  /// Minimum toolbar width, independent from the object block's layout width.
  final double minWidth;

  /// Gap between the toolbar bottom and the anchor top.
  final double gap;

  /// Height used until the overlay measures its real toolbar child.
  final double fallbackHeight;
}

/// Last known geometry for a rendered object-block toolbar anchor.
@immutable
class ObjectBlockToolbarAnchorSnapshot {
  const ObjectBlockToolbarAnchorSnapshot({
    required this.owner,
    required this.anchorLink,
    required this.anchorRect,
    required this.visibleTop,
    required this.visibleBottom,
    required this.blockId,
    required this.blockIndex,
  });

  final Object owner;
  final LayerLink anchorLink;
  final Rect anchorRect;
  final double visibleTop;
  final double visibleBottom;
  final String blockId;
  final int blockIndex;
}

/// Editor-owned controller for the active object-block toolbar overlay request.
class ObjectBlockToolbarOverlayController extends ChangeNotifier {
  ObjectBlockToolbarOverlayRequest? _request;
  final Map<String, ObjectBlockToolbarAnchorSnapshot> _anchors =
      <String, ObjectBlockToolbarAnchorSnapshot>{};

  ObjectBlockToolbarOverlayRequest? get request => _request;

  ObjectBlockToolbarAnchorSnapshot? anchorFor(
    String blockId, {
    int? blockIndex,
  }) {
    final anchor = _anchors[blockId];
    if (anchor == null ||
        (blockIndex != null && anchor.blockIndex != blockIndex)) {
      return null;
    }
    return anchor;
  }

  void updateAnchor(ObjectBlockToolbarAnchorSnapshot anchor) {
    _anchors[anchor.blockId] = anchor;
  }

  void unregisterAnchor({required Object owner}) {
    _anchors.removeWhere((_, anchor) => identical(anchor.owner, owner));
    hide(owner: owner);
  }

  void show(
    ObjectBlockToolbarOverlayRequest request, {
    bool replaceDifferentRequest = true,
  }) {
    final current = _request;
    if (!replaceDifferentRequest &&
        current != null &&
        !_targetsSameActiveBlock(current, request)) {
      return;
    }
    _request = request;
    notifyListeners();
  }

  bool _targetsSameActiveBlock(
    ObjectBlockToolbarOverlayRequest current,
    ObjectBlockToolbarOverlayRequest next,
  ) {
    return identical(current.owner, next.owner) ||
        (current.blockId == next.blockId &&
            current.blockIndex == next.blockIndex);
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

/// Editor-level host that renders object-block toolbar requests into the
/// system overlay.
class ObjectBlockToolbarOverlayHost extends StatefulWidget {
  const ObjectBlockToolbarOverlayHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final ObjectBlockToolbarOverlayController controller;
  final Widget child;

  @override
  State<ObjectBlockToolbarOverlayHost> createState() =>
      _ObjectBlockToolbarOverlayHostState();
}

class _ObjectBlockToolbarOverlayHostState
    extends State<ObjectBlockToolbarOverlayHost> {
  final OverlayPortalController _portalController = OverlayPortalController();
  ObjectBlockToolbarOverlayRequest? _request;

  @override
  void initState() {
    super.initState();
    _request = widget.controller.request;
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPortal());
  }

  @override
  void didUpdateWidget(covariant ObjectBlockToolbarOverlayHost oldWidget) {
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
        return _ObjectBlockToolbarOverlayEntry(
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleControllerChanged());
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

/// Anchor installed by object-block renderers. It publishes or withdraws
/// requests while leaving overlay ownership with
/// [ObjectBlockToolbarOverlayHost].
class ObjectBlockToolbarOverlayAnchor extends StatefulWidget {
  const ObjectBlockToolbarOverlayAnchor({
    super.key,
    required this.controller,
    required this.requestBuilder,
    required this.blockId,
    required this.blockIndex,
    required this.child,
  });

  final ObjectBlockToolbarOverlayController? controller;
  final ObjectBlockToolbarOverlayRequestBuilder? requestBuilder;
  final String blockId;
  final int blockIndex;
  final Widget child;

  @override
  State<ObjectBlockToolbarOverlayAnchor> createState() =>
      _ObjectBlockToolbarOverlayAnchorState();
}

class _ObjectBlockToolbarOverlayAnchorState
    extends State<ObjectBlockToolbarOverlayAnchor>
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
  void didUpdateWidget(covariant ObjectBlockToolbarOverlayAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.blockId != widget.blockId) {
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
        child: _ObjectBlockToolbarAnchorMeasure(
          onSizeChanged: (_) => _scheduleSync(),
          child: widget.child,
        ),
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
      ObjectBlockToolbarAnchorSnapshot(
        owner: _owner,
        anchorLink: _anchorLink,
        anchorRect: anchorRect,
        visibleTop: visibleBounds.top,
        visibleBottom: visibleBounds.bottom,
        blockId: widget.blockId,
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
    final paddingTop = MediaQuery.maybeOf(context)?.padding.top ?? 0;
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

  ObjectBlockToolbarOverlayRequest _withVisibleBounds(
    ObjectBlockToolbarOverlayRequest request, {
    required Rect anchorRect,
    required ({double top, double bottom}) visibleBounds,
  }) {
    return ObjectBlockToolbarOverlayRequest(
      owner: request.owner,
      anchorLink: request.anchorLink,
      anchorRect: anchorRect,
      visibleTop: visibleBounds.top,
      visibleBottom: visibleBounds.bottom,
      blockId: request.blockId,
      blockIndex: request.blockIndex,
      toolbarBuilder: request.toolbarBuilder,
      enabled: request.enabled,
      minWidth: request.minWidth,
      gap: request.gap,
      fallbackHeight: request.fallbackHeight,
    );
  }
}

class _ObjectBlockToolbarAnchorMeasure
    extends SingleChildRenderObjectWidget {
  const _ObjectBlockToolbarAnchorMeasure({
    required this.onSizeChanged,
    required super.child,
  });

  final ValueChanged<Size> onSizeChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderObjectBlockToolbarAnchorMeasure(
      onSizeChanged: onSizeChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderObjectBlockToolbarAnchorMeasure renderObject,
  ) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class _RenderObjectBlockToolbarAnchorMeasure extends RenderProxyBox {
  _RenderObjectBlockToolbarAnchorMeasure({
    required ValueChanged<Size> onSizeChanged,
  }) : _onSizeChanged = onSizeChanged;

  ValueChanged<Size> _onSizeChanged;
  Size? _lastSize;

  set onSizeChanged(ValueChanged<Size> value) {
    _onSizeChanged = value;
  }

  @override
  void performLayout() {
    super.performLayout();
    final nextSize = size;
    final previous = _lastSize;
    if (previous != null &&
        (previous.width - nextSize.width).abs() < 0.5 &&
        (previous.height - nextSize.height).abs() < 0.5) {
      return;
    }
    _lastSize = nextSize;
    _onSizeChanged(nextSize);
  }
}

class _ObjectBlockToolbarOverlayEntry extends StatefulWidget {
  const _ObjectBlockToolbarOverlayEntry({
    required this.request,
    required this.overlaySize,
  });

  final ObjectBlockToolbarOverlayRequest request;
  final Size overlaySize;

  @override
  State<_ObjectBlockToolbarOverlayEntry> createState() =>
      _ObjectBlockToolbarOverlayEntryState();
}

class _ObjectBlockToolbarOverlayEntryState
    extends State<_ObjectBlockToolbarOverlayEntry> {
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
            'object-block-toolbar-hit-test-blocker',
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
      _syncToolbarSize();
    });
  }

  void _syncToolbarSize() {
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
    ObjectBlockToolbarOverlayRequest request,
  ) {
    if (request.visibleBottom < request.visibleTop) {
      return true;
    }
    return request.anchorRect.bottom >= request.visibleTop &&
        request.anchorRect.top <= request.visibleBottom;
  }
}

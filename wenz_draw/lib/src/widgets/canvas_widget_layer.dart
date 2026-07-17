import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../elements/canvas_element.dart';
import '../elements/element_registry.dart';
import '../elements/element_renderer.dart';
import '../elements/image_element.dart';
import '../elements/widget_element.dart';
import '../infinite_canvas/canvas_transform.dart';
import '../infinite_canvas/infinite_canvas_config.dart';
import '../infinite_canvas/infinite_canvas_controller.dart';
import '../layers/canvas_layer.dart';
import '../rendering/grid_renderer.dart';
import '../rendering/selection_renderer.dart';
import '../rendering/viewport_culling.dart';
import '../tools/select_tool.dart';
import 'widget_element_builder.dart';
import 'widget_element_registry.dart';

typedef CanvasElementOverlayBuilder =
    Widget? Function(BuildContext context, CanvasElement element);
typedef CanvasElementOverlayAnchorPredicate =
    bool Function(CanvasElement element);

/// Coordinates the gesture-arena participant used by interactive widget
/// elements with the canvas-level selection gesture.
class CanvasWidgetGestureController {
  static const double dragSlop = kTouchSlop;

  final Map<int, _CanvasWidgetDragGestureRecognizer> _recognizers = {};

  void suppressPointer(int pointer) {
    _recognizers[pointer]?._acceptPointer(pointer);
  }

  void suppressAll() {
    for (final pointer in _recognizers.keys.toList(growable: false)) {
      suppressPointer(pointer);
    }
  }

  void _register(
    int pointer,
    _CanvasWidgetDragGestureRecognizer recognizer,
  ) {
    _recognizers[pointer] = recognizer;
  }

  void _unregister(
    int pointer,
    _CanvasWidgetDragGestureRecognizer recognizer,
  ) {
    if (identical(_recognizers[pointer], recognizer)) {
      _recognizers.remove(pointer);
    }
  }
}

class CanvasWidgetLayer extends StatefulWidget {
  const CanvasWidgetLayer({
    super.key,
    required this.controller,
    this.config = const InfiniteCanvasConfig(),
    this.elementOverlayBuilder,
    this.elementOverlayAnchorPredicate,
    this.gestureController,
  });

  final InfiniteCanvasController controller;
  final InfiniteCanvasConfig config;
  final CanvasElementOverlayBuilder? elementOverlayBuilder;
  final CanvasElementOverlayAnchorPredicate? elementOverlayAnchorPredicate;
  final CanvasWidgetGestureController? gestureController;

  @override
  State<CanvasWidgetLayer> createState() => _CanvasWidgetLayerState();
}

class _CanvasWidgetLayerState extends State<CanvasWidgetLayer> {
  final Map<String, ui.Image> _snapshots = {};
  final Map<String, int> _snapshotRevisions = {};
  final Map<String, int> _pendingSnapshotRevisions = {};
  int _captureGeneration = 0;

  @override
  void dispose() {
    for (final image in _snapshots.values) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final canvasController = controller.canvasController;
    final visibleRect = controller.visibleWorldRect();
    final orderedVisibleElements = canvasController
        .orderedElements(visibleOnly: true)
        .where(
          (element) =>
              element.bounds.overlaps(visibleRect) ||
              (widget.elementOverlayAnchorPredicate?.call(element) ?? false),
        )
        .toList(growable: false);
    final visibleWidgetElements = orderedVisibleElements
        .whereType<CanvasWidgetElement>()
        .toList(growable: false);
    _scheduleSnapshotCaptures(
      canvasController.state.revision,
      visibleRect,
      visibleWidgetElements,
    );
    final selectedSnapshotWidgetIds = _selectedSnapshotWidgetIds(
      visibleRect,
      visibleWidgetElements,
    );
    _pruneSnapshots(visibleWidgetElements.map((element) => element.id).toSet());
    final liveOverlayIds = {for (final id in selectedSnapshotWidgetIds) id};
    final children = <Widget>[
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _CanvasBackgroundPainter(
              controller: controller,
              config: widget.config,
            ),
          ),
        ),
      ),
    ];

    final elementsByLayer = <String, List<CanvasElement>>{};
    final unknownLayerElements = <CanvasElement>[];
    for (final element in orderedVisibleElements) {
      if (canvasController.layerManager.layerById(element.layerId) == null) {
        unknownLayerElements.add(element);
      } else {
        (elementsByLayer[element.layerId] ??= <CanvasElement>[]).add(element);
      }
    }

    for (final layer in canvasController.layers) {
      if (!layer.isVisible) {
        continue;
      }
      final layerElements = elementsByLayer[layer.id];
      if (layerElements == null || layerElements.isEmpty) {
        continue;
      }
      children.add(
        Positioned.fill(
          child: _LayerMixedStack(
            controller: controller,
            config: widget.config,
            layer: layer,
            visibleRect: visibleRect,
            elements: layerElements,
            snapshots: _snapshots,
            liveOverlayIds: liveOverlayIds,
            elementOverlayBuilder: widget.elementOverlayBuilder,
            gestureController: widget.gestureController,
          ),
        ),
      );
    }

    if (unknownLayerElements.isNotEmpty) {
      children.add(
        Positioned.fill(
          child: _MixedElementStack(
            controller: controller,
            config: widget.config,
            elements: unknownLayerElements,
            visibleRect: visibleRect,
            layer: null,
            snapshots: _snapshots,
            liveOverlayIds: liveOverlayIds,
            elementOverlayBuilder: widget.elementOverlayBuilder,
            gestureController: widget.gestureController,
          ),
        ),
      );
    }

    final preview = canvasController.previewElement;
    if (preview != null && preview is! CanvasWidgetElement) {
      children.add(
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CanvasElementSegmentPainter(
                controller: controller,
                config: widget.config,
                elements: [preview],
              ),
            ),
          ),
        ),
      );
    }

    children.add(
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _CanvasSelectionPainter(controller: controller),
          ),
        ),
      ),
    );

    return Stack(clipBehavior: Clip.none, children: children);
  }

  List<CanvasWidgetElement> _snapshotElements(
    Rect visibleRect,
    List<CanvasWidgetElement> visibleWidgetElements,
  ) {
    return visibleWidgetElements
        .where(
          (element) =>
              element.renderMode == CanvasWidgetRenderMode.snapshot &&
              element.worldRect.overlaps(visibleRect),
        )
        .toList(growable: false);
  }

  Set<String> _selectedSnapshotWidgetIds(
    Rect visibleRect,
    List<CanvasWidgetElement> visibleWidgetElements,
  ) {
    final canvasController = widget.controller.canvasController;
    return _snapshotElements(visibleRect, visibleWidgetElements)
        .where((element) => canvasController.selectedIds.contains(element.id))
        .map((element) => element.id)
        .toSet();
  }

  void _pruneSnapshots(Set<String> visibleWidgetIds) {
    final staleIds = [
      for (final id in _snapshots.keys)
        if (!visibleWidgetIds.contains(id)) id,
    ];
    if (staleIds.isEmpty) {
      return;
    }
    for (final id in staleIds) {
      _snapshots.remove(id)?.dispose();
      _snapshotRevisions.remove(id);
      _pendingSnapshotRevisions.remove(id);
    }
  }

  void _scheduleSnapshotCaptures(
    int revision,
    Rect visibleRect,
    List<CanvasWidgetElement> visibleWidgetElements,
  ) {
    final generation = ++_captureGeneration;
    final elements = _snapshotElements(visibleRect, visibleWidgetElements)
        .where(
          (e) =>
              CanvasWidgetLayout.resolve(
                e,
                widget.controller.transform,
              ).detail ==
              CanvasWidgetRenderDetail.full,
        )
        .where(
          (e) =>
              _snapshotRevisions[e.id] != revision &&
              _pendingSnapshotRevisions[e.id] != revision,
        )
        .toList(growable: false);
    if (elements.isEmpty) {
      return;
    }
    for (final element in elements) {
      _pendingSnapshotRevisions[element.id] = revision;
    }
    // Defer capture to after the current frame to avoid calling
    // RenderRepaintBoundary.toImage during the layout/paint phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _captureGeneration) {
        for (final element in elements) {
          _pendingSnapshotRevisions.remove(element.id);
        }
        return;
      }
      for (final element in elements) {
        if (_snapshotRevisions[element.id] == revision) {
          _pendingSnapshotRevisions.remove(element.id);
          continue;
        }
        unawaited(_captureSnapshot(element, revision, generation));
      }
    });
  }

  Future<void> _captureSnapshot(
    CanvasWidgetElement element,
    int revision,
    int generation,
  ) async {
    final builder = WidgetElementRegistry.getBuilder(element.widgetType);
    if (builder == null || element.worldRect.isEmpty) {
      return;
    }
    final renderDetail = CanvasWidgetLayout.resolve(
      element,
      widget.controller.transform,
    ).detail;
    final image = await WidgetSnapshotRenderer.capture(
      context: context,
      controller: widget.controller,
      element: element,
      builder: builder,
      renderDetail: renderDetail,
    );
    if (!mounted || generation != _captureGeneration) {
      image?.dispose();
      _pendingSnapshotRevisions.remove(element.id);
      return;
    }
    final previous = _snapshots[element.id];
    setState(() {
      if (image == null) {
        _snapshots.remove(element.id)?.dispose();
        _snapshotRevisions.remove(element.id);
        _pendingSnapshotRevisions.remove(element.id);
      } else {
        _snapshots[element.id] = image;
        _snapshotRevisions[element.id] = revision;
        _pendingSnapshotRevisions.remove(element.id);
      }
    });
    if (previous != null && previous != image) {
      previous.dispose();
    }
  }
}

class _LayerMixedStack extends StatelessWidget {
  const _LayerMixedStack({
    required this.controller,
    required this.config,
    required this.layer,
    required this.visibleRect,
    required this.elements,
    required this.snapshots,
    required this.liveOverlayIds,
    required this.elementOverlayBuilder,
    required this.gestureController,
  });

  final InfiniteCanvasController controller;
  final InfiniteCanvasConfig config;
  final CanvasLayer layer;
  final Rect visibleRect;
  final List<CanvasElement> elements;
  final Map<String, ui.Image> snapshots;
  final Set<String> liveOverlayIds;
  final CanvasElementOverlayBuilder? elementOverlayBuilder;
  final CanvasWidgetGestureController? gestureController;

  @override
  Widget build(BuildContext context) {
    final opacity = layer.opacity.clamp(0.0, 1.0).toDouble();
    final child = _MixedElementStack(
      controller: controller,
      config: config,
      layer: layer,
      visibleRect: visibleRect,
      elements: elements,
      snapshots: snapshots,
      liveOverlayIds: liveOverlayIds,
      elementOverlayBuilder: elementOverlayBuilder,
      gestureController: gestureController,
    );

    return Opacity(opacity: opacity, child: child);
  }
}

class _MixedElementStack extends StatelessWidget {
  const _MixedElementStack({
    required this.controller,
    required this.config,
    required this.elements,
    required this.visibleRect,
    required this.layer,
    required this.snapshots,
    required this.liveOverlayIds,
    required this.elementOverlayBuilder,
    required this.gestureController,
  });

  final InfiniteCanvasController controller;
  final InfiniteCanvasConfig config;
  final List<CanvasElement> elements;
  final Rect visibleRect;
  final CanvasLayer? layer;
  final Map<String, ui.Image> snapshots;
  final Set<String> liveOverlayIds;
  final CanvasElementOverlayBuilder? elementOverlayBuilder;
  final CanvasWidgetGestureController? gestureController;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final paintBatch = <CanvasElement>[];

    void flushPaintBatch() {
      if (paintBatch.isEmpty) {
        return;
      }
      children.add(
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CanvasElementSegmentPainter(
                controller: controller,
                config: config,
                elements: List<CanvasElement>.of(paintBatch),
                layer: layer,
              ),
            ),
          ),
        ),
      );
      paintBatch.clear();
    }

    for (final element in elements) {
      final overlay = elementOverlayBuilder?.call(context, element);
      if (overlay != null) {
        flushPaintBatch();
        children.add(overlay);
      }
      if (element is CanvasWidgetElement) {
        final layout = CanvasWidgetLayout.resolve(
          element,
          controller.transform,
        );
        if (element.renderMode == CanvasWidgetRenderMode.snapshot &&
            layout.detail == CanvasWidgetRenderDetail.full) {
          final image = snapshots[element.id];
          if (image != null && !liveOverlayIds.contains(element.id)) {
            paintBatch.add(SnapshotWidgetElement.fromWidget(element, image));
            flushPaintBatch();
            continue;
          }
        }

        flushPaintBatch();
        children.add(
          _CanvasWidgetHost(
            key: ValueKey(element.id),
            element: element,
            controller: controller,
            transform: controller.transform,
            applyLayerOpacity: layer == null,
            forcePaintScale:
                element.renderMode == CanvasWidgetRenderMode.snapshot,
            gestureController: gestureController,
          ),
        );
        continue;
      }
      paintBatch.add(element);
    }

    flushPaintBatch();
    return Stack(clipBehavior: Clip.none, children: children);
  }
}

class SnapshotWidgetElement extends CanvasElement {
  const SnapshotWidgetElement({
    required this.id,
    required this.rect,
    required this.image,
    required this.layerId,
    required this.visible,
    required this.opacity,
    required this.zIndex,
    this.groupId,
  });

  factory SnapshotWidgetElement.fromWidget(
    CanvasWidgetElement element,
    ui.Image image,
  ) {
    return SnapshotWidgetElement(
      id: element.id,
      rect: element.worldRect,
      image: image,
      layerId: element.layerId,
      visible: element.visible,
      opacity: element.opacity,
      zIndex: element.zIndex,
    );
  }

  final Rect rect;
  final ui.Image image;

  @override
  final String id;

  @override
  final String layerId;

  @override
  final bool visible;

  @override
  final double opacity;

  @override
  final int zIndex;

  @override
  final String? groupId;

  @override
  String get type => 'widget_snapshot';

  @override
  Rect get bounds => rect;

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    return rect.inflate(tolerance).contains(worldPoint);
  }

  @override
  SnapshotWidgetElement copyWith({
    String? id,
    Rect? rect,
    ui.Image? image,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    String? groupId,
  }) {
    return SnapshotWidgetElement(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      image: image ?? this.image,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      groupId: groupId ?? this.groupId,
    );
  }

  @override
  SnapshotWidgetElement translate(Offset delta) {
    return copyWith(rect: rect.shift(delta));
  }

  @override
  SnapshotWidgetElement scaleElement(double factor, {Offset? pivot}) {
    final origin = pivot ?? rect.center;
    return copyWith(
      rect: Rect.fromCenter(
        center: origin + (rect.center - origin) * factor,
        width: rect.width * factor,
        height: rect.height * factor,
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{};
  }
}

class SnapshotWidgetElementRenderer
    extends ElementRenderer<SnapshotWidgetElement> {
  const SnapshotWidgetElementRenderer();

  @override
  void render(Canvas canvas, SnapshotWidgetElement element) {
    if (!element.visible) {
      return;
    }
    final source = Rect.fromLTWH(
      0,
      0,
      element.image.width.toDouble(),
      element.image.height.toDouble(),
    );
    canvas.drawImageRect(
      element.image,
      source,
      element.rect,
      Paint()..color = Colors.black.withValues(alpha: element.opacity),
    );
  }

  @override
  bool hitTest(
    SnapshotWidgetElement element,
    Offset worldPoint,
    double tolerance,
  ) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}

class WidgetSnapshotRenderer {
  const WidgetSnapshotRenderer._();

  static Future<ui.Image?> capture({
    required BuildContext context,
    required InfiniteCanvasController controller,
    required CanvasWidgetElement element,
    required WidgetElementBuilder builder,
    CanvasWidgetRenderDetail renderDetail = CanvasWidgetRenderDetail.full,
    double pixelRatio = 1,
  }) async {
    final renderView = View.maybeOf(context);
    final view =
        renderView ?? WidgetsBinding.instance.platformDispatcher.views.first;
    final size = element.worldRect.size;
    if (size.isEmpty) {
      return null;
    }

    final repaintBoundary = RenderRepaintBoundary();
    final renderObjectToWidget = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData.fromView(view),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Overlay(
              clipBehavior: element.clipBehavior,
              initialEntries: [
                OverlayEntry(
                  builder: (_) => SizedBox.expand(
                    child: ClipRect(
                      clipBehavior: element.clipBehavior,
                      child: renderDetail == CanvasWidgetRenderDetail.full
                          ? builder.build(
                              context,
                              element,
                              canvas: CanvasWidgetBuildContext(
                                canvasController: controller.canvasController,
                                viewController: controller,
                                selected: false,
                                scale: 1,
                                renderDetail: CanvasWidgetRenderDetail.full,
                              ),
                            )
                          : builder.buildPreview(
                              context,
                              element,
                              canvas: CanvasWidgetBuildContext(
                                canvasController: controller.canvasController,
                                viewController: controller,
                                selected: false,
                                scale: 1,
                                renderDetail: renderDetail,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());
    repaintBoundary.attach(pipelineOwner);
    final elementTree = renderObjectToWidget.attachToRenderTree(buildOwner);
    buildOwner
      ..buildScope(elementTree)
      ..finalizeTree();
    repaintBoundary.layout(BoxConstraints.tight(size));
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    // Safety: flush one more time in case any post-layout work
    // (e.g. LayoutBuilder callbacks during finalizeTree) marked the
    // tree dirty again.
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    try {
      final image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
      return image;
    } catch (_) {
      // If capture fails, the caller will simply not update the snapshot.
      return null;
    } finally {
      repaintBoundary.detach();
    }
  }
}

class _CanvasBackgroundPainter extends CustomPainter {
  _CanvasBackgroundPainter({required this.controller, required this.config});

  final InfiniteCanvasController controller;
  final InfiniteCanvasConfig config;

  static const _gridRenderer = GridRenderer();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(config.backgroundColor, BlendMode.src);
    _gridRenderer.render(canvas, size, controller.transform, config);
  }

  @override
  bool shouldRepaint(covariant _CanvasBackgroundPainter oldDelegate) {
    return oldDelegate.controller.transform != controller.transform ||
        oldDelegate.config != config;
  }
}

class _CanvasElementSegmentPainter extends CustomPainter {
  _CanvasElementSegmentPainter({
    required this.controller,
    required this.config,
    required this.elements,
    this.layer,
  }) : revision = controller.canvasController.state.revision;

  final InfiniteCanvasController controller;
  final InfiniteCanvasConfig config;
  final List<CanvasElement> elements;
  final CanvasLayer? layer;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    final transform = controller.transform;
    final blendMode = layer?.blendMode ?? BlendMode.srcOver;
    final needsLayer = blendMode != BlendMode.srcOver;

    canvas.save();
    canvas.translate(transform.offset.dx, transform.offset.dy);
    canvas.scale(transform.scale);

    if (needsLayer) {
      canvas.saveLayer(null, Paint()..blendMode = blendMode);
    }

    final visibleRect = transform.visibleWorldRect(size);
    for (final element in ViewportCulling.visibleElements(
      elements,
      visibleRect,
    )) {
      if (element is SnapshotWidgetElement) {
        const SnapshotWidgetElementRenderer().render(canvas, element);
        continue;
      }
      if (element is ImageElement &&
          transform.scale < config.imageContentMinScale) {
        const ImageElementRenderer().renderPlaceholder(canvas, element);
        continue;
      }
      ElementRendererRegistry.render(canvas, element);
    }

    if (needsLayer) {
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CanvasElementSegmentPainter oldDelegate) {
    return oldDelegate.revision != revision ||
        oldDelegate.controller.transform != controller.transform ||
        oldDelegate.config != config ||
        oldDelegate.elements != elements ||
        oldDelegate.layer != layer;
  }
}

class _CanvasSelectionPainter extends CustomPainter {
  _CanvasSelectionPainter({required this.controller})
    : revision = controller.canvasController.state.revision;

  final InfiniteCanvasController controller;
  final int revision;

  static const _selectionRenderer = SelectionRenderer();

  @override
  void paint(Canvas canvas, Size size) {
    final transform = controller.transform;
    canvas.save();
    canvas.translate(transform.offset.dx, transform.offset.dy);
    canvas.scale(transform.scale);
    _selectionRenderer.render(canvas, controller.canvasController, transform);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CanvasSelectionPainter oldDelegate) {
    return oldDelegate.revision != revision ||
        oldDelegate.controller.transform != controller.transform;
  }
}

class CanvasWidgetLayout {
  const CanvasWidgetLayout({
    required this.screenRect,
    required this.layoutSize,
    required this.paintScale,
    required this.detail,
  });

  final Rect screenRect;
  final Size layoutSize;
  final double paintScale;
  final CanvasWidgetRenderDetail detail;

  static CanvasWidgetLayout resolve(
    CanvasWidgetElement element,
    CanvasTransform transform,
  ) {
    final worldSize = element.worldRect.size;
    if (worldSize.isEmpty) {
      final origin = transform.worldToScreen(element.worldRect.topLeft);
      return CanvasWidgetLayout(
        screenRect: Rect.fromLTWH(origin.dx, origin.dy, 0, 0),
        layoutSize: Size.zero,
        paintScale: 1,
        detail: CanvasWidgetRenderDetail.color,
      );
    }

    return switch (element.scaleMode) {
      CanvasWidgetScaleMode.fixedScreenSize => _fixedScreenSize(
        element,
        transform,
        worldSize,
      ),
      CanvasWidgetScaleMode.layoutScale || CanvasWidgetScaleMode.paintScale =>
        _scaledWorldSize(element, transform, worldSize),
    };
  }

  static CanvasWidgetLayout _scaledWorldSize(
    CanvasWidgetElement element,
    CanvasTransform transform,
    Size worldSize,
  ) {
    final scale = _constrainedScale(
      baseScale: transform.scale,
      worldSize: worldSize,
      minScreenSize: element.minScreenSize,
      maxScreenSize: element.maxScreenSize,
    );
    final screenSize = worldSize * scale;
    final center = transform.worldToScreen(element.worldRect.center);
    return CanvasWidgetLayout(
      screenRect: Rect.fromCenter(
        center: center,
        width: screenSize.width,
        height: screenSize.height,
      ),
      layoutSize: worldSize,
      paintScale: scale,
      detail: _detailFor(screenSize),
    );
  }

  static CanvasWidgetLayout _fixedScreenSize(
    CanvasWidgetElement element,
    CanvasTransform transform,
    Size worldSize,
  ) {
    final scale = _constrainedScale(
      baseScale: 1,
      worldSize: worldSize,
      minScreenSize: element.minScreenSize,
      maxScreenSize: element.maxScreenSize,
    );
    final screenSize = worldSize * scale;
    final center = transform.worldToScreen(element.worldRect.center);
    return CanvasWidgetLayout(
      screenRect: Rect.fromCenter(
        center: center,
        width: screenSize.width,
        height: screenSize.height,
      ),
      layoutSize: screenSize,
      paintScale: 1,
      detail: _detailFor(screenSize),
    );
  }

  static const double _colorOnlyShortestSide = 18;
  static const double _textShortestSide = 42;
  static const double _textLongestSide = 72;
  static const double _fullContentShortestSide = 140;
  static const double _fullContentLongestSide = 240;

  static CanvasWidgetRenderDetail _detailFor(Size screenSize) {
    final shortestSide = screenSize.shortestSide;
    final longestSide = screenSize.longestSide;

    // Four-level LOD, from smallest to largest:
    // 1. color only, 2. text + color, 3. thumbnail, 4. full content.
    if (shortestSide < _colorOnlyShortestSide) {
      return CanvasWidgetRenderDetail.color;
    }
    if (shortestSide < _textShortestSide || longestSide < _textLongestSide) {
      return CanvasWidgetRenderDetail.colorWithText;
    }
    if (shortestSide < _fullContentShortestSide ||
        longestSide < _fullContentLongestSide) {
      return CanvasWidgetRenderDetail.thumbnail;
    }
    return CanvasWidgetRenderDetail.full;
  }

  static double _constrainedScale({
    required double baseScale,
    required Size worldSize,
    Size? minScreenSize,
    Size? maxScreenSize,
  }) {
    var scale = baseScale;
    final minSize = minScreenSize;
    if (minSize != null) {
      scale = scale.clamp(
        _maxFinite(
          minSize.width / worldSize.width,
          minSize.height / worldSize.height,
        ),
        double.infinity,
      );
    }

    final maxSize = maxScreenSize;
    if (maxSize != null) {
      scale = scale.clamp(
        0,
        _minFinite(
          maxSize.width / worldSize.width,
          maxSize.height / worldSize.height,
        ),
      );
    }
    return scale.toDouble();
  }

  static double _maxFinite(double a, double b) {
    final finite = [a, b].where((value) => value.isFinite);
    return finite.isEmpty ? 0 : finite.reduce((x, y) => x > y ? x : y);
  }

  static double _minFinite(double a, double b) {
    final finite = [a, b].where((value) => value.isFinite);
    return finite.isEmpty
        ? double.infinity
        : finite.reduce((x, y) => x < y ? x : y);
  }
}

class _CanvasWidgetHost extends StatelessWidget {
  const _CanvasWidgetHost({
    super.key,
    required this.element,
    required this.controller,
    required this.transform,
    this.applyLayerOpacity = true,
    this.forcePaintScale = false,
    this.gestureController,
  });

  final CanvasWidgetElement element;
  final InfiniteCanvasController controller;
  final CanvasTransform transform;
  final bool applyLayerOpacity;
  final bool forcePaintScale;
  final CanvasWidgetGestureController? gestureController;

  @override
  Widget build(BuildContext context) {
    final canvasController = controller.canvasController;
    final builder = WidgetElementRegistry.getBuilder(element.widgetType);
    final isSelected = canvasController.selectedIds.contains(element.id);
    final canInteract =
        canvasController.currentTool?.id == SelectTool.idValue &&
        element.interactive &&
        !element.isLocked;

    final layout = CanvasWidgetLayout.resolve(element, transform);
    final canvas = CanvasWidgetBuildContext(
      canvasController: canvasController,
      viewController: controller,
      selected: isSelected,
      scale: transform.scale,
      renderDetail: layout.detail,
    );

    if (builder == null) {
      return _placeholder(isSelected, layout);
    }

    if (forcePaintScale) {
      return _paintScale(
        context,
        builder,
        canvas,
        canInteract,
        isSelected,
        layout,
      );
    }

    return switch (element.scaleMode) {
      CanvasWidgetScaleMode.layoutScale => _layoutScale(
        context,
        builder,
        canvas,
        canInteract,
        isSelected,
        layout,
      ),
      CanvasWidgetScaleMode.paintScale => _paintScale(
        context,
        builder,
        canvas,
        canInteract,
        isSelected,
        layout,
      ),
      CanvasWidgetScaleMode.fixedScreenSize => _fixedScreenSize(
        context,
        builder,
        canvas,
        canInteract,
        isSelected,
        layout,
      ),
    };
  }

  Widget _layoutScale(
    BuildContext context,
    WidgetElementBuilder builder,
    CanvasWidgetBuildContext canvas,
    bool canInteract,
    bool isSelected,
    CanvasWidgetLayout layout,
  ) {
    return _paintScale(
      context,
      builder,
      canvas,
      canInteract,
      isSelected,
      layout,
    );
  }

  Widget _paintScale(
    BuildContext context,
    WidgetElementBuilder builder,
    CanvasWidgetBuildContext canvas,
    bool canInteract,
    bool isSelected,
    CanvasWidgetLayout layout,
  ) {
    return Positioned(
      left: layout.screenRect.left,
      top: layout.screenRect.top,
      width: layout.screenRect.width,
      height: layout.screenRect.height,
      child: IgnorePointer(
        ignoring: !canInteract,
        child: _gestureGate(
          canInteract,
          ClipRect(
            clipBehavior: element.clipBehavior,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: layout.layoutSize.width,
              maxWidth: layout.layoutSize.width,
              minHeight: layout.layoutSize.height,
              maxHeight: layout.layoutSize.height,
              child: Transform.scale(
                scale: layout.paintScale,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: layout.layoutSize.width,
                  height: layout.layoutSize.height,
                  child: _selectedFrame(
                    builder.useDefaultSelectionFrame && isSelected,
                    _buildForDetail(context, builder, canvas, layout),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fixedScreenSize(
    BuildContext context,
    WidgetElementBuilder builder,
    CanvasWidgetBuildContext canvas,
    bool canInteract,
    bool isSelected,
    CanvasWidgetLayout layout,
  ) {
    return Positioned(
      left: layout.screenRect.left,
      top: layout.screenRect.top,
      width: layout.screenRect.width,
      height: layout.screenRect.height,
      child: IgnorePointer(
        ignoring: !canInteract,
        child: _gestureGate(
          canInteract,
          _selectedFrame(
            builder.useDefaultSelectionFrame && isSelected,
            ClipRect(
              clipBehavior: element.clipBehavior,
              child: SizedBox(
                width: layout.layoutSize.width,
                height: layout.layoutSize.height,
                child: _buildForDetail(context, builder, canvas, layout),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gestureGate(bool canInteract, Widget child) {
    final controller = gestureController;
    if (!canInteract || controller == null) {
      return child;
    }
    return _CanvasWidgetGestureGate(
      controller: controller,
      child: child,
    );
  }

  Widget _buildForDetail(
    BuildContext context,
    WidgetElementBuilder builder,
    CanvasWidgetBuildContext canvas,
    CanvasWidgetLayout layout,
  ) {
    if (layout.detail == CanvasWidgetRenderDetail.full) {
      return builder.build(context, element, canvas: canvas);
    }

    return _previewFrame(
      isThumbnail:
          layout.detail == CanvasWidgetRenderDetail.thumbnail &&
          builder.useDefaultThumbnailFrame,
      child: builder.buildPreview(context, element, canvas: canvas),
    );
  }

  Widget _previewFrame({required bool isThumbnail, required Widget child}) {
    if (!isThumbnail) {
      return child;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x33000000)),
      ),
      child: child,
    );
  }

  Widget _placeholder(bool isSelected, CanvasWidgetLayout layout) {
    return Positioned(
      left: layout.screenRect.left,
      top: layout.screenRect.top,
      width: layout.screenRect.width,
      height: layout.screenRect.height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF9CA3AF),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              element.widgetType.isEmpty ? 'Widget' : element.widgetType,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedFrame(bool isSelected, Widget child) {
    final layerOpacity = applyLayerOpacity
        ? controller.canvasController.layerManager
              .layerById(element.layerId)
              ?.opacity
              .clamp(0.0, 1.0)
              .toDouble()
        : 1.0;

    return Opacity(
      opacity: element.opacity.clamp(0, 1).toDouble() * (layerOpacity ?? 1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(color: const Color(0xFF2563EB), width: 1.2)
              : null,
        ),
        child: child,
      ),
    );
  }
}

class _CanvasWidgetGestureGate extends StatefulWidget {
  const _CanvasWidgetGestureGate({
    required this.controller,
    required this.child,
  });

  final CanvasWidgetGestureController controller;
  final Widget child;

  @override
  State<_CanvasWidgetGestureGate> createState() =>
      _CanvasWidgetGestureGateState();
}

class _CanvasWidgetGestureGateState extends State<_CanvasWidgetGestureGate> {
  late _CanvasWidgetDragGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = _CanvasWidgetDragGestureRecognizer(widget.controller);
  }

  @override
  void didUpdateWidget(covariant _CanvasWidgetGestureGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) {
      return;
    }
    _recognizer.dispose();
    _recognizer = _CanvasWidgetDragGestureRecognizer(widget.controller);
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PreemptivePointerListener(
      onPointerDown: _recognizer.addPointer,
      child: widget.child,
    );
  }
}

class _PreemptivePointerListener extends SingleChildRenderObjectWidget {
  const _PreemptivePointerListener({
    required this.onPointerDown,
    required super.child,
  });

  final PointerDownEventListener onPointerDown;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPreemptivePointerListener(onPointerDown);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPreemptivePointerListener renderObject,
  ) {
    renderObject.onPointerDown = onPointerDown;
  }
}

class _RenderPreemptivePointerListener extends RenderProxyBox {
  _RenderPreemptivePointerListener(this.onPointerDown);

  PointerDownEventListener onPointerDown;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) {
      return false;
    }
    result.add(BoxHitTestEntry(this, position));
    hitTestChildren(result, position: position);
    return true;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      onPointerDown(event);
    }
  }
}

class _CanvasWidgetDragGestureRecognizer extends OneSequenceGestureRecognizer {
  _CanvasWidgetDragGestureRecognizer(this.controller);

  CanvasWidgetGestureController controller;
  final Map<int, Offset> _initialPositions = {};
  final Set<int> _acceptedPointers = {};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer);
    _initialPositions[event.pointer] = event.position;
    controller._register(event.pointer, this);
  }

  @override
  void handleEvent(PointerEvent event) {
    final initialPosition = _initialPositions[event.pointer];
    if (event is PointerMoveEvent &&
        initialPosition != null &&
        (event.position - initialPosition).distance >=
            CanvasWidgetGestureController.dragSlop) {
      _acceptPointer(event.pointer);
      return;
    }

    if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (!_acceptedPointers.contains(event.pointer)) {
        resolvePointer(event.pointer, GestureDisposition.rejected);
      }
      _stopTracking(event.pointer);
    }
  }

  void _acceptPointer(int pointer) {
    if (!_initialPositions.containsKey(pointer) ||
        !_acceptedPointers.add(pointer)) {
      return;
    }
    resolvePointer(pointer, GestureDisposition.accepted);
    _stopTracking(pointer);
  }

  void _stopTracking(int pointer) {
    if (_initialPositions.remove(pointer) == null) {
      return;
    }
    controller._unregister(pointer, this);
    _acceptedPointers.remove(pointer);
    stopTrackingPointer(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    _stopTracking(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'canvas widget drag';

  @override
  void dispose() {
    for (final pointer in _initialPositions.keys.toList(growable: false)) {
      controller._unregister(pointer, this);
    }
    _initialPositions.clear();
    _acceptedPointers.clear();
    super.dispose();
  }
}

import 'package:flutter/widgets.dart';

import '../layers/canvas_layer.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';

enum CanvasWidgetScaleMode { layoutScale, paintScale, fixedScreenSize }

enum CanvasWidgetRenderMode { live, snapshot }

@immutable
class CanvasWidgetElement extends CanvasElement {
  const CanvasWidgetElement({
    required this.id,
    required this.worldRect,
    required this.widgetType,
    this.widgetData = const <String, dynamic>{},
    this.layerId = CanvasLayer.defaultLayerId,
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
    this.isLocked = false,
    this.interactive = true,
    this.scaleMode = CanvasWidgetScaleMode.layoutScale,
    this.renderMode = CanvasWidgetRenderMode.snapshot,
    this.minScreenSize,
    this.maxScreenSize,
    this.clipBehavior = Clip.hardEdge,
    this.groupId,
  });

  static const elementType = 'widget';

  @override
  final String id;

  final Rect worldRect;
  final String widgetType;
  final Map<String, dynamic> widgetData;
  final bool isLocked;
  final bool interactive;
  final CanvasWidgetScaleMode scaleMode;
  final CanvasWidgetRenderMode renderMode;
  final Size? minScreenSize;
  final Size? maxScreenSize;
  final Clip clipBehavior;

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
  String get type => elementType;

  @override
  Rect get bounds => worldRect;

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    return worldRect.inflate(tolerance).contains(worldPoint);
  }

  @override
  CanvasWidgetElement copyWith({
    String? id,
    Rect? worldRect,
    String? widgetType,
    Map<String, dynamic>? widgetData,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    bool? isLocked,
    bool? interactive,
    CanvasWidgetScaleMode? scaleMode,
    CanvasWidgetRenderMode? renderMode,
    Size? minScreenSize,
    Size? maxScreenSize,
    Clip? clipBehavior,
    Object? groupId = _unset,
  }) {
    return CanvasWidgetElement(
      id: id ?? this.id,
      worldRect: worldRect ?? this.worldRect,
      widgetType: widgetType ?? this.widgetType,
      widgetData: widgetData ?? this.widgetData,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      isLocked: isLocked ?? this.isLocked,
      interactive: interactive ?? this.interactive,
      scaleMode: scaleMode ?? this.scaleMode,
      renderMode: renderMode ?? this.renderMode,
      minScreenSize: minScreenSize ?? this.minScreenSize,
      maxScreenSize: maxScreenSize ?? this.maxScreenSize,
      clipBehavior: clipBehavior ?? this.clipBehavior,
      groupId: identical(groupId, _unset)
          ? this.groupId
          : groupId as String?,
    );
  }

  @override
  CanvasWidgetElement translate(Offset delta) {
    return copyWith(worldRect: worldRect.shift(delta));
  }

  @override
  CanvasWidgetElement scaleElement(double factor, {Offset? pivot}) {
    final origin = pivot ?? worldRect.center;
    return copyWith(
      worldRect: Rect.fromPoints(
        scalePoint(worldRect.topLeft, factor, origin),
        scalePoint(worldRect.bottomRight, factor, origin),
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'layerId': layerId,
      'visible': visible,
      'opacity': opacity,
      'zIndex': zIndex,
      'groupId': groupId,
      'worldRect': {
        'left': worldRect.left,
        'top': worldRect.top,
        'right': worldRect.right,
        'bottom': worldRect.bottom,
      },
      'widgetType': widgetType,
      'widgetData': widgetData,
      'isLocked': isLocked,
      'interactive': interactive,
      'scaleMode': scaleMode.name,
      'renderMode': renderMode.name,
      if (minScreenSize != null) 'minScreenSize': _sizeToJson(minScreenSize!),
      if (maxScreenSize != null) 'maxScreenSize': _sizeToJson(maxScreenSize!),
      'clipBehavior': clipBehavior.name,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is CanvasWidgetElement &&
        other.id == id &&
        other.worldRect == worldRect &&
        other.widgetType == widgetType &&
        _mapEquals(other.widgetData, widgetData) &&
        other.layerId == layerId &&
        other.visible == visible &&
        other.opacity == opacity &&
        other.zIndex == zIndex &&
        other.isLocked == isLocked &&
        other.interactive == interactive &&
        other.scaleMode == scaleMode &&
        other.renderMode == renderMode &&
        other.minScreenSize == minScreenSize &&
        other.maxScreenSize == maxScreenSize &&
        other.clipBehavior == clipBehavior &&
        other.groupId == groupId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    worldRect,
    widgetType,
    Object.hashAllUnordered(widgetData.entries),
    layerId,
    visible,
    opacity,
    zIndex,
    isLocked,
    interactive,
    scaleMode,
    renderMode,
    minScreenSize,
    maxScreenSize,
    clipBehavior,
    groupId,
  );

  static Map<String, double> _sizeToJson(Size size) {
    return {'width': size.width, 'height': size.height};
  }

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  static const _unset = Object();
}

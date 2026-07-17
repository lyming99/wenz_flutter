import 'package:flutter/widgets.dart';

abstract class CanvasElement {
  const CanvasElement();

  String get id;
  String get type;
  String get layerId;
  Rect get bounds;
  bool get visible;
  double get opacity;
  int get zIndex;
  String? get groupId;

  double get rotation => 0;

  bool hitTest(Offset worldPoint, {double tolerance = 5.0});

  Map<String, dynamic> toJson();

  CanvasElement copyWith({
    String? id,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    String? groupId,
  });

  CanvasElement translate(Offset delta);

  CanvasElement scaleElement(double factor, {Offset? pivot});

  CanvasElement rotateElement(double radians, {Offset? pivot}) {
    return this;
  }
}

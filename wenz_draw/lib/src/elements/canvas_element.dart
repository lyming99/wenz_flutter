import 'dart:ui' show Offset, Rect;

/// 画布元素抽象基类（不可变）。
///
/// 所有具体的绘图元素（路径、矩形、椭圆等）都继承此类。
/// 元素为不可变对象，修改通过 [copyWith] 返回新实例。
abstract class CanvasElement {
  /// 唯一标识（UUID）
  String get id;

  /// 元素类型标识（如 'path', 'line', 'rect', 'ellipse'）
  String get type;

  /// 所属图层 ID
  String get layerId;

  /// 世界坐标系下的包围盒
  Rect get bounds;

  /// 可见性
  bool get visible;

  /// 透明度 0.0~1.0
  double get opacity;

  /// 层级排序（值越大越靠前）
  int get zIndex;

  /// 命中测试（世界坐标）。
  ///
  /// [worldPoint] 测试点（世界坐标）。
  /// [tolerance] 容差（世界坐标单位）。
  bool hitTest(Offset worldPoint, {double tolerance = 5.0});

  /// 序列化为 JSON
  Map<String, dynamic> toJson();

  /// 创建副本（修改部分字段）。
  ///
  /// 子类需实现自己的 copyWith，支持修改所有可变属性。
  CanvasElement copyWith({
    String? id,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
  });

  /// 平移（返回新实例）。
  CanvasElement translate(Offset delta);

  /// 缩放（返回新实例）。
  ///
  /// [factor] 缩放因子。
  /// [pivot] 缩放中心（世界坐标），默认为 bounds 中心。
  CanvasElement scaleElement(double factor, {Offset? pivot});
}

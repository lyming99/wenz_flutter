import 'dart:ui' show Canvas, Offset;

import 'canvas_element.dart';

/// 元素渲染器抽象接口。
///
/// 每种元素类型对应一个渲染器，将绘制逻辑与数据模型分离。
/// 通过 [ElementRendererRegistry] 注册和查找。
abstract class ElementRenderer<T extends CanvasElement> {
  /// 渲染元素到画布。
  ///
  /// [canvas] 已应用视图变换的画布（处于世界坐标系）。
  /// [element] 要渲染的元素。
  void render(Canvas canvas, T element);

  /// 命中测试。
  ///
  /// [element] 目标元素。
  /// [worldPoint] 测试点（世界坐标）。
  /// [tolerance] 容差（世界坐标单位）。
  bool hitTest(T element, Offset worldPoint, double tolerance);
}

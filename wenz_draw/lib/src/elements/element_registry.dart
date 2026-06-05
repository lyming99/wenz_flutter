import 'canvas_element.dart';
import 'element_renderer.dart';

/// 元素渲染器注册中心。
///
/// 每种元素类型（通过 [CanvasElement.type] 标识）注册一个对应的渲染器。
/// 渲染管线通过 [getRenderer] 查找渲染器来绘制元素。
///
/// 使用方式：
/// ```dart
/// ElementRendererRegistry.register<PathElement>('path', PathElementRenderer());
/// final renderer = ElementRendererRegistry.getRenderer('path');
/// ```
class ElementRendererRegistry {
  static final Map<String, ElementRenderer> _renderers = {};

  /// 注册渲染器。
  ///
  /// [type] 元素类型标识，与 [CanvasElement.type] 对应。
  /// [renderer] 渲染器实例。
  static void register<T extends CanvasElement>(
    String type,
    ElementRenderer<T> renderer,
  ) {
    _renderers[type] = renderer;
  }

  /// 获取指定类型的渲染器。
  ///
  /// 返回 null 表示未注册。
  static ElementRenderer? getRenderer(String type) {
    return _renderers[type];
  }

  /// 是否已注册指定类型。
  static bool hasRenderer(String type) => _renderers.containsKey(type);

  /// 获取所有已注册的类型。
  static Set<String> get registeredTypes => _renderers.keys.toSet();

  /// 清除所有注册（主要用于测试）。
  static void clear() => _renderers.clear();
}

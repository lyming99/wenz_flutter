import 'dart:ui' show Rect;

import '../elements/canvas_element.dart';
import '../utils/quad_tree.dart';

/// 空间索引，封装四叉树用于加速视口裁剪查询。
///
/// 当元素数量超过 [threshold] 时自动启用四叉树索引，
/// 否则退化为线性遍历。
class SpatialIndex {
  QuadTree<CanvasElement>? _tree;

  /// 元素数量阈值，超过此值启用四叉树。
  static const int threshold = 200;

  /// 世界边界（覆盖通常的绘图区域）。
  static const Rect worldBounds =
      Rect.fromLTRB(-100000, -100000, 100000, 100000);

  /// 重建索引。
  ///
  /// 当元素数量低于 [threshold] 时不创建四叉树，使用线性遍历。
  void rebuild(List<CanvasElement> elements) {
    if (elements.length < threshold) {
      _tree = null;
      return;
    }
    _tree = QuadTree<CanvasElement>(bounds: worldBounds);
    for (final element in elements) {
      _tree!.insert(element, element.bounds);
    }
  }

  /// 查询视口内可见元素。
  ///
  /// [visibleRect] 视口在世界坐标系中的矩形。
  /// [fallback] 当四叉树未启用时使用的完整元素列表。
  List<CanvasElement> query(
      Rect visibleRect, List<CanvasElement> fallback) {
    if (_tree == null) {
      // 元素少，线性遍历
      return fallback
          .where((e) => e.visible && visibleRect.overlaps(e.bounds))
          .toList();
    }
    return _tree!.query(visibleRect).where((e) => e.visible).toList();
  }

  /// 是否启用四叉树。
  bool get isActive => _tree != null;
}

import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../elements/canvas_element.dart';
import 'spatial_index.dart';

/// 元素管理器。
///
/// 负责元素的 CRUD 操作，内部使用 Map 存储。
/// 集成 [SpatialIndex] 提供基于四叉树的视口裁剪加速。
class ElementManager extends ChangeNotifier {
  final Map<String, CanvasElement> _elements = {};
  final SpatialIndex _spatialIndex = SpatialIndex();

  /// 添加元素。
  void addElement(CanvasElement element) {
    _elements[element.id] = element;
    _rebuildSpatialIndex();
    notifyListeners();
  }

  /// 移除元素。
  void removeElement(String id) {
    if (_elements.remove(id) != null) {
      _rebuildSpatialIndex();
      notifyListeners();
    }
  }

  /// 更新元素（替换同 id 的元素）。
  void updateElement(String id, CanvasElement element) {
    if (_elements.containsKey(id)) {
      _elements[id] = element;
      _rebuildSpatialIndex();
      notifyListeners();
    }
  }

  /// 获取元素。
  CanvasElement? getElement(String id) => _elements[id];

  /// 获取所有元素（按 zIndex 排序）。
  List<CanvasElement> get elements {
    final list = _elements.values.toList();
    list.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return list;
  }

  /// 元素数量。
  int get count => _elements.length;

  /// 是否包含指定元素。
  bool contains(String id) => _elements.containsKey(id);

  /// 清除所有元素。
  void clear() {
    _elements.clear();
    _rebuildSpatialIndex();
    notifyListeners();
  }

  /// 获取视口内可见的元素（使用空间索引加速）。
  ///
  /// [visibleRect] 视口在世界坐标系中的矩形。
  List<CanvasElement> getVisibleElements(Rect visibleRect) {
    final result =
        _spatialIndex.query(visibleRect, _elements.values.toList());
    result.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return result;
  }

  /// 空间索引。
  SpatialIndex get spatialIndex => _spatialIndex;

  /// 重建空间索引。
  void _rebuildSpatialIndex() {
    _spatialIndex.rebuild(_elements.values.toList());
  }
}

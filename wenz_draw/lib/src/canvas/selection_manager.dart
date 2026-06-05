import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import '../elements/canvas_element.dart';

/// 选择管理器。
///
/// 管理画布上被选中的元素 ID 集合。
class SelectionManager extends ChangeNotifier {
  final Set<String> _selectedIds = {};

  /// 选中单个元素。
  ///
  /// [addToSelection] 为 true 时追加到现有选择，否则替换。
  void select(String id, {bool addToSelection = false}) {
    if (!addToSelection) {
      _selectedIds.clear();
    }
    _selectedIds.add(id);
    notifyListeners();
  }

  /// 框选：选择矩形区域内的所有元素。
  void selectInRect(Rect worldRect, List<CanvasElement> elements) {
    _selectedIds.clear();
    for (final element in elements) {
      if (element.visible && worldRect.overlaps(element.bounds)) {
        // 更精确：检查元素 bounds 是否大部分在选择框内
        final intersection = worldRect.intersect(element.bounds);
        if (intersection != null) {
          final intersectionArea = intersection.width * intersection.height;
          final elementArea = element.bounds.width * element.bounds.height;
          // 元素面积 > 0 且交集面积占元素面积 > 50%
          if (elementArea > 0 && intersectionArea / elementArea > 0.5) {
            _selectedIds.add(element.id);
          } else if (elementArea == 0) {
            // 线段等零面积元素，只要相交就选中
            _selectedIds.add(element.id);
          }
        }
      }
    }
    notifyListeners();
  }

  /// 全选。
  void selectAll(List<CanvasElement> elements) {
    _selectedIds.clear();
    for (final element in elements) {
      if (element.visible) {
        _selectedIds.add(element.id);
      }
    }
    notifyListeners();
  }

  /// 取消所有选择。
  void deselectAll() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    notifyListeners();
  }

  /// 从选择中移除。
  void removeFromSelection(String id) {
    if (_selectedIds.remove(id)) {
      notifyListeners();
    }
  }

  /// 当前选中的元素 ID 集合。
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  /// 是否选中了指定元素。
  bool isSelected(String id) => _selectedIds.contains(id);

  /// 是否有选中元素。
  bool get hasSelection => _selectedIds.isNotEmpty;

  /// 选中元素数量。
  int get selectedCount => _selectedIds.length;

  /// 获取选中的元素对象。
  List<CanvasElement> getSelectedElements(List<CanvasElement> all) {
    return all.where((e) => _selectedIds.contains(e.id)).toList();
  }

  /// 获取选中元素的统一包围盒。
  ///
  /// 返回 null 表示无选中元素。
  Rect? getSelectionBounds(List<CanvasElement> all) {
    final selected = getSelectedElements(all);
    if (selected.isEmpty) return null;

    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;

    for (final element in selected) {
      final bounds = element.bounds;
      if (bounds.left < left) left = bounds.left;
      if (bounds.top < top) top = bounds.top;
      if (bounds.right > right) right = bounds.right;
      if (bounds.bottom > bottom) bottom = bounds.bottom;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// 清除所有状态。
  void clear() {
    _selectedIds.clear();
    notifyListeners();
  }
}

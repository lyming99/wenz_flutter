import 'dart:ui' show Rect;

/// 四叉树数据项，存储值和包围盒。
class _QuadTreeItem<T> {
  final T value;
  final Rect bounds;
  _QuadTreeItem(this.value, this.bounds);
}

/// 四叉树节点，存储具有包围盒的数据项。
///
/// 用于空间索引，加速矩形区域查询。当节点中的数据项超过 [maxItems] 且
/// 深度未达 [maxDepth] 时，自动分裂为四个子节点。
class QuadTree<T> {
  /// 节点边界。
  final Rect bounds;

  /// 最大容量（超过则分裂）。
  final int maxItems;

  /// 最大深度。
  final int maxDepth;

  /// 当前深度。
  final int depth;

  /// 存储的数据项（bounds + value 对）。
  final List<_QuadTreeItem<T>> _items = [];

  /// 四个子节点（分裂后创建）。
  QuadTree<T>? _nw, _ne, _sw, _se;

  /// 是否已分裂。
  bool _isSplit = false;

  QuadTree({
    required this.bounds,
    this.maxItems = 8,
    this.maxDepth = 8,
    this.depth = 0,
  });

  /// 插入数据项。
  ///
  /// [value] 要存储的数据。
  /// [itemBounds] 数据项的包围盒。
  void insert(T value, Rect itemBounds) {
    // 如果不相交则不插入
    if (!bounds.overlaps(itemBounds)) return;

    // 如果已分裂，尝试插入子节点
    if (_isSplit) {
      final child = _getChild(itemBounds);
      if (child != null) {
        child.insert(value, itemBounds);
        return;
      }
      // 跨越多个象限，保留在当前节点
      _items.add(_QuadTreeItem(value, itemBounds));
      return;
    }

    // 未分裂，直接添加
    _items.add(_QuadTreeItem(value, itemBounds));

    // 检查是否需要分裂
    if (_items.length > maxItems && depth < maxDepth) {
      _split();
    }
  }

  /// 查询与指定矩形相交的所有数据项。
  ///
  /// 返回结果已去重。
  List<T> query(Rect queryRect) {
    // 如果不相交，直接返回空
    if (!bounds.overlaps(queryRect)) return [];

    final result = <T>{};
    _queryRecursive(queryRect, result);
    return result.toList();
  }

  void _queryRecursive(Rect queryRect, Set<T> result) {
    if (!bounds.overlaps(queryRect)) return;

    // 检查当前节点的数据项
    for (final item in _items) {
      if (queryRect.overlaps(item.bounds)) {
        result.add(item.value);
      }
    }

    // 递归检查子节点
    if (_isSplit) {
      _nw?._queryRecursive(queryRect, result);
      _ne?._queryRecursive(queryRect, result);
      _sw?._queryRecursive(queryRect, result);
      _se?._queryRecursive(queryRect, result);
    }
  }

  /// 移除数据项（通过 value 相等判断）。
  ///
  /// [value] 要移除的数据。
  /// [itemBounds] 数据项的包围盒（用于加速定位）。
  /// 返回是否成功移除。
  bool remove(T value, Rect itemBounds) {
    // 如果不相交，不可能在此节点
    if (!bounds.overlaps(itemBounds)) return false;

    // 在当前节点的数据项中查找并移除
    for (int i = _items.length - 1; i >= 0; i--) {
      if (_items[i].value == value) {
        _items.removeAt(i);
        return true;
      }
    }

    // 递归检查子节点
    if (_isSplit) {
      return _nw?.remove(value, itemBounds) == true ||
          _ne?.remove(value, itemBounds) == true ||
          _sw?.remove(value, itemBounds) == true ||
          _se?.remove(value, itemBounds) == true;
    }

    return false;
  }

  /// 清空所有数据。
  void clear() {
    _items.clear();
    _nw?.clear();
    _ne?.clear();
    _sw?.clear();
    _se?.clear();
    _nw = null;
    _ne = null;
    _sw = null;
    _se = null;
    _isSplit = false;
  }

  /// 总数据项数。
  int get size {
    int count = _items.length;
    if (_isSplit) {
      count += _nw!.size + _ne!.size + _sw!.size + _se!.size;
    }
    return count;
  }

  /// 分裂为四个子节点，并将现有数据项重新分配。
  void _split() {
    final cx = (bounds.left + bounds.right) / 2;
    final cy = (bounds.top + bounds.bottom) / 2;

    _nw = QuadTree<T>(
      bounds: Rect.fromLTRB(bounds.left, bounds.top, cx, cy),
      maxItems: maxItems,
      maxDepth: maxDepth,
      depth: depth + 1,
    );
    _ne = QuadTree<T>(
      bounds: Rect.fromLTRB(cx, bounds.top, bounds.right, cy),
      maxItems: maxItems,
      maxDepth: maxDepth,
      depth: depth + 1,
    );
    _sw = QuadTree<T>(
      bounds: Rect.fromLTRB(bounds.left, cy, cx, bounds.bottom),
      maxItems: maxItems,
      maxDepth: maxDepth,
      depth: depth + 1,
    );
    _se = QuadTree<T>(
      bounds: Rect.fromLTRB(cx, cy, bounds.right, bounds.bottom),
      maxItems: maxItems,
      maxDepth: maxDepth,
      depth: depth + 1,
    );

    _isSplit = true;

    // 重新分配现有数据项
    final oldItems = List<_QuadTreeItem<T>>.from(_items);
    _items.clear();

    for (final item in oldItems) {
      final child = _getChild(item.bounds);
      if (child != null) {
        child.insert(item.value, item.bounds);
      } else {
        // 跨越多个象限，保留在当前节点
        _items.add(item);
      }
    }
  }

  /// 获取数据项应属于哪个子节点。
  ///
  /// 如果 [itemBounds] 完全在某个子节点内，返回该子节点。
  /// 如果跨越多个象限，返回 null（保留在当前节点）。
  QuadTree<T>? _getChild(Rect itemBounds) {
    if (!_isSplit) return null;

    final inNW = _nw!.bounds.contains(itemBounds.topLeft) &&
        _nw!.bounds.contains(itemBounds.bottomRight);
    if (inNW) return _nw;

    final inNE = _ne!.bounds.contains(itemBounds.topLeft) &&
        _ne!.bounds.contains(itemBounds.bottomRight);
    if (inNE) return _ne;

    final inSW = _sw!.bounds.contains(itemBounds.topLeft) &&
        _sw!.bounds.contains(itemBounds.bottomRight);
    if (inSW) return _sw;

    final inSE = _se!.bounds.contains(itemBounds.topLeft) &&
        _se!.bounds.contains(itemBounds.bottomRight);
    if (inSE) return _se;

    return null;
  }
}

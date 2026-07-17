import 'package:flutter/widgets.dart';

class QuadTree<T> {
  QuadTree({
    required this.bounds,
    this.capacity = 8,
    this.maxDepth = 8,
    this.depth = 0,
  });

  final Rect bounds;
  final int capacity;
  final int maxDepth;
  final int depth;
  final List<_QuadEntry<T>> _items = [];
  List<QuadTree<T>>? _children;

  void insert(Rect rect, T value) {
    if (!bounds.overlaps(rect) && !bounds.contains(rect.center)) {
      return;
    }

    final children = _children;
    if (children != null) {
      final child = _childContaining(rect);
      if (child != null) {
        child.insert(rect, value);
        return;
      }
    }

    _items.add(_QuadEntry(rect, value));
    if (_items.length > capacity && depth < maxDepth) {
      _subdivide();
    }
  }

  List<T> query(Rect range) {
    final result = <T>[];
    _query(range, result);
    return result;
  }

  void _query(Rect range, List<T> result) {
    if (!bounds.overlaps(range)) {
      return;
    }
    for (final item in _items) {
      if (item.rect.overlaps(range) || range.contains(item.rect.center)) {
        result.add(item.value);
      }
    }
    final children = _children;
    if (children == null) {
      return;
    }
    for (final child in children) {
      child._query(range, result);
    }
  }

  QuadTree<T>? _childContaining(Rect rect) {
    final children = _children;
    if (children == null) {
      return null;
    }
    for (final child in children) {
      if (child.bounds.contains(rect.topLeft) &&
          child.bounds.contains(rect.bottomRight)) {
        return child;
      }
    }
    return null;
  }

  void _subdivide() {
    if (_children != null) {
      return;
    }
    final halfWidth = bounds.width / 2;
    final halfHeight = bounds.height / 2;
    final left = bounds.left;
    final top = bounds.top;
    final nextDepth = depth + 1;
    _children = [
      QuadTree<T>(
        bounds: Rect.fromLTWH(left, top, halfWidth, halfHeight),
        capacity: capacity,
        maxDepth: maxDepth,
        depth: nextDepth,
      ),
      QuadTree<T>(
        bounds: Rect.fromLTWH(left + halfWidth, top, halfWidth, halfHeight),
        capacity: capacity,
        maxDepth: maxDepth,
        depth: nextDepth,
      ),
      QuadTree<T>(
        bounds: Rect.fromLTWH(left, top + halfHeight, halfWidth, halfHeight),
        capacity: capacity,
        maxDepth: maxDepth,
        depth: nextDepth,
      ),
      QuadTree<T>(
        bounds: Rect.fromLTWH(
          left + halfWidth,
          top + halfHeight,
          halfWidth,
          halfHeight,
        ),
        capacity: capacity,
        maxDepth: maxDepth,
        depth: nextDepth,
      ),
    ];

    final existing = List<_QuadEntry<T>>.from(_items);
    _items.clear();
    for (final item in existing) {
      final child = _childContaining(item.rect);
      if (child == null) {
        _items.add(item);
      } else {
        child.insert(item.rect, item.value);
      }
    }
  }
}

class _QuadEntry<T> {
  const _QuadEntry(this.rect, this.value);

  final Rect rect;
  final T value;
}

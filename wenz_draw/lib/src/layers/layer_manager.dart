import 'package:flutter/foundation.dart';

import 'canvas_layer.dart';

/// 图层管理器。
///
/// 管理画布图层的增删改查、排序、可见性等。
class LayerManager extends ChangeNotifier {
  final List<CanvasLayer> _layers = [];
  String? _activeLayerId;
  int _layerCounter = 0;

  /// 获取所有图层。
  List<CanvasLayer> get layers => List.unmodifiable(_layers);

  /// 当前活跃图层。
  CanvasLayer? get activeLayer =>
      _layers.where((l) => l.id == _activeLayerId).firstOrNull;

  /// 当前活跃图层 ID。
  String? get activeLayerId => _activeLayerId;

  /// 可见图层列表。
  List<CanvasLayer> get visibleLayers =>
      _layers.where((l) => l.isVisible).toList();

  /// 图层数量。
  int get count => _layers.length;

  /// 添加新图层。
  CanvasLayer addLayer({String? name}) {
    _layerCounter++;
    final layer = CanvasLayer(
      id: 'layer_$_layerCounter',
      name: name ?? '图层 $_layerCounter',
    );
    _layers.add(layer);
    _activeLayerId ??= layer.id;
    notifyListeners();
    return layer;
  }

  /// 移除图层。
  void removeLayer(String id) {
    final index = _layers.indexWhere((l) => l.id == id);
    if (index < 0) return;
    _layers.removeAt(index);

    if (_activeLayerId == id) {
      _activeLayerId = _layers.isNotEmpty ? _layers.last.id : null;
    }
    notifyListeners();
  }

  /// 设置活跃图层。
  void setActiveLayer(String id) {
    if (_layers.any((l) => l.id == id)) {
      _activeLayerId = id;
      notifyListeners();
    }
  }

  /// 切换可见性。
  void toggleVisibility(String id) {
    final index = _layers.indexWhere((l) => l.id == id);
    if (index < 0) return;
    _layers[index] = _layers[index].copyWith(isVisible: !_layers[index].isVisible);
    notifyListeners();
  }

  /// 切换锁定。
  void toggleLock(String id) {
    final index = _layers.indexWhere((l) => l.id == id);
    if (index < 0) return;
    _layers[index] = _layers[index].copyWith(isLocked: !_layers[index].isLocked);
    notifyListeners();
  }

  /// 设置透明度。
  void setOpacity(String id, double opacity) {
    final index = _layers.indexWhere((l) => l.id == id);
    if (index < 0) return;
    _layers[index] = _layers[index].copyWith(opacity: opacity.clamp(0.0, 1.0));
    notifyListeners();
  }

  /// 重排图层顺序。
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final layer = _layers.removeAt(oldIndex);
    _layers.insert(newIndex, layer);
    notifyListeners();
  }

  /// 向下合并图层。
  void mergeDown(String id) {
    final index = _layers.indexWhere((l) => l.id == id);
    if (index <= 0) return; // 没有下方图层

    final upper = _layers[index];
    final lower = _layers[index - 1];

    // 合并元素 ID
    final merged = lower.copyWith(
      elementIds: [...lower.elementIds, ...upper.elementIds],
    );
    _layers[index - 1] = merged;
    _layers.removeAt(index);

    if (_activeLayerId == id) {
      _activeLayerId = merged.id;
    }
    notifyListeners();
  }

  /// 获取指定 ID 的图层。
  CanvasLayer? getLayer(String id) =>
      _layers.where((l) => l.id == id).firstOrNull;

  /// 清除所有图层。
  void clear() {
    _layers.clear();
    _activeLayerId = null;
    notifyListeners();
  }
}

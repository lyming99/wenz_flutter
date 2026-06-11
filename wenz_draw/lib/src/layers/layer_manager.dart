import 'package:flutter/foundation.dart';

import '../utils/uuid_generator.dart';
import 'canvas_layer.dart';

class LayerManager extends ChangeNotifier {
  LayerManager({List<CanvasLayer>? layers, String? activeLayerId})
    : _layers = List<CanvasLayer>.from(
        layers ??
            const [
              CanvasLayer(id: CanvasLayer.defaultLayerId, name: 'Layer 1'),
            ],
      ),
      _activeLayerId = activeLayerId ?? CanvasLayer.defaultLayerId;

  final List<CanvasLayer> _layers;
  String _activeLayerId;

  List<CanvasLayer> get layers => List<CanvasLayer>.unmodifiable(_layers);
  String get activeLayerId => _activeLayerId;

  CanvasLayer get activeLayer {
    return _layers.firstWhere(
      (layer) => layer.id == _activeLayerId,
      orElse: () => _layers.first,
    );
  }

  List<CanvasLayer> get visibleLayers {
    return List<CanvasLayer>.unmodifiable(
      _layers.where((layer) => layer.isVisible),
    );
  }

  void addLayer({String? name}) {
    final layer = CanvasLayer(
      id: UuidGenerator.create(),
      name: name ?? 'Layer ${_layers.length + 1}',
    );
    _layers.add(layer);
    _activeLayerId = layer.id;
    notifyListeners();
  }

  void removeLayer(String id) {
    if (_layers.length == 1) {
      return;
    }
    _layers.removeWhere((layer) => layer.id == id);
    if (_activeLayerId == id) {
      _activeLayerId = _layers.last.id;
    }
    notifyListeners();
  }

  void setActiveLayer(String id) {
    if (_activeLayerId == id || !_layers.any((layer) => layer.id == id)) {
      return;
    }
    _activeLayerId = id;
    notifyListeners();
  }

  void toggleVisibility(String id) {
    _updateLayer(id, (layer) => layer.copyWith(isVisible: !layer.isVisible));
  }

  void toggleLock(String id) {
    _updateLayer(id, (layer) => layer.copyWith(isLocked: !layer.isLocked));
  }

  void setOpacity(String id, double opacity) {
    _updateLayer(
      id,
      (layer) => layer.copyWith(opacity: opacity.clamp(0.0, 1.0)),
    );
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _layers.length) {
      return;
    }
    final targetIndex = newIndex.clamp(0, _layers.length - 1);
    final layer = _layers.removeAt(oldIndex);
    _layers.insert(targetIndex, layer);
    notifyListeners();
  }

  int layerIndexOf(String id) {
    final index = _layers.indexWhere((layer) => layer.id == id);
    return index == -1 ? 0 : index;
  }

  CanvasLayer? layerById(String id) {
    for (final layer in _layers) {
      if (layer.id == id) {
        return layer;
      }
    }
    return null;
  }

  bool isLayerVisible(String id) {
    return layerById(id)?.isVisible ?? true;
  }

  bool isLayerLocked(String id) {
    return layerById(id)?.isLocked ?? false;
  }

  void _updateLayer(String id, CanvasLayer Function(CanvasLayer) update) {
    final index = _layers.indexWhere((layer) => layer.id == id);
    if (index == -1) {
      return;
    }
    _layers[index] = update(_layers[index]);
    notifyListeners();
  }
}

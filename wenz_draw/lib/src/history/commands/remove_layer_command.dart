import '../../canvas/canvas_controller.dart';
import '../../elements/canvas_element.dart';
import '../../layers/canvas_layer.dart';
import '../canvas_command.dart';

/// Removes a layer and all its elements. Undo restores both the layer
/// (at its original index) and all elements that belonged to it.
class RemoveLayerCommand extends CanvasCommand {
  const RemoveLayerCommand({
    required this.layer,
    required this.layerIndex,
    required this.wasActiveLayer,
    required this.elements,
  });

  final CanvasLayer layer;
  final int layerIndex;
  final bool wasActiveLayer;
  final List<CanvasElement> elements;

  @override
  String get description => 'Remove layer "${layer.name}"';

  @override
  void execute(CanvasController controller) {
    // Remove all elements belonging to this layer.
    for (final element in elements) {
      controller.applyElementRemoved(element.id);
    }
    controller.layerManager.removeLayer(layer.id);
  }

  @override
  void undo(CanvasController controller) {
    // Restore the layer at its original position.
    controller.layerManager.insertLayer(layer, layerIndex);
    if (wasActiveLayer) {
      controller.layerManager.setActiveLayer(layer.id);
    }
    // Restore all elements.
    for (final element in elements) {
      controller.applyElementAdded(element);
    }
  }
}

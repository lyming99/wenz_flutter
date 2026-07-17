import '../../canvas/canvas_controller.dart';
import '../../layers/canvas_layer.dart';
import '../canvas_command.dart';

/// Adds a new layer. Undo removes it.
class AddLayerCommand extends CanvasCommand {
  const AddLayerCommand({
    required this.layer,
    required this.previousActiveLayerId,
  });

  final CanvasLayer layer;
  final String previousActiveLayerId;

  @override
  String get description => 'Add layer "${layer.name}"';

  @override
  void execute(CanvasController controller) {
    controller.layerManager.insertLayer(layer, controller.layers.length);
    controller.layerManager.setActiveLayer(layer.id);
  }

  @override
  void undo(CanvasController controller) {
    controller.layerManager.removeLayer(layer.id);
    controller.layerManager.setActiveLayer(previousActiveLayerId);
  }
}

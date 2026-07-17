import '../../canvas/canvas_controller.dart';
import '../../layers/canvas_layer.dart';
import '../canvas_command.dart';

/// Updates a layer property (visibility, lock, opacity).
/// Stores before/after snapshots to support undo/redo.
class UpdateLayerCommand extends CanvasCommand {
  const UpdateLayerCommand({
    required this.before,
    required this.after,
    this.descriptionText,
  });

  final CanvasLayer before;
  final CanvasLayer after;
  final String? descriptionText;

  @override
  String get description => descriptionText ?? 'Update layer';

  @override
  void execute(CanvasController controller) {
    controller.layerManager.replaceLayer(after);
  }

  @override
  void undo(CanvasController controller) {
    controller.layerManager.replaceLayer(before);
  }
}

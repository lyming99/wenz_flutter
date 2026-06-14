import '../../canvas/canvas_controller.dart';
import '../canvas_command.dart';

/// Reorders a layer from [oldIndex] to [newIndex]. Undo moves it back.
class ReorderLayerCommand extends CanvasCommand {
  const ReorderLayerCommand({
    required this.oldIndex,
    required this.newIndex,
  });

  final int oldIndex;
  final int newIndex;

  @override
  String get description => 'Reorder layer';

  @override
  void execute(CanvasController controller) {
    controller.layerManager.reorder(oldIndex, newIndex);
  }

  @override
  void undo(CanvasController controller) {
    // Move the layer back from newIndex to oldIndex.
    controller.layerManager.reorder(newIndex, oldIndex);
  }
}

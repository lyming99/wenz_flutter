import '../../canvas/canvas_controller.dart';
import '../../elements/canvas_element.dart';
import '../canvas_command.dart';

class UpdateElementCommand extends CanvasCommand {
  const UpdateElementCommand({
    required this.before,
    required this.after,
    this.description = 'Update element',
  });

  final CanvasElement before;
  final CanvasElement after;

  @override
  final String description;

  @override
  void execute(CanvasController controller) {
    controller.applyElementUpdated(after.id, after);
  }

  @override
  void undo(CanvasController controller) {
    controller.applyElementUpdated(before.id, before);
  }
}

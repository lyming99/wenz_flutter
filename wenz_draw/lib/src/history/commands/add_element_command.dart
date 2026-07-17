import '../../canvas/canvas_controller.dart';
import '../../elements/canvas_element.dart';
import '../canvas_command.dart';

class AddElementCommand extends CanvasCommand {
  const AddElementCommand(this.element);

  final CanvasElement element;

  @override
  String get description => 'Add ${element.type}';

  @override
  void execute(CanvasController controller) {
    controller.applyElementAdded(element);
  }

  @override
  void undo(CanvasController controller) {
    controller.applyElementRemoved(element.id);
  }
}

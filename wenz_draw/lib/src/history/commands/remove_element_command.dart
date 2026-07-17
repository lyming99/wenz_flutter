import '../../canvas/canvas_controller.dart';
import '../../elements/canvas_element.dart';
import '../canvas_command.dart';

class RemoveElementCommand extends CanvasCommand {
  const RemoveElementCommand(this.element);

  final CanvasElement element;

  @override
  String get description => 'Remove ${element.type}';

  @override
  void execute(CanvasController controller) {
    controller.applyElementRemoved(element.id);
  }

  @override
  void undo(CanvasController controller) {
    controller.applyElementAdded(element);
  }
}

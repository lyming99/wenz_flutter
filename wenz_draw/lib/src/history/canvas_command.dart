import '../canvas/canvas_controller.dart';

abstract class CanvasCommand {
  const CanvasCommand();

  String get description;

  void execute(CanvasController controller);

  void undo(CanvasController controller);
}

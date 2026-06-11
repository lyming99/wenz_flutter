import '../../canvas/canvas_controller.dart';
import '../canvas_command.dart';

class BatchCommand extends CanvasCommand {
  const BatchCommand({
    required this.commands,
    this.description = 'Batch operation',
  });

  final List<CanvasCommand> commands;

  @override
  final String description;

  @override
  void execute(CanvasController controller) {
    for (final command in commands) {
      command.execute(controller);
    }
  }

  @override
  void undo(CanvasController controller) {
    for (final command in commands.reversed) {
      command.undo(controller);
    }
  }
}

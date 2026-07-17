import '../../elements/canvas_element.dart';
import 'update_element_command.dart';

class MoveElementCommand extends UpdateElementCommand {
  const MoveElementCommand({
    required CanvasElement before,
    required CanvasElement after,
  }) : super(before: before, after: after, description: 'Move element');
}

import '../../canvas/element_manager.dart';
import '../../elements/canvas_element.dart';
import '../canvas_command.dart';

/// 移除元素命令。
///
/// execute: 从 ElementManager 中移除该元素。
/// undo: 将元素重新添加到 ElementManager。
class RemoveElementCommand implements CanvasCommand {
  final ElementManager _manager;
  final CanvasElement _element;

  RemoveElementCommand(this._manager, this._element);

  @override
  void execute() {
    _manager.removeElement(_element.id);
  }

  @override
  void undo() {
    _manager.addElement(_element);
  }

  @override
  String get description => '移除元素 (${_element.type})';
}

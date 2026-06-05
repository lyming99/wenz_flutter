import '../../canvas/element_manager.dart';
import '../../elements/canvas_element.dart';
import '../canvas_command.dart';

/// 添加元素命令。
///
/// execute: 将元素添加到 ElementManager。
/// undo: 从 ElementManager 中移除该元素。
class AddElementCommand implements CanvasCommand {
  final ElementManager _manager;
  final CanvasElement _element;

  AddElementCommand(this._manager, this._element);

  @override
  void execute() {
    _manager.addElement(_element);
  }

  @override
  void undo() {
    _manager.removeElement(_element.id);
  }

  @override
  String get description => '添加元素 (${_element.type})';
}

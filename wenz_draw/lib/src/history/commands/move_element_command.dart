import 'dart:ui' show Offset;

import '../../canvas/element_manager.dart';
import '../canvas_command.dart';

/// 移动元素命令。
///
/// execute: 将元素平移 [delta]。
/// undo: 将元素平移 -[delta]（恢复原位）。
class MoveElementCommand implements CanvasCommand {
  final ElementManager _manager;
  final String _elementId;
  final Offset _delta;

  MoveElementCommand(this._manager, this._elementId, this._delta);

  @override
  void execute() {
    final element = _manager.getElement(_elementId);
    if (element != null) {
      _manager.updateElement(_elementId, element.translate(_delta));
    }
  }

  @override
  void undo() {
    final element = _manager.getElement(_elementId);
    if (element != null) {
      _manager.updateElement(_elementId, element.translate(-_delta));
    }
  }

  @override
  String get description =>
      '移动元素 (dx: ${_delta.dx.toStringAsFixed(1)}, dy: ${_delta.dy.toStringAsFixed(1)})';
}

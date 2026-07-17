import 'package:flutter/foundation.dart';

import '../canvas/canvas_controller.dart';
import 'canvas_command.dart';

class HistoryManager extends ChangeNotifier {
  HistoryManager({this.maxHistory = 100});

  final int maxHistory;
  final List<CanvasCommand> _undoStack = [];
  final List<CanvasCommand> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  List<CanvasCommand> get undoStack => List.unmodifiable(_undoStack);
  List<CanvasCommand> get redoStack => List.unmodifiable(_redoStack);

  void execute(CanvasCommand command, CanvasController controller) {
    command.execute(controller);
    record(command);
  }

  void record(CanvasCommand command) {
    _undoStack.add(command);
    if (_undoStack.length > maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    notifyListeners();
  }

  void undo(CanvasController controller) {
    if (!canUndo) {
      return;
    }
    final command = _undoStack.removeLast();
    command.undo(controller);
    _redoStack.add(command);
    notifyListeners();
  }

  void redo(CanvasController controller) {
    if (!canRedo) {
      return;
    }
    final command = _redoStack.removeLast();
    command.execute(controller);
    _undoStack.add(command);
    notifyListeners();
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}

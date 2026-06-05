import 'package:flutter/foundation.dart';

import 'canvas_command.dart';

/// 历史记录管理器（Command 模式）。
///
/// 维护撤销/重做栈，支持有限长度的操作历史。
class HistoryManager extends ChangeNotifier {
  final List<CanvasCommand> _undoStack = [];
  final List<CanvasCommand> _redoStack = [];

  /// 最大历史记录条数。
  final int maxHistory;

  HistoryManager({this.maxHistory = 100});

  // ─── 公开 API ─────────────────────────────────────────────

  /// 执行命令并加入撤销栈，同时清空重做栈。
  void execute(CanvasCommand command) {
    command.execute();
    _undoStack.add(command);
    _redoStack.clear();
    _trimUndoStack();
    notifyListeners();
  }

  /// 撤销最近一次操作。
  void undo() {
    if (_undoStack.isEmpty) return;
    final command = _undoStack.removeLast();
    command.undo();
    _redoStack.add(command);
    notifyListeners();
  }

  /// 重做最近一次撤销的操作。
  void redo() {
    if (_redoStack.isEmpty) return;
    final command = _redoStack.removeLast();
    command.execute();
    _undoStack.add(command);
    notifyListeners();
  }

  /// 是否可以撤销。
  bool get canUndo => _undoStack.isNotEmpty;

  /// 是否可以重做。
  bool get canRedo => _redoStack.isNotEmpty;

  /// 撤销栈大小。
  int get undoCount => _undoStack.length;

  /// 重做栈大小。
  int get redoCount => _redoStack.length;

  /// 清空所有历史记录。
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  // ─── 内部方法 ─────────────────────────────────────────────

  /// 裁剪撤销栈，使其不超过 [maxHistory]。
  void _trimUndoStack() {
    while (_undoStack.length > maxHistory) {
      _undoStack.removeAt(0);
    }
  }

  @override
  void dispose() {
    _undoStack.clear();
    _redoStack.clear();
    super.dispose();
  }
}

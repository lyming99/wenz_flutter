import '../core/transaction/change_set.dart';

class HistoryManager {
  HistoryManager({this.limit = 1000});

  final int limit;
  final List<ChangeSet> _undoStack = <ChangeSet>[];
  final List<ChangeSet> _redoStack = <ChangeSet>[];

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  int get undoDepth => _undoStack.length;

  int get redoDepth => _redoStack.length;

  void push(ChangeSet change) {
    if (change.isNoop) {
      return;
    }
    _undoStack.add(change);
    _redoStack.clear();
    if (_undoStack.length > limit) {
      _undoStack.removeAt(0);
    }
  }

  /// Coalesces [change] into the most recent undo entry instead of pushing a
  /// new one. The merged entry keeps the original [ChangeSet.before] (so a
  /// single undo reverts the whole coalesced run) and adopts [change]'s
  /// `after` and selection-after. Used by [CommandExecutor] to merge adjacent
  /// commands (e.g. consecutive insertText) into one undo step.
  ///
  /// If the undo stack is empty this falls back to [push].
  void merge(ChangeSet change) {
    if (change.isNoop) {
      return;
    }
    if (_undoStack.isEmpty) {
      push(change);
      return;
    }
    final top = _undoStack.removeLast();
    _undoStack.add(
      ChangeSet(
        before: top.before,
        after: change.after,
        selectionBefore: top.selectionBefore,
        selectionAfter: change.selectionAfter,
        description: top.description,
      ),
    );
    _redoStack.clear();
  }

  ChangeSet? undo() {
    if (!canUndo) {
      return null;
    }
    final change = _undoStack.removeLast();
    _redoStack.add(change);
    return change;
  }

  ChangeSet? redo() {
    if (!canRedo) {
      return null;
    }
    final change = _redoStack.removeLast();
    _undoStack.add(change);
    return change;
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}

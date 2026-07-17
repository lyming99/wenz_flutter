import '../core/transaction/change_set.dart';

class HistoryManager {
  HistoryManager({
    this.limit = 1000,
    this.maxEstimatedBytes = 16 * 1024 * 1024,
  })  : assert(limit > 0),
        assert(maxEstimatedBytes > 0);

  final int limit;
  final int maxEstimatedBytes;
  final List<ChangeSet> _undoStack = <ChangeSet>[];
  final List<ChangeSet> _redoStack = <ChangeSet>[];
  int _estimatedRetainedBytes = 0;

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  int get undoDepth => _undoStack.length;

  int get redoDepth => _redoStack.length;

  int get estimatedRetainedBytes => _estimatedRetainedBytes;

  void push(ChangeSet change) {
    if (change.isNoop) {
      return;
    }
    _undoStack.add(change);
    _estimatedRetainedBytes += _entryBytes(change);
    _clearRedo();
    _trimUndoBudget();
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
    _estimatedRetainedBytes -= _entryBytes(top);
    final merged = ChangeSet(
      before: top.before,
      after: change.after,
      selectionBefore: top.selectionBefore,
      selectionAfter: change.selectionAfter,
      description: top.description,
      changeSummary: DocumentChangeSummary.merge(
        top.changeSummary,
        change.changeSummary,
      ),
    );
    _undoStack.add(merged);
    _estimatedRetainedBytes += _entryBytes(merged);
    _clearRedo();
    _trimUndoBudget();
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
    _estimatedRetainedBytes = 0;
  }

  int _entryBytes(ChangeSet change) {
    return 192 + change.changeSummary.estimatedChangedBytes;
  }

  void _clearRedo() {
    for (final change in _redoStack) {
      _estimatedRetainedBytes -= _entryBytes(change);
    }
    _redoStack.clear();
  }

  void _trimUndoBudget() {
    while (_undoStack.length > 1 &&
        (_undoStack.length > limit ||
            _estimatedRetainedBytes > maxEstimatedBytes)) {
      final removed = _undoStack.removeAt(0);
      _estimatedRetainedBytes -= _entryBytes(removed);
    }
  }
}

import '../../history/history_manager.dart';
import '../model/persistent_block_list.dart';
import '../position/document_position.dart';
import '../transaction/change_set.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';

class CommandExecutor {
  CommandExecutor(this.session);

  final DocumentSession session;
  final List<CommandMiddleware> middlewares = <CommandMiddleware>[];
  EditorCommand? _lastCommand;
  DocumentSelection? _lastSelectionAfter;

  HistoryManager get history => session.history;

  ChangeSet execute(EditorCommand command) {
    // before-hooks may short-circuit the command by returning a change.
    for (final middleware in middlewares) {
      final override = middleware.before(command, session);
      if (override != null) {
        session.document = override.after;
        session.selection = override.selectionAfter;
        _runAfterHooks(override);
        _lastCommand = null;
        _lastSelectionAfter = null;
        return override;
      }
    }

    final before = session.document;
    final selectionBefore = session.selection;
    final result = command.execute(session);
    if (result.selection != null) {
      session.selection = result.selection;
    }
    // Enforce the document schema after every command so outputs are always
    // well-formed (non-empty, cells non-empty, attrs consistent with type).
    final normalized = session.schema.normalize(session.document);
    session.document = normalized.blocks is PersistentBlockList
        ? normalized
        : normalized.asPersistentSnapshot();
    final after = session.document;
    final change = ChangeSet(
      before: before,
      after: after,
      selectionBefore: selectionBefore,
      selectionAfter: session.selection,
      description: command.description,
      metadata: result.metadata,
      changeSummary: DocumentChangeSummary.between(
        before,
        after,
        documentChanged: !identical(before, after),
      ),
    );
    if (result.recordHistory) {
      final canMerge = _lastCommand != null &&
          command.canMergeWith(_lastCommand!) &&
          _isContiguous(selectionBefore);
      if (canMerge) {
        history.merge(change);
      } else {
        history.push(change);
      }
    }
    // Commands that move the caret (even without recording history) must break
    // an in-progress coalesce run, otherwise typing after moving the caret
    // would merge with text typed before the move.
    if (command.breaksMergeRun) {
      _lastCommand = null;
      _lastSelectionAfter = null;
    } else {
      _lastCommand = command;
      _lastSelectionAfter = session.selection;
    }
    _runAfterHooks(change);
    return change;
  }

  void _runAfterHooks(ChangeSet change) {
    for (final middleware in middlewares) {
      middleware.after(change, session);
    }
  }

  /// Whether the new command's [selectionBefore] (the caret state when the
  /// command started) matches where the previous merged command left the caret.
  /// Non-contiguous edits never coalesce even if [canMergeWith] is true.
  bool _isContiguous(DocumentSelection? selectionBefore) {
    final last = _lastSelectionAfter;
    if (last == null) {
      return false;
    }
    // The new command must start with a collapsed caret at the exact position
    // the previous command ended. A non-collapsed selection (e.g. after a
    // select-drag) breaks the run.
    if (selectionBefore == null || !selectionBefore.isCollapsed) {
      return false;
    }
    return selectionBefore.extent == last.extent;
  }

  EditorCommand? get lastCommand => _lastCommand;
}

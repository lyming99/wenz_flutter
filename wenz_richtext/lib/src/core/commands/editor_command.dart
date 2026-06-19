import '../position/document_position.dart';
import '../transaction/change_set.dart';
import '../transaction/document_session.dart';

class CommandResult {
  const CommandResult({
    this.selection,
    this.recordHistory = true,
    this.metadata,
  });

  final DocumentSelection? selection;
  final bool recordHistory;

  /// Optional metadata a command may report to [CommandMiddleware.after]
  /// hooks (e.g. dirty block ids, command kind). Additive; `null` by default.
  final Map<String, Object?>? metadata;
}

abstract class EditorCommand {
  const EditorCommand();

  String get description;

  CommandResult execute(DocumentSession session);

  /// Whether this command can be coalesced with [previous] into a single undo
  /// step. Default is `false`; commands opt in by overriding.
  bool canMergeWith(EditorCommand previous) => false;

  /// Whether executing this command must break the current coalesce run even
  /// when it records no history. Caret-movement commands return `true` so that
  /// typing after a move does not merge with text typed before the move.
  bool get breaksMergeRun => false;
}

/// Intercepts command execution. Registered on [CommandExecutor], a middleware
/// runs for every command without modifying the core executor.
///
/// - [before] may validate, enforce policy, rewrite by executing another path,
///   or return a non-null [ChangeSet] to **short-circuit** the command. Returning
///   `null` lets the command proceed.
/// - [after] observes the committed [change] after schema normalisation; it
///   receives [ChangeSet.metadata] from the command result and cannot alter the
///   document.
abstract class CommandMiddleware {
  const CommandMiddleware();

  ChangeSet? before(EditorCommand command, DocumentSession session) => null;

  void after(ChangeSet change, DocumentSession session) {}
}

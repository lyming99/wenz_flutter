import '../../history/history_manager.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../schema/document_schema.dart';

class DocumentSession {
  DocumentSession({
    RichTextDocument? document,
    this.selection,
    HistoryManager? history,
    this.schema = const DocumentSchema(),
  })  : document = schema.normalize(document ?? const RichTextDocument()),
        history = history ?? HistoryManager();

  final DocumentSchema schema;

  RichTextDocument document;
  DocumentSelection? selection;
  final HistoryManager history;

  bool get canUndo => history.canUndo;

  bool get canRedo => history.canRedo;

  void replaceDocument(
    RichTextDocument nextDocument, {
    DocumentSelection? nextSelection,
  }) {
    document = schema.normalize(nextDocument);
    selection = nextSelection;
  }

  bool undo() {
    final change = history.undo();
    if (change == null) {
      return false;
    }
    document = change.before.copy();
    selection = change.selectionBefore;
    return true;
  }

  bool redo() {
    final change = history.redo();
    if (change == null) {
      return false;
    }
    document = change.after.copy();
    selection = change.selectionAfter;
    return true;
  }
}

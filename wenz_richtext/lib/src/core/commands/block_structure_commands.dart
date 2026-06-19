import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';

/// Adjusts the [BlockAttributes.indent] of every text block covered by the
/// current selection by [delta] (clamped to >= 0 and the schema max). Stage 3
/// uses indent for both paragraph indentation and quote nesting depth.
class IndentCommand extends EditorCommand {
  const IndentCommand(this.delta, {this.selection});

  final int delta;
  final DocumentSelection? selection;

  @override
  String get description => delta > 0 ? 'indent' : 'outdent';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null || delta == 0) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    var changed = false;
    for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      final current = block.attributes.indent ?? 0;
      final next = (current + delta).clamp(0, 8).toInt();
      if (next == current) {
        continue;
      }
      blocks[i] = TextBlockNode(
        id: block.id,
        type: block.type,
        attributes: BlockAttributes(
          level: block.attributes.level,
          indent: next,
          alignment: block.attributes.alignment,
          listType: block.attributes.listType,
          checked: block.attributes.checked,
          childNote: block.attributes.childNote,
        ),
        content: block.content,
      );
      changed = true;
    }
    if (!changed) {
      return const CommandResult(recordHistory: false);
    }
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }
}

/// Toggles the checked state of a task list item at the caret. If the block is
/// not a task list item, converts it to one first.
class ToggleTodoCommand extends EditorCommand {
  const ToggleTodoCommand({this.selection});

  final DocumentSelection? selection;

  @override
  String get description => 'toggleTodo';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    var changed = false;
    for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      final isTask = block.type == BlockType.listItem &&
          block.attributes.listType == 'task';
      if (isTask) {
        blocks[i] = _withChecked(block, !(block.attributes.checked ?? false));
      } else {
        blocks[i] = TextBlockNode(
          id: block.id,
          type: BlockType.listItem,
          attributes: BlockAttributes(
            indent: block.attributes.indent,
            alignment: block.attributes.alignment,
            listType: 'task',
            checked: false,
            childNote: block.attributes.childNote,
          ),
          content: block.content,
        );
      }
      changed = true;
    }
    if (!changed) {
      return const CommandResult(recordHistory: false);
    }
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }

  TextBlockNode _withChecked(TextBlockNode block, bool checked) {
    return TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: BlockAttributes(
        level: block.attributes.level,
        indent: block.attributes.indent,
        alignment: block.attributes.alignment,
        listType: block.attributes.listType,
        checked: checked,
        childNote: block.attributes.childNote,
      ),
      content: block.content,
    );
  }
}

/// Sets the [CodeBlockNode.language] of the code block at the caret.
class SetCodeLanguageCommand extends EditorCommand {
  const SetCodeLanguageCommand(this.language, {this.blockIndex});

  final String language;
  final int? blockIndex;

  @override
  String get description => 'setCodeLanguage';

  @override
  CommandResult execute(DocumentSession session) {
    final index = blockIndex ?? session.selection?.extent.blockIndex ?? -1;
    if (index < 0 || index >= session.document.blocks.length) {
      return const CommandResult(recordHistory: false);
    }
    final block = session.document.blocks[index];
    if (block is! CodeBlockNode || block.language == language) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[index] = CodeBlockNode(
      id: block.id,
      code: block.code,
      language: language,
      attributes: block.attributes,
    );
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return const CommandResult(recordHistory: false);
  }
}

/// Toggles the quote type of the block at the caret: a non-quote becomes a
/// quote, a quote becomes a paragraph. Quote nesting depth uses indent.
class ToggleQuoteCommand extends EditorCommand {
  const ToggleQuoteCommand({this.selection});

  final DocumentSelection? selection;

  @override
  String get description => 'toggleQuote';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    var changed = false;
    for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      blocks[i] = block.type == BlockType.quote
          ? _convert(block, BlockType.paragraph)
          : _convert(block, BlockType.quote);
      changed = true;
    }
    if (!changed) {
      return const CommandResult(recordHistory: false);
    }
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }

  TextBlockNode _convert(TextBlockNode block, BlockType type) {
    return TextBlockNode(
      id: block.id,
      type: type,
      attributes: BlockAttributes(
        indent: block.attributes.indent,
        alignment: block.attributes.alignment,
        childNote: block.attributes.childNote,
      ),
      content: block.content,
    );
  }
}

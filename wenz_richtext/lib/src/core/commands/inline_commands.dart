import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';
import 'inline_editing.dart';
import 'style_commands.dart';
import 'table_cell_editing.dart';
import 'text_commands.dart';

/// Sets (or replaces) the link URL on the current selection's text runs. Pass
/// `null` to clear the link — unlike [FormatTextCommand], this can remove a
/// URL because it rewrites the affected runs directly.
class SetLinkCommand extends EditorCommand {
  const SetLinkCommand(this.url, {this.selection});

  final String? url;
  final DocumentSelection? selection;

  @override
  String get description => url == null ? 'clearLink' : 'setLink';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    final start = target.start;
    final end = target.end;
    if (start.blockIndex != end.blockIndex || start.path != end.path) {
      return const CommandResult(recordHistory: false);
    }
    final block = _blockAt(session.document, start.blockIndex);
    // Table cell selection: route to the cell-aware link rewrite, which edits
    // the cell's first text block via replaceCellTextBlock (the block here is a
    // TableBlockNode and would otherwise short-circuit on the guard below).
    if (start.path.isTableCellText && block is TableBlockNode) {
      final rowIndex = start.path.tableRowIndex;
      final columnIndex = start.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return setTableCellLinkRange(
        session,
        start.blockIndex,
        rowIndex,
        columnIndex,
        start.offset,
        end.offset,
        url,
      );
    }
    if (block is! TextBlockNode) {
      return const CommandResult(recordHistory: false);
    }
    final nextContent = withUrl(
      block.content,
      start.offset,
      end.offset,
      url,
    );
    final nextBlock = TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: block.attributes,
      content: nextContent,
    );
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[start.blockIndex] = nextBlock;
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }
}

/// Toggles a boolean text mark (bold/italic/underline/lineThrough/remark) on
/// the current selection: if any run in the range has the mark set, the whole
/// range is cleared of it; otherwise it is applied.
class ToggleMarkCommand extends EditorCommand {
  const ToggleMarkCommand(this.mark, {this.selection});

  final TextMark mark;
  final DocumentSelection? selection;

  @override
  String get description => 'toggleMark:${mark.name}';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    final start = target.start;
    final end = target.end;
    if (start.blockIndex != end.blockIndex || start.path != end.path) {
      return const CommandResult(recordHistory: false);
    }
    final block = _blockAt(session.document, start.blockIndex);
    // Table cell selection: toggle the mark inside the cell's first text block
    // (the block here is a TableBlockNode and would otherwise short-circuit on
    // the guard below).
    if (start.path.isTableCellText && block is TableBlockNode) {
      final rowIndex = start.path.tableRowIndex;
      final columnIndex = start.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return toggleTableCellMark(
        session,
        start.blockIndex,
        rowIndex,
        columnIndex,
        start.offset,
        end.offset,
        mark,
      );
    }
    if (block is! TextBlockNode) {
      return const CommandResult(recordHistory: false);
    }
    final currentlyOn = anyRunHasMark(
      block.content,
      start.offset,
      end.offset,
      mark,
    );
    if (currentlyOn) {
      // Clear the mark across the range. FormatTextCommand can't unset a bool,
      // so rewrite the runs directly.
      final nextContent = clearMark(
        block.content,
        start.offset,
        end.offset,
        mark,
      );
      final nextBlock = TextBlockNode(
        id: block.id,
        type: block.type,
        attributes: block.attributes,
        content: nextContent,
      );
      final blocks = session.document.blocks.map((b) => b.copy()).toList();
      blocks[start.blockIndex] = nextBlock;
      session.document = RichTextDocument(
        version: session.document.version,
        blocks: blocks,
      );
    } else {
      final attrs = markAttributes(mark);
      session.selection = target;
      FormatTextCommand(attributes: attrs, selection: target).execute(session);
      session.selection = target;
    }
    return CommandResult(selection: target);
  }
}

// TextMark + the mark helpers (markAttributes / anyRunHasMark / clearMark /
// withoutMark) live in inline_editing.dart so both this file and
// table_cell_editing.dart can reuse them without a circular import. They are
// imported below and re-exported via the barrel file.

/// Inserts an inline embed (formula / mention / image) at the caret. If the
/// selection is non-collapsed the range is deleted first. The caret moves past
/// the inserted embed.
class InsertInlineEmbedCommand extends EditorCommand {
  const InsertInlineEmbedCommand({
    required this.embedType,
    this.data = const <String, Object?>{},
    this.selection,
  });

  final String embedType;
  final Map<String, Object?> data;
  final DocumentSelection? selection;

  @override
  String get description => 'insertInlineEmbed:$embedType';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    if (!target.isCollapsed) {
      final deleteResult =
          DeleteSelectionCommand(target).execute(session);
      if (deleteResult.selection != null) {
        session.selection = deleteResult.selection;
      }
    }
    final position = session.selection!.extent;
    final block = _blockAt(session.document, position.blockIndex);
    // Table cell caret: route to the cell-aware embed insertion (the block here
    // is a TableBlockNode and would otherwise short-circuit on the guard below).
    if (position.path.isTableCellText && block is TableBlockNode) {
      final rowIndex = position.path.tableRowIndex;
      final columnIndex = position.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return insertTableCellInlineEmbed(
        session,
        position.blockIndex,
        rowIndex,
        columnIndex,
        position.offset,
        embedType,
        data,
      );
    }
    if (block is! TextBlockNode) {
      return const CommandResult(recordHistory: false);
    }
    final embed = InlineEmbed(embedType: embedType, data: data);
    final nextContent = insertInline(
      block.content,
      position.offset,
      // Embeds render as a single placeholder char.
      embed.plainText,
      const TextAttributes(),
    );
    // Replace the inserted placeholder text run with the actual embed.
    final cleaned = replacePlaceholderWithEmbed(
      nextContent,
      position.offset,
      embed,
    );
    final nextBlock = TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: block.attributes,
      content: cleaned,
    );
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[position.blockIndex] = nextBlock;
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    final nextPosition = position.copyWith(offset: position.offset + 1);
    return CommandResult(
      selection: DocumentSelection(base: nextPosition, extent: nextPosition),
    );
  }
}

// replacePlaceholderWithEmbed and withUrl live in inline_editing.dart so both
// inline_commands.dart and table_cell_editing.dart can reuse them without a
// circular import.

BlockNode? _blockAt(RichTextDocument document, int index) {
  if (index < 0 || index >= document.blocks.length) {
    return null;
  }
  return document.blocks[index];
}

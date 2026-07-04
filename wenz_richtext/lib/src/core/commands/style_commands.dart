import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';
import 'inline_editing.dart';
import 'table_cell_editing.dart';

class FormatTextCommand extends EditorCommand {
  const FormatTextCommand({required this.attributes, this.selection});

  final TextAttributes attributes;
  final DocumentSelection? selection;

  @override
  String get description => 'formatText';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null || target.isCollapsed || attributes.isEmpty) {
      return const CommandResult(recordHistory: false);
    }

    final start = target.start;
    final end = target.end;
    // Table cell selection: route to the cell-aware formatter, which edits the
    // cell's first text block via replaceCellTextBlock (the loop below only
    // handles top-level TextBlockNode blocks and would skip the table block).
    if (start.path.isTableCellText &&
        start.blockIndex == end.blockIndex &&
        start.path == end.path) {
      final rowIndex = start.path.tableRowIndex;
      final columnIndex = start.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return formatTableCellInlineRange(
        session,
        start.blockIndex,
        rowIndex,
        columnIndex,
        start.offset,
        end.offset,
        attributes,
      );
    }

    final blocks =
        session.document.blocks.map((block) => block.copy()).toList();
    var changed = false;

    for (var i = start.blockIndex; i <= end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      final rangeStart = i == start.blockIndex ? start.offset : 0;
      final rangeEnd =
          i == end.blockIndex ? end.offset : inlineNodesLength(block.content);
      blocks[i] = TextBlockNode(
        id: block.id,
        type: block.type,
        attributes: block.attributes,
        content: formatInline(block.content, rangeStart, rangeEnd, attributes),
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

class ClearStyleCommand extends EditorCommand {
  const ClearStyleCommand({this.selection});

  final DocumentSelection? selection;

  @override
  String get description => 'clearStyle';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null || target.isCollapsed) {
      return const CommandResult(recordHistory: false);
    }

    final start = target.start;
    final end = target.end;
    // Table cell selection: route to the cell-aware clear, which edits the
    // cell's first text block via replaceCellTextBlock.
    if (start.path.isTableCellText &&
        start.blockIndex == end.blockIndex &&
        start.path == end.path) {
      final rowIndex = start.path.tableRowIndex;
      final columnIndex = start.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return clearTableCellInlineStyle(
        session,
        start.blockIndex,
        rowIndex,
        columnIndex,
        start.offset,
        end.offset,
      );
    }

    final blocks =
        session.document.blocks.map((block) => block.copy()).toList();
    var changed = false;
    for (var i = start.blockIndex; i <= end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      final rangeStart = i == start.blockIndex ? start.offset : 0;
      final rangeEnd =
          i == end.blockIndex ? end.offset : inlineNodesLength(block.content);
      blocks[i] = TextBlockNode(
        id: block.id,
        type: block.type,
        attributes: block.attributes,
        content: clearInlineFormatting(block.content, rangeStart, rangeEnd),
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

class ClearTextColorCommand extends EditorCommand {
  const ClearTextColorCommand({this.selection});

  final DocumentSelection? selection;

  @override
  String get description => 'clearTextColor';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null || target.isCollapsed) {
      return const CommandResult(recordHistory: false);
    }

    final start = target.start;
    final end = target.end;
    if (start.path.isTableCellText &&
        start.blockIndex == end.blockIndex &&
        start.path == end.path) {
      final rowIndex = start.path.tableRowIndex;
      final columnIndex = start.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return clearTableCellInlineTextColor(
        session,
        start.blockIndex,
        rowIndex,
        columnIndex,
        start.offset,
        end.offset,
      );
    }

    final blocks =
        session.document.blocks.map((block) => block.copy()).toList();
    var changed = false;
    for (var i = start.blockIndex; i <= end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      final rangeStart = i == start.blockIndex ? start.offset : 0;
      final rangeEnd =
          i == end.blockIndex ? end.offset : inlineNodesLength(block.content);
      blocks[i] = TextBlockNode(
        id: block.id,
        type: block.type,
        attributes: block.attributes,
        content: clearInlineTextColor(block.content, rangeStart, rangeEnd),
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

class SetBlockTypeCommand extends EditorCommand {
  const SetBlockTypeCommand({
    required this.type,
    this.selection,
    this.level,
    this.listType,
    this.checked,
  });

  final BlockType type;
  final DocumentSelection? selection;
  final int? level;
  final String? listType;
  final bool? checked;

  @override
  String get description => 'setBlockType';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null || !_isTextBlockType(type)) {
      return const CommandResult(recordHistory: false);
    }

    final blocks =
        session.document.blocks.map((block) => block.copy()).toList();
    var changed = false;
    for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length || blocks[i] is! TextBlockNode) {
        continue;
      }
      final block = blocks[i] as TextBlockNode;
      final nextType = type == BlockType.quote
          ? (block.type == BlockType.quote ? BlockType.paragraph : block.type)
          : type;
      blocks[i] = TextBlockNode(
        id: block.id,
        type: nextType,
        attributes: _attributesForType(block.attributes),
        content: block.content.map((node) => node.copy()).toList(),
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

  BlockAttributes _attributesForType(BlockAttributes current) {
    if (type == BlockType.quote) {
      return BlockAttributes(
        level: current.level,
        indent: current.indent,
        alignment: current.alignment,
        listType: current.listType,
        checked: current.checked,
        quoted: true,
        childNote: current.childNote,
        anchor: current.anchor,
      );
    }
    return BlockAttributes(
      level: type == BlockType.heading ? level ?? current.level ?? 1 : null,
      indent: current.indent,
      alignment: current.alignment,
      listType: type == BlockType.listItem ? listType : null,
      checked: type == BlockType.listItem ? _checkedForListType(current) : null,
      quoted: current.quoted,
      childNote: current.childNote,
      anchor: current.anchor,
    );
  }

  bool? _checkedForListType(BlockAttributes current) {
    if (checked != null) {
      return checked;
    }
    if (listType == 'check' || listType == 'task') {
      return current.checked ?? false;
    }
    if (listType == 'ordered') {
      return current.checked;
    }
    return null;
  }
}

class SetAlignmentCommand extends EditorCommand {
  const SetAlignmentCommand({required this.alignment, this.selection});

  final String? alignment;
  final DocumentSelection? selection;

  @override
  String get description => 'setAlignment';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    if (target.tableCellRange != null) {
      return const CommandResult(recordHistory: false);
    }

    final blocks =
        session.document.blocks.map((block) => block.copy()).toList();
    var changed = false;
    var hasTargetBlock = false;
    for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      hasTargetBlock = true;
      final nextAttributes = _setAlignment(blocks[i].attributes, alignment);
      if (nextAttributes == blocks[i].attributes) {
        continue;
      }
      blocks[i] = _copyBlockWithAttributes(
        blocks[i],
        nextAttributes,
      );
      changed = true;
    }

    if (!changed) {
      return CommandResult(
        selection: hasTargetBlock ? target : null,
        recordHistory: false,
      );
    }
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }
}

bool _isTextBlockType(BlockType type) {
  return type == BlockType.paragraph ||
      type == BlockType.heading ||
      type == BlockType.quote ||
      type == BlockType.listItem;
}

BlockAttributes _setAlignment(BlockAttributes current, String? alignment) {
  return BlockAttributes(
    level: current.level,
    indent: current.indent,
    alignment: alignment,
    listType: current.listType,
    checked: current.checked,
    quoted: current.quoted,
    childNote: current.childNote,
    anchor: current.anchor,
  );
}

BlockNode _copyBlockWithAttributes(
  BlockNode block,
  BlockAttributes attributes,
) {
  final json = Map<String, Object?>.from(block.toJson());
  if (attributes.isEmpty) {
    json.remove('attrs');
  } else {
    json['attrs'] = attributes.toJson();
  }
  return BlockNode.fromJson(json);
}

import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';
import 'inline_editing.dart';

/// Applies block-level Markdown shortcuts at the caret.
///
/// The command expects the triggering marker to be at the start of the current
/// text block. For example, after the user types `# `, the command removes the
/// marker and converts the block to a level-1 heading.
class ApplyMarkdownShortcutCommand extends EditorCommand {
  const ApplyMarkdownShortcutCommand();

  @override
  String get description => 'applyMarkdownShortcut';

  @override
  CommandResult execute(DocumentSession session) {
    final selection = session.selection;
    if (selection == null || !selection.isCollapsed) {
      return const CommandResult(recordHistory: false);
    }
    final position = selection.extent;
    if (!position.path.isBlockText) {
      return const CommandResult(recordHistory: false);
    }
    final block = _blockAt(session.document, position.blockIndex);
    if (block is! TextBlockNode) {
      return const CommandResult(recordHistory: false);
    }
    final offset =
        position.offset.clamp(0, inlineNodesLength(block.content)).toInt();
    final prefix = block.plainText.substring(0, offset);
    final shortcut = _matchShortcut(block, prefix);
    if (shortcut == null) {
      return const CommandResult(recordHistory: false);
    }

    final split = splitInline(block.content, offset);
    return switch (shortcut.kind) {
      _ShortcutKind.heading => _replaceTextBlock(
          session,
          block,
          position.blockIndex,
          BlockType.heading,
          _headingAttributes(block.attributes, shortcut.level),
          split.after,
        ),
      _ShortcutKind.quote => _replaceTextBlock(
          session,
          block,
          position.blockIndex,
          BlockType.quote,
          _simpleTextAttributes(block.attributes),
          split.after,
        ),
      _ShortcutKind.unorderedList => _replaceTextBlock(
          session,
          block,
          position.blockIndex,
          BlockType.listItem,
          _listAttributes(block.attributes, null, false),
          split.after,
        ),
      _ShortcutKind.orderedList => _replaceTextBlock(
          session,
          block,
          position.blockIndex,
          BlockType.listItem,
          _listAttributes(block.attributes, 'ordered', false),
          split.after,
        ),
      _ShortcutKind.taskList => _replaceTextBlock(
          session,
          block,
          position.blockIndex,
          BlockType.listItem,
          _listAttributes(block.attributes, 'task', shortcut.checked),
          split.after,
        ),
      _ShortcutKind.codeBlock => _replaceWithCodeBlock(
          session,
          block,
          position.blockIndex,
          split.after,
        ),
      _ShortcutKind.divider => _replaceWithDivider(
          session,
          block,
          position.blockIndex,
          split.after,
        ),
    };
  }
}

_Shortcut? _matchShortcut(TextBlockNode block, String prefix) {
  if (block.type == BlockType.paragraph) {
    final heading = RegExp(r'^(#{1,6}) $').firstMatch(prefix);
    if (heading != null) {
      return _Shortcut.heading(heading.group(1)!.length);
    }
    final ordered = RegExp(r'^\d+\. $').firstMatch(prefix);
    if (ordered != null) {
      return const _Shortcut(_ShortcutKind.orderedList);
    }
    switch (prefix) {
      case '- [ ] ':
        return const _Shortcut(_ShortcutKind.taskList, checked: false);
      case '- [x] ':
      case '- [X] ':
        return const _Shortcut(_ShortcutKind.taskList, checked: true);
      case '- ':
      case '* ':
        return const _Shortcut(_ShortcutKind.unorderedList);
      case '> ':
        return const _Shortcut(_ShortcutKind.quote);
      case '```':
        return const _Shortcut(_ShortcutKind.codeBlock);
      case '---':
        return const _Shortcut(_ShortcutKind.divider);
    }
  }
  if (block.type == BlockType.listItem && block.attributes.listType != 'task') {
    switch (prefix) {
      case '[ ] ':
        return const _Shortcut(_ShortcutKind.taskList, checked: false);
      case '[x] ':
      case '[X] ':
        return const _Shortcut(_ShortcutKind.taskList, checked: true);
    }
  }
  return null;
}

CommandResult _replaceTextBlock(
  DocumentSession session,
  TextBlockNode block,
  int blockIndex,
  BlockType type,
  BlockAttributes attributes,
  List<InlineNode> content,
) {
  final nextBlock = TextBlockNode(
    id: block.id,
    type: type,
    attributes: attributes,
    content: content.map((node) => node.copy()).toList(),
  );
  _replaceBlocks(session, blockIndex, 1, <BlockNode>[nextBlock]);
  final position = DocumentPosition.text(
    blockId: nextBlock.id,
    blockIndex: blockIndex,
    offset: 0,
  );
  return CommandResult(
    selection: DocumentSelection(base: position, extent: position),
  );
}

CommandResult _replaceWithCodeBlock(
  DocumentSession session,
  TextBlockNode block,
  int blockIndex,
  List<InlineNode> content,
) {
  final nextBlock = CodeBlockNode(
    id: block.id,
    code: content.map((node) => node.plainText).join(),
  );
  _replaceBlocks(session, blockIndex, 1, <BlockNode>[nextBlock]);
  final position = DocumentPosition.code(
    blockId: nextBlock.id,
    blockIndex: blockIndex,
    offset: 0,
  );
  return CommandResult(
    selection: DocumentSelection(base: position, extent: position),
  );
}

CommandResult _replaceWithDivider(
  DocumentSession session,
  TextBlockNode block,
  int blockIndex,
  List<InlineNode> trailingContent,
) {
  final nextBlocks = <BlockNode>[
    DividerBlockNode(id: block.id, attributes: block.attributes),
    TextBlockNode(
      id: _uniqueBlockId(session.document, '${block.id}-after'),
      type: BlockType.paragraph,
      attributes: _simpleTextAttributes(block.attributes),
      content: trailingContent.map((node) => node.copy()).toList(),
    ),
  ];
  _replaceBlocks(session, blockIndex, 1, nextBlocks);
  final position = DocumentPosition.text(
    blockId: nextBlocks[1].id,
    blockIndex: blockIndex + 1,
    offset: 0,
  );
  return CommandResult(
    selection: DocumentSelection(base: position, extent: position),
  );
}

BlockAttributes _headingAttributes(BlockAttributes current, int level) {
  return BlockAttributes(
    level: level,
    indent: current.indent,
    alignment: current.alignment,
    childNote: current.childNote,
  );
}

BlockAttributes _simpleTextAttributes(BlockAttributes current) {
  return BlockAttributes(
    indent: current.indent,
    alignment: current.alignment,
    childNote: current.childNote,
  );
}

BlockAttributes _listAttributes(
  BlockAttributes current,
  String? listType,
  bool checked,
) {
  return BlockAttributes(
    indent: current.indent,
    alignment: current.alignment,
    listType: listType,
    checked: listType == 'task' ? checked : null,
    childNote: current.childNote,
  );
}

BlockNode? _blockAt(RichTextDocument document, int index) {
  if (index < 0 || index >= document.blocks.length) {
    return null;
  }
  return document.blocks[index];
}

void _replaceBlocks(
  DocumentSession session,
  int index,
  int deleteCount,
  List<BlockNode> nextBlocks,
) {
  final blocks = <BlockNode>[
    for (var i = 0; i < index; i++) session.document.blocks[i].copy(),
    ...nextBlocks.map((block) => block.copy()),
    for (var i = index + deleteCount; i < session.document.blocks.length; i++)
      session.document.blocks[i].copy(),
  ];
  session.document = RichTextDocument(
    version: session.document.version,
    blocks: blocks,
  );
}

String _uniqueBlockId(RichTextDocument document, String seed) {
  final ids = document.blocks.map((block) => block.id).toSet();
  if (!ids.contains(seed)) {
    return seed;
  }
  var index = 1;
  while (ids.contains('$seed-$index')) {
    index += 1;
  }
  return '$seed-$index';
}

enum _ShortcutKind {
  heading,
  quote,
  unorderedList,
  orderedList,
  taskList,
  codeBlock,
  divider,
}

class _Shortcut {
  const _Shortcut(this.kind, {this.level = 1, this.checked = false});

  const _Shortcut.heading(int level)
      : this(_ShortcutKind.heading, level: level);

  final _ShortcutKind kind;
  final int level;
  final bool checked;
}

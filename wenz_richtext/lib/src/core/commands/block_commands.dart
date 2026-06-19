import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';
import 'inline_editing.dart';
import 'table_cell_editing.dart';
import 'text_commands.dart';

class InsertBlocksCommand extends EditorCommand {
  const InsertBlocksCommand({
    required this.index,
    required this.blocks,
    this.selection,
  });

  final int index;
  final List<BlockNode> blocks;
  final DocumentSelection? selection;

  @override
  String get description => 'insertBlocks';

  @override
  CommandResult execute(DocumentSession session) {
    if (blocks.isEmpty) {
      return const CommandResult(recordHistory: false);
    }
    final insertIndex = index.clamp(0, session.document.blocks.length).toInt();
    final nextBlocks = <BlockNode>[
      for (var i = 0; i < insertIndex; i++) session.document.blocks[i].copy(),
      ...blocks.map((block) => block.copy()),
      for (var i = insertIndex; i < session.document.blocks.length; i++)
        session.document.blocks[i].copy(),
    ];
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: nextBlocks,
    );
    return CommandResult(selection: selection);
  }
}

class ReplaceBlocksCommand extends EditorCommand {
  const ReplaceBlocksCommand({
    required this.index,
    required this.deleteCount,
    required this.blocks,
    this.selection,
  });

  final int index;
  final int deleteCount;
  final List<BlockNode> blocks;
  final DocumentSelection? selection;

  @override
  String get description => 'replaceBlocks';

  @override
  CommandResult execute(DocumentSession session) {
    if (index < 0 || index > session.document.blocks.length) {
      return const CommandResult(recordHistory: false);
    }
    final safeDeleteCount =
        deleteCount.clamp(0, session.document.blocks.length - index).toInt();
    final nextBlocks = <BlockNode>[
      for (var i = 0; i < index; i++) session.document.blocks[i].copy(),
      ...blocks.map((block) => block.copy()),
      for (var i = index + safeDeleteCount;
          i < session.document.blocks.length;
          i++)
        session.document.blocks[i].copy(),
    ];
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: nextBlocks,
    );
    return CommandResult(selection: selection);
  }
}

class EnterCommand extends EditorCommand {
  const EnterCommand({this.newBlockId});

  final String? newBlockId;

  @override
  String get description => 'enter';

  @override
  CommandResult execute(DocumentSession session) {
    if (session.selection == null) {
      return const CommandResult(recordHistory: false);
    }
    if (!session.selection!.isCollapsed) {
      final deleteResult = DeleteSelectionCommand(
        session.selection!,
      ).execute(session);
      if (deleteResult.selection != null) {
        session.selection = deleteResult.selection;
      }
    }

    final position = session.selection!.extent;
    if (position.path.isTableCellText) {
      final rowIndex = position.path.tableRowIndex;
      final columnIndex = position.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return insertTableCellInlineText(
        session,
        position.blockIndex,
        rowIndex,
        columnIndex,
        position.offset,
        '\n',
      );
    }
    if (position.blockIndex < 0 ||
        position.blockIndex >= session.document.blocks.length) {
      return const CommandResult(recordHistory: false);
    }

    final block = session.document.blocks[position.blockIndex];
    if (block is TextBlockNode) {
      return _splitTextBlock(session, block, position);
    }
    if (block is CodeBlockNode) {
      return _insertCodeNewline(session, block, position);
    }
    return _insertParagraphAfter(session, block, position);
  }

  CommandResult _splitTextBlock(
    DocumentSession session,
    TextBlockNode block,
    DocumentPosition position,
  ) {
    final split = splitInline(block.content, position.offset);
    final nextBlockId = newBlockId ?? '${block.id}-next';
    final before = TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: block.attributes,
      content: split.before,
    );
    final after = TextBlockNode(
      id: nextBlockId,
      type: block.type,
      attributes: block.attributes,
      content: split.after,
    );
    final nextSelectionPosition = DocumentPosition.text(
      blockId: nextBlockId,
      blockIndex: position.blockIndex + 1,
      offset: 0,
    );
    return ReplaceBlocksCommand(
      index: position.blockIndex,
      deleteCount: 1,
      blocks: <BlockNode>[before, after],
      selection: DocumentSelection(
        base: nextSelectionPosition,
        extent: nextSelectionPosition,
      ),
    ).execute(session);
  }

  CommandResult _insertCodeNewline(
    DocumentSession session,
    CodeBlockNode block,
    DocumentPosition position,
  ) {
    final offset = position.offset.clamp(0, block.code.length).toInt();
    final nextBlock = CodeBlockNode(
      id: block.id,
      code: block.code.replaceRange(offset, offset, '\n'),
      language: block.language,
      attributes: block.attributes,
    );
    final nextSelectionPosition = position.copyWith(offset: offset + 1);
    return ReplaceBlocksCommand(
      index: position.blockIndex,
      deleteCount: 1,
      blocks: <BlockNode>[nextBlock],
      selection: DocumentSelection(
        base: nextSelectionPosition,
        extent: nextSelectionPosition,
      ),
    ).execute(session);
  }

  CommandResult _insertParagraphAfter(
    DocumentSession session,
    BlockNode block,
    DocumentPosition position,
  ) {
    final nextBlockId = newBlockId ?? '${block.id}-next';
    final nextSelectionPosition = DocumentPosition.text(
      blockId: nextBlockId,
      blockIndex: position.blockIndex + 1,
      offset: 0,
    );
    return InsertBlocksCommand(
      index: position.blockIndex + 1,
      blocks: <BlockNode>[
        TextBlockNode(
          id: nextBlockId,
          type: BlockType.paragraph,
          content: const <InlineNode>[],
        ),
      ],
      selection: DocumentSelection(
        base: nextSelectionPosition,
        extent: nextSelectionPosition,
      ),
    ).execute(session);
  }
}

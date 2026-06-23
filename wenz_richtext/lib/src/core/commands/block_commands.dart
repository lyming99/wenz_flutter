import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/rich_text_document.dart';
import '../model/table_model.dart';
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

/// Pastes a slice of whole blocks ([pastedBlocks]) at the current selection.
///
/// Used by cross-block rich paste. Behaviour mirrors a typical rich-text
/// editor: the first pasted block's inline content merges into the caret's
/// current block (in front of the caret); the last pasted block's inline
/// content merges with the text that originally followed the caret; any
/// blocks in between are inserted as new blocks, preserving their type and
/// attributes.
///
/// Non-text pasted blocks (code/table/media) are inserted verbatim as new
/// blocks — they are not merged with the surrounding text blocks. When the
/// caret is inside a non-text block, the slice is inserted after that block
/// instead of being merged in.
class PasteBlocksCommand extends EditorCommand {
  const PasteBlocksCommand(this.pastedBlocks, {this.newBlockId});

  final List<BlockNode> pastedBlocks;
  final String? newBlockId;

  @override
  String get description => 'pasteBlocks';

  @override
  CommandResult execute(DocumentSession session) {
    if (pastedBlocks.isEmpty || session.selection == null) {
      return const CommandResult(recordHistory: false);
    }
    // Delete any active selection first so paste replaces it.
    if (!session.selection!.isCollapsed) {
      final deleteResult =
          DeleteSelectionCommand(session.selection!).execute(session);
      if (deleteResult.selection != null) {
        session.selection = deleteResult.selection;
      }
    }
    final position = session.selection!.extent;
    if (position.path.isTableCellText) {
      // Cell paste falls back to plain inline merge of the first text block;
      // block-structure paste inside a single cell is out of scope.
      final firstText = _firstInlineSlice(pastedBlocks);
      if (firstText != null) {
        final rowIndex = position.path.tableRowIndex!;
        final columnIndex = position.path.tableColumnIndex!;
        return insertTableCellInlineText(
          session,
          position.blockIndex,
          rowIndex,
          columnIndex,
          position.offset,
          firstText.map((node) => node.plainText).join(),
        );
      }
      return const CommandResult(recordHistory: false);
    }

    final idAllocator = _PasteIdAllocator(session.document, newBlockId);
    final pasteBlocks = _copyBlocksForPaste(pastedBlocks, idAllocator);
    final block = _blockAt(session.document, position.blockIndex);
    if (block is! TextBlockNode) {
      // Caret in a non-text block: insert the slice after it as new blocks.
      return InsertBlocksCommand(
        index: position.blockIndex + 1,
        blocks: pasteBlocks,
        selection: _endSelection(
          position.blockIndex + pasteBlocks.length,
          pasteBlocks.last,
        ),
      ).execute(session);
    }

    final split = splitInline(block.content, position.offset);
    final generatedId = idAllocator.unique(newBlockId ?? '${block.id}-paste');
    final rebuilt = <BlockNode>[];

    // First pasted block: merge its inline content into the caret's "before"
    // slice. Non-text first blocks are inserted as their own block.
    final firstPasted = pasteBlocks.first;
    if (firstPasted is TextBlockNode) {
      rebuilt.add(
        TextBlockNode(
          id: block.id,
          type: block.type,
          attributes: block.attributes,
          content: mergeTextRuns(<InlineNode>[
            ...split.before,
            ...firstPasted.content.map((node) => node.copy()),
          ]),
        ),
      );
    } else {
      rebuilt.add(
        TextBlockNode(
          id: block.id,
          type: block.type,
          attributes: block.attributes,
          content: split.before,
        ),
      );
      rebuilt.add(firstPasted.copy());
    }

    // Middle blocks: copy through verbatim.
    for (var i = 1; i < pasteBlocks.length - 1; i++) {
      rebuilt.add(pasteBlocks[i].copy());
    }

    // Last pasted block: merge its inline content with the caret's "after"
    // slice, preserving the pasted block's type/attributes when it differs.
    final caretOffsetAfterPaste = _endOffsetForMerge(
      split.before,
      pasteBlocks,
    );
    if (pasteBlocks.length == 1 && firstPasted is TextBlockNode) {
      // Single pasted text block: everything landed in the first rebuilt
      // block, append the caret's "after" slice to it.
      final merged = rebuilt.removeAt(0) as TextBlockNode;
      rebuilt.add(
        TextBlockNode(
          id: merged.id,
          type: merged.type,
          attributes: merged.attributes,
          content: mergeTextRuns(<InlineNode>[
            ...merged.content,
            ...split.after,
          ]),
        ),
      );
    } else {
      final lastPasted = pasteBlocks.last;
      if (lastPasted is TextBlockNode) {
        rebuilt.add(
          TextBlockNode(
            id: generatedId,
            type: lastPasted.type,
            attributes: lastPasted.attributes,
            content: mergeTextRuns(<InlineNode>[
              ...lastPasted.content.map((node) => node.copy()),
              ...split.after,
            ]),
          ),
        );
      } else {
        if (pasteBlocks.length > 1) {
          rebuilt.add(lastPasted.copy());
        }
        // Re-attach the caret's trailing text as its own paragraph so no text
        // is lost.
        rebuilt.add(
          TextBlockNode(
            id: generatedId,
            type: block.type,
            attributes: block.attributes,
            content: split.after,
          ),
        );
      }
    }

    final caretBlockIndex = position.blockIndex + rebuilt.length - 1;
    return ReplaceBlocksCommand(
      index: position.blockIndex,
      deleteCount: 1,
      blocks: rebuilt,
      selection: DocumentSelection(
        base: DocumentPosition.text(
          blockId: rebuilt.last.id,
          blockIndex: caretBlockIndex,
          offset: caretOffsetAfterPaste,
        ),
        extent: DocumentPosition.text(
          blockId: rebuilt.last.id,
          blockIndex: caretBlockIndex,
          offset: caretOffsetAfterPaste,
        ),
      ),
    ).execute(session);
  }

  /// Computes the caret offset inside the final rebuilt block after the merge.
  /// The caret lands at the end of the last pasted inline content (before the
  /// original "after" slice).
  int _endOffsetForMerge(List<InlineNode> beforeSlice, List<BlockNode> pasted) {
    final last = pasted.last;
    if (last is TextBlockNode) {
      return inlineNodesLength(last.content);
    }
    return 0;
  }

  DocumentSelection _endSelection(
    int blockIndexDelta,
    BlockNode last,
  ) {
    if (last is TextBlockNode) {
      final pos = DocumentPosition.text(
        blockId: last.id,
        blockIndex: blockIndexDelta,
        offset: inlineNodesLength(last.content),
      );
      return DocumentSelection(base: pos, extent: pos);
    }
    if (last is CodeBlockNode) {
      final pos = DocumentPosition.code(
        blockId: last.id,
        blockIndex: blockIndexDelta,
        offset: last.code.length,
      );
      return DocumentSelection(base: pos, extent: pos);
    }
    if (last is TableBlockNode) {
      final pos = _lastTableCellPosition(last, blockIndexDelta);
      if (pos != null) {
        return DocumentSelection(base: pos, extent: pos);
      }
    }
    final start = DocumentPosition(
      blockId: last.id,
      blockIndex: blockIndexDelta,
      path: PositionPath.blockObject(last.id),
      offset: 0,
    );
    final end = start.copyWith(offset: _kObjectSelectionLength);
    return DocumentSelection(base: start, extent: end);
  }

  List<InlineNode>? _firstInlineSlice(List<BlockNode> blocks) {
    final first = blocks.first;
    if (first is TextBlockNode) {
      return first.content.map((node) => node.copy()).toList();
    }
    return null;
  }
}

const int _kObjectSelectionLength = 1;

List<BlockNode> _copyBlocksForPaste(
  List<BlockNode> blocks,
  _PasteIdAllocator ids,
) {
  return blocks.map((block) => _copyBlockForPaste(block, ids)).toList();
}

BlockNode _copyBlockForPaste(BlockNode block, _PasteIdAllocator ids) {
  final id = ids.next();
  if (block is TextBlockNode) {
    return TextBlockNode(
      id: id,
      type: block.type,
      attributes: block.attributes,
      content: block.content.map((node) => node.copy()).toList(),
    );
  }
  if (block is CodeBlockNode) {
    return CodeBlockNode(
      id: id,
      code: block.code,
      language: block.language,
      attributes: block.attributes,
    );
  }
  if (block is ImageBlockNode) {
    return ImageBlockNode(
      id: id,
      assetId: block.assetId,
      file: block.file,
      width: block.width,
      height: block.height,
      showWidth: block.showWidth,
      showHeight: block.showHeight,
      attributes: block.attributes,
    );
  }
  if (block is TableBlockNode) {
    return TableBlockNode(
      id: id,
      table: _copyTableForPaste(block.table, ids),
      attributes: block.attributes,
    );
  }
  if (block is DividerBlockNode) {
    return DividerBlockNode(id: id, attributes: block.attributes);
  }
  if (block is VideoBlockNode) {
    return VideoBlockNode(
      id: id,
      assetId: block.assetId,
      file: block.file,
      attributes: block.attributes,
    );
  }
  if (block is CalloutBlockNode) {
    return CalloutBlockNode(
      id: id,
      content: block.content.map((node) => node.copy()).toList(),
      variant: block.variant,
      attributes: block.attributes,
    );
  }
  if (block is FileBlockNode) {
    return FileBlockNode(
      id: id,
      assetId: block.assetId,
      name: block.name,
      size: block.size,
      file: block.file,
      attributes: block.attributes,
    );
  }
  return block.copy();
}

TableModel _copyTableForPaste(TableModel table, _PasteIdAllocator ids) {
  return TableModel(
    rows: table.rows
        .map(
          (row) => row
              .map(
                (cell) => TableCellNode(
                  id: ids.next(),
                  blocks: _copyBlocksForPaste(cell.blocks, ids),
                  rowSpan: cell.rowSpan,
                  columnSpan: cell.columnSpan,
                  isHeader: cell.isHeader,
                  backgroundColor: cell.backgroundColor,
                  covered: cell.covered,
                ),
              )
              .toList(),
        )
        .toList(),
    columnAlignments: Map<int, String>.from(table.columnAlignments),
    columnWidths: Map<int, double>.from(table.columnWidths),
  );
}

DocumentPosition? _lastTableCellPosition(TableBlockNode block, int blockIndex) {
  for (var rowIndex = block.table.rows.length - 1; rowIndex >= 0; rowIndex--) {
    final row = block.table.rows[rowIndex];
    for (var columnIndex = row.length - 1; columnIndex >= 0; columnIndex--) {
      final cell = row[columnIndex];
      if (cell.covered) {
        continue;
      }
      return DocumentPosition.tableCell(
        tableBlockId: block.id,
        blockIndex: blockIndex,
        tableRowIndex: rowIndex,
        tableColumnIndex: columnIndex,
        offset: inlineNodesLength(cellTextBlock(cell).content),
      );
    }
  }
  return null;
}

class _PasteIdAllocator {
  _PasteIdAllocator(RichTextDocument document, String? base)
      : _base = (base == null || base.isEmpty) ? 'paste' : base {
    for (final block in document.blocks) {
      _collectBlockIds(block);
    }
  }

  final String _base;
  final Set<String> _used = <String>{};
  var _counter = 0;

  String next() {
    return unique('$_base-${_counter++}');
  }

  String unique(String preferred) {
    final base = preferred.isEmpty ? '$_base-${_counter++}' : preferred;
    var candidate = base;
    var suffix = 1;
    while (_used.contains(candidate)) {
      candidate = '$base-${suffix++}';
    }
    _used.add(candidate);
    return candidate;
  }

  void _collectBlockIds(BlockNode block) {
    _used.add(block.id);
    if (block is TableBlockNode) {
      for (final row in block.table.rows) {
        for (final cell in row) {
          _used.add(cell.id);
          for (final nested in cell.blocks) {
            _collectBlockIds(nested);
          }
        }
      }
    }
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

BlockNode? _blockAt(RichTextDocument document, int index) {
  if (index < 0 || index >= document.blocks.length) {
    return null;
  }
  return document.blocks[index];
}

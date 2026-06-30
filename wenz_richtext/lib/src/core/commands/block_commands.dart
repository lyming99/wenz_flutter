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
import '../model/attributes.dart';

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
    final replacementIndex = _emptyParagraphReplacementIndex(
      session,
      insertIndex,
      blocks,
    );
    if (replacementIndex != null) {
      final nextBlocks = <BlockNode>[
        for (var i = 0; i < replacementIndex; i++)
          session.document.blocks[i].copy(),
        ...blocks.map((block) => block.copy()),
        for (var i = replacementIndex + 1;
            i < session.document.blocks.length;
            i++)
          session.document.blocks[i].copy(),
      ];
      session.document = RichTextDocument(
        version: session.document.version,
        blocks: nextBlocks,
      );
      return CommandResult(
        selection: selection ??
            _defaultSelectionForInsertedBlock(replacementIndex, blocks.first),
      );
    }
    final splitInsertion = _splitInsertionAtCaret(
      session,
      insertIndex,
      blocks,
    );
    if (splitInsertion != null) {
      final nextBlocks = <BlockNode>[
        for (var i = 0; i < splitInsertion.replacedIndex; i++)
          session.document.blocks[i].copy(),
        ...splitInsertion.replacementBlocks,
        for (var i = splitInsertion.replacedIndex + 1;
            i < session.document.blocks.length;
            i++)
          session.document.blocks[i].copy(),
      ];
      session.document = RichTextDocument(
        version: session.document.version,
        blocks: nextBlocks,
      );
      return CommandResult(
        selection: selection ??
            _defaultSelectionForInsertedBlock(
              splitInsertion.insertedIndex,
              blocks.first,
            ),
      );
    }
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

int? _emptyParagraphReplacementIndex(
  DocumentSession session,
  int insertIndex,
  List<BlockNode> insertedBlocks,
) {
  if (insertedBlocks.length != 1 || insertedBlocks.single is TextBlockNode) {
    return null;
  }
  final selection = session.selection;
  if (selection == null || !selection.isCollapsed) {
    return null;
  }
  final position = selection.extent;
  if (!position.path.isBlockText) {
    return null;
  }
  final caretIndex = position.blockIndex;
  if (insertIndex != caretIndex && insertIndex != caretIndex + 1) {
    return null;
  }
  final block = _blockAt(session.document, caretIndex);
  if (block is! TextBlockNode ||
      block.type != BlockType.paragraph ||
      block.plainText.trim().isNotEmpty) {
    return null;
  }
  return caretIndex;
}

_SplitInsertion? _splitInsertionAtCaret(
  DocumentSession session,
  int insertIndex,
  List<BlockNode> insertedBlocks,
) {
  if (!_canSplitAround(insertedBlocks)) {
    return null;
  }
  final selection = session.selection;
  if (selection == null || !selection.isCollapsed) {
    return null;
  }
  final position = selection.extent;
  if (insertIndex != position.blockIndex) {
    return null;
  }
  final block = _blockAt(session.document, position.blockIndex);
  if (block is TextBlockNode && position.path.isBlockText) {
    return _splitTextBlockForInsertion(
      session,
      block,
      position,
      insertedBlocks,
    );
  }
  if (block is CodeBlockNode && position.path.isBlockCode) {
    return _splitCodeBlockForInsertion(
      session,
      block,
      position,
      insertedBlocks,
    );
  }
  return null;
}

bool _canSplitAround(List<BlockNode> insertedBlocks) {
  return insertedBlocks.isNotEmpty && insertedBlocks.first is! TextBlockNode;
}

_SplitInsertion _splitTextBlockForInsertion(
  DocumentSession session,
  TextBlockNode block,
  DocumentPosition position,
  List<BlockNode> insertedBlocks,
) {
  final length = inlineNodesLength(block.content);
  final offset = position.offset.clamp(0, length).toInt();
  final split = splitInline(block.content, offset);
  final replacement = <BlockNode>[];
  var insertedIndex = position.blockIndex;
  if (split.before.isNotEmpty) {
    replacement.add(
      TextBlockNode(
        id: block.id,
        type: block.type,
        attributes: block.attributes,
        content: split.before,
      ),
    );
    insertedIndex += 1;
  }
  replacement.addAll(insertedBlocks.map((block) => block.copy()));
  if (split.after.isNotEmpty) {
    replacement.add(
      TextBlockNode(
        id: split.before.isEmpty
            ? block.id
            : _uniqueBlockId(
                session.document,
                insertedBlocks,
                '${block.id}-after',
              ),
        type: block.type,
        attributes: block.attributes,
        content: split.after,
      ),
    );
  }
  return _SplitInsertion(
    replacedIndex: position.blockIndex,
    insertedIndex: insertedIndex,
    replacementBlocks: replacement,
  );
}

_SplitInsertion _splitCodeBlockForInsertion(
  DocumentSession session,
  CodeBlockNode block,
  DocumentPosition position,
  List<BlockNode> insertedBlocks,
) {
  final offset = position.offset.clamp(0, block.code.length).toInt();
  final before = block.code.substring(0, offset);
  final after = block.code.substring(offset);
  final replacement = <BlockNode>[];
  var insertedIndex = position.blockIndex;
  if (before.isNotEmpty) {
    replacement.add(
      CodeBlockNode(
        id: block.id,
        code: before,
        language: block.language,
        attributes: block.attributes,
      ),
    );
    insertedIndex += 1;
  }
  replacement.addAll(insertedBlocks.map((block) => block.copy()));
  if (after.isNotEmpty) {
    replacement.add(
      CodeBlockNode(
        id: before.isEmpty
            ? block.id
            : _uniqueBlockId(
                session.document,
                insertedBlocks,
                '${block.id}-after',
              ),
        code: after,
        language: block.language,
        attributes: block.attributes,
      ),
    );
  }
  return _SplitInsertion(
    replacedIndex: position.blockIndex,
    insertedIndex: insertedIndex,
    replacementBlocks: replacement,
  );
}

String _uniqueBlockId(
  RichTextDocument document,
  List<BlockNode> insertedBlocks,
  String preferred,
) {
  final used = <String>{};
  for (final block in document.blocks) {
    _collectIds(block, used);
  }
  for (final block in insertedBlocks) {
    _collectIds(block, used);
  }
  var candidate = preferred;
  var suffix = 1;
  while (used.contains(candidate)) {
    candidate = '$preferred-${suffix++}';
  }
  return candidate;
}

void _collectIds(BlockNode block, Set<String> used) {
  used.add(block.id);
  if (block is TableBlockNode) {
    for (final row in block.table.rows) {
      for (final cell in row) {
        used.add(cell.id);
        for (final nested in cell.blocks) {
          _collectIds(nested, used);
        }
      }
    }
  }
}

class _SplitInsertion {
  const _SplitInsertion({
    required this.replacedIndex,
    required this.insertedIndex,
    required this.replacementBlocks,
  });

  final int replacedIndex;
  final int insertedIndex;
  final List<BlockNode> replacementBlocks;
}

DocumentSelection? _defaultSelectionForInsertedBlock(
  int blockIndex,
  BlockNode block,
) {
  final position = switch (block) {
    TextBlockNode() => DocumentPosition.text(
        blockId: block.id,
        blockIndex: blockIndex,
        offset: 0,
      ),
    CodeBlockNode() => DocumentPosition.code(
        blockId: block.id,
        blockIndex: blockIndex,
        offset: 0,
      ),
    TableBlockNode() => _firstTableCellPosition(block, blockIndex),
    _ => null,
  };
  if (position != null) {
    return DocumentSelection(base: position, extent: position);
  }
  final start = DocumentPosition(
    blockId: block.id,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(block.id),
    offset: 0,
  );
  final end = start.copyWith(offset: _kObjectSelectionLength);
  return DocumentSelection(base: start, extent: end);
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
    if (_isEmptyParagraphAtStart(block, position)) {
      return ReplaceBlocksCommand(
        index: position.blockIndex,
        deleteCount: 1,
        blocks: pasteBlocks,
        selection: _endSelection(
          position.blockIndex + pasteBlocks.length - 1,
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

  bool _isEmptyParagraphAtStart(
      TextBlockNode block, DocumentPosition position) {
    return block.type == BlockType.paragraph &&
        position.path.isBlockText &&
        position.offset == 0 &&
        block.content.isEmpty;
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
      caption: block.caption,
      altText: block.altText,
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
    return block.copyWith(id: id);
  }
  if (block is BlockEmbedNode) {
    return BlockEmbedNode(
      id: id,
      embedType: block.embedType,
      data: Map<String, Object?>.from(block.data),
      fallbackText: block.fallbackText,
      attributes: block.attributes,
    );
  }
  if (block is CalloutBlockNode) {
    return CalloutBlockNode(
      id: id,
      content: block.content.map((node) => node.copy()).toList(),
      variant: block.variant,
      title: block.title,
      icon: block.icon,
      attributes: block.attributes,
    );
  }
  if (block is FileBlockNode) {
    return FileBlockNode(
      id: id,
      assetId: block.assetId,
      name: block.name,
      size: block.size,
      mimeType: block.mimeType,
      file: block.file,
      downloadUrl: block.downloadUrl,
      uploadStatus: block.uploadStatus,
      uploadError: block.uploadError,
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

DocumentPosition? _firstTableCellPosition(
    TableBlockNode block, int blockIndex) {
  for (var rowIndex = 0; rowIndex < block.table.rows.length; rowIndex++) {
    final row = block.table.rows[rowIndex];
    for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
      final cell = row[columnIndex];
      if (cell.covered) {
        continue;
      }
      return DocumentPosition.tableCell(
        tableBlockId: block.id,
        blockIndex: blockIndex,
        tableRowIndex: rowIndex,
        tableColumnIndex: columnIndex,
        offset: 0,
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

class InsertVideoBlockCommand extends EditorCommand {
  const InsertVideoBlockCommand({
    required this.index,
    required this.blockId,
    this.assetId = '',
    this.playbackUrl = '',
    this.file = '',
    this.coverUrl = '',
    this.title = '',
    String description = '',
    this.aspectRatio,
    this.uploadStatus = FileUploadStatus.none,
    this.uploadError = '',
    this.selection,
  }) : videoDescription = description;

  final int index;
  final String blockId;
  final String assetId;
  final String playbackUrl;
  final String file;
  final String coverUrl;
  final String title;
  final String videoDescription;
  final double? aspectRatio;
  final FileUploadStatus uploadStatus;
  final String uploadError;
  final DocumentSelection? selection;

  @override
  String get description => 'insertVideoBlock';

  @override
  CommandResult execute(DocumentSession session) {
    final video = VideoBlockNode(
      id: blockId,
      assetId: assetId,
      playbackUrl: playbackUrl,
      file: file,
      coverUrl: coverUrl,
      title: title,
      description: videoDescription,
      aspectRatio: aspectRatio,
      uploadStatus: uploadStatus,
      uploadError: uploadError,
    );
    final result = InsertBlocksCommand(
      index: index,
      blocks: <BlockNode>[video],
      selection: selection,
    ).execute(session);
    if (selection != null ||
        result.selection != null ||
        !result.recordHistory) {
      return result;
    }
    final insertedIndex = session.document.blocks.indexWhere(
      (block) => block.id == blockId,
    );
    if (insertedIndex == -1) {
      return result;
    }
    return CommandResult(
      selection: _defaultSelectionForInsertedBlock(
        insertedIndex,
        session.document.blocks[insertedIndex],
      ),
      recordHistory: result.recordHistory,
      metadata: result.metadata,
    );
  }
}

class UpdateImageBlockCommand extends EditorCommand {
  const UpdateImageBlockCommand({
    required this.blockIndex,
    this.assetId,
    this.file,
    this.width,
    this.height,
    this.showWidth,
    this.showHeight,
    this.clearShowWidth = false,
    this.clearShowHeight = false,
    this.caption,
    this.altText,
  });

  final int blockIndex;
  final String? assetId;
  final String? file;
  final int? width;
  final int? height;
  final double? showWidth;
  final double? showHeight;
  final bool clearShowWidth;
  final bool clearShowHeight;
  final String? caption;
  final String? altText;

  @override
  String get description => 'updateImageBlock';

  @override
  CommandResult execute(DocumentSession session) {
    final block = _blockAt(session.document, blockIndex);
    if (block is! ImageBlockNode) {
      return const CommandResult(recordHistory: false);
    }

    final next = block.copyWith(
      assetId: assetId,
      file: file,
      width: width,
      height: height,
      showWidth: showWidth,
      showHeight: showHeight,
      clearShowWidth: clearShowWidth,
      clearShowHeight: clearShowHeight,
      caption: caption,
      altText: altText,
    );
    if (_sameImageBlock(block, next)) {
      return const CommandResult(recordHistory: false);
    }

    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[blockIndex] = next;
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return const CommandResult();
  }
}

bool _sameImageBlock(ImageBlockNode a, ImageBlockNode b) {
  return a.id == b.id &&
      a.assetId == b.assetId &&
      a.file == b.file &&
      a.width == b.width &&
      a.height == b.height &&
      a.showWidth == b.showWidth &&
      a.showHeight == b.showHeight &&
      a.caption == b.caption &&
      a.altText == b.altText &&
      a.attributes == b.attributes;
}

class UpdateFileBlockCommand extends EditorCommand {
  const UpdateFileBlockCommand({
    required this.blockIndex,
    this.assetId,
    this.name,
    this.size,
    this.mimeType,
    this.file,
    this.downloadUrl,
    this.uploadStatus,
    this.uploadError,
  });

  final int blockIndex;
  final String? assetId;
  final String? name;
  final int? size;
  final String? mimeType;
  final String? file;
  final String? downloadUrl;
  final FileUploadStatus? uploadStatus;
  final String? uploadError;

  @override
  String get description => 'updateFileBlock';

  @override
  CommandResult execute(DocumentSession session) {
    final block = _blockAt(session.document, blockIndex);
    if (block is! FileBlockNode) {
      return const CommandResult(recordHistory: false);
    }

    final next = block.copyWith(
      assetId: assetId,
      name: name,
      size: size,
      mimeType: mimeType,
      file: file,
      downloadUrl: downloadUrl,
      uploadStatus: uploadStatus,
      uploadError: uploadError,
    );
    if (_sameFileBlock(block, next)) {
      return const CommandResult(recordHistory: false);
    }

    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[blockIndex] = next;
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return const CommandResult();
  }
}

bool _sameFileBlock(FileBlockNode a, FileBlockNode b) {
  return a.id == b.id &&
      a.assetId == b.assetId &&
      a.name == b.name &&
      a.size == b.size &&
      a.mimeType == b.mimeType &&
      a.file == b.file &&
      a.downloadUrl == b.downloadUrl &&
      a.uploadStatus == b.uploadStatus &&
      a.uploadError == b.uploadError &&
      a.attributes == b.attributes;
}

class UpdateVideoBlockCommand extends EditorCommand {
  const UpdateVideoBlockCommand({
    required this.blockIndex,
    this.assetId,
    this.playbackUrl,
    this.file,
    this.coverUrl,
    this.title,
    String? description,
    this.aspectRatio,
    this.clearAspectRatio = false,
    this.uploadStatus,
    this.uploadError,
  }) : videoDescription = description;

  final int blockIndex;
  final String? assetId;
  final String? playbackUrl;
  final String? file;
  final String? coverUrl;
  final String? title;
  final String? videoDescription;
  final double? aspectRatio;
  final bool clearAspectRatio;
  final FileUploadStatus? uploadStatus;
  final String? uploadError;

  @override
  String get description => 'updateVideoBlock';

  @override
  CommandResult execute(DocumentSession session) {
    final block = _blockAt(session.document, blockIndex);
    if (block is! VideoBlockNode) {
      return const CommandResult(recordHistory: false);
    }

    final next = block.copyWith(
      assetId: assetId,
      playbackUrl: playbackUrl,
      file: file,
      coverUrl: coverUrl,
      title: title,
      description: videoDescription,
      aspectRatio: aspectRatio,
      clearAspectRatio: clearAspectRatio,
      uploadStatus: uploadStatus,
      uploadError: uploadError,
    );
    if (_sameVideoBlock(block, next)) {
      return const CommandResult(recordHistory: false);
    }

    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[blockIndex] = next;
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return const CommandResult();
  }
}

class DeleteVideoBlockCommand extends EditorCommand {
  const DeleteVideoBlockCommand({
    required this.blockIndex,
    this.selection,
  });

  final int blockIndex;
  final DocumentSelection? selection;

  @override
  String get description => 'deleteVideoBlock';

  @override
  CommandResult execute(DocumentSession session) {
    final block = _blockAt(session.document, blockIndex);
    if (block is! VideoBlockNode) {
      return const CommandResult(recordHistory: false);
    }

    final nextBlocks = <BlockNode>[
      for (var i = 0; i < blockIndex; i++) session.document.blocks[i].copy(),
      for (var i = blockIndex + 1; i < session.document.blocks.length; i++)
        session.document.blocks[i].copy(),
    ];
    if (nextBlocks.isEmpty) {
      final paragraph = TextBlockNode(
        id: '${block.id}-empty',
        type: BlockType.paragraph,
        content: const <InlineNode>[],
      );
      session.document = RichTextDocument(
        version: session.document.version,
        blocks: <BlockNode>[paragraph],
      );
      final position = DocumentPosition.text(
        blockId: paragraph.id,
        blockIndex: 0,
        offset: 0,
      );
      return CommandResult(
        selection:
            selection ?? DocumentSelection(base: position, extent: position),
      );
    }

    final selectionAfter = _selectionAfterDeletingBlock(
      beforeBlocks: session.document.blocks,
      afterBlocks: nextBlocks,
      deletedIndex: blockIndex,
    );
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: nextBlocks,
    );
    return CommandResult(selection: selection ?? selectionAfter);
  }
}

bool _sameVideoBlock(VideoBlockNode a, VideoBlockNode b) {
  return a.id == b.id &&
      a.assetId == b.assetId &&
      a.playbackUrl == b.playbackUrl &&
      a.file == b.file &&
      a.coverUrl == b.coverUrl &&
      a.title == b.title &&
      a.description == b.description &&
      a.aspectRatio == b.aspectRatio &&
      a.uploadStatus == b.uploadStatus &&
      a.uploadError == b.uploadError &&
      a.attributes == b.attributes;
}

DocumentSelection _selectionAfterDeletingBlock({
  required List<BlockNode> beforeBlocks,
  required List<BlockNode> afterBlocks,
  required int deletedIndex,
}) {
  for (var i = deletedIndex - 1; i >= 0; i--) {
    final block = beforeBlocks[i];
    if (block is TextBlockNode || block is CodeBlockNode) {
      return _selectionAtEditableBlockEnd(block, i);
    }
  }
  if (deletedIndex < afterBlocks.length) {
    return _selectionAtBlockStartOrObject(
        afterBlocks[deletedIndex], deletedIndex);
  }
  return _selectionAtBlockEndOrObject(afterBlocks.last, afterBlocks.length - 1);
}

DocumentSelection _selectionAtEditableBlockEnd(
    BlockNode block, int blockIndex) {
  if (block is TextBlockNode) {
    final position = DocumentPosition.text(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: inlineNodesLength(block.content),
    );
    return DocumentSelection(base: position, extent: position);
  }
  final code = block as CodeBlockNode;
  final position = DocumentPosition.code(
    blockId: code.id,
    blockIndex: blockIndex,
    offset: code.code.length,
  );
  return DocumentSelection(base: position, extent: position);
}

DocumentSelection _selectionAtBlockStartOrObject(
    BlockNode block, int blockIndex) {
  if (block is TextBlockNode) {
    final position = DocumentPosition.text(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: 0,
    );
    return DocumentSelection(base: position, extent: position);
  }
  if (block is CodeBlockNode) {
    final position = DocumentPosition.code(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: 0,
    );
    return DocumentSelection(base: position, extent: position);
  }
  if (block is TableBlockNode) {
    final position = _firstTableCellPosition(block, blockIndex);
    if (position != null) {
      return DocumentSelection(base: position, extent: position);
    }
  }
  return _objectSelectionForBlock(block, blockIndex);
}

DocumentSelection _selectionAtBlockEndOrObject(
    BlockNode block, int blockIndex) {
  if (block is TextBlockNode || block is CodeBlockNode) {
    return _selectionAtEditableBlockEnd(block, blockIndex);
  }
  if (block is TableBlockNode) {
    final position = _lastTableCellPosition(block, blockIndex);
    if (position != null) {
      return DocumentSelection(base: position, extent: position);
    }
  }
  return _objectSelectionForBlock(block, blockIndex);
}

DocumentSelection _objectSelectionForBlock(BlockNode block, int blockIndex) {
  final start = DocumentPosition(
    blockId: block.id,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(block.id),
    offset: 0,
  );
  final end = start.copyWith(offset: _kObjectSelectionLength);
  return DocumentSelection(base: start, extent: end);
}

class SetBlockAnchorCommand extends EditorCommand {
  const SetBlockAnchorCommand({
    required this.blockIndex,
    this.anchor,
  });

  final int blockIndex;
  final String? anchor;

  @override
  String get description => 'setBlockAnchor';

  @override
  CommandResult execute(DocumentSession session) {
    final block = _blockAt(session.document, blockIndex);
    if (block == null) {
      return const CommandResult(recordHistory: false);
    }

    final normalizedAnchor = _normalizeAnchor(anchor);
    final nextAttributes =
        _blockAttributesWithAnchor(block.attributes, normalizedAnchor);
    if (nextAttributes == block.attributes) {
      return const CommandResult(recordHistory: false);
    }

    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[blockIndex] = _blockWithAttributes(block, nextAttributes);
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return const CommandResult();
  }
}

String? _normalizeAnchor(String? anchor) {
  final trimmed = anchor?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

BlockAttributes _blockAttributesWithAnchor(
  BlockAttributes attributes,
  String? anchor,
) {
  return BlockAttributes(
    level: attributes.level,
    indent: attributes.indent,
    alignment: attributes.alignment,
    listType: attributes.listType,
    checked: attributes.checked,
    childNote: attributes.childNote,
    anchor: anchor,
  );
}

BlockNode _blockWithAttributes(BlockNode block, BlockAttributes attributes) {
  if (block is TextBlockNode) {
    return TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: attributes,
      content: block.content.map((node) => node.copy()).toList(),
    );
  }
  if (block is CodeBlockNode) {
    return CodeBlockNode(
      id: block.id,
      code: block.code,
      language: block.language,
      attributes: attributes,
    );
  }
  if (block is ImageBlockNode) {
    return ImageBlockNode(
      id: block.id,
      assetId: block.assetId,
      file: block.file,
      width: block.width,
      height: block.height,
      showWidth: block.showWidth,
      showHeight: block.showHeight,
      caption: block.caption,
      altText: block.altText,
      attributes: attributes,
    );
  }
  if (block is TableBlockNode) {
    return TableBlockNode(
      id: block.id,
      table: block.table,
      attributes: attributes,
    );
  }
  if (block is DividerBlockNode) {
    return DividerBlockNode(id: block.id, attributes: attributes);
  }
  if (block is VideoBlockNode) {
    return block.copyWith(attributes: attributes);
  }
  if (block is BlockEmbedNode) {
    return BlockEmbedNode(
      id: block.id,
      embedType: block.embedType,
      data: block.data,
      fallbackText: block.fallbackText,
      attributes: attributes,
    );
  }
  if (block is CalloutBlockNode) {
    return CalloutBlockNode(
      id: block.id,
      content: block.content.map((node) => node.copy()).toList(),
      variant: block.variant,
      title: block.title,
      icon: block.icon,
      attributes: attributes,
    );
  }
  if (block is FileBlockNode) {
    return FileBlockNode(
      id: block.id,
      assetId: block.assetId,
      name: block.name,
      size: block.size,
      mimeType: block.mimeType,
      file: block.file,
      downloadUrl: block.downloadUrl,
      uploadStatus: block.uploadStatus,
      uploadError: block.uploadError,
      attributes: attributes,
    );
  }
  return block.copy();
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
    if (block.type == BlockType.listItem && block.plainText.trim().isEmpty) {
      return _exitEmptyListItem(session, block, position);
    }
    if (_isEmptyQuoteBlock(block)) {
      return _exitEmptyQuoteBlock(session, block, position);
    }

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
      attributes: _continuedTextBlockAttributes(block),
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

  bool _isEmptyQuoteBlock(TextBlockNode block) {
    return block.plainText.trim().isEmpty &&
        (block.type == BlockType.quote || block.attributes.isQuoted);
  }

  CommandResult _exitEmptyQuoteBlock(
    DocumentSession session,
    TextBlockNode block,
    DocumentPosition position,
  ) {
    final paragraph = TextBlockNode(
      id: block.id,
      type: block.type == BlockType.quote ? BlockType.paragraph : block.type,
      attributes: _attributesAfterQuoteExit(block.attributes),
      content: const <InlineNode>[],
    );
    final nextSelectionPosition = DocumentPosition.text(
      blockId: paragraph.id,
      blockIndex: position.blockIndex,
      offset: 0,
    );
    return ReplaceBlocksCommand(
      index: position.blockIndex,
      deleteCount: 1,
      blocks: <BlockNode>[paragraph],
      selection: DocumentSelection(
        base: nextSelectionPosition,
        extent: nextSelectionPosition,
      ),
    ).execute(session);
  }

  CommandResult _exitEmptyListItem(
    DocumentSession session,
    TextBlockNode block,
    DocumentPosition position,
  ) {
    final paragraph = TextBlockNode(
      id: block.id,
      type: BlockType.paragraph,
      attributes: _paragraphAttributesAfterListExit(block.attributes),
      content: const <InlineNode>[],
    );
    final nextSelectionPosition = DocumentPosition.text(
      blockId: paragraph.id,
      blockIndex: position.blockIndex,
      offset: 0,
    );
    return ReplaceBlocksCommand(
      index: position.blockIndex,
      deleteCount: 1,
      blocks: <BlockNode>[paragraph],
      selection: DocumentSelection(
        base: nextSelectionPosition,
        extent: nextSelectionPosition,
      ),
    ).execute(session);
  }

  BlockAttributes _continuedTextBlockAttributes(TextBlockNode block) {
    final current = block.attributes;
    if (block.type == BlockType.listItem) {
      return BlockAttributes(
        level: current.level,
        indent: current.indent,
        alignment: current.alignment,
        listType: current.listType,
        checked: current.checked != null || current.listType == 'task'
            ? false
            : null,
        quoted: current.quoted,
        childNote: current.childNote,
        anchor: current.anchor,
      );
    }
    return BlockAttributes(
      level: current.level,
      indent: current.indent,
      alignment: current.alignment,
      listType: current.listType,
      checked: current.checked,
      quoted: current.quoted,
      childNote: current.childNote,
      anchor: current.anchor,
    );
  }

  BlockAttributes _attributesAfterQuoteExit(BlockAttributes current) {
    return BlockAttributes(
      level: current.level,
      indent: current.indent,
      alignment: current.alignment,
      listType: current.listType,
      checked: current.checked,
      childNote: current.childNote,
      anchor: current.anchor,
    );
  }

  BlockAttributes _paragraphAttributesAfterListExit(
    BlockAttributes current,
  ) {
    return BlockAttributes(
      indent: current.indent,
      alignment: current.alignment,
      quoted: current.quoted,
      childNote: current.childNote,
      anchor: current.anchor,
    );
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

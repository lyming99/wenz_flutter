import 'package:flutter/foundation.dart';

import '../codecs/legacy_wen_json_codec.dart';
import '../codecs/rich_text_json_codec.dart';
import '../core/commands/block_commands.dart';
import '../core/commands/block_structure_commands.dart';
import '../core/commands/command_executor.dart';
import '../core/commands/command_registry.dart';
import '../core/commands/editor_command.dart';
import '../core/commands/inline_commands.dart';
import '../core/commands/selection_commands.dart';
import '../core/commands/style_commands.dart';
import '../core/commands/table_commands.dart';
import '../core/commands/text_commands.dart';
import '../core/model/attributes.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/rich_text_document.dart';
import '../core/position/document_position.dart';
import '../core/transaction/change_set.dart';
import '../core/transaction/document_session.dart';
import '../history/history_manager.dart';
import '../input/clipboard_service.dart';
import '../input/composition_state.dart';

class WenzRichTextController extends ChangeNotifier {
  WenzRichTextController({
    RichTextDocument? document,
    DocumentSelection? selection,
    HistoryManager? history,
    RichTextJsonCodec richTextJsonCodec = const RichTextJsonCodec(),
    LegacyWenJsonCodec legacyWenJsonCodec = const LegacyWenJsonCodec(),
    this.clipboardService = const ClipboardService(),
  })  : session = DocumentSession(
          document: document,
          selection: selection,
          history: history,
        ),
        _richTextJsonCodec = richTextJsonCodec,
        _legacyWenJsonCodec = legacyWenJsonCodec {
    _executor = CommandExecutor(session);
  }

  final DocumentSession session;
  final RichTextJsonCodec _richTextJsonCodec;
  final LegacyWenJsonCodec _legacyWenJsonCodec;
  final ClipboardService clipboardService;
  late final CommandExecutor _executor;

  /// Named-command registry. Plugins register commands here and invoke them
  /// via [executeCommand] without modifying the controller's typed surface.
  final CommandRegistry registry = CommandRegistry();

  /// Middleware list on the executor. Add [CommandMiddleware]s to intercept
  /// every command (before/after hooks).
  List<CommandMiddleware> get middlewares => _executor.middlewares;

  /// Active IME composition region, or `null` when none. Driven by the
  /// TextInputClient bridge; not part of undo/redo history.
  CompositionState? get compositionState => _compositionState;
  CompositionState? _compositionState;

  RichTextDocument get document => session.document;

  DocumentSelection? get selection => session.selection;

  bool get canUndo => session.canUndo;

  bool get canRedo => session.canRedo;

  void setSelection(DocumentSelection? selection) {
    if (session.selection == selection) {
      return;
    }
    session.selection = selection;
    notifyListeners();
  }

  /// Updates the IME composition region. Called by the TextInputClient bridge.
  /// Does not record history; only refreshes listeners so the composition
  /// decoration can repaint. A null/empty [state] clears any active
  /// composition.
  void setCompositionState(CompositionState? state) {
    final next = (state == null || state.isEmpty) ? null : state;
    if (next == _compositionState) {
      return;
    }
    _compositionState = next;
    notifyListeners();
  }

  void replaceDocument(
    RichTextDocument document, {
    DocumentSelection? selection,
    bool clearHistory = true,
  }) {
    session.replaceDocument(document, nextSelection: selection);
    if (clearHistory) {
      session.history.clear();
    }
    notifyListeners();
  }

  String toJson() => _richTextJsonCodec.encode(document);

  void loadJson(
    String source, {
    bool legacy = false,
    DocumentSelection? selection,
  }) {
    final nextDocument = legacy
        ? _legacyWenJsonCodec.decode(source)
        : _richTextJsonCodec.decode(source);
    replaceDocument(nextDocument, selection: selection);
  }

  ChangeSet execute(EditorCommand command) {
    final change = _executor.execute(command);
    if (!change.isNoop || change.selectionBefore != change.selectionAfter) {
      notifyListeners();
    }
    return change;
  }

  /// Executes a named command registered via [registry]. Lets plugins run
  /// commands without a typed controller method. Throws if [name] is unknown.
  ChangeSet executeCommand(String name, Map<String, Object?> args) {
    final change = registry.execute(name, args, _executor);
    if (!change.isNoop || change.selectionBefore != change.selectionAfter) {
      notifyListeners();
    }
    return change;
  }

  bool undo() {
    final changed = session.undo();
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  bool redo() {
    final changed = session.redo();
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  ChangeSet insertText(
    String text, {
    TextAttributes attributes = const TextAttributes(),
  }) {
    return execute(InsertTextCommand(text, attributes: attributes));
  }

  ChangeSet deleteSelection([DocumentSelection? selection]) {
    return execute(DeleteSelectionCommand(selection));
  }

  ChangeSet deleteBackward() {
    return execute(const DeleteBackwardCommand());
  }

  ChangeSet deleteForward() {
    return execute(const DeleteForwardCommand());
  }

  ChangeSet moveCaretBackward({bool expandSelection = false}) {
    return execute(
      MoveCaretCommand(
        CaretMovementDirection.backward,
        expandSelection: expandSelection,
      ),
    );
  }

  ChangeSet moveCaretForward({bool expandSelection = false}) {
    return execute(
      MoveCaretCommand(
        CaretMovementDirection.forward,
        expandSelection: expandSelection,
      ),
    );
  }

  ChangeSet moveTableCell({required bool forward}) {
    return execute(
      MoveTableCellCommand(
        forward
            ? CaretMovementDirection.forward
            : CaretMovementDirection.backward,
      ),
    );
  }

  ChangeSet moveCaretByWord({
    required bool forward,
    bool expandSelection = false,
  }) {
    return execute(
      MoveCaretByWordCommand(
        forward
            ? CaretMovementDirection.forward
            : CaretMovementDirection.backward,
        expandSelection: expandSelection,
      ),
    );
  }

  ChangeSet moveCaretToBlockBoundary({
    required bool forward,
    bool expandSelection = false,
  }) {
    return execute(
      MoveCaretToBlockBoundaryCommand(
        forward
            ? CaretMovementDirection.forward
            : CaretMovementDirection.backward,
        expandSelection: expandSelection,
      ),
    );
  }

  ChangeSet moveCaretToDocumentBoundary({
    required bool forward,
    bool expandSelection = false,
  }) {
    return execute(
      MoveCaretToDocumentBoundaryCommand(
        forward
            ? CaretMovementDirection.forward
            : CaretMovementDirection.backward,
        expandSelection: expandSelection,
      ),
    );
  }

  ChangeSet selectAll() {
    return execute(const SelectAllCommand());
  }

  ChangeSet indent() {
    return execute(const IndentCommand(1));
  }

  ChangeSet outdent() {
    return execute(const IndentCommand(-1));
  }

  ChangeSet toggleTodo() {
    return execute(const ToggleTodoCommand());
  }

  ChangeSet toggleQuote() {
    return execute(const ToggleQuoteCommand());
  }

  ChangeSet setCodeLanguage(String language, {int? blockIndex}) {
    return execute(SetCodeLanguageCommand(language, blockIndex: blockIndex));
  }

  ChangeSet insertCallout({
    required String blockId,
    String variant = 'info',
    List<InlineNode> content = const <InlineNode>[],
    DocumentSelection? selection,
  }) {
    return insertBlocks(
      index: document.blocks.length,
      blocks: <BlockNode>[
        CalloutBlockNode(id: blockId, content: content, variant: variant),
      ],
      selection: selection,
    );
  }

  ChangeSet insertFile({
    required String blockId,
    required String assetId,
    String name = '',
    int size = 0,
    String file = '',
    DocumentSelection? selection,
  }) {
    return insertBlocks(
      index: document.blocks.length,
      blocks: <BlockNode>[
        FileBlockNode(
          id: blockId,
          assetId: assetId,
          name: name,
          size: size,
          file: file,
        ),
      ],
      selection: selection,
    );
  }

  /// Serialises the current selection into a clipboard string (rich JSON for a
  /// same-block range, plain text otherwise). Returns `null` when nothing is
  /// selected. Does not touch the platform clipboard — the caller writes the
  /// result via `Clipboard.setData`.
  String? copySelection([DocumentSelection? selection]) {
    final target = selection ?? this.selection;
    final payload = clipboardService.copy(document, target);
    return payload;
  }

  /// Copy then delete. Returns the copied payload (for the caller to write to
  /// the platform clipboard), or `null` when nothing was selected.
  String? cutSelection([DocumentSelection? selection]) {
    final payload = copySelection(selection);
    if (payload != null) {
      deleteSelection(selection);
    }
    return payload;
  }

  /// Pastes a clipboard payload at the current selection. Rich inline payloads
  /// preserve attributes; plain text is split on newlines — the first line
  /// inserts into the current block, each subsequent line creates a new block
  /// via [EnterCommand].
  void pasteText(String raw) {
    if (raw.isEmpty) {
      return;
    }
    final paste = clipboardService.parse(raw);
    if (paste.isRich) {
      _pasteInline(paste.inlineRuns);
      notifyListeners();
      return;
    }
    final text = paste.text;
    if (text.isEmpty) {
      return;
    }
    _pastePlain(text);
    notifyListeners();
  }

  void _pasteInline(List<InlineNode> runs) {
    if (runs.isEmpty) {
      return;
    }
    // Insert each run at the current caret; InsertTextCommand handles attribute
    // preservation per run. Inserting as separate commands lets them coalesce
    // only when attributes match.
    for (final run in runs) {
      if (run is TextRun) {
        if (run.text.isEmpty) {
          continue;
        }
        insertText(run.text, attributes: run.attributes);
      }
    }
  }

  void _pastePlain(String text) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) {
        // Split into a new block at the caret before inserting the next line.
        enter(newBlockId: 'paste-${_pasteBlockCounter()}');
      }
      if (lines[i].isNotEmpty) {
        insertText(lines[i]);
      }
    }
  }

  int _pasteSequence = 0;
  String _pasteBlockCounter() {
    _pasteSequence += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_pasteSequence';
  }

  ChangeSet enter({String? newBlockId}) {
    return execute(EnterCommand(newBlockId: newBlockId));
  }

  ChangeSet insertBlocks({
    required int index,
    required List<BlockNode> blocks,
    DocumentSelection? selection,
  }) {
    return execute(
      InsertBlocksCommand(index: index, blocks: blocks, selection: selection),
    );
  }

  ChangeSet replaceBlocks({
    required int index,
    required int deleteCount,
    required List<BlockNode> blocks,
    DocumentSelection? selection,
  }) {
    return execute(
      ReplaceBlocksCommand(
        index: index,
        deleteCount: deleteCount,
        blocks: blocks,
        selection: selection,
      ),
    );
  }

  ChangeSet formatText(
    TextAttributes attributes, {
    DocumentSelection? selection,
  }) {
    return execute(
      FormatTextCommand(attributes: attributes, selection: selection),
    );
  }

  ChangeSet clearStyle({DocumentSelection? selection}) {
    return execute(ClearStyleCommand(selection: selection));
  }

  ChangeSet setLink(String? url, {DocumentSelection? selection}) {
    return execute(SetLinkCommand(url, selection: selection));
  }

  ChangeSet toggleRemark({DocumentSelection? selection}) {
    return execute(ToggleMarkCommand(TextMark.remark, selection: selection));
  }

  ChangeSet insertFormula(String text, {DocumentSelection? selection}) {
    return execute(
      InsertInlineEmbedCommand(
        embedType: 'formula',
        data: <String, Object?>{'text': text},
        selection: selection,
      ),
    );
  }

  ChangeSet insertMention(
    String id,
    String label, {
    DocumentSelection? selection,
  }) {
    return execute(
      InsertInlineEmbedCommand(
        embedType: 'mention',
        data: <String, Object?>{'id': id, 'label': label},
        selection: selection,
      ),
    );
  }

  ChangeSet insertInlineImage({
    required String assetId,
    double? width,
    double? height,
    DocumentSelection? selection,
  }) {
    return execute(
      InsertInlineEmbedCommand(
        embedType: 'image',
        data: <String, Object?>{
          'assetId': assetId,
          if (width != null) 'width': width,
          if (height != null) 'height': height,
        },
        selection: selection,
      ),
    );
  }

  ChangeSet setBlockType({
    required BlockType type,
    DocumentSelection? selection,
    int? level,
    String? listType,
    bool? checked,
  }) {
    return execute(
      SetBlockTypeCommand(
        type: type,
        selection: selection,
        level: level,
        listType: listType,
        checked: checked,
      ),
    );
  }

  ChangeSet setAlignment(String? alignment, {DocumentSelection? selection}) {
    return execute(
      SetAlignmentCommand(alignment: alignment, selection: selection),
    );
  }

  ChangeSet insertTable({
    required int index,
    required String tableId,
    required int rowCount,
    required int columnCount,
    DocumentSelection? selection,
  }) {
    return execute(
      InsertTableCommand(
        index: index,
        tableId: tableId,
        rowCount: rowCount,
        columnCount: columnCount,
        selection: selection,
      ),
    );
  }

  ChangeSet insertTableRow({required int blockIndex, required int rowIndex}) {
    return execute(
      InsertTableRowCommand(blockIndex: blockIndex, rowIndex: rowIndex),
    );
  }

  ChangeSet insertTableColumn({
    required int blockIndex,
    required int columnIndex,
  }) {
    return execute(
      InsertTableColumnCommand(
        blockIndex: blockIndex,
        columnIndex: columnIndex,
      ),
    );
  }

  ChangeSet deleteTableRow({required int blockIndex, required int rowIndex}) {
    return execute(
      DeleteTableRowCommand(blockIndex: blockIndex, rowIndex: rowIndex),
    );
  }

  ChangeSet deleteTableColumn({
    required int blockIndex,
    required int columnIndex,
  }) {
    return execute(
      DeleteTableColumnCommand(
        blockIndex: blockIndex,
        columnIndex: columnIndex,
      ),
    );
  }

  ChangeSet setTableColumnAlignment({
    required int blockIndex,
    required int columnIndex,
    required String? alignment,
  }) {
    return execute(
      SetTableColumnAlignmentCommand(
        blockIndex: blockIndex,
        columnIndex: columnIndex,
        alignment: alignment,
      ),
    );
  }

  ChangeSet setTableColumnWidth({
    required int blockIndex,
    required int columnIndex,
    required double? width,
  }) {
    return execute(
      SetTableColumnWidthCommand(
        blockIndex: blockIndex,
        columnIndex: columnIndex,
        width: width,
      ),
    );
  }

  ChangeSet setTableCellHeader({
    required int blockIndex,
    required int rowIndex,
    required int columnIndex,
    required bool isHeader,
  }) {
    return execute(
      SetTableCellHeaderCommand(
        blockIndex: blockIndex,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        isHeader: isHeader,
      ),
    );
  }

  ChangeSet setTableCellBackground({
    required int blockIndex,
    required int rowIndex,
    required int columnIndex,
    required int? backgroundColor,
  }) {
    return execute(
      SetTableCellBackgroundCommand(
        blockIndex: blockIndex,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        backgroundColor: backgroundColor,
      ),
    );
  }

  ChangeSet mergeTableCells({
    required int blockIndex,
    required int startRow,
    required int startColumn,
    required int endRow,
    required int endColumn,
  }) {
    return execute(
      MergeTableCellsCommand(
        blockIndex: blockIndex,
        startRow: startRow,
        startColumn: startColumn,
        endRow: endRow,
        endColumn: endColumn,
      ),
    );
  }

  ChangeSet splitTableCell({
    required int blockIndex,
    required int rowIndex,
    required int columnIndex,
  }) {
    return execute(
      SplitTableCellCommand(
        blockIndex: blockIndex,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
      ),
    );
  }

  void selectTableRow({required int blockIndex, required int rowIndex}) {
    final tableBlock = _tableBlockAt(blockIndex);
    if (tableBlock == null ||
        rowIndex < 0 ||
        rowIndex >= tableBlock.table.rowCount ||
        tableBlock.table.columnCount == 0) {
      return;
    }
    setSelection(
      _tableRangeSelection(
        tableBlock,
        blockIndex,
        startRow: rowIndex,
        endRow: rowIndex,
        startColumn: 0,
        endColumn: tableBlock.table.columnCount - 1,
      ),
    );
  }

  void selectTableColumn({required int blockIndex, required int columnIndex}) {
    final tableBlock = _tableBlockAt(blockIndex);
    if (tableBlock == null ||
        columnIndex < 0 ||
        columnIndex >= tableBlock.table.columnCount ||
        tableBlock.table.rowCount == 0) {
      return;
    }
    setSelection(
      _tableRangeSelection(
        tableBlock,
        blockIndex,
        startRow: 0,
        endRow: tableBlock.table.rowCount - 1,
        startColumn: columnIndex,
        endColumn: columnIndex,
      ),
    );
  }

  void selectTable({required int blockIndex}) {
    final tableBlock = _tableBlockAt(blockIndex);
    if (tableBlock == null ||
        tableBlock.table.rowCount == 0 ||
        tableBlock.table.columnCount == 0) {
      return;
    }
    setSelection(
      _tableRangeSelection(
        tableBlock,
        blockIndex,
        startRow: 0,
        endRow: tableBlock.table.rowCount - 1,
        startColumn: 0,
        endColumn: tableBlock.table.columnCount - 1,
      ),
    );
  }

  TableBlockNode? _tableBlockAt(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      return null;
    }
    final block = document.blocks[blockIndex];
    return block is TableBlockNode ? block : null;
  }

  DocumentSelection _tableRangeSelection(
    TableBlockNode tableBlock,
    int blockIndex, {
    required int startRow,
    required int endRow,
    required int startColumn,
    required int endColumn,
  }) {
    final base = DocumentPosition.tableCell(
      tableBlockId: tableBlock.id,
      blockIndex: blockIndex,
      tableRowIndex: startRow,
      tableColumnIndex: startColumn,
      offset: 0,
    );
    final extent = DocumentPosition.tableCell(
      tableBlockId: tableBlock.id,
      blockIndex: blockIndex,
      tableRowIndex: endRow,
      tableColumnIndex: endColumn,
      offset: 0,
    );
    return DocumentSelection(base: base, extent: extent);
  }

  ChangeSet insertTableCellText({
    required int blockIndex,
    required int rowIndex,
    required int columnIndex,
    required int offset,
    required String text,
    TextAttributes attributes = const TextAttributes(),
  }) {
    return execute(
      InsertTableCellTextCommand(
        blockIndex: blockIndex,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        offset: offset,
        text: text,
        attributes: attributes,
      ),
    );
  }

  ChangeSet deleteTableCellText({
    required int blockIndex,
    required int rowIndex,
    required int columnIndex,
    required int startOffset,
    required int endOffset,
  }) {
    return execute(
      DeleteTableCellTextCommand(
        blockIndex: blockIndex,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        startOffset: startOffset,
        endOffset: endOffset,
      ),
    );
  }

  ChangeSet formatTableCellText({
    required int blockIndex,
    required int rowIndex,
    required int columnIndex,
    required int startOffset,
    required int endOffset,
    required TextAttributes attributes,
  }) {
    return execute(
      FormatTableCellTextCommand(
        blockIndex: blockIndex,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        startOffset: startOffset,
        endOffset: endOffset,
        attributes: attributes,
      ),
    );
  }
}

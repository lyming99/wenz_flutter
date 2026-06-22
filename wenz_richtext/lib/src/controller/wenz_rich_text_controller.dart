import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../codecs/document_errors.dart';
import '../codecs/html_codec.dart';
import '../codecs/legacy_wen_json_codec.dart';
import '../codecs/markdown_codec.dart';
import '../codecs/plain_text_codec.dart';
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
import '../widgets/media_resolver.dart';

class WenzRichTextController extends ChangeNotifier {
  WenzRichTextController({
    RichTextDocument? document,
    DocumentSelection? selection,
    HistoryManager? history,
    RichTextJsonCodec richTextJsonCodec = const RichTextJsonCodec(),
    LegacyWenJsonCodec legacyWenJsonCodec = const LegacyWenJsonCodec(),
    PlainTextCodec plainTextCodec = const PlainTextCodec(),
    MarkdownCodec markdownCodec = const MarkdownCodec(),
    HtmlCodec htmlCodec = const HtmlCodec(),
    this.clipboardService = const ClipboardService(),
    this.mediaResolver,
  })  : session = DocumentSession(
          document: document,
          selection: selection,
          history: history,
        ),
        _richTextJsonCodec = richTextJsonCodec,
        _legacyWenJsonCodec = legacyWenJsonCodec,
        _plainTextCodec = plainTextCodec,
        _markdownCodec = markdownCodec,
        _htmlCodec = htmlCodec {
    _executor = CommandExecutor(session);
  }

  final DocumentSession session;
  final RichTextJsonCodec _richTextJsonCodec;
  final LegacyWenJsonCodec _legacyWenJsonCodec;
  final PlainTextCodec _plainTextCodec;
  final MarkdownCodec _markdownCodec;
  final HtmlCodec _htmlCodec;
  final ClipboardService clipboardService;
  late final CommandExecutor _executor;

  /// Optional [MediaResolver] held on the controller for business-layer
  /// reachability (e.g. an insert helper that uploads then writes the resulting
  /// URL into `assetId`/`file` can reference the same resolver instance). The
  /// editor widget still needs the resolver passed via
  /// `WenzRichTextEditor.mediaResolver` to actually drive rendering — this
  /// field is a convenience handle, not a render hook on its own.
  final MediaResolver? mediaResolver;

  /// The editor widget's focus node, injected from the widget layer. `null`
  /// until the editor is mounted (or when no editor is attached, e.g. in pure
  /// logic tests). [requestFocus] uses it to move focus to the editor.
  FocusNode? _focusNode;

  /// Named-command registry. Plugins register commands here and invoke them
  /// via [executeCommand] without modifying the controller's typed surface.
  final CommandRegistry registry = CommandRegistry();

  /// Middleware list on the executor. Add [CommandMiddleware]s to intercept
  /// every command (before/after hooks).
  List<CommandMiddleware> get middlewares => _executor.middlewares;

  /// Invoked synchronously **before** [notifyListeners] whenever the document
  /// content changes (typing, format, block structure, undo/redo, replace,
  /// paste). Receives the committed document. Selection-only and
  /// composition-only mutations do **not** trigger this — use
  /// [onSelectionChanged] for those.
  ///
  /// Avoid mutating the document from inside the callback (it runs during the
  /// controller's own mutation); read state and schedule follow-up work
  /// instead.
  ValueChanged<RichTextDocument>? onChanged;

  /// Invoked synchronously **before** [notifyListeners] whenever the selection
  /// changes, whether from a command, a programmatic [setSelection], undo/redo,
  /// or replace. Receives the new selection (`null` when cleared). Use this to
  /// drive toolbar state, inspector panels, or analytics.
  ///
  /// Avoid mutating the document from inside the callback.
  ValueChanged<DocumentSelection?>? onSelectionChanged;

  /// Invoked synchronously **before** [notifyListeners] right after a command
  /// produced a non-noop [ChangeSet]. Receives the originating command and the
  /// committed change. Fires for both typed [execute] and registry-driven
  /// [executeCommand] paths. Undo/redo do **not** trigger this (there is no
  /// originating command object) — they still trigger [onChanged] /
  /// [onSelectionChanged].
  ///
  /// Prefer [CommandMiddleware.after] for cross-cutting concerns (validation
  /// logging, analytics) that must observe *every* command including those
  /// dispatched by plugins. This callback is the business-integration layer:
  /// it fires for commands run through this controller's typed surface.
  void Function(EditorCommand command, ChangeSet change)? onCommandExecuted;

  /// Active IME composition region, or `null` when none. Driven by the
  /// TextInputClient bridge; not part of undo/redo history.
  CompositionState? get compositionState => _compositionState;
  CompositionState? _compositionState;

  RichTextDocument get document => session.document;

  DocumentSelection? get selection => session.selection;

  bool get canUndo => session.canUndo;

  bool get canRedo => session.canRedo;

  /// Block ids whose content changed in the most recent mutation
  /// ([execute], [executeCommand], [undo], [redo], [replaceDocument]), plus the
  /// ids of blocks newly added in that mutation. Consumers (e.g. the editor
  /// widget) use this to skip rebuilding blocks that did not change.
  ///
  /// The set is computed by diffing the previous document against the new one
  /// (see [_changedBlockIds]). It is reset to empty for selection-only /
  /// composition-only notifications. `null` means "everything may have changed"
  /// (e.g. after [replaceDocument] with no prior snapshot) — callers should
  /// treat that as a full rebuild.
  Set<String>? get lastChangedBlockIds => _lastChangedBlockIds;
  Set<String>? _lastChangedBlockIds;

  /// Requests keyboard focus for the editor, if one is attached. No-op when no
  /// [WenzRichTextEditor] is bound to this controller (e.g. in headless logic
  /// tests). The focus node is injected by the widget on mount.
  ///
  /// Returns `true` when focus was requested on an attached node, `false`
  /// otherwise.
  bool requestFocus() {
    final node = _focusNode;
    if (node == null) {
      return false;
    }
    node.requestFocus();
    return true;
  }

  /// Whether the editor currently has focus. `false` when no editor is
  /// attached.
  bool get hasFocus => _focusNode?.hasFocus ?? false;

  /// Injected by the editor widget so [requestFocus] / [hasFocus] can drive the
  /// editor's [FocusNode]. Internal; callers outside the package should not
  /// invoke this — the [WenzRichTextEditor] widget manages it on mount/dispose.
  @internal
  void attachFocusNode(FocusNode? node) {
    _focusNode = node;
  }

  void setSelection(DocumentSelection? selection) {
    final previous = session.selection;
    if (previous == selection) {
      return;
    }
    session.selection = selection;
    // Selection-only change: no block content changed.
    _lastChangedBlockIds = <String>{};
    onSelectionChanged?.call(selection);
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
    // Composition-only change: no block content changed.
    _lastChangedBlockIds = <String>{};
    notifyListeners();
  }

  void replaceDocument(
    RichTextDocument document, {
    DocumentSelection? selection,
    bool clearHistory = true,
  }) {
    final before = session.document;
    session.replaceDocument(document, nextSelection: selection);
    if (clearHistory) {
      session.history.clear();
    }
    _lastChangedBlockIds = _changedBlockIds(before, session.document);
    onChanged?.call(session.document);
    notifyListeners();
  }

  String toJson() => _richTextJsonCodec.encode(document);

  /// Exports the document as plain text with paragraphs separated by blank
  /// lines. Non-text blocks (image/video/file/divider) emit a short sentinel
  /// line so their position in the flow is still visible. See
  /// [PlainTextCodec] for the format and options.
  String toPlainText() => _plainTextCodec.encode(document);

  /// Exports the document as GitHub-Flavored Markdown. See [MarkdownCodec]
  /// for the supported block/inline syntax matrix.
  String toMarkdown() => _markdownCodec.encode(document);

  /// Exports the document as an HTML fragment. See [HtmlCodec] for the
  /// supported tag matrix.
  String toHtml() => _htmlCodec.encode(document);

  /// Loads a document from an HTML fragment, replacing the current document,
  /// clearing history, and firing [onChanged]. HTML5's leniency means
  /// unrecognised / malformed content falls back to paragraphs, so this does
  /// not throw for content. For a no-throw entry point, use [tryLoadHtml].
  void loadHtml(String source, {DocumentSelection? selection}) {
    replaceDocument(_htmlCodec.decode(source), selection: selection);
  }

  /// No-throw variant of [loadHtml]. Returns a [TryLoadResult] (`ok` /
  /// `document?` / `error?`); on failure the current document, selection,
  /// history, and change callbacks are untouched.
  TryLoadResult tryLoadHtml(String source, {DocumentSelection? selection}) {
    try {
      final nextDocument = _htmlCodec.decode(source);
      replaceDocument(nextDocument, selection: selection);
      return TryLoadResult.ok(nextDocument);
    } on Object catch (error) {
      return TryLoadResult.failed(error);
    }
  }

  /// Loads a document from GitHub-Flavored Markdown, replacing the current
  /// document, clearing history, and firing [onChanged]. Unrecognised lines
  /// fall back to paragraphs (Markdown's usual leniency), so this does not
  /// throw for content. For a no-throw entry point symmetric with
  /// [tryLoadJson], use [tryLoadMarkdown].
  void loadMarkdown(String source, {DocumentSelection? selection}) {
    replaceDocument(_markdownCodec.decode(source), selection: selection);
  }

  /// No-throw variant of [loadMarkdown]. Returns a [TryLoadResult] (`ok` /
  /// `document?` / `error?`); on failure the current document, selection,
  /// history, and change callbacks are untouched.
  TryLoadResult tryLoadMarkdown(String source, {DocumentSelection? selection}) {
    try {
      final nextDocument = _markdownCodec.decode(source);
      replaceDocument(nextDocument, selection: selection);
      return TryLoadResult.ok(nextDocument);
    } on Object catch (error) {
      return TryLoadResult.failed(error);
    }
  }

  /// Loads a document from JSON, replacing the current document, clearing
  /// history, and firing [onChanged]. Throws [DocumentDecodeException] when
  /// [source] is malformed (the originating error is preserved on
  /// [DocumentDecodeException.raw]); the current document and selection are
  /// left untouched on failure.
  ///
  /// Set [legacy] to `true` to decode legacy `wenz_editor` JSON via the
  /// [LegacyWenJsonCodec]. For a no-throw entry point, use [tryLoadJson].
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

  /// No-throw variant of [loadJson]. Decodes [source] and, on success,
  /// replaces the current document (firing [onChanged] exactly like
  /// [loadJson]). On failure returns a [TryLoadResult] with `ok: false` and
  /// the originating error on [TryLoadResult.error]; the current document,
  /// selection, history, and change callbacks are **not** touched.
  ///
  /// Use this from UI code paths that must not throw (e.g. paste/open-file
  /// handlers); use [loadJson] when you prefer typed exception handling.
  TryLoadResult tryLoadJson(
    String source, {
    bool legacy = false,
    DocumentSelection? selection,
  }) {
    try {
      final nextDocument = legacy
          ? _legacyWenJsonCodec.decode(source)
          : _richTextJsonCodec.decode(source);
      replaceDocument(nextDocument, selection: selection);
      return TryLoadResult.ok(nextDocument);
    } on Object catch (error) {
      return TryLoadResult.failed(error);
    }
  }

  ChangeSet execute(EditorCommand command) {
    final before = session.document;
    final change = _executor.execute(command);
    final docChanged = !change.isNoop;
    final selectionChanged = change.selectionBefore != change.selectionAfter;
    if (docChanged || selectionChanged) {
      _lastChangedBlockIds = _changedBlockIds(before, change.after);
      if (docChanged) {
        onChanged?.call(change.after);
      }
      if (selectionChanged) {
        onSelectionChanged?.call(change.selectionAfter);
      }
      onCommandExecuted?.call(command, change);
      notifyListeners();
    }
    return change;
  }

  /// Executes a named command registered via [registry]. Lets plugins run
  /// commands without a typed controller method. Throws
  /// [UnknownCommandException] if [name] is not registered (use
  /// [tryExecuteCommand] for a no-throw variant).
  ChangeSet executeCommand(String name, Map<String, Object?> args) {
    // Build the command via the registry, then route through [execute] so the
    // command/selection/document callbacks fire from a single dispatch point.
    return execute(registry.build(name, args));
  }

  /// No-throw variant of [executeCommand]. Returns `true` when the command
  /// was built and executed, `false` when [name] is unknown or argument
  /// decoding failed — in which case the document, selection, and change
  /// callbacks are untouched. Prefer [executeCommand] when you want unknown
  /// names to surface as an exception.
  bool tryExecuteCommand(String name, Map<String, Object?> args) {
    try {
      execute(registry.build(name, args));
      return true;
    } on UnknownCommandException {
      return false;
    } on DocumentDecodeException {
      return false;
    }
  }

  bool undo() {
    final selectionBefore = session.selection;
    final before = session.document;
    final changed = session.undo();
    if (changed) {
      _lastChangedBlockIds = _changedBlockIds(before, session.document);
      onChanged?.call(session.document);
      if (session.selection != selectionBefore) {
        onSelectionChanged?.call(session.selection);
      }
      notifyListeners();
    }
    return changed;
  }

  bool redo() {
    final selectionBefore = session.selection;
    final before = session.document;
    final changed = session.redo();
    if (changed) {
      _lastChangedBlockIds = _changedBlockIds(before, session.document);
      onChanged?.call(session.document);
      if (session.selection != selectionBefore) {
        onSelectionChanged?.call(session.selection);
      }
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

  /// Vertical ArrowUp/ArrowDown navigation inside a table cell. Moves to the
  /// same column in the adjacent visible row; a no-op at the table edge.
  ChangeSet moveTableCellVertical({required bool forward}) {
    return execute(
      MoveTableCellVerticalCommand(
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

  /// Moves the caret vertically (Up/Down arrow). At a block boundary it crosses
  /// to the neighbouring editable block; within a block it moves to the block
  /// end (Down) or start (Up). See [MoveCaretVerticalCommand].
  ChangeSet moveCaretVertical({
    required bool forward,
    bool expandSelection = false,
  }) {
    return execute(
      MoveCaretVerticalCommand(
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
  /// preserve attributes; rich blocks payloads (cross-block copy) restore the
  /// block structure; plain text is split on newlines — the first line inserts
  /// into the current block, each subsequent line creates a new block via
  /// [EnterCommand].
  void pasteText(String raw) {
    if (raw.isEmpty) {
      return;
    }
    final paste = clipboardService.parse(raw);
    if (paste.isBlocks) {
      execute(PasteBlocksCommand(paste.blocks, newBlockId: 'paste-${_pasteBlockCounter()}'));
      return;
    }
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

  /// Diffs [before] against [after] and returns the set of block ids whose
  /// rendering must refresh: every block id present in [after] whose
  /// lightweight fingerprint changed or that is newly added. Removed block ids
  /// are not included (there is nothing left to rebuild for them). Returns an
  /// empty set when the two documents are content-identical.
  ///
  /// The fingerprint is intentionally cheap (`type` + `plainText` + attributes
  /// JSON) — it catches text, structure, and attribute edits without a full
  /// deep compare or [BlockNode.toJson] on every block. It may produce a false
  /// positive (rebuild a block that did not visually change) but never a false
  /// negative, so correctness is preserved.
  Set<String> _changedBlockIds(RichTextDocument before, RichTextDocument after) {
    final beforeFingerprints = <String, String>{
      for (final block in before.blocks) block.id: _blockFingerprint(block),
    };
    final changed = <String>{};
    for (final block in after.blocks) {
      final previous = beforeFingerprints[block.id];
      if (previous == null || previous != _blockFingerprint(block)) {
        changed.add(block.id);
      }
    }
    return changed;
  }

  String _blockFingerprint(BlockNode block) {
    // The full JSON shape (including inline content + run attributes, table
    // cells, code language, media metadata) is the fingerprint. A coarser
    // fingerprint based only on type + plainText would miss inline attribute
    // changes (e.g. formatText toggling bold) and fail to mark the block dirty
    // for incremental rebuild, leaving stale spans rendered.
    return jsonEncode(block.toJson());
  }
}

/// Outcome of [WenzRichTextController.tryLoadJson]. Immutable; read [ok] to
/// branch, then either [document] (on success) or [error] (on failure). The
/// [error] is the originating exception (typically a
/// [DocumentDecodeException]) preserved verbatim so callers can inspect it.
class TryLoadResult {
  const TryLoadResult._({
    required this.ok,
    this.document,
    this.error,
  });

  /// Successful result carrying the decoded [document].
  factory TryLoadResult.ok(RichTextDocument document) =>
      TryLoadResult._(ok: true, document: document);

  /// Failed result carrying the originating [error].
  factory TryLoadResult.failed(Object error) =>
      TryLoadResult._(ok: false, error: error);

  /// Whether decoding succeeded.
  final bool ok;

  /// The decoded document. Non-null when [ok] is `true`.
  final RichTextDocument? document;

  /// The originating error. Non-null when [ok] is `false`.
  final Object? error;
}

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
import '../core/commands/inline_editing.dart';
import '../core/commands/markdown_shortcut_commands.dart';
import '../core/commands/revision_commands.dart';
import '../core/commands/selection_commands.dart';
import '../core/commands/style_commands.dart';
import '../core/commands/table_cell_editing.dart';
import '../core/commands/table_commands.dart';
import '../core/commands/text_commands.dart';
import '../core/model/attributes.dart';
import '../core/model/block_node.dart';
import '../core/model/document_version_snapshot.dart';
import '../core/model/inline_node.dart';
import '../core/model/revision_model.dart';
import '../core/model/rich_text_document.dart';
import '../core/position/document_position.dart';
import '../core/transaction/change_set.dart';
import '../core/transaction/document_session.dart';
import '../history/history_manager.dart';
import '../input/clipboard_debug_log.dart';
import '../input/clipboard_service.dart';
import '../input/composition_state.dart';
import '../input/external_image_input.dart';
import '../widgets/media_resolver.dart';
import 'document_export_snapshot.dart';

final RegExp _autoLinkCandidateRegex = RegExp(
  r'(?:(?:https?)://|www\.)',
  caseSensitive: false,
);

const String _autoLinkTriggerCharacters = ' \t\n\r,!?;:)]}，。！？；：、';

enum ExternalImagePasteStatus {
  inserted,
  emptyInput,
  noInsertableImages,
  permissionDenied,
  unchanged,
}

class ExternalImagePasteResult {
  const ExternalImagePasteResult._({
    required this.status,
    required this.insertedImageCount,
    this.change,
  });

  const ExternalImagePasteResult.emptyInput()
      : this._(
          status: ExternalImagePasteStatus.emptyInput,
          insertedImageCount: 0,
        );

  const ExternalImagePasteResult.noInsertableImages()
      : this._(
          status: ExternalImagePasteStatus.noInsertableImages,
          insertedImageCount: 0,
        );

  factory ExternalImagePasteResult.fromChange(
    ChangeSet change, {
    required int insertedImageCount,
  }) {
    if (change.metadata?['reason'] == 'permissionDenied') {
      return ExternalImagePasteResult._(
        status: ExternalImagePasteStatus.permissionDenied,
        insertedImageCount: 0,
        change: change,
      );
    }
    if (change.isNoop) {
      return ExternalImagePasteResult._(
        status: ExternalImagePasteStatus.unchanged,
        insertedImageCount: 0,
        change: change,
      );
    }
    return ExternalImagePasteResult._(
      status: ExternalImagePasteStatus.inserted,
      insertedImageCount: insertedImageCount,
      change: change,
    );
  }

  final ExternalImagePasteStatus status;
  final int insertedImageCount;
  final ChangeSet? change;

  bool get isSuccess => status == ExternalImagePasteStatus.inserted;

  bool get isFailure => !isSuccess;
}

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
    WenzEditorPermission permission = WenzEditorPermission.edit,
  })  : session = DocumentSession(
          document: document,
          selection: selection,
          history: history,
        ),
        _richTextJsonCodec = richTextJsonCodec,
        _legacyWenJsonCodec = legacyWenJsonCodec,
        _plainTextCodec = plainTextCodec,
        _markdownCodec = markdownCodec,
        _htmlCodec = htmlCodec,
        _permission = permission {
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

  /// Current command permission policy for this controller.
  WenzEditorPermission get permission => _permission;
  WenzEditorPermission _permission;

  set permission(WenzEditorPermission value) {
    if (_permission == value) {
      return;
    }
    _permission = value;
    _lastChangedBlockIds = <String>{};
    _lastDocumentChangeSummary = DocumentChangeSummary.none;
    notifyListeners();
  }

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

  bool get isApplyingComposingTextInput => _isApplyingComposingTextInput;
  bool _isApplyingComposingTextInput = false;

  bool get lastChangeWasCompositionOnly => _lastChangeWasCompositionOnly;
  bool _lastChangeWasCompositionOnly = false;

  int _inputUpdateBatchDepth = 0;
  bool _hasPendingInputUpdateNotification = false;
  Set<String>? _batchedInputChangedBlockIds;
  DocumentChangeSummary? _batchedInputChangeSummary;
  bool _batchedInputHasNonCompositionChange = false;

  RichTextDocument get document => session.document;

  DocumentSelection? get selection => session.selection;

  bool get canRead => _permission.allows(WenzEditorPermission.read);

  bool get canComment => _permission.allows(WenzEditorPermission.comment);

  bool get canEdit => _permission.allows(WenzEditorPermission.edit);

  bool get canUndo => canEdit && session.canUndo;

  bool get canRedo => canEdit && session.canRedo;

  bool get revisionModeEnabled => _revisionModeEnabled;
  bool _revisionModeEnabled = false;

  String? get revisionAuthorId => _revisionAuthorId;
  String? _revisionAuthorId;

  String? get revisionAuthorName => _revisionAuthorName;
  String? _revisionAuthorName;
  int _revisionIdCounter = 0;

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

  /// Structured mutation metadata for the most recent notification.
  /// Selection-, permission-, and composition-only notifications expose
  /// [DocumentChangeSummary.none].
  DocumentChangeSummary? get lastDocumentChangeSummary =>
      _lastDocumentChangeSummary;
  DocumentChangeSummary? _lastDocumentChangeSummary;

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
    _lastDocumentChangeSummary = DocumentChangeSummary.none;
    _lastChangeWasCompositionOnly = false;
    onSelectionChanged?.call(selection);
    _notifyInputAwareListeners(
      documentChanged: false,
      compositionOnly: false,
    );
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
    _lastDocumentChangeSummary = DocumentChangeSummary.none;
    _lastChangeWasCompositionOnly = true;
    _notifyInputAwareListeners(
      documentChanged: false,
      compositionOnly: true,
    );
  }

  void runWithComposingTextInput(VoidCallback action) {
    final previous = _isApplyingComposingTextInput;
    _isApplyingComposingTextInput = true;
    try {
      action();
    } finally {
      _isApplyingComposingTextInput = previous;
    }
  }

  void runWithInputUpdate(VoidCallback action) {
    final isOuterBatch = _inputUpdateBatchDepth == 0;
    if (isOuterBatch) {
      _hasPendingInputUpdateNotification = false;
      _batchedInputChangedBlockIds = null;
      _batchedInputChangeSummary = null;
      _batchedInputHasNonCompositionChange = false;
    }
    _inputUpdateBatchDepth += 1;
    try {
      action();
    } finally {
      _inputUpdateBatchDepth -= 1;
      if (isOuterBatch) {
        _flushInputUpdateNotification();
      }
    }
  }

  void _notifyInputAwareListeners({
    required bool documentChanged,
    required bool compositionOnly,
  }) {
    if (_inputUpdateBatchDepth == 0) {
      notifyListeners();
      return;
    }
    _hasPendingInputUpdateNotification = true;
    if (documentChanged) {
      final changedBlockIds = _lastChangedBlockIds;
      final batched = _batchedInputChangedBlockIds ?? <String>{};
      if (changedBlockIds != null) {
        batched.addAll(changedBlockIds);
      }
      _batchedInputChangedBlockIds = batched;
      final summary = _lastDocumentChangeSummary;
      if (summary != null) {
        final previousSummary = _batchedInputChangeSummary;
        _batchedInputChangeSummary = previousSummary == null
            ? summary
            : DocumentChangeSummary.merge(previousSummary, summary);
      }
    }
    if (!compositionOnly) {
      _batchedInputHasNonCompositionChange = true;
    }
  }

  void _flushInputUpdateNotification() {
    if (!_hasPendingInputUpdateNotification) {
      return;
    }
    final changedBlockIds = _batchedInputChangedBlockIds;
    if (changedBlockIds != null) {
      _lastChangedBlockIds = changedBlockIds;
    }
    final changeSummary = _batchedInputChangeSummary;
    if (changeSummary != null) {
      _lastDocumentChangeSummary = changeSummary;
    }
    _lastChangeWasCompositionOnly = !_batchedInputHasNonCompositionChange;
    _hasPendingInputUpdateNotification = false;
    _batchedInputChangedBlockIds = null;
    _batchedInputChangeSummary = null;
    _batchedInputHasNonCompositionChange = false;
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
    _lastDocumentChangeSummary = DocumentChangeSummary.between(
      before,
      session.document,
      documentChanged: !identical(before, session.document),
    );
    _lastChangedBlockIds = _lastDocumentChangeSummary!.changedBlockIds;
    _lastChangeWasCompositionOnly = false;
    onChanged?.call(session.document);
    notifyListeners();
  }

  void setRevisionMode(
    bool enabled, {
    String? authorId,
    String? authorName,
  }) {
    if (_revisionModeEnabled == enabled &&
        _revisionAuthorId == authorId &&
        _revisionAuthorName == authorName) {
      return;
    }
    _revisionModeEnabled = enabled;
    _revisionAuthorId = authorId;
    _revisionAuthorName = authorName;
    _lastChangedBlockIds = <String>{};
    _lastDocumentChangeSummary = DocumentChangeSummary.none;
    notifyListeners();
  }

  /// Creates an immutable, application-owned version snapshot for the current
  /// document. The snapshot list/storage remains outside the editor core.
  DocumentVersionSnapshot createVersionSnapshot({
    required String id,
    DateTime? createdAt,
    String? authorId,
    String? authorName,
    String? description,
    String? baseSnapshotId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return DocumentVersionSnapshot(
      id: id,
      document: document,
      createdAt: createdAt ?? DateTime.now(),
      authorId: authorId,
      authorName: authorName,
      description: description,
      baseSnapshotId: baseSnapshotId,
      metadata: metadata,
    );
  }

  /// Restores [snapshot] into the editor via [replaceDocument].
  void restoreVersionSnapshot(
    DocumentVersionSnapshot snapshot, {
    DocumentSelection? selection,
    bool clearHistory = true,
  }) {
    replaceDocument(
      snapshot.restoreDocument(),
      selection: selection,
      clearHistory: clearHistory,
    );
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

  /// Encodes JSON, Markdown, and plain text from the same document revision.
  Future<DocumentExportSnapshot> exportSnapshot({bool useIsolate = false}) {
    return buildDocumentExportSnapshot(document, useIsolate: useIsolate);
  }

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

  /// Auto-detects the JSON format of [source] and loads it.
  ///
  /// This is the lazy-migration entry point for hosts (like wenzflow) that
  /// store documents from an older editor alongside documents written by this
  /// editor. It inspects the parsed JSON root:
  ///
  ///   - top-level array  → legacy `wenz_editor` format (decoded via
  ///     [LegacyWenJsonCodec]).
  ///   - top-level object → current Rich JSON (decoded via
  ///     [RichTextJsonCodec]).
  ///
  /// On success the document is replaced (history cleared, [onChanged] fired)
  /// and the result carries the detected [JsonLoadFormat] so the host can
  /// decide whether to re-persist the document in the new format. On failure
  /// the current document, selection, history, and change callbacks are left
  /// untouched, exactly like [tryLoadJson].
  ///
  /// Hosts implementing lazy migration should:
  ///   1. load with this method,
  ///   2. keep the editor bound to `toJson()` for saves (always emits the new
  ///      Rich JSON format), so the note is upgraded the first time it is
  ///      edited and re-saved.
  TryLoadJsonAutoResult tryLoadJsonAuto(
    String source, {
    DocumentSelection? selection,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on Object catch (error) {
      return TryLoadJsonAutoResult.failed(error);
    }
    final isLegacy = decoded is List;
    try {
      final nextDocument = isLegacy
          ? _legacyWenJsonCodec.decode(source)
          : _richTextJsonCodec.decode(source);
      replaceDocument(nextDocument, selection: selection);
      return TryLoadJsonAutoResult.ok(
        nextDocument,
        format: isLegacy ? JsonLoadFormat.legacy : JsonLoadFormat.current,
      );
    } on Object catch (error) {
      return TryLoadJsonAutoResult.failed(error);
    }
  }

  ChangeSet execute(EditorCommand command) {
    if (!canExecute(command)) {
      return _permissionDeniedChange(command);
    }
    final change = _executor.execute(command);
    final docChanged = !change.isNoop;
    final selectionChanged = change.selectionBefore != change.selectionAfter;
    if (docChanged || selectionChanged) {
      _lastChangedBlockIds = change.changedBlockIds;
      _lastDocumentChangeSummary = change.changeSummary;
      _lastChangeWasCompositionOnly = false;
      if (docChanged) {
        onChanged?.call(change.after);
      }
      if (selectionChanged) {
        onSelectionChanged?.call(change.selectionAfter);
      }
      onCommandExecuted?.call(command, change);
      _notifyInputAwareListeners(
        documentChanged: docChanged,
        compositionOnly: false,
      );
    }
    return change;
  }

  bool canExecute(EditorCommand command) {
    return _permission.allows(command.requiredPermission);
  }

  ChangeSet _permissionDeniedChange(EditorCommand command) {
    final before = session.document;
    final requiredPermission = command.requiredPermission;
    return ChangeSet(
      before: before,
      after: before,
      selectionBefore: session.selection,
      selectionAfter: session.selection,
      description: 'permission:blocked:${command.description}',
      metadata: <String, Object?>{
        'blocked': true,
        'reason': 'permissionDenied',
        'permission': _permission.name,
        'requiredPermission': requiredPermission.name,
        'command': command.description,
      },
      changeSummary: DocumentChangeSummary.none,
    );
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

  bool canExecuteCommand(String name, Map<String, Object?> args) {
    try {
      return canExecute(registry.build(name, args));
    } on UnknownCommandException {
      return false;
    } on DocumentDecodeException {
      return false;
    }
  }

  /// No-throw variant of [executeCommand]. Returns `true` when the command
  /// was built and executed, `false` when [name] is unknown or argument
  /// decoding failed — in which case the document, selection, and change
  /// callbacks are untouched. Prefer [executeCommand] when you want unknown
  /// names to surface as an exception.
  bool tryExecuteCommand(String name, Map<String, Object?> args) {
    try {
      final command = registry.build(name, args);
      if (!canExecute(command)) {
        return false;
      }
      execute(command);
      return true;
    } on UnknownCommandException {
      return false;
    } on DocumentDecodeException {
      return false;
    }
  }

  bool undo() {
    if (!canEdit) {
      return false;
    }
    final selectionBefore = session.selection;
    final before = session.document;
    final changed = session.undo();
    if (changed) {
      _lastDocumentChangeSummary = DocumentChangeSummary.between(
        before,
        session.document,
        documentChanged: !identical(before, session.document),
      );
      _lastChangedBlockIds = _lastDocumentChangeSummary!.changedBlockIds;
      _lastChangeWasCompositionOnly = false;
      onChanged?.call(session.document);
      if (session.selection != selectionBefore) {
        onSelectionChanged?.call(session.selection);
      }
      notifyListeners();
    }
    return changed;
  }

  bool redo() {
    if (!canEdit) {
      return false;
    }
    final selectionBefore = session.selection;
    final before = session.document;
    final changed = session.redo();
    if (changed) {
      _lastDocumentChangeSummary = DocumentChangeSummary.between(
        before,
        session.document,
        documentChanged: !identical(before, session.document),
      );
      _lastChangedBlockIds = _lastDocumentChangeSummary!.changedBlockIds;
      _lastChangeWasCompositionOnly = false;
      onChanged?.call(session.document);
      if (session.selection != selectionBefore) {
        onSelectionChanged?.call(session.selection);
      }
      notifyListeners();
    }
    return changed;
  }

  ChangeSet insertRevisionText(
    String text, {
    TextAttributes attributes = const TextAttributes(),
    DocumentSelection? selection,
    String? revisionId,
    String? authorId,
    String? authorName,
    DateTime? createdAt,
  }) {
    if (text.isEmpty) {
      return execute(
        InsertRevisionTextCommand(
          text,
          revisionId: revisionId ?? '',
          attributes: attributes,
          selection: selection,
          authorId: authorId ?? _revisionAuthorId,
          authorName: authorName ?? _revisionAuthorName,
          createdAt: createdAt,
        ),
      );
    }
    final target = selection ?? this.selection;
    ChangeSet? deletionChange;
    if (target != null && !target.isCollapsed) {
      deletionChange = markDeletionRevision(
        selection: target,
        authorId: authorId,
        authorName: authorName,
        createdAt: createdAt,
      );
      if (deletionChange.isNoop) {
        return deletionChange;
      }
    }
    final insertionSelection =
        target != null && target.isCollapsed ? target : null;
    final insertionChange = execute(
      InsertRevisionTextCommand(
        text,
        revisionId: revisionId ?? _nextRevisionId(RevisionChangeType.insert),
        attributes: attributes,
        selection: insertionSelection,
        authorId: authorId ?? _revisionAuthorId,
        authorName: authorName ?? _revisionAuthorName,
        createdAt: createdAt,
      ),
    );
    if (insertionChange.isNoop && deletionChange != null) {
      return deletionChange;
    }
    return insertionChange;
  }

  ChangeSet markDeletionRevision({
    DocumentSelection? selection,
    String? revisionId,
    String? authorId,
    String? authorName,
    DateTime? createdAt,
  }) {
    return execute(
      MarkDeletionRevisionCommand(
        revisionId: revisionId ?? _nextRevisionId(RevisionChangeType.delete),
        selection: selection,
        authorId: authorId ?? _revisionAuthorId,
        authorName: authorName ?? _revisionAuthorName,
        createdAt: createdAt,
      ),
    );
  }

  ChangeSet markFormatRevision(
    TextAttributes attributes, {
    DocumentSelection? selection,
    String? revisionId,
    String? authorId,
    String? authorName,
    DateTime? createdAt,
  }) {
    return execute(
      MarkFormatRevisionCommand(
        revisionId: revisionId ?? _nextRevisionId(RevisionChangeType.format),
        attributes: attributes,
        selection: selection,
        authorId: authorId ?? _revisionAuthorId,
        authorName: authorName ?? _revisionAuthorName,
        createdAt: createdAt,
      ),
    );
  }

  ChangeSet acceptRevision(String revisionId, {DateTime? resolvedAt}) {
    return execute(AcceptRevisionCommand(revisionId, resolvedAt: resolvedAt));
  }

  ChangeSet rejectRevision(String revisionId, {DateTime? resolvedAt}) {
    return execute(RejectRevisionCommand(revisionId, resolvedAt: resolvedAt));
  }

  ChangeSet insertText(
    String text, {
    TextAttributes attributes = const TextAttributes(),
    bool applyMarkdownShortcuts = true,
    bool applyAutoLinkUrls = true,
  }) {
    if (_revisionModeEnabled) {
      return insertRevisionText(text, attributes: attributes);
    }
    final change = execute(InsertTextCommand(text, attributes: attributes));
    var latestChange = change;
    if (_shouldApplyMarkdownShortcut(
      text,
      attributes,
      applyMarkdownShortcuts,
      change,
    )) {
      final shortcutChange = execute(const ApplyMarkdownShortcutCommand());
      if (!shortcutChange.isNoop) {
        latestChange = shortcutChange;
      }
    }
    if (_shouldApplyAutoLinkUrls(
      text,
      attributes,
      applyAutoLinkUrls,
      latestChange,
    )) {
      final autoLinkChange = autoLinkUrls();
      if (!autoLinkChange.isNoop) {
        return autoLinkChange;
      }
    }
    return latestChange;
  }

  bool _shouldApplyMarkdownShortcut(
    String text,
    TextAttributes attributes,
    bool enabled,
    ChangeSet change,
  ) {
    if (!enabled || change.isNoop || !attributes.isEmpty || text.length != 1) {
      return false;
    }
    return text == ' ' || text == '-' || text == '`';
  }

  bool _shouldApplyAutoLinkUrls(
    String text,
    TextAttributes attributes,
    bool enabled,
    ChangeSet change,
  ) {
    if (!enabled || change.isNoop || attributes.url != null) {
      return false;
    }
    if (_autoLinkCandidateRegex.hasMatch(text)) {
      return true;
    }
    if (!_containsAutoLinkTrigger(text)) {
      return false;
    }
    return _currentTextScopeHasAutoLinkCandidate();
  }

  bool _containsAutoLinkTrigger(String text) {
    for (final codePoint in text.runes) {
      if (_autoLinkTriggerCharacters.contains(String.fromCharCode(codePoint))) {
        return true;
      }
    }
    return false;
  }

  bool _currentTextScopeHasAutoLinkCandidate() {
    final target = selection;
    if (target == null ||
        target.start.blockIndex != target.end.blockIndex ||
        target.start.path != target.end.path) {
      return false;
    }
    final position = target.extent;
    if (position.blockIndex < 0 ||
        position.blockIndex >= document.blocks.length) {
      return false;
    }
    final block = document.blocks[position.blockIndex];
    if (position.path.isBlockText && block is TextBlockNode) {
      return _autoLinkCandidateRegex.hasMatch(block.plainText);
    }
    if (position.path.isTableCellText) {
      final textBlock = tableCellTextBlockForPosition(document, position);
      return textBlock != null &&
          _autoLinkCandidateRegex.hasMatch(textBlock.plainText);
    }
    return false;
  }

  ChangeSet deleteSelection([DocumentSelection? selection]) {
    if (_revisionModeEnabled) {
      return markDeletionRevision(selection: selection);
    }
    return execute(DeleteSelectionCommand(selection));
  }

  ChangeSet deleteBackward() {
    if (_revisionModeEnabled) {
      return markDeletionRevision(
        selection: _singleCharacterRevisionSelection(forward: false),
      );
    }
    return execute(const DeleteBackwardCommand());
  }

  ChangeSet deleteForward() {
    if (_revisionModeEnabled) {
      return markDeletionRevision(
        selection: _singleCharacterRevisionSelection(forward: true),
      );
    }
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

  ChangeSet setTodoChecked({required int blockIndex, required bool checked}) {
    return execute(
      SetTodoCheckedCommand(blockIndex: blockIndex, checked: checked),
    );
  }

  ChangeSet toggleQuote() {
    return execute(const ToggleQuoteCommand());
  }

  ChangeSet setCodeLanguage(String language, {int? blockIndex}) {
    return execute(SetCodeLanguageCommand(language, blockIndex: blockIndex));
  }

  ChangeSet setCalloutVariant(String variant, {int? blockIndex}) {
    return execute(SetCalloutVariantCommand(variant, blockIndex: blockIndex));
  }

  ChangeSet updateCalloutBlock({
    int? blockIndex,
    String? variant,
    String? title,
    String? icon,
  }) {
    return execute(
      UpdateCalloutBlockCommand(
        blockIndex: blockIndex,
        variant: variant,
        title: title,
        icon: icon,
      ),
    );
  }

  ChangeSet indentCodeBlock({
    bool outdent = false,
    String indent = '  ',
    DocumentSelection? selection,
  }) {
    return execute(
      IndentCodeBlockCommand(
        outdent: outdent,
        indent: indent,
        selection: selection,
      ),
    );
  }

  ChangeSet insertCallout({
    required String blockId,
    String variant = 'info',
    String title = '',
    String icon = '',
    List<InlineNode> content = const <InlineNode>[],
    DocumentSelection? selection,
  }) {
    final insertionIndex = document.blocks.length;
    final defaultPosition = DocumentPosition(
      blockId: blockId,
      blockIndex: insertionIndex,
      path: PositionPath.blockText(blockId),
      offset: 0,
    );
    return insertBlocks(
      index: insertionIndex,
      blocks: <BlockNode>[
        CalloutBlockNode(
          id: blockId,
          content: content,
          variant: variant,
          title: title,
          icon: icon,
        ),
      ],
      selection: selection ??
          DocumentSelection(
            base: defaultPosition,
            extent: defaultPosition,
          ),
    );
  }

  ChangeSet insertImage({
    int? index,
    required String blockId,
    String assetId = '',
    String file = '',
    int width = 0,
    int height = 0,
    double? showWidth,
    double? showHeight,
    String caption = '',
    String altText = '',
    DocumentSelection? selection,
  }) {
    return execute(
      _InsertImageBlockCommand(
        index: index ?? _currentBlockInsertionIndex(),
        blockId: blockId,
        assetId: assetId,
        file: file,
        width: width,
        height: height,
        showWidth: showWidth,
        showHeight: showHeight,
        caption: caption,
        altText: altText,
        selection: selection,
      ),
    );
  }

  ChangeSet insertVideo({
    int? index,
    required String blockId,
    String assetId = '',
    String playbackUrl = '',
    String file = '',
    String coverUrl = '',
    String title = '',
    String description = '',
    double? aspectRatio,
    double? showWidth,
    double? showHeight,
    FileUploadStatus uploadStatus = FileUploadStatus.none,
    String uploadError = '',
    DocumentSelection? selection,
  }) {
    return execute(
      InsertVideoBlockCommand(
        index: index ?? _currentBlockInsertionIndex(),
        blockId: blockId,
        assetId: assetId,
        playbackUrl: playbackUrl,
        file: file,
        coverUrl: coverUrl,
        title: title,
        description: description,
        aspectRatio: aspectRatio,
        showWidth: showWidth,
        showHeight: showHeight,
        uploadStatus: uploadStatus,
        uploadError: uploadError,
        selection: selection,
      ),
    );
  }

  ChangeSet insertFile({
    int? index,
    required String blockId,
    required String assetId,
    String name = '',
    int size = 0,
    String mimeType = '',
    String file = '',
    String downloadUrl = '',
    FileUploadStatus uploadStatus = FileUploadStatus.none,
    String uploadError = '',
    DocumentSelection? selection,
  }) {
    return insertBlocks(
      index: index ?? document.blocks.length,
      blocks: <BlockNode>[
        FileBlockNode(
          id: blockId,
          assetId: assetId,
          name: name,
          size: size,
          mimeType: mimeType,
          file: file,
          downloadUrl: downloadUrl,
          uploadStatus: uploadStatus,
          uploadError: uploadError,
        ),
      ],
      selection: selection,
    );
  }

  ChangeSet insertBlockEmbed({
    int? index,
    required String blockId,
    required String embedType,
    Map<String, Object?> data = const <String, Object?>{},
    String fallbackText = '',
    DocumentSelection? selection,
  }) {
    return insertBlocks(
      index: index ?? document.blocks.length,
      blocks: <BlockNode>[
        BlockEmbedNode(
          id: blockId,
          embedType: embedType,
          data: data,
          fallbackText: fallbackText,
        ),
      ],
      selection: selection,
    );
  }

  /// Updates a custom block embed ([BlockEmbedNode]) in place — its [data],
  /// [fallbackText], and/or [embedType] — without changing the block's id or
  /// position. This is the embed counterpart to [updateImageBlock] /
  /// [updateVideoBlock] / [updateFileBlock]: a business renderer (e.g. a
  /// flowchart view whose nodes were just dragged) writes the new payload back
  /// through this helper so the change flows through the command layer
  /// (undo/redo history, [onChanged], [onCommandExecuted]) and the edit
  /// permission gate, just like the typed media helpers.
  ///
  /// Each nullable field means "leave unchanged": a non-null [data] *replaces*
  /// the whole data map (it is not deep-merged), so callers pass the full
  /// updated payload. Rich JSON round-trips `data` verbatim; HTML / Markdown /
  /// plain-text exports degrade via [BlockEmbedNode.displayText] /
  /// `fallbackText`, exactly as on insert.
  ///
  /// A missing [blockId], a block that is not a [BlockEmbedNode], all three
  /// fields being `null`, or an update that leaves the block unchanged is a
  /// no-op: it returns an empty [ChangeSet] (`isNoop == true`) without throwing
  /// or recording history. Under [WenzEditorPermission.read] a real update is
  /// blocked by the gate (returns a blocked [ChangeSet], document untouched).
  ChangeSet updateBlockEmbed({
    required String blockId,
    Map<String, Object?>? data,
    String? fallbackText,
    String? embedType,
    DocumentSelection? selection,
  }) {
    final blockIndex = document.blocks.indexWhere(
      (block) => block.id == blockId,
    );
    if (blockIndex < 0) {
      return _noopChangeSet();
    }
    final block = document.blocks[blockIndex];
    if (block is! BlockEmbedNode) {
      return _noopChangeSet();
    }
    if (data == null && fallbackText == null && embedType == null) {
      return _noopChangeSet();
    }
    final nextBlock = block.copyWith(
      embedType: embedType,
      data: data,
      fallbackText: fallbackText,
    );
    if (_sameBlockContent(block, nextBlock)) {
      return _noopChangeSet();
    }
    return replaceBlocks(
      index: blockIndex,
      deleteCount: 1,
      blocks: <BlockNode>[nextBlock],
      selection: selection,
    );
  }

  /// Builds an empty (no-op) [ChangeSet] over the current document — two equal
  /// snapshots so [ChangeSet.isNoop] is `true`. Used by helpers that bail out
  /// without mutating (e.g. [updateBlockEmbed] on a missing/unchanged block) to
  /// avoid recording history or firing change callbacks.
  ChangeSet _noopChangeSet() {
    final snapshot = session.document;
    return ChangeSet(
      before: snapshot,
      after: snapshot,
      selectionBefore: session.selection,
      selectionAfter: session.selection,
      changeSummary: DocumentChangeSummary.none,
    );
  }

  /// Builds a structured copy payload for the current selection. Does not
  /// touch the platform clipboard — the caller writes the prepared
  /// internal/HTML/plain flavours through its clipboard adapter.
  ClipboardCopyPayload? copySelectionPayload([DocumentSelection? selection]) {
    final target = selection ?? this.selection;
    return clipboardService.copyPayload(document, target);
  }

  /// Serialises the current selection into the legacy clipboard string.
  /// Returns `null` when nothing is selected. Does not touch the platform
  /// clipboard — the caller writes the result via `Clipboard.setData`.
  String? copySelection([DocumentSelection? selection]) {
    return copySelectionPayload(selection)?.legacyText;
  }

  String? copyVideoBlock({required int blockIndex}) {
    final selection = _objectSelectionForBlockIndex(
      blockIndex,
      type: BlockType.video,
    );
    if (selection == null) {
      return null;
    }
    return copySelection(selection);
  }

  /// Builds the current selection's structured clipboard payload, then deletes
  /// that selection. Returns `null` when nothing valid is selected.
  ClipboardCopyPayload? cutSelectionPayload([DocumentSelection? selection]) {
    final payload = copySelectionPayload(selection);
    if (payload != null) {
      deleteSelection(selection);
    }
    return payload;
  }

  /// Copy then delete using the legacy clipboard string.
  ///
  /// Prefer [cutSelectionPayload] for editor clipboard integrations so the
  /// private Wenz, HTML, and readable plain-text flavours are all preserved.
  String? cutSelection([DocumentSelection? selection]) {
    return cutSelectionPayload(selection)?.legacyText;
  }

  /// Pastes a clipboard payload at the current selection. Rich inline payloads
  /// preserve attributes; rich blocks payloads (cross-block copy) restore the
  /// block structure; plain text normally splits on newlines — the first line
  /// inserts into the current block, each subsequent line creates a new block
  /// via [EnterCommand]. Plain text pasted into a code block is inserted as one
  /// command so newlines remain inside the same [CodeBlockNode].
  void pasteText(String raw) {
    if (raw.isEmpty) {
      return;
    }
    _pasteClipboard(
      clipboardService.parse(raw),
      allowCodeBlockPlainTextFastPath: true,
    );
  }

  /// Applies an already parsed clipboard value.
  ///
  /// The widget layer uses this after validating the preferred private format,
  /// allowing it to fall back to HTML or plain text when private clipboard data
  /// is corrupt instead of turning the paste into an empty no-op.
  void pasteParsedClipboard(ClipboardPaste paste) {
    _pasteClipboard(
      paste,
      allowCodeBlockPlainTextFastPath: true,
    );
  }

  /// Pastes a known Markdown clipboard fragment through the same pipeline as
  /// rich/plain text paste.
  void pasteMarkdown(String markdown) {
    if (markdown.isEmpty) {
      return;
    }
    _pasteClipboard(
      clipboardService.parse(
        markdown,
        format: ClipboardPasteFormat.markdown,
      ),
      allowCodeBlockPlainTextFastPath: false,
    );
  }

  /// Pastes a known HTML clipboard fragment through the same pipeline as
  /// rich/plain text paste.
  void pasteHtml(String html) {
    if (html.isEmpty) {
      return;
    }
    _pasteClipboard(
      clipboardService.parse(
        html,
        format: ClipboardPasteFormat.html,
      ),
      allowCodeBlockPlainTextFastPath: false,
    );
  }

  /// Returns a table-cell matrix only when the current paste target is inside
  /// a table cell. The clipboard parser deliberately keeps the original paste
  /// flavour alongside this matrix, so callers outside a table continue to use
  /// the established rich/block/plain-text paste paths.
  ClipboardTableCellMatrix? tableCellMatrixForPaste(ClipboardPaste paste) {
    final target = selection;
    if (target == null || !target.extent.path.isTableCellText) {
      return null;
    }
    return paste.tableCellMatrix;
  }

  ExternalImagePasteResult pasteExternalImages(
    List<ExternalImageBlockDescription> images, {
    DocumentSelection? selection,
  }) {
    if (images.isEmpty) {
      return const ExternalImagePasteResult.emptyInput();
    }
    final paste = clipboardService.parseExternalImages(
      images,
      newBlockId: () => 'external-image-${_pasteBlockCounter()}',
    );
    if (paste == null || !paste.isBlocks || paste.blocks.isEmpty) {
      return const ExternalImagePasteResult.noInsertableImages();
    }
    final change = _pasteExternalImageBlocks(
      paste.blocks,
      selection: selection,
    );
    return ExternalImagePasteResult.fromChange(
      change,
      insertedImageCount: paste.blocks.length,
    );
  }

  ChangeSet _pasteExternalImageBlocks(
    List<BlockNode> blocks, {
    DocumentSelection? selection,
  }) {
    final effectiveSelection =
        _normalizedExternalImagePasteSelection(selection) ??
            _normalizedExternalImagePasteSelection(session.selection);
    final selectionOverride = selection != null &&
            effectiveSelection != null &&
            effectiveSelection != session.selection
        ? effectiveSelection
        : null;
    if (effectiveSelection == null ||
        _shouldInsertExternalImageBlocksDirectly(
          effectiveSelection,
          explicitSelection: selectionOverride != null,
        )) {
      return _insertExternalImageBlocksAt(
        _currentBlockInsertionIndexForSelection(effectiveSelection),
        blocks,
        targetSelection: selectionOverride,
      );
    }
    final command = PasteBlocksCommand(
      blocks,
      newBlockId: 'paste-${_pasteBlockCounter()}',
    );
    return selectionOverride == null
        ? execute(command)
        : execute(
            _SelectionScopedCommand(
              targetSelection: selectionOverride,
              delegate: command,
            ),
          );
  }

  ChangeSet _insertExternalImageBlocksAt(
    int index,
    List<BlockNode> blocks, {
    DocumentSelection? targetSelection,
  }) {
    final command = InsertBlocksCommand(
      index: index,
      blocks: blocks,
      selection: _selectionForExternalImageBlock(
        blocks.last,
        index + blocks.length - 1,
      ),
    );
    return targetSelection == null
        ? execute(command)
        : execute(
            _SelectionScopedCommand(
              targetSelection: targetSelection,
              delegate: command,
            ),
          );
  }

  void _pasteClipboard(
    ClipboardPaste paste, {
    required bool allowCodeBlockPlainTextFastPath,
  }) {
    WenzClipboardDebugLog.event(
      'controller.paste-dispatch',
      fields: <String, Object?>{
        'kind': paste.isBlocks
            ? 'blocks'
            : paste.isRich
                ? 'inline'
                : 'plain',
        'blockCount': paste.blocks.length,
        'blockTypes': paste.blocks.map((block) => block.type.name).join(','),
        'inlineRunCount': paste.inlineRuns.length,
        'text': WenzClipboardDebugLog.text(paste.text),
        'selection': WenzClipboardDebugLog.selection(selection),
        'allowCodeFastPath': allowCodeBlockPlainTextFastPath,
      },
    );
    if (paste.isBlocks) {
      execute(PasteBlocksCommand(paste.blocks,
          newBlockId: 'paste-${_pasteBlockCounter()}'));
      WenzClipboardDebugLog.event(
        'controller.paste-applied',
        fields: <String, Object?>{
          'branch': 'blocks',
          'documentBlocks': document.blocks.length,
          'selection': WenzClipboardDebugLog.selection(selection),
        },
      );
      return;
    }
    if (paste.isRich) {
      _pasteInline(paste.inlineRuns);
      notifyListeners();
      WenzClipboardDebugLog.event(
        'controller.paste-applied',
        fields: <String, Object?>{
          'branch': 'inline',
          'documentBlocks': document.blocks.length,
          'selection': WenzClipboardDebugLog.selection(selection),
        },
      );
      return;
    }
    final text = paste.text;
    if (text.isEmpty) {
      WenzClipboardDebugLog.event(
        'controller.paste-skipped',
        fields: const <String, Object?>{'reason': 'empty-text'},
      );
      return;
    }
    if (allowCodeBlockPlainTextFastPath && _pastePlainIntoCodeBlock(text)) {
      WenzClipboardDebugLog.event(
        'controller.paste-applied',
        fields: <String, Object?>{
          'branch': 'plain-code-fast-path',
          'selection': WenzClipboardDebugLog.selection(selection),
        },
      );
      return;
    }
    _pastePlain(text);
    notifyListeners();
    WenzClipboardDebugLog.event(
      'controller.paste-applied',
      fields: <String, Object?>{
        'branch': 'plain',
        'documentBlocks': document.blocks.length,
        'selection': WenzClipboardDebugLog.selection(selection),
      },
    );
  }

  void _pasteInline(List<InlineNode> runs) {
    if (runs.isEmpty) {
      return;
    }
    // Insert each run at the current caret; InsertTextCommand handles attribute
    // preservation per run, and InsertInlineEmbedCommand re-inserts embeds
    // (formula/mention/image) so rich inline elements survive paste. Inserting
    // as separate commands lets them coalesce only when attributes match.
    for (final run in runs) {
      if (run is TextRun) {
        if (run.text.isEmpty) {
          continue;
        }
        insertText(
          run.text,
          attributes: run.attributes,
          applyMarkdownShortcuts: false,
        );
      } else if (run is InlineEmbed) {
        execute(
          InsertInlineEmbedCommand(
            embedType: run.embedType,
            data: run.data,
          ),
        );
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
        insertText(lines[i], applyMarkdownShortcuts: false);
      }
    }
  }

  bool _pastePlainIntoCodeBlock(String text) {
    if (!_isSelectionWithinCodeBlock(selection)) {
      return false;
    }
    insertText(
      text,
      applyMarkdownShortcuts: false,
      applyAutoLinkUrls: false,
    );
    return true;
  }

  bool _isSelectionWithinCodeBlock(DocumentSelection? selection) {
    if (selection == null) {
      return false;
    }
    final start = selection.start;
    final end = selection.end;
    if (start.blockIndex != end.blockIndex ||
        start.blockId != end.blockId ||
        start.path != end.path ||
        !start.path.isBlockCode ||
        start.path.blockId != start.blockId) {
      return false;
    }
    final blockIndex = start.blockIndex;
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      return false;
    }
    final block = document.blocks[blockIndex];
    return block is CodeBlockNode && block.id == start.blockId;
  }

  int _pasteSequence = 0;
  String _pasteBlockCounter() {
    _pasteSequence += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_pasteSequence';
  }

  int _currentBlockInsertionIndex() {
    return _currentBlockInsertionIndexForSelection(session.selection);
  }

  int _currentBlockInsertionIndexForSelection(DocumentSelection? selection) {
    final blockCount = document.blocks.length;
    if (selection == null) {
      return blockCount;
    }
    final position = _blockInsertionPosition(selection);
    final index = position.blockIndex.clamp(0, blockCount).toInt();
    if (position.path.isTableCellText) {
      return (index + 1).clamp(0, blockCount).toInt();
    }
    if (position.path.isBlockObject && position.offset > 0) {
      return (index + 1).clamp(0, blockCount).toInt();
    }
    return index;
  }

  bool _shouldInsertExternalImageBlocksDirectly(
    DocumentSelection selection, {
    required bool explicitSelection,
  }) {
    if (selection.extent.path.isTableCellText) {
      return true;
    }
    if (!selection.isCollapsed) {
      return false;
    }
    if (selection.extent.path.isBlockObject) {
      return true;
    }
    return explicitSelection && selection.extent.path.isBlockCode;
  }

  DocumentSelection? _normalizedExternalImagePasteSelection(
    DocumentSelection? selection,
  ) {
    if (selection == null) {
      return null;
    }
    return _isValidExternalImagePasteSelection(selection) ? selection : null;
  }

  bool _isValidExternalImagePasteSelection(DocumentSelection selection) {
    return _isValidExternalImagePastePosition(selection.base) &&
        _isValidExternalImagePastePosition(selection.extent);
  }

  bool _isValidExternalImagePastePosition(DocumentPosition position) {
    if (position.blockIndex < 0 ||
        position.blockIndex >= document.blocks.length) {
      return false;
    }
    final block = document.blocks[position.blockIndex];
    if (position.blockId != block.id || position.path.blockId != block.id) {
      return false;
    }
    if (position.path.isBlockText) {
      return block is TextBlockNode || block is CalloutBlockNode;
    }
    if (position.path.isBlockCode) {
      return block is CodeBlockNode;
    }
    if (position.path.isTableCellText) {
      if (block is! TableBlockNode) {
        return false;
      }
      final rowIndex = position.path.tableRowIndex;
      final columnIndex = position.path.tableColumnIndex;
      return rowIndex != null &&
          columnIndex != null &&
          rowIndex >= 0 &&
          columnIndex >= 0 &&
          rowIndex < block.table.rowCount &&
          columnIndex < block.table.columnCount;
    }
    if (position.path.isBlockObject) {
      return block is ImageBlockNode ||
          block is DividerBlockNode ||
          block is VideoBlockNode ||
          block is BlockEmbedNode ||
          block is FileBlockNode;
    }
    return false;
  }

  DocumentPosition _blockInsertionPosition(DocumentSelection selection) {
    if (selection.start.path.isBlockObject ||
        selection.end.path.isBlockObject) {
      return selection.end;
    }
    return selection.extent;
  }

  DocumentSelection _selectionForExternalImageBlock(
    BlockNode block,
    int blockIndex,
  ) {
    final start = DocumentPosition.object(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: 0,
    );
    return DocumentSelection(base: start, extent: start.copyWith(offset: 1));
  }

  ChangeSet enter({String? newBlockId}) {
    return execute(EnterCommand(newBlockId: newBlockId));
  }

  ChangeSet insertTextBlockAbove({
    String? blockId,
    DocumentSelection? selection,
  }) {
    return _insertTextBlockAtSelection(
      direction: TextBlockInsertionDirection.above,
      blockId: blockId,
      selection: selection,
    );
  }

  ChangeSet insertTextBlockBelow({
    String? blockId,
    DocumentSelection? selection,
  }) {
    return _insertTextBlockAtSelection(
      direction: TextBlockInsertionDirection.below,
      blockId: blockId,
      selection: selection,
    );
  }

  ChangeSet _insertTextBlockAtSelection({
    required TextBlockInsertionDirection direction,
    String? blockId,
    DocumentSelection? selection,
  }) {
    return execute(
      InsertTextBlockAtSelectionCommand(
        blockId: blockId ?? 'quick-text-${_pasteBlockCounter()}',
        direction: direction,
        selection: selection,
      ),
    );
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

  ChangeSet moveBlock({
    required int fromIndex,
    required int toIndex,
  }) {
    return execute(
      MoveBlockCommand(fromIndex: fromIndex, toIndex: toIndex),
    );
  }

  /// Moves [count] continuous top-level blocks starting at [fromIndex].
  ///
  /// [toIndex] is an insertion boundary in the original document before the
  /// range is removed. The command normalizes it to the final start index after
  /// removal, allowing callers to pass document-level drop boundaries directly.
  ChangeSet moveBlockRange({
    required int fromIndex,
    required int count,
    required int toIndex,
  }) {
    return execute(
      MoveBlockRangeCommand(
        fromIndex: fromIndex,
        count: count,
        toIndex: toIndex,
      ),
    );
  }

  ChangeSet updateImageBlock({
    required int blockIndex,
    String? assetId,
    String? file,
    int? width,
    int? height,
    double? showWidth,
    double? showHeight,
    bool clearShowWidth = false,
    bool clearShowHeight = false,
    String? caption,
    String? altText,
  }) {
    return execute(
      UpdateImageBlockCommand(
        blockIndex: blockIndex,
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
      ),
    );
  }

  ChangeSet updateVideoBlock({
    required int blockIndex,
    String? assetId,
    String? playbackUrl,
    String? file,
    String? coverUrl,
    String? title,
    String? description,
    double? aspectRatio,
    bool clearAspectRatio = false,
    double? showWidth,
    double? showHeight,
    bool clearShowWidth = false,
    bool clearShowHeight = false,
    FileUploadStatus? uploadStatus,
    String? uploadError,
  }) {
    return execute(
      UpdateVideoBlockCommand(
        blockIndex: blockIndex,
        assetId: assetId,
        playbackUrl: playbackUrl,
        file: file,
        coverUrl: coverUrl,
        title: title,
        description: description,
        aspectRatio: aspectRatio,
        clearAspectRatio: clearAspectRatio,
        showWidth: showWidth,
        showHeight: showHeight,
        clearShowWidth: clearShowWidth,
        clearShowHeight: clearShowHeight,
        uploadStatus: uploadStatus,
        uploadError: uploadError,
      ),
    );
  }

  ChangeSet deleteVideoBlock({
    required int blockIndex,
    DocumentSelection? selection,
  }) {
    return execute(
      DeleteVideoBlockCommand(blockIndex: blockIndex, selection: selection),
    );
  }

  ChangeSet updateFileBlock({
    required int blockIndex,
    String? assetId,
    String? name,
    int? size,
    String? mimeType,
    String? file,
    String? downloadUrl,
    FileUploadStatus? uploadStatus,
    String? uploadError,
  }) {
    return execute(
      UpdateFileBlockCommand(
        blockIndex: blockIndex,
        assetId: assetId,
        name: name,
        size: size,
        mimeType: mimeType,
        file: file,
        downloadUrl: downloadUrl,
        uploadStatus: uploadStatus,
        uploadError: uploadError,
      ),
    );
  }

  DocumentSelection? _objectSelectionForBlockIndex(
    int blockIndex, {
    BlockType? type,
  }) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      return null;
    }
    final block = document.blocks[blockIndex];
    if (type != null && block.type != type) {
      return null;
    }
    final start = DocumentPosition(
      blockId: block.id,
      blockIndex: blockIndex,
      path: PositionPath.blockObject(block.id),
      offset: 0,
    );
    final end = start.copyWith(offset: 1);
    return DocumentSelection(base: start, extent: end);
  }

  ChangeSet setBlockAnchor({
    required int blockIndex,
    String? anchor,
  }) {
    return execute(
      SetBlockAnchorCommand(blockIndex: blockIndex, anchor: anchor),
    );
  }

  ChangeSet formatText(
    TextAttributes attributes, {
    DocumentSelection? selection,
  }) {
    // Inline color/background follow the same nullable-attribute contract:
    // callers store `0xAARRGGBB`, `null` means no inline override, and merging
    // a null value does not clear an existing value. A collapsed, missing,
    // empty-attributes, invalid, object-block, or non-text-only selection is a
    // no-op at the command layer; same-cell table selections are routed through
    // table-cell editing. Edit permission is still enforced by [execute].
    if (_revisionModeEnabled) {
      return markFormatRevision(attributes, selection: selection);
    }
    return execute(
      FormatTextCommand(attributes: attributes, selection: selection),
    );
  }

  /// Applies an inline font [color] to the current selection, storing it in the
  /// document model as a stable `0xAARRGGBB` integer.
  ChangeSet setTextColor(Color color, {DocumentSelection? selection}) {
    return setTextColorValue(color.toARGB32(), selection: selection);
  }

  /// Applies an inline font color already encoded as `0xAARRGGBB`.
  ChangeSet setTextColorValue(int color, {DocumentSelection? selection}) {
    return formatText(TextAttributes(color: color), selection: selection);
  }

  /// Clears only inline font color for the current selection while preserving
  /// other inline attributes such as links, background, and emphasis.
  ChangeSet clearTextColor({DocumentSelection? selection}) {
    return execute(ClearTextColorCommand(selection: selection));
  }

  /// Applies an inline background/highlight [color] to the current selection.
  ChangeSet setTextBackground(Color color, {DocumentSelection? selection}) {
    return setTextBackgroundValue(color.toARGB32(), selection: selection);
  }

  /// Applies an inline background/highlight color encoded as `0xAARRGGBB`.
  ChangeSet setTextBackgroundValue(
    int background, {
    DocumentSelection? selection,
  }) {
    return formatText(
      TextAttributes(background: background),
      selection: selection,
    );
  }

  ChangeSet setTextHighlight(Color color, {DocumentSelection? selection}) {
    return setTextBackground(color, selection: selection);
  }

  ChangeSet setTextHighlightValue(int color, {DocumentSelection? selection}) {
    return setTextBackgroundValue(color, selection: selection);
  }

  /// Clears only inline background/highlight color for the current selection.
  ChangeSet clearTextBackground({DocumentSelection? selection}) {
    return execute(ClearTextBackgroundCommand(selection: selection));
  }

  ChangeSet clearTextHighlight({DocumentSelection? selection}) {
    return clearTextBackground(selection: selection);
  }

  ChangeSet clearStyle({DocumentSelection? selection}) {
    // This clears the selected inline attributes as a whole. Use the dedicated
    // color/background clear helpers to preserve unrelated inline attributes.
    return execute(ClearStyleCommand(selection: selection));
  }

  ChangeSet setLink(String? url, {DocumentSelection? selection}) {
    return execute(SetLinkCommand(url, selection: selection));
  }

  ChangeSet autoLinkUrls({DocumentSelection? selection}) {
    return execute(AutoLinkUrlsCommand(selection: selection));
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

  ChangeSet updateInlineFormula({
    required DocumentPosition position,
    required String text,
  }) {
    return execute(
      UpdateInlineFormulaCommand(position: position, text: text),
    );
  }

  ChangeSet updateBlockFormula({
    required String blockId,
    required String text,
  }) {
    return execute(
      UpdateBlockFormulaCommand(blockId: blockId, text: text),
    );
  }

  /// Inserts a `mention` inline embed.
  ///
  /// The stored payload is the interaction contract for mention opening: the
  /// editor keeps the original embed data available to renderers/events and the
  /// required stable fields are `id` and `label`. The embed remains one logical
  /// character, so taps and drag selections can share the same hit boundary.
  /// Extra [data] is preserved for host-owned business fields; canonical
  /// `id`/`label` values always win if the map also contains those keys.
  ChangeSet insertMention(
    String id,
    String label, {
    Map<String, Object?> data = const <String, Object?>{},
    DocumentSelection? selection,
  }) {
    return execute(
      InsertInlineEmbedCommand(
        embedType: 'mention',
        data: <String, Object?>{
          ...data,
          'id': id,
          'label': label,
        },
        selection: selection,
      ),
    );
  }

  ChangeSet insertEmoji(
    String emoji, {
    String? shortName,
    DocumentSelection? selection,
  }) {
    return execute(
      InsertInlineEmbedCommand(
        embedType: 'emoji',
        data: <String, Object?>{
          'emoji': emoji,
          if (shortName != null) 'shortName': shortName,
        },
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
    final target = selection ?? session.selection;
    if (target?.tableCellRange != null) {
      return execute(
        SetTableCellRangeAlignmentCommand(
          alignment: alignment,
          selection: target,
        ),
      );
    }
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

  ChangeSet setTableCellAlignment({
    required int blockIndex,
    required int rowIndex,
    required int columnIndex,
    required String? alignment,
  }) {
    return execute(
      SetTableCellAlignmentCommand(
        blockIndex: blockIndex,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        alignment: alignment,
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

  String _nextRevisionId(RevisionChangeType type) {
    _revisionIdCounter += 1;
    return 'rev-${type.name}-${DateTime.now().microsecondsSinceEpoch}-$_revisionIdCounter';
  }

  DocumentSelection? _singleCharacterRevisionSelection(
      {required bool forward}) {
    final target = selection;
    if (target == null) {
      return null;
    }
    if (!target.isCollapsed) {
      return target;
    }
    final position = target.extent;
    if (!position.path.isBlockText ||
        position.blockIndex < 0 ||
        position.blockIndex >= document.blocks.length) {
      return null;
    }
    final block = document.blocks[position.blockIndex];
    if (block is! TextBlockNode) {
      return null;
    }
    final offset = position.offset.clamp(0, block.plainText.length).toInt();
    final startOffset = forward ? offset : offset - 1;
    final endOffset = forward ? offset + 1 : offset;
    if (startOffset < 0 || endOffset > block.plainText.length) {
      return null;
    }
    final start = position.copyWith(offset: startOffset);
    final end = position.copyWith(offset: endOffset);
    return DocumentSelection(base: start, extent: end);
  }

  bool _sameBlockContent(BlockNode first, BlockNode second) {
    if (identical(first, second)) {
      return true;
    }
    return jsonEncode(first.toJson()) == jsonEncode(second.toJson());
  }
}

class _InsertImageBlockCommand extends InsertBlocksCommand {
  _InsertImageBlockCommand({
    required super.index,
    required this.blockId,
    String assetId = '',
    String file = '',
    int width = 0,
    int height = 0,
    double? showWidth,
    double? showHeight,
    String caption = '',
    String altText = '',
    super.selection,
  }) : super(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: blockId,
              assetId: assetId,
              file: file,
              width: width,
              height: height,
              showWidth: showWidth,
              showHeight: showHeight,
              caption: caption,
              altText: altText,
            ),
          ],
        );

  final String blockId;

  @override
  CommandResult execute(DocumentSession session) {
    final result = super.execute(session);
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
      selection: _objectSelectionForInsertedBlock(blockId, insertedIndex),
      recordHistory: result.recordHistory,
      metadata: result.metadata,
    );
  }
}

class _SelectionScopedCommand extends EditorCommand {
  const _SelectionScopedCommand({
    required this.targetSelection,
    required this.delegate,
  });

  final DocumentSelection targetSelection;
  final EditorCommand delegate;

  @override
  String get description => delegate.description;

  @override
  WenzEditorPermission get requiredPermission => delegate.requiredPermission;

  @override
  bool canMergeWith(EditorCommand previous) {
    final previousDelegate =
        previous is _SelectionScopedCommand ? previous.delegate : previous;
    return delegate.canMergeWith(previousDelegate);
  }

  @override
  bool get breaksMergeRun => delegate.breaksMergeRun;

  @override
  CommandResult execute(DocumentSession session) {
    final previousSelection = session.selection;
    session.selection = targetSelection;
    final result = delegate.execute(session);
    if (result.selection == null) {
      session.selection = previousSelection;
    }
    return result;
  }
}

DocumentSelection _objectSelectionForInsertedBlock(
  String blockId,
  int blockIndex,
) {
  final start = DocumentPosition.object(
    blockId: blockId,
    blockIndex: blockIndex,
  );
  return DocumentSelection(base: start, extent: start.copyWith(offset: 1));
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

/// Which JSON family [WenzRichTextController.tryLoadJsonAuto] decoded.
///
/// Hosts use this to implement lazy migration: a note loaded as [legacy] is a
/// candidate for upgrade on its next save, while [current] notes are already in
/// the new format and need no special handling.
enum JsonLoadFormat {
  /// Current Rich JSON — a top-level object with `version` and `blocks`.
  current,

  /// Legacy `wenz_editor` JSON — a top-level bare array of blocks.
  legacy,
}

/// Outcome of [WenzRichTextController.tryLoadJsonAuto]. Like [TryLoadResult]
/// but additionally carries the [format] detected before decoding, so hosts
/// can track which notes still need upgrading. On failure [format] is `null`.
class TryLoadJsonAutoResult {
  const TryLoadJsonAutoResult._({
    required this.ok,
    this.document,
    this.format,
    this.error,
  });

  factory TryLoadJsonAutoResult.ok(
    RichTextDocument document, {
    required JsonLoadFormat format,
  }) =>
      TryLoadJsonAutoResult._(ok: true, document: document, format: format);

  factory TryLoadJsonAutoResult.failed(Object error) =>
      TryLoadJsonAutoResult._(ok: false, error: error);

  /// Whether decoding succeeded.
  final bool ok;

  /// The decoded document. Non-null when [ok] is `true`.
  final RichTextDocument? document;

  /// The detected source format. Non-null when [ok] is `true`; `null` on
  /// failure (the format could not be determined or the payload was not valid
  /// JSON).
  final JsonLoadFormat? format;

  /// The originating error. Non-null when [ok] is `false`.
  final Object? error;
}

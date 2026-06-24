# Schema and commands

Stage 3 adds a schema boundary around the document model and expands the command
surface for inline, block, and plugin-driven editing.

## Document schema

`DocumentSchema.normalize` is the canonical repair step for documents entering or
leaving commands.

Rules:

- Empty documents become a single empty paragraph.
- Text block attributes are made consistent with their block type.
- List item `listType` values are canonicalised to `ordered`, `task`, or `null`
  for unordered bullets.
- Table cells always contain at least one paragraph block.
- Indent values are clamped to the configured schema range.
- `BlockEmbedNode.embedType` is normalized to `custom` when blank, and
  `fallbackText` is trimmed; app-owned `data` is preserved as JSON-compatible
  metadata.
- `BlockAttributes.anchor` is preserved as optional block-level metadata. Empty
  anchors are cleared by the command layer before they reach the document.
- Optional top-level collaboration metadata (`comments`, `revisions`) is
  preserved by normalization and defaults to an empty list for old JSON.

Normalizer entry points:

- `DocumentSession` normalizes the initial document and `replaceDocument` input.
- `CommandExecutor.execute` normalizes after every command result before creating
  the `ChangeSet`.
- JSON and legacy JSON loads go through controller/session replacement, so decoded
  documents are normalized before use.

Schema evolution gate:

- Optional fields may stay on the current JSON version only when old documents
  decode safely through defaults and normalize remains idempotent.
- Renamed, removed, or semantically changed fields require a `DocumentMigration`
  step and fixture tests before the model change lands.
- `docs/schema_migration_impact.md` is the ADV-002 decision record for planned
  advanced features and their schema/migration impact.

## Version snapshots

`ADV-020` keeps version history outside the document body schema:

- `DocumentVersionSnapshot` wraps a deep-copied `RichTextDocument` with snapshot
  metadata (`id`, `createdAt`, optional author fields, description, and
  `baseSnapshotId` for future diff flows).
- `DocumentVersionSnapshotJsonCodec` persists one snapshot or a snapshot list for
  app-owned storage; it does not add a top-level `versions` field to rich JSON.
- `WenzRichTextController.createVersionSnapshot` and
  `restoreVersionSnapshot` are helper entry points around the same document
  model and `replaceDocument` normalization path.
- Retention policy, labels, comparison UI, and server/local storage remain host
  application responsibilities.

## Inline commands

Use semantic commands instead of reaching into `FormatTextCommand` directly when
the intent is part of the rich text feature set.

- `SetLinkCommand(url)` applies or replaces a link URL on the current selection;
  `null` clears links.
- `AutoLinkUrlsCommand` scans the current text block or table-cell text scope,
  applies `TextAttributes.url` to detected `http(s)://` / `www.` tokens, trims
  trailing punctuation, and skips ranges that already carry a link.
- `ToggleMarkCommand(TextMark.remark)` toggles remark/comment anchor styling.
  The same command can also toggle boolean marks such as underline and
  line-through.
- `InsertInlineEmbedCommand` inserts an inline embed at the caret and moves the
  selection after the embed.
- `WenzRichTextController.insertFormula(text)` inserts a formula embed with
  `embedType: 'formula'`.
- `WenzRichTextController.insertMention(id, label)` inserts a mention embed with
  `embedType: 'mention'` and renders as `@label`.
- `WenzRichTextController.insertEmoji(emoji, shortName: ...)` inserts an emoji
  embed with `embedType: 'emoji'`; JSON stores the unicode value and optional
  short name while default renderers display the emoji character.
- `WenzRichTextController.insertInlineImage(...)` inserts an inline image embed
  with `embedType: 'image'` and renders as `[img]` until a media renderer is
  provided.

## Comment threads

`ADV-023` introduces the storage and UI contract for comments without adding
comment mutation commands yet:

- `RichTextDocument.comments` stores `CommentThread` records in rich JSON.
- `CommentAnchor` serializes block id, block index, `PositionPath`, and start/end
  offsets, and exposes `selection` so hosts can jump to the commented range with
  the existing `DocumentSelection` contract.
- `TextAttributes.commentIds` marks inline runs covered by one or more comment
  threads. It is additive and defaults to an empty list for old documents.
- `WenzCommentSidebar` is UI-only; resolve/reopen persistence is app-owned until
  `comment_commands.dart` is introduced.

## Revision changes

`ADV-024` introduces the storage and command contract for same-block text
revisions:

- `RichTextDocument.revisions` stores `RevisionChange` records in rich JSON.
- `RevisionRange` serializes block id, block index, `PositionPath`, and
  start/end offsets, and exposes `selection` for controller/UI integration.
- `TextAttributes.revisionIds` marks inline runs covered by pending revisions.
- `InsertRevisionTextCommand`, `MarkDeletionRevisionCommand`, and
  `MarkFormatRevisionCommand` create insert/delete/format revision records and
  write inline markers through the command pipeline.
- `AcceptRevisionCommand` and `RejectRevisionCommand` clear inline markers and
  apply or revert the same-block text change while preserving revision status.
- `WenzRichTextController.setRevisionMode` is a runtime switch; when enabled,
  typed insert/delete/format helpers route through revision commands. Cross-block,
  table-cell, sidebar, and visual rendering flows remain future work.

## Block commands

Stage 3 block structure commands keep block-level editing behind command objects
so history, schema normalization, and middleware all run consistently.

- `IndentCommand(1)` and `IndentCommand(-1)` power controller `indent()` and
  `outdent()`.
- `ToggleTodoCommand` converts a block to a task list item when needed, then
  toggles checked state.
- `EnterCommand` has list-aware behavior: non-empty unordered/ordered/task list
  items split into a following list item with the same indent/type; task
  continuations start unchecked. Pressing Enter on an empty list item converts
  it back to a paragraph, preserving block-level metadata such as anchor.
- `SetCodeLanguageCommand(language)` updates a code block language.
- `SetCalloutVariantCommand(variant)` updates a callout block type. Supported
  values are `info`, `success`, `warning`, and `danger`; unknown values
  normalize to `info`.
- `UpdateCalloutBlockCommand(variant/title/icon)` updates callout metadata
  through the command pipeline. Empty `title` or `icon` clears the custom value
  and lets renderers fall back to the variant default.
- `ToggleQuoteCommand` switches paragraph/quote state and uses indent for quote
  depth during this stage.
- `SetBlockAnchorCommand(blockIndex, anchor)` writes or clears a block-level
  anchor through the normal command pipeline; controller code usually calls
  `WenzRichTextController.setBlockAnchor`.
- `CalloutBlockNode`, `FileBlockNode`, and `BlockEmbedNode` are serializable
  blocks that can be inserted through controller helpers. Callout JSON/HTML
  preserve structured `variant`/`title`/`icon`; Markdown export deliberately
  degrades to a blockquote while preserving the visible icon, title, and body.
  File blocks store `assetId/name/size/file` plus
  `mimeType/downloadUrl/uploadStatus` and `uploadError`; `UpdateFileBlockCommand`
  changes those fields through the undo/redo pipeline. `BlockEmbedNode` stores
  business `embedType/data/fallbackText`, is inserted via
  `WenzRichTextController.insertBlockEmbed`, round-trips through rich JSON and
  HTML `data-*` attributes, and degrades to readable Markdown/plain text.

## Command pipeline

`WenzRichTextController` first checks `WenzEditorPermission` against
`EditorCommand.requiredPermission` (`edit` by default). Disabled commands return
a no-op `ChangeSet` with `metadata.reason == 'permissionDenied'` and never reach
the executor.

`CommandExecutor` is the choke point for allowed command execution:

1. Run each `CommandMiddleware.before` hook.
2. If a hook returns a `ChangeSet`, short-circuit the command.
3. Execute the command body.
4. Apply the command selection result.
5. Normalize the document with `DocumentSchema`.
6. Create a `ChangeSet`, including `CommandResult.metadata`.
7. Record history when requested.
8. Run each `CommandMiddleware.after` hook.

Middleware before-hooks are the extension point for validation, additional policy
checks, command blocking, or command rewriting. After-hooks are observers and
should use `ChangeSet.metadata` for dirty block ids, command kind, analytics, or
renderer invalidation hints.

## Controller callbacks

`WenzRichTextController` exposes three optional callbacks for business-layer
integration. They are the typed, integration-level counterpart to the coarse
`addListener`/`notifyListeners` signal and to the pipeline-level
`CommandMiddleware.after` hook:

- `onChanged(RichTextDocument doc)` — fires when document content changes:
  typing, formatting, block structure, undo/redo, `replaceDocument`, paste.
  Selection-only and composition-only mutations do **not** fire it.
- `onSelectionChanged(DocumentSelection? selection)` — fires when the selection
  changes, whether from a command, a programmatic `setSelection`, undo/redo,
  or replace. Passes the new selection (`null` when cleared).
- `onCommandExecuted(EditorCommand command, ChangeSet change)` — fires right
  after a non-noop command produced a change, for both typed `execute` and
  registry-driven `executeCommand`. Undo/redo do **not** fire it (there is no
  originating command object), but they still fire `onChanged` /
  `onSelectionChanged`. Permission-blocked commands do not fire callbacks.

Ordering and reentrancy:

- All three callbacks fire **synchronously before** `notifyListeners`, so when
  they run the controller already holds the committed document and selection.
  This matches what an `addListener` observer sees when notified.
- Avoid mutating the document from inside a callback — it runs during the
  controller's own mutation. Read state and schedule follow-up work (e.g. via
  `Future.microtask`) instead.

Choosing between callbacks and middleware:

- Use `CommandMiddleware` for cross-cutting, pipeline-level concerns
  (validation logging, analytics, policy) that must observe **every** command
  including those dispatched by plugins via `CommandRegistry`.
- Use the controller callbacks for business-integration concerns
  (toolbar state, save indicators, inspector panels) keyed off the typed
  controller surface.
- `WenzAutoSaveController` builds on the same notification stream but compares
  rich JSON snapshots itself, so it can ignore selection-only notifications and
  keep dirty/autosave state outside the document schema. Persist the supplied
  `AutoSaveSnapshot.json` in an app-owned draft store and restore it with
  `loadJson` / `tryLoadJson`.

## Command registry

Plugins can register named commands without changing `CommandExecutor` or adding
methods to `WenzRichTextController`:

```dart
controller.registry.register(
  CommandDescriptor(
    name: 'insertHello',
    factory: (args) => InsertTextCommand(args.readString('text') ?? 'hello'),
  ),
);

controller.executeCommand('insertHello', <String, Object?>{
  'text': 'world',
});
```

Use `CommandArgsRead` helpers to read typed JSON-like arguments safely. Unknown
command names throw `UnknownCommandException` (a structured error, see Error
handling below) so callers can fall back to typed controller APIs.

`ADV-027` adds a higher-level plugin install surface around the same registry:
`WenzRichTextPlugin` / `WenzPluginBundle` / `WenzPluginContext`. Command plugins
registered through that surface still end up in `controller.registry`, and their
execution still flows through `CommandExecutor`, middleware, history, and schema
normalisation. The same context can also receive runtime registries for block
renderers, block embed renderers (`BlockRendererRegistry.registerEmbed`), inline
embed renderers, slash menu items, headless toolbar items, and paste
transformers; none of those runtime registrations writes to rich JSON.

## Error handling

Import/export and command dispatch use **structured exceptions** so callers can
catch failures with a typed handler instead of sniffing error strings. The
originating error is always preserved on the `.raw` field, so no diagnostic
information is lost.

### Exception types

- `DocumentDecodeException` — raised by `RichTextJsonCodec.decode`,
  `LegacyWenJsonCodec.decode`, and `decodeWithMigrations` on any decode
  failure (malformed JSON, wrong root type, a gap in the migration chain, or
  a model inflation error). Fields: `reason`, optional `jsonPath`,
  `raw` (the originating `FormatException` / `StateError` / type error).
- `UnknownCommandException` — raised by `CommandRegistry.build` (and therefore
  by `WenzRichTextController.executeCommand`) when a command name has not been
  registered. Field: `name`.

### Two entry-point styles

```dart
// 1. Typed exceptions — preferred when you can handle a failure locally
try {
  controller.loadJson(maybeBadSource);
} on DocumentDecodeException catch (e) {
  log(e.reason, e.raw);
}

// 2. No-throw safe entries — for UI code paths that must not throw
final result = controller.tryLoadJson(maybeBadSource);
if (!result.ok) {
  showError(result.error);          // result.document is null; current doc untouched
}

final ran = controller.tryExecuteCommand('pluginCmd', args);
if (!ran) {
  // unknown, disabled, or bad args — document untouched, no callbacks fired
}
```

### Guarantees on failure

- `loadJson` / `tryLoadJson` on failure: the current document, selection,
  history, and `lastChangedBlockIds` are untouched; no change callback fires.
- `executeCommand` / `tryExecuteCommand` on an unknown command: same — the
  command never reaches the executor, so nothing mutates.
- `tryExecuteCommand` on a permission-disabled command returns `false`; typed
  `execute` / `executeCommand` return a no-op `ChangeSet` carrying the denial
  metadata.
- `tryLoadJson` returns a `TryLoadResult` (`ok` / `document?` / `error?`);
  `tryExecuteCommand` returns a `bool`.

### Command execution safety

Commands that *are* built successfully still run through `CommandExecutor`,
which applies schema normalisation after every command so outputs are always
well-formed. No-op commands (e.g. indent at the floor) produce an `isNoop`
`ChangeSet` and are skipped silently — they do not trigger the change
callbacks or enter history. Media resolver failures are reported through
`FlutterError.reportError` and fall back to the built-in renderer; file upload
failures should be represented by `FileBlockNode.uploadStatus == failed` plus
`uploadError`, then retried by business UI/resolvers through
`WenzRichTextController.updateFileBlock`.

### Markdown leniency

`loadMarkdown` / `MarkdownCodec.decode` never throw for content — Markdown is
lenient by design, so any unrecognised line becomes a paragraph. `tryLoadMarkdown`
mirrors `tryLoadJson` for UI code paths that want a `TryLoadResult` regardless.

### HTML leniency

`loadHtml` / `HtmlCodec.decode` likewise never throw for content — `package:html`
is a spec-compliant HTML5 parser that self-corrects malformed input into a
sensible DOM, and unrecognised tags fall back to paragraphs. `tryLoadHtml`
provides the no-throw entry point.

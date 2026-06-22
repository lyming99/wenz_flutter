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

Normalizer entry points:

- `DocumentSession` normalizes the initial document and `replaceDocument` input.
- `CommandExecutor.execute` normalizes after every command result before creating
  the `ChangeSet`.
- JSON and legacy JSON loads go through controller/session replacement, so decoded
  documents are normalized before use.

## Inline commands

Use semantic commands instead of reaching into `FormatTextCommand` directly when
the intent is part of the rich text feature set.

- `SetLinkCommand(url)` applies or replaces a link URL on the current selection;
  `null` clears links.
- `ToggleMarkCommand(TextMark.remark)` toggles remark/comment anchor styling.
  The same command can also toggle boolean marks such as underline and
  line-through.
- `InsertInlineEmbedCommand` inserts an inline embed at the caret and moves the
  selection after the embed.
- `WenzRichTextController.insertFormula(text)` inserts a formula embed with
  `embedType: 'formula'`.
- `WenzRichTextController.insertMention(id, label)` inserts a mention embed with
  `embedType: 'mention'` and renders as `@label`.
- `WenzRichTextController.insertInlineImage(...)` inserts an inline image embed
  with `embedType: 'image'` and renders as `[img]` until a media renderer is
  provided.

## Block commands

Stage 3 block structure commands keep block-level editing behind command objects
so history, schema normalization, and middleware all run consistently.

- `IndentCommand(1)` and `IndentCommand(-1)` power controller `indent()` and
  `outdent()`.
- `ToggleTodoCommand` converts a block to a task list item when needed, then
  toggles checked state.
- `SetCodeLanguageCommand(language)` updates a code block language.
- `ToggleQuoteCommand` switches paragraph/quote state and uses indent for quote
  depth during this stage.
- `CalloutBlockNode` and `FileBlockNode` are serializable blocks that can be
  inserted through controller helpers.

## Command pipeline

`CommandExecutor` is the choke point for command execution:

1. Run each `CommandMiddleware.before` hook.
2. If a hook returns a `ChangeSet`, short-circuit the command.
3. Execute the command body.
4. Apply the command selection result.
5. Normalize the document with `DocumentSchema`.
6. Create a `ChangeSet`, including `CommandResult.metadata`.
7. Record history when requested.
8. Run each `CommandMiddleware.after` hook.

Middleware before-hooks are the extension point for validation, policy checks,
command blocking, or command rewriting. After-hooks are observers and should use
`ChangeSet.metadata` for dirty block ids, command kind, analytics, or renderer
invalidation hints.

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
  `onSelectionChanged`.

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
  // unknown command or bad args — document untouched, no callbacks fired
}
```

### Guarantees on failure

- `loadJson` / `tryLoadJson` on failure: the current document, selection,
  history, and `lastChangedBlockIds` are untouched; no change callback fires.
- `executeCommand` / `tryExecuteCommand` on an unknown command: same — the
  command never reaches the executor, so nothing mutates.
- `tryLoadJson` returns a `TryLoadResult` (`ok` / `document?` / `error?`);
  `tryExecuteCommand` returns a `bool`.

### Command execution safety

Commands that *are* built successfully still run through `CommandExecutor`,
which applies schema normalisation after every command so outputs are always
well-formed. No-op commands (e.g. indent at the floor) produce an `isNoop`
`ChangeSet` and are skipped silently — they do not trigger the change
callbacks or enter history. Media load-failure handling rides along with the
media resolver work (task B6); until then media blocks render as placeholders
and have no load path to fail.

### Markdown leniency

`loadMarkdown` / `MarkdownCodec.decode` never throw for content — Markdown is
lenient by design, so any unrecognised line becomes a paragraph. `tryLoadMarkdown`
mirrors `tryLoadJson` for UI code paths that want a `TryLoadResult` regardless.

### HTML leniency

`loadHtml` / `HtmlCodec.decode` likewise never throw for content — `package:html`
is a spec-compliant HTML5 parser that self-corrects malformed input into a
sensible DOM, and unrecognised tags fall back to paragraphs. `tryLoadHtml`
provides the no-throw entry point.

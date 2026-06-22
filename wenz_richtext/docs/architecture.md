# Architecture

`wenz_richtext` is a self-contained rich text editor kernel: it owns its
document model, command layer, history, input bridge, and rendering — no
`ydart`/Yjs dependency. The package is layered so each tier depends only on the
ones below it, and the codec layer is a cross-cutting adapter that touches the
model but not the command/session core.

## Layers (bottom-up)

```
┌─────────────────────────────────────────────────────────────┐
│ Widget layer                                                 │
│ WenzRichTextEditor, selection_gesture_overlay,               │
│ block_renderer_registry, shared_text_layout_cache            │
├─────────────────────────────────────────────────────────────┤
│ Input layer                                                  │
│ EditorTextInputClient (IME), ClipboardService, shortcuts     │
├─────────────────────────────────────────────────────────────┤
│ Controller layer                                             │
│ WenzRichTextController, ToolbarController                    │
├─────────────────────────────────────────────────────────────┤
│ Transaction / History                                        │
│ DocumentSession, ChangeSet, HistoryManager, CommandExecutor  │
├─────────────────────────────────────────────────────────────┤
│ Command layer                                                │
│ EditorCommand + concrete commands, CommandRegistry/middleware│
├─────────────────────────────────────────────────────────────┤
│ Model layer                                                  │
│ RichTextDocument, BlockNode, InlineNode, TableModel,         │
│ DocumentSchema, DocumentPosition/DocumentSelection           │
└─────────────────────────────────────────────────────────────┘

        Codec layer (cross-cutting, imports model only):
        RichTextJsonCodec, LegacyWenJsonCodec, PlainTextCodec,
        DocumentMigration — (de)serialise model <-> JSON/text
```

**Dependency direction is strictly downward.** A higher layer may import a
lower one, never the reverse. The codec layer is the exception: it imports the
model layer only and is consumed by the controller, so it sits beside the
stack rather than in it.

## Per-layer responsibilities and key files

### Model layer (`lib/src/core/model/`, `lib/src/core/position/`, `lib/src/core/schema/`)

The source of truth. Pure Dart, no Flutter dependency.

- `RichTextDocument` — the top-level document: a `version` + ordered list of
  `BlockNode`s.
- `BlockNode` hierarchy — `TextBlockNode` (paragraph/heading/quote/listItem),
  `CodeBlockNode`, `ImageBlockNode`, `VideoBlockNode`, `FileBlockNode`,
  `DividerBlockNode`, `CalloutBlockNode`, `TableBlockNode`. Each is immutable,
  `copy()`-able, and JSON-round-trippable.
- `InlineNode` — `TextRun` (with `TextAttributes`) and `InlineEmbed`
  (link/formula/mention/image).
- `TableModel` / `TableCellNode` — row/column/span/header/bg/width model for
  tables.
- `DocumentSchema` — the canonical repair normaliser; guarantees invariants
  (non-empty doc, consistent block attrs, non-empty cells, clamped indent).
- `DocumentPosition` / `DocumentSelection` / `PositionPath` — the selection
  contract; see `selection_model.md`.

### Command layer (`lib/src/core/commands/`)

All mutations flow through `EditorCommand` objects. Commands are immutable
descriptions of intent; the executor applies them.

- Text: `InsertTextCommand`, `DeleteBackwardCommand`, `DeleteForwardCommand`,
  `DeleteSelectionCommand`, `EnterCommand`.
- Style/inline: `FormatTextCommand`, `ClearStyleCommand`, `SetLinkCommand`,
  `ToggleMarkCommand`, `InsertInlineEmbedCommand`.
- Block structure: `SetBlockTypeCommand`, `SetAlignmentCommand`,
  `IndentCommand`, `ToggleTodoCommand`, `SetCodeLanguageCommand`,
  `ToggleQuoteCommand`, `InsertBlocksCommand`, `ReplaceBlocksCommand`.
- Selection: `MoveCaretCommand`, `MoveCaretByWordCommand`,
  `MoveCaretVerticalCommand`, `MoveCaretToBlockBoundaryCommand`,
  `MoveCaretToDocumentBoundaryCommand`, `SelectAllCommand`,
  `MoveTableCellCommand`, `MoveTableCellVerticalCommand`.
- Table structure: `InsertTableCommand`, row/column add/delete, alignment,
  width, header, background, `MergeTableCellsCommand`, `SplitTableCellCommand`.
- Plugin surface: `CommandRegistry` (name → `CommandDescriptor` →
  `EditorCommand` factory) and `CommandMiddleware` (before/after hooks).

### Transaction / History (`lib/src/core/transaction/`, `lib/src/history/`)

- `DocumentSession` — holds the current `document`, `selection`, `schema`,
  and `history`. The single mutable container everything else reads from.
- `ChangeSet` — immutable before/after pair + selection before/after +
  description + metadata. The unit of history and the observer payload.
- `CommandExecutor` — the choke point: runs middleware before-hooks, executes
  the command, applies the selection result, normalises via the schema, builds
  the `ChangeSet`, records history (with merge/coalesce), runs after-hooks.
  See `schema_and_commands.md` §Command pipeline.
- `HistoryManager` — undo/redo stack of `ChangeSet`s with coalescing rules.

### Controller layer (`lib/src/controller/`)

- `WenzRichTextController` (a `ChangeNotifier`) — the business integration
  surface. Holds the `DocumentSession`, exposes typed command methods
  (`insertText`, `setBlockType`, `insertTable`, …), the named-command
  `registry`, three change callbacks (`onChanged`, `onSelectionChanged`,
  `onCommandExecuted`), JSON/plain-text codecs, and the no-throw safe-entry
  helpers (`tryLoadJson`, `tryExecuteCommand`).
- `ToolbarController` — a derived `ChangeNotifier` that snapshots
  `ToolbarState` (active marks, block type, command enable flags) off the host
  controller on every notification.

### Input layer (`lib/src/input/`)

- `EditorTextInputClient` — the `DeltaTextInputClient` bridge that carries IME
  deltas (composing region, commit, selection) into the controller. See
  `input_system.md`.
- `ClipboardService` — copy/cut/parse for plain text, same-block rich inline,
  and cross-block rich `type:blocks` payloads.
- `CompositionState` — the IME composing region rendered as an underline span.

### Widget layer (`lib/src/widgets/`)

- `WenzRichTextEditor` — the `StatefulWidget` that lays blocks out in a
  virtualised `ListView` with keep-alive, draws the caret and selection
  overlay, and hosts the focus node injected back into the controller.
- `BlockRendererRegistry` / `BlockRenderContext` — the tier-2 extension point
  for custom block renderers (e.g. a real image decoder replacing the
  placeholder). See `rendering.md`.
- `MediaResolver` — a narrower, media-only injection point; the built-in
  image/video/file renderers consult it before falling back to the placeholder.
  Returned via `BlockRenderContext.mediaResolver`.
- `SelectionGestureOverlay` — pointer handling: tap-to-place-caret,
  drag-to-select across blocks, double/triple-click, drag auto-scroll.
- `BlockGeometryRegistry` — maps offsets ↔ coordinates for hit-testing and
  selection boxes.
- `TextLayoutService` — per-block text layout cache (offset/box/caret queries).
- `SharedTextLayoutCache` — cross-remount painter reuse for virtualised blocks.

### Codec layer (`lib/src/codecs/`)

Cross-cutting adapters between the model and JSON/text. Imported by the
controller; never imported by the command/session core.

- `RichTextJsonCodec` — versioned rich JSON (the canonical on-disk shape).
- `LegacyWenJsonCodec` — the old `wenz_editor` block-list format.
- `PlainTextCodec` — paragraph-blank-line-separated plain text export.
- `MarkdownCodec` — GitHub-Flavored Markdown import/export (line-oriented state
  machine for decode; per-block/per-run emitter for encode).
- `HtmlCodec` — HTML fragment import/export. Decode walks a DOM produced by
  `package:html` (the package's first third-party runtime dependency — pure
  Dart, official Dart team library, also used by `flutter_markdown`). Encode
  emits per-block/per-run HTML. See `migration_guide.md` §HTML import/export.
- `DocumentMigration` / `DocumentMigrationRegistry` /
  `V1ToV2DocumentMigration` — JSON-level schema migration framework.
- `document_errors.dart` — `DocumentDecodeException` /
  `UnknownCommandException`: structured errors raised by codecs and the
  command registry. See `schema_and_commands.md` §Error handling.

## Key data flow: a keystroke

```
platform key/IME  →  EditorTextInputClient  →  WenzRichTextController.insertText()
   →  CommandExecutor.execute(InsertTextCommand)
        ├─ middleware.before hooks
        ├─ command.execute(session)        // mutates a copy
        ├─ schema.normalize
        ├─ ChangeSet built, history pushed (with coalesce)
        └─ middleware.after hooks
   →  controller fires onCommandExecuted / onChanged / onSelectionChanged
   →  notifyListeners()
   →  widget rebuilds only lastChangedBlockIds blocks (incremental rebuild)
```

## Key data flow: load a document from JSON

```
controller.loadJson(source)          // or tryLoadJson for no-throw
   →  RichTextJsonCodec.decode(source)
        ├─ jsonDecode
        ├─ DocumentMigrationRegistry.migrateToCurrent  (if supplied)
        └─ RichTextDocument.fromJson
   →  controller.replaceDocument(doc)
        ├─ session.replaceDocument + schema.normalize
        ├─ history.clear()
        ├─ onChanged callback
        └─ notifyListeners()
```

On any decode failure the codec raises a `DocumentDecodeException`
(preserving the originating error on `.raw`); `loadJson` propagates it,
`tryLoadJson` catches it and returns a `TryLoadResult.ok=false` without
touching the current document.

## API stability tiers

Public API is exported from `lib/wenz_richtext.dart` and tagged in three tiers
(see the library doc comment for the full list):

- **Tier 1 (stable core)** — document/selection model, controller, history,
  core text/block/style/selection commands, `ClipboardService`,
  `EditorTextInputClient`.
- **Tier 2 (stabilising)** — editor widget, schema, codecs, migration
  framework, semantic inline/block-structure commands, command pipeline,
  renderer registry, toolbar binding, controller callbacks, structured error
  types, no-throw safe-entry helpers.
- **Tier 3 (experimental)** — table command family, rich block models
  (`CalloutBlockNode`, `FileBlockNode`) — contracts may change before the
  table editing stage is finalised.

## Where to read next

- `selection_model.md` / `selection_engine.md` — selection contract and
  cross-block gesture/layout engine.
- `schema_and_commands.md` — schema normalisation, command pipeline, error
  handling, plugin registry.
- `input_system.md` — IME bridge, clipboard, shortcuts, command merge.
- `rendering.md` — block renderer registry, virtualisation, incremental
  rebuild, shared layout cache.
- `api_reference.md` — public API surface grouped by module.
- `migration_guide.md` — adopting the package from legacy `wenz_editor` data.

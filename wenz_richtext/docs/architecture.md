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
│ WenzRichTextController, Toolbar/Outline/Stats controllers    │
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

        Codec/exporter plan layer (cross-cutting, imports model only):
        RichTextJsonCodec, LegacyWenJsonCodec, PlainTextCodec,
        MarkdownCodec, HtmlCodec, DocumentMigration,
        DocumentVersionSnapshotJsonCodec,
        WenzDocumentConversionPlan —
        (de)serialise model <-> JSON/text/Markdown/HTML and describe
        app-owned PDF/DOCX adapters

        Plugin API layer (cross-cutting, wires runtime registries):
        WenzRichTextPlugin, WenzPluginContext, WenzPluginBundle
```

**Dependency direction is strictly downward.** A higher layer may import a
lower one, never the reverse. The codec layer is the exception: it imports the
model layer only and is consumed by the controller, so it sits beside the
stack rather than in it.

## Per-layer responsibilities and key files

### Model layer (`lib/src/core/model/`, `lib/src/core/position/`, `lib/src/core/schema/`)

The source of truth. Pure Dart, no Flutter dependency.

- `RichTextDocument` — the top-level document: a `version` + ordered list of
  `BlockNode`s plus optional `CommentThread`s and `RevisionChange`s.
- `BlockNode` hierarchy — `TextBlockNode` (paragraph/heading/quote/listItem),
  `CodeBlockNode`, `ImageBlockNode`, `VideoBlockNode`, `BlockEmbedNode`,
  `FileBlockNode`, `DividerBlockNode`, `CalloutBlockNode`, `TableBlockNode`.
  Each is immutable, `copy()`-able, and JSON-round-trippable. `BlockEmbedNode`
  keeps app-owned `embedType` + JSON-compatible `data` outside the core schema
  vocabulary while still providing `fallbackText` for non-rich exports.
- `InlineNode` — `TextRun` (with `TextAttributes`) and `InlineEmbed`
  (link/formula/mention/image).
- `CommentAnchor` / `CommentThread` / `CommentEntry` — pure-Dart comment model;
  anchors round-trip through `DocumentSelection` semantics and inline text uses
  `TextAttributes.commentIds` for anchor marks.
- `RevisionRange` / `RevisionChange` — pure-Dart revision model; ranges
  round-trip through `DocumentSelection` semantics, inline text uses
  `TextAttributes.revisionIds` for marks, and top-level `revisions` stores
  author/time/status metadata.
- `DocumentVersionSnapshot` — app-owned version-history record that wraps a
  deep-copied `RichTextDocument` with id/time/author/description metadata and an
  optional `baseSnapshotId` reserved for future diff flows. Snapshot lists are
  intentionally not stored inside `RichTextDocument`.
- `TableModel` / `TableCellNode` — row/column/span/header/bg/width model for
  tables.
- `DocumentSchema` — the canonical repair normaliser; guarantees invariants
  (non-empty doc, consistent block attrs, non-empty cells, clamped indent).
  Block-level anchors live in `BlockAttributes.anchor` and are preserved during
  normalisation; optional top-level `comments` / `revisions` are preserved.
- `DocumentPosition` / `DocumentSelection` / `PositionPath` — the selection
  contract; see `selection_model.md`.

### Command layer (`lib/src/core/commands/`)

All mutations flow through `EditorCommand` objects. Commands are immutable
descriptions of intent; the executor applies them.

- Text: `InsertTextCommand`, `DeleteBackwardCommand`, `DeleteForwardCommand`,
  `DeleteSelectionCommand`, `EnterCommand` (including list continuation and
  empty-list exit behavior).
- Style/inline: `FormatTextCommand`, `ClearStyleCommand`, `SetLinkCommand`,
  `ToggleMarkCommand`, `InsertInlineEmbedCommand`.
- Block structure: `SetBlockTypeCommand`, `SetAlignmentCommand`,
  `IndentCommand`, `ToggleTodoCommand`, `SetCodeLanguageCommand`,
  `IndentCodeBlockCommand`, `SetCalloutVariantCommand`,
  `UpdateCalloutBlockCommand`, `ToggleQuoteCommand`, `InsertBlocksCommand`,
  `ReplaceBlocksCommand`, `SetBlockAnchorCommand`.
- Selection: `MoveCaretCommand`, `MoveCaretByWordCommand`,
  `MoveCaretVerticalCommand`, `MoveCaretToBlockBoundaryCommand`,
  `MoveCaretToDocumentBoundaryCommand`, `SelectAllCommand`,
  `MoveTableCellCommand`, `MoveTableCellVerticalCommand`.
- Table structure: `InsertTableCommand`, row/column add/delete, alignment,
  width, header, background, `MergeTableCellsCommand`, `SplitTableCellCommand`.
- Revisions: `InsertRevisionTextCommand`, `MarkDeletionRevisionCommand`,
  `MarkFormatRevisionCommand`, `AcceptRevisionCommand`, `RejectRevisionCommand`
  cover same-block tracked text changes and remain undo/redo-compatible.
- Command plugin surface: `CommandRegistry` (name → `CommandDescriptor` →
  `EditorCommand` factory) and `CommandMiddleware` (before/after hooks). The
  higher-level `WenzRichTextPlugin` API wires these into one install context
  with renderer, slash, toolbar, and paste extension registries.
- Permission surface: `WenzEditorPermission.read/comment/edit` is enforced by
  `WenzRichTextController` before commands enter the executor. Commands default
  to `edit`; plugins can override `EditorCommand.requiredPermission` for
  comment-only or read-only commands.

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
  helpers (`tryLoadJson`, `tryExecuteCommand`). It also owns command permission
  state and exposes `canExecute` / `canExecuteCommand` for UI disable states.
- `ToolbarController` — a derived `ChangeNotifier` that snapshots
  `ToolbarState` (active marks, block type, command enable flags) off the host
  controller on every notification.
- `WenzOutlineController` — a derived `ChangeNotifier` that snapshots
  non-empty heading blocks as `OutlineItem`s and can move the host selection to
  a heading by block id or explicit block anchor. The outline is derived state;
  it does not write a table of contents into the document.
- `WenzDocumentStatsController` — a derived `ChangeNotifier` that snapshots
  `DocumentStats` (blocks, words, visible characters, inline embeds, estimated
  reading time) from the host document. Statistics are derived state and do not
  introduce document metadata or JSON schema changes.
- `WenzAutoSaveController` — a derived `ChangeNotifier` that tracks dirty state
  by comparing rich JSON snapshots, schedules an optional debounced external
  save adapter, and marks the current snapshot clean after success. Autosave
  state is runtime UI/business state and is not serialized into the document.
- Version snapshot helpers on `WenzRichTextController` create and restore
  `DocumentVersionSnapshot` values through `replaceDocument`; durable version
  lists, retention policy, labels, and diff UI remain application-owned.

### Plugin API layer (`lib/src/plugins/`)

- `WenzRichTextPlugin` — package/app extension contract. Plugins receive a
  `WenzPluginContext` and may register named commands, command middleware,
  block renderers, inline embed renderers, slash menu items, toolbar descriptors,
  and paste transformers.
- `WenzPluginBundle` — declarative helper for common contributions; custom
  plugins can still implement `install` directly when they need conditional
  wiring.
- Plugin installation mutates runtime registries only. It does not introduce
  document fields, does not persist plugin state into rich JSON, and user-visible
  edits still need command objects for history/schema consistency.

### Input layer (`lib/src/input/`)

- `EditorTextInputClient` — the `DeltaTextInputClient` bridge that carries IME
  deltas (composing region, commit, selection) into the controller. See
  `input_system.md`.
- `ClipboardService` — copy/cut/parse for plain text, same-block rich inline,
  and cross-block rich `type:blocks` payloads. Optional
  `ClipboardPasteTransformer`s run before the built-in parser and can be
  registered through the plugin context when the host provides a growable list.
- `CompositionState` — the IME composing region rendered as an underline span.

### Widget layer (`lib/src/widgets/`)

- `WenzRichTextEditor` — the `StatefulWidget` that lays blocks out in a
  virtualised `ListView` with keep-alive, draws the caret and selection
  overlay, hosts the focus node injected back into the controller, and maps
  code-block toolbar/Tab interactions back to controller commands. It wraps
  the editing surface in a focusable multiline `Semantics` node configured by
  `WenzRichTextEditorAccessibility`, and paints a high-contrast focus outline
  when `MediaQuery.highContrast` is active.
- `BlockRendererRegistry` / `BlockRenderContext` — the tier-2 extension point
  for custom block renderers (e.g. a real image decoder replacing the
  placeholder, or a `BlockEmbedNode.embedType` business card renderer). Code
  renderers receive optional language-change/copy hooks; table renderers
  receive toolbar action and column-resize hooks so UI controls still flow
  through controller commands. `WenzObjectBlockSurface` lets custom atomic
  renderers reuse built-in object-block selection geometry. See `rendering.md`.
- `MediaResolver` — a narrower, media-only injection point; the built-in
  image/video/file renderers consult it before falling back to the placeholder.
  Returned via `BlockRenderContext.mediaResolver`.
- `InlineEmbedRendererRegistry` / `InlineEmbedRenderer` — text-span renderer
  hooks for formula / mention / custom inline embeds. The built-in text,
  callout, and table-cell renderers consult them via
  `BlockRenderContext.inlineEmbedRenderer`.
- `WenzCommentSidebar` — reusable comment-thread sidebar. It is intentionally
  outside `WenzRichTextEditor`; host apps decide where to store updated threads
  and use the sidebar's reveal callback to set editor selection.
- `SelectionGestureOverlay` — pointer handling: tap-to-place-caret,
  drag-to-select across blocks, double/triple-click, drag auto-scroll.
- `BlockGeometryRegistry` — maps offsets ↔ coordinates for hit-testing and
  selection boxes.
- `TextLayoutService` — per-block text layout cache (offset/box/caret queries).
- `SharedTextLayoutCache` — cross-remount painter reuse for virtualised blocks.

### Codec layer (`lib/src/codecs/`)

Cross-cutting adapters between the model and JSON/text. Imported by the
controller; never imported by the command/session core.

- `RichTextJsonCodec` — versioned rich JSON (the canonical on-disk shape),
  including optional comment threads and inline comment anchor ids.
- `LegacyWenJsonCodec` — the old `wenz_editor` block-list format.
- `PlainTextCodec` — paragraph-blank-line-separated plain text export.
- `MarkdownCodec` — GitHub-Flavored Markdown import/export (line-oriented state
  machine for decode; per-block/per-run emitter for encode). File and block
  embed content degrade to readable text/links, while Wenz `![video](src)`
  placeholders restore video blocks without adding Markdown-only schema.
  `import_export_strategy.md` keeps the ADV-021 block/inline acceptance matrix
  and explicit Markdown format boundaries.
- `HtmlCodec` — HTML fragment import/export. Decode walks a DOM produced by
  `package:html` (the package's first third-party runtime dependency — pure
  Dart, official Dart team library, also used by `flutter_markdown`). Encode
  emits per-block/per-run HTML, including Wenz `data-*` metadata for file/video
  and `BlockEmbedNode`, inline image attributes, and table `rowspan`/`colspan`
  round-trip. See `migration_guide.md` §HTML import/export.
- `DocumentMigration` / `DocumentMigrationRegistry` /
  `V1ToV2DocumentMigration` — JSON-level schema migration framework.
- `schema_migration_impact.md` — contributor gate for future schema changes:
  when to bump rich JSON, when to keep state external, and which migration,
  codec, and test notes are required.
- `document_errors.dart` — `DocumentDecodeException` /
  `UnknownCommandException`: structured errors raised by codecs and the
  command registry. See `schema_and_commands.md` §Error handling.

### Exporter plan layer (`lib/src/exporters/`)

Pure Dart descriptors for external document conversions that are intentionally
not core codecs.

- `document_conversion_plan.dart` — ADV-022 PDF/DOCX platform, dependency, and
  degradation matrix plus `WenzDocumentExporter<TOutput>` /
  `WenzDocumentImporter<TSource>` contracts for app-owned adapters.
- The core package keeps PDF renderers, DOCX/OOXML packages, native plugins,
  print pipelines, and server workers outside its runtime dependency graph.
- Adapters must map into or out of `RichTextDocument` without adding
  format-specific schema fields. Asset bytes, attachments, comments, revisions,
  and collaboration metadata remain owned by the host app unless a dedicated ADV
  task defines stable model support.

### Collaboration layer (`lib/src/collaboration/`)

Pure Dart/Flutter-foundation sidecar APIs for app-owned collaboration adapters.

- `WenzCollaborationAdapter` — backend contract for publishing local document
  changes and local selection while receiving remote document and selection
  streams. It intentionally avoids CRDT/OT/server-room assumptions.
- `WenzCollaborationController` — observes `WenzRichTextController` through
  `addListener` rather than taking over `onChanged` callbacks, publishes local
  rich JSON snapshots plus changed block ids, and applies remote document
  snapshots with an echo guard.
- `WenzRemoteSelectionUpdate` / `WenzCollaborationPeer` — ephemeral remote
  presence payloads for cursor/selection renderers. These are not part of the
  rich JSON schema and should be dropped when the session ends.

## Key data flow: a keystroke

```
platform key/IME  →  EditorTextInputClient  →  WenzRichTextController.insertText()
   →  controller permission guard (read/comment/edit)
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

## Key data flow: autosave a dirty document

```text
controller mutates document
   →  notifyListeners()
   →  WenzAutoSaveController compares controller.toJson()
        ├─ same JSON: ignore selection/composition-only notification
        ├─ changed JSON: mark dirty and schedule debounce
        └─ saveNow: pass AutoSaveSnapshot(json/document/revision) to adapter
   →  adapter success marks matching revision clean; failure keeps dirty + error
```

The durable target remains outside the package. Apps can store the supplied rich
JSON in local storage, a database, or a remote draft API, then restore with the
existing `loadJson` / `tryLoadJson` entry points.

## Key data flow: collaboration adapter

```text
controller mutates document/selection
   →  notifyListeners()
   →  WenzCollaborationController compares controller.toJson() + selection
        ├─ changed JSON: publish WenzLocalDocumentChange to app adapter
        └─ changed selection: publish WenzRemoteSelectionUpdate
remote adapter stream
   →  WenzCollaborationController.applyRemoteDocument()
        ├─ controller.replaceDocument(..., clearHistory: update.clearHistory)
        └─ echo guard prevents re-publishing the remote snapshot
   →  remote selection stream updates controller.remoteSelections for UI renderers
```

Collaboration state remains outside `RichTextDocument`: remote cursors,
presence, backend revisions, rooms, and transport metadata are runtime adapter
state. Comments and document revision changes are explicit schema concerns and
round-trip through rich JSON when present.

## API stability tiers

Public API is exported from `lib/wenz_richtext.dart` and tagged in three tiers
(see the library doc comment for the full list):

- **Tier 1 (stable core)** — document/selection model, controller, history,
  core text/block/style/selection commands, `ClipboardService`,
  `EditorTextInputClient`.
- **Tier 2 (stabilising)** — editor widget, schema, codecs, migration
  framework, semantic inline/block-structure commands, command pipeline,
  renderer registry, inline embed renderer, toolbar binding, controller
  callbacks, revision model/commands, collaboration adapter primitives,
  structured error types, no-throw safe-entry helpers.
- **Tier 3 (experimental)** — table command family and rich file-block model
  (`FileBlockNode`) — the file block now carries attachment metadata
  (`mimeType`, `downloadUrl`, `uploadStatus`, `uploadError`) and a command-backed
  update path, while upload/retry orchestration remains a business integration
  concern. `CalloutBlockNode` has a command-backed variant/title/icon contract
  and is treated as stabilising API.

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

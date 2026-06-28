# API reference

The public surface is everything exported from `lib/wenz_richtext.dart`. APIs
are tagged in three stability tiers (see the library doc comment for the full
tier list); this page groups them by module for quick lookup and shows the
typical call shape. For the layered design behind these types, see
`architecture.md`.

## Standard external interface (tier 1, recommended entry)

The facade + configuration pair is the recommended way to integrate the editor
without assembling the six-plus registries and controllers by hand. Both types
are tier 1 (standard external interface / recommended entry) and live behind
the single entry point `import 'package:wenz_richtext/wenz_richtext.dart';` —
no `src/` path is required. They are additive: the existing typed API
(`WenzRichTextController`, `WenzRichTextEditor`, the registries, the plugins)
stays tier 1/2 and is not deprecated.

| Type | Role |
| --- | --- |
| `WenzEditorConfiguration` | `@immutable`, side-effect-free description of *intent*. Every field is optional with a sane default, so `WenzEditorConfiguration()` is a runnable zero-config setup. Derive per-scenario variants with `copyWith`. Creates nothing and holds no `BuildContext`. |
| `WenzEditorBootstrap` | The facade. `WenzEditorBootstrap.create(configuration)` assembles the controller + every registry + derived controllers + plugins in one call, exposes unified data I/O and getters, builds the editor widget via `buildEditor({...})`, and releases everything via `dispose()` (idempotent, dependency-reverse order). |

End-to-end skeleton — `create()` → `buildEditor()` → read/write data →
`dispose()`:

```dart
import 'package:wenz_richtext/wenz_richtext.dart';

// 1) Assemble once: controller + registries + derived controllers + plugins.
final bootstrap = WenzEditorBootstrap.create(
  WenzEditorConfiguration(
    document: myDoc,                       // optional; defaults to an empty doc
    permission: WenzEditorPermission.edit, // read / comment / edit (gate, never bypassed)
    plugins: [myPlugin],                   // optional extension injection
    onChanged: (doc) => log('blocks=${doc.blocks.length}'),
  ),
);
// bootstrap.controller.document is a valid empty doc; permission == .edit

// 2) Render the editor widget from a build() method.
//    buildEditor() returns a plain WenzRichTextEditor with the assembly injected
//    (controller, blockRenderers, mediaResolver, slashMenuController,
//    findController, shortcutConfiguration, accessibility, …).
final editor = bootstrap.buildEditor(autofocus: true);

// 3) Read / write data through the facade I/O surface (delegates verbatim to
//    WenzRichTextController; no new serialization format is introduced).
final json = bootstrap.toJson();                 // rich JSON (versioned)
bootstrap.loadJson(json);                        // round-trip
bootstrap.loadMarkdown('# Hello');               // Markdown import
bootstrap.loadHtml('<h1>Hello</h1>');             // HTML import
final snap = bootstrap.createVersionSnapshot(id: 'v1'); // app-owned snapshot
bootstrap.restoreVersionSnapshot(snap);

// 4) Release everything once, in dependency-reverse order.
@override
void dispose() {
  bootstrap.dispose(); // idempotent; derived listeners released before controller
  super.dispose();
}
```

Facade getters expose the assembled pieces so a host that needs to drive a
derived controller directly still can: `controller`, `blockRendererRegistry`,
`inlineEmbedRendererRegistry`, `slashMenuRegistry`, `toolbarItemRegistry`,
`toolbarController`, `slashMenuController`, `findReplaceController`,
`outlineController`, `statsController`, `autosaveController`, plus `document`
and `selection` convenience aliases. Each derived controller is `null` when its
`enable*` flag is `false` (or, for autosave, when no `onAutosave` sink was
given).

### Configuration field → advanced extension point

Every extension is a `WenzEditorConfiguration` field; the facade feeds it into
the same registry/plugin install surface it already assembles, so an injected
custom renderer is indistinguishable from a plugin-contributed one. The fields
below map to tier 2 advanced extension points (the facade is built *on top* of
these and never bypasses them):

| Configuration field | Feeds | Advanced extension point (tier 2) |
| --- | --- | --- |
| `mediaResolver` | controller + `buildEditor` | `MediaResolver` |
| `richTextJsonCodec` | controller ctor | `RichTextJsonCodec` (+ `DocumentMigrationRegistry`) |
| `accessibility` | `buildEditor` | `WenzRichTextEditorAccessibility` |
| `plugins` | `installWenzRichTextPlugins` | `WenzRichTextPlugin` / `WenzPluginBundle` |
| `shortcutConfiguration` | merged last (host wins) | `EditorShortcutConfiguration` |
| `pasteTransformers` | `ClipboardService` | `ClipboardPasteTransformer` |
| `blockRenderers` / `blockEmbedRenderers` | `BlockRendererRegistry` | `BlockRendererBuilder` |
| `inlineEmbedRenderers` | `InlineEmbedRendererRegistry` | `InlineEmbedSpanBuilder` |
| `slashMenuItems` | `SlashMenuRegistry` | `SlashMenuItem` |
| `toolbarItems` | `WenzToolbarItemRegistry` | `WenzToolbarItem` |
| `enableSlashMenu` / `enableFindReplace` / `enableOutline` / `enableStats` / `enableToolbar` / `enableAutosave` | facade only | derived controllers (tier 2) |

The tiering is kept in sync with the library doc comment at the top of
`lib/wenz_richtext.dart`: facade/configuration are tier 1 (recommended entry),
the registries/plugins the facade wires internally remain tier 2, and anything
under `src/*` that is not re-exported stays internal. No existing public type
is renamed or removed, no runtime dependency is added, and no serialization
format changes. See `integration_guide.md` for the full contract (minimal
access, three modes, dispose order, the `src/*` internal boundary).

## Model layer (tier 1)

| Type | Purpose |
| --- | --- |
| `RichTextDocument` | Top-level document: `version` + ordered `BlockNode` list + optional `CommentThread` / `RevisionChange` lists. JSON-round-trippable via the codecs. |
| `BlockNode` (abstract) + concrete subclasses | `TextBlockNode` (paragraph/heading/quote/listItem), `CodeBlockNode`, `ImageBlockNode`, `VideoBlockNode`, `BlockEmbedNode`, `FileBlockNode`, `DividerBlockNode`, `CalloutBlockNode`, `TableBlockNode`. Immutable; `copy()` / `toJson()` / `fromJson()`. `BlockEmbedNode` stores `embedType/data/fallbackText` for business-owned block embeds; `FileBlockNode` stores `assetId/name/size/file` plus `mimeType/downloadUrl/uploadStatus/uploadError`. |
| `InlineNode` | `TextRun(text, attributes)` and `InlineEmbed(embedType, data, attributes)` (link/formula/mention/emoji/image). |
| `FileUploadStatus` | Attachment workflow state: `none`, `pending`, `uploading`, `uploaded`, `failed`; JSON stores the string name when not `none`. |
| `TextAttributes` / `BlockAttributes` | Inline run attributes (bold/italic/color/url/commentIds/revisionIds/…) and block attributes (level/indent/alignment/listType/checked/childNote/anchor). `listType` describes list marker/numbering (`null` unordered, `'ordered'` numbered, `'task'` legacy unordered todo); `checked` is the independent todo state, so `'ordered'` + non-null `checked` represents an ordered todo item. |
| `CommentAnchor` / `CommentThread` / `CommentEntry` | Comment-thread model: stores selection-compatible anchors, author/time/message payloads, and `open` / `resolved` status. |
| `RevisionRange` / `RevisionChange` | Revision model: stores selection-compatible ranges, insert/delete/format type, pending/accepted/rejected status, author/time payloads, and optional before/after format attributes. |
| `DocumentVersionSnapshot` | Application-owned version snapshot: deep-copied `RichTextDocument` plus id/time/author/description, optional `baseSnapshotId` for future diff flows, and JSON-compatible metadata. |
| `TableModel` / `TableCellNode` | Table structure: rows/columns/spans/header/bg/width. |
| `DocumentSchema` | Canonical document normaliser; invariants enforced on every command and load. |
| `DocumentPosition` / `DocumentSelection` / `PositionPath` | Selection contract — three position shapes (block text, block code, table cell) plus structured sort. |

`ImageBlockNode` carries `assetId`/`file`, natural `width`/`height`, display
`showWidth`/`showHeight`, plus `caption` and `altText`. JSON writes
`altText` and also reads a legacy/external `alt` key for compatibility.

`BlockEmbedNode` is the generic business block embed model. It JSON round-trips
`embedType`, JSON-compatible `data`, and `fallbackText`; HTML preserves these
through `data-wenz-block="embed"`, while Markdown/plain text export a readable
fallback line.

`CalloutBlockNode` carries inline `content`, a canonical `variant`
(`info`/`success`/`warning`/`danger`), and optional custom `title`/`icon`.
When `title` or `icon` is empty, renderers and Markdown/HTML export use the
variant default through `effectiveTitle` / `effectiveIcon`.

List items may freely mix unordered, ordered, legacy unordered todo, and ordered
todo semantics in the same document or nested list. Existing
`listType == 'task'` documents remain compatible as unordered todo items and are
not forcibly migrated. Ordered numbering is scoped by indent level: consecutive
same-level ordered items increment, a same-level non-ordered item interrupts the
run so later ordered items restart, and nested levels count independently.

## Commands (tier 1 / tier 2 / tier 3)

All mutations are `EditorCommand` objects routed through `CommandExecutor`.

- **Text (tier 1):** `InsertTextCommand`, `DeleteBackwardCommand`,
  `DeleteForwardCommand`, `DeleteSelectionCommand`, `EnterCommand`.
  `EnterCommand` extends list items when the current item is non-empty and
  exits the list when the current list item is empty; task-list continuations
  start unchecked.
- **Style (tier 1):** `FormatTextCommand`, `ClearStyleCommand`,
  `SetBlockTypeCommand`, `SetAlignmentCommand`.
- **Inline (tier 2):** `SetLinkCommand`, `AutoLinkUrlsCommand`,
  `ToggleMarkCommand`, `InsertInlineEmbedCommand`, plus controller helpers for
  formula, mention, emoji, and inline image embeds.
- **Revisions (tier 2):** `InsertRevisionTextCommand`,
  `MarkDeletionRevisionCommand`, `MarkFormatRevisionCommand`,
  `AcceptRevisionCommand`, `RejectRevisionCommand` for same-block tracked text
  changes.
- **Block structure (tier 2):** `IndentCommand`, `ToggleTodoCommand`,
  `SetCodeLanguageCommand`, `IndentCodeBlockCommand`,
  `SetCalloutVariantCommand`, `UpdateCalloutBlockCommand`,
  `ToggleQuoteCommand`.
  Lists use the shared `BlockAttributes.listType/checked/indent` model:
  `listType` controls unordered/ordered marker semantics, while non-null
  `checked` controls todo state. The legacy unordered todo form is
  `listType == 'task'` + `checked`; the ordered todo form is
  `listType == 'ordered'` + `checked`.
  Code blocks use `CodeBlockNode.language` plus command-backed line
  indent/outdent so toolbar and Tab edits enter undo/redo.
  Callouts use command-backed variant/title/icon updates so toolbar or business
  panels participate in undo/redo.
- **Media/block metadata (tier 2):** `UpdateImageBlockCommand`,
  `UpdateFileBlockCommand`, `SetBlockAnchorCommand`.
- **Selection (tier 1):** `MoveCaretCommand`, `MoveCaretByWordCommand`,
  `MoveCaretVerticalCommand`, `MoveCaretToBlockBoundaryCommand`,
  `MoveCaretToDocumentBoundaryCommand`, `SelectAllCommand`,
  `MoveTableCellCommand`, `MoveTableCellVerticalCommand`.
- **Table (tier 3):** `InsertTableCommand`, `InsertTableRowCommand`,
  `InsertTableColumnCommand`, `DeleteTableRowCommand`,
  `DeleteTableColumnCommand`, `SetTableColumnAlignmentCommand`,
  `SetTableColumnWidthCommand`, `SetTableCellHeaderCommand`,
  `SetTableCellBackgroundCommand`, `MergeTableCellsCommand`,
  `SplitTableCellCommand`, `InsertTableCellTextCommand`,
  `DeleteTableCellTextCommand`, `FormatTableCellTextCommand`. The default
  editor table toolbar now routes row/column, cell style, merge/split, and
  column resize interactions through this command family.
- **Pipeline (tier 2):** `CommandRegistry`, `CommandDescriptor`,
  `CommandMiddleware`, `CommandExecutor`.

## Controller (tier 1 / tier 2)

`WenzRichTextController extends ChangeNotifier` — the integration surface.

Construction:

```dart
final controller = WenzRichTextController(
  document: doc,                 // optional; defaults to an empty doc
  selection: selection,          // optional
  richTextJsonCodec: RichTextJsonCodec(migrations: registry),  // optional override
  clipboardService: ClipboardService(),                        // optional override
  mediaResolver: myResolver,     // optional; business handle (editor still needs it too)
  permission: WenzEditorPermission.edit, // read/comment/edit command policy
);
```

State accessors: `document`, `selection`, `compositionState`, `canUndo`,
`canRedo`, `lastChangedBlockIds` (incremental-rebuild signal),
`revisionModeEnabled`, `revisionAuthorId`, `revisionAuthorName`, `hasFocus`,
`requestFocus()`, `permission`, `canRead`, `canComment`, `canEdit`.

Typed command surface (sample): `insertText`, `deleteBackward`, `deleteForward`,
`deleteSelection`, `enter`, `moveCaretForward/Backward/Vertical/ByWord`,
`moveCaretToBlockBoundary`, `moveCaretToDocumentBoundary`, `selectAll`,
`formatText`, `clearStyle`, `setLink`, `autoLinkUrls`, `toggleRemark`, `setBlockType`,
`setAlignment`, `indent`, `outdent`, `toggleTodo`, `toggleQuote`,
`setCodeLanguage`, `indentCodeBlock`, `insertBlocks`, `replaceBlocks`,
`setCalloutVariant`, `updateCalloutBlock`, `updateImageBlock`, `insertFile`,
`updateFileBlock`, `insertBlockEmbed`,
`setBlockAnchor`, `setRevisionMode`, `insertRevisionText`,
`markDeletionRevision`, `markFormatRevision`, `acceptRevision`,
`rejectRevision`,
`insertTable` + the table structure family, `selectTableRow/Column`/
`selectTable`.

`insertText` applies URL auto-linking by default for `http(s)://` and `www.`
tokens, and can opt out per call with `applyAutoLinkUrls: false`.
When revision mode is enabled, typed insert/delete/format helpers route through
revision commands and create inline `revisionIds` plus top-level `revisions`.
`WenzLinkEditDialog` / `showWenzLinkEditDialog` provide the reusable Material
link-edit popup used by the example toolbar; an empty result clears the link.

Callbacks (fire synchronously before `notifyListeners`):

- `onChanged(RichTextDocument doc)`
- `onSelectionChanged(DocumentSelection? selection)`
- `onCommandExecuted(EditorCommand command, ChangeSet change)`

Serialization:

```dart
controller.toJson();                         // rich JSON
controller.toPlainText();                    // plain text, paragraphs blank-line separated
controller.toMarkdown();                     // GFM Markdown export
controller.toHtml();                         // HTML fragment export
controller.loadJson(source);                 // throws DocumentDecodeException on bad input
controller.tryLoadJson(source);              // no-throw: returns TryLoadResult
controller.loadJson(source, legacy: true);   // legacy wenz_editor block list
controller.loadMarkdown(source);             // Markdown import (lenient, never throws on content)
controller.tryLoadMarkdown(source);          // no-throw Markdown import
controller.loadHtml(source);                 // HTML import (lenient, malformed → paragraphs)
controller.tryLoadHtml(source);              // no-throw HTML import
controller.createVersionSnapshot(id: 'v1');  // app-owned version snapshot
controller.restoreVersionSnapshot(snapshot); // replace document from snapshot

controller.updateImageBlock(
  blockIndex: 0,
  showWidth: 320,
  clearShowHeight: true,
  caption: 'Figure 1',
  altText: 'Diagram of the flow',
);

controller.insertFile(
  index: 1,
  blockId: 'file-1',
  assetId: 'asset-1',
  name: 'report.pdf',
  size: 4096,
  mimeType: 'application/pdf',
  downloadUrl: 'https://cdn.example.com/report.pdf',
  uploadStatus: FileUploadStatus.uploaded,
);

controller.updateFileBlock(
  blockIndex: 1,
  uploadStatus: FileUploadStatus.failed,
  uploadError: 'network timeout',
);

controller.insertBlockEmbed(
  blockId: 'crm-1',
  embedType: 'crm-card',
  data: <String, Object?>{'recordId': '42'},
  fallbackText: 'Acme account',
);

controller.updateCalloutBlock(
  blockIndex: 0,
  variant: 'warning',
  title: 'Heads up',
  icon: '⚠️',
);

controller.setBlockAnchor(blockIndex: 0, anchor: 'introduction');
```

`HtmlCodec` preserves table `rowspan`/`colspan` through
`TableCellNode.rowSpan` / `columnSpan` plus `covered` placeholder cells; GFM
Markdown export keeps covered slots readable but cannot encode merged-cell
metadata.

Named-command surface:

```dart
controller.registry.register(CommandDescriptor(name: 'foo', factory: ...));
final enabled = controller.canExecuteCommand('foo', {'a': 1});
controller.executeCommand('foo', {'a': 1});  // throws UnknownCommandException if unknown
controller.tryExecuteCommand('foo', {'a': 1}); // returns bool, never throws
```

Permission policy: `WenzEditorPermission.read/comment/edit` gates all commands
through `EditorCommand.requiredPermission` (default: `edit`). Built-in toolbar
edit flags and undo/redo follow the controller permission; plugin commands that
should run in comment mode override `requiredPermission` to `comment`.

`ToolbarController` (tier 2) derives `ToolbarState` (active marks, block type,
command enable flags) off the host controller; see `README.md` for the
toolbar sample.

`WenzFindReplaceController` (tier 2) derives search state from a host
`WenzRichTextController` without storing anything in the document model.

```dart
final find = WenzFindReplaceController(editor: controller);
find.setQuery('invoice');
find.next();
find.setReplacement('receipt');
find.replaceCurrent();
find.replaceAll();
find.setOptions(caseSensitive: true, wholeWord: true);
```

State accessors: `query`, `replacement`, `options`, `matches`,
`currentIndex`, `currentMatch`, `hasQuery`, `hasMatches`. `FindReplaceMatch`
stores the matched `DocumentSelection`, path, offsets and matched text, so
business UI can show counts or jump to a match without recomputing ranges.

`SlashMenuController` (tier 2) derives slash-trigger state from a host
`WenzRichTextController`. It detects `/query` before the collapsed caret,
filters a `SlashMenuRegistry`, tracks the highlighted item, and activates an
item by deleting the trigger range before running the item's command action.

```dart
final slash = SlashMenuController(editor: controller);
slash.moveHighlight(1);
slash.activateHighlighted();

slash.registry.register(SlashMenuItem(
  id: 'callout',
  title: 'Callout',
  icon: 'auto_awesome',
  action: (editor, context) {
    editor.insertCallout(blockId: context.generatedId('callout'));
  },
));
```

The default registry includes `heading`, `list`, `todo`, `quote`, `code`,
`table`, and `image`. Menu actions route through existing controller commands
such as `setBlockType`, `toggleTodo`, `insertTable`, `insertBlocks`, and
`replaceBlocks`, so undo/redo remains command-based.

`WenzOutlineController` (tier 2) derives a document outline from non-empty
heading blocks. It does not store outline data in the document; each
`OutlineItem` carries `blockId`, `blockIndex`, heading `level`, `title`, and an
optional explicit `anchor`.

```dart
final outline = WenzOutlineController(editor: controller);
for (final item in outline.items) {
  print('${item.level}: ${item.title} -> ${item.target}');
}

outline.selectByAnchor('introduction'); // moves selection to the heading start
outline.selectByBlockId('heading-1');
```

`BlockAttributes.anchor` is serialized through rich JSON and can be updated via
`SetBlockAnchorCommand` or `WenzRichTextController.setBlockAnchor`. Empty or
whitespace-only anchors clear the field. `OutlineItem.target` uses the explicit
anchor when present and falls back to the block id.

`CommentThread` (tier 1) stores comment metadata in `RichTextDocument.comments`.
Its `CommentAnchor.selection` maps back to the same `DocumentSelection` contract
used by editor commands, while `TextAttributes.commentIds` marks inline text runs
that visually belong to one or more threads. Rich JSON preserves both fields;
Markdown/HTML/plain text keep document content but do not export comments.

`WenzCommentSidebar` (tier 2) renders a comment list and calls
`onRevealAnchor(thread, selection)` when a thread or locate button is activated,
so host apps can call `controller.setSelection(selection)` and rely on existing
selection scrolling. It also exposes resolve/reopen callbacks; mutating and
persisting the updated `RichTextDocument.comments` list remains app-owned until
comment commands are introduced.

`WenzDocumentStatsController` (tier 2) derives live document statistics from a
host `WenzRichTextController` without storing anything in the schema. Its
`DocumentStats` snapshot includes `blockCount`, `paragraphCount`,
`headingCount`, `imageCount`, `wordCount`, `characterCount`,
`characterCountExcludingWhitespace`, `inlineEmbedCount`,
`readingTimeMinutes`, and `readingTime`.

```dart
final stats = WenzDocumentStatsController(editor: controller);
print(stats.wordCount);
print(stats.stats.readingTimeMinutes);
```

`DocumentStats.fromDocument(doc, readingWordsPerMinute: 275)` is available for
one-off calculation. Character counts use visible textual content only (no
synthetic block separators or media sentinels); word counts treat CJK
ideographs as individual words and contiguous non-CJK letters/digits as one
word. Formula, mention, and emoji inline embeds use the same readable fallback
fields as Markdown/HTML export.

`WenzAutoSaveController` (tier 2) derives dirty state from a host
`WenzRichTextController`, compares rich JSON snapshots to ignore selection-only
notifications, and optionally runs a debounced external save callback. It does
not write autosave metadata into the document schema.

```dart
final autosave = WenzAutoSaveController(
  editor: controller,
  debounceDuration: const Duration(seconds: 2),
  onSave: (snapshot) => draftStore.put(snapshot.json),
);

print(autosave.state.status);
await autosave.saveNow();
autosave.markClean(); // for an external save flow
```

`AutoSaveState` exposes `status`, `isDirty`, `revision`, `lastChangedAt`,
`lastSaveAttemptAt`, `lastSavedAt`, and `error`. `AutoSaveSnapshot` passes the
document, rich JSON, local revision, and change time to the persistence adapter.
Successful saves mark the current snapshot clean; failed saves keep dirty state
and expose the error for UI retry affordances.

`DocumentVersionSnapshot` (tier 2) is the version-history storage unit for host
apps. It stores a deep-copied document plus `id`, `createdAt`, optional
`authorId` / `authorName`, `description`, `baseSnapshotId`, and JSON-compatible
`metadata`; the snapshot list remains outside `RichTextDocument`.

```dart
final snapshot = controller.createVersionSnapshot(
  id: 'v1',
  authorName: 'Ada',
  description: 'Before publishing',
  baseSnapshotId: 'draft-v0', // optional future diff anchor
);

const snapshotCodec = DocumentVersionSnapshotJsonCodec();
final payload = snapshotCodec.encode(snapshot);
final restored = snapshotCodec.decode(payload);
controller.restoreVersionSnapshot(restored);
```

## Collaboration adapter layer (tier 2)

| Type | Purpose |
| --- | --- |
| `WenzCollaborationAdapter` | App-owned collaboration backend bridge. Implementations publish local document changes / local selection and expose remote document / remote selection streams. |
| `WenzCollaborationController` | Optional sidecar controller that observes `WenzRichTextController` via `addListener`, publishes local mutations, applies remote document snapshots without echo, and exposes remote selections for renderer layers. |
| `WenzLocalDocumentChange` | Local change event containing `clientId`, current `RichTextDocument`, rich JSON snapshot, local revision, change time, selection, and `changedBlockIds`. |
| `WenzRemoteDocumentUpdate` | Backend-resolved remote document snapshot with optional transformed local selection and history-clear policy. |
| `WenzRemoteSelectionUpdate` | Ephemeral remote cursor/selection or clear event. It round-trips JSON for transport payloads and reports `isCursor` / `isClear`. |
| `WenzCollaborationPeer` | Lightweight peer metadata for labels, avatars, and cursor colors. |

```dart
final collaboration = WenzCollaborationController(
  editor: controller,
  adapter: myCollaborationAdapter,
  localClientId: 'client-a',
  localPeer: const WenzCollaborationPeer(
    id: 'user-a',
    displayName: 'Alice',
  ),
);

final remoteSelections = collaboration.remoteSelections;
```

The collaboration API does not store presence, cursors, selections, rooms, or
backend metadata in `RichTextDocument`. It does not bind the package to Yjs,
CRDT, OT, WebSocket, or a server implementation; adapters own that translation.

## Codec & migration layer (tier 2)

| Type | Purpose |
| --- | --- |
| `RichTextJsonCodec({migrations})` | Encode/decode the canonical versioned rich JSON. Optional `DocumentMigrationRegistry` lifts older versions. |
| `LegacyWenJsonCodec()` | Decode the old `wenz_editor` block-list format. |
| `PlainTextCodec({omitEmptyBlocks})` | Export to plain text (paragraphs blank-line separated, media sentinels; image sentinel prefers caption, then alt text). List exports preserve unordered / ordered markers and todo checkboxes, including ordered todo as `1. [ ] text` / `1. [x] text`. |
| `MarkdownCodec()` | GFM Markdown import/export. `encode` → Markdown; `decode` → document (line-oriented state machine; unrecognised lines fall back to paragraphs). Image caption uses Markdown image title: `![alt](src "caption")`; video blocks export/import through the Wenz `![video](src)` placeholder; file and block embed content degrade to readable text/links on import. Lists preserve the combined `ordered + checked` model with legacy `task` kept as unordered todo. |
| `HtmlCodec()` | HTML fragment import/export via `package:html`. `encode` → HTML; `decode` → document (DOM walk; malformed HTML falls back to paragraphs). Image block captions use `<figure><img ...><figcaption>...`; inline image embeds preserve `altText`/`caption`/`width`/`height` through `<img>` attributes; Wenz file links, video tags, and `BlockEmbedNode` preserve metadata through `data-*` attributes; table `rowspan`/`colspan` maps to `TableCellNode` spans. Ordered todo uses `<ol><li><input type="checkbox" ...>` so numbering and checked state both round-trip. |
| `DocumentVersionSnapshotJsonCodec()` | Encode/decode one `DocumentVersionSnapshot` or a snapshot list for app-owned version history persistence. |
| `DocumentMigration` / `DocumentMigrationRegistry` | JSON-level schema migration framework; ships `V1ToV2DocumentMigration`. |
| `decodeWithMigrations(source, registry)` | Helper: JSON decode + migrate in one step. |
| `DocumentDecodeException` | Structured codec error (`reason`, `jsonPath?`, `raw?`). |
| `UnknownCommandException` | Structured error raised by `CommandRegistry.build` for unknown names. |
| `TryLoadResult` | Outcome of `tryLoadJson`: `ok` / `document?` / `error?`. |
| `WenzEditorPermission` | Controller command policy: `read`, `comment`, `edit`. |

## External document conversion plan (tier 2)

| Type | Purpose |
| --- | --- |
| `WenzDocumentConversionPlan` | Declarative PDF/DOCX boundary: format, direction, owner, platform families, dependency boundaries, degradation boundaries, and summary. |
| `wenzDocumentConversionPlans` / `wenzDocumentConversionPlanFor(format, direction)` | Default ADV-022 matrix for PDF export/import and DOCX export/import. All entries keep PDF/DOCX runtime dependencies outside this package. |
| `WenzDocumentExporter<TOutput>` | App-owned export adapter contract. Implementations receive a `RichTextDocument` and return bytes, files, URLs, or another app-defined output type. |
| `WenzDocumentImporter<TSource>` | App-owned import adapter contract. Implementations receive app-defined DOCX/source input and return a `RichTextDocument`. PDF import is explicitly unsupported by the default plan. |

PDF/DOCX conversion is not wired into `WenzRichTextController`: host apps choose
their PDF renderer, print pipeline, OOXML package, native plugin, or server
worker and call the adapter from their own UI. See `import_export_strategy.md`
for the platform, dependency, asset, and degradation boundaries.

For contributor-facing schema evolution rules, see
`schema_migration_impact.md`. Public API additions that alter persisted rich
JSON must document whether they reuse the current schema, add optional fields,
or require a new `DocumentMigration` step.

## Error handling entry points (tier 2)

Two styles, pick per call site:

```dart
// 1. Typed exceptions (preferred when you can handle a failure locally)
try {
  controller.loadJson(maybeBadSource);
} on DocumentDecodeException catch (e) {
  log('${e.reason}', e.raw);   // e.raw is the originating FormatException/TypeError/…
}

// 2. No-throw safe entries (for UI code paths that must not throw)
final result = controller.tryLoadJson(maybeBadSource);
if (!result.ok) {
  showError(result.error);     // result.document is null; current doc untouched
}

final ran = controller.tryExecuteCommand('pluginCmd', args);
if (!ran) {
  // unknown, disabled, or bad args — document untouched, no callbacks fired
}
```

See `schema_and_commands.md` §Error handling for the full strategy.

## Plugin API (tier 2 / stabilising)

`WenzRichTextPlugin` is the converged extension contract for package and app
modules. A plugin installs through `WenzPluginContext`; the context always
exposes the host `WenzRichTextController` plus command registry/middleware, and
optionally exposes widget/input registries created by the host app.

- `WenzPluginBundle` — declarative plugin for common contributions:
  `commands`, `middlewares`, `blockRenderers`, `blockEmbedRenderers`, `inlineEmbedRenderers`,
  `slashMenuItems`, `toolbarItems`, `shortcutConfigurations`, and
  `pasteTransformers`.
- `installWenzRichTextPlugins` — installs a batch and rejects duplicate plugin
  ids in that batch.
- `mergeWenzShortcutConfigurations` — merges plugin shortcut fragments before
  the editor-level configuration so host apps can override plugin defaults.
- `WenzPluginApiStatus` — marks plugin-facing contracts as `stable`,
  `stabilising`, or `experimental`.

Minimal host wiring:

```dart
final pasteTransformers = <ClipboardPasteTransformer>[];
final controller = WenzRichTextController(
  clipboardService: ClipboardService(pasteTransformers: pasteTransformers),
);
final blockRenderers = BlockRendererRegistry();
WenzRichTextEditor.installDefaultRenderers(blockRenderers);
final inlineEmbeds = InlineEmbedRendererRegistry();
final slashItems = SlashMenuRegistry.defaults();
final toolbarItems = WenzToolbarItemRegistry();
final shortcutConfigurations = <EditorShortcutConfiguration>[];

installWenzRichTextPlugins(
  plugins: [myPlugin],
  context: WenzPluginContext(
    controller: controller,
    blockRenderers: blockRenderers,
    inlineEmbedRenderers: inlineEmbeds,
    slashMenuRegistry: slashItems,
    toolbarItems: toolbarItems,
    shortcutConfigurations: shortcutConfigurations,
    pasteTransformers: pasteTransformers,
  ),
);
```

The plugin layer does not persist anything by itself. User-visible document
changes must still enter through command objects so history, middleware, schema
normalisation, and `onCommandExecuted` stay consistent.

## Input layer (tier 1)

- `EditorTextInputClient` — the `DeltaTextInputClient` IME bridge carried by
  the editor widget; drives `setCompositionState` and text deltas.
- `ClipboardService` — `copy`/`parse` for plain text, same-block rich inline,
  and cross-block rich `type:blocks` payloads. `parse(..., format: ...)`
  supports explicit `plainText` / `markdown` / `html` flavours; plugin
  `ClipboardPasteTransformer`s run before the built-in parsers; `parseMarkdown`
  and `parseHtml` return structured `ClipboardPaste.blocks` payloads.
- `ClipboardPasteFormat` — selects the paste parser when the caller knows the
  platform clipboard flavour (`auto`, `plainText`, `markdown`, `html`).
- `CompositionState` — the IME composing region rendered as an underline span.
- `EditorShortcutManager` — pure keymap resolver used by the widget layer;
  includes opt-in Ctrl/Cmd+F and Ctrl/Cmd+H intents for find/replace.
- `EditorShortcutConfiguration` — shortcut keymap fragment with `bindings` and
  `disabledIntents`. Use `EditorShortcutConfiguration.merge` for low-level
  composition or `mergeWenzShortcutConfigurations` when combining plugin and
  editor-level fragments.
- `EditorShortcutBinding` / `EditorShortcutKey` — map a normalized combination
  (`LogicalKeyboardKey`, `EditorShortcutModifier`s, optional
  `EditorShortcutPlatform`s) to `handled`, `ignored`, or `passThrough`.
  `EditorShortcutModifier.primary` abstracts Ctrl on Windows/Linux/Web/Android
  and Cmd on macOS/iOS; exact `control` / `meta` / `alt` / `shift` matching is
  also available.
- `EditorShortcutResolution` / `EditorShortcutIntent` — resolver output passed
  to the widget's existing shortcut execution path. Configuration never calls
  controller commands directly.
- `EditorShortcutConfiguration.validate()` — reports duplicate combinations,
  empty platform sets, and invalid `insertCharacter` bindings. Duplicate
  combinations are deterministic: later bindings win, while multiple bindings
  for the same intent are allowed as aliases.

## Widget layer (tier 2)

- `WenzRichTextEditor({controller, shortcutConfiguration, blockRenderers, mediaResolver, inlineEmbedRenderer, onMentionTap, findController, slashMenuController, accessibility, …})` — the editor widget.
  Pass `shortcutConfiguration` to append/override the built-in keymap, disable
  intents, or return `passThrough` for host-level shortcuts such as save.
  Passing `findController` paints all search matches; `onFindRequested` and
  `onReplaceRequested` let the host open its own panel for Ctrl/Cmd+F/H.
  Passing `slashMenuController` shows the built-in slash overlay and routes
  ArrowUp/ArrowDown/Enter/Escape while it is open.
  Passing `onMentionTap` lets the host open a user profile, member card, or
  another business surface when a default `mention` inline embed is activated.
  The package only emits the event; it does not own navigation or profile UI.
- `WenzMentionTapCallback` / `WenzMentionTapDetails` — mention activation API.
  `details.id` and `details.label` are normalized from the mention embed data,
  `details.data` is the original `InlineEmbed.data`, and `details.position`,
  `blockId`, `blockIndex`, `path`, `offset`, and optional `selection` identify
  where the mention lives. Host data should provide at least `id` and `label`;
  additional business fields are preserved in `data`.
- `WenzRichTextEditorAccessibility` — screen-reader label/hint configuration
  for editable and read-only editors, plus high-contrast focus-outline color
  and width. The default editor semantics is a focusable multiline text field;
  built-in block renderers expose block, media, and table-cell labels below it.
- `WenzFindReplacePanel({controller})` — reusable basic find/replace UI with
  query, replacement, previous/next, replace current/all, case-sensitive and
  whole-word controls.
- `WenzSlashMenuOverlay({controller})` — reusable slash menu list UI. It can
  be used inside `WenzRichTextEditor` through `slashMenuController` or mounted
  by a host UI that wants custom positioning.
- `BlockRendererRegistry` / `BlockRendererBuilder` / `BlockRenderContext` —
  custom block renderer extension point.
  `WenzRichTextEditor.installDefaultRenderers(registry)` seeds the built-in
  renderers; override per-`BlockType` with `registry.register`, or register business block embeds per `BlockEmbedNode.embedType` with `registry.registerEmbed`.
  `BlockRenderContext.onCodeLanguageChanged` and `onCodeCopied` let custom code
  renderers reuse the host controller/clipboard hooks; table renderers can reuse
  `TableToolbarActionIntent`, `onTableToolbarAction`, and
  `onTableColumnResize` to delegate floating-toolbar and column-resize actions
  back to the host editor. Wrap custom atomic widgets in `WenzObjectBlockSurface(renderContext: rc, child: widget)` when they should keep built-in object-block selection, geometry, caret anchoring, and debug-overlay behaviour.
- `MediaResolver` — quick path for real image/video/file rendering. The
  built-in media renderers consult the injected resolver before falling back to
  the placeholder; returning `null` declines, throwing is tolerated (falls back
  to placeholder). The default image renderer wraps the resolved widget with
  `showWidth`/`showHeight` sizing and caption text; the default file renderer
  shows display name, size, MIME type, upload status, and failure text. See
  `rendering.md` §Media resolver.
- `InlineEmbedRendererRegistry` / `InlineEmbedRenderer` /
  `InlineEmbedRendererCallback` — quick path for formula / mention / emoji /
  custom inline embed text-span rendering. The built-in text, callout, and
  table-cell renderers consult it before falling back to compact formula /
  mention / emoji labels. When a custom renderer returns a non-null span for
  `mention`, it owns any tap recognizer or business action; return `null` to
  keep the default `@label` rendering and editor-level `onMentionTap` event, or
  call `WenzMentionTapHandler.maybeOf(context)?.notifyMentionTap(embed,
  position)` from custom code that already has a `DocumentPosition` for that
  mention.
- `WenzToolbarItem` / `WenzToolbarItemRegistry` — headless toolbar descriptor
  registry for plugin-contributed buttons or menu entries. The package does not
  impose a toolbar widget; host UI renders descriptors and calls their actions
  with `WenzRichTextController` plus current `ToolbarState`.
- `WenzRichTextController` also re-exports `HistoryManager` (tier 1) and
  `ChangeSet` (tier 1).

### Theme token boundary

`WenzRichTextEditor` does not expose a dedicated editor theme object or
background override. The public compatibility boundary remains the existing
constructor plus Flutter's ambient `ThemeData`; host apps should configure
`theme` / `darkTheme` / `ThemeMode` and may still wrap the editor in their own
surface when they need custom chrome. This keeps the public API unchanged and
avoids introducing theme data into the document model, command layer, codecs,
or plugin contracts.

The built-in widget layer resolves editor colors from these sources:

| Area | Direct `ColorScheme` use | Private editor token needed |
| --- | --- | --- |
| Editor surface | Body text from `onSurface`; focus outline, caret, selection, active object/table state, task checkbox, heading-collapse control, quote accent, resize handles, and toolbar selection from `primary`; subdued text from `onSurfaceVariant` / `outline`; find highlights from `tertiary` / `tertiaryContainer`. | The editor's own default carrying background must be derived in the widget layer: light theme uses `Colors.white`, dark theme uses `Colors.black`. This is visual chrome only and must not be serialized. |
| Text blocks and inline styles | Paragraphs/headings/quotes/lists inherit the editor body style; checked task text, heading level 5/6, inline formula/mention fallbacks, composition underline, revision background, and table-cell text use `ColorScheme` plus caller-supplied `TextStyle` / explicit inline attributes. | Link / remark colors are private semantic tokens derived for readability. Explicit `TextAttributes.color` / `background` remain document-authored data and are not theme tokens. |
| Selection, caret, and search | `_TextSelectionSurface` derives selection highlight, caret, and find-match colors from `primary`, `tertiaryContainer`, and `tertiary`. | Alpha levels for selection/search/caret contrast are private editor tokens so they can be tuned for both black and white editor backgrounds without changing public API. |
| Block surfaces | Quote, image placeholder, video fallback gradient, file-card surface/type badge/status, floating object toolbar, debug tag, selected block borders, table header cells, and formula preview use `ColorScheme` counterparts. | Surface shadows, hover fills, and selected object shells stay private visual tokens because they are implementation details of the default renderer. |
| Tables | Cell text/header text, selected-cell overlay, column resize handles, table card surface, toolbar state, table border, zebra row, and toolbar sample background are derived for light/dark themes. | Persisted `TableCellNode.backgroundColor` stays authored cell data and is not treated as a theme token. |
| Code, divider, callout, file, embed/formula | Selected borders, labels, code block background/text palette, divider line, callout variant tint/foreground/border, file-card idle border, embed card background/border, and formula card foreground/background are derived for light/dark themes. | Code syntax colors remain a private syntax palette; renderer token names are not public API. |
| Media placeholders and previews | Image placeholders, video cover fallback gradients, and metadata text can use `ColorScheme`. | Hard black/white overlay controls inside video previews are media-preview private tokens; they are not editor-background tokens and may stay fixed only where contrast is guaranteed by the preview gradient. |

The black/white background requirement lands in the widget/example layer only:
the default editor carrying surface is white for `Brightness.light` and black
for `Brightness.dark`, while the example app configures matching light and dark
scaffold/editor surfaces plus a runtime toggle. No document JSON, commands,
undo/redo, selection model, import/export codec, or plugin registration behavior
changes for theme adaptation.

## Running the example

See `running_guide.md` for Web/Windows run instructions, the verified
interaction set, and the current platform boundaries.



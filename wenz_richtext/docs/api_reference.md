# API reference

The public surface is everything exported from `lib/wenz_richtext.dart`. APIs
are tagged in three stability tiers (see the library doc comment for the full
tier list); this page groups them by module for quick lookup and shows the
typical call shape. For the layered design behind these types, see
`architecture.md`.

## Model layer (tier 1)

| Type | Purpose |
| --- | --- |
| `RichTextDocument` | Top-level document: `version` + ordered `BlockNode` list. JSON-round-trippable via the codecs. |
| `BlockNode` (abstract) + concrete subclasses | `TextBlockNode` (paragraph/heading/quote/listItem), `CodeBlockNode`, `ImageBlockNode`, `VideoBlockNode`, `FileBlockNode`, `DividerBlockNode`, `CalloutBlockNode`, `TableBlockNode`. Immutable; `copy()` / `toJson()` / `fromJson()`. |
| `InlineNode` | `TextRun(text, attributes)` and `InlineEmbed(embedType, data, attributes)` (link/formula/mention/image). |
| `TextAttributes` / `BlockAttributes` | Inline run attributes (bold/italic/color/url/…) and block attributes (level/indent/alignment/listType/checked/childNote). |
| `TableModel` / `TableCellNode` | Table structure: rows/columns/spans/header/bg/width. |
| `DocumentSchema` | Canonical document normaliser; invariants enforced on every command and load. |
| `DocumentPosition` / `DocumentSelection` / `PositionPath` | Selection contract — three position shapes (block text, block code, table cell) plus structured sort. |

## Commands (tier 1 / tier 2 / tier 3)

All mutations are `EditorCommand` objects routed through `CommandExecutor`.

- **Text (tier 1):** `InsertTextCommand`, `DeleteBackwardCommand`,
  `DeleteForwardCommand`, `DeleteSelectionCommand`, `EnterCommand`.
- **Style (tier 1):** `FormatTextCommand`, `ClearStyleCommand`,
  `SetBlockTypeCommand`, `SetAlignmentCommand`.
- **Inline (tier 2):** `SetLinkCommand`, `ToggleMarkCommand`,
  `InsertInlineEmbedCommand`.
- **Block structure (tier 2):** `IndentCommand`, `ToggleTodoCommand`,
  `SetCodeLanguageCommand`, `ToggleQuoteCommand`.
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
  `DeleteTableCellTextCommand`, `FormatTableCellTextCommand`.
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
);
```

State accessors: `document`, `selection`, `compositionState`, `canUndo`,
`canRedo`, `lastChangedBlockIds` (incremental-rebuild signal),
`hasFocus`, `requestFocus()`.

Typed command surface (sample): `insertText`, `deleteBackward`, `deleteForward`,
`deleteSelection`, `enter`, `moveCaretForward/Backward/Vertical/ByWord`,
`moveCaretToBlockBoundary`, `moveCaretToDocumentBoundary`, `selectAll`,
`formatText`, `clearStyle`, `setLink`, `toggleRemark`, `setBlockType`,
`setAlignment`, `indent`, `outdent`, `toggleTodo`, `toggleQuote`,
`setCodeLanguage`, `insertBlocks`, `replaceBlocks`, `insertTable` + the table
structure family, `selectTableRow/Column`/`selectTable`.

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
```

Named-command surface:

```dart
controller.registry.register(CommandDescriptor(name: 'foo', factory: ...));
controller.executeCommand('foo', {'a': 1});  // throws UnknownCommandException if unknown
controller.tryExecuteCommand('foo', {'a': 1}); // returns bool, never throws
```

`ToolbarController` (tier 2) derives `ToolbarState` (active marks, block type,
command enable flags) off the host controller; see `README.md` for the
toolbar sample.

## Codec & migration layer (tier 2)

| Type | Purpose |
| --- | --- |
| `RichTextJsonCodec({migrations})` | Encode/decode the canonical versioned rich JSON. Optional `DocumentMigrationRegistry` lifts older versions. |
| `LegacyWenJsonCodec()` | Decode the old `wenz_editor` block-list format. |
| `PlainTextCodec({omitEmptyBlocks})` | Export to plain text (paragraphs blank-line separated, media sentinels). |
| `MarkdownCodec()` | GFM Markdown import/export. `encode` → Markdown; `decode` → document (line-oriented state machine; unrecognised lines fall back to paragraphs). |
| `HtmlCodec()` | HTML fragment import/export via `package:html`. `encode` → HTML; `decode` → document (DOM walk; malformed HTML falls back to paragraphs). |
| `DocumentMigration` / `DocumentMigrationRegistry` | JSON-level schema migration framework; ships `V1ToV2DocumentMigration`. |
| `decodeWithMigrations(source, registry)` | Helper: JSON decode + migrate in one step. |
| `DocumentDecodeException` | Structured codec error (`reason`, `jsonPath?`, `raw?`). |
| `UnknownCommandException` | Structured error raised by `CommandRegistry.build` for unknown names. |
| `TryLoadResult` | Outcome of `tryLoadJson`: `ok` / `document?` / `error?`. |

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
  // unknown command or bad args — document untouched, no callbacks fired
}
```

See `schema_and_commands.md` §Error handling for the full strategy.

## Input layer (tier 1)

- `EditorTextInputClient` — the `DeltaTextInputClient` IME bridge carried by
  the editor widget; drives `setCompositionState` and text deltas.
- `ClipboardService` — `copy`/`parse` for plain text, same-block rich inline,
  and cross-block rich `type:blocks` payloads; `pasteHtml`/`pasteMarkdown`
  reserved (stage 6).
- `CompositionState` — the IME composing region rendered as an underline span.

## Widget layer (tier 2)

- `WenzRichTextEditor({controller, blockRenderers, mediaResolver, inlineEmbedRenderer, …})` — the editor widget.
- `BlockRendererRegistry` / `BlockRenderBuilder` / `BlockRenderContext` —
  custom block renderer extension point.
  `WenzRichTextEditor.installDefaultRenderers(registry)` seeds the built-in
  renderers; override per-`BlockType` with `registry.register`.
- `MediaResolver` — quick path for real image/video/file rendering. The
  built-in media renderers consult the injected resolver before falling back to
  the placeholder; returning `null` declines, throwing is tolerated (falls back
  to placeholder). See `rendering.md` §Media resolver.
- `InlineEmbedRenderer` / `InlineEmbedRendererCallback` — quick path for
  formula / mention / custom inline embed text-span rendering. The built-in
  text, callout, and table-cell renderers consult it before falling back to
  compact formula / mention labels.
- `WenzRichTextController` also re-exports `HistoryManager` (tier 1) and
  `ChangeSet` (tier 1).

## Running the example

See `running_guide.md` for Web/Windows run instructions, the verified
interaction set, and the current platform boundaries.

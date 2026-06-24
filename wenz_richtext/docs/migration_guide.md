# Migration guide (consumer adoption)

This guide is for **consumers** adopting `wenz_richtext` — in particular,
teams migrating data off the legacy `wenz_editor` format. (The internal
`refactor_plan.md` records the package's own refactor history and is not an
adoption guide.)

## Two JSON shapes

`wenz_richtext` understands two on-disk shapes:

1. **Rich JSON** (canonical, versioned) — the output of
   `RichTextJsonCodec.encode` / `controller.toJson()`. An object with a
   `version` field and a `blocks` array. This is the format you should write
   going forward.
2. **Legacy JSON** — the old `wenz_editor` block list. Either a bare JSON
   array of blocks, or `{"blocks": [...]}`. Decode-only (`LegacyWenJsonCodec`);
   there is no legacy *encoder*.

### Load legacy data

```dart
final controller = WenzRichTextController();

// Legacy block list → document. Non-Map entries are skipped (with a debug
// warning); unknown legacy block types fall back to paragraph.
controller.loadJson(legacyJsonString, legacy: true);
```

### Load rich JSON (with schema migration)

Rich JSON carries a `version`. If your stored documents predate the current
schema, pass a `DocumentMigrationRegistry` so older versions are lifted up to
the current one before model inflation:

```dart
final migrations = DocumentMigrationRegistry()
  ..register(const V1ToV2DocumentMigration());

final controller = WenzRichTextController(
  richTextJsonCodec: RichTextJsonCodec(migrations: migrations),
);

// A version-1 document is migrated to version 2 on decode.
controller.loadJson(richJsonString);
```

`DocumentMigrationRegistry.currentVersion` defaults to `2` (the latest). A
document already at or above `currentVersion` is returned untouched (forward
compatible — unknown future fields pass through). If a required intermediate
step is missing from the registry, decode raises a
`DocumentDecodeException` with the originating `StateError` on `.raw`.

### One-shot decode helper

`decodeWithMigrations(source, registry)` does JSON decode + migration in one
step and returns the migrated JSON map (useful when you want to inspect or
post-process the JSON before inflating):

```dart
final json = decodeWithMigrations(source, migrations);
// inspect / mutate json, then:
final doc = RichTextDocument.fromJson(json);
```

## What the v1 → v2 migration does

`V1ToV2DocumentMigration` (`lib/src/codecs/document_migration.dart`) handles
the only schema bump shipped so far:

- **Back-fills missing block ids.** v1 documents could legally omit a block
  `id` (the model synthesised one on decode). v2 requires every block to
  carry a stable id so incremental rebuild, copy/paste, and addressing all
  have a deterministic key. Missing ids are filled deterministically as
  `block-<index>`.
- **Canonicalises legacy `listType`.** v1 accepted `'unordered'` / `'li'`; v2
  treats unordered as the default (omitted), matching what `DocumentSchema`
  now enforces.
- Bumps `version` to `2` and leaves all other fields untouched.

Write your own migrations by extending `DocumentMigration` and registering
them; migrations are pure JSON transforms (they run *before* model inflation,
so renamed/removed fields never reach `fromJson`).

For contributors planning new persisted fields, `schema_migration_impact.md`
defines the schema bump rules, future v3 candidates, and the required migration
fixture/test/documentation checklist.

## Adopting: minimal controller + editor

```dart
import 'package:wenz_richtext/wenz_richtext.dart';

final controller = WenzRichTextController();   // starts on an empty doc
controller.loadJson(myRichJson);               // or legacy: true

// Wire callbacks (all fire synchronously before notifyListeners):
controller.onChanged = (doc) => saveDebounced(doc);
controller.onSelectionChanged = (sel) => updateToolbar(sel);

// Render:
WenzRichTextEditor(controller: controller);
```

## Handling decode failures

`loadJson` throws `DocumentDecodeException` on bad input (the originating
`FormatException` / type error is preserved on `.raw`); the current document
is left untouched. For UI code paths that must not throw, use `tryLoadJson`:

```dart
final result = controller.tryLoadJson(maybeBadSource);
if (!result.ok) {
  showSnack('无法打开文档：${result.error}');
  // current document, selection, history, and callbacks are all untouched
}
```

See `schema_and_commands.md` §Error handling for the full error strategy.

## Markdown import/export

`MarkdownCodec` (wired via the controller) round-trips documents against the
GitHub-Flavored Markdown subset this package models:

```dart
// Export the current document as Markdown.
final md = controller.toMarkdown();

// Import Markdown, replacing the current document.
controller.loadMarkdown(md);

// No-throw variant.
final result = controller.tryLoadMarkdown(md);
if (!result.ok) { /* result.error */ }
```

Supported syntax (aligned with the `gpt_markdown` matrix for the kinds this
package models):

- **Blocks**: ATX headings (`#{1,6}`), paragraphs, blockquotes (`> `),
  unordered (`- `/`* `), ordered (`1. `), and task (`- [x] `/`- [ ] `) lists,
  fenced code (``` ``` ``` with language), GFM pipe tables (with `:---` alignment),
  thematic breaks (`---`/`***`), and standalone images (`![alt](url)`).
- **Inline**: `**bold**`, `*italic*`, `~~strike~~`, `<u>underline</u>` (GFM has
  no native underline syntax), `[text](url)`, and `![alt](url)` embeds.

Notes:

- Markdown is lenient by design — `decode` never throws for content; any
  unrecognised line becomes a paragraph.
- Video blocks have no standard Markdown form: export emits a best-effort
  placeholder, import restores Wenz `![video](src)` placeholders. File blocks
  export as Markdown links using `FileBlockNode.displayName` and
  `effectiveDownloadUrl`; Markdown import still treats links as inline text and
  does not recreate file blocks. Block embeds export as readable fallback text;
  use rich JSON or Wenz HTML when `BlockEmbedNode.data` must round-trip.
- Image blocks preserve `altText` as Markdown alt text. When `caption` is
  present, export uses the common image-title form
  `![alt](src "caption")`; import keeps the historical `file = alt` mapping
  and also fills `altText`.
- Callouts export to blockquotes with visible icon, title, and body; the
  structured variant is not restored by plain Markdown import.
- LaTeX / radio buttons (which `gpt_markdown` supports) have no model
  counterpart here and are left as plain text.

## HTML import/export

`HtmlCodec` (wired via the controller) round-trips documents as HTML fragments:

```dart
// Export the current document as an HTML fragment.
final html = controller.toHtml();

// Import an HTML fragment, replacing the current document.
controller.loadHtml(html);

// No-throw variant.
final result = controller.tryLoadHtml(html);
if (!result.ok) { /* result.error */ }
```

Supported tags (block and inline):

- **Blocks**: `<h1>`–`<h6>`, `<p>`, `<blockquote>`, `<ul>`/`<ol>`/`<li>` (with
  `<input type="checkbox">` for task items), `<pre><code class="language-x">`,
  `<table>`/`<thead>`/`<tr>`/`<th>`/`<td>`, `<img>`, `<hr>`.
- **Inline**: `<strong>`/`<b>`, `<em>`/`<i>`, `<s>`/`<del>`/`<strike>`, `<u>`,
  `<a href>`, `<img>` (embed), `<br>`. Nested emphasis merges attributes.
- Unknown tags (`<div>`, `<span>`, …) are recursed into so their children still
  decode.

Notes:

- **Dependency**: `HtmlCodec` depends on `package:html ^0.15.6` — a pure-Dart,
  official Dart-team HTML5 parser (also used by `flutter_markdown`). This is
  the package's first third-party runtime dependency; `pubspec.yaml` records
  it. It has no native code and works on all Flutter platforms.
- HTML5 leniency: `decode` never throws for content — malformed HTML becomes
  paragraphs (the `html` package's parser is spec-compliant and self-correcting).
- HTML entities are decoded on import and re-encoded on export.
- Image blocks with caption export as
  `<figure><img ...><figcaption>...</figcaption></figure>`. `width`/`height`
  attributes restore display size (`showWidth`/`showHeight`); optional
  `data-width`/`data-height` restore natural image dimensions.
- Inline image embeds inside paragraphs export as `<img>` and preserve
  `assetId`/`altText` plus optional `caption` (`title` + `data-caption`) and
  `width`/`height`; import restores those fields into `InlineEmbed.data`.
- Callouts export as `<aside class="wenz-callout" ...>` with
  `data-callout-variant`, `data-callout-icon`, title, and body elements; HTML
  import restores those fields as `CalloutBlockNode` metadata.
- File blocks export as Wenz `<a data-wenz-block="file">` links and import
  restores `assetId`, display name, size, MIME type, local file, download URL,
  upload status, and upload error metadata.
- Block embeds export as Wenz `<div data-wenz-block="embed">` elements and
  import restores `embedType`, JSON-compatible `data`, and `fallbackText`.
- Video blocks export as `<video>` and import accepts either `src` or nested
  `<source src>`, with Wenz `data-asset-id`/`data-file` preserving round-trip
  metadata when present.
- **Clipboard paste**: `ClipboardService.parse(html, format:
  ClipboardPasteFormat.html)` parses an HTML fragment into a multi-block
  `ClipboardPaste` so pasting HTML from the browser restores block structure
  (not just flattened text). Markdown uses the same pipeline via
  `ClipboardPasteFormat.markdown`. Call these from your platform clipboard
  handler when the clipboard carries an HTML or Markdown flavour.
- HTML table `colspan`/`rowspan` are restored into existing table-cell span
  fields plus covered placeholders; Markdown file import remains a readable
  linked paragraph fallback, block embed Markdown remains readable fallback
  text, while exported `![video](src)` placeholders restore `VideoBlockNode`
  with only the visible source string preserved.

## Upgrading to 0.1.0

The first tagged release. API stability tiers are documented in the library
doc comment (`lib/wenz_richtext.dart`):

- **Tier 1 (stable core)** — document/selection model, controller, history,
  core commands, `ClipboardService`, `EditorTextInputClient`. Intended
  integration points; change only with a documented reason.
- **Tier 2 (stabilising)** — editor widget, schema, codecs, migration
  framework, semantic commands, command pipeline, callout block metadata,
  renderer registry, toolbar binding, callbacks, structured error types,
  no-throw safe-entry helpers.
- **Tier 3 (experimental)** — table command family and rich file-block model
  (`FileBlockNode`, including `mimeType`/`downloadUrl`/upload state); the
  cell-editing contract may still change before the table editing stage is
  finalised.

Known boundaries at this release (tracked in `acceptance_report.md`):

- Merged table cells are structurally preserved and the default renderer
  visually spans the anchor cell across its `rowSpan` / `columnSpan`; covered
  cells are not rendered or hit-tested.
- Markdown import/export is supported via `MarkdownCodec` (task C2). HTML
  import/export is supported via `HtmlCodec` (task C3), which depends on
  `package:html`.
- Image/video/file blocks render via an injected `MediaResolver` (the business
  layer assembles `Image`/video/download chip/any widget). Returning `null`
  falls back to built-in rendering: image/video placeholders and a file metadata
  card. `video_player` and similar stay business dependencies — the library
  itself depends on none of them. Load-failure fallback is the resolver's job
  (e.g. `Image.errorBuilder`); a throwing resolver is caught by the editor and
  falls back to built-in rendering.
- `ImageBlockNode` now has `caption` and `altText` alongside existing size
  fields. Rich JSON writes `altText` and reads legacy/external `alt` for
  compatibility; default rendering shows caption and uses alt text for image
  semantics.
- `FileBlockNode` keeps existing `assetId/name/size/file` JSON fields and adds
  optional `mimeType`, `downloadUrl`, `uploadStatus`, and `uploadError`. Older
  JSON without these fields still decodes; new retry/upload workflows should use
  `WenzRichTextController.updateFileBlock` to change status through history.
- Formula / mention inline embeds render by default and can be customised via
  `InlineEmbedRenderer`. Markdown/HTML export still degrades them to readable
  text because those formats do not round-trip the package's embed metadata.
- Block embeds use `BlockEmbedNode` plus `BlockRendererRegistry.registerEmbed`
  for business renderers. Rich JSON and Wenz HTML preserve the structured data;
  Markdown/plain text intentionally degrade to readable fallback text.
- Mobile selection handles are reserved for a later stage (task C9).

## Release-readiness checklist

Before consuming or tagging `0.1.0`, check the release-facing documents in this
order:

1. `README.md` — install, quick start, commands, serialization, extension
   points, FAQ.
2. `CHANGELOG.md` — consumer-facing changes and known alpha boundaries.
3. `docs/api_reference.md` — public API surface and stability tiers.
4. `docs/release_checklist.md` — automated, manual, and packaging gates.
5. `docs/running_guide.md` — Web / Windows example commands and supported
   interaction list.

If a release skips full Flutter validation because it only changes documents,
record the reduced validation explicitly in the release note.

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
- video/file blocks have no standard Markdown form: export emits a
  best-effort placeholder, import does not restore them.
- callouts map to blockquotes (the variant is not preserved in plain Markdown).
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
- **Clipboard paste**: `ClipboardService.pasteHtml(html)` parses an HTML
  fragment into a multi-block `ClipboardPaste` so pasting HTML from the browser
  restores block structure (not just flattened text). Call it from your
  platform clipboard handler when the clipboard carries an HTML flavour.
- Table `colspan`/`rowspan` are not restored by import (merged-cell visual is
  task B3); video/file blocks have no standard HTML form here.

## Upgrading to 0.1.0-alpha

The first tagged release. API stability tiers are documented in the library
doc comment (`lib/wenz_richtext.dart`):

- **Tier 1 (stable core)** — document/selection model, controller, history,
  core commands, `ClipboardService`, `EditorTextInputClient`. Intended
  integration points; change only with a documented reason.
- **Tier 2 (stabilising)** — editor widget, schema, codecs, migration
  framework, semantic commands, command pipeline, renderer registry, toolbar
  binding, callbacks, structured error types, no-throw safe-entry helpers.
- **Tier 3 (experimental)** — table command family and rich block models
  (`CalloutBlockNode`, `FileBlockNode`); the cell-editing contract may still
  change before the table editing stage is finalised.

Known boundaries at this release (tracked in `acceptance_report.md`):

- Merged table cells are structurally preserved and the default renderer
  visually spans the anchor cell across its `rowSpan` / `columnSpan`; covered
  cells are not rendered or hit-tested.
- Markdown import/export is supported via `MarkdownCodec` (task C2). HTML
  import/export is supported via `HtmlCodec` (task C3), which depends on
  `package:html`.
- Image/video/file blocks render via an injected `MediaResolver` (the business
  layer assembles `Image`/video/any widget; returning `null` falls back to the
  built-in placeholder). `video_player` and similar stay business dependencies
  — the library itself depends on none of them. Load-failure fallback is the
  resolver's job (e.g. `Image.errorBuilder`); a throwing resolver is caught by
  the editor and falls back to the placeholder.
- Formula / mention inline embeds render by default and can be customised via
  `InlineEmbedRenderer`. Markdown/HTML export still degrades them to readable
  text because those formats do not round-trip the package's embed metadata.
- Mobile selection handles are reserved for a later stage (task C9).

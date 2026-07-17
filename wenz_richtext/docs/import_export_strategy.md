# Import / export strategy

This document tracks the `ADV-021` Markdown/HTML import/export scope and the
`ADV-022` PDF/DOCX conversion boundary. The goal is to keep codecs small,
deterministic, and schema-neutral: codecs map external formats onto existing
document blocks, inline runs, and embeds rather than adding format-specific
model fields.

## Current support

- `MarkdownCodec` supports headings, paragraphs, quotes, unordered/ordered/task
  lists, fenced code, GFM pipe tables, dividers, links, inline emphasis, inline
  images, standalone images, Wenz video placeholders, and readable fallbacks for
  file blocks, block embeds, and custom inline embeds.
- `HtmlCodec` supports headings, paragraphs, quotes, lists/tasks, code blocks,
  tables (including `rowspan`/`colspan` mapped to table-cell spans), dividers,
  block images, inline images, video blocks, Wenz file blocks, block embeds,
  Wenz callouts, links, and nested inline emphasis.
- Both codecs are lenient on import: malformed or unknown content falls back to
  paragraphs instead of throwing for user content.

## ADV-021 increment

- HTML inline image embeds now round-trip `assetId`, `altText`, optional
  `caption`, and optional `width`/`height` through `<img>` attributes.
- Caption is exported on inline `<img>` as both `title` and `data-caption`; import
  accepts `data-caption` first, then `title` as the fallback.
- Block-level `<img>` import also accepts `data-caption`/`title` when no
  surrounding `<figure><figcaption>` is present.
- Wenz HTML file blocks now import from `<a data-wenz-block="file">`, preserving
  `assetId`, display name, size, MIME type, local file, download URL, upload
  status, and upload error metadata.
- HTML video blocks now import from `<video>` (and nested `<source src>`), with
  Wenz `data-asset-id`/`data-file` attributes preserving round-trip metadata.
- HTML block embeds import from `<div data-wenz-block="embed">`, preserving
  `embedType`, JSON-compatible `data`, and `fallbackText` for business renderers.
- HTML table cells now round-trip `rowspan`/`colspan` through existing
  `TableCellNode.rowSpan`/`columnSpan`, inserting `covered` placeholder cells so
  the model keeps a rectangular grid without adding schema fields.
- Markdown video blocks export as `![video](src)` and standalone placeholders
  import back to `VideoBlockNode`; file blocks export as ordinary links and
  reimport as linked paragraphs to avoid guessing that every standalone link is
  an attachment.

## Acceptance matrix

| Capability | Markdown | HTML | Automated entry |
| --- | --- | --- | --- |
| Headings / paragraphs / quotes | import + export | import + export | `test/codecs/markdown_codec_test.dart`, `test/codecs/html_codec_test.dart` |
| Bold / italic / strike / underline / links | import + export; underline falls back to plain text | import + export | `test/codecs/markdown_codec_test.dart`, `test/codecs/html_codec_test.dart` |
| Lists and task items | import + export | import + export | `test/codecs/markdown_codec_test.dart`, `test/codecs/html_codec_test.dart` |
| Fenced code with language | import + export | import + export | `test/codecs/markdown_codec_test.dart`, `test/codecs/html_codec_test.dart` |
| Tables | GFM pipe tables, no merged-cell metadata | HTML table with `rowspan`/`colspan` round-trip | `test/codecs/markdown_codec_test.dart`, `test/codecs/html_codec_test.dart` |
| Images and inline image embeds | block image import/export; inline image is plain Markdown image semantics | block image + inline image metadata round-trip | `test/codecs/markdown_codec_test.dart`, `test/codecs/html_codec_test.dart` |
| Video, file, and block embed blocks | readable fallback; video placeholder restores to `VideoBlockNode` | Wenz `data-*` metadata round-trip | `test/codecs/markdown_codec_test.dart`, `test/codecs/html_codec_test.dart` |
| Example demo | Markdown sample import/export preview | HTML sample import/export preview with inline image, merged table, video, and file metadata | `test/widgets/import_export_demo_test.dart` |

## Remaining boundaries

- Markdown has no structured file block import; file blocks export as links and
  import as readable paragraphs with `TextAttributes.url`, so attachment
  metadata such as `assetId`, `mimeType`, size, and upload status remains a JSON
  or Wenz HTML-only round-trip concern.
- Markdown video placeholders preserve only the visible source string. If export
  chose `VideoBlockNode.file` over `assetId`, Markdown import cannot recover the
  separate original `assetId`.
- Markdown block embeds preserve only the readable fallback. Use rich JSON or
  Wenz HTML when `BlockEmbedNode.data` must round-trip.
- Markdown / GFM has no merged-cell syntax; tables with covered cells export as
  readable pipe tables with empty covered slots, and Markdown import cannot
  recover `rowSpan`/`columnSpan` metadata.

## ADV-022 PDF/DOCX conversion boundary

PDF and DOCX conversion stays outside the core codec layer. The package exposes
`WenzDocumentConversionPlan`, `WenzDocumentExporter<TOutput>`, and
`WenzDocumentImporter<TSource>` as a lightweight app-owned adapter contract, but
does not add PDF, print, OOXML, native plugin, or server dependencies.

| Format | Direction | Core stance | Platform/dependency boundary | Degradation boundary |
| --- | --- | --- | --- | --- |
| PDF | export | supported only through a host adapter | app-owned platform plugin, platform print pipeline, or server worker; no core runtime dependency | fixed-layout output is not editable; visual layout may differ; unsupported embeds become readable text; attachments become links; assets require an external resolver |
| PDF | import | unsupported in core | no core runtime dependency | fixed-layout PDF cannot reliably become editable rich text; use OCR/extraction outside this package before mapping to the model |
| DOCX | export | host adapter | app-owned pure-Dart/OOXML package, platform plugin, or server worker; no core runtime dependency | layout may differ; unsupported embeds become readable text; attachments become links; comments/revisions remain external; assets require an external resolver |
| DOCX | import | host adapter | app-owned pure-Dart/OOXML package, platform plugin, or server worker; no core runtime dependency | unsupported styles/embeds degrade to readable text or existing blocks; comments/revisions remain external until their schema tasks land |

Resource strategy:

- Image/video/file bytes are resolved by the host adapter using existing block
  metadata (`assetId`, `file`, `downloadUrl`, MIME type, size) plus any app-side
  storage context; the core package does not own binary packaging.
- File blocks may become DOCX attachments or links at the adapter's choice; PDF
  export should prefer readable links because PDF attachment UX varies by
  platform/viewer.
- Inline embeds without a native target should use the same readable fallback as
  Markdown/HTML export, then preserve canonical data in rich JSON if round-trip
  fidelity is required.
- Comments, revisions, and collaboration metadata are intentionally external for
  now; adapters must not invent persisted schema fields before their ADV tasks.

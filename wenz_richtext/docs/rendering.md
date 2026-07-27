# Rendering Architecture

Stage 5 splits block rendering behind an extension point so consumers can replace
how a block type paints without forking the editor widget. This document covers
the registry contract, the default renderers, and the virtualisation / dirty
work still on the roadmap.

## Block renderer registry

`lib/src/widgets/block_renderer_registry.dart` defines the indirection:

- `BlockRendererRegistry` — maps `BlockType` and custom
  `BlockEmbedNode.embedType` → `BlockRendererBuilder`.
- `BlockRendererBuilder` — `Widget Function(BuildContext, BlockRenderContext)`.
- `BlockRenderContext` — bundles everything a renderer needs: the `BlockNode`,
  its `blockIndex`, the active `DocumentSelection`, the IME
  `CompositionState`, the `BlockGeometryRegistry` (for hit-testing), the
  `showCaret` flag, the ambient `textStyle`, the `showDebugOverlay` flag, and
  optional media/embed helpers (`mediaResolver`, `inlineEmbedRenderer`),
  object-block hooks (`objectBlockToolbarOverlayController`,
  `onObjectBlockAction`), and code/callout/table hooks
  (`onCodeLanguageChanged`, `onCodeCopied`, `onCalloutVariantChanged`,
  `onTableToolbarAction`, `onTableColumnResize`).

The editor consults the registry once per block in `_BlockRenderer.build`. When
no builder is registered for a block's type, the editor falls back to a
plain-text `Text(block.plainText)` so an unknown type always paints something.

## Wiring a custom renderer

Two equivalent entry points:

1. **Implicit (defaults provided).** Omit `WenzRichTextEditor.blockRenderers`.
   The editor builds a private registry with the built-in defaults installed.
   Use this when you only want default behaviour.

2. **Explicit (override what you need).** Construct a `BlockRendererRegistry`,
   seed it with `WenzRichTextEditor.installDefaultRenderers(registry)`, then
   `register` overrides for block types or `registerEmbed` overrides for
   business embed types. Pass it via `blockRenderers`.

```dart
final registry = BlockRendererRegistry();
WenzRichTextEditor.installDefaultRenderers(registry);
registry.register(BlockType.image, (context, rc) {
  final image = rc.block as ImageBlockNode;
  return MyImageDecoder(assetId: image.assetId, file: image.file);
});

WenzRichTextEditor(
  controller: controller,
  blockRenderers: registry,
);
```

A custom renderer receives the same `BlockRenderContext` the built-ins do. For
atomic object blocks, wrap the custom widget in
`WenzObjectBlockSurface(renderContext: rc, child: widget)` to keep selection
highlight, geometry registration, caret anchoring, and debug-overlay behaviour;
or ignore the surface and paint freely.

When a custom object-block renderer needs a floating toolbar, publish an
`ObjectBlockToolbarOverlayRequest` through
`BlockRenderContext.objectBlockToolbarOverlayController` and anchor it with
`ObjectBlockToolbarOverlayAnchor` / `LayerLink`. Do not insert the toolbar as a
block-layout child, spacer, or negative-offset node; selection state should not
change the measured height or position of the object block.

## Block embed renderer injection

`BlockEmbedNode` is the generic block-level embed model for business content
such as CRM cards, link previews, diagrams, or external workflow panels. It
stores `embedType`, JSON-compatible `data`, and `fallbackText`.

```dart
final registry = BlockRendererRegistry();
WenzRichTextEditor.installDefaultRenderers(registry);
registry.registerEmbed('crm-card', (context, rc) {
  final embed = rc.block as BlockEmbedNode;
  return WenzObjectBlockSurface(
    renderContext: rc,
    child: CrmCard(recordId: embed.data['recordId'] as String),
  );
});

controller.insertBlockEmbed(
  blockId: 'crm-1',
  embedType: 'crm-card',
  data: <String, Object?>{'recordId': '42'},
  fallbackText: 'Acme account',
);
```

Resolution order for `BlockEmbedNode`: an exact `registerEmbed(embedType, ...)`
builder wins; otherwise the generic `BlockType.embed` renderer paints the built-
in placeholder. Rich JSON and HTML round-trip the structured embed fields;
Markdown/plain text intentionally degrade to readable fallback text.

## Default renderers

`WenzRichTextEditor.installDefaultRenderers` registers one builder per
`BlockType`:

| BlockType | Renderer | Notes |
| --- | --- | --- |
| paragraph / heading / quote / listItem | `_TextBlockRenderer` | Inline-aware; inline formula renders math/fallback text without a default background, mention keeps its fallback pill, and both can be replaced through `InlineEmbedRenderer`; selection/caret/composition still run through `_TextSelectionSurface`. Quote is now an attribute-level decoration (`BlockAttributes.quoted`) that can wrap paragraph, heading, list, or todo semantics; legacy `BlockType.quote` is still accepted as compatible input. |
| code | `_CodeBlockRenderer` | Monospace body with syntax highlighting (`CodeSyntaxHighlighter`, see [Code block syntax highlighting](#code-block-syntax-highlighting)) and composition underline span; code blocks reserve a display-only left gutter for 1-based line numbers; toolbar includes language dropdown and copy-code button. Language changes call `SetCodeLanguageCommand`; Tab/Shift+Tab in the editor call `IndentCodeBlockCommand`. |
| image / video / file | asks `MediaResolver`, then built-in fallback | Built-in media renderers consult the injected [MediaResolver] first; when it returns `null` (or no resolver is set) images/videos fall back to built-in placeholders, while files fall back to a metadata card. Image blocks can carry remote identifiers in `assetId` and local paths/URIs in `file`; the renderer wraps the resolved widget or fallback placeholder in a finite figure frame derived from `showWidth`/`showHeight`, natural size, or the editor content width. Image `BlockAttributes.alignment` moves the whole figure frame (`null`/`center` centered, `left` at start, `right` at end); the single frame-hugging selection stroke, resize hit zones, and object toolbar follow that frame; caption stays metadata and does not add visible height. The selected image object menu exposes left / center / right / clear alignment entries in the same toolbar as image sizing. Image/video selection actions are rendered by the editor-level object-toolbar overlay, not as children in the media block layout, so selecting media does not move the frame. Video blocks place both the fallback chrome and resolver child inside a finite rounded frame that is clipped to the editor content width and safe aspect-ratio height; file cards show display name, size, MIME type, upload status, and failure text. See [Media resolver](#media-resolver). |
| embed | `_BlockEmbedContent`, `_FormulaBlockContent`, or business renderer | Generic block embed placeholder displays `embedType` + `fallbackText`/data label. Formula block embeds render source text plus display math with readable foreground and no default formula card or preview background. Register per business type with `BlockRendererRegistry.registerEmbed`; wrap large custom widgets in `WenzObjectBlockSurface` for object-block selection semantics. |
| table | `_TableBlockRenderer` | Custom Stack grid layout; visible cells are positioned by `rowSpan`/`columnSpan`, covered cells are not rendered or hit-tested; table-cell text uses the same inline embed fallback/renderer path. When a table cell/range is selected, the default renderer shows a floating toolbar for row/column insert/delete, header/background/alignment, merge/split, width reset, plus drag handles that persist explicit column widths via `SetTableColumnWidthCommand`. |
| divider | `_DividerBlockContent` | Content-width horizontal rule with a centered primary dot. The line fills the available editor content width; the dot is decoration only and must not determine the block width. Selected dividers keep a shell border and disable the generic object selection overlay. |
| callout | `_CalloutRenderer` | Variant-tinted surface with icon, title, body, and an editable type dropdown for `info`/`success`/`warning`/`danger`; uses the same inline embed fallback/renderer path. |

## Todo list layout

Default todo list items are a compact `_TextBlockRenderer` row:

- the row starts with `_kTaskListPaddingLeft = 4.0`;
- `_TodoCheckbox` keeps a stable selection-exclusion hit region and renders in a
  `20x28` slot, with the `28px` height matching the default `16px / 1.75`
  body line height;
- `_kTodoTextGap = 6.0` separates the checkbox from the editable text surface;
- wrapped todo lines remain inside the same `Expanded` text slot, so
  continuation lines align with the first text line rather than with the
  checkbox;
- ordered todo keeps the existing sequence: marker column, marker gap,
  checkbox, text gap, text.

This is render-layer geometry only. `BlockAttributes.listType`, `checked`,
todo toggle commands, serialization, clipboard handling, selection exclusion,
and business renderer overrides are unchanged.

Golden status: the current `editor_blocks.png` and `editor_advanced_blocks.png`
fixtures do not render todo blocks, so the compact todo layout is covered by
widget geometry assertions instead of updating those PNG baselines.

## Consecutive quoted text block background

A run of index-adjacent quoted `TextBlockNode`s renders as a **single continuous
quote surface**, not as a row of separate boxed blocks. Quoted blocks are text
blocks with `BlockAttributes.quoted == true`; that flag is independent from the
semantic text type, so a paragraph, heading, unordered/ordered list item, or
todo item can all be quoted without losing `level`, `listType`, or `checked`.
Legacy `BlockType.quote` remains a compatible input and is treated as quoted for
rendering. This section pins the visual contract, the grouping boundary, and the
render-only scope that the default quote renderer must satisfy.

### Visual contract

Adjacent quoted text blocks fuse into one continuous background rectangle, even
when the run mixes quoted paragraphs, quoted headings, quoted lists, and quoted
todo items:

- **No vertical gap.** The vertical spacing between two quoted blocks in the same
  group is `0`, so the two `surfaceContainer` backgrounds touch with no visible
  seam. This collapse has priority over a host-supplied `blockSpacing`; custom
  spacing still applies at quoted ↔ non-quoted boundaries, but never between two
  adjacent quoted blocks in the same group.
- **Corners only on the outer ends.** Rounded corners appear only on the first
  block's top edge and the last block's bottom edge of the whole run. Interior
  joins are square, so the run reads as one rectangle rather than stacked boxes.
  The quote surface already keeps the start (accent-bar) edge square; only the
  end edge is currently rounded (`topEnd` / `bottomEnd`).
- **Accent bar runs through.** The 4px `primary` accent bar on the start edge is
  continuous across the whole group — no break, no offset, no double stroke at
  joins. It is a vertical emphasis bar, not a slash or diagonal marker.
- **Subpixel-safe joins.** Joined edges overpaint by a tiny visual-only overlap
  so fractional virtual-list offsets or backend layer snapping cannot reveal a
  transparent seam. This overlap is decoration only and does not change block
  measurement, hit-testing, selection geometry, or semantics.
- **Uniform internal rhythm.** Vertical padding is redistributed by group
  position so the join between two blocks does not double the top/bottom inset.
  Merged text keeps a natural, even line rhythm with no doubled whitespace or
  corner notch.

### Grouping boundary

A **continuous quote group** is a maximal run of top-level blocks that are both:

1. consecutive by document index, **and**
2. `TextBlockNode` with `attributes.quoted == true`, or legacy
   `type == BlockType.quote`.

The group is decided purely by block order and quote state — not by indentation,
list markers, heading level, todo state, or list numbering. Consequences:

- `quoted → non-quoted → quoted` produces **two independent groups**. Each keeps
  its own outer rounded corners and its own accent bar; the non-quoted block
  between them is a clean boundary.
- `BlockType` continues to express text semantics (`paragraph`, `heading`,
  `listItem`). Quote is a decoration on those blocks, so quoted headings,
  quoted todo items, quoted unordered lists, and quoted ordered lists remain in
  the same quote group when adjacent.
- A quoted block may still carry an `indent` attribute; indentation does not
  extend or break the group. Grouping is adjacency + quote state only. The row
  shell may still apply its normal horizontal indent to that block; this is not
  a group boundary and must not restore vertical spacing or standalone quote
  corners.

### Why the background fuses visually, not via one container

Blocks are laid out as a virtualised, absolutely-positioned `Stack`
(`_MeasuredVirtualBlockList`): each block is measured on its own by
`_MeasuredBlockExtent`, positioned by an absolute `top`, recycled off-screen,
and selectively kept alive. Continuous quotes **must not** be collapsed into a
single container — that would break per-block measurement, virtualised
recycling, and keep-alive (caret / selection endpoints). The continuity is
achieved purely by **visual fusion** at the default quote renderer:

- `_spacingBetweenBlocks` returns `0` for quoted text block → quoted text block,
- the quote group position (first / interior / last) is precomputed by the host
  from the block list and threaded to the surface the same way `listMarker`
  already is (a sibling-derived field on `BlockRenderContext`),
- `_QuoteBlockSurface` redistributes corners and vertical padding by that
  position, keeps the accent bar continuous, and paints visual-only seam covers
  on joined edges to guard against subpixel gaps.

### Render-only scope (what does NOT change)

This is a presentation fix. The following stay untouched:

- **Document model** — quoted text blocks remain individual blocks; nothing is
  merged, and text semantics such as heading/list/todo are preserved.
- **Quote toggle** — `ToggleQuoteCommand` /
  `WenzRichTextController.toggleQuote` only changes `BlockAttributes.quoted`.
- **Serialization** — Markdown / rich JSON / HTML / plain-text export keep
  treating each quoted block independently (e.g. one `>` line per block).
- **Selection & hit-testing** — caret placement, range selection,
  `_TextSelectionSurface` geometry, and `BlockGeometryRegistry` hit resolution
  are unchanged. The fused background is paint-only; each block still owns its
  own surface and geometry. Joined-edge seam covers are wrapped as ignored,
  semantic-free decoration.
- **Find highlight** — quoted blocks' find-match painting is unchanged.
- **Virtual list** — per-block measurement (`_MeasuredBlockExtent`),
  `offsetFor` / `totalExtent` accounting, virtualised recycling, and keep-alive
  semantics are unchanged. The only layout change is the quoted → quoted spacing
  value flowing through the existing spacing path.

### Edge-case coverage matrix

| Scenario | Expected appearance |
| --- | --- |
| Single quote (isolated group) | Original rounded corners and full top/bottom padding; visually identical to pre-change. |
| Quote at document start | First block of its group: top corners rounded, keeps top padding; no neighbour above. |
| Quote at document end | Last block of its group: bottom corners rounded, keeps bottom padding; no neighbour below. |
| 3+ consecutive quotes | Interior blocks: square corners, top/bottom padding removed/narrowed so joins are seamless. |
| Empty quote inside a run | Still renders its quote surface and accent bar, keeps the run continuous, and remains an independent selectable block. |
| `quoted → non-quoted heading/list/code/paragraph/callout/… → quoted` | Two independent groups; each keeps outer corners; the intervening block uses its normal spacing on both sides. |
| Quoted paragraph adjacent to quoted heading/list/todo | Both blocks join the same group; the heading size, list marker, checkbox, completion style, caret, selection, and find highlights stay owned by the original block type. |
| Quote with `indent` attribute | Indent does not affect grouping; the block still joins its adjacent quoted neighbours by quote state. |
| Custom `blockSpacing` | Preserved at quote-group boundaries, but ignored inside the group so quoted → quoted remains seamless. |
| Adjacent non-quoted todo / list item | Not part of a quote group; todo/list spacing (`_kListItemSpacing` / `_kNestedListItemSpacing`) is unchanged outside quoted runs. |

## Divider block layout

The default divider renderer paints a full-width horizontal rule plus a centered
primary dot. The divider shell participates in object-block selection and row
geometry, but the visible line is laid out against the finite editor content
width rather than the dot's intrinsic size. In a narrow editor, the line clamps
to the available content width and never asks children for an infinite or
negative width.

Selection is intentionally minimal: a selected divider shows only the shell
border. It disables the generic object selection overlay so the line and dot are
not covered by an extra highlight rectangle. The line colour continues to come
from `_dividerLineColor(theme)`, and the centered dot remains an ornament; it is
not part of width negotiation.

## Empty text row hit targets

Text-bearing renderers must keep empty text rows visible and targetable. `_TextSelectionSurface` owns the selection geometry for paragraphs, headings, quotes, list/todo items, callout body text, code text, and table-cell text. When its logical `textLength` is `0`, the surface still contributes a hit-test box with at least the current block's minimum line height; in finite parent layouts it expands to the available editable text width.

That expansion is intentionally local to the text slot. List markers, todo checkboxes, heading collapse buttons, block handles, toolbar/menu chrome, code gutters, and table neighbouring cells stay outside the text surface or register as selection exclusions. Table cells may use the whole cell frame as `hitTestKey`, but hit coordinates are mapped back into the centred text surface so padding taps remain in the same cell instead of jumping to adjacent cells or rows.

Caret rendering also treats empty text as a normal text target: hit-testing returns offset `0`, and caret height falls back through measured height, preferred line height, and style-derived line height so the caret remains visible instead of painting with zero height.

## Table selection rendering contract

Table-cell selection is rendered as three separate states. Keep them separate in
default renderers and in custom table renderers that mirror the built-in table
behaviour:

| State | Renderer owner | Contract |
| --- | --- | --- |
| Whole-cell highlight | `_TableCellSurface.highlightWholeCell` | Paints a full-cell background inside the visible cell frame. It is for multi-cell rectangular selections and cross-block selections that visually cover table cells. A single-cell text selection must not enable it. |
| Text selection highlight | `_TextSelectionSurface.paintSelectionHighlight` inside the cell | Paints only `TextPainter.getBoxesForSelection` rectangles for text that is actually selected. Multi-cell table ranges suppress this path, so cells that are selected as grid cells do not show fake text selection. |
| Semantic selected | `_TableCellSurface` semantics | Marks a cell as selected for accessibility/state when the cell belongs to a table range, a cross-block table coverage range, or has a local text selection. This flag is not a paint instruction. |

The expected visual difference is:

- A **multi-cell rectangular table selection** paints whole-cell highlights on
  visible cells whose grid rectangles overlap the table selection rectangle.
  Covered cells (`covered == true`) are skipped entirely: they are not rendered,
  not hit-tested, and cannot paint either whole-cell or text selection
  highlights.
- A **single-cell text selection** paints selection boxes only over that cell's
  selected text range. It may mark the cell as semantically selected, but the
  cell background stays in its normal non-selected state.
- A **cross-block selection spanning a table** may paint whole-cell highlights
  for the table cells covered by the block range, while table-cell text
  selection remains limited to endpoint cells that have real text offsets.

Cell text geometry is always resolved in the padding-inner text-layout
coordinate space. The cell frame can be the hit-test box, but coordinates are
converted back to the `_TextSelectionSurface` before asking `TextLayoutService`
for offsets, carets, or selection boxes. Center and right alignment are handled
by the shared `TextPainter` inputs (`textAlign`, `textDirection`, `maxWidth`);
callers must not add a second manual alignment shift. As a result, the collapsed
caret, drag endpoints, and selection boxes for centered/right-aligned cells sit
at the visual text position inside the cell padding rather than at the cell's
left edge. Taps in left/right padding clamp to offset `0`/`textLength`, taps in
vertical centering gutters stay in the same cell, and empty cells resolve to
offset `0`.

## Inline embed renderer

`InlineEmbedRenderer` (`lib/src/widgets/inline_embed_renderer.dart`) is the
quick path for formula / mention / emoji / custom inline embed text rendering without
replacing the whole paragraph renderer:

```dart
final renderer = InlineEmbedRendererCallback((context, embed, style) {
  if (embed.embedType == 'formula') {
    return TextSpan(text: "formula(${embed.data['text']})", style: style);
  }
  return null; // keep the built-in fallback for mention / emoji / image / custom types.
});

WenzRichTextEditor(
  controller: controller,
  inlineEmbedRenderer: renderer,
);
```

The editor still treats every `InlineEmbed` as one logical character for caret
movement and selection. Prefer compact `TextSpan`s here; use
`BlockRendererRegistry` when a feature needs a large interactive widget.
Built-in fallbacks render formula math/fallback text with no default background,
mention `@label` with its mention styling, emoji unicode, inline images as
`[img]`, and unknown custom types as `[type]`. This is only a default visual
change: formula data fields, JSON / Markdown / HTML codecs, controller APIs, and
undo/redo commands are unchanged. Business `InlineEmbedRenderer` code may still
paint any background it needs.

## Code block line numbers

Code line numbers are a renderer concern, not document content:

- They are derived from `CodeBlockNode.code` at paint time and never persist to
  `CodeBlockNode`, rich/legacy JSON, Markdown, HTML, plain-text export,
  clipboard payloads, command history, or undo/redo snapshots.
- Numbering is 1-based. The line count is `code.split('\n').length`, so empty
  code displays line `1`, blank lines are counted, consecutive newlines produce
  blank numbered rows, and a trailing newline produces a final empty numbered
  row.
- `_CodeLineNumberGutter` sits to the left of the code text and reuses the
  resolved code typography exactly: the same monospace family, responsive font
  size (`13.5px` desktop / `12.5px` compact), and `1.6` line height. It aligns
  labels to the right, uses `0x8AE6E6F0`, and keeps `12px` between the gutter
  and code text. The gutter width is measured from the widest current line
  number so `9` → `10` → `100` grows without overlapping code content.
- `_CodeLineNumberGutter` registers as a selection exclusion and is not part of
  `_TextSelectionSurface`: it does not participate in text offset mapping,
  selection, caret/composition rectangles, find highlights, Tab indentation,
  language changes, or copy-code output.
- `_CodeScrollableTextSurface` owns the horizontal `SingleChildScrollView` for
  the code text only. The line-number gutter remains visually anchored at the
  left edge of the code block so long lines can scroll without dragging line
  numbers away from their rows.
- Golden coverage: `editor_blocks.png` includes the common single/multi-line
  code-block surface, while `editor_advanced_blocks.png` includes a long code
  snippet so the fixed gutter and horizontally scrollable text body remain part
  of visual regression review.

## Code block syntax highlighting

`CodeSyntaxHighlighter` (`lib/src/widgets/code_syntax_highlighter.dart`) turns a
`CodeBlockNode`'s code into a coloured `TextSpan`. It is backed by the
[`highlight`](https://pub.dev/packages/highlight) package (a Dart port of
highlight.js), not a hand-written tokenizer. `highlight()` still returns a single
`TextSpan`, so `_codeSpan()` / `_darkCodeSyntaxPalette()` in
`wenz_rich_text_editor.dart` are unchanged.

### Language coverage and registration

Languages are **selectively registered** (not `allLanguages`) to keep the bundle
small. The registered set covers every entry of `_kDefaultCodeLanguages`
(dart, javascript, typescript, python, java, kotlin, swift, go, rust, sql, json,
yaml, html/xml, css, markdown, bash) plus commonly requested languages — cpp,
cs (c#), php, ruby, scala, shell, ini (toml) and plaintext — 24 in total.

`_normalizeLanguage` lower-cases, trims, strips leading/trailing dots, and maps
common aliases to their canonical registered id before parsing, so `js`→
`javascript`, `ts`→`typescript`, `sh`/`zsh`→`bash`, `md`/`gfm`→`markdown`,
`c#`/`csharp`→`cs`, `c`→`cpp`, `html`/`xhtml`→`xml`, `toml`→`ini` all resolve.
highlight.js aliases registered alongside each mode are also resolved
automatically by `Highlight.parse`.

### Palette → highlight.js scope mapping

The highlight.js `Node` tree is walked in document order; each leaf's
`className` (scope, space-separated when compound) is mapped to one of six
`CodeSyntaxPalette` categories. Scopes with no mapping (punctuation, operators,
whitespace) are intentionally omitted, and the caller fills those gaps with
`baseStyle` — exactly as the legacy scanner did, so token granularity is finer
but unclassified text keeps the monospace base colour.

| Palette category | highlight.js scopes |
| --- | --- |
| `keyword` | `keyword`, `literal` |
| `type` | `built_in`, `type`, `class`, `title`, `function`, `attr`, `attribute`, `section` |
| `string` | `string`, `subst`, `addition` |
| `comment` | `comment`, `quote`, `doctag` |
| `number` | `number`, `symbol` |
| `marker` | `tag`, `name`, `bullet`, `link`, `meta`, `regexp`, `selector` |

Structural scopes (`tag`/`name`/`bullet`/`link`/`meta`/`regexp`/`selector`) have
no dedicated palette slot and collapse onto the `marker` category as a fallback
when no explicit mapping matches. `CodeSyntaxPalette.fromColorScheme` derives
the six colours from the ambient `ColorScheme`: `keyword`/`marker`→`primary`,
`type`→`secondary`, `string`→`tertiary`, `comment`→`onSurfaceVariant`,
`number`→`error`.

### Degradation

When highlighting cannot produce coloured tokens, the highlighter falls back to a
single `baseStyle` plain-text span (the editor's monospace code style) and never
throws. This happens when the language is unknown or not registered (after
normalization), when `highlight.parse` returns an empty node tree (e.g.
whitespace-only code), or when parsing throws.

### Composition underline

`CodeSyntaxHighlighter` accepts optional `compositionStart` / `compositionEnd`
offsets. While an IME composition is active, the corresponding character range
is overlaid with `TextDecoration.underline` during segment assembly
(`_appendSegment`), so the candidate-spelling underline survives inside
highlighted code blocks.

## Media resolver

`MediaResolver` (`lib/src/widgets/media_resolver.dart`) is the quick path for
real image/video/file rendering without replacing an entire block renderer:

```dart
class ExampleMediaResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is ImageBlockNode) {
      final source = block.file.isNotEmpty ? block.file : block.assetId;
      if (source.startsWith('http')) {
        return Image.network(source, fit: BoxFit.contain);
      }
      return null;
    }
    if (block is VideoBlockNode) {
      final source = block.effectivePlaybackUrl;
      if (!source.startsWith('http')) return null;
      return AspectRatio(
        aspectRatio: block.effectiveAspectRatio,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFE8EAED)),
          child: Center(child: Text('▶ ${block.displayText}')),
        ),
      );
    }
    return null;
  }
}

final resolver = ExampleMediaResolver();
final controller = WenzRichTextController(document: doc, mediaResolver: resolver);
controller.insertImage(
  blockId: 'image-1',
  file: '/Users/ada/Pictures/diagram.png',
  caption: 'Architecture diagram',
  altText: 'Architecture diagram',
);
controller.insertVideo(
  blockId: 'video-1',
  playbackUrl: 'https://example.com/demo.mp4',
  coverUrl: 'https://example.com/demo.jpg',
  title: 'Demo video',
  aspectRatio: 16 / 9,
);

WenzRichTextEditor(controller: controller, mediaResolver: resolver);
```

Inject the resolver in **two places**: the editor widget (drives rendering) and
the controller (business-layer handle, e.g. for an upload helper). The same
instance should be shared.

Semantics:

- Returning a widget (rather than an `ImageProvider`/URL) keeps the resolver
  fully general — the business layer assembles `Image`, a video player, a
  download chip, or any custom widget, using whatever source it owns. The
  package never needs to depend on `video_player`/`image`/etc.
- Returning `null` declines the block → the editor falls back to the built-in
  placeholder. Use this to handle only some media types or some sources.
- Image resolver widgets are placed inside an editor-owned finite figure frame.
  The default image renderer computes that frame from explicit
  `showWidth`/`showHeight`, natural `width`/`height`, or the available editor
  content width. The same frame wraps resolver widgets, empty placeholders,
  failure placeholders, the selected media stroke, resize hit zones,
  and the object-toolbar anchor. Resolver widgets should size to the incoming
  constraints and should not rely on unbounded height.
- File picking is not part of the core package. Host UI (or the example app)
  opens the platform picker, then stores the chosen local path/URI in
  `ImageBlockNode.file` through `ToolbarController.insertImage` or
  `WenzRichTextController.insertImage`. If a resolver needs `dart:io` for
  `Image.file`, isolate it behind a conditional import so Web builds keep using
  `null`/placeholder fallback for unsupported local sources.
- On Windows desktop, the picker interaction belongs to the host/example UI:
  disable the image button while the platform picker is open, show a visible
  pending indicator, treat cancellation as a silent UI restore, and surface
  picker exceptions, empty paths, or inaccessible files with a short error
  message without inserting an image block or adding history. The example keeps
  this in `example/lib/main.dart`; the core package does not add a file-picker
  dependency.
- Local-image preview helpers should validate empty sources, non-`file`
  schemes, Windows drive-letter paths, missing files, and unreadable files
  before returning a widget. Failures should render a compact fallback/error
  widget instead of throwing from the resolver into the editor.
- For large local images, return a bounded preview rather than decoding the
  original at full size. The example IO helper uses `Image.file` with
  `cacheWidth`/`cacheHeight`, plus visible loading and error builders; hosts can
  use the same strategy or generate thumbnails before handing a widget back
  through `MediaResolver`.
- Throwing from `resolve` is tolerated: the editor catches it, reports the
  error via `FlutterError.reportError` (so it surfaces in dev tools), and falls
  back to the placeholder. A faulty resolver never crashes the editor.
- Upload is a business concern: create or insert a `FileBlockNode` with
  `uploadStatus: FileUploadStatus.pending/uploading`, then store the resulting
  URL in `downloadUrl` (or legacy `file`) and flip status to `uploaded` via
  `WenzRichTextController.updateFileBlock`. On failure, set
  `uploadStatus: FileUploadStatus.failed` and `uploadError`; business UI or a
  custom `MediaResolver` can expose a retry button and drive another update.
- Image metadata stays on `ImageBlockNode`: use
  `WenzRichTextController.insertImage` to create block-level figures and
  `WenzRichTextController.updateImageBlock` to update natural size
  (`width`/`height`), display size (`showWidth`/`showHeight`), source,
  `caption`, and `altText`. The default image renderer does not show caption
  as visible editor text; semantics prefer `altText`, then caption, then the
  asset/file label. Codecs and clipboard paths keep the metadata intact. It
  also reads
  `ImageBlockNode.attributes.alignment`: `null` keeps the historical centered
  figure, `left` / `center` / `right` align the same frame within the editable
  content width, and `justify` does not stretch the image.
- The built-in slash-menu `image` / `图片` item creates a placeholder
  `ImageBlockNode` with an asset id but no natural size and no
  `showWidth`/`showHeight`. This is intentional: upload, replacement, source
  assignment, and size updates happen later through the existing image update
  APIs. The default renderer still gives that placeholder a finite content-width
  frame using `_kImagePlaceholderAspectRatio` (2:1), so inserting it from the
  slash menu does not require changing slash-menu semantics or the persisted
  image schema.
- The image alignment frame is shared by every built-in image subpart. The
  resolver widget or placeholder, selected media stroke, invisible
  resize hit zones, and object-toolbar anchor all use the same aligned frame
  rectangle. Resize hit zones provide edge dragging without adding persistent
  left/right visual lines. A custom
  image renderer registered through `BlockRendererRegistry` replaces this
  default chrome, so it can choose whether to reuse
  `block.attributes.alignment` or implement a different business layout.
- Video metadata stays on `VideoBlockNode`: use the slash menu keyword
  `video`/`视频`, `ToolbarController.insertVideo`, or
  `WenzRichTextController.insertVideo` to create a block; update playback URL,
  cover, title/description, aspect ratio, and upload state via
  `WenzRichTextController.updateVideoBlock`. The built-in renderer is a
  placeholder only; real playback belongs in the business `MediaResolver`, so
  this package does not depend on `video_player`.
- Inline video layout is bounded by the editor's rounded video frame. The frame
  width never exceeds the editor content width, the aspect ratio/height are
  clamped to safe values, and the fallback cover, play button, cover chip,
  title/source text, upload state, and `MediaResolver` child are constrained
  and clipped inside that frame. Custom players should size to the incoming
  constraints instead of relying on unbounded width or height.
- Video preview uses a dedicated fullscreen route: its black surface covers the
  complete viewport without `Dialog` insets, the former 720×560 cap, or rounded
  corners. Its viewport and zero-radius playback frame use the same complete
  finite rectangle, so fullscreen resolver output receives tight width and
  height constraints for the whole viewport. The player, rather than the outer
  frame, owns aspect fitting and any letterbox/pillarbox space. The fullscreen
  path does not reuse the inline frame's media corner radius, rounded shape,
  shadow, or `ClipRRect`; `null` and thrown resolver results use the same
  viewport-sized square boundary. The close control remains in the safe area,
  and Escape plus normal route-back navigation close the preview. For API
  compatibility the resolver entry is still named
  `WenzRichTextVideoMediaResolveEntry.dialog`, but it represents this fullscreen
  surface. Inline and fullscreen resolver calls receive independent widget
  subtrees/player instances.
- Golden status: the current `editor_blocks.png` and
  `editor_advanced_blocks.png` baselines do not render a video block, so this
  overflow fix is covered by widget tests instead of updating those images.

### Media object toolbar overlay

Built-in image and video blocks render their selected-state object toolbar
through the editor-owned `ObjectBlockToolbarOverlayHost`. The renderer owns an
`ObjectBlockToolbarOverlayAnchor` on the media frame and publishes an
`ObjectBlockToolbarOverlayRequest` through
`BlockRenderContext.objectBlockToolbarOverlayController`; the host owns the
`OverlayPortal` lifecycle. The toolbar is therefore not part of the block's
measured layout, and selecting an image or video must not add vertical space,
move the frame.

Positioning contract:

- the anchor is the media frame top edge, not the whole block row;
- for images, that frame is the post-alignment figure frame, so left/default
  center/right image blocks move the toolbar with the visible image;
- the toolbar is aligned to the frame end edge and clamped inside the overlay
  width;
- the vertical gap from the frame is `_kBlockFloatingToolbarInset`;
- the top coordinate is clamped to `visibleTop` so the toolbar stays inside the
  visible editor viewport when the frame is near the top;
- hit testing is limited to the positioned toolbar body; the overlay must not
  install a full-screen blocker.

Selection remains owned by `_MediaSelectionStroke`, which hugs the media frame
rectangle and uses the media corner radius. Image and video blocks disable the
generic full-block object selection overlay so the stroke does not cover block
margins.

For editable selected images, the default object "more" menu exposes image
left / center / right / clear alignment entries. The current explicit alignment
entry is shown as selected and disabled; when no explicit alignment is stored,
the clear entry is disabled. These actions only change
`ImageBlockNode.attributes.alignment`; the visible frame, selected media
stroke, resize hit zones, and toolbar anchor already share the same aligned
frame and therefore move together.

For editable selected images, resize remains available through invisible left
and right edge hit zones that register as selection exclusions and use the
horizontal resize cursor. Those hit zones do not paint persistent vertical
lines; drag feedback comes from the changing frame size, the frame-hugging
stroke and object-toolbar anchor following the preview size.

The overlay positioning itself is rendering-only. Image alignment persistence is
part of the document/codec contract: rich JSON and HTML preserve explicit image
alignment, while Markdown and plain text degrade to readable image content
without alignment.
Non-media object blocks such as file cards, dividers, and business embeds keep
their existing block floating toolbar path unless their renderer explicitly
migrates to `ObjectBlockToolbarOverlayController`.

### MediaResolver vs BlockRendererRegistry

Both are extension points for block rendering; pick by scope:

- **`MediaResolver`** — narrow, media-only. The built-in image/video/file
  renderers consult it. Lowest effort; ideal when you just want real media
  decoding.
- **`BlockRendererRegistry`** — whole-block replacement for any `BlockType`,
  including media, plus per-`BlockEmbedNode.embedType` business renderers. Use
  it when you need to change the surrounding chrome (selection/caret
  participation, custom layout), override a non-media block, or render a custom
  business block embed.

Priority for a media block: a custom `BlockRendererRegistry` entry wins (it
replaces the whole renderer, which would not consult the resolver at all);
otherwise the default renderer asks the `MediaResolver`; otherwise the
placeholder.

## Virtualisation (large documents)

Blocks are laid out lazily via `ListView.separated`: only blocks inside the
viewport (plus a small overflow buffer the sliver keeps) are built. Each block
is wrapped in `_KeepAliveBlock`, a `StatefulWidget` mixing in
`AutomaticKeepAliveClientMixin`. The editor marks the **caret block** (collapsed
selection) and the **selection endpoints** (`base` / `extent` block ids) as
keep-alive, so they stay mounted even after they scroll out of view.

Why keep-alive matters: selection highlight, the caret, and click hit-testing
are all painted/resolved *inside* each mounted `_TextSelectionSurface` (and
registered with the `BlockGeometryRegistry` on mount). Keeping the caret and
selection endpoints mounted guarantees:

- The caret always paints.
- The selection start/end blocks always contribute their geometry, so
  `BlockGeometryRegistry._clampToNearest` does not jump to an unrelated block.
- Cross-block selection endpoints stay addressable for word/paragraph selection.

Keep-alive is bounded: at most the caret + 2 endpoints (usually 1-2 ids after
dedup), so memory does not grow with document size the way full mounting did.

### Known boundaries (acceptable degradation, not crashes)

- **Drag into a far, never-built region.** The gesture overlay's
  `positionFromGlobalOffset` only knows mounted blocks. Dragging the pointer
  into a region that has never been built resolves to the nearest mounted block
  (via `_clampToNearest`), which may be the keep-alive caret/endpoint or the
  visible window. The selection model itself stays correct; only the *visual*
  clamp target degrades until the region scrolls into view.
- **Auto-scroll-on-drag (B2).** `SelectionGestureOverlay` drives scroll on two
  layers. (1) **Synchronous edge scroll** runs on every pointer-move for every
  device: when the pointer is within the 48px top/bottom edge band, the scroll
  offset jumps one step toward the edge. This is the primary scroll driver under
  a drag — the scrollable's own pan recognizer does not win the gesture arena
  beneath the overlay's `Listener`, so without this the list would not follow a
  touch drag at all. (2) **Continuous ticker** (mouse/stylus only): when the
  pointer is held still near an edge, a `Ticker` advances the offset every frame
  so the user can scroll past the visible area without moving the pointer. After
  each ticker-driven scroll, the overlay re-resolves the extent at the last
  pointer coordinate so the visible selection continues growing under a
  stationary pointer. Range selections produced this way do not trigger the
  editor's caret-scroll-into-view path, avoiding a fight between the two scroll
  drivers. Touch does not engage the ticker — touch selection past the viewport
  is reserved for dedicated handles (C9).
- **Auto-scroll-to-caret for far jumps.** When a programmatic selection
  change moves the caret to a block that is not currently built (e.g. jumping
  to block 400 in a 1000-block doc while viewing block 0), the editor
  estimates the target scroll offset from the average mounted-block height,
  jumps the viewport close enough for `ListView` to build the block, then a
  follow-up frame pixel-aligns so the caret sits inside the viewport. This
  avoids a `ScrollablePositionedList` dependency. The estimate degrades when
  block heights vary wildly (mixed media / code blocks); in that case the
  follow-up frame still corrects to the true position. Typing and nearby taps
  are no-ops because the caret is already in view.
- **`TextPainter` cache** lives per `_TextSelectionSurface`; a virtualised-away
  block drops its cache and re-measures on remount.

### Selection correctness across virtualised regions

`DocumentSelection` is block-index based and `DeleteSelectionCommand` /
`_selectionRangeForPath` operate over block-index ranges, not over mounted
widgets. So a selection spanning many unmounted interior blocks is still valid:
the model holds it; deleting it works; only the *highlight* for the unmounted
interior blocks is not painted (they are off-screen anyway).

## Incremental rebuild

Each controller mutation now reports which blocks changed via
`WenzRichTextController.lastChangedBlockIds` (a `Set<String>?` of block ids whose
content changed or were added in the last mutation). The editor consults it in
`_KeepAliveBlock`: a block re-renders only when its content changed
(`blockChanged`) **or** when the selection / caret / IME composition touches it.
A pure caret move inside a different block leaves untouched blocks' cached
children intact, so their inline-span rebuild is skipped.

### How the dirty set is computed

`WenzRichTextController._changedBlockIds(before, after)` diffs the document
before and after a mutation using a cheap per-block fingerprint
(`type + plainText + attributes`). A block id is "changed" when its fingerprint
differs or it is newly added. The fingerprint may produce false positives
(re-render a block that did not visually change) but never false negatives, so
correctness is preserved. Removed block ids are not included (nothing to rebuild
for them).

Special cases:

- `lastChangedBlockIds` is `null` when no diff was available (e.g. before any
  mutation). The editor treats `null` as "rebuild everything".
- Selection-only and composition-only changes set the set to empty
  (`{}`) — no block content changed.
- A no-op command does not notify listeners at all, so the set reflects the
  prior mutation.

### What still rebuilds unconditionally

A block always re-renders when it is a selection endpoint, an interior block of
a multi-block range (fully highlighted), the caret block, or the
composition-bearing block. Ambient `textStyle` / `showDebugOverlay` /
`blockRenderers` changes also force every block to re-render. These are rare
and correct.

## Shared text-layout cache

Each `_TextSelectionSurface` used to own a private `TextLayoutService` (which
caches one laid-out `TextPainter` keyed on span/align/width). Under
virtualisation a block scrolled out of view unmounts its surface and dropped
that painter, so re-entering the block re-measured it from scratch.

`SharedTextLayoutCache` (held by the editor state, exposed down the subtree via
`_SharedLayoutCacheScope`) keeps a `TextLayoutService` per surface identity
`(blockId, path)` alive **across remount**. A surface fetches its entry on mount
instead of creating a fresh one; unmount no longer discards it. Re-entering a
previously-viewed block reuses the already-laid-out painter.

Invalidation:
- When `WenzRichTextController.lastChangedBlockIds` reports a block changed, the
  editor calls `removeBlock(id)` so a stale painter is not reused.
- Removed block ids drop all their surface entries.
- `dispose()` (editor teardown) drops everything.

When no scope is present (e.g. a test mounting a surface in isolation), the
surface falls back to a private `TextLayoutService`, so behaviour is unchanged.

## Benchmarks

`test/benchmarks/editor_benchmarks.dart` measures per-frame build/layout/paint
cost for the stage-5 scenarios. The file is named **without** the `_test.dart`
suffix on purpose, so `flutter test` (which only auto-discovers `*_test.dart`)
does **not** run them in the regular suite. Run them explicitly:

```
flutter test test/benchmarks/editor_benchmarks.dart
```

Each case mounts the editor in a fixed 800×600 viewport, warms up 3 frames,
then times 20 frames and prints average + max µs/frame. Cases:

| Case | Document | Loose guard |
| --- | --- | --- |
| 1k blocks (idle) | 1000 paragraphs | avg < 50ms/frame |
| 1k blocks (editing) | 1000 paragraphs + caret tick | avg < 50ms/frame |
| 10k inline runs | 1 paragraph, 10000 runs | avg < 120ms/frame |
| large table | 50×20 cells | avg < 120ms/frame |
| advanced mixed document | 200 groups of paragraph/callout/code/file blocks with mention/formula inline embeds | avg < 90ms/frame |
| 1k blocks scroll (remount) | 1000 paragraphs, drag-scroll | avg < 80ms/frame |

The guards are deliberately loose (well above the measured numbers on a dev
machine) — their job is to catch a catastrophic regression
(e.g. virtualisation accidentally disabled, every block rebuilt every frame),
not to flake on slower hosts. For real before/after signal, compare the printed
µs numbers on the same machine.

Reference numbers (this machine, after the custom table grid layout / B3):

- 1k blocks idle: ~86µs avg, ~259µs max
- 1k blocks editing: ~49µs avg, ~88µs max
- 10k inline runs: ~51µs avg, ~95µs max
- 50×20 table: ~37µs avg, ~46µs max
- advanced mixed document: run locally with the same command to compare against
  the 90ms guard
- 1k blocks scroll (remount): ~18ms avg (includes gesture + layout)

## Table merged-cell layout

The model stores `rowSpan`/`columnSpan` on the visible anchor cell and marks
covered cells with `covered=true`. The default table renderer now uses a custom
Stack-based grid layout instead of Flutter `Table`, so an anchor cell is
positioned over the full cross-row / cross-column rectangle and covered cells
are skipped entirely. The same outer cell frame remains registered with
`BlockGeometryRegistry`, so taps anywhere inside the merged visual cell resolve
to the anchor cell for caret placement and selection.

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
  optional code/callout/table hooks (`onCodeLanguageChanged`, `onCodeCopied`,
  `onCalloutVariantChanged`, `onTableToolbarAction`, `onTableColumnResize`).

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
  return MyImageDecoder(assetId: (rc.block as ImageBlockNode).assetId);
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
| paragraph / heading / quote / listItem | `_TextBlockRenderer` | Inline-aware; formula/mention fallback + optional `InlineEmbedRenderer`; selection/caret/composition via `_TextSelectionSurface`. |
| code | `_CodeBlockRenderer` | Monospace body with composition underline span; toolbar includes language dropdown and copy-code button. Language changes call `SetCodeLanguageCommand`; Tab/Shift+Tab in the editor call `IndentCodeBlockCommand`. |
| image / video / file | asks `MediaResolver`, then built-in fallback | Built-in media renderers consult the injected [MediaResolver] first; when it returns `null` (or no resolver is set) images/videos fall back to `_MediaPlaceholder`, while files fall back to a metadata card. Image blocks wrap the result with `showWidth`/`showHeight` sizing and optional caption text; file cards show display name, size, MIME type, upload status, and failure text. See [Media resolver](#media-resolver). |
| embed | `_BlockEmbedContent` or business renderer | Generic block embed placeholder displays `embedType` + `fallbackText`/data label. Register per business type with `BlockRendererRegistry.registerEmbed`; wrap large custom widgets in `WenzObjectBlockSurface` for object-block selection semantics. |
| table | `_TableBlockRenderer` | Custom Stack grid layout; visible cells are positioned by `rowSpan`/`columnSpan`, covered cells are not rendered or hit-tested; table-cell text uses the same inline embed fallback/renderer path. When a table cell/range is selected, the default renderer shows a floating toolbar for row/column insert/delete, header/background/alignment, merge/split, width reset, plus drag handles that persist explicit column widths via `SetTableColumnWidthCommand`. |
| divider | Flutter `Divider`. | |
| callout | `_CalloutRenderer` | Variant-tinted surface with icon, title, body, and an editable type dropdown for `info`/`success`/`warning`/`danger`; uses the same inline embed fallback/renderer path. |

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
Built-in fallbacks display formula text, mention `@label`, emoji unicode, inline
images as `[img]`, and unknown custom types as `[type]`.

## Media resolver

`MediaResolver` (`lib/src/widgets/media_resolver.dart`) is the quick path for
real image/video/file rendering without replacing an entire block renderer:

```dart
class NetworkImageResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is! ImageBlockNode) return null;
    final url = block.file.isNotEmpty ? block.file : block.assetId;
    if (!url.startsWith('http')) return null;       // let the placeholder show
    return Image.network(url, fit: BoxFit.contain,
      errorBuilder: (_, e, __) => const Text('image load failed'));
  }
}

final resolver = NetworkImageResolver();
final controller = WenzRichTextController(document: doc, mediaResolver: resolver);

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
  `WenzRichTextController.updateImageBlock` to update natural size
  (`width`/`height`), display size (`showWidth`/`showHeight`), `caption`, and
  `altText`. The default image renderer shows the caption below either the
  resolver widget or fallback placeholder; semantics prefer `altText`, then
  caption, then the asset/file label.

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

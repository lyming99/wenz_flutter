# Rendering Architecture

Stage 5 splits block rendering behind an extension point so consumers can replace
how a block type paints without forking the editor widget. This document covers
the registry contract, the default renderers, and the virtualisation / dirty
work still on the roadmap.

## Block renderer registry

`lib/src/widgets/block_renderer_registry.dart` defines the indirection:

- `BlockRendererRegistry` — maps `BlockType` → `BlockRendererBuilder`.
- `BlockRendererBuilder` — `Widget Function(BuildContext, BlockRenderContext)`.
- `BlockRenderContext` — bundles everything a renderer needs: the `BlockNode`,
  its `blockIndex`, the active `DocumentSelection`, the IME
  `CompositionState`, the `BlockGeometryRegistry` (for hit-testing), the
  `showCaret` flag, the ambient `textStyle`, and the `showDebugOverlay` flag.

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
   `register` overrides for the types you want to change. Pass it via
   `blockRenderers`.

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

A custom renderer receives the same `BlockRenderContext` the built-ins do, so it
can participate in selection highlight, caret, and debug behaviour by reusing
the existing `_TextSelectionSurface` — or ignore all of it and paint freely.

## Default renderers

`WenzRichTextEditor.installDefaultRenderers` registers one builder per
`BlockType`:

| BlockType | Renderer | Notes |
| --- | --- | --- |
| paragraph / heading / quote / listItem | `_TextBlockRenderer` | Inline-aware; selection/caret/composition via `_TextSelectionSurface`. |
| code | `_CodeBlockRenderer` | Monospace; composition underline span. |
| image / video / file | asks `MediaResolver`, then `_MediaPlaceholder` | Built-in media renderers consult the injected [MediaResolver] first; when it returns `null` (or no resolver is set) they fall back to the placeholder. See [Media resolver](#media-resolver). |
| table | `_TableBlockRenderer` | Flutter `Table`; covered (merged) cells hidden. |
| divider | Flutter `Divider`. | |
| callout | `_CalloutRenderer` | Variant-tinted surface. |

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
- Upload is a business concern: do it before calling `insertBlocks`, then store
  the resulting URL in `assetId`/`file` (opaque business handles); the resolver
  reads those fields.

### MediaResolver vs BlockRendererRegistry

Both are extension points for block rendering; pick by scope:

- **`MediaResolver`** — narrow, media-only. The built-in image/video/file
  renderers consult it. Lowest effort; ideal when you just want real media
  decoding.
- **`BlockRendererRegistry`** — whole-block replacement for any `BlockType`,
  including media. Use it when you need to change the surrounding chrome
  (selection/caret participation, custom layout) or override a non-media block.

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
| 1k blocks scroll (remount) | 1000 paragraphs, drag-scroll | avg < 80ms/frame |

The guards are deliberately loose (orders of magnitude above the measured
~30–80µs on a dev machine) — their job is to catch a catastrophic regression
(e.g. virtualisation accidentally disabled, every block rebuilt every frame),
not to flake on slower hosts. For real before/after signal, compare the printed
µs numbers on the same machine.

Reference numbers (this machine, after stage 5-2/5-3/5-4):

- 1k blocks idle: ~62µs avg, ~200µs max
- 1k blocks editing: ~30µs avg, ~34µs max
- 10k inline runs: ~31µs avg, ~79µs max
- 50×20 table: ~42µs avg, ~169µs max
- 1k blocks scroll (remount): ~9ms avg (includes gesture + layout)

## What is NOT yet done (stage 5 roadmap)

- **Merged-cell visual layout.** The model stores `rowSpan`/`columnSpan`/
  `covered`; the current Flutter `Table` cannot natively span cells, so a merged
  anchor renders in its 1×1 slot with covered cells hidden. Full cross-row/
  cross-column visual spanning awaits a custom table layout (stage 5+).

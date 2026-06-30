# Integration guide — standard external interface

This guide is the authoritative contract for integrating the Wenz RichText
editor from outside the package. It defines **what the standard external
interface is**, **where the stability boundary runs** (tier 1 / tier 2 /
internal), and **how to wire the full lifecycle** — *create → render → read &
write data → extend → destroy* — without reaching into the six-plus registries
and controllers by hand.

If you only need the business-facing quick reference, start with the root
[README interface documentation](../README.md#接口文档). This guide keeps the
detailed integration contract, lifecycle rules, permission boundary, and
internal stability boundary.

> **TL;DR** — The standard external interface is exactly two types:
> [`WenzEditorConfiguration`](#1-what-the-standard-interface-is) (a declarative
> description of intent) + [`WenzEditorBootstrap`](#1-what-the-standard-interface-is)
> (the facade that assembles, builds, and disposes). Everything else below is
> either a configuration field, a facade getter, or an advanced extension point
> for hosts that need more than the facade exposes.

The tier list in [§2](#2-stability-boundary--three-tiers) is kept in sync with
the stability tiers declared in the library doc comment at the top of
`lib/wenz_richtext.dart`. When in doubt, that header is the single source of
truth for tier membership.

---

## 1. What the standard interface is

```dart
import 'package:wenz_richtext/wenz_richtext.dart';
```

The standard external interface is **a facade plus a configuration object**:

| Type | Role | Stability tier |
| --- | --- | --- |
| `WenzEditorConfiguration` | A `@immutable`, side-effect-free description of *intent*: initial document/selection, permission, media resolver, codec/migrations, accessibility, plugins, shortcuts, paste transformers, callbacks, and on/off switches for the built-in derived controllers. Describes what you want; never creates anything. | tier 1 (recommended entry) |
| `WenzEditorBootstrap` | The facade. `WenzEditorBootstrap.create(configuration)` assembles the `WenzRichTextController` + every registry + the derived controllers + plugins in one call, exposes unified data I/O and getters, builds the `WenzRichTextEditor` via `buildEditor({...})`, and releases everything in dependency-reverse order via `dispose()`. | tier 1 (recommended entry) |

### Why facade + configuration, not a replacement typed API

The existing public surface (`WenzRichTextController`,
`WenzRichTextEditor`, the registries, the plugins) is **not** being replaced. It
stays exactly where it is for advanced use. The facade only does three things
the manual path forces every host to reinvent:

1. **Converge the default assembly** — a single `create()` call wires the
   controller, `BlockRendererRegistry` (+ `installDefaultRenderers`),
   `InlineEmbedRendererRegistry`, `SlashMenuRegistry`,
   `WenzToolbarItemRegistry`, and the optional derived controllers
   (`ToolbarController`, `SlashMenuController`,
   `WenzFindReplaceController`, `WenzOutlineController`,
   `WenzDocumentStatsController`, `WenzAutoSaveController`) in the same order
   the bundled `example` uses, and runs `installWenzRichTextPlugins` once.
2. **Unify the data contract** — read/export, write/import, version snapshots,
   and selection/focus all go through one set of facade delegates whose
   signatures match `WenzRichTextController` verbatim (no invented semantics).
3. **Own the lifecycle** — `dispose()` releases the derived controllers and
   registries in dependency-reverse order, with idempotent protection, so the
   `SlashMenuController` is unbound *before* the editor it listens to is torn
   down.

Configuration objects are deliberately narrow: they describe intent only. They
hold no `BuildContext`, no mutable resources, no controller references. This is
the discipline that keeps the facade from becoming a second, ambiguous typed API
(see [§9](#9-what-the-facade-does-not-do)).

---

## 2. Stability boundary — three tiers

Every public type lives behind the single entry point
`lib/wenz_richtext.dart`. The package is pre-`0.1.0`; the public surface is
still stabilising, and types fall into three tiers. **The lists below mirror the
library doc comment in `lib/wenz_richtext.dart`.**

### tier 1 — recommended entry (standard external interface)

The intended integration surface for the vast majority of hosts. Use these
first; reach lower only when the facade genuinely cannot express what you need.

- **Facade & configuration:** `WenzEditorConfiguration`, `WenzEditorBootstrap`.
- **Controller:** `WenzRichTextController` (and its incremental-rebuild signal
  `lastChangedBlockIds`), `HistoryManager`, the core commands
  (`InsertTextCommand`, `DeleteSelectionCommand`, `EnterCommand`,
  `FormatTextCommand`, `SetBlockTypeCommand`, …), the selection commands
  (`MoveCaretCommand`, `SelectAllCommand`, `MoveTableCellCommand`, …).
- **Editor widget:** `WenzRichTextEditor`.
- **Document model:** `RichTextDocument`, `BlockNode`, `InlineNode`,
  `TableModel`, `DocumentPosition`, `DocumentSelection`, `PositionPath`.
- **Codecs (data contract):** `RichTextJsonCodec`, the legacy JSON codec,
  `PlainTextCodec`, `MarkdownCodec`, `HtmlCodec`.
- **Permission policy:** `WenzEditorPermission` (`read` / `comment` / `edit`).
- **Controller change callbacks:** `WenzRichTextController.onChanged`,
  `.onSelectionChanged`, `.onCommandExecuted`.

### tier 2 — advanced extension points

Stabilising. These are the seams the facade wires internally; hosts use them
directly only when injecting behaviour the configuration object does not cover.
The facade is built *on top of* these, so a host that drops down to tier 2 still
gets fully stable behaviour — the facade never bypasses them.

- **Renderers:** `BlockRendererRegistry`, `BlockRendererBuilder`,
  `BlockRenderContext`, `WenzObjectBlockSurface`, `MediaResolver`,
  `InlineEmbedRenderer`, `InlineEmbedRendererRegistry`.
- **Plugin install surface:** `WenzRichTextPlugin`, `WenzPluginBundle`,
  `WenzPluginContext`, `WenzPluginApiStatus`, `installWenzRichTextPlugins`,
  `mergeWenzShortcutConfigurations`.
- **Shortcuts:** `EditorShortcutConfiguration`
  (`EditorShortcutBinding` / `EditorShortcutIntent`).
- **Toolbar / slash / find / outline / stats / autosave state:**
  `ToolbarController`, `WenzToolbarItemRegistry`, `SlashMenuController`,
  `SlashMenuRegistry`, `SlashMenuItem`, `WenzFindReplaceController`,
  `WenzOutlineController`, `WenzDocumentStatsController`,
  `WenzAutoSaveController`.
- **Exporters / importers:** `WenzDocumentExporter`, the conversion plan,
  application-owned `DocumentVersionSnapshot` +
  `DocumentVersionSnapshotJsonCodec`.
- **Accessibility:** `WenzRichTextEditorAccessibility`.
- **Pipeline:** `CommandRegistry`, `CommandDescriptor`, `CommandMiddleware`.

### internal — not part of the public surface

Everything under `src/*` that is **not** re-exported by `lib/wenz_richtext.dart`
is internal. It may change without notice. Hosts must never import `src/...`
paths directly; the single public entry is `package:wenz_richtext/wenz_richtext.dart`.

### tier 3 — experimental

The table command family (`InsertTableCommand`, …) and the stage-3 rich block
models (`VideoBlockNode`, `FileBlockNode`, `BlockEmbedNode`) are experimental;
their low-level contracts may still evolve. The facade exposes them through the
same data/extension seams, but the per-type contract is less frozen than tier 1/2.

---

## 3. Minimal access (zero configuration)

A usable, fully-wired editor in three calls. Every configuration field is
optional with a sane default, so `WenzEditorConfiguration()` is a legal,
runnable configuration.

```dart
final bootstrap = WenzEditorBootstrap.create(
  WenzEditorConfiguration(), // zero-config: empty document, edit permission, built-ins on
);

// controller.document is a valid empty document; permission == WenzEditorPermission.edit
print(bootstrap.controller.document.blocks.length); // 0+
print(bootstrap.controller.permission);             // WenzEditorPermission.edit

// buildEditor() returns a stock WenzRichTextEditor with the assembly injected:
final editor = bootstrap.buildEditor(autofocus: true);

// ...later, when the host widget is torn down:
bootstrap.dispose(); // idempotent; safe to call once
```

`buildEditor()` does not introduce a new widget type — it returns a plain
`WenzRichTextEditor` and injects `controller`, `blockRenderers`, `mediaResolver`,
`inlineEmbedRenderer`, `slashMenuController`, `findController` /
`onFindRequested` / `onReplaceRequested`, `outlineController`, `onMentionTap`,
`shortcutConfiguration`, and `accessibility`. Behaviour is identical to
constructing `WenzRichTextEditor` yourself; the facade only saves you the
assembly.

---

## 4. Data read / write

The facade delegates to the controller's existing contract. **No new
serialization format is introduced** — these are the same codecs the controller
already exposes, surfaced through the facade for a single I/O surface.

```dart
final b = WenzEditorBootstrap.create(WenzEditorConfiguration());

// ---- export / read (no mutation) ----
final json       = b.toJson();        // rich JSON (versioned)
final markdown   = b.toMarkdown();
final html       = b.toHtml();
final plainText  = b.toPlainText();

// ---- import / write (replaces the document, fires onChanged) ----
b.loadJson(json);
b.loadJson(legacyJson, legacy: true);           // legacy Wenz JSON shape
b.loadMarkdown('# Hello');
b.loadHtml('<h1>Hello</h1>');

// ---- no-throw variants for UI paths (paste / open-file) ----
// On failure they return TryLoadResult(ok: false, error: ...) and leave the
// current document, selection, history, and callbacks untouched.
final r = b.tryLoadJson(maybeBrokenJson);
if (!r.ok) { /* show r.error; editor state is unchanged */ }
final m = b.tryLoadMarkdown(maybeBrokenMarkdown);
final h = b.tryLoadHtml(maybeBrokenHtml);

// ---- application-owned version snapshots (deep-copied document) ----
final snap = b.createVersionSnapshot(
  author: 'ada',
  description: 'before review',
);
// ...user edits...
b.restoreVersionSnapshot(snap); // back to the saved document

// ---- selection / focus ----
b.setSelection(mySelection);
b.requestFocus();
```

| Facade method | Delegates to | Notes |
| --- | --- | --- |
| `toJson` / `toMarkdown` / `toHtml` / `toPlainText` | `controller.toJson/toMarkdown/toHtml/toPlainText` | pure export |
| `loadJson(source, {legacy, selection})` | `controller.loadJson` | `legacy: true` decodes the legacy shape |
| `tryLoadJson` / `tryLoadMarkdown` / `tryLoadHtml` | controller no-throw variants | return `TryLoadResult` |
| `loadMarkdown` / `loadHtml` | `controller.loadMarkdown/loadHtml` | throw on malformed input |
| `createVersionSnapshot` / `restoreVersionSnapshot` | `controller.createVersionSnapshot/restoreVersionSnapshot` | app-owned snapshots |
| `setSelection` / `requestFocus` | `controller.setSelection/requestFocus` | selection contract unchanged |

Codec note: quote is an attribute-level decoration in the canonical model. Hosts
can round-trip quoted headings, quoted ordered/todo list items, and ordinary
quoted paragraphs through rich JSON (`attrs.quoted`), Markdown (`>` prefixes),
and HTML (`<blockquote>` wrapping the original block tag). Legacy rich JSON with
`type: "quote"` is still accepted and normalizes to a quoted paragraph.

---

## 5. Extension injection

All host-side extensions are injected through `WenzEditorConfiguration`. The
facade feeds them into the same registries and the plugin context it already
assembles — so an injected custom renderer behaves identically to one a plugin
registers.

```dart
final config = WenzEditorConfiguration(
  // 1) Custom block embed renderer (e.g. a CRM card).
  blockEmbedRenderers: <String, BlockRendererBuilder>{
    'crm-card': (_, renderContext) => WenzObjectBlockSurface(
      renderContext: renderContext,
      child: CrmCardEmbed(block: renderContext.block as BlockEmbedNode),
    ),
  },

  // 2) Custom inline embed renderer (e.g. a @mention chip).
  inlineEmbedRenderers: <String, InlineEmbedSpanBuilder>{
    'mention': (embed, _) => mentionSpan(embed),
  },

  // 3) Slash-menu items / filters.
  slashMenuItems: <SlashMenuItem>[ mySlashItem ],

  // 4) Toolbar items.
  toolbarItems: <WenzToolbarItem>[ myToolbarItem ],

  // 5) Host-level shortcut overrides (applied last, so they win over plugins).
  shortcutConfiguration: EditorShortcutConfiguration(
    bindings: <EditorShortcutBinding>[ myBinding ],
  ),

  // 6) Paste transformers.
  pasteTransformers: <ClipboardPasteTransformer>[ myTransformer ],

  // 7) Media resolution (images/videos) — the editor still needs the handle too.
  mediaResolver: myMediaResolver,

  // 8) Whole plugins / bundles — commands, middleware, renderers, menu/toolbar
  //    items, shortcuts, paste transformers in one declarative package.
  plugins: <WenzRichTextPlugin>[
    WenzPluginBundle(id: 'acme.mentions', slashMenuItems: <SlashMenuItem>[...]),
  ],
);

final b = WenzEditorBootstrap.create(config);
```

During assembly the facade builds a `WenzPluginContext` from the controller +
the registries + the shortcut/paste-transformer lists, then calls
`installWenzRichTextPlugins(plugins: config.plugins, context: context)`. After
that, configuration-supplied renderers/items and plugin-contributed ones are
indistinguishable to the editor. Shortcut fragments contributed by plugins are
merged before the host's `shortcutConfiguration` (see
`mergeWenzShortcutConfigurations`), so host bindings always win.

See [§10](#10-configuration-field--extension-point-map) for the full
field → extension-point mapping.

---

## 6. Callbacks & permissions

### Callbacks

The three controller callbacks are exposed as configuration fields and wired
onto the controller during `create()`. They fire synchronously *before*
`notifyListeners`, so reading controller state inside them is safe.

```dart
final config = WenzEditorConfiguration(
  onChanged: (doc) => log('blocks=${doc.blocks.length}'),
  onSelectionChanged: (selection) => log('sel=$selection'),
  onCommandExecuted: (command, change) => log('cmd=${command.description}'),
  onMentionTap: (mention) => openProfile(mention),
);
```

### Permissions

`WenzEditorPermission` is an ordered policy: `read < comment < edit`. A command
declares the permission it requires, and the gate grants it only if the active
permission's index is `>=` the required one. The facade forwards
`configuration.permission` (default `edit`) to the controller, so the gate is
**never bypassed** — read/comment modes reject write commands at the command
layer, not just by hiding UI.

```dart
WenzEditorConfiguration(permission: WenzEditorPermission.comment)
// -> insertText / formatText / setBlockType / etc. are rejected by the gate
```

---

## 7. Three modes — read-only / comment / edit

There is one source of truth for mode: `WenzEditorConfiguration.permission`.
The facade does not keep a parallel "mode" knob.

| Mode | `permission` | Widget | Write commands | Typical use |
| --- | --- | --- | --- | --- |
| Edit | `edit` (default) | editable | allowed | authoring |
| Comment | `comment` | editable surface, no destructive writes | rejected by the gate | review/annotation |
| Read-only | `read` | `buildEditor(readOnly: true)` recommended | rejected by the gate | published/preview |

`permission` controls **command policy** (what mutations the model accepts);
`buildEditor(readOnly: true)` controls the **widget's input affordances**
(whether the surface accepts keyboard/IME/selection edits). For a true
read-only view, set both — `permission: read` so any programmatic command is
also rejected, and `readOnly: true` so the surface stops accepting input. They
compose; neither alone is sufficient to lock the surface fully.

```dart
// Read-only view: locked at both layers.
final ro = WenzEditorBootstrap.create(
  WenzEditorConfiguration(permission: WenzEditorPermission.read),
);
final view = ro.buildEditor(readOnly: true);
```

---

## 8. Lifecycle & dispose order

The full lifecycle is `create()` → `buildEditor()` (call repeatedly to rebuild)
→ `dispose()` (once).

`dispose()` releases resources in **dependency-reverse order**, mirroring the
bundled `example`'s manual dispose: the derived controllers and registries that
*listen to* the editor (`SlashMenuController`, `ToolbarController`,
`WenzDocumentStatsController`, `WenzAutoSaveController`, …) are released
**before** the `WenzRichTextController`, so their `removeListener` calls hit a
still-alive editor. `dispose()` is **idempotent** — calling it twice is safe and
does not double-free.

```dart
@override
void dispose() {
  bootstrap.dispose(); // reverse-order release; idempotent
  super.dispose();
}
```

> **Why the order matters.** `SlashMenuController` attaches listeners to the
> editor. If the controller were disposed first, the slash-menu controller's
> teardown would try to unbind from an already-destroyed editor and throw. The
> facade encodes the correct order once so hosts don't have to.

---

## 9. What the facade does not do

The facade is additive and conservative. Explicitly:

- **It does not replace the typed API.** Advanced hosts may continue to
  construct `WenzRichTextController` + `WenzRichTextEditor` + registries by hand
  and call `installWenzRichTextPlugins` themselves. The facade is the
  *recommended* path, not the *only* path.
- **It introduces no new runtime dependency.** PDF/DOCX/player/etc. still enter
  through the existing injection boundaries (`WenzDocumentExporter`,
  `MediaResolver`). Importing the facade adds nothing to the dependency tree.
- **It adds no facade-specific serialization format.** JSON/Markdown/HTML/plain-
  text codec shapes come from the controller codecs. The facade delegates; it
  does not re-encode or maintain a second import/export model.
- **Configuration describes intent only.** It creates no controller, no widget,
  holds no `BuildContext`, and produces no side effects. A
  `WenzEditorConfiguration` is safe to construct, `copyWith`, and pass around
  freely. This discipline keeps a single, unambiguous integration surface — if
  you find yourself wanting the facade to *do* something at construction time,
  that belongs on the controller or a derived controller, not on the config.
- **It changes no public type signature.** No existing tier 1/2 type is renamed
  or removed; the facade/config are purely additive exports.

---

## 10. Configuration field → extension-point map

This is the contract `WenzEditorConfiguration` (P002) implements and
`WenzEditorBootstrap` (P003/P004) consumes. Defaults make every field optional.

| Configuration field | Type | Consumed by | Maps to tier |
| --- | --- | --- | --- |
| `document` | `RichTextDocument?` | controller ctor | tier 1 |
| `selection` | `DocumentSelection?` | controller ctor | tier 1 |
| `permission` | `WenzEditorPermission` (default `edit`) | controller ctor + gate | tier 1 |
| `mediaResolver` | `MediaResolver?` | controller + `buildEditor` | tier 2 |
| `richTextJsonCodec` | `RichTextJsonCodec?` | controller ctor | tier 1 |
| `accessibility` | `WenzRichTextEditorAccessibility` | `buildEditor` | tier 2 |
| `plugins` | `List<WenzRichTextPlugin>` | `installWenzRichTextPlugins` | tier 2 |
| `shortcutConfiguration` | `EditorShortcutConfiguration` | merged last, wins | tier 2 |
| `pasteTransformers` | `List<ClipboardPasteTransformer>` | `ClipboardService` | tier 2 |
| `blockRenderers` | `Map<BlockType, BlockRendererBuilder>` | registry | tier 2 |
| `blockEmbedRenderers` | `Map<String, BlockRendererBuilder>` | registry | tier 2 |
| `inlineEmbedRenderers` | `Map<String, InlineEmbedSpanBuilder>` | registry | tier 2 |
| `slashMenuItems` | `List<SlashMenuItem>` | `SlashMenuRegistry` | tier 2 |
| `toolbarItems` | `List<WenzToolbarItem>` | `WenzToolbarItemRegistry` | tier 2 |
| `onMentionTap` | mention tap callback | `buildEditor` | tier 1 |
| `onChanged` | doc-changed callback | controller | tier 1 |
| `onSelectionChanged` | selection callback | controller | tier 1 |
| `onCommandExecuted` | command callback | controller | tier 1 |
| built-in derived-controller switches | `bool` (slash menu / find & replace / outline / autosave / stats / toolbar) | facade only creates the ones enabled | tier 2 |

`buildEditor({...})` pass-through appearance params (all optional, all forwarded
verbatim to `WenzRichTextEditor`): `padding`, `blockSpacing`, `textStyle`,
`defaultTextColor`, `physics`, `focusNode`, `autofocus`, `readOnly`,
`showDebugOverlay`, `enableIme`. The facade does not reinterpret any of them.

`WenzEditorBootstrap.create(configuration)` — constructor + assembly.
`buildEditor({...})` — widget factory, may be called multiple times.
`dispose()` — idempotent, dependency-reverse release.

---

## 11. End-to-end checklist

When integrating, confirm each of these against your host:

1. Single import: `import 'package:wenz_richtext/wenz_richtext.dart';` — no
   `src/` paths.
2. One `WenzEditorBootstrap.create(...)` owns the assembly; one
   `buildEditor(...)` returns the widget.
3. Data goes in/out through the facade I/O delegates ([§4](#4-data-read--write));
   no direct codec construction for default shapes.
4. Extensions are configuration fields ([§5](#5-extension-injection)), not
   ad-hoc registry mutation after creation.
5. Mode is `permission` (command gate) optionally combined with `readOnly`
   ([§7](#7-three-modes--read-only--comment--edit)); the gate is never bypassed.
6. `dispose()` is called exactly once in your widget's `dispose()`
   ([§8](#8-lifecycle--dispose-order)).
7. If the facade cannot express what you need, drop to tier 2
   ([§2](#2-stability-boundary--three-tiers)) — the typed API remains stable and
   is not deprecated.

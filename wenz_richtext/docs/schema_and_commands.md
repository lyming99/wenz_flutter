# Schema and commands

Stage 3 adds a schema boundary around the document model and expands the command
surface for inline, block, and plugin-driven editing.

## Document schema

`DocumentSchema.normalize` is the canonical repair step for documents entering or
leaving commands.

Rules:

- Empty documents become a single empty paragraph.
- Text block attributes are made consistent with their block type.
- List item `listType` values are canonicalised to `ordered`, `task`, or `null`
  for unordered bullets.
- Table cells always contain at least one paragraph block.
- Indent values are clamped to the configured schema range.

Normalizer entry points:

- `DocumentSession` normalizes the initial document and `replaceDocument` input.
- `CommandExecutor.execute` normalizes after every command result before creating
  the `ChangeSet`.
- JSON and legacy JSON loads go through controller/session replacement, so decoded
  documents are normalized before use.

## Inline commands

Use semantic commands instead of reaching into `FormatTextCommand` directly when
the intent is part of the rich text feature set.

- `SetLinkCommand(url)` applies or replaces a link URL on the current selection;
  `null` clears links.
- `ToggleMarkCommand(TextMark.remark)` toggles remark/comment anchor styling.
  The same command can also toggle boolean marks such as underline and
  line-through.
- `InsertInlineEmbedCommand` inserts an inline embed at the caret and moves the
  selection after the embed.
- `WenzRichTextController.insertFormula(text)` inserts a formula embed with
  `embedType: 'formula'`.
- `WenzRichTextController.insertMention(id, label)` inserts a mention embed with
  `embedType: 'mention'` and renders as `@label`.
- `WenzRichTextController.insertInlineImage(...)` inserts an inline image embed
  with `embedType: 'image'` and renders as `[img]` until a media renderer is
  provided.

## Block commands

Stage 3 block structure commands keep block-level editing behind command objects
so history, schema normalization, and middleware all run consistently.

- `IndentCommand(1)` and `IndentCommand(-1)` power controller `indent()` and
  `outdent()`.
- `ToggleTodoCommand` converts a block to a task list item when needed, then
  toggles checked state.
- `SetCodeLanguageCommand(language)` updates a code block language.
- `ToggleQuoteCommand` switches paragraph/quote state and uses indent for quote
  depth during this stage.
- `CalloutBlockNode` and `FileBlockNode` are serializable blocks that can be
  inserted through controller helpers.

## Command pipeline

`CommandExecutor` is the choke point for command execution:

1. Run each `CommandMiddleware.before` hook.
2. If a hook returns a `ChangeSet`, short-circuit the command.
3. Execute the command body.
4. Apply the command selection result.
5. Normalize the document with `DocumentSchema`.
6. Create a `ChangeSet`, including `CommandResult.metadata`.
7. Record history when requested.
8. Run each `CommandMiddleware.after` hook.

Middleware before-hooks are the extension point for validation, policy checks,
command blocking, or command rewriting. After-hooks are observers and should use
`ChangeSet.metadata` for dirty block ids, command kind, analytics, or renderer
invalidation hints.

## Command registry

Plugins can register named commands without changing `CommandExecutor` or adding
methods to `WenzRichTextController`:

```dart
controller.registry.register(
  CommandDescriptor(
    name: 'insertHello',
    factory: (args) => InsertTextCommand(args.readString('text') ?? 'hello'),
  ),
);

controller.executeCommand('insertHello', <String, Object?>{
  'text': 'world',
});
```

Use `CommandArgsRead` helpers to read typed JSON-like arguments safely. Unknown
command names throw `ArgumentError` so callers can fall back to typed controller
APIs.

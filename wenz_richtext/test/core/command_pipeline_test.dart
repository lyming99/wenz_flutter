import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  group('command middleware', () {
    test('after hook observes committed changes', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);
      final seen = <ChangeSet>[];
      executor.middlewares.add(
        _RecordingMiddleware(onAfter: seen.add),
      );

      executor.execute(const InsertTextCommand('hi'));

      expect(seen, hasLength(1));
      expect(seen.single.after.plainText, 'hi');
    });

    test('before hook can short-circuit a command', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'orig')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);
      // Block all commands by returning an override change.
      executor.middlewares.add(
        _BlockingMiddleware(
          overrideChange: ChangeSet(
            before: session.document.copy(),
            after: session.document.copy(),
            selectionBefore: session.selection,
            selectionAfter: session.selection,
            description: 'blocked',
          ),
        ),
      );

      executor.execute(const InsertTextCommand('hi'));

      // The command never ran; the document is unchanged.
      expect(session.document.plainText, 'orig');
    });

    test('CommandResult.metadata is carried through to after hooks', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);
      final seen = <ChangeSet>[];
      executor.middlewares.add(_RecordingMiddleware(onAfter: seen.add));

      final change = executor.execute(const _MetadataCommand());

      expect(change.metadata, <String, Object?>{'kind': 'metadata'});
      expect(seen.single.metadata, <String, Object?>{'kind': 'metadata'});
    });

    test('before hook can validate and block invalid commands', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'safe')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 4),
      );
      final executor = CommandExecutor(session);
      final seen = <ChangeSet>[];
      executor.middlewares
        ..add(_ValidationMiddleware())
        ..add(_RecordingMiddleware(onAfter: seen.add));

      final change = executor.execute(const _InvalidCommand());

      expect(session.document.plainText, 'safe');
      expect(change.description, 'validation:blocked');
      expect(change.metadata, <String, Object?>{
        'blocked': true,
        'reason': 'invalidCommand',
      });
      expect(seen.single.metadata?['blocked'], isTrue);
    });
  });

  group('command registry', () {
    test('registered command runs through the executor', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      controller.registry.register(
        CommandDescriptor(
          name: 'insertHello',
          factory: (args) =>
              InsertTextCommand(args.readString('text') ?? 'hello'),
        ),
      );

      controller.executeCommand('insertHello', <String, Object?>{
        'text': 'world',
      });

      expect(controller.document.plainText, 'world');
    });

    test('unknown name throws', () {
      final controller = WenzRichTextController();
      expect(
        () => controller.executeCommand('nope', <String, Object?>{}),
        throwsA(isA<UnknownCommandException>()),
      );
    });
  });

  group('controller permissions', () {
    test('read permission blocks edit commands but keeps read commands', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Hi')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 2),
        permission: WenzEditorPermission.read,
      );
      var notifyCount = 0;
      var commandCount = 0;
      controller
        ..addListener(() => notifyCount++)
        ..onCommandExecuted = (_, __) => commandCount++;

      final blocked = controller.insertText('!');

      expect(controller.document.plainText, 'Hi');
      expect(blocked.isNoop, isTrue);
      expect(blocked.description, 'permission:blocked:insertText');
      expect(blocked.metadata?['permission'], 'read');
      expect(blocked.metadata?['requiredPermission'], 'edit');
      expect(controller.canExecute(const InsertTextCommand('!')), isFalse);
      expect(notifyCount, 0);
      expect(commandCount, 0);

      controller.selectAll();

      expect(controller.selection?.isCollapsed, isFalse);
      expect(notifyCount, 1);
      expect(commandCount, 1);
    });

    test('comment permission allows comment commands only', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Hi')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 2),
        permission: WenzEditorPermission.comment,
      );
      var commentRuns = 0;
      controller.registry
        ..register(
          CommandDescriptor(
            name: 'insertBang',
            factory: (_) => const InsertTextCommand('!'),
          ),
        )
        ..register(
          CommandDescriptor(
            name: 'commentOnly',
            factory: (_) => _CommentOnlyCommand(() => commentRuns++),
          ),
        );

      expect(controller.canComment, isTrue);
      expect(controller.canEdit, isFalse);
      expect(controller.canExecuteCommand('insertBang', <String, Object?>{}),
          isFalse);
      expect(controller.tryExecuteCommand('insertBang', <String, Object?>{}),
          isFalse);
      expect(controller.document.plainText, 'Hi');

      expect(controller.canExecuteCommand('commentOnly', <String, Object?>{}),
          isTrue);
      expect(controller.tryExecuteCommand('commentOnly', <String, Object?>{}),
          isTrue);
      expect(commentRuns, 1);
    });

    test('undo and redo require edit permission', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Hi')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 2),
      );
      controller.insertText('!');
      controller.permission = WenzEditorPermission.read;

      expect(controller.canUndo, isFalse);
      expect(controller.undo(), isFalse);
      expect(controller.document.plainText, 'Hi!');

      controller.permission = WenzEditorPermission.edit;
      expect(controller.canUndo, isTrue);
      expect(controller.undo(), isTrue);
      expect(controller.canRedo, isTrue);

      controller.permission = WenzEditorPermission.comment;
      expect(controller.redo(), isFalse);
      expect(controller.document.plainText, 'Hi');
    });
  });
}

class _RecordingMiddleware extends CommandMiddleware {
  _RecordingMiddleware({this.onAfter});
  final void Function(ChangeSet change)? onAfter;
  @override
  void after(ChangeSet change, DocumentSession session) =>
      onAfter?.call(change);
}

class _BlockingMiddleware extends CommandMiddleware {
  _BlockingMiddleware({required this.overrideChange});
  final ChangeSet overrideChange;
  @override
  ChangeSet? before(EditorCommand command, DocumentSession session) =>
      overrideChange;
}

class _ValidationMiddleware extends CommandMiddleware {
  @override
  ChangeSet? before(EditorCommand command, DocumentSession session) {
    if (command is! _InvalidCommand) {
      return null;
    }
    return ChangeSet(
      before: session.document.copy(),
      after: session.document.copy(),
      selectionBefore: session.selection,
      selectionAfter: session.selection,
      description: 'validation:blocked',
      metadata: const <String, Object?>{
        'blocked': true,
        'reason': 'invalidCommand',
      },
    );
  }
}

class _MetadataCommand extends EditorCommand {
  const _MetadataCommand();

  @override
  String get description => 'metadata';

  @override
  CommandResult execute(DocumentSession session) {
    return const CommandResult(
      metadata: <String, Object?>{'kind': 'metadata'},
    );
  }
}

class _InvalidCommand extends EditorCommand {
  const _InvalidCommand();

  @override
  String get description => 'invalid';

  @override
  CommandResult execute(DocumentSession session) {
    throw StateError('validation should block this command');
  }
}

class _CommentOnlyCommand extends EditorCommand {
  _CommentOnlyCommand(this.onExecute);

  final void Function() onExecute;

  @override
  String get description => 'commentOnly';

  @override
  WenzEditorPermission get requiredPermission => WenzEditorPermission.comment;

  @override
  CommandResult execute(DocumentSession session) {
    onExecute();
    return const CommandResult(recordHistory: false);
  }
}

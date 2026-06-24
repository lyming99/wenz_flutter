import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('revision range and inline attribute markers round trip', () {
    final selection = textSelection('p1', 0, 1, 4);
    final range = RevisionRange.fromSelection(selection);
    final decodedRange = RevisionRange.fromJson(range.toJson());

    const attributes = TextAttributes(
      bold: true,
      revisionIds: <String>['rev-1'],
    );
    final decodedAttributes = TextAttributes.fromJson(attributes.toJson());

    expect(decodedRange, range);
    expect(decodedRange.selection, selection);
    expect(decodedAttributes.revisionIds, <String>['rev-1']);
    expect(decodedAttributes, attributes);
  });

  test('rich JSON saves and restores revision changes with document', () {
    final revision = _revision(RevisionChangeType.insert);
    final document = RichTextDocument(
      blocks: const <BlockNode>[
        TextBlockNode(
          id: 'p1',
          type: BlockType.paragraph,
          content: <InlineNode>[
            TextRun(
              text: 'tracked',
              attributes: TextAttributes(revisionIds: <String>['rev-1']),
            ),
          ],
        ),
      ],
      revisions: <RevisionChange>[revision],
    );

    const codec = RichTextJsonCodec();
    final decoded = codec.decode(codec.encode(document));
    final decodedRun = (decoded.blocks.single as TextBlockNode).content.single;

    expect(decoded.revisions, <RevisionChange>[revision]);
    expect((decodedRun as TextRun).attributes.revisionIds, <String>['rev-1']);
  });

  test('accepting inserted revision keeps text and clears inline marker', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      InsertRevisionTextCommand(
        '!',
        revisionId: 'rev-insert',
        authorId: 'u1',
        authorName: 'Alice',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    executor.execute(
      AcceptRevisionCommand(
        'rev-insert',
        resolvedAt: DateTime.utc(2026, 1, 2),
      ),
    );

    final run =
        (session.document.blocks.single as TextBlockNode).content.single;
    expect(session.document.plainText, 'Hello!');
    expect((run as TextRun).attributes.revisionIds, isEmpty);
    expect(session.document.revisions.single.isAccepted, isTrue);
  });

  test('deletion revision can be accepted or rejected', () {
    final acceptSession = _sessionWithText('Hello world');
    final acceptExecutor = CommandExecutor(acceptSession);
    acceptExecutor.execute(
      MarkDeletionRevisionCommand(
        revisionId: 'rev-delete',
        selection: textSelection('p1', 0, 5, 11),
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    acceptExecutor.execute(const AcceptRevisionCommand('rev-delete'));

    expect(acceptSession.document.plainText, 'Hello');
    expect(acceptSession.document.revisions.single.isAccepted, isTrue);

    final rejectSession = _sessionWithText('Hello world');
    final rejectExecutor = CommandExecutor(rejectSession);
    rejectExecutor.execute(
      MarkDeletionRevisionCommand(
        revisionId: 'rev-delete',
        selection: textSelection('p1', 0, 5, 11),
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    rejectExecutor.execute(const RejectRevisionCommand('rev-delete'));
    final run = (rejectSession.document.blocks.single as TextBlockNode)
        .content
        .single as TextRun;

    expect(rejectSession.document.plainText, 'Hello world');
    expect(run.attributes.revisionIds, isEmpty);
    expect(rejectSession.document.revisions.single.isRejected, isTrue);
  });

  test('format revision rejection restores previous inline attributes', () {
    final session = _sessionWithText('Hello');
    final executor = CommandExecutor(session);

    executor.execute(
      MarkFormatRevisionCommand(
        revisionId: 'rev-format',
        attributes: const TextAttributes(bold: true),
        selection: textSelection('p1', 0, 0, 5),
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    executor.execute(const RejectRevisionCommand('rev-format'));

    final run =
        (session.document.blocks.single as TextBlockNode).content.single;
    expect((run as TextRun).attributes, const TextAttributes());
    expect(session.document.revisions.single.isRejected, isTrue);
  });

  test('controller revision mode routes typed insert through revision command',
      () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
    );

    controller.setRevisionMode(true, authorId: 'u1', authorName: 'Alice');
    controller.insertText('!');

    final revision = controller.document.revisions.single;
    final insertedRun = (controller.document.blocks.single as TextBlockNode)
        .content
        .last as TextRun;

    expect(controller.revisionModeEnabled, isTrue);
    expect(revision.type, RevisionChangeType.insert);
    expect(revision.authorId, 'u1');
    expect(insertedRun.attributes.revisionIds, <String>[revision.id]);
  });
}

DocumentSession _sessionWithText(String text) {
  return DocumentSession(
    document: RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'p1',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: text)],
        ),
      ],
    ),
  );
}

RevisionChange _revision(RevisionChangeType type) {
  return RevisionChange(
    id: 'rev-1',
    type: type,
    range: const RevisionRange(
      blockId: 'p1',
      blockIndex: 0,
      path: PositionPath(<Object>['block', 'p1', 'text']),
      startOffset: 0,
      endOffset: 7,
    ),
    createdAt: DateTime.utc(2026, 1, 1, 9),
    authorId: 'u1',
    authorName: 'Alice',
  );
}

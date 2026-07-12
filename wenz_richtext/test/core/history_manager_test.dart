import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  test('undo and redo restore document and selection', () {
    final startPosition = DocumentPosition(
      blockId: 'p1',
      blockIndex: 0,
      path: PositionPath.blockText('p1'),
      offset: 5,
    );
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
      selection: DocumentSelection(base: startPosition, extent: startPosition),
    );
    final executor = CommandExecutor(session);

    executor.execute(const InsertTextCommand('!'));
    expect(session.document.plainText, 'Hello!');
    expect(session.history.undoDepth, 1);

    expect(session.undo(), isTrue);
    expect(session.document.plainText, 'Hello');
    expect(session.selection?.extent.offset, 5);
    expect(session.canRedo, isTrue);

    expect(session.redo(), isTrue);
    expect(session.document.plainText, 'Hello!');
    expect(session.selection?.extent.offset, 6);
  });

  test('no-op commands are not pushed to history', () {
    final session = DocumentSession(document: const RichTextDocument());
    final executor = CommandExecutor(session);

    executor.execute(const InsertTextCommand('ignored'));

    expect(session.history.undoDepth, 0);
  });

  test('history enforces entry and estimated-byte budgets', () {
    final history = HistoryManager(limit: 10, maxEstimatedBytes: 1000);
    const document = RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(id: 'p1', type: BlockType.paragraph),
      ],
    );

    for (var index = 0; index < 4; index++) {
      history.push(
        ChangeSet(
          before: document,
          after: document,
          description: 'change-$index',
          changeSummary: const DocumentChangeSummary(
            documentChanged: true,
            changedBlockIds: <String>{'p1'},
            estimatedChangedBytes: 400,
          ),
        ),
      );
    }

    expect(history.undoDepth, 1);
    expect(history.estimatedRetainedBytes, lessThanOrEqualTo(1000));
    expect(history.undo(), isNotNull);
    expect(history.redo(), isNotNull);
    expect(history.estimatedRetainedBytes, lessThanOrEqualTo(1000));
  });
}

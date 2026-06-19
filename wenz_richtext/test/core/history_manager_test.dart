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
}

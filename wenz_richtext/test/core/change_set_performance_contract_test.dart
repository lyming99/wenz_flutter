import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('single-block typing shares every unchanged block snapshot', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'first')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'second')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
    );
    final unchanged = session.document.blocks[1];

    final change = CommandExecutor(session).execute(
      const InsertTextCommand('!'),
    );

    expect(change.isNoop, isFalse);
    expect(change.changedBlockIds, <String>{'p1'});
    expect(change.removedBlockIds, isEmpty);
    expect(change.structureChanged, isFalse);
    expect(identical(change.before.blocks[1], unchanged), isTrue);
    expect(identical(change.after.blocks[1], unchanged), isTrue);
    expect(
      () => session.document.blocks[1] = const TextBlockNode(
        id: 'illegal',
        type: BlockType.paragraph,
      ),
      throwsUnsupportedError,
    );
  });

  test('structural summary does not dirty unchanged shifted blocks', () {
    const first = TextBlockNode(
      id: 'first',
      type: BlockType.paragraph,
      content: <InlineNode>[TextRun(text: 'first')],
    );
    const second = TextBlockNode(
      id: 'second',
      type: BlockType.paragraph,
      content: <InlineNode>[TextRun(text: 'second')],
    );
    const inserted = TextBlockNode(
      id: 'inserted',
      type: BlockType.paragraph,
      content: <InlineNode>[TextRun(text: 'inserted')],
    );
    const before = RichTextDocument(blocks: <BlockNode>[first, second]);
    const after = RichTextDocument(
      blocks: <BlockNode>[inserted, first, second],
    );

    final summary = DocumentChangeSummary.between(
      before,
      after,
      documentChanged: true,
    );

    expect(summary.structureChanged, isTrue);
    expect(summary.changedBlockIds, <String>{'inserted'});
    expect(summary.removedBlockIds, isEmpty);
    expect(summary.changedStartIndex, 0);
  });

  test('manual ChangeSet keeps content-compatible no-op semantics', () {
    const before = RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'p1',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'same')],
        ),
      ],
    );

    final change = ChangeSet(before: before, after: before.copy());

    expect(change.isNoop, isTrue);
    expect(change.changedBlockIds, isEmpty);
  });
}

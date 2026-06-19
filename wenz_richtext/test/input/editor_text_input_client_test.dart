import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  group('EditorTextInputClient', () {
    late WenzRichTextController controller;
    late EditorTextInputClient client;

    setUp(() {
      controller = WenzRichTextController(
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
      client = EditorTextInputClient(controller);
      client.syncBufferForTest();
    });

    test('insertion delta inserts text at the caret', () {
      client.injectDelta(
        const TextEditingDeltaInsertion(
          insertionOffset: 0,
          textInserted: 'Hi',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange.empty,
          oldText: '',
        ),
      );

      expect(controller.document.plainText, 'Hi');
      expect(controller.selection?.extent.offset, 2);
      expect(controller.compositionState, isNull);
    });

    test('composition delta sets the composition region for rendering', () {
      // Simulate a Chinese IME: user types "ni", the IME shows a composing
      // region covering "ni" before the user picks a candidate.
      client.injectDelta(
        const TextEditingDeltaInsertion(
          insertionOffset: 0,
          textInserted: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
          oldText: '',
        ),
      );

      expect(controller.document.plainText, 'ni');
      expect(controller.compositionState, isNotNull);
      expect(controller.compositionState!.startOffset, 0);
      expect(controller.compositionState!.endOffset, 2);
      expect(controller.compositionState!.blockId, 'p1');
    });

    test('committing the composition clears the composition state', () {
      // Compose "ni" then replace it with the committed candidate "你".
      client.injectDelta(
        const TextEditingDeltaInsertion(
          insertionOffset: 0,
          textInserted: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
          oldText: '',
        ),
      );
      client.injectDelta(
        const TextEditingDeltaReplacement(
          oldText: 'ni',
          replacementText: '你',
          replacedRange: TextRange(start: 0, end: 2),
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
      );

      expect(controller.document.plainText, '你');
      expect(controller.compositionState, isNull);
    });

    test('deletion delta removes the range', () {
      controller.insertText('Hello');
      controller.setSelection(collapsedTextSelection('p1', 0, 5));
      client.syncBufferForTest();

      client.injectDelta(
        const TextEditingDeltaDeletion(
          oldText: 'Hello',
          deletedRange: TextRange(start: 1, end: 4),
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
      );

      expect(controller.document.plainText, 'Ho');
      expect(controller.selection?.extent.offset, 1);
    });

    test('consecutive IME insertions coalesce into one undo step', () {
      client.injectDelta(
        const TextEditingDeltaInsertion(
          insertionOffset: 0,
          textInserted: 'a',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
          oldText: '',
        ),
      );
      client.injectDelta(
        const TextEditingDeltaInsertion(
          insertionOffset: 1,
          textInserted: 'b',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange.empty,
          oldText: 'a',
        ),
      );

      expect(controller.document.plainText, 'ab');
      expect(controller.canUndo, isTrue);
      controller.undo();
      // One coalesced undo step reverts the whole run.
      expect(controller.document.plainText, '');
      expect(controller.canUndo, isFalse);
    });

    test('syncBuffer reflects table cell text and caret', () {
      controller = WenzRichTextController(
        document: _tableCellDocument('Hello'),
        selection: _collapsedTableCellSelection(2),
      );
      client = EditorTextInputClient(controller);
      client.syncBufferForTest();

      expect(client.currentBuffer.text, 'Hello');
      expect(client.currentBuffer.selection.baseOffset, 2);
    });

    test('deltas edit table cell text', () {
      controller = WenzRichTextController(
        document: _tableCellDocument('Hello'),
        selection: _collapsedTableCellSelection(5),
      );
      client = EditorTextInputClient(controller);
      client.syncBufferForTest();

      client.injectDelta(
        const TextEditingDeltaInsertion(
          insertionOffset: 5,
          textInserted: '!',
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange.empty,
          oldText: 'Hello',
        ),
      );
      client.injectDelta(
        const TextEditingDeltaDeletion(
          oldText: 'Hello!',
          deletedRange: TextRange(start: 1, end: 4),
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
      );

      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.cellAt(0, 0)!.plainText, 'Ho!');
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
      expect(controller.selection?.extent.offset, 1);
    });
  });
}

RichTextDocument _tableCellDocument(String text) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table1',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'cell1',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-p1',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: text)],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

DocumentSelection _collapsedTableCellSelection(int offset) {
  final position = DocumentPosition.tableCell(
    tableBlockId: 'table1',
    blockIndex: 0,
    tableRowIndex: 0,
    tableColumnIndex: 0,
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}

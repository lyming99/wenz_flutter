import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  // TextInput.attach needs a binary messenger; ensure the binding is up.
  TestWidgetsFlutterBinding.ensureInitialized();
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

    test('pinyin composition updates in the middle of a block stay aligned',
        () {
      controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcXYZ')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 3),
      );
      client = EditorTextInputClient(controller);
      client.syncBufferForTest();

      client.injectDelta(
        const TextEditingDeltaInsertion(
          oldText: 'abcXYZ',
          insertionOffset: 3,
          textInserted: 'n',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 3, end: 4),
        ),
      );
      client.injectDelta(
        const TextEditingDeltaReplacement(
          oldText: 'abcnXYZ',
          replacementText: 'ni',
          replacedRange: TextRange(start: 3, end: 4),
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 3, end: 5),
        ),
      );
      client.injectDelta(
        const TextEditingDeltaReplacement(
          oldText: 'abcniXYZ',
          replacementText: '你',
          replacedRange: TextRange(start: 3, end: 5),
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange.empty,
        ),
      );

      expect(controller.document.plainText, 'abc你XYZ');
      expect(controller.selection?.extent.offset, 4);
      expect(controller.compositionState, isNull);
    });

    test('insertion delta uses the current caret when platform offset is stale',
        () {
      controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcdef')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 3),
      );
      client = EditorTextInputClient(controller);
      client.syncBufferForTest();

      client.injectDelta(
        const TextEditingDeltaInsertion(
          oldText: 'abcdef',
          insertionOffset: 0,
          textInserted: 'X',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
      );

      expect(controller.document.plainText, 'abcXdef');
      expect(controller.selection?.extent.offset, 4);
      expect(client.currentBuffer.text, 'abcXdef');
      expect(client.currentBuffer.selection.baseOffset, 4);
    });

    test('stale pinyin replacement removes composing text at the caret', () {
      controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcXYZ')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 3),
      );
      client = EditorTextInputClient(controller);
      client.syncBufferForTest();

      client.injectDelta(
        const TextEditingDeltaInsertion(
          oldText: 'abcXYZ',
          insertionOffset: 0,
          textInserted: 'n',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      );
      client.injectDelta(
        const TextEditingDeltaReplacement(
          oldText: 'n',
          replacementText: 'ni',
          replacedRange: TextRange(start: 0, end: 1),
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      client.injectDelta(
        const TextEditingDeltaReplacement(
          oldText: 'ni',
          replacementText: '\u4F60',
          replacedRange: TextRange(start: 0, end: 2),
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
      );

      expect(controller.document.plainText, 'abc\u4F60XYZ');
      expect(controller.selection?.extent.offset, 4);
      expect(controller.compositionState, isNull);
      expect(client.currentBuffer.text, 'abc\u4F60XYZ');
    });

    test('non-delta IME updates replace pinyin at the current caret', () {
      controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcXYZ')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 3),
      );
      client = EditorTextInputClient(controller);
      client.syncBufferForTest();

      client.updateEditingValue(
        const TextEditingValue(
          text: 'abcjiuXYZ',
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange(start: 3, end: 6),
        ),
      );

      expect(controller.document.plainText, 'abcjiuXYZ');
      expect(controller.selection?.extent.offset, 6);
      expect(controller.compositionState, isNotNull);
      expect(controller.compositionState!.startOffset, 3);
      expect(controller.compositionState!.endOffset, 6);

      client.updateEditingValue(
        const TextEditingValue(
          text: 'abc\u540EXYZ',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange.empty,
        ),
      );

      expect(controller.document.plainText, 'abc\u540EXYZ');
      expect(controller.selection?.extent.offset, 4);
      expect(controller.compositionState, isNull);
      expect(client.currentBuffer.text, 'abc\u540EXYZ');
      expect(client.currentBuffer.selection.baseOffset, 4);
    });

    test('non-text composition update follows platform selection', () {
      client.injectDelta(
        const TextEditingDeltaInsertion(
          oldText: '',
          insertionOffset: 0,
          textInserted: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );

      client.injectDelta(
        const TextEditingDeltaNonTextUpdate(
          oldText: 'ni',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 2),
        ),
      );

      expect(controller.document.plainText, 'ni');
      expect(controller.selection?.extent.offset, 1);
      expect(controller.compositionState, isNotNull);
      expect(controller.compositionState!.startOffset, 0);
      expect(controller.compositionState!.endOffset, 2);
    });

    test('syncBuffer preserves active composition range', () {
      controller.insertText('ni');
      controller.setSelection(collapsedTextSelection('p1', 0, 2));
      controller.setCompositionState(
        CompositionState(
          blockId: 'p1',
          blockIndex: 0,
          path: PositionPath.blockText('p1'),
          startOffset: 0,
          endOffset: 2,
        ),
      );

      client.syncBufferForTest();

      expect(client.currentBuffer.text, 'ni');
      expect(client.currentBuffer.selection.baseOffset, 2);
      expect(client.currentBuffer.composing, const TextRange(start: 0, end: 2));
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

    test('syncBuffer reflects same-target expanded selection', () {
      controller.insertText('Hello');
      controller.setSelection(textSelection('p1', 0, 1, 4));

      client.syncBufferForTest();

      expect(client.currentBuffer.text, 'Hello');
      expect(client.currentBuffer.selection.baseOffset, 1);
      expect(client.currentBuffer.selection.extentOffset, 4);
    });

    test('syncBuffer clears cross-target expanded selection', () {
      controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'one')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'two')],
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 1,
          ),
          extent: DocumentPosition.text(
            blockId: 'p2',
            blockIndex: 1,
            offset: 1,
          ),
        ),
      );
      client = EditorTextInputClient(controller);

      client.syncBufferForTest();

      expect(client.currentBuffer, TextEditingValue.empty);
    });

    test('insertion delta replaces cross-block selection at the start', () {
      controller = _crossBlockController();
      client = EditorTextInputClient(controller);
      client.syncBufferForTest();

      client.injectDelta(
        const TextEditingDeltaInsertion(
          oldText: '',
          insertionOffset: 0,
          textInserted: 'n',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      );

      expect(controller.document.plainText, 'abnXYZ');
      expect(controller.selection?.isCollapsed, isTrue);
      expect(controller.selection?.extent.blockId, 'p1');
      expect(controller.selection?.extent.offset, 3);
      expect(controller.compositionState, isNotNull);
      expect(controller.compositionState!.startOffset, 2);
      expect(controller.compositionState!.endOffset, 3);

      controller.undo();

      expect(controller.document.plainText, 'abcdef\n123XYZ');
      expect(controller.selection?.isCollapsed, isFalse);
      expect(controller.selection?.start.offset, 2);
      expect(controller.selection?.end.offset, 3);
    });

    test('replacement delta maps pinyin across a cross-block selection', () {
      controller = _crossBlockController();
      client = EditorTextInputClient(controller);
      client.syncBufferForTest();

      client.injectDelta(
        const TextEditingDeltaReplacement(
          oldText: '',
          replacementText: 'ni',
          replacedRange: TextRange(start: 0, end: 0),
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );

      expect(controller.document.plainText, 'abniXYZ');
      expect(controller.selection?.isCollapsed, isTrue);
      expect(controller.selection?.extent.blockId, 'p1');
      expect(controller.selection?.extent.offset, 4);
      expect(controller.compositionState, isNotNull);
      expect(controller.compositionState!.startOffset, 2);
      expect(controller.compositionState!.endOffset, 4);
    });

    test('non-delta pinyin replaces cross-block selection before composing',
        () {
      controller = _crossBlockController();
      client = EditorTextInputClient(controller);
      client.syncBufferForTest();

      client.updateEditingValue(
        const TextEditingValue(
          text: 'n',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      );

      expect(controller.document.plainText, 'abnXYZ');
      expect(controller.selection?.extent.blockId, 'p1');
      expect(controller.selection?.extent.offset, 3);
      expect(controller.compositionState, isNotNull);
      expect(controller.compositionState!.startOffset, 2);
      expect(controller.compositionState!.endOffset, 3);

      client.updateEditingValue(
        const TextEditingValue(
          text: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );

      expect(controller.document.plainText, 'abniXYZ');
      expect(controller.selection?.extent.offset, 4);
      expect(controller.compositionState, isNotNull);
      expect(controller.compositionState!.startOffset, 2);
      expect(controller.compositionState!.endOffset, 4);

      client.updateEditingValue(
        const TextEditingValue(
          text: '\u4F60',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
      );

      expect(controller.document.plainText, 'ab\u4F60XYZ');
      expect(controller.selection?.extent.offset, 3);
      expect(controller.compositionState, isNull);
    });

    test('deletion delta removes active selection even with empty range', () {
      controller.insertText('Hello');
      controller.setSelection(textSelection('p1', 0, 1, 4));
      client.syncBufferForTest();

      client.injectDelta(
        const TextEditingDeltaDeletion(
          oldText: 'Hello',
          deletedRange: TextRange.empty,
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
      );

      expect(controller.document.plainText, 'Ho');
      expect(controller.selection?.isCollapsed, isTrue);
      expect(controller.selection?.extent.offset, 1);
      expect(client.currentBuffer.text, 'Ho');
      expect(client.currentBuffer.selection.baseOffset, 1);
    });

    test('insertion delta replaces active selection', () {
      controller.insertText('Hello');
      controller.setSelection(textSelection('p1', 0, 1, 4));
      client.syncBufferForTest();

      client.injectDelta(
        const TextEditingDeltaInsertion(
          insertionOffset: 1,
          textInserted: 'i',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange.empty,
          oldText: 'Hello',
        ),
      );

      expect(controller.document.plainText, 'Hio');
      expect(controller.selection?.isCollapsed, isTrue);
      expect(controller.selection?.extent.offset, 2);
      expect(client.currentBuffer.text, 'Hio');
    });

    test('replacement delta replaces active selection', () {
      controller.insertText('Hello');
      controller.setSelection(textSelection('p1', 0, 1, 4));
      client.syncBufferForTest();

      client.injectDelta(
        const TextEditingDeltaReplacement(
          oldText: 'Hello',
          replacementText: 'ey',
          replacedRange: TextRange(start: 1, end: 4),
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange.empty,
        ),
      );

      expect(controller.document.plainText, 'Heyo');
      expect(controller.selection?.isCollapsed, isTrue);
      expect(controller.selection?.extent.offset, 3);
      expect(client.currentBuffer.text, 'Heyo');
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

    test('attach reports the caret rect so the IME window can follow it', () {
      // The platform IME candidate window (e.g. pinyin) must be told where the
      // caret is. attach() should push the caret rect provided by the widget
      // layer; syncBuffer() should refresh it when the caret moves.
      var reportedRect = const Rect.fromLTWH(10, 20, 1, 24);
      client.caretRectProvider = () => reportedRect;

      client.attach();

      expect(client.isAttached, isTrue);
      expect(client.lastReportedCaretRect, reportedRect);
      expect(client.lastReportedEditableSize, reportedRect.size);
      expect(
          client.lastReportedLocalCaretRect, Offset.zero & reportedRect.size);
      expect(client.lastReportedComposingRect, Offset.zero & reportedRect.size);

      // Move the caret (simulate): the provider now returns a different rect.
      reportedRect = const Rect.fromLTWH(50, 200, 1, 24);
      client.syncBuffer();

      expect(
        client.lastReportedCaretRect,
        reportedRect,
        reason: 'syncBuffer must re-push the caret rect so the IME window '
            'follows caret movement',
      );
      expect(client.lastReportedEditableSize, reportedRect.size);
      expect(
          client.lastReportedLocalCaretRect, Offset.zero & reportedRect.size);
      expect(client.lastReportedComposingRect, Offset.zero & reportedRect.size);
    });

    test('attach does not report when no caret rect is available', () {
      // No provider wired up: attach must not throw and must not report.
      client.attach();
      expect(client.lastReportedCaretRect, isNull);
    });

    test('attach reports TextField-style editable geometry', () {
      const globalCaret = Rect.fromLTWH(210, 320, 1.5, 24);
      const localCaret = Rect.fromLTWH(40, 8, 1.5, 24);
      const composing = Rect.fromLTWH(18, 8, 42, 24);
      client.textInputGeometryProvider = () => EditorTextInputGeometry(
            editableSize: const Size(320, 48),
            transform: Matrix4.translationValues(170, 312, 0),
            caretRect: localCaret,
            composingRect: composing,
            globalCaretRect: globalCaret,
          );

      client.attach();

      expect(client.lastReportedEditableSize, const Size(320, 48));
      expect(client.lastReportedLocalCaretRect, localCaret);
      expect(client.lastReportedComposingRect, composing);
      expect(client.lastReportedCaretRect, globalCaret);
    });

    test('attach pushes the viewId into the text input configuration', () {
      // The platform text-input engine rejects setClient when the viewId is
      // missing ("view ID is null"). Verify the client reads the injected
      // provider and surfaces it.
      client.viewIdProvider = () => 42;

      client.attach();

      expect(client.isAttached, isTrue);
      expect(client.lastConfigurationViewId, 42);
    });

    test('performSelector forwards platform selectors to the widget layer', () {
      final seen = <String>[];
      client.performSelectorHandler = seen.add;

      client.performSelector('moveLeft:');
      client.performSelector('deleteWordBackward:');

      expect(seen, <String>['moveLeft:', 'deleteWordBackward:']);
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

WenzRichTextController _crossBlockController() {
  return WenzRichTextController(
    document: const RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'p1',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'abcdef')],
        ),
        TextBlockNode(
          id: 'p2',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: '123XYZ')],
        ),
      ],
    ),
    selection: DocumentSelection(
      base: DocumentPosition.text(
        blockId: 'p1',
        blockIndex: 0,
        offset: 2,
      ),
      extent: DocumentPosition.text(
        blockId: 'p2',
        blockIndex: 1,
        offset: 3,
      ),
    ),
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('move caret forward and backward within and across editable blocks', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hi')],
          ),
          DividerBlockNode(id: 'd1'),
          CodeBlockNode(id: 'c1', code: 'ok'),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 2),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveCaretCommand(CaretMovementDirection.forward),
    );

    expect(session.selection?.extent.blockId, 'c1');
    expect(session.selection?.extent.offset, 0);
    expect(session.canUndo, isFalse);

    executor.execute(
      const MoveCaretCommand(CaretMovementDirection.backward),
    );

    expect(session.selection?.extent.blockId, 'p1');
    expect(session.selection?.extent.offset, 2);
    expect(session.canUndo, isFalse);
  });

  test('move caret collapses expanded selection without recording history', () {
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
      selection: DocumentSelection(
        base: DocumentPosition(
          blockId: 'p1',
          blockIndex: 0,
          path: PositionPath.blockText('p1'),
          offset: 1,
        ),
        extent: DocumentPosition(
          blockId: 'p1',
          blockIndex: 0,
          path: PositionPath.blockText('p1'),
          offset: 4,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveCaretCommand(CaretMovementDirection.backward),
    );

    expect(session.selection?.isCollapsed, isTrue);
    expect(session.selection?.extent.offset, 1);
    expect(session.canUndo, isFalse);
  });

  test('move caret expands selection from the extent side', () {
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
      selection: collapsedTextSelection('p1', 0, 3),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveCaretCommand(
        CaretMovementDirection.backward,
        expandSelection: true,
      ),
    );

    expect(session.selection?.isCollapsed, isFalse);
    expect(session.selection?.base.offset, 3);
    expect(session.selection?.extent.offset, 2);
    expect(session.canUndo, isFalse);
  });

  test('move caret creates selection at first editable block when missing', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          DividerBlockNode(id: 'd1'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveCaretCommand(CaretMovementDirection.forward),
    );

    expect(session.selection?.extent.blockId, 'p1');
    expect(session.selection?.extent.offset, 0);
    expect(session.canUndo, isFalse);
  });

  test('move caret creates selection inside first callout block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          DividerBlockNode(id: 'd1'),
          CalloutBlockNode(
            id: 'callout1',
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveCaretCommand(CaretMovementDirection.forward),
    );

    expect(session.selection?.extent.blockId, 'callout1');
    expect(session.selection?.extent.path, PositionPath.blockText('callout1'));
    expect(session.selection?.extent.offset, 0);
    expect(session.canUndo, isFalse);
  });

  group('move caret by word', () {
    test('forward skips a word run then following separators', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'foo bar')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretByWordCommand(CaretMovementDirection.forward),
      );
      // Lands at the start of "bar" (skipped "foo" + the space).
      expect(session.selection?.extent.offset, 4);

      executor.execute(
        const MoveCaretByWordCommand(CaretMovementDirection.forward),
      );
      // End of the block.
      expect(session.selection?.extent.offset, 7);
      expect(session.canUndo, isFalse);
    });

    test('backward skips preceding word run', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'foo bar')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 7),
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretByWordCommand(CaretMovementDirection.backward),
      );
      expect(session.selection?.extent.offset, 4);

      executor.execute(
        const MoveCaretByWordCommand(CaretMovementDirection.backward),
      );
      expect(session.selection?.extent.offset, 0);
    });

    test('expandSelection extends from a fixed base', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'foo bar')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretByWordCommand(
          CaretMovementDirection.forward,
          expandSelection: true,
        ),
      );

      expect(session.selection?.isCollapsed, isFalse);
      expect(session.selection?.base.offset, 0);
      expect(session.selection?.extent.offset, 4);
    });

    test(
        'non-collapsed selection collapses to start then jumps backward by word',
        () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'hello world')],
            ),
          ],
        ),
        selection: textSelection('p1', 0, 1, 4), // "ell" selected
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretByWordCommand(CaretMovementDirection.backward),
      );

      // Collapsed to selection.start (1), then jumped backward to word
      // boundary (0).
      expect(session.selection?.isCollapsed, isTrue);
      expect(session.selection?.extent.offset, 0);
      expect(session.canUndo, isFalse);
    });

    test('non-collapsed selection collapses to end then jumps forward by word',
        () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'hello world')],
            ),
          ],
        ),
        selection: textSelection('p1', 0, 1, 4), // "ell" selected
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretByWordCommand(CaretMovementDirection.forward),
      );

      // Collapsed to selection.end (4), then jumped forward to next word
      // boundary. From offset 4 ('o'), forward skips "o" then the space,
      // landing at 'w' (6).
      expect(session.selection?.isCollapsed, isTrue);
      expect(session.selection?.extent.offset, 6);
      expect(session.canUndo, isFalse);
    });

    test('non-collapsed word with expandSelection=true extends from base', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'hello world')],
            ),
          ],
        ),
        selection: textSelection('p1', 0, 1, 4), // base=1, extent=4
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretByWordCommand(
          CaretMovementDirection.forward,
          expandSelection: true,
        ),
      );

      // Extends from base (1) to next word boundary from extent (4→6).
      expect(session.selection?.isCollapsed, isFalse);
      expect(session.selection?.base.offset, 1);
      expect(session.selection?.extent.offset, 6);
      expect(session.canUndo, isFalse);
    });
  });

  group('move caret to boundary', () {
    test('block boundary home/end moves within the current block', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abc')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'def')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p2', 1, 1),
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretToBlockBoundaryCommand(CaretMovementDirection.backward),
      );
      expect(session.selection?.extent.blockId, 'p2');
      expect(session.selection?.extent.offset, 0);

      executor.execute(
        const MoveCaretToBlockBoundaryCommand(CaretMovementDirection.forward),
      );
      expect(session.selection?.extent.offset, 3);
    });

    test('document boundary jumps across blocks', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abc')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'def')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 1),
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretToDocumentBoundaryCommand(
          CaretMovementDirection.forward,
        ),
      );
      expect(session.selection?.extent.blockId, 'p2');
      expect(session.selection?.extent.offset, 3);

      executor.execute(
        const MoveCaretToDocumentBoundaryCommand(
          CaretMovementDirection.backward,
        ),
      );
      expect(session.selection?.extent.blockId, 'p1');
      expect(session.selection?.extent.offset, 0);
    });

    test('non-collapsed selection collapses to start on Home', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcdef')],
            ),
          ],
        ),
        selection: textSelection('p1', 0, 2, 5), // "cde" selected
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretToBlockBoundaryCommand(CaretMovementDirection.backward),
      );

      expect(session.selection?.isCollapsed, isTrue);
      expect(session.selection?.extent.offset, 0);
      expect(session.canUndo, isFalse);
    });

    test('non-collapsed selection collapses to end on End', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcdef')],
            ),
          ],
        ),
        selection: textSelection('p1', 0, 2, 5), // "cde" selected
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretToBlockBoundaryCommand(CaretMovementDirection.forward),
      );

      expect(session.selection?.isCollapsed, isTrue);
      expect(session.selection?.extent.offset, 6); // end of "abcdef"
      expect(session.canUndo, isFalse);
    });

    test('non-collapsed Home with expandSelection=true extends to boundary',
        () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcdef')],
            ),
          ],
        ),
        selection: textSelection('p1', 0, 2, 5), // base=2, extent=5
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretToBlockBoundaryCommand(
          CaretMovementDirection.backward,
          expandSelection: true,
        ),
      );

      expect(session.selection?.isCollapsed, isFalse);
      expect(session.selection?.base.offset, 2); // base stays
      expect(session.selection?.extent.offset, 0); // extent moves to start
      expect(session.canUndo, isFalse);
    });

    test('document boundary from non-collapsed selection collapses correctly',
        () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abc')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'def')],
            ),
          ],
        ),
        selection: textSelection('p1', 0, 1, 3), // "bc" selected
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretToDocumentBoundaryCommand(
          CaretMovementDirection.forward,
        ),
      );
      // Should collapse and jump to document end.
      expect(session.selection?.isCollapsed, isTrue);
      expect(session.selection?.extent.blockId, 'p2');
      expect(session.selection?.extent.offset, 3);

      executor.execute(
        const MoveCaretToDocumentBoundaryCommand(
          CaretMovementDirection.backward,
        ),
      );
      // Should jump to document start.
      expect(session.selection?.isCollapsed, isTrue);
      expect(session.selection?.extent.blockId, 'p1');
      expect(session.selection?.extent.offset, 0);
      expect(session.canUndo, isFalse);
    });

    test('document boundary from non-collapsed with expandSelection extends',
        () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abc')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'def')],
            ),
          ],
        ),
        selection: textSelection('p2', 1, 0, 2), // "de" selected in p2
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretToDocumentBoundaryCommand(
          CaretMovementDirection.backward,
          expandSelection: true,
        ),
      );
      // Extends from base to document start.
      expect(session.selection?.isCollapsed, isFalse);
      expect(session.selection?.base.blockId, 'p2');
      expect(session.selection?.base.offset, 0);
      expect(session.selection?.extent.blockId, 'p1');
      expect(session.selection?.extent.offset, 0);
      expect(session.canUndo, isFalse);
    });
  });

  test('select all spans first selectable start to last selectable end', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          DividerBlockNode(id: 'd1'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abc')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'def')],
          ),
          DividerBlockNode(id: 'd2'),
        ],
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const SelectAllCommand());

    expect(session.selection, isNotNull);
    expect(session.selection!.isCollapsed, isFalse);
    expect(session.selection!.start.blockId, 'd1');
    expect(session.selection!.start.path.isBlockObject, isTrue);
    expect(session.selection!.start.offset, 0);
    expect(session.selection!.end.blockId, 'd2');
    expect(session.selection!.end.path.isBlockObject, isTrue);
    expect(session.selection!.end.offset, 1);
    expect(session.canUndo, isFalse);
  });

  test('select all includes image blocks at document edges', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'img1', assetId: 'a1'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abc')],
          ),
          ImageBlockNode(id: 'img2', assetId: 'a2'),
        ],
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const SelectAllCommand());

    expect(session.selection, isNotNull);
    expect(session.selection!.isCollapsed, isFalse);
    expect(session.selection!.start.blockId, 'img1');
    expect(session.selection!.start.path.isBlockObject, isTrue);
    expect(session.selection!.start.offset, 0);
    expect(session.selection!.end.blockId, 'img2');
    expect(session.selection!.end.path.isBlockObject, isTrue);
    expect(session.selection!.end.offset, 1);
  });

  test('select all treats callout as editable text range', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            title: 'Info',
            content: <InlineNode>[TextRun(text: 'abc')],
          ),
        ],
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const SelectAllCommand());

    expect(session.selection, isNotNull);
    expect(session.selection!.start.blockId, 'callout1');
    expect(session.selection!.start.path, PositionPath.blockText('callout1'));
    expect(session.selection!.start.offset, 0);
    expect(session.selection!.end.blockId, 'callout1');
    expect(session.selection!.end.path, PositionPath.blockText('callout1'));
    expect(session.selection!.end.offset, 3);
  });

  test('arrow navigation selects a video block as an atomic object', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          VideoBlockNode(
            id: 'video1',
            assetId: 'clip',
            playbackUrl: 'https://cdn.example.test/clip.mp4',
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 6),
    );
    final executor = CommandExecutor(session);

    executor.execute(const MoveCaretCommand(CaretMovementDirection.forward));

    expect(session.selection?.isCollapsed, isFalse);
    expect(session.selection?.start.blockId, 'video1');
    expect(session.selection?.start.path.isBlockObject, isTrue);
    expect(session.selection?.start.offset, 0);
    expect(session.selection?.end.blockId, 'video1');
    expect(session.selection?.end.offset, 1);
    expect(session.canUndo, isFalse);
  });

  test('arrow navigation selects previous video from following text', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(id: 'video1', assetId: 'clip'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 1, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(const MoveCaretCommand(CaretMovementDirection.backward));

    expect(session.selection?.isCollapsed, isFalse);
    expect(session.selection?.start.blockId, 'video1');
    expect(session.selection?.start.path.isBlockObject, isTrue);
    expect(session.selection?.start.offset, 0);
    expect(session.selection?.end.offset, 1);
    expect(session.canUndo, isFalse);
  });

  test('table cell caret moves within and across cells', () {
    final session = DocumentSession(
      document: _tableDocument(),
      selection: _tableCellSelection(row: 0, column: 0, offset: 1),
    );
    final executor = CommandExecutor(session);

    executor.execute(const MoveCaretCommand(CaretMovementDirection.forward));
    expect(session.selection?.extent.offset, 2);
    expect(session.selection?.extent.path.tableColumnIndex, 0);

    executor.execute(const MoveCaretCommand(CaretMovementDirection.forward));
    expect(session.selection?.extent.offset, 0);
    expect(session.selection?.extent.path.tableColumnIndex, 1);

    executor.execute(const MoveCaretCommand(CaretMovementDirection.backward));
    expect(session.selection?.extent.offset, 2);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
  });

  test('table cell home and end move within the current cell', () {
    final session = DocumentSession(
      document: _tableDocument(),
      selection: _tableCellSelection(row: 0, column: 1, offset: 1),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveCaretToBlockBoundaryCommand(CaretMovementDirection.backward),
    );
    expect(session.selection?.extent.path.tableColumnIndex, 1);
    expect(session.selection?.extent.offset, 0);

    executor.execute(
      const MoveCaretToBlockBoundaryCommand(CaretMovementDirection.forward),
    );
    expect(session.selection?.extent.path.tableColumnIndex, 1);
    expect(session.selection?.extent.offset, 2);
  });

  test('move table cell command traverses rows in reading order', () {
    final session = DocumentSession(
      document: _tableDocument(),
      selection: _tableCellSelection(row: 0, column: 1, offset: 2),
    );
    final executor = CommandExecutor(session);

    executor
        .execute(const MoveTableCellCommand(CaretMovementDirection.forward));
    expect(session.selection?.extent.path.tableRowIndex, 1);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
    expect(session.selection?.extent.offset, 0);

    executor
        .execute(const MoveTableCellCommand(CaretMovementDirection.backward));
    expect(session.selection?.extent.path.tableRowIndex, 0);
    expect(session.selection?.extent.path.tableColumnIndex, 1);
    expect(session.selection?.extent.offset, 2);
  });

  test('move table cell forward at last cell inserts a row', () {
    final session = DocumentSession(
      document: _tableDocument(),
      selection: _tableCellSelection(row: 1, column: 1, offset: 2),
    );
    final executor = CommandExecutor(session);

    executor
        .execute(const MoveTableCellCommand(CaretMovementDirection.forward));

    var table = session.document.blocks.single as TableBlockNode;
    expect(table.table.rowCount, 3);
    expect(session.selection?.extent.path.tableRowIndex, 2);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
    expect(session.selection?.extent.offset, 0);
    expect(session.canUndo, isTrue);

    session.undo();
    table = session.document.blocks.single as TableBlockNode;
    expect(table.table.rowCount, 2);
    expect(session.selection?.extent.path.tableRowIndex, 1);
    expect(session.selection?.extent.path.tableColumnIndex, 1);
  });

  test('move table cell vertical up and down stays in the same column', () {
    final session = DocumentSession(
      document: _tableDocument(),
      selection: _tableCellSelection(row: 0, column: 1, offset: 1),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveTableCellVerticalCommand(CaretMovementDirection.forward),
    );
    expect(session.selection?.extent.path.tableRowIndex, 1);
    expect(session.selection?.extent.path.tableColumnIndex, 1);
    // Offset is preserved, clamped to the target cell length (2).
    expect(session.selection?.extent.offset, 1);

    executor.execute(
      const MoveTableCellVerticalCommand(CaretMovementDirection.backward),
    );
    expect(session.selection?.extent.path.tableRowIndex, 0);
    expect(session.selection?.extent.path.tableColumnIndex, 1);
    expect(session.selection?.extent.offset, 1);
    // No history is recorded for pure caret motion.
    expect(session.canUndo, isFalse);
  });

  test('move table cell vertical is a no-op at the table edge', () {
    final session = DocumentSession(
      document: _tableDocument(),
      selection: _tableCellSelection(row: 0, column: 0, offset: 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveTableCellVerticalCommand(CaretMovementDirection.backward),
    );
    // Already on the top row: caret does not move.
    expect(session.selection?.extent.path.tableRowIndex, 0);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
    expect(session.selection?.extent.offset, 0);

    executor.execute(
      const MoveTableCellVerticalCommand(CaretMovementDirection.forward),
    );
    expect(session.selection?.extent.path.tableRowIndex, 1);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
  });

  test('move table cell vertical skips covered merged cells', () {
    // Build a 3x1 table where row 1's cell is `covered` by a merged anchor at
    // row 0 (rowSpan 2). ArrowDown from row 0 must skip row 1 and land on row 2.
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'mtable',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'm0',
                    rowSpan: 2,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'm0-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'TOP')],
                      ),
                    ],
                  ),
                ],
                <TableCellNode>[
                  TableCellNode(
                    id: 'm1',
                    covered: true,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'm1-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: '')],
                      ),
                    ],
                  ),
                ],
                <TableCellNode>[
                  TableCellNode(
                    id: 'm2',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'm2-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'BOT')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.tableCell(
          tableBlockId: 'mtable',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 1,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'mtable',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 1,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveTableCellVerticalCommand(CaretMovementDirection.forward),
    );
    // Skipped the covered cell at row 1, landed on the visible cell at row 2.
    expect(session.selection?.extent.path.tableRowIndex, 2);
    expect(session.selection?.extent.path.tableColumnIndex, 0);

    executor.execute(
      const MoveTableCellVerticalCommand(CaretMovementDirection.backward),
    );
    expect(session.selection?.extent.path.tableRowIndex, 0);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
  });

  test('move caret vertical crosses to the next editable block', () {
    // The widget layer invokes MoveCaretVerticalCommand once the caret reaches
    // the block's first/last visual line. The command must cross blocks
    // regardless of the caret's *string* offset — the offset below (3) is mid-
    // text, but the caret is on the last visual line so a Down must still
    // advance to the neighbouring block.
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
          CodeBlockNode(id: 'c1', code: 'ok'),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 3),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveCaretVerticalCommand(CaretMovementDirection.forward),
    );

    expect(session.selection?.extent.blockId, 'c1');
    expect(session.selection?.extent.offset, 0);

    executor.execute(
      const MoveCaretVerticalCommand(CaretMovementDirection.backward),
    );

    // Up from the start of c1 lands at the end of p1's editable text.
    expect(session.selection?.extent.blockId, 'p1');
    expect(session.selection?.extent.offset, 5);
    // Pure caret motion records no history.
    expect(session.canUndo, isFalse);
  });

  test('move caret vertical skips non-editable blocks (divider)', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hi')],
          ),
          DividerBlockNode(id: 'd1'),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Yo')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 2),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveCaretVerticalCommand(CaretMovementDirection.forward),
    );

    expect(session.selection?.extent.blockId, 'p2');
    expect(session.selection?.extent.offset, 0);
  });

  test('move caret vertical is a no-op at the document boundary', () {
    final session = DocumentSession(
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
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveCaretVerticalCommand(CaretMovementDirection.forward),
    );

    expect(session.selection?.extent.blockId, 'p1');
    expect(session.selection?.extent.offset, 2);
  });

  group('escape trailing object/table blocks', () {
    DocumentPosition objectPosition(String blockId) {
      return DocumentPosition(
        blockId: blockId,
        blockIndex: 0,
        path: PositionPath.blockObject(blockId),
        offset: 0,
      );
    }

    test('ArrowDown from a trailing image appends a paragraph', () {
      final pos = objectPosition('img1');
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'img1', assetId: 'a1'),
          ],
        ),
        selection: DocumentSelection(base: pos, extent: pos),
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretVerticalCommand(CaretMovementDirection.forward),
      );

      expect(session.document.blocks, hasLength(2));
      expect(session.document.blocks.last, isA<TextBlockNode>());
      expect(session.selection?.extent.blockId, 'img1-next');
      expect(session.selection?.extent.offset, 0);
      expect(session.canUndo, isTrue);
    });

    test('ArrowDown from a trailing video appends a paragraph', () {
      final pos = objectPosition('video1');
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(id: 'video1', assetId: 'clip'),
          ],
        ),
        selection:
            DocumentSelection(base: pos, extent: pos.copyWith(offset: 1)),
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretVerticalCommand(CaretMovementDirection.forward),
      );

      expect(session.document.blocks, hasLength(2));
      expect(session.document.blocks.last, isA<TextBlockNode>());
      expect(session.selection?.extent.blockId, 'video1-next');
      expect(session.selection?.extent.offset, 0);
      expect(session.canUndo, isTrue);
    });

    test('ArrowDown from the last table cell appends a paragraph', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 't1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'c0',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'c0p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'x')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
      final lastCell = DocumentPosition.tableCell(
        tableBlockId: 't1',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 1,
      );
      final session = DocumentSession(
        document: document,
        selection: DocumentSelection(base: lastCell, extent: lastCell),
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretVerticalCommand(CaretMovementDirection.forward),
      );

      expect(session.document.blocks, hasLength(2));
      expect(session.document.blocks.last, isA<TextBlockNode>());
      expect(session.selection?.extent.blockId, 't1-next');
      expect(session.selection?.extent.offset, 0);
    });

    test('ArrowRight from a trailing image appends a paragraph', () {
      final pos = objectPosition('img1');
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'img1', assetId: 'a1'),
          ],
        ),
        selection: DocumentSelection(base: pos, extent: pos),
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretCommand(CaretMovementDirection.forward),
      );

      expect(session.document.blocks, hasLength(2));
      expect(session.selection?.extent.blockId, 'img1-next');
    });

    test('ArrowDown from a paragraph does NOT append', () {
      final session = DocumentSession(
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
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretVerticalCommand(CaretMovementDirection.forward),
      );

      expect(session.document.blocks, hasLength(1));
      expect(session.selection?.extent.blockId, 'p1');
      expect(session.canUndo, isFalse);
    });

    test('ArrowDown from a non-trailing image moves on without appending', () {
      final pos = objectPosition('img1');
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'img1', assetId: 'a1'),
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'after')],
            ),
          ],
        ),
        selection: DocumentSelection(base: pos, extent: pos),
      );
      final executor = CommandExecutor(session);

      executor.execute(
        const MoveCaretVerticalCommand(CaretMovementDirection.forward),
      );

      expect(session.document.blocks, hasLength(2));
      expect(session.selection?.extent.blockId, 'p1');
      expect(session.selection?.extent.offset, 0);
    });
  });

  test('move table cell vertical is a no-op outside a table', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hi')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const MoveTableCellVerticalCommand(CaretMovementDirection.forward),
    );
    expect(session.selection?.extent.blockId, 'p1');
    expect(session.selection?.extent.offset, 1);
  });
}

RichTextDocument _tableDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table1',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'cell-a',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-a-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'AA')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-b',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-b-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'BB')],
                  ),
                ],
              ),
            ],
            <TableCellNode>[
              TableCellNode(
                id: 'cell-c',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-c-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'CC')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-d',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-d-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'DD')],
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

DocumentSelection _tableCellSelection({
  required int row,
  required int column,
  required int offset,
}) {
  final position = DocumentPosition.tableCell(
    tableBlockId: 'table1',
    blockIndex: 0,
    tableRowIndex: row,
    tableColumnIndex: column,
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}

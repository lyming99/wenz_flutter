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
  });

  test('select all spans first editable start to last editable end', () {
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
    expect(session.selection!.start.blockId, 'p1');
    expect(session.selection!.start.offset, 0);
    expect(session.selection!.end.blockId, 'p2');
    expect(session.selection!.end.offset, 3);
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

    executor.execute(const MoveTableCellCommand(CaretMovementDirection.forward));
    expect(session.selection?.extent.path.tableRowIndex, 1);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
    expect(session.selection?.extent.offset, 0);

    executor.execute(const MoveTableCellCommand(CaretMovementDirection.backward));
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

    executor.execute(const MoveTableCellCommand(CaretMovementDirection.forward));

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

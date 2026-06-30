import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('insert blocks command inserts copied blocks at index', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'one')],
          ),
          TextBlockNode(
            id: 'p3',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'three')],
          ),
        ],
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const InsertBlocksCommand(
        index: 1,
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'two')],
          ),
        ],
      ),
    );

    expect(session.document.plainText, 'one\ntwo\nthree');
    expect(session.canUndo, isTrue);
  });

  test('insert object block after current empty paragraph replaces it', () {
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

    executor.execute(
      const InsertBlocksCommand(
        index: 1,
        blocks: <BlockNode>[
          ImageBlockNode(id: 'img1', assetId: 'a1'),
        ],
      ),
    );

    expect(session.document.blocks, hasLength(1));
    expect(session.document.blocks.single, isA<ImageBlockNode>());
    expect(session.selection?.start.blockId, 'img1');
    expect(session.selection?.start.path.isBlockObject, isTrue);
    expect(session.selection?.start.offset, 0);
    expect(session.selection?.end.offset, 1);
  });

  test('insert object block after non-empty paragraph keeps the paragraph', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'text')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 4),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const InsertBlocksCommand(
        index: 1,
        blocks: <BlockNode>[
          ImageBlockNode(id: 'img1', assetId: 'a1'),
        ],
      ),
    );

    expect(session.document.blocks, hasLength(2));
    expect(session.document.blocks[0].id, 'p1');
    expect(session.document.blocks[1], isA<ImageBlockNode>());
  });

  test('insert object block at text caret splits the paragraph', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'HelloWorld')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const InsertBlocksCommand(
        index: 0,
        blocks: <BlockNode>[ImageBlockNode(id: 'img1', assetId: 'a1')],
      ),
    );

    expect(session.document.blocks, hasLength(3));
    expect((session.document.blocks[0] as TextBlockNode).plainText, 'Hello');
    expect(session.document.blocks[1], isA<ImageBlockNode>());
    expect(session.document.blocks[1].id, 'img1');
    expect((session.document.blocks[2] as TextBlockNode).plainText, 'World');
    expect(session.document.blocks[2].id, 'p1-after');
    expect(session.selection?.start.blockId, 'img1');
    expect(session.selection?.start.path.isBlockObject, isTrue);
    expect(session.selection?.start.offset, 0);
    expect(session.selection?.end.offset, 1);
  });

  test('insert table at text caret splits the paragraph and focuses the table',
      () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'HelloWorld')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const InsertTableCommand(
        index: 0,
        tableId: 't1',
        rowCount: 2,
        columnCount: 2,
      ),
    );

    expect(session.document.blocks, hasLength(3));
    expect((session.document.blocks[0] as TextBlockNode).plainText, 'Hello');
    expect(session.document.blocks[1], isA<TableBlockNode>());
    expect((session.document.blocks[2] as TextBlockNode).plainText, 'World');
    expect(session.selection?.extent.blockId, 't1');
    expect(session.selection?.extent.blockIndex, 1);
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.path.tableRowIndex, 0);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
    expect(session.selection?.extent.offset, 0);
  });

  test('replace blocks command replaces requested range', () {
    final session = DocumentSession(
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
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const ReplaceBlocksCommand(
        index: 0,
        deleteCount: 2,
        blocks: <BlockNode>[DividerBlockNode(id: 'line')],
      ),
    );

    expect(session.document.blocks.single, isA<DividerBlockNode>());
  });

  test('set block anchor command writes trimmed anchor and supports undo', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1),
            content: <InlineNode>[TextRun(text: 'Title')],
          ),
        ],
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const SetBlockAnchorCommand(blockIndex: 0, anchor: ' intro '),
    );

    var heading = session.document.blocks.single as TextBlockNode;
    expect(heading.attributes.anchor, 'intro');
    expect(session.canUndo, isTrue);

    expect(session.undo(), isTrue);
    heading = session.document.blocks.single as TextBlockNode;
    expect(heading.attributes.anchor, isNull);
  });

  test('set block anchor command clears anchor with empty text', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1, anchor: 'intro'),
            content: <InlineNode>[TextRun(text: 'Title')],
          ),
        ],
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const SetBlockAnchorCommand(blockIndex: 0, anchor: '  '));

    final heading = session.document.blocks.single as TextBlockNode;
    expect(heading.attributes.anchor, isNull);
  });

  test('enter splits text block at selection', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'HelloWorld')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
    );
    final executor = CommandExecutor(session);

    executor.execute(const EnterCommand(newBlockId: 'p2'));

    expect(session.document.blocks, hasLength(2));
    expect(session.document.plainText, 'Hello\nWorld');
    expect(session.selection?.extent.blockId, 'p2');
    expect(session.selection?.extent.offset, 0);
  });

  test('enter continues a list item with the same list metadata', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'li1',
            type: BlockType.listItem,
            attributes: BlockAttributes(indent: 2, listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'First')],
          ),
        ],
      ),
      selection: collapsedTextSelection('li1', 0, 5),
    );
    final executor = CommandExecutor(session);

    executor.execute(const EnterCommand(newBlockId: 'li2'));

    expect(session.document.blocks, hasLength(2));
    final first = session.document.blocks[0] as TextBlockNode;
    final second = session.document.blocks[1] as TextBlockNode;
    expect(first.type, BlockType.listItem);
    expect(first.plainText, 'First');
    expect(second.type, BlockType.listItem);
    expect(second.attributes.indent, 2);
    expect(second.attributes.listType, 'ordered');
    expect(second.plainText, isEmpty);
    expect(session.selection?.extent.blockId, 'li2');
  });

  test('enter after a checked task creates an unchecked task item', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'task1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: true),
            content: <InlineNode>[TextRun(text: 'Done')],
          ),
        ],
      ),
      selection: collapsedTextSelection('task1', 0, 4),
    );
    final executor = CommandExecutor(session);

    executor.execute(const EnterCommand(newBlockId: 'task2'));

    final first = session.document.blocks[0] as TextBlockNode;
    final second = session.document.blocks[1] as TextBlockNode;
    expect(first.attributes.checked, isTrue);
    expect(second.type, BlockType.listItem);
    expect(second.attributes.listType, 'task');
    expect(second.attributes.checked, isFalse);
  });

  test('enter after checked ordered todo keeps numbering and resets checked', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'ordered1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', checked: true),
            content: <InlineNode>[TextRun(text: 'Done')],
          ),
        ],
      ),
      selection: collapsedTextSelection('ordered1', 0, 4),
    );
    final executor = CommandExecutor(session);

    executor.execute(const EnterCommand(newBlockId: 'ordered2'));

    final first = session.document.blocks[0] as TextBlockNode;
    final second = session.document.blocks[1] as TextBlockNode;
    expect(first.attributes.listType, 'ordered');
    expect(first.attributes.checked, isTrue);
    expect(second.type, BlockType.listItem);
    expect(second.attributes.listType, 'ordered');
    expect(second.attributes.checked, isFalse);
  });

  test('enter on an empty list item exits the list', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'li1',
            type: BlockType.listItem,
            attributes: BlockAttributes(
              indent: 1,
              listType: 'task',
              checked: false,
              anchor: 'todo',
            ),
            content: <InlineNode>[],
          ),
        ],
      ),
      selection: collapsedTextSelection('li1', 0, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(const EnterCommand());

    expect(session.document.blocks, hasLength(1));
    final block = session.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.paragraph);
    expect(block.attributes.listType, isNull);
    expect(block.attributes.checked, isNull);
    expect(block.attributes.indent, 1);
    expect(block.attributes.anchor, 'todo');
    expect(session.selection?.extent.blockId, 'li1');
    expect(session.selection?.extent.offset, 0);
  });

  test('enter on an empty quoted paragraph removes quote styling', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'quote1',
            type: BlockType.paragraph,
            attributes: BlockAttributes(
              indent: 2,
              alignment: 'center',
              quoted: true,
              childNote: 'note1',
              anchor: 'anchor1',
            ),
            content: <InlineNode>[TextRun(text: '   ')],
          ),
        ],
      ),
      selection: collapsedTextSelection('quote1', 0, 3),
    );
    final executor = CommandExecutor(session);

    executor.execute(const EnterCommand(newBlockId: 'quote2'));

    expect(session.document.blocks, hasLength(1));
    final block = session.document.blocks.single as TextBlockNode;
    expect(block.id, 'quote1');
    expect(block.type, BlockType.paragraph);
    expect(block.plainText, isEmpty);
    expect(block.attributes.quoted, isNull);
    expect(block.attributes.indent, 2);
    expect(block.attributes.alignment, 'center');
    expect(block.attributes.childNote, 'note1');
    expect(block.attributes.anchor, 'anchor1');
    expect(session.selection?.extent.blockId, 'quote1');
    expect(session.selection?.extent.offset, 0);
  });

  test('enter on an empty legacy quote block converts it to a paragraph', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'quote1',
            type: BlockType.quote,
            attributes: BlockAttributes(indent: 1, anchor: 'legacy'),
            content: <InlineNode>[],
          ),
        ],
      ),
      selection: collapsedTextSelection('quote1', 0, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(const EnterCommand(newBlockId: 'quote2'));

    expect(session.document.blocks, hasLength(1));
    final block = session.document.blocks.single as TextBlockNode;
    expect(block.id, 'quote1');
    expect(block.type, BlockType.paragraph);
    expect(block.attributes.quoted, isNull);
    expect(block.attributes.indent, 1);
    expect(block.attributes.anchor, 'legacy');
    expect(session.selection?.extent.blockId, 'quote1');
    expect(session.selection?.extent.offset, 0);
  });

  test('enter on a non-empty quoted block continues quote styling', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'quote1',
            type: BlockType.paragraph,
            attributes: BlockAttributes(quoted: true),
            content: <InlineNode>[TextRun(text: 'HelloWorld')],
          ),
        ],
      ),
      selection: collapsedTextSelection('quote1', 0, 5),
    );
    final executor = CommandExecutor(session);

    executor.execute(const EnterCommand(newBlockId: 'quote2'));

    expect(session.document.blocks, hasLength(2));
    final first = session.document.blocks[0] as TextBlockNode;
    final second = session.document.blocks[1] as TextBlockNode;
    expect(first.plainText, 'Hello');
    expect(first.attributes.isQuoted, isTrue);
    expect(second.id, 'quote2');
    expect(second.plainText, 'World');
    expect(second.attributes.isQuoted, isTrue);
    expect(session.selection?.extent.blockId, 'quote2');
    expect(session.selection?.extent.offset, 0);
  });

  test('enter inserts newline into code block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', code: 'ab', language: 'text'),
        ],
      ),
      selection: collapsedCodeSelection('c1', 0, 1),
    );
    final executor = CommandExecutor(session);

    executor.execute(const EnterCommand());

    expect(session.document.plainText, 'a\nb');
    expect(session.selection?.extent.offset, 2);
  });

  test('enter inserts newline inside table cell text', () {
    final session = DocumentSession(
      document: _tableCellDocument('HelloWorld'),
      selection: _collapsedTableCellSelection(5),
    );
    final executor = CommandExecutor(session);

    executor.execute(const EnterCommand());

    expect(session.document.blocks, hasLength(1));
    final table = session.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.plainText, 'Hello\nWorld');
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.offset, 6);
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

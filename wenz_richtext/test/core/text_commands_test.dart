import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('insert text updates text block and selection', () {
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

    executor.execute(const InsertTextCommand(' world'));

    expect(session.document.plainText, 'Hello world');
    expect(session.selection?.extent.offset, 11);
    expect(session.canUndo, isTrue);
  });

  test('insert text replaces non collapsed selection', () {
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
      selection: textSelection('p1', 0, 1, 4),
    );
    final executor = CommandExecutor(session);

    executor.execute(const InsertTextCommand('i'));

    expect(session.document.plainText, 'Hio');
    expect(session.selection?.extent.offset, 2);
  });

  test('delete selection removes same-block text range', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello world')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 5, 11),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(session.document.plainText, 'Hello');
    expect(session.selection?.isCollapsed, isTrue);
    expect(session.selection?.extent.offset, 5);
  });

  test('callout deletion boundary is editable body content only', () {
    const block = CalloutBlockNode(
      id: 'callout1',
      variant: CalloutBlockNode.warningVariant,
      title: 'Heads up',
      icon: '!',
      attributes: BlockAttributes(anchor: 'note-anchor'),
      content: <InlineNode>[
        TextRun(text: 'Keep '),
        TextRun(
          text: 'body',
          attributes: TextAttributes(bold: true),
        ),
      ],
    );

    final bodyPath = PositionPath.blockText(block.id);
    final selection = DocumentSelection(
      base: DocumentPosition(
        blockId: block.id,
        blockIndex: 0,
        path: bodyPath,
        offset: 0,
      ),
      extent: DocumentPosition(
        blockId: block.id,
        blockIndex: 0,
        path: bodyPath,
        offset: 9,
      ),
    );
    final emptyBody = block.copyWith(content: const <InlineNode>[]);

    expect(selection.start.path.isBlockText, isTrue);
    expect(selection.start.path.isBlockObject, isFalse);
    expect(block.content.map((node) => node.plainText).join(), 'Keep body');
    expect(emptyBody.id, block.id);
    expect(emptyBody.variant, block.variant);
    expect(emptyBody.title, block.title);
    expect(emptyBody.icon, block.icon);
    expect(emptyBody.attributes, block.attributes);
    expect(emptyBody.content, isEmpty);
    expect(emptyBody.toJson()['type'], BlockType.callout.name);
  });

  test('delete selection removes same-callout body range', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            variant: CalloutBlockNode.warningVariant,
            title: 'Heads up',
            icon: '!',
            attributes: BlockAttributes(anchor: 'note-anchor'),
            content: <InlineNode>[
              TextRun(text: 'Keep '),
              TextRun(
                text: 'this',
                attributes: TextAttributes(bold: true),
              ),
              TextRun(text: ' body'),
            ],
          ),
        ],
      ),
      selection: calloutSelection('callout1', 0, 5, 9),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    final block = session.document.blocks.single as CalloutBlockNode;
    expect(block.content.map((node) => node.plainText).join(), 'Keep  body');
    expect(block.id, 'callout1');
    expect(block.variant, CalloutBlockNode.warningVariant);
    expect(block.title, 'Heads up');
    expect(block.icon, '!');
    expect(block.attributes, const BlockAttributes(anchor: 'note-anchor'));
    expect(session.selection?.isCollapsed, isTrue);
    expect(session.selection?.extent.blockId, 'callout1');
    expect(session.selection?.extent.path, PositionPath.blockText('callout1'));
    expect(session.selection?.extent.offset, 5);
  });

  test('delete selection clears same-callout body without removing block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            variant: CalloutBlockNode.dangerVariant,
            title: 'Danger',
            icon: '!!',
            content: <InlineNode>[TextRun(text: 'Remove me')],
          ),
        ],
      ),
      selection: calloutSelection('callout1', 0, 0, 9),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    final block = session.document.blocks.single as CalloutBlockNode;
    expect(block.content, isEmpty);
    expect(block.id, 'callout1');
    expect(block.variant, CalloutBlockNode.dangerVariant);
    expect(block.title, 'Danger');
    expect(block.icon, '!!');
    expect(session.selection?.isCollapsed, isTrue);
    expect(session.selection?.extent.path, PositionPath.blockText('callout1'));
    expect(session.selection?.extent.offset, 0);
  });

  test('delete selection preserves callout inline styles outside range', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            content: <InlineNode>[
              TextRun(
                text: 'AA',
                attributes: TextAttributes(bold: true),
              ),
              TextRun(text: 'middle'),
              TextRun(
                text: 'ZZ',
                attributes: TextAttributes(italic: true),
              ),
            ],
          ),
        ],
      ),
      selection: calloutSelection('callout1', 0, 2, 8),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    final block = session.document.blocks.single as CalloutBlockNode;
    expect(block.content, hasLength(2));
    expect((block.content[0] as TextRun).text, 'AA');
    expect((block.content[0] as TextRun).attributes.bold, isTrue);
    expect((block.content[1] as TextRun).text, 'ZZ');
    expect((block.content[1] as TextRun).attributes.italic, isTrue);
    expect(session.selection?.extent.offset, 2);
  });

  test('delete selection in callout records undo and redo snapshots', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            variant: CalloutBlockNode.warningVariant,
            title: 'Heads up',
            icon: '!',
            attributes: BlockAttributes(anchor: 'note-anchor'),
            content: <InlineNode>[TextRun(text: 'Keep this body')],
          ),
        ],
      ),
      selection: calloutSelection('callout1', 0, 5, 10),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    var block = session.document.blocks.single as CalloutBlockNode;
    expect(block.content.map((node) => node.plainText).join(), 'Keep body');
    expect(block.variant, CalloutBlockNode.warningVariant);
    expect(block.title, 'Heads up');
    expect(block.icon, '!');
    expect(block.attributes, const BlockAttributes(anchor: 'note-anchor'));
    expect(session.canUndo, isTrue);

    expect(session.undo(), isTrue);
    block = session.document.blocks.single as CalloutBlockNode;
    expect(block.content.map((node) => node.plainText).join(), 'Keep this body');
    expect(block.variant, CalloutBlockNode.warningVariant);
    expect(block.title, 'Heads up');
    expect(block.icon, '!');
    expect(block.attributes, const BlockAttributes(anchor: 'note-anchor'));

    expect(session.redo(), isTrue);
    block = session.document.blocks.single as CalloutBlockNode;
    expect(block.content.map((node) => node.plainText).join(), 'Keep body');
    expect(block.variant, CalloutBlockNode.warningVariant);
    expect(block.title, 'Heads up');
    expect(block.icon, '!');
    expect(block.attributes, const BlockAttributes(anchor: 'note-anchor'));
  });

  test('delete selection clamps callout body offsets at boundaries', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
      selection: calloutSelection('callout1', 0, -4, 99),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    final block = session.document.blocks.single as CalloutBlockNode;
    expect(block.content, isEmpty);
    expect(session.selection?.extent.path, PositionPath.blockText('callout1'));
    expect(session.selection?.extent.offset, -4);
  });

  test('delete selection ignores callout range with non-body text path', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            title: 'Info',
            content: <InlineNode>[TextRun(text: 'Keep me')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.code(
          blockId: 'callout1',
          blockIndex: 0,
          offset: 0,
        ),
        extent: DocumentPosition.code(
          blockId: 'callout1',
          blockIndex: 0,
          offset: 1,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    final block = session.document.blocks.single as CalloutBlockNode;
    expect(block.content.map((node) => node.plainText).join(), 'Keep me');
    expect(session.selection?.start.path.isBlockCode, isTrue);
  });

  test('delete selection merges text across blocks', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello first')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'middle')],
          ),
          TextBlockNode(
            id: 'p3',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'last world')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition(
          blockId: 'p1',
          blockIndex: 0,
          path: PositionPath.blockText('p1'),
          offset: 5,
        ),
        extent: DocumentPosition(
          blockId: 'p3',
          blockIndex: 2,
          path: PositionPath.blockText('p3'),
          offset: 4,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(session.document.blocks, hasLength(1));
    expect(session.document.plainText, 'Hello world');
    expect(session.selection?.extent.blockIndex, 0);
    expect(session.selection?.extent.offset, 5);
  });

  test('delete selection spans code block boundary into text block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', code: 'final value = 1;'),
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
                ],
              ],
            ),
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'tail text')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.code(
          blockId: 'c1',
          blockIndex: 0,
          offset: 6,
        ),
        extent: DocumentPosition.text(
          blockId: 'p2',
          blockIndex: 2,
          offset: 5,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(session.document.blocks, hasLength(2));
    expect((session.document.blocks[0] as CodeBlockNode).code, 'final ');
    expect((session.document.blocks[1] as TextBlockNode).plainText, 'text');
    expect(session.selection?.extent.blockId, 'c1');
    expect(session.selection?.extent.offset, 6);
  });

  test('delete selection spans text block into code block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'hello start')],
          ),
          DividerBlockNode(id: 'divider1'),
          CodeBlockNode(id: 'c2', code: 'print("tail");'),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.text(
          blockId: 'p1',
          blockIndex: 0,
          offset: 5,
        ),
        extent: DocumentPosition.code(
          blockId: 'c2',
          blockIndex: 2,
          offset: 6,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(session.document.blocks, hasLength(2));
    expect((session.document.blocks[0] as TextBlockNode).plainText, 'hello');
    expect((session.document.blocks[1] as CodeBlockNode).code, '"tail");');
    expect(session.selection?.extent.blockId, 'p1');
    expect(session.selection?.extent.offset, 5);
  });

  test('delete selection spans callout body into later text block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            variant: CalloutBlockNode.warningVariant,
            title: 'Heads up',
            icon: '!',
            attributes: BlockAttributes(anchor: 'note-anchor'),
            content: <InlineNode>[TextRun(text: 'Keep callout tail')],
          ),
          DividerBlockNode(id: 'divider1'),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'text remains')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.text(
          blockId: 'callout1',
          blockIndex: 0,
          offset: 4,
        ),
        extent: DocumentPosition.text(
          blockId: 'p2',
          blockIndex: 2,
          offset: 5,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(session.document.blocks, hasLength(2));
    final callout = session.document.blocks[0] as CalloutBlockNode;
    expect(callout.content.map((node) => node.plainText).join(), 'Keep');
    expect(callout.variant, CalloutBlockNode.warningVariant);
    expect(callout.title, 'Heads up');
    expect(callout.icon, '!');
    expect(callout.attributes, const BlockAttributes(anchor: 'note-anchor'));
    expect((session.document.blocks[1] as TextBlockNode).plainText, 'remains');
    expect(session.selection?.extent.blockId, 'callout1');
    expect(session.selection?.extent.path, PositionPath.blockText('callout1'));
    expect(session.selection?.extent.offset, 4);
  });

  test('delete selection spans text block into later callout body', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'head text')],
          ),
          ImageBlockNode(id: 'img1', assetId: 'a1'),
          CalloutBlockNode(
            id: 'callout1',
            variant: CalloutBlockNode.successVariant,
            title: 'Done',
            icon: '✓',
            content: <InlineNode>[TextRun(text: 'callout remains')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.text(
          blockId: 'p1',
          blockIndex: 0,
          offset: 4,
        ),
        extent: DocumentPosition.text(
          blockId: 'callout1',
          blockIndex: 2,
          offset: 8,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(session.document.blocks, hasLength(2));
    expect((session.document.blocks[0] as TextBlockNode).plainText, 'head');
    final callout = session.document.blocks[1] as CalloutBlockNode;
    expect(callout.content.map((node) => node.plainText).join(), 'remains');
    expect(callout.variant, CalloutBlockNode.successVariant);
    expect(callout.title, 'Done');
    expect(callout.icon, '✓');
    expect(session.selection?.extent.blockId, 'p1');
    expect(session.selection?.extent.offset, 4);
  });

  test('delete selection merges callout body remainders', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            variant: CalloutBlockNode.dangerVariant,
            title: 'Danger',
            icon: '!!',
            content: <InlineNode>[TextRun(text: 'Keep start')],
          ),
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
                ],
              ],
            ),
          ),
          CalloutBlockNode(
            id: 'callout2',
            variant: CalloutBlockNode.infoVariant,
            title: 'Info',
            icon: 'i',
            content: <InlineNode>[TextRun(text: 'end kept')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.text(
          blockId: 'callout1',
          blockIndex: 0,
          offset: 4,
        ),
        extent: DocumentPosition.text(
          blockId: 'callout2',
          blockIndex: 2,
          offset: 3,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(session.document.blocks, hasLength(1));
    final callout = session.document.blocks.single as CalloutBlockNode;
    expect(callout.content.map((node) => node.plainText).join(), 'Keep kept');
    expect(callout.id, 'callout1');
    expect(callout.variant, CalloutBlockNode.dangerVariant);
    expect(callout.title, 'Danger');
    expect(callout.icon, '!!');
    expect(session.selection?.extent.blockId, 'callout1');
    expect(session.selection?.extent.path, PositionPath.blockText('callout1'));
    expect(session.selection?.extent.offset, 4);
  });

  test('delete selection removes object block between callout boundaries', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            content: <InlineNode>[TextRun(text: 'Keep start')],
          ),
          ImageBlockNode(id: 'img1', assetId: 'a1'),
          CalloutBlockNode(
            id: 'callout2',
            content: <InlineNode>[TextRun(text: 'end kept')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.text(
          blockId: 'callout1',
          blockIndex: 0,
          offset: 4,
        ),
        extent: DocumentPosition.text(
          blockId: 'callout2',
          blockIndex: 2,
          offset: 3,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(session.document.blocks, hasLength(1));
    final callout = session.document.blocks.single as CalloutBlockNode;
    expect(callout.content.map((node) => node.plainText).join(), 'Keep kept');
    expect(callout.id, 'callout1');
    expect(session.selection?.extent.path, PositionPath.blockText('callout1'));
    expect(session.selection?.extent.offset, 4);
  });

  test('delete selection from table cell into later text block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
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
              ],
            ),
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'tail')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 1,
        ),
        extent: DocumentPosition.text(
          blockId: 'p2',
          blockIndex: 1,
          offset: 2,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    final table = session.document.blocks[0] as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.plainText, 'A');
    expect(table.table.cellAt(0, 1)!.plainText, '');
    expect((session.document.blocks[1] as TextBlockNode).plainText, 'il');
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.offset, 1);
  });

  test('delete selection from text block into later table cell', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'head')],
          ),
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
              ],
            ),
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.text(
          blockId: 'p1',
          blockIndex: 0,
          offset: 2,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 1,
          tableRowIndex: 0,
          tableColumnIndex: 1,
          offset: 1,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect((session.document.blocks[0] as TextBlockNode).plainText, 'he');
    final table = session.document.blocks[1] as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.plainText, '');
    expect(table.table.cellAt(0, 1)!.plainText, 'B');
    expect(session.selection?.extent.blockId, 'p1');
    expect(session.selection?.extent.offset, 2);
  });

  test('insert and delete work for code blocks', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', code: 'print();', language: 'dart'),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition(
          blockId: 'c1',
          blockIndex: 0,
          path: PositionPath.blockCode('c1'),
          offset: 6,
        ),
        extent: DocumentPosition(
          blockId: 'c1',
          blockIndex: 0,
          path: PositionPath.blockCode('c1'),
          offset: 6,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const InsertTextCommand("'hi'"));

    expect(session.document.plainText, "print('hi');");
  });

  test('delete backward removes character before collapsed selection', () {
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

    executor.execute(const DeleteBackwardCommand());

    expect(session.document.plainText, 'Hell');
    expect(session.selection?.extent.offset, 4);
  });

  test('delete backward removes character inside callout body', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
      selection: collapsedCalloutSelection('callout1', 0, 5),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteBackwardCommand());

    final block = session.document.blocks.single as CalloutBlockNode;
    expect(block.content.map((node) => node.plainText).join(), 'Hell');
    expect(session.selection?.extent.path, PositionPath.blockText('callout1'));
    expect(session.selection?.extent.offset, 4);
  });

  test('delete backward merges text blocks at block start', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello ')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'world')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p2', 1, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteBackwardCommand());

    expect(session.document.blocks, hasLength(1));
    expect(session.document.plainText, 'Hello world');
    expect(session.selection?.extent.blockId, 'p1');
    expect(session.selection?.extent.offset, 6);
  });

  test('delete backward at text start selects previous image block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          ImageBlockNode(id: 'img1', assetId: 'a1'),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p2', 2, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteBackwardCommand());

    expect(session.document.blocks, hasLength(3));
    expect(session.document.blocks[0].id, 'p1');
    expect(session.document.blocks[1].id, 'img1');
    expect(session.document.blocks[2].id, 'p2');
    expect(session.selection?.start.blockId, 'img1');
    expect(session.selection?.start.path.isBlockObject, isTrue);
    expect(session.selection?.extent.blockIndex, 1);
    expect(session.selection?.start.offset, 0);
    expect(session.selection?.end.offset, 1);
  });

  test('delete backward at text start moves into previous table block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
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
                        content: <InlineNode>[TextRun(text: 'cell')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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

    executor.execute(const DeleteBackwardCommand());

    expect(session.document.blocks, hasLength(2));
    expect(session.document.blocks[0].id, 'table1');
    expect(session.document.blocks[1].id, 'p1');
    expect(session.selection?.extent.blockId, 'table1');
    expect(session.selection?.extent.blockIndex, 0);
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.path.tableRowIndex, 0);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
    expect(session.selection?.extent.offset, 4);
  });

  test('delete backward on empty paragraph after table removes the paragraph',
      () {
    final session = DocumentSession(
      document: const RichTextDocument(
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
                        content: <InlineNode>[TextRun(text: 'cell')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 1, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteBackwardCommand());

    expect(session.document.blocks, hasLength(1));
    expect(session.document.blocks.single.id, 'table1');
    expect(session.selection?.extent.blockId, 'table1');
    expect(session.selection?.extent.blockIndex, 0);
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.offset, 4);
  });

  test('delete backward on empty paragraph after image removes the paragraph',
      () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'img1', assetId: 'a1'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 1, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteBackwardCommand());

    expect(session.document.blocks, hasLength(1));
    expect(session.document.blocks.single.id, 'img1');
    expect(session.selection?.start.blockId, 'img1');
    expect(session.selection?.start.path.isBlockObject, isTrue);
    expect(session.selection?.start.blockIndex, 0);
    expect(session.selection?.start.offset, 0);
    expect(session.selection?.end.offset, 1);
  });

  test('delete backward at text start moves into previous callout body', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            content: <InlineNode>[TextRun(text: 'before')],
          ),
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

    executor.execute(const DeleteBackwardCommand());

    expect(session.document.blocks, hasLength(2));
    expect(session.selection?.extent.blockId, 'callout1');
    expect(session.selection?.extent.path, PositionPath.blockText('callout1'));
    expect(session.selection?.extent.offset, 6);
  });

  test('delete backward removes empty callout before object selection', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'img1', assetId: 'a1'),
          CalloutBlockNode(id: 'callout1', content: <InlineNode>[]),
        ],
      ),
      selection: collapsedCalloutSelection('callout1', 1, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteBackwardCommand());

    expect(session.document.blocks, hasLength(1));
    expect(session.document.blocks.single.id, 'img1');
    expect(session.selection?.start.blockId, 'img1');
    expect(session.selection?.start.path.isBlockObject, isTrue);
  });

  test('delete forward merges code blocks at block end', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', code: 'final a = '),
          CodeBlockNode(id: 'c2', code: '1;'),
        ],
      ),
      selection: collapsedCodeSelection('c1', 0, 10),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteForwardCommand());

    expect(session.document.blocks, hasLength(1));
    expect(session.document.plainText, 'final a = 1;');
    expect(session.selection?.extent.blockId, 'c1');
    expect(session.selection?.extent.offset, 10);
  });

  test('delete forward removes character inside callout body', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
      selection: collapsedCalloutSelection('callout1', 0, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteForwardCommand());

    final block = session.document.blocks.single as CalloutBlockNode;
    expect(block.content.map((node) => node.plainText).join(), 'ello');
    expect(session.selection?.extent.path, PositionPath.blockText('callout1'));
    expect(session.selection?.extent.offset, 0);
  });

  test('delete forward at text end selects next image block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          ImageBlockNode(id: 'img1', assetId: 'a1'),
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

    executor.execute(const DeleteForwardCommand());

    expect(session.document.blocks, hasLength(3));
    expect(session.document.blocks[0].id, 'p1');
    expect(session.document.blocks[1].id, 'img1');
    expect(session.document.blocks[2].id, 'p2');
    expect(session.selection?.start.blockId, 'img1');
    expect(session.selection?.start.path.isBlockObject, isTrue);
    expect(session.selection?.start.blockIndex, 1);
    expect(session.selection?.start.offset, 0);
    expect(session.selection?.end.offset, 1);
  });

  test('delete forward at text end moves into next callout body', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          CalloutBlockNode(
            id: 'callout1',
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 6),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteForwardCommand());

    expect(session.document.blocks, hasLength(2));
    expect(session.selection?.extent.blockId, 'callout1');
    expect(session.selection?.extent.path, PositionPath.blockText('callout1'));
    expect(session.selection?.extent.offset, 0);
  });

  test('delete forward removes empty callout before object selection', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(id: 'callout1', content: <InlineNode>[]),
          ImageBlockNode(id: 'img1', assetId: 'a1'),
        ],
      ),
      selection: collapsedCalloutSelection('callout1', 0, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteForwardCommand());

    expect(session.document.blocks, hasLength(1));
    expect(session.document.blocks.single.id, 'img1');
    expect(session.selection?.start.blockId, 'img1');
    expect(session.selection?.start.path.isBlockObject, isTrue);
  });

  test('delete forward at text end moves into next table block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
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
                        content: <InlineNode>[TextRun(text: 'cell')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 6),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteForwardCommand());

    expect(session.document.blocks, hasLength(2));
    expect(session.document.blocks[0].id, 'p1');
    expect(session.document.blocks[1].id, 'table1');
    expect(session.selection?.extent.blockId, 'table1');
    expect(session.selection?.extent.blockIndex, 1);
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.path.tableRowIndex, 0);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
    expect(session.selection?.extent.offset, 0);
  });

  test('generic text commands edit table cell text', () {
    final session = DocumentSession(
      document: _tableCellDocument('Hello'),
      selection: _collapsedTableCellSelection(5),
    );
    final executor = CommandExecutor(session);

    executor.execute(const InsertTextCommand('!'));

    var cell = _tableCellText(session.document);
    expect(cell.plainText, 'Hello!');
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.offset, 6);

    executor.execute(const DeleteBackwardCommand());

    cell = _tableCellText(session.document);
    expect(cell.plainText, 'Hello');
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.offset, 5);

    executor.execute(const DeleteForwardCommand());
    expect(_tableCellText(session.document).plainText, 'Hello');
  });

  test('delete selection removes table cell range', () {
    final session = DocumentSession(
      document: _tableCellDocument('Hello'),
      selection: DocumentSelection(
        base: _tableCellPosition(1),
        extent: _tableCellPosition(4),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(_tableCellText(session.document).plainText, 'Ho');
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.offset, 1);
  });

  test('delete selection clears table cell range', () {
    final session = DocumentSession(
      document: _tableRangeDocument(),
      selection: _tableRangeSelection(),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    final table = session.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.plainText, '');
    expect(table.table.cellAt(0, 1)!.plainText, '');
    expect(table.table.cellAt(1, 0)!.plainText, '');
    expect(table.table.cellAt(1, 1)!.plainText, '');
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.path.tableRowIndex, 0);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
    expect(session.selection?.extent.offset, 0);
  });

  test('delete all selected content leaves one empty paragraph', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'img1', assetId: 'a1'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'middle')],
          ),
          ImageBlockNode(id: 'img2', assetId: 'a2'),
        ],
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const SelectAllCommand());
    executor.execute(const DeleteSelectionCommand());

    expect(session.document.blocks, hasLength(1));
    final block = session.document.blocks.single;
    expect(block, isA<TextBlockNode>());
    expect((block as TextBlockNode).content, isEmpty);
    expect(block.type, BlockType.paragraph);
    expect(session.selection?.extent.blockIndex, 0);
    expect(session.selection?.extent.path.isBlockText, isTrue);
    expect(session.selection?.extent.offset, 0);
  });

  group('delete object block', () {
    DocumentSelection objectSelection(String blockId, int blockIndex) {
      final start = DocumentPosition(
        blockId: blockId,
        blockIndex: blockIndex,
        path: PositionPath.blockObject(blockId),
        offset: 0,
      );
      final end = DocumentPosition(
        blockId: blockId,
        blockIndex: blockIndex,
        path: PositionPath.blockObject(blockId),
        offset: 1,
      );
      return DocumentSelection(base: start, extent: end);
    }

    test('deleting a selected image lands the caret in the previous block', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'before')],
            ),
            ImageBlockNode(id: 'img1', assetId: 'a1'),
          ],
        ),
        selection: objectSelection('img1', 1),
      );
      final executor = CommandExecutor(session);

      executor.execute(const DeleteSelectionCommand());

      expect(session.document.blocks, hasLength(1));
      expect(session.document.blocks.single, isA<TextBlockNode>());
      expect(session.selection?.extent.blockId, 'p1');
      expect(session.selection?.extent.offset, 6); // end of "before"
      expect(session.canUndo, isTrue);
    });

    test('deleting an image with no previous block lands at the next block',
        () {
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
        selection: objectSelection('img1', 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const DeleteSelectionCommand());

      expect(session.document.blocks, hasLength(1));
      expect(session.selection?.extent.blockId, 'p1');
      expect(session.selection?.extent.offset, 0);
    });

    test('deleting the only image leaves a normalised empty paragraph', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'img1', assetId: 'a1'),
          ],
        ),
        selection: objectSelection('img1', 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const DeleteSelectionCommand());

      // The command re-adds a paragraph so the caret can land in valid text.
      expect(session.document.blocks, hasLength(1));
      expect(session.document.blocks.single, isA<TextBlockNode>());
      expect(session.selection?.extent.blockIndex, 0);
      expect(session.selection?.extent.path.isBlockText, isTrue);
      expect(session.selection?.extent.offset, 0);
    });

    test('deleting a selected divider works', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'x')],
            ),
            DividerBlockNode(id: 'd1'),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'y')],
            ),
          ],
        ),
        selection: objectSelection('d1', 1),
      );
      final executor = CommandExecutor(session);

      executor.execute(const DeleteSelectionCommand());

      expect(session.document.blocks, hasLength(2));
      expect(session.selection?.extent.blockId, 'p1');
      expect(session.selection?.extent.offset, 1);
    });
  });
}

RichTextDocument _tableRangeDocument() {
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

DocumentSelection _tableRangeSelection() {
  return DocumentSelection(
    base: DocumentPosition.tableCell(
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      offset: 0,
    ),
    extent: DocumentPosition.tableCell(
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 1,
      tableColumnIndex: 1,
      offset: 0,
    ),
  );
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
  final position = _tableCellPosition(offset);
  return DocumentSelection(base: position, extent: position);
}

DocumentPosition _tableCellPosition(int offset) {
  return DocumentPosition.tableCell(
    tableBlockId: 'table1',
    blockIndex: 0,
    tableRowIndex: 0,
    tableColumnIndex: 0,
    offset: offset,
  );
}

TextBlockNode _tableCellText(RichTextDocument document) {
  final table = document.blocks.single as TableBlockNode;
  return table.table.cellAt(0, 0)!.blocks.single as TextBlockNode;
}

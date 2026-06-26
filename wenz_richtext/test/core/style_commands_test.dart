import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

const int _fontColor = 0xFF336699;
const int _secondFontColor = 0xFFE91E63;
const int _backgroundColor = 0xFFFFF59D;

void main() {
  test('text color attributes use argb integers and null merge semantics', () {
    const attributes = TextAttributes(color: _fontColor);

    expect(attributes.toJson(), containsPair('color', _fontColor));
    expect(TextAttributes.fromJson(attributes.toJson()).color, _fontColor);
    expect(const TextAttributes().toJson().containsKey('color'), isFalse);

    final merged = const TextAttributes(color: _fontColor).mergeWith(
      const TextAttributes(background: _backgroundColor),
    );
    expect(merged.color, _fontColor);
    expect(merged.background, _backgroundColor);
  });

  test('format text splits run and applies attributes to selected range', () {
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

    executor.execute(
      const FormatTextCommand(attributes: TextAttributes(bold: true)),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.plainText, 'Hello');
    expect(block.content, hasLength(3));
    expect((block.content[1] as TextRun).text, 'ell');
    expect((block.content[1] as TextRun).attributes.bold, isTrue);
    expect(session.canUndo, isTrue);
  });

  test('format text color no-ops for collapsed selection', () {
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
      selection: collapsedTextSelection('p1', 0, 2),
    );
    final executor = CommandExecutor(session);

    final change = executor.execute(
      const FormatTextCommand(attributes: TextAttributes(color: _fontColor)),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(change.isNoop, isTrue);
    expect((block.content.single as TextRun).attributes.color, isNull);
    expect(session.canUndo, isFalse);
  });

  test('format text applies across text blocks', () {
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
      selection: DocumentSelection(
        base: DocumentPosition(
          blockId: 'p1',
          blockIndex: 0,
          path: PositionPath.blockText('p1'),
          offset: 1,
        ),
        extent: DocumentPosition(
          blockId: 'p2',
          blockIndex: 1,
          path: PositionPath.blockText('p2'),
          offset: 2,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const FormatTextCommand(attributes: TextAttributes(italic: true)),
    );

    final first = session.document.blocks[0] as TextBlockNode;
    final second = session.document.blocks[1] as TextBlockNode;
    expect((first.content.last as TextRun).text, 'bc');
    expect((first.content.last as TextRun).attributes.italic, isTrue);
    expect((second.content.first as TextRun).text, 'de');
    expect((second.content.first as TextRun).attributes.italic, isTrue);
  });

  test('format text color spans text blocks and skips object blocks', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abc')],
          ),
          ImageBlockNode(id: 'img', assetId: 'asset', width: 10, height: 10),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'def')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 1),
        extent: DocumentPosition.text(blockId: 'p2', blockIndex: 2, offset: 2),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const FormatTextCommand(attributes: TextAttributes(color: _fontColor)),
    );

    final first = session.document.blocks[0] as TextBlockNode;
    final image = session.document.blocks[1] as ImageBlockNode;
    final second = session.document.blocks[2] as TextBlockNode;
    expect((first.content.last as TextRun).text, 'bc');
    expect((first.content.last as TextRun).attributes.color, _fontColor);
    expect(image.assetId, 'asset');
    expect((second.content.first as TextRun).text, 'de');
    expect((second.content.first as TextRun).attributes.color, _fontColor);
  });

  test('format text color no-ops for object block selection', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'img', assetId: 'asset', width: 10, height: 10),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.object(blockId: 'img', blockIndex: 0),
        extent: DocumentPosition.object(
          blockId: 'img',
          blockIndex: 0,
          offset: 1,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    final change = executor.execute(
      const FormatTextCommand(attributes: TextAttributes(color: _fontColor)),
    );

    expect(change.isNoop, isTrue);
    expect((session.document.blocks.single as ImageBlockNode).assetId, 'asset');
    expect(session.canUndo, isFalse);
  });

  test('format text color no-ops for invalid block selection', () {
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
      selection: const DocumentSelection(
        base: DocumentPosition(
          blockId: 'missing',
          blockIndex: 9,
          path: PositionPath(<Object>['block', 'missing', 'text']),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 'missing',
          blockIndex: 9,
          path: PositionPath(<Object>['block', 'missing', 'text']),
          offset: 4,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    final change = executor.execute(
      const FormatTextCommand(attributes: TextAttributes(color: _fontColor)),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(change.isNoop, isTrue);
    expect((block.content.single as TextRun).text, 'Hello');
    expect((block.content.single as TextRun).attributes.color, isNull);
    expect(session.canUndo, isFalse);
  });

  test('format text color applies inside table cell text', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 't1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'c1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'c1-p1',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Cell')],
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
          tableBlockId: 't1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 1,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 't1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 3,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const FormatTextCommand(attributes: TextAttributes(color: _fontColor)),
    );

    final textBlock = _singleCellTextBlock(session);
    expect(textBlock.plainText, 'Cell');
    expect((textBlock.content[1] as TextRun).text, 'el');
    expect((textBlock.content[1] as TextRun).attributes.color, _fontColor);
  });

  test('controller blocks font color formatting without edit permission', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Read only')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 0, 4),
      permission: WenzEditorPermission.read,
    );

    final change = controller.formatText(
      const TextAttributes(color: _secondFontColor),
    );

    final block = controller.document.blocks.single as TextBlockNode;
    expect(change.isNoop, isTrue);
    expect(change.metadata, containsPair('reason', 'permissionDenied'));
    expect((block.content.single as TextRun).attributes.color, isNull);
    expect(controller.canUndo, isFalse);
  });

  test('clear style resets selected inline attributes only', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(
                text: 'Hello',
                attributes: TextAttributes(
                  color: _fontColor,
                  background: _backgroundColor,
                  bold: true,
                  italic: true,
                ),
              ),
            ],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 1, 4),
    );
    final executor = CommandExecutor(session);

    executor.execute(const ClearStyleCommand());

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.content, hasLength(3));
    expect((block.content.first as TextRun).attributes.bold, isTrue);
    expect((block.content.first as TextRun).attributes.color, _fontColor);
    expect((block.content[1] as TextRun).attributes.isEmpty, isTrue);
    expect((block.content[1] as TextRun).attributes.color, isNull);
    expect((block.content.last as TextRun).attributes.italic, isTrue);
    expect((block.content.last as TextRun).attributes.background,
        _backgroundColor);
  });

  test('set block type converts selected text blocks to heading', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Title')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const SetBlockTypeCommand(type: BlockType.heading, level: 2),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.heading);
    expect(block.attributes.level, 2);
  });

  test('set block type converts selected text blocks to check list item', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Task')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const SetBlockTypeCommand(
        type: BlockType.listItem,
        listType: 'check',
        checked: false,
      ),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.listItem);
    // 'check' is normalised to the canonical 'task' list type.
    expect(block.attributes.listType, 'task');
    expect(block.attributes.checked, isFalse);
  });

  test('set block type supports canonical task list type', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            attributes: BlockAttributes(anchor: 'task-anchor'),
            content: <InlineNode>[TextRun(text: 'Task')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const SetBlockTypeCommand(
        type: BlockType.listItem,
        listType: 'task',
        checked: true,
      ),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.listItem);
    expect(block.attributes.listType, 'task');
    expect(block.attributes.checked, isTrue);
    expect(block.attributes.anchor, 'task-anchor');
  });

  test('set block type can switch an existing list item to unordered', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'li1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'Item')],
          ),
        ],
      ),
      selection: collapsedTextSelection('li1', 0, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(const SetBlockTypeCommand(type: BlockType.listItem));

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.listItem);
    expect(block.attributes.listType, isNull);
    expect(block.attributes.checked, isNull);
  });

  test('set alignment updates non-text block attributes too', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'img', assetId: 'asset', width: 10, height: 10),
        ],
      ),
      selection: const DocumentSelection(
        base: DocumentPosition(
          blockId: 'img',
          blockIndex: 0,
          path: PositionPath(<Object>['block', 'img', 'object']),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 'img',
          blockIndex: 0,
          path: PositionPath(<Object>['block', 'img', 'object']),
          offset: 0,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const SetAlignmentCommand(alignment: 'center'));

    expect(session.document.blocks.single.attributes.alignment, 'center');
  });
}

TextBlockNode _singleCellTextBlock(DocumentSession session) {
  final tableBlock = session.document.blocks.single as TableBlockNode;
  final cell = tableBlock.table.cellAt(0, 0)!;
  return cell.blocks.single as TextBlockNode;
}

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

  test('format text background spans runs and text blocks', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(
                text: 'ab',
                attributes: TextAttributes(color: _fontColor),
              ),
              TextRun(text: 'cd', attributes: TextAttributes(bold: true)),
            ],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ef')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 1),
        extent: DocumentPosition.text(blockId: 'p2', blockIndex: 1, offset: 1),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const FormatTextCommand(
        attributes: TextAttributes(background: _backgroundColor),
      ),
    );

    final first = session.document.blocks[0] as TextBlockNode;
    final second = session.document.blocks[1] as TextBlockNode;
    expect((first.content[1] as TextRun).text, 'b');
    expect((first.content[1] as TextRun).attributes.color, _fontColor);
    expect(
      (first.content[1] as TextRun).attributes.background,
      _backgroundColor,
    );
    expect((first.content[2] as TextRun).text, 'cd');
    expect((first.content[2] as TextRun).attributes.bold, isTrue);
    expect(
      (first.content[2] as TextRun).attributes.background,
      _backgroundColor,
    );
    expect((second.content.first as TextRun).text, 'e');
    expect(
      (second.content.first as TextRun).attributes.background,
      _backgroundColor,
    );
  });

  test('clear text color preserves other inline attributes', () {
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
                  url: 'https://example.com',
                ),
              ),
            ],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 1, 4),
    );
    final executor = CommandExecutor(session);

    executor.execute(const ClearTextColorCommand());

    final block = session.document.blocks.single as TextBlockNode;
    final middle = block.content[1] as TextRun;
    expect(middle.text, 'ell');
    expect(middle.attributes.color, isNull);
    expect(middle.attributes.background, _backgroundColor);
    expect(middle.attributes.bold, isTrue);
    expect(middle.attributes.italic, isTrue);
    expect(middle.attributes.url, 'https://example.com');
    expect((block.content.first as TextRun).attributes.color, _fontColor);
    expect((block.content.last as TextRun).attributes.color, _fontColor);
  });

  test('clear text background preserves other inline attributes', () {
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
                  url: 'https://example.com',
                ),
              ),
            ],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 1, 4),
    );
    final executor = CommandExecutor(session);

    executor.execute(const ClearTextBackgroundCommand());

    final block = session.document.blocks.single as TextBlockNode;
    final middle = block.content[1] as TextRun;
    expect(middle.text, 'ell');
    expect(middle.attributes.background, isNull);
    expect(middle.attributes.color, _fontColor);
    expect(middle.attributes.bold, isTrue);
    expect(middle.attributes.italic, isTrue);
    expect(middle.attributes.url, 'https://example.com');
    expect(
      (block.content.first as TextRun).attributes.background,
      _backgroundColor,
    );
    expect(
      (block.content.last as TextRun).attributes.background,
      _backgroundColor,
    );
  });

  test('clear text background applies inside table cell text', () {
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
                        content: <InlineNode>[
                          TextRun(
                            text: 'Cell',
                            attributes: TextAttributes(
                              color: _fontColor,
                              background: _backgroundColor,
                            ),
                          ),
                        ],
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

    executor.execute(const ClearTextBackgroundCommand());

    final textBlock = _singleCellTextBlock(session);
    final middle = textBlock.content[1] as TextRun;
    expect(middle.text, 'el');
    expect(middle.attributes.background, isNull);
    expect(middle.attributes.color, _fontColor);
    expect(
      (textBlock.content.first as TextRun).attributes.background,
      _backgroundColor,
    );
    expect(
      (textBlock.content.last as TextRun).attributes.background,
      _backgroundColor,
    );
  });

  test('format text color supports undo and redo', () {
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
      const FormatTextCommand(attributes: TextAttributes(color: _fontColor)),
    );
    var block = session.document.blocks.single as TextBlockNode;
    expect((block.content[1] as TextRun).attributes.color, _fontColor);

    expect(session.undo(), isTrue);
    block = session.document.blocks.single as TextBlockNode;
    expect(block.content, hasLength(1));
    expect((block.content.single as TextRun).attributes.color, isNull);

    expect(session.redo(), isTrue);
    block = session.document.blocks.single as TextBlockNode;
    expect((block.content[1] as TextRun).attributes.color, _fontColor);
  });

  test('format text color with same value does not add history', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(
                text: 'Hello',
                attributes: TextAttributes(color: _fontColor),
              ),
            ],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 0, 5),
    );
    final executor = CommandExecutor(session);

    final change = executor.execute(
      const FormatTextCommand(attributes: TextAttributes(color: _fontColor)),
    );

    expect(change.isNoop, isTrue);
    expect(session.history.undoDepth, 0);
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

  test('controller blocks background formatting without edit permission', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(
                text: 'Read only',
                attributes: TextAttributes(background: _backgroundColor),
              ),
            ],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 0, 4),
      permission: WenzEditorPermission.comment,
    );

    final setChange = controller.setTextBackgroundValue(_secondFontColor);
    final clearChange = controller.clearTextBackground();

    final block = controller.document.blocks.single as TextBlockNode;
    expect(setChange.isNoop, isTrue);
    expect(setChange.metadata, containsPair('reason', 'permissionDenied'));
    expect(clearChange.isNoop, isTrue);
    expect(clearChange.metadata, containsPair('reason', 'permissionDenied'));
    expect(
      (block.content.single as TextRun).attributes.background,
      _backgroundColor,
    );
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

  test('set block type supports ordered todo list item', () {
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
        listType: 'ordered',
        checked: true,
      ),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.listItem);
    expect(block.attributes.listType, 'ordered');
    expect(block.attributes.checked, isTrue);
  });

  test('set block type keeps ordered todo state when staying ordered', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'li1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', checked: true),
            content: <InlineNode>[TextRun(text: 'Task')],
          ),
        ],
      ),
      selection: collapsedTextSelection('li1', 0, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const SetBlockTypeCommand(
        type: BlockType.listItem,
        listType: 'ordered',
      ),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.listItem);
    expect(block.attributes.listType, 'ordered');
    expect(block.attributes.checked, isTrue);
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

  test('set quote preserves heading and todo list semantics', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'heading',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 3, anchor: 'h-anchor'),
            content: <InlineNode>[TextRun(text: 'Quoted heading')],
          ),
          TextBlockNode(
            id: 'ordered-todo',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', checked: true),
            content: <InlineNode>[TextRun(text: 'Ordered todo')],
          ),
          TextBlockNode(
            id: 'task',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: false),
            content: <InlineNode>[TextRun(text: 'Task todo')],
          ),
        ],
      ),
      selection: const DocumentSelection(
        base: DocumentPosition(
          blockId: 'heading',
          blockIndex: 0,
          path: PositionPath(<Object>['block', 'heading', 'text']),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 'task',
          blockIndex: 2,
          path: PositionPath(<Object>['block', 'task', 'text']),
          offset: 9,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const SetBlockTypeCommand(type: BlockType.quote));

    final blocks = session.document.blocks.cast<TextBlockNode>().toList();
    expect(blocks[0].type, BlockType.heading);
    expect(blocks[0].attributes.level, 3);
    expect(blocks[0].attributes.anchor, 'h-anchor');
    expect(blocks[0].attributes.isQuoted, isTrue);
    expect(blocks[1].type, BlockType.listItem);
    expect(blocks[1].attributes.listType, 'ordered');
    expect(blocks[1].attributes.checked, isTrue);
    expect(blocks[1].attributes.isQuoted, isTrue);
    expect(blocks[2].type, BlockType.listItem);
    expect(blocks[2].attributes.listType, 'task');
    expect(blocks[2].attributes.checked, isFalse);
    expect(blocks[2].attributes.isQuoted, isTrue);
  });

  test('set block type preserves existing quote attribute', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'quoted-heading',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2, quoted: true),
            content: <InlineNode>[TextRun(text: 'Quoted heading')],
          ),
        ],
      ),
      selection: collapsedTextSelection('quoted-heading', 0, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const SetBlockTypeCommand(
        type: BlockType.listItem,
        listType: 'ordered',
        checked: true,
      ),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.listItem);
    expect(block.attributes.level, isNull);
    expect(block.attributes.listType, 'ordered');
    expect(block.attributes.checked, isTrue);
    expect(block.attributes.isQuoted, isTrue);
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

  test('set alignment clears image block alignment and skips identical values',
      () {
    final selection = DocumentSelection(
      base: DocumentPosition.object(blockId: 'img', blockIndex: 0, offset: 1),
      extent: DocumentPosition.object(blockId: 'img', blockIndex: 0, offset: 1),
    );
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(
            id: 'img',
            assetId: 'asset',
            width: 10,
            height: 10,
            attributes: BlockAttributes(alignment: 'center'),
          ),
        ],
      ),
      selection: selection,
    );
    final executor = CommandExecutor(session);

    final unchanged =
        executor.execute(const SetAlignmentCommand(alignment: 'center'));

    expect(unchanged.isNoop, isTrue);
    expect(session.canUndo, isFalse);
    expect(session.selection, selection);

    final cleared =
        executor.execute(const SetAlignmentCommand(alignment: null));

    expect(cleared.isNoop, isFalse);
    expect(session.document.blocks.single.attributes.alignment, isNull);
    expect(session.selection, selection);
    expect(session.canUndo, isTrue);
  });

  test('set alignment ignores table cell selections', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-text',
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
      selection: DocumentSelection(
        base: DocumentPosition.tableCell(
          tableBlockId: 'table',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 4,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    final change = executor.execute(
      const SetAlignmentCommand(alignment: 'right'),
    );

    final table = session.document.blocks.single as TableBlockNode;
    expect(change.isNoop, isTrue);
    expect(table.attributes.alignment, isNull);
    expect(table.table.cellAt(0, 0)?.alignment, isNull);
    expect(table.table.columnAlignments, isEmpty);
    expect(session.canUndo, isFalse);
  });
}

TextBlockNode _singleCellTextBlock(DocumentSession session) {
  final tableBlock = session.document.blocks.single as TableBlockNode;
  final cell = tableBlock.table.cellAt(0, 0)!;
  return cell.blocks.single as TextBlockNode;
}

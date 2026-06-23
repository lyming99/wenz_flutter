import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  const service = ClipboardService();

  group('ClipboardService.copy', () {
    test('returns null for a collapsed selection', () {
      final doc = _doc('Hello');
      expect(service.copy(doc, collapsedTextSelection('p1', 0, 0)), isNull);
    });

    test('same-block range produces a rich payload with the magic prefix', () {
      final doc = _doc('Hello');
      final sel = textSelection('p1', 0, 1, 4);
      final payload = service.copy(doc, sel);

      expect(payload, isNotNull);
      expect(payload!.startsWith(wenzClipboardPrefix), isTrue);
      // The payload parses back to the selected slice 'ell'.
      expect(service.parse(payload).text, 'ell');
    });

    test('same-block range preserves run attributes on parse', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'He', attributes: TextAttributes(bold: true)),
              TextRun(text: 'llo'),
            ],
          ),
        ],
      );
      final sel = textSelection('p1', 0, 1, 4); // 'ell'
      final payload = service.copy(doc, sel)!;
      final paste = service.parse(payload);

      expect(paste.isRich, isTrue);
      expect(paste.text, 'ell');
      // The slice crosses the bold/plain boundary: 'e' (bold) + 'll' (plain).
      expect(paste.inlineRuns, hasLength(2));
      expect((paste.inlineRuns[0] as TextRun).attributes.bold, isTrue);
      expect((paste.inlineRuns[1] as TextRun).attributes.bold, isNull);
    });

    test('same-block range preserves an inline embed through copy and parse',
        () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'a'),
              InlineEmbed(
                  embedType: 'formula', data: <String, Object?>{'text': 'x^2'}),
              TextRun(text: 'b'),
            ],
          ),
        ],
      );
      // Select the whole run 'a' + embed + 'b' (offsets 0..3).
      final sel = textSelection('p1', 0, 0, 3);
      final payload = service.copy(doc, sel)!;
      final paste = service.parse(payload);

      expect(paste.isRich, isTrue);
      // The embed must survive: a, embed, b — not just 'ab'.
      final embeds = paste.inlineRuns.whereType<InlineEmbed>().toList();
      expect(embeds, hasLength(1));
      expect(embeds.single.embedType, 'formula');
      expect(embeds.single.data['text'], 'x^2');
    });

    test('object block selection produces a blocks payload', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'img1', assetId: 'hero', file: 'hero.png'),
        ],
      );

      final payload = service.copy(doc, objectSelection('img1', 0));
      final paste = service.parse(payload!);

      expect(paste.isBlocks, isTrue);
      expect(paste.blocks, hasLength(1));
      final image = paste.blocks.single as ImageBlockNode;
      expect(image.id, 'img1');
      expect(image.assetId, 'hero');
      expect(image.file, 'hero.png');
    });

    test('cross-block range preserves an inline embed in the trimmed blocks',
        () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'a'),
              InlineEmbed(
                  embedType: 'mention',
                  data: <String, Object?>{'id': 'u1', 'label': 'Ada'}),
              TextRun(text: 'b'),
            ],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'c')],
          ),
        ],
      );
      // From the start of p1 through p2 — the p1 slice includes the embed.
      final sel = DocumentSelection(
        base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 0),
        extent: DocumentPosition.text(blockId: 'p2', blockIndex: 1, offset: 1),
      );
      final payload = service.copy(doc, sel)!;
      final paste = service.parse(payload);

      expect(paste.isBlocks, isTrue);
      final first = paste.blocks.first as TextBlockNode;
      final embeds = first.content.whereType<InlineEmbed>().toList();
      expect(embeds, hasLength(1));
      expect(embeds.single.embedType, 'mention');
      expect(embeds.single.data['label'], 'Ada');
    });

    test('cross-block range produces a rich blocks payload with plain fallback',
        () {
      const doc = RichTextDocument(
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
      );
      final sel = DocumentSelection(
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
      );
      final payload = service.copy(doc, sel);

      expect(payload, isNotNull);
      expect(payload!.startsWith(wenzClipboardPrefix), isTrue);
      // Plain-text view of the payload matches the old behaviour.
      expect(service.parse(payload).text, 'bc\nde');
      // Parsed as a blocks payload carrying the block slice.
      final paste = service.parse(payload);
      expect(paste.isBlocks, isTrue);
      expect(paste.blocks, hasLength(2));
      expect((paste.blocks[0] as TextBlockNode).plainText, 'bc');
      expect((paste.blocks[1] as TextBlockNode).plainText, 'de');
    });

    test('cross-block range preserves inline attributes per block', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'abc', attributes: TextAttributes(bold: true)),
            ],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'def', attributes: TextAttributes(italic: true)),
            ],
          ),
        ],
      );
      final sel = DocumentSelection(
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
      );
      final payload = service.copy(doc, sel)!;
      final paste = service.parse(payload);

      expect(paste.isBlocks, isTrue);
      final firstRun =
          (paste.blocks[0] as TextBlockNode).content.first as TextRun;
      final lastRun =
          (paste.blocks[1] as TextBlockNode).content.first as TextRun;
      expect(firstRun.attributes.bold, isTrue);
      expect(lastRun.attributes.italic, isTrue);
    });

    test('cross-block range preserves block type and attributes', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Title')],
          ),
          TextBlockNode(
            id: 'q1',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'quoted')],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 'h1',
          blockIndex: 0,
          path: PositionPath.blockText('h1'),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 'q1',
          blockIndex: 1,
          path: PositionPath.blockText('q1'),
          offset: 6,
        ),
      );
      final payload = service.copy(doc, sel)!;
      final paste = service.parse(payload);

      expect(paste.isBlocks, isTrue);
      expect((paste.blocks[0] as TextBlockNode).type, BlockType.heading);
      expect((paste.blocks[0] as TextBlockNode).attributes.level, 2);
      expect((paste.blocks[1] as TextBlockNode).type, BlockType.quote);
    });

    test('code block range copies plain text slice', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', code: 'abcdef'),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 'c1',
          blockIndex: 0,
          path: PositionPath.blockCode('c1'),
          offset: 1,
        ),
        extent: DocumentPosition(
          blockId: 'c1',
          blockIndex: 0,
          path: PositionPath.blockCode('c1'),
          offset: 4,
        ),
      );
      expect(service.copy(doc, sel), 'bcd');
    });

    test('table cell range produces a rich payload from the selected cell', () {
      final doc = _tableDoc();
      final payload = service.copy(doc, _tableCellSelection(1, 4));

      expect(payload, isNotNull);
      expect(payload!.startsWith(wenzClipboardPrefix), isTrue);
      expect(service.parse(payload).text, 'ell');
    });

    test('table cell range preserves run attributes on parse', () {
      final doc = _tableDoc();
      final payload = service.copy(doc, _tableCellSelection(0, 4))!;
      final paste = service.parse(payload);

      expect(paste.isRich, isTrue);
      expect(paste.text, 'Hell');
      expect(paste.inlineRuns, hasLength(2));
      expect((paste.inlineRuns[0] as TextRun).attributes.bold, isTrue);
      expect((paste.inlineRuns[1] as TextRun).attributes.bold, isNull);
    });

    test('table cell range copies as TSV plain text', () {
      final doc = _tableRangeDoc();

      expect(service.copy(doc, _tableRangeSelection()), 'AA\tBB\nCC\tDD');
      expect(
          service.copy(doc, _reversedTableRangeSelection()), 'AA\tBB\nCC\tDD');
    });
  });

  group('ClipboardService.parse', () {
    test('rich payload round-trips through parse', () {
      final doc = _doc('Hello');
      final payload = service.copy(doc, textSelection('p1', 0, 0, 5))!;
      final paste = service.parse(payload);

      expect(paste.isRich, isTrue);
      expect(paste.text, 'Hello');
    });

    test('plain text is parsed as plain', () {
      final paste = service.parse('just text');
      expect(paste.isRich, isFalse);
      expect(paste.text, 'just text');
    });

    test('plain text preserves newlines for multi-line paste', () {
      final paste = service.parse('line one\nline two\nline three');
      expect(paste.isRich, isFalse);
      expect(paste.text, 'line one\nline two\nline three');
    });
  });

  group('controller paste integration', () {
    test('paste plain single line inserts at caret', () {
      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );

      controller.pasteText('XY');

      expect(controller.document.plainText, 'aXYb');
      expect(controller.selection?.extent.offset, 3);
    });

    test('paste plain multi-line splits into blocks', () {
      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );

      controller.pasteText('X\nYY\nZ');

      expect(controller.document.blocks, hasLength(3));
      expect(controller.document.plainText, 'aX\nYY\nZb');
    });

    test('paste rich payload preserves attributes', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'bold', attributes: TextAttributes(bold: true)),
            ],
          ),
        ],
      );
      final payload = service.copy(
        source,
        textSelection('p1', 0, 0, 4),
      )!;

      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );
      controller.pasteText(payload);

      final block = controller.document.blocks.single as TextBlockNode;
      final pastedRun = block.content
          .whereType<TextRun>()
          .firstWhere((r) => r.text == 'bold');
      expect(pastedRun.attributes.bold, isTrue);
    });

    test('paste rich payload re-inserts an inline embed', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'src',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'x'),
              InlineEmbed(
                  embedType: 'formula', data: <String, Object?>{'text': 'y'}),
              TextRun(text: 'z'),
            ],
          ),
        ],
      );
      final payload = service.copy(
        source,
        DocumentSelection(
          base: DocumentPosition.text(blockId: 'src', blockIndex: 0, offset: 0),
          extent:
              DocumentPosition.text(blockId: 'src', blockIndex: 0, offset: 3),
        ),
      )!;

      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );
      controller.pasteText(payload);

      final block = controller.document.blocks.single as TextBlockNode;
      final embeds = block.content.whereType<InlineEmbed>().toList();
      expect(embeds, hasLength(1));
      expect(embeds.single.embedType, 'formula');
      expect(embeds.single.data['text'], 'y');
    });

    test('cut deletes the selection and returns the payload', () {
      final controller = WenzRichTextController(
        document: _doc('abcdef'),
        selection: textSelection('p1', 0, 1, 4),
      );

      final payload = controller.cutSelection();

      expect(payload, isNotNull);
      expect(controller.document.plainText, 'aef');
    });

    test('cut deletes a table cell selection and returns its payload', () {
      final controller = WenzRichTextController(
        document: _tableDoc(),
        selection: _tableCellSelection(1, 4),
      );

      final payload = controller.cutSelection();

      expect(payload, isNotNull);
      expect(service.parse(payload!).text, 'ell');
      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.cellAt(0, 0)!.plainText, 'Ho');
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
      expect(controller.selection?.extent.offset, 1);
    });

    test('cut clears a table cell range and returns TSV', () {
      final controller = WenzRichTextController(
        document: _tableRangeDoc(),
        selection: _tableRangeSelection(),
      );

      final payload = controller.cutSelection();

      expect(payload, 'AA\tBB\nCC\tDD');
      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.cellAt(0, 0)!.plainText, '');
      expect(table.table.cellAt(0, 1)!.plainText, '');
      expect(table.table.cellAt(1, 0)!.plainText, '');
      expect(table.table.cellAt(1, 1)!.plainText, '');
      expect(controller.selection?.extent.path.tableRowIndex, 0);
      expect(controller.selection?.extent.path.tableColumnIndex, 0);
    });

    test('paste plain single line inserts into table cell', () {
      final controller = WenzRichTextController(
        document: _tableDoc(),
        selection: _collapsedTableCellSelection(2),
      );

      controller.pasteText('XY');

      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.cellAt(0, 0)!.plainText, 'HeXYllo');
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
      expect(controller.selection?.extent.offset, 4);
    });

    test('paste rich payload preserves attributes inside table cell', () {
      final payload = service.copy(_tableDoc(), _tableCellSelection(0, 2))!;
      final controller = WenzRichTextController(
        document: _plainTableDoc('ab'),
        selection: _collapsedTableCellSelection(1),
      );

      controller.pasteText(payload);

      final table = controller.document.blocks.single as TableBlockNode;
      final cellBlock =
          table.table.cellAt(0, 0)!.blocks.single as TextBlockNode;
      final pastedRun = cellBlock.content
          .whereType<TextRun>()
          .firstWhere((run) => run.text.contains('He'));
      expect(table.table.cellAt(0, 0)!.plainText, 'aHeb');
      expect(pastedRun.text, 'He');
      expect(pastedRun.attributes.bold, isTrue);
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
    });

    test('cross-block copy then paste restores block structure', () {
      // Source: two paragraphs with distinct inline attributes.
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 's1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'bo', attributes: TextAttributes(bold: true)),
              TextRun(text: 'ld'),
            ],
          ),
          TextBlockNode(
            id: 's2',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'it', attributes: TextAttributes(italic: true)),
            ],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 's1',
          blockIndex: 0,
          path: PositionPath.blockText('s1'),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 's2',
          blockIndex: 1,
          path: PositionPath.blockText('s2'),
          offset: 2,
        ),
      );
      final payload = service.copy(source, sel)!;

      // Target: a single paragraph "ab" with the caret between a and b.
      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );
      controller.pasteText(payload);

      // Expectation: "a" + bold+plain merged into block 1, italic in block 2,
      // then trailing "b" merged into the last block.
      expect(controller.document.blocks, hasLength(2));
      final first = controller.document.blocks[0] as TextBlockNode;
      final second = controller.document.blocks[1] as TextBlockNode;
      expect(first.plainText, 'abold');
      expect(second.plainText, 'itb');
      // bold preserved on the 'bo' slice, italic on the 'it' slice.
      final boldRun = first.content.whereType<TextRun>().firstWhere(
            (r) => r.text.contains('bo'),
          );
      expect(boldRun.attributes.bold, isTrue);
      final italicRun = second.content.whereType<TextRun>().firstWhere(
            (r) => r.text.contains('it'),
          );
      expect(italicRun.attributes.italic, isTrue);
    });

    test('cross-block paste into a selection replaces the selection', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 's1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'X')],
          ),
          TextBlockNode(
            id: 's2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Y')],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 's1',
          blockIndex: 0,
          path: PositionPath.blockText('s1'),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 's2',
          blockIndex: 1,
          path: PositionPath.blockText('s2'),
          offset: 1,
        ),
      );
      final payload = service.copy(source, sel)!;

      // Target: "a[BB]c" — selection covers 'BB', caret-equivalent after paste
      // should leave 'a' + X + (new block) Y + 'c'.
      final controller = WenzRichTextController(
        document: _doc('aBBc'),
        selection: textSelection('p1', 0, 1, 3),
      );
      controller.pasteText(payload);

      expect(controller.document.blocks, hasLength(2));
      expect(controller.document.blocks[0].plainText, 'aX');
      expect(controller.document.blocks[1].plainText, 'Yc');
    });

    test('cross-block copy-paste round-trips through cut', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 's1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'hello')],
          ),
          TextBlockNode(
            id: 's2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'world')],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 's1',
          blockIndex: 0,
          path: PositionPath.blockText('s1'),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 's2',
          blockIndex: 1,
          path: PositionPath.blockText('s2'),
          offset: 5,
        ),
      );
      final payload = service.copy(source, sel)!;

      // Cut removes the selected range; the payload still parses as blocks.
      final cutController = WenzRichTextController(
        document: source,
        selection: sel,
      );
      final cutPayload = cutController.cutSelection()!;
      expect(service.parse(cutPayload).isBlocks, isTrue);

      // Pasting elsewhere restores the two blocks.
      final target = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 't1',
              type: BlockType.paragraph,
              content: <InlineNode>[],
            ),
          ],
        ),
        selection: collapsedTextSelection('t1', 0, 0),
      );
      target.pasteText(cutPayload);
      expect(target.document.blocks, hasLength(2));
      expect(target.document.blocks[0].plainText, 'hello');
      expect(target.document.blocks[1].plainText, 'world');
      expect(payload, isNotNull);
    });

    test('paste copied image into text uses a fresh id once', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
          ImageBlockNode(id: 'img1', assetId: 'hero', file: 'hero.png'),
        ],
      );
      final payload = service.copy(source, objectSelection('img1', 1))!;
      final controller = WenzRichTextController(
        document: source,
        selection: collapsedTextSelection('p1', 0, 1),
      );

      controller.pasteText(payload);

      final images = controller.document.blocks.whereType<ImageBlockNode>();
      expect(images, hasLength(2));
      final pastedImage = controller.document.blocks[1] as ImageBlockNode;
      expect(pastedImage.id, isNot('img1'));
      expect(pastedImage.assetId, 'hero');
      expect(controller.document.blocks[3].id, 'img1');
      expect(controller.selection?.extent.path.isBlockText, isTrue);
      expect(
        controller.selection?.extent.blockId,
        controller.document.blocks[2].id,
      );
    });

    test('paste copied image after an object selects the pasted image', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'src-img', assetId: 'hero', file: 'hero.png'),
        ],
      );
      final payload = service.copy(source, objectSelection('src-img', 0))!;
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'target-img', assetId: 'target'),
          ],
        ),
        selection: collapsedObjectSelection('target-img', 0),
      );

      controller.pasteText(payload);

      expect(controller.document.blocks, hasLength(2));
      final pastedImage = controller.document.blocks[1] as ImageBlockNode;
      expect(pastedImage.id, isNot('src-img'));
      expect(controller.selection?.isCollapsed, isFalse);
      expect(controller.selection?.start.blockId, pastedImage.id);
      expect(controller.selection?.start.path.isBlockObject, isTrue);
      expect(controller.selection?.start.offset, 0);
      expect(controller.selection?.end.blockId, pastedImage.id);
      expect(controller.selection?.end.offset, 1);
    });
  });
}

RichTextDocument _doc(String text) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: text)],
      ),
    ],
  );
}

RichTextDocument _tableDoc([String plainTail = 'llo']) {
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
                    content: <InlineNode>[
                      const TextRun(
                        text: 'He',
                        attributes: TextAttributes(bold: true),
                      ),
                      TextRun(text: plainTail),
                    ],
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

RichTextDocument _plainTableDoc(String text) {
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

RichTextDocument _tableRangeDoc() {
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
    base: _tableCellPositionAt(row: 0, column: 0),
    extent: _tableCellPositionAt(row: 1, column: 1),
  );
}

DocumentSelection _reversedTableRangeSelection() {
  return DocumentSelection(
    base: _tableCellPositionAt(row: 1, column: 1),
    extent: _tableCellPositionAt(row: 0, column: 0),
  );
}

DocumentPosition _tableCellPositionAt({required int row, required int column}) {
  return DocumentPosition.tableCell(
    tableBlockId: 'table1',
    blockIndex: 0,
    tableRowIndex: row,
    tableColumnIndex: column,
    offset: 0,
  );
}

DocumentSelection _tableCellSelection(int start, int end) {
  return DocumentSelection(
    base: _tableCellPosition(start),
    extent: _tableCellPosition(end),
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

DocumentSelection collapsedObjectSelection(String blockId, int blockIndex) {
  final position = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(blockId),
    offset: 0,
  );
  return DocumentSelection(base: position, extent: position);
}

DocumentSelection objectSelection(String blockId, int blockIndex) {
  final start = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(blockId),
    offset: 0,
  );
  return DocumentSelection(base: start, extent: start.copyWith(offset: 1));
}

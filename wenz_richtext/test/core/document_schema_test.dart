import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  const schema = DocumentSchema();

  group('DocumentSchema.normalize', () {
    test('empty document gets a paragraph', () {
      const empty = RichTextDocument();
      final normalized = schema.normalize(empty);

      expect(normalized.blocks, hasLength(1));
      expect(normalized.blocks.single, isA<TextBlockNode>());
      expect((normalized.blocks.single as TextBlockNode).type,
          BlockType.paragraph);
    });

    test('heading drops list-specific attributes', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(
              level: 2,
              listType: 'ordered',
              checked: true,
              indent: 1,
              alignment: 'center',
            ),
            content: <InlineNode>[TextRun(text: 'Title')],
          ),
        ],
      );
      final normalized = schema.normalize(doc);
      final block = normalized.blocks.single as TextBlockNode;

      expect(block.attributes.level, 2);
      expect(block.attributes.indent, 1);
      expect(block.attributes.alignment, 'center');
      // list-specific attrs stripped from a heading.
      expect(block.attributes.listType, isNull);
      expect(block.attributes.checked, isNull);
    });

    test('listItem canonicalises listType and clears level', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'li1',
            type: BlockType.listItem,
            attributes: BlockAttributes(
              level: 3,
              listType: 'li',
            ),
            content: <InlineNode>[TextRun(text: 'item')],
          ),
          TextBlockNode(
            id: 'li2',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'oli'),
            content: <InlineNode>[TextRun(text: 'ordered')],
          ),
          TextBlockNode(
            id: 'li3',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'check'),
            content: <InlineNode>[TextRun(text: 'task')],
          ),
        ],
      );
      final normalized = schema.normalize(doc);
      final blocks = normalized.blocks.cast<TextBlockNode>();

      // 'li' -> null (unordered).
      expect(blocks[0].attributes.listType, isNull);
      expect(blocks[0].attributes.level, isNull);
      // 'oli' -> 'ordered'.
      expect(blocks[1].attributes.listType, 'ordered');
      // 'check' -> 'task'.
      expect(blocks[2].attributes.listType, 'task');
    });

    test('paragraph drops level/listType/checked but keeps indent/alignment', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            attributes: BlockAttributes(
              level: 2,
              listType: 'ordered',
              checked: true,
              indent: 2,
              alignment: 'right',
            ),
            content: <InlineNode>[TextRun(text: 'p')],
          ),
        ],
      );
      final block = (schema.normalize(doc).blocks.single as TextBlockNode);

      expect(block.attributes.level, isNull);
      expect(block.attributes.listType, isNull);
      expect(block.attributes.checked, isNull);
      expect(block.attributes.indent, 2);
      expect(block.attributes.alignment, 'right');
    });

    test('table cell with no blocks gets a paragraph', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 't1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(id: 'c1', blocks: <BlockNode>[]),
                ],
              ],
            ),
          ),
        ],
      );
      final table = schema.normalize(doc).blocks.single as TableBlockNode;

      expect(table.table.cellAt(0, 0)!.blocks, hasLength(1));
      expect(
        table.table.cellAt(0, 0)!.blocks.single,
        isA<TextBlockNode>(),
      );
    });

    test('indent is clamped to maxIndent', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            attributes: BlockAttributes(indent: 99),
            content: <InlineNode>[],
          ),
        ],
      );
      final block = (schema.normalize(doc).blocks.single as TextBlockNode);
      expect(block.attributes.indent, 8);
    });

    test('idempotent on an already-normal document', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            attributes: BlockAttributes(indent: 1, alignment: 'center'),
            content: <InlineNode>[TextRun(text: 'hi')],
          ),
        ],
      );
      final once = schema.normalize(doc);
      final twice = schema.normalize(once);

      // Structural equality: normalising a normal doc changes nothing.
      expect(twice.blocks.length, once.blocks.length);
      expect((twice.blocks.single as TextBlockNode).attributes,
          (once.blocks.single as TextBlockNode).attributes);
    });

    test('code/image/divider blocks pass through unchanged', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', code: 'x'),
          DividerBlockNode(id: 'd1'),
        ],
      );
      final normalized = schema.normalize(doc);
      expect(normalized.blocks, hasLength(2));
      expect(normalized.blocks[0], isA<CodeBlockNode>());
      expect(normalized.blocks[1], isA<DividerBlockNode>());
    });
  });
}

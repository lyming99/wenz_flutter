import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  test('finds matches in text, code, and table-cell text', () {
    final editor = WenzRichTextController(document: _document());
    final find = WenzFindReplaceController(editor: editor);
    addTearDown(find.dispose);

    find.setQuery('alpha');

    expect(find.matches, hasLength(4));
    expect(find.currentIndex, 0);
    expect(find.currentMatch?.blockId, 'p1');
    expect(find.currentMatch?.start, 0);
    expect(find.currentMatch?.end, 5);
    expect(editor.selection, find.currentMatch?.selection);

    find.next();
    expect(find.currentIndex, 1);
    expect(find.currentMatch?.start, 11);

    find.previous();
    expect(find.currentIndex, 0);
  });

  test('supports case-sensitive and whole-word matching', () {
    final editor = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Alpha alphabet alpha'),
            ],
          ),
        ],
      ),
    );
    final find = WenzFindReplaceController(editor: editor);
    addTearDown(find.dispose);

    find.setQuery('alpha');
    expect(find.matches, hasLength(3));

    find.setOptions(wholeWord: true);
    expect(find.matches, hasLength(2));

    find.setOptions(caseSensitive: true);
    expect(find.matches, hasLength(1));
    expect(find.currentMatch?.text, 'alpha');
  });

  test('replaces current match and all remaining matches', () {
    final editor = WenzRichTextController(document: _document());
    final find = WenzFindReplaceController(editor: editor);
    addTearDown(find.dispose);

    find
      ..setQuery('beta')
      ..setReplacement('BETA');

    expect(find.replaceCurrent(), isTrue);
    expect((editor.document.blocks[0] as TextBlockNode).plainText,
        'Alpha BETA alpha');

    find.setQuery('alpha');
    final replaced = find.replaceAll('x');

    expect(replaced, 4);
    expect((editor.document.blocks[0] as TextBlockNode).plainText, 'x BETA x');
    expect((editor.document.blocks[1] as CodeBlockNode).code, 'x();');
    final table = editor.document.blocks[2] as TableBlockNode;
    expect(table.table.rows[0][0].plainText, 'beta x');
    expect(find.matches, isEmpty);
  });

  test('reveals collapsed outline range before selecting hidden match', () {
    final editor = WenzRichTextController(document: _foldedDocument());
    final outline = WenzOutlineController(editor: editor);
    final find = WenzFindReplaceController(
      editor: editor,
      outlineController: outline,
    );
    addTearDown(find.dispose);
    addTearDown(outline.dispose);

    expect(outline.collapseByBlockId('h1'), isTrue);
    expect(outline.isBlockHidden('p1'), isTrue);

    find.setQuery('needle');

    expect(find.currentMatch?.blockId, 'p1');
    expect(editor.selection, find.currentMatch?.selection);
    expect(outline.isCollapsed('h1'), isFalse);
    expect(outline.isBlockHidden('p1'), isFalse);
  });
}

RichTextDocument _document() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(text: 'Alpha beta alpha'),
        ],
      ),
      CodeBlockNode(id: 'c1', code: 'ALPHA();'),
      TableBlockNode(
        id: 't1',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'cell-1',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-p1',
                    type: BlockType.paragraph,
                    content: <InlineNode>[
                      TextRun(text: 'beta alpha'),
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

RichTextDocument _foldedDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'h1',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Chapter')],
      ),
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'hidden needle')],
      ),
      TextBlockNode(
        id: 'h2',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Next')],
      ),
    ],
  );
}

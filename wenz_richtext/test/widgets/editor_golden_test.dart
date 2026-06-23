import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

const _goldenKey = ValueKey<String>('editor-golden-surface');

void main() {
  testWidgets('golden: paragraph code and image placeholder', (tester) async {
    await _pumpGoldenEditor(
      tester,
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'title',
              type: BlockType.heading,
              attributes: BlockAttributes(level: 2),
              content: <InlineNode>[
                TextRun(
                  text: 'Release checklist',
                  attributes: TextAttributes(bold: true),
                ),
              ],
            ),
            TextBlockNode(
              id: 'body',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Paragraph rendering with inline text.'),
              ],
            ),
            CodeBlockNode(
              id: 'code',
              language: 'dart',
              code: 'final ready = true;',
            ),
            ImageBlockNode(id: 'image', assetId: 'hero', file: 'hero.png'),
          ],
        ),
      ),
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_blocks.png'),
    );
  });

  testWidgets('golden: merged table cell visual span', (tester) async {
    await _pumpGoldenEditor(
      tester,
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'table',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'a',
                      rowSpan: 2,
                      columnSpan: 2,
                      backgroundColor: 0xFFEAF4FF,
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'a-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Merged 2 x 2'),
                          ],
                        ),
                      ],
                    ),
                    TableCellNode(id: 'b', covered: true),
                    TableCellNode(
                      id: 'c',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'c-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Right')],
                        ),
                      ],
                    ),
                  ],
                  <TableCellNode>[
                    TableCellNode(id: 'd', covered: true),
                    TableCellNode(id: 'e', covered: true),
                    TableCellNode(
                      id: 'f',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'f-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Bottom')],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_merged_table.png'),
    );
  });

  testWidgets('golden: selection highlight', (tester) async {
    await _pumpGoldenEditor(
      tester,
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Selected words stay highlighted.'),
              ],
            ),
          ],
        ),
        selection: textSelection('p1', 0, 0, 14),
      ),
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_selection.png'),
    );
  });

  testWidgets('golden: collapsed caret', (tester) async {
    await _pumpGoldenEditor(
      tester,
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Caret is visible here.'),
              ],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 8),
      ),
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_caret.png'),
    );
  });
}

Future<void> _pumpGoldenEditor(
  WidgetTester tester,
  WenzRichTextController controller,
) async {
  const size = Size(520, 320);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: _goldenKey,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

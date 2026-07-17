import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  group('DocumentStats', () {
    test('derives words characters embeds and reading time', () {
      final stats = DocumentStats.fromDocument(
        _richDocument(),
        readingWordsPerMinute: 10,
      );

      expect(stats.blockCount, 7);
      expect(stats.paragraphCount, 2);
      expect(stats.headingCount, 0);
      expect(stats.imageCount, 1);
      expect(stats.wordCount, 20);
      expect(stats.characterCount, 79);
      expect(stats.characterCountExcludingWhitespace, 69);
      expect(stats.inlineEmbedCount, 3);
      expect(stats.readingTimeMinutes, 2);
      expect(stats.readingTime, const Duration(minutes: 2));
    });

    test('tracks host document changes without selection-only notifications',
        () {
      final host = WenzRichTextController(
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
      final stats = WenzDocumentStatsController(
        editor: host,
        readingWordsPerMinute: 1,
      );
      var notifications = 0;
      stats.addListener(() => notifications++);
      expect(stats.recomputedBlockCount, 1);

      host.setSelection(collapsedTextSelection('p1', 0, 1));

      expect(notifications, 0);
      expect(stats.wordCount, 1);
      expect(stats.recomputedBlockCount, 1);

      host.insertText(' there');

      expect(notifications, 1);
      expect(stats.wordCount, 2);
      expect(stats.characterCount, 8);
      expect(stats.readingTimeMinutes, 2);
      expect(stats.recomputedBlockCount, 2);

      stats.dispose();
      host.dispose();
    });
  });
}

RichTextDocument _richDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(text: 'Hello 世界 '),
          InlineEmbed(
            embedType: 'formula',
            data: <String, Object?>{'text': 'E=mc^2'},
          ),
          TextRun(text: ' '),
          InlineEmbed(
            embedType: 'mention',
            data: <String, Object?>{'id': 'u1', 'label': 'Ada'},
          ),
          TextRun(text: ' '),
          InlineEmbed(
            embedType: 'emoji',
            data: <String, Object?>{'emoji': '😀'},
          ),
        ],
      ),
      CodeBlockNode(
        id: 'code',
        code: 'final count = 1;',
      ),
      CalloutBlockNode(
        id: 'callout',
        title: 'Note',
        content: <InlineNode>[TextRun(text: '看看 details')],
      ),
      TableBlockNode(
        id: 'table',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'cell-1',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-1-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'Cell text')],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      ImageBlockNode(
        id: 'image',
        assetId: 'image-1',
        caption: 'Figure 一',
      ),
      FileBlockNode(
        id: 'file',
        assetId: 'file-1',
        name: 'report.pdf',
      ),
      DividerBlockNode(id: 'divider'),
    ],
  );
}

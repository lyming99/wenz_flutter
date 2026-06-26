import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('WenzOutlineController', () {
    test('derives outline items from non-empty headings', () {
      final host = WenzRichTextController(document: _doc());
      final outline = WenzOutlineController(editor: host);

      expect(outline.items, hasLength(2));
      expect(outline.items[0].blockId, 'h1');
      expect(outline.items[0].blockIndex, 0);
      expect(outline.items[0].level, 1);
      expect(outline.items[0].title, 'Intro');
      expect(outline.items[0].anchor, 'intro');
      expect(outline.items[0].target, 'intro');
      expect(outline.items[1].blockId, 'h2');
      expect(outline.items[1].level, 2);
      expect(outline.items[1].target, 'h2');

      outline.dispose();
      host.dispose();
    });

    test('computes collapse ranges from heading levels', () {
      final host = WenzRichTextController(document: _foldingDoc());
      final outline = WenzOutlineController(editor: host);

      final chapter = outline.itemForBlockId('h1')!;
      expect(chapter.canCollapse, isTrue);
      expect(chapter.isCollapsed, isFalse);
      expect(chapter.coveredBlockCount, 6);
      expect(chapter.hiddenBlockCount, 0);
      expect(chapter.collapseStartBlockIndex, 1);
      expect(chapter.collapseEndBlockIndexExclusive, 7);
      expect(
        chapter.coveredBlockIds,
        <String>['p1', 'h2', 'p2', 'h3', 'p3', 'h2b'],
      );
      expect(chapter.coveredBlockIndexes, <int>[1, 2, 3, 4, 5, 6]);

      final section = outline.itemForBlockId('h2')!;
      expect(section.canCollapse, isTrue);
      expect(section.coveredBlockIds, <String>['p2', 'h3', 'p3']);
      expect(section.collapseRange.endBlockIndex, 5);

      final leaf = outline.itemForBlockId('h2b')!;
      expect(leaf.canCollapse, isFalse);
      expect(leaf.coveredBlockCount, 0);
      expect(leaf.hiddenBlockCount, 0);
      expect(leaf.coveredBlockIds, isEmpty);
      expect(leaf.collapseRange.endBlockIndex, isNull);

      outline.dispose();
      host.dispose();
    });

    test('exposes read-only collapse state and hidden counts', () {
      final host = WenzRichTextController(document: _foldingDoc());
      final outline = WenzOutlineController(editor: host);

      final initial = outline.collapseStateForBlockId('h2')!;
      expect(initial.canCollapse, isTrue);
      expect(initial.isCollapsed, isFalse);
      expect(initial.coveredBlockIds, <String>['p2', 'h3', 'p3']);
      expect(initial.coveredBlockIndexes, <int>[3, 4, 5]);
      expect(initial.coveredBlockCount, 3);
      expect(initial.hiddenBlockCount, 0);
      expect(outline.hiddenBlockCount, 0);

      expect(outline.collapseByAnchor('section'), isTrue);

      final collapsed = outline.collapseStateForAnchor('section')!;
      expect(collapsed.isCollapsed, isTrue);
      expect(collapsed.hiddenBlockCount, 3);
      expect(outline.itemForBlockId('h2')?.hiddenBlockCount, 3);
      expect(outline.hiddenBlockCount, 3);
      expect(outline.collapseStateForBlockId('missing'), isNull);

      outline.dispose();
      host.dispose();
    });

    test('handles H1-H6 nested consecutive empty and leaf headings', () {
      final host = WenzRichTextController(document: _headingEdgeDoc());
      final outline = WenzOutlineController(editor: host);

      expect(
        outline.items.map((item) => '${item.blockId}:${item.level}'),
        <String>[
          'h1:1',
          'h2:2',
          'h3:3',
          'h4:4',
          'h5:5',
          'h6:6',
          'h6-leaf:6',
          'h1-tail:1',
        ],
      );
      expect(outline.itemForBlockId('empty-h2'), isNull);

      final root = outline.itemForBlockId('h1')!;
      expect(
        root.coveredBlockIds,
        <String>[
          'h2',
          'h3',
          'h4',
          'h5',
          'h6',
          'p6',
          'h6-leaf',
          'empty-h2',
          'p-empty',
        ],
      );

      final consecutive = outline.itemForBlockId('h2')!;
      expect(
        consecutive.coveredBlockIds,
        <String>['h3', 'h4', 'h5', 'h6', 'p6', 'h6-leaf'],
      );
      expect(outline.itemForBlockId('h6')?.coveredBlockIds, <String>['p6']);
      expect(outline.itemForBlockId('h6-leaf')?.canCollapse, isFalse);
      expect(outline.itemForBlockId('h1-tail')?.canCollapse, isFalse);

      expect(outline.collapseByBlockId('h1'), isTrue);
      expect(
        outline.visibleBlockProjection().visibleBlocks.map((block) => block.id),
        <String>['h1', 'h1-tail'],
      );

      outline.dispose();
      host.dispose();
    });

    test('recomputes ranges after heading delete level change and move', () {
      final host = WenzRichTextController(document: _foldingDoc());
      final outline = WenzOutlineController(editor: host);

      expect(outline.collapseByBlockId('h2'), isTrue);

      host.replaceBlocks(index: 2, deleteCount: 1, blocks: const <BlockNode>[]);

      expect(outline.itemForBlockId('h2'), isNull);
      expect(outline.collapsedBlockIds, isEmpty);
      expect(
        outline.itemForBlockId('h1')?.coveredBlockIds,
        <String>['p1', 'p2', 'h3', 'p3', 'h2b'],
      );

      host.replaceBlocks(
        index: 3,
        deleteCount: 1,
        blocks: const <BlockNode>[
          TextBlockNode(
            id: 'h3',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1),
            content: <InlineNode>[TextRun(text: 'Nested')],
          ),
        ],
      );

      expect(outline.itemForBlockId('h3')?.level, 1);
      expect(outline.itemForBlockId('h1')?.coveredBlockIds, <String>[
        'p1',
        'p2',
      ]);
      expect(outline.itemForBlockId('h3')?.coveredBlockIds, <String>[
        'p3',
        'h2b',
      ]);

      host.moveBlock(fromIndex: 5, toIndex: 3);

      expect(
        host.document.blocks.map((block) => block.id),
        <String>['h1', 'p1', 'p2', 'h2b', 'h3', 'p3', 'h1b'],
      );
      expect(outline.itemForBlockId('h1')?.coveredBlockIds, <String>[
        'p1',
        'p2',
        'h2b',
      ]);
      expect(outline.itemForBlockId('h2b')?.canCollapse, isFalse);
      expect(outline.itemForBlockId('h3')?.coveredBlockIds, <String>['p3']);

      outline.dispose();
      host.dispose();
    });

    test('collapses expands toggles and keeps document unchanged', () {
      final host = WenzRichTextController(document: _foldingDoc());
      final outline = WenzOutlineController(editor: host);
      final beforeJson = host.toJson();
      var notifications = 0;
      outline.addListener(() => notifications++);

      expect(outline.collapseByBlockId('h1'), isTrue);
      expect(outline.isCollapsed('h1'), isTrue);
      expect(outline.itemForBlockId('h1')?.isCollapsed, isTrue);
      expect(outline.collapsedBlockIds, <String>{'h1'});

      expect(outline.collapseByBlockId('h1'), isFalse);
      expect(outline.expandByAnchor('chapter'), isTrue);
      expect(outline.isCollapsedByAnchor('chapter'), isFalse);

      final section = outline.itemForBlockId('h2')!;
      expect(outline.toggle(section), isTrue);
      expect(outline.isCollapsedItem(section), isTrue);
      expect(outline.expandAll(), isTrue);
      expect(outline.collapsedBlockIds, isEmpty);

      expect(host.toJson(), beforeJson);
      expect(host.canUndo, isFalse);
      expect(notifications, 4);

      outline.dispose();
      host.dispose();
    });

    test('projects visible blocks without changing document indexes', () {
      final host = WenzRichTextController(document: _foldingDoc());
      final outline = WenzOutlineController(editor: host);
      final beforeJson = host.toJson();

      expect(outline.collapseByBlockId('h2'), isTrue);

      final projection = outline.visibleBlockProjection();
      expect(
        projection.visibleBlocks.map((block) => block.id),
        <String>['h1', 'p1', 'h2', 'h2b', 'h1b'],
      );
      expect(projection.visibleBlockIndexes, <int>[0, 1, 2, 6, 7]);
      expect(projection.hiddenBlockIds, <String>{'p2', 'h3', 'p3'});
      expect(projection.hiddenBlockIndexes, <int>{3, 4, 5});
      expect(outline.hiddenBlockIds, <String>{'p2', 'h3', 'p3'});
      expect(outline.isBlockHidden('p2'), isTrue);
      expect(outline.isBlockIndexHidden(3), isTrue);
      expect(projection.visibleIndexForBlockIndex(2), 2);
      expect(projection.visibleIndexForBlockIndex(3), isNull);
      expect(projection.nearestVisibleIndexForBlockIndex(5), 2);
      expect(host.toJson(), beforeJson);
      expect(host.canUndo, isFalse);

      outline.dispose();
      host.dispose();
    });

    test('keeps nested child collapse after parent expands', () {
      final host = WenzRichTextController(document: _foldingDoc());
      final outline = WenzOutlineController(editor: host);

      expect(outline.collapseByBlockId('h2'), isTrue);
      expect(outline.collapseByBlockId('h1'), isTrue);

      final parentCollapsed = outline.visibleBlockProjection();
      expect(
        parentCollapsed.visibleBlocks.map((block) => block.id),
        <String>['h1', 'h1b'],
      );
      expect(
        parentCollapsed.hiddenBlockIds,
        <String>{'p1', 'h2', 'p2', 'h3', 'p3', 'h2b'},
      );
      expect(outline.isCollapsed('h2'), isTrue);

      expect(outline.expandByBlockId('h1'), isTrue);

      final parentExpanded = outline.visibleBlockProjection();
      expect(
        parentExpanded.visibleBlocks.map((block) => block.id),
        <String>['h1', 'p1', 'h2', 'h2b', 'h1b'],
      );
      expect(parentExpanded.hiddenBlockIds, <String>{'p2', 'h3', 'p3'});
      expect(outline.isCollapsed('h2'), isTrue);

      outline.dispose();
      host.dispose();
    });

    test('recomputes first and tail heading ranges after dynamic edits', () {
      final host = WenzRichTextController(document: _dynamicBoundaryDoc());
      final outline = WenzOutlineController(editor: host);

      expect(outline.itemForBlockId('start')?.coveredBlockIds, <String>[
        'child',
        'child-body',
      ]);
      expect(outline.itemForBlockId('tail')?.canCollapse, isFalse);
      expect(outline.collapseByBlockId('start'), isTrue);

      host.replaceBlocks(
        index: 4,
        deleteCount: 0,
        blocks: const <BlockNode>[
          TextBlockNode(
            id: 'tail-body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Tail body')],
          ),
        ],
      );

      expect(outline.isCollapsed('start'), isTrue);
      expect(outline.itemForBlockId('tail')?.coveredBlockIds, <String>[
        'tail-body',
      ]);
      expect(outline.collapseByBlockId('tail'), isTrue);

      host.replaceBlocks(
        index: 1,
        deleteCount: 0,
        blocks: const <BlockNode>[
          TextBlockNode(
            id: 'intro-body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Inserted intro')],
          ),
        ],
      );

      expect(outline.itemForBlockId('start')?.coveredBlockIds, <String>[
        'intro-body',
        'child',
        'child-body',
      ]);
      expect(
        outline.visibleBlockProjection().visibleBlocks.map((block) => block.id),
        <String>['start', 'tail'],
      );
      expect(outline.hiddenBlockIds, <String>{
        'intro-body',
        'child',
        'child-body',
        'tail-body',
      });

      host.replaceBlocks(index: 5, deleteCount: 1, blocks: const <BlockNode>[]);

      expect(outline.itemForBlockId('tail')?.canCollapse, isFalse);
      expect(outline.isCollapsed('tail'), isFalse);
      expect(outline.collapsedBlockIds, <String>{'start'});

      outline.dispose();
      host.dispose();
    });

    test('collapse API safely no-ops for invalid targets', () {
      final host = WenzRichTextController(document: _foldingDoc());
      final outline = WenzOutlineController(editor: host);

      expect(outline.collapseByBlockId('missing'), isFalse);
      expect(outline.collapseByBlockId('p1'), isFalse);
      expect(outline.toggleByBlockId('h2b'), isFalse);
      expect(outline.collapseByAnchor('missing'), isFalse);
      expect(outline.expandAll(), isFalse);
      expect(outline.collapsedBlockIds, isEmpty);

      outline.dispose();
      host.dispose();
    });

    test('cleans invalid collapse state after document changes', () {
      final host = WenzRichTextController(document: _foldingDoc());
      final outline = WenzOutlineController(editor: host);

      expect(outline.collapseByBlockId('h2'), isTrue);
      var notifications = 0;
      outline.addListener(() => notifications++);

      host.replaceBlocks(
        index: 2,
        deleteCount: 1,
        blocks: const <BlockNode>[
          TextBlockNode(
            id: 'h2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'No longer heading')],
          ),
        ],
      );

      expect(outline.itemForBlockId('h2'), isNull);
      expect(outline.isCollapsed('h2'), isFalse);
      expect(outline.collapsedBlockIds, isEmpty);
      expect(notifications, 1);

      outline.dispose();
      host.dispose();
    });

    test('updates when a heading anchor changes', () {
      final host = WenzRichTextController(document: _doc());
      final outline = WenzOutlineController(editor: host);
      var notifications = 0;
      outline.addListener(() => notifications++);

      host.setBlockAnchor(blockIndex: 2, anchor: 'details');

      expect(notifications, 1);
      expect(outline.itemForBlockId('h2')?.anchor, 'details');
      expect(outline.itemForAnchor('details')?.blockId, 'h2');

      outline.dispose();
      host.dispose();
    });

    test('selectByAnchor moves host selection to heading start', () {
      final host = WenzRichTextController(document: _doc());
      final outline = WenzOutlineController(editor: host);

      final selected = outline.selectByAnchor('intro', requestFocus: false);

      expect(selected, isTrue);
      expect(host.selection?.extent.blockId, 'h1');
      expect(host.selection?.extent.blockIndex, 0);
      expect(host.selection?.extent.offset, 0);
      expect(host.selection?.extent.path.isBlockText, isTrue);

      outline.dispose();
      host.dispose();
    });

    test('selectByBlockId returns false for non-heading blocks', () {
      final host = WenzRichTextController(document: _doc());
      final outline = WenzOutlineController(editor: host);

      expect(outline.selectByBlockId('p1', requestFocus: false), isFalse);
      expect(host.selection, isNull);

      outline.dispose();
      host.dispose();
    });
  });
}

RichTextDocument _doc() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'h1',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1, anchor: 'intro'),
        content: <InlineNode>[TextRun(text: 'Intro')],
      ),
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Body')],
      ),
      TextBlockNode(
        id: 'h2',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 2),
        content: <InlineNode>[TextRun(text: 'Details')],
      ),
      TextBlockNode(
        id: 'empty-heading',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 3),
        content: <InlineNode>[],
      ),
    ],
  );
}

RichTextDocument _foldingDoc() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'h1',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1, anchor: 'chapter'),
        content: <InlineNode>[TextRun(text: 'Chapter')],
      ),
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Intro body')],
      ),
      TextBlockNode(
        id: 'h2',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 2, anchor: 'section'),
        content: <InlineNode>[TextRun(text: 'Section')],
      ),
      TextBlockNode(
        id: 'p2',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Section body')],
      ),
      TextBlockNode(
        id: 'h3',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 3),
        content: <InlineNode>[TextRun(text: 'Nested')],
      ),
      TextBlockNode(
        id: 'p3',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Nested body')],
      ),
      TextBlockNode(
        id: 'h2b',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 2),
        content: <InlineNode>[TextRun(text: 'Next section')],
      ),
      TextBlockNode(
        id: 'h1b',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Next chapter')],
      ),
    ],
  );
}

RichTextDocument _headingEdgeDoc() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'h1',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Root')],
      ),
      TextBlockNode(
        id: 'h2',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 2),
        content: <InlineNode>[TextRun(text: 'Consecutive section')],
      ),
      TextBlockNode(
        id: 'h3',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 3),
        content: <InlineNode>[TextRun(text: 'Level 3')],
      ),
      TextBlockNode(
        id: 'h4',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 4),
        content: <InlineNode>[TextRun(text: 'Level 4')],
      ),
      TextBlockNode(
        id: 'h5',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 5),
        content: <InlineNode>[TextRun(text: 'Level 5')],
      ),
      TextBlockNode(
        id: 'h6',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 6),
        content: <InlineNode>[TextRun(text: 'Level 6')],
      ),
      TextBlockNode(
        id: 'p6',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Deep body')],
      ),
      TextBlockNode(
        id: 'h6-leaf',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 6),
        content: <InlineNode>[TextRun(text: 'Leaf')],
      ),
      TextBlockNode(
        id: 'empty-h2',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 2),
        content: <InlineNode>[],
      ),
      TextBlockNode(
        id: 'p-empty',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Body after empty heading')],
      ),
      TextBlockNode(
        id: 'h1-tail',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Tail')],
      ),
    ],
  );
}

RichTextDocument _dynamicBoundaryDoc() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'start',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Start')],
      ),
      TextBlockNode(
        id: 'child',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 2),
        content: <InlineNode>[TextRun(text: 'Child')],
      ),
      TextBlockNode(
        id: 'child-body',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Child body')],
      ),
      TextBlockNode(
        id: 'tail',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Tail')],
      ),
    ],
  );
}

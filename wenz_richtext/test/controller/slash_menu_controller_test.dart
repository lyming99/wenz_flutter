import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('opens only for editable collapsed text slash triggers', () {
    final cases = <_SlashTriggerCase>[
      _SlashTriggerCase(
        description: 'plain text slash at block start opens',
        editor: WenzRichTextController(
          document: _document('/'),
          selection: collapsedTextSelection('p1', 0, 1),
        ),
        isOpen: true,
      ),
      _SlashTriggerCase(
        description: 'slash after whitespace opens',
        editor: WenzRichTextController(
          document: _document('hello /hea'),
          selection: collapsedTextSelection('p1', 0, 10),
        ),
        isOpen: true,
      ),
      _SlashTriggerCase(
        description: 'slash inside a word is ignored',
        editor: WenzRichTextController(
          document: _document('hello/hea'),
          selection: collapsedTextSelection('p1', 0, 9),
        ),
      ),
      _SlashTriggerCase(
        description: 'expanded cross-block selection is ignored',
        editor: WenzRichTextController(
          document: _twoParagraphDocument('/hea', 'next'),
          selection: DocumentSelection(
            base: DocumentPosition.text(
              blockId: 'p1',
              blockIndex: 0,
              offset: 1,
            ),
            extent: DocumentPosition.text(
              blockId: 'p2',
              blockIndex: 1,
              offset: 1,
            ),
          ),
        ),
      ),
      _SlashTriggerCase(
        description: 'code block selection is ignored',
        editor: WenzRichTextController(
          document: _codeDocument('/hea'),
          selection: collapsedCodeSelection('code1', 0, 4),
        ),
      ),
      _SlashTriggerCase(
        description: 'object block selection is ignored',
        editor: WenzRichTextController(
          document: _imageDocument(),
          selection: _objectSelection('img1', 0),
        ),
      ),
      _SlashTriggerCase(
        description: 'table cell selection is ignored',
        editor: WenzRichTextController(
          document: _tableDocument('/hea'),
          selection: _tableCellSelection(offset: 4),
        ),
      ),
      _SlashTriggerCase(
        description: 'table object selection is ignored',
        editor: WenzRichTextController(
          document: _tableDocument('/hea'),
          selection: _objectSelection('table1', 0),
        ),
      ),
      _SlashTriggerCase(
        description: 'read permission is ignored',
        editor: WenzRichTextController(
          document: _document('/hea'),
          selection: collapsedTextSelection('p1', 0, 4),
          permission: WenzEditorPermission.read,
        ),
      ),
    ];

    for (final testCase in cases) {
      final slash = SlashMenuController(editor: testCase.editor);
      addTearDown(slash.dispose);

      expect(slash.isOpen, testCase.isOpen, reason: testCase.description);
    }
  });

  test('detects slash query and filters registry items', () {
    final editor = WenzRichTextController(
      document: _document('/hea'),
      selection: collapsedTextSelection('p1', 0, 4),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.isOpen, isTrue);
    expect(slash.query, 'hea');
    expect(slash.items.map((item) => item.id), contains('heading'));
    expect(slash.items.every((item) => item.matches('hea')), isTrue);
  });

  test('detects empty paragraph paragraph-start and unicode-space triggers', () {
    final cases = <_SlashTriggerCase>[
      _SlashTriggerCase(
        description: 'empty paragraph receives slash',
        editor: WenzRichTextController(
          document: _document(''),
          selection: collapsedTextSelection('p1', 0, 0),
        )..insertText('/'),
        isOpen: true,
      ),
      _SlashTriggerCase(
        description: 'paragraph start receives slash before existing text',
        editor: WenzRichTextController(
          document: _document('body'),
          selection: collapsedTextSelection('p1', 0, 0),
        )..insertText('/'),
        isOpen: true,
      ),
      _SlashTriggerCase(
        description: 'full-width space is a command boundary',
        editor: WenzRichTextController(
          document: _document('intro\u3000/'),
          selection: collapsedTextSelection('p1', 0, 7),
        ),
        isOpen: true,
      ),
    ];

    for (final testCase in cases) {
      final slash = SlashMenuController(editor: testCase.editor);
      addTearDown(slash.dispose);

      expect(slash.isOpen, testCase.isOpen, reason: testCase.description);
      expect(slash.query, isEmpty, reason: testCase.description);
      expect(slash.trigger?.end, testCase.editor.selection?.extent.offset,
          reason: testCase.description);
    }
  });

  test('updates query and filtered items while typing table command', () {
    final editor = WenzRichTextController(
      document: _document('/'),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.isOpen, isTrue);
    expect(slash.query, isEmpty);

    editor.insertText('t');
    expect(slash.query, 't');
    expect(slash.items.map((item) => item.id), contains('table'));

    editor.insertText('able');
    expect(slash.query, 'table');
    expect(slash.items.map((item) => item.id), contains('table'));
    expect(slash.items.every((item) => item.matches('table')), isTrue);
  });

  test('refreshes from editor document changes after slash input', () {
    final editor = WenzRichTextController(
      document: _document(''),
      selection: collapsedTextSelection('p1', 0, 0),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.trigger, isNull);
    expect(slash.isOpen, isFalse);

    editor.insertText('/');
    expect(slash.trigger?.blockId, 'p1');
    expect(slash.trigger?.blockIndex, 0);
    expect(slash.trigger?.start, 0);
    expect(slash.trigger?.end, 1);
    expect(slash.query, isEmpty);
    expect(slash.items, isNotEmpty);
    expect(slash.isOpen, isTrue);

    editor.insertText('hea');
    expect(slash.trigger?.start, 0);
    expect(slash.trigger?.end, 4);
    expect(slash.query, 'hea');
    expect(slash.items.map((item) => item.id), contains('heading'));
    expect(slash.isOpen, isTrue);
  });

  test('reports each closed slash-menu state in the refresh chain', () {
    final editor = WenzRichTextController(
      document: _document('/'),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.trigger, isNotNull);
    expect(slash.items, isNotEmpty);
    expect(slash.isOpen, isTrue);

    slash.close();
    expect(slash.trigger, isNotNull);
    expect(slash.items, isNotEmpty);
    expect(slash.isOpen, isFalse);

    editor.replaceDocument(
      _document('/no-such-item'),
      selection: collapsedTextSelection('p1', 0, 13),
    );
    expect(slash.trigger, isNotNull);
    expect(slash.items, isEmpty);
    expect(slash.isOpen, isFalse);

    editor.replaceDocument(
      _document('plain text'),
      selection: collapsedTextSelection('p1', 0, 10),
    );
    expect(slash.trigger, isNull);
    expect(slash.items, isEmpty);
    expect(slash.isOpen, isFalse);
  });

  test('tracks trigger block range query and highlighted item', () {
    final editor = WenzRichTextController(
      document: _document('hello /hea'),
      selection: collapsedTextSelection('p1', 0, 10),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.trigger?.blockId, 'p1');
    expect(slash.trigger?.blockIndex, 0);
    expect(slash.trigger?.start, 6);
    expect(slash.trigger?.end, 10);
    expect(slash.query, 'hea');
    expect(slash.highlightedIndex, 0);
    expect(slash.highlightedItem?.id, slash.items.first.id);
  });

  test('ignores stale selections whose block id no longer matches index', () {
    final editor = WenzRichTextController(
      document: _document('/hea'),
      selection: collapsedTextSelection('p1', 0, 4),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.isOpen, isTrue);

    editor.replaceDocument(
      _documentWithId('p2', '/hea'),
      selection: collapsedTextSelection('p1', 0, 4),
    );

    expect(slash.trigger, isNull);
    expect(slash.isOpen, isFalse);
  });

  test('filters empty, case-insensitive, unmatched, and Chinese queries', () {
    final editor = WenzRichTextController(
      document: _document('/'),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    final defaultCount = slash.items.length;
    expect(slash.isOpen, isTrue);
    expect(slash.query, isEmpty);

    editor.replaceDocument(
      _document('/HEA'),
      selection: collapsedTextSelection('p1', 0, 4),
    );
    expect(slash.query, 'HEA');
    expect(slash.items.map((item) => item.id), contains('heading'));

    editor.replaceDocument(
      _document('/视频'),
      selection: collapsedTextSelection('p1', 0, 3),
    );
    expect(slash.items.map((item) => item.id), contains('video'));

    editor.replaceDocument(
      _document('/no-such-item'),
      selection: collapsedTextSelection('p1', 0, 13),
    );
    expect(slash.query, 'no-such-item');
    expect(slash.items, isEmpty);
    expect(slash.isOpen, isFalse);

    editor.replaceDocument(
      _document('/'),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    expect(slash.query, isEmpty);
    expect(slash.items, hasLength(defaultCount));
    expect(slash.isOpen, isTrue);
  });

  test('query matches item id title description and keywords', () {
    final registry = SlashMenuRegistry.defaults();

    // id
    expect(
      registry.filter('heading').map((item) => item.id),
      contains('heading'),
    );
    // title
    expect(
      registry.filter('bulleted').map((item) => item.id),
      contains('list'),
    );
    // description
    expect(
      registry.filter('section').map((item) => item.id),
      contains('heading'),
    );
    // keywords (English)
    expect(
      registry.filter('bullet').map((item) => item.id),
      contains('list'),
    );
    expect(
      registry.filter('blockquote').map((item) => item.id),
      contains('quote'),
    );
    // keywords (Chinese)
    expect(
      registry.filter('图片').map((item) => item.id),
      contains('image'),
    );
  });

  test('does not open while an IME composition is in progress', () {
    final editor = WenzRichTextController(
      document: _document('/hea'),
      selection: collapsedTextSelection('p1', 0, 4),
    );
    editor.setCompositionState(const CompositionState(
      blockId: 'p1',
      blockIndex: 0,
      path: PositionPath(<Object>['block', 'p1', 'text']),
      startOffset: 1,
      endOffset: 4,
    ));
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    // Mid-composition the platform owns the composing text, so the menu must
    // not open on the partial `/hea` run.
    expect(slash.isOpen, isFalse);
    expect(slash.trigger, isNull);

    // Committing the composition re-evaluates the trigger and opens normally.
    editor.setCompositionState(null);
    expect(slash.isOpen, isTrue);
    expect(slash.query, 'hea');
  });

  test('freezes an open menu during composition-only changes', () {
    final editor = WenzRichTextController(
      document: _document('/hea'),
      selection: collapsedTextSelection('p1', 0, 4),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.isOpen, isTrue);
    expect(slash.query, 'hea');
    final queryBefore = slash.query;
    final itemsBefore = slash.items.length;

    // A pure composition-only notification (e.g. pinyin starts composing) must
    // not refresh the query, swap the items, or close the already-open menu.
    editor.setCompositionState(const CompositionState(
      blockId: 'p1',
      blockIndex: 0,
      path: PositionPath(<Object>['block', 'p1', 'text']),
      startOffset: 1,
      endOffset: 4,
    ));
    expect(slash.isOpen, isTrue);
    expect(slash.query, queryBefore);
    expect(slash.items, hasLength(itemsBefore));

    // Once the composition clears, the menu is free to refresh again.
    editor.setCompositionState(null);
    expect(slash.isOpen, isTrue);
    expect(slash.query, queryBefore);
  });

  test('closes when trigger is removed, caret moves, or structure changes', () {
    final editor = WenzRichTextController(
      document: _document('/hea'),
      selection: collapsedTextSelection('p1', 0, 4),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.isOpen, isTrue);

    editor.replaceDocument(
      _document('hea'),
      selection: collapsedTextSelection('p1', 0, 3),
    );
    expect(slash.isOpen, isFalse);

    editor.replaceDocument(
      _document('/hea'),
      selection: collapsedTextSelection('p1', 0, 4),
    );
    expect(slash.isOpen, isTrue);

    editor.setSelection(collapsedTextSelection('p1', 0, 1));
    expect(slash.isOpen, isFalse);

    editor.replaceDocument(
      _twoParagraphDocument('intro', '/hea'),
      selection: collapsedTextSelection('p2', 1, 4),
    );
    expect(slash.trigger?.query, 'hea');
    expect(slash.isOpen, isFalse);
  });

  test('refreshes after undo redo paste cut and batch delete', () {
    final editor = WenzRichTextController(
      document: _document(''),
      selection: collapsedTextSelection('p1', 0, 0),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    editor.insertText('/hea');
    expect(slash.isOpen, isTrue);
    expect(slash.query, 'hea');

    expect(editor.undo(), isTrue);
    expect(slash.trigger, isNull);

    expect(editor.redo(), isTrue);
    expect(slash.isOpen, isTrue);

    editor.setSelection(DocumentSelection(
      base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 0),
      extent: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 4),
    ));
    final cut = editor.cutSelection();
    expect(cut, isNotNull);
    expect(slash.trigger, isNull);

    editor.pasteText('/video');
    expect(slash.isOpen, isTrue);
    expect(slash.query, 'video');

    editor.deleteSelection(DocumentSelection(
      base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 0),
      extent: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 6),
    ));
    expect(slash.trigger, isNull);
  });

  test('close hides current trigger without changing document text', () {
    final editor = WenzRichTextController(
      document: _document('/hea'),
      selection: collapsedTextSelection('p1', 0, 4),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    slash.close();

    expect(slash.isOpen, isFalse);
    expect((editor.document.blocks.single as TextBlockNode).plainText, '/hea');
  });

  test('moves highlighted item with wrapping', () {
    final editor = WenzRichTextController(
      document: _document('/'),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.highlightedIndex, 0);
    slash.moveHighlight(-1);
    expect(slash.highlightedIndex, slash.items.length - 1);
    slash.moveHighlight(1);
    expect(slash.highlightedIndex, 0);
  });

  test('highlight navigation is safe on empty results and clamps selection', () {
    final editor = WenzRichTextController(
      document: _document('/no-such-item'),
      selection: collapsedTextSelection('p1', 0, 13),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    // No matching items: the menu is closed and navigation/activation are
    // harmless no-ops rather than throwing.
    expect(slash.items, isEmpty);
    expect(slash.isOpen, isFalse);
    expect(slash.highlightedItem, isNull);
    expect(slash.activateHighlighted(), isFalse);

    slash.moveHighlight(1);
    slash.moveHighlight(-1);
    slash.selectIndex(5);
    expect(slash.highlightedIndex, 0);

    // With the menu open, selectIndex clamps out-of-range values into bounds.
    editor.replaceDocument(
      _document('/'),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    expect(slash.isOpen, isTrue);
    final count = slash.items.length;
    expect(count, greaterThan(1));

    slash.selectIndex(-3);
    expect(slash.highlightedIndex, 0);
    slash.selectIndex(count + 50);
    expect(slash.highlightedIndex, count - 1);
  });

  test('activating heading removes trigger and runs block command', () {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.activateHighlighted(), isTrue);

    final block = editor.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.heading);
    expect(block.plainText, isEmpty);
    expect(slash.isOpen, isFalse);
    expect(editor.canUndo, isTrue);

    expect(editor.undo(), isTrue);
    expect((editor.document.blocks.single as TextBlockNode).plainText,
        '/heading');
    expect(editor.redo(), isTrue);
    expect((editor.document.blocks.single as TextBlockNode).type,
        BlockType.heading);
  });

  test('built-in heading items expose H1 through H6 levels', () {
    final registry = SlashMenuRegistry.defaults();
    // H1 keeps the historical `heading` id; H2–H6 carry their own ids.
    expect(registry.contains('heading'), isTrue);
    for (var level = 2; level <= 6; level++) {
      expect(registry.contains('h$level'), isTrue, reason: 'h$level id');
    }

    // Each level filter resolves to its own item and inserts the right level.
    for (var level = 2; level <= 6; level++) {
      final id = 'h$level';
      final editor = WenzRichTextController(
        document: _document('/$id'),
        selection: collapsedTextSelection('p1', 0, 1 + id.length),
      );
      final slash = SlashMenuController(editor: editor);
      addTearDown(slash.dispose);

      slash.selectIndex(
        slash.items.indexWhere((item) => item.id == id),
      );
      expect(slash.activateHighlighted(), isTrue, reason: id);

      final block = editor.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.heading, reason: id);
      expect(block.attributes.level, level, reason: id);
      expect(block.plainText, isEmpty, reason: id);
    }
  });

  test('built-in block type items remove trigger and keep surrounding text', () {
    final cases = <_SlashActivationCase>[
      _SlashActivationCase(
        itemId: 'list',
        verify: (block) {
          final text = block as TextBlockNode;
          expect(text.type, BlockType.listItem);
          expect(text.attributes.listType, 'bullet');
        },
      ),
      _SlashActivationCase(
        itemId: 'todo',
        verify: (block) {
          final text = block as TextBlockNode;
          expect(text.type, BlockType.listItem);
          expect(text.attributes.listType, 'task');
          expect(text.attributes.checked, isFalse);
        },
      ),
      _SlashActivationCase(
        itemId: 'quote',
        verify: (block) {
          expect((block as TextBlockNode).type, BlockType.quote);
        },
      ),
      _SlashActivationCase(
        itemId: 'code',
        verify: (block) {
          expect(block, isA<CodeBlockNode>());
          expect((block as CodeBlockNode).code, 'before  after');
        },
      ),
    ];

    for (final testCase in cases) {
      final editor = WenzRichTextController(
        document: _document('before /${testCase.itemId} after'),
        selection: collapsedTextSelection(
          'p1',
          0,
          'before /${testCase.itemId}'.length,
        ),
      );
      final slash = SlashMenuController(editor: editor);
      addTearDown(slash.dispose);

      slash.selectIndex(
        slash.items.indexWhere((item) => item.id == testCase.itemId),
      );
      expect(slash.activateHighlighted(), isTrue, reason: testCase.itemId);

      final block = editor.document.blocks.single;
      expect(block.plainText, 'before  after', reason: testCase.itemId);
      testCase.verify(block);
      expect(editor.selection?.extent.offset, 'before '.length);
      expect(editor.undo(), isTrue, reason: testCase.itemId);
      expect((editor.document.blocks.single as TextBlockNode).plainText,
          'before /${testCase.itemId} after');
    }
  });

  test('built-in table item removes trigger and selects first cell', () {
    final editor = WenzRichTextController(
      document: _document('/table'),
      selection: collapsedTextSelection('p1', 0, 6),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    final tableIndex = slash.items.indexWhere((item) => item.id == 'table');
    slash.selectIndex(tableIndex);
    expect(slash.activateHighlighted(), isTrue);

    final block = editor.document.blocks.single;
    expect(block, isA<TableBlockNode>());
    expect((block as TableBlockNode).table.rowCount, 3);
    expect(block.table.columnCount, 3);
    expect(editor.selection?.extent.path.isTableCellText, isTrue);
    expect(editor.undo(), isTrue);
    expect((editor.document.blocks.single as TextBlockNode).plainText, '/table');
  });

  test('table item removes trigger without dropping surrounding text', () {
    final editor = WenzRichTextController(
      document: _document('before /table after'),
      selection: collapsedTextSelection('p1', 0, 'before /table'.length),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    slash.selectIndex(slash.items.indexWhere((item) => item.id == 'table'));
    expect(slash.activateHighlighted(), isTrue);

    expect(editor.document.blocks, hasLength(3));
    expect((editor.document.blocks[0] as TextBlockNode).plainText, 'before ');
    expect(editor.document.blocks[1], isA<TableBlockNode>());
    expect((editor.document.blocks[2] as TextBlockNode).plainText, ' after');
    expect(editor.selection?.extent.path.isTableCellText, isTrue);
    expect(editor.selection?.extent.blockIndex, 1);
  });

  test('built-in image and video items select inserted object blocks', () {
    final cases = <_SlashActivationCase>[
      _SlashActivationCase(
        itemId: 'image',
        verify: (block) => expect(block, isA<ImageBlockNode>()),
      ),
      _SlashActivationCase(
        itemId: 'video',
        verify: (block) => expect(block, isA<VideoBlockNode>()),
      ),
    ];

    for (final testCase in cases) {
      final editor = WenzRichTextController(
        document: _document('/${testCase.itemId}'),
        selection: collapsedTextSelection('p1', 0, testCase.itemId.length + 1),
      );
      final slash = SlashMenuController(editor: editor);
      addTearDown(slash.dispose);

      slash.selectIndex(
        slash.items.indexWhere((item) => item.id == testCase.itemId),
      );
      expect(slash.activateHighlighted(), isTrue, reason: testCase.itemId);

      final block = editor.document.blocks.single;
      testCase.verify(block);
      expect(block.plainText, isEmpty);
      expect(editor.selection?.extent.path.isBlockObject, isTrue);
      expect(editor.selection?.extent.offset, 1);
      expect(editor.undo(), isTrue, reason: testCase.itemId);
      expect((editor.document.blocks.single as TextBlockNode).plainText,
          '/${testCase.itemId}');
    }
  });

  test('object items remove trigger without dropping surrounding text', () {
    final editor = WenzRichTextController(
      document: _document('before /image after'),
      selection: collapsedTextSelection('p1', 0, 'before /image'.length),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    slash.selectIndex(slash.items.indexWhere((item) => item.id == 'image'));
    expect(slash.activateHighlighted(), isTrue);

    expect(editor.document.blocks, hasLength(3));
    expect((editor.document.blocks[0] as TextBlockNode).plainText, 'before ');
    expect(editor.document.blocks[1], isA<ImageBlockNode>());
    expect((editor.document.blocks[2] as TextBlockNode).plainText, ' after');
    expect(editor.selection?.extent.blockIndex, 1);

    expect(editor.undo(), isTrue);
    expect((editor.document.blocks.single as TextBlockNode).plainText,
        'before /image after');
  });

  test('custom registry item can execute existing commands', () {
    final editor = WenzRichTextController(
      document: _document('/alert'),
      selection: collapsedTextSelection('p1', 0, 6),
    );
    final registry = SlashMenuRegistry(<SlashMenuItem>[
      SlashMenuItem(
        id: 'alert',
        title: 'Alert',
        icon: 'format_quote',
        action: (editor, context) {
          editor.setBlockType(type: BlockType.quote);
        },
      ),
    ]);
    final slash = SlashMenuController(editor: editor, registry: registry);
    addTearDown(slash.dispose);

    expect(slash.items.single.id, 'alert');
    expect(slash.activateHighlighted(), isTrue);
    expect(
        (editor.document.blocks.single as TextBlockNode).type, BlockType.quote);
  });

  test('registry supports overriding filtering sorting and deduping items', () {
    final registry = SlashMenuRegistry.defaults();
    final defaultHeading = registry['heading'];
    expect(defaultHeading, isNotNull);

    registry.register(
      SlashMenuItem(
        id: 'heading',
        title: 'Custom heading',
        icon: 'title',
        keywords: const <String>['custom'],
        action: (editor, context) {},
      ),
    );
    registry.registerAll(<SlashMenuItem>[
      SlashMenuItem(
        id: 'alpha',
        title: 'Alpha',
        icon: 'auto_awesome',
        keywords: const <String>['x'],
        action: (editor, context) {},
      ),
      SlashMenuItem(
        id: 'beta',
        title: 'Beta',
        icon: 'auto_awesome',
        keywords: const <String>['x'],
        action: (editor, context) {},
      ),
    ]);
    registry.addFilter((item, query) => item.id != 'beta');
    registry.setSorter((a, b, query) => b.id.compareTo(a.id));

    expect(registry['heading']?.title, 'Custom heading');
    expect(registry.items.where((item) => item.id == 'heading'), hasLength(1));
    expect(registry.filter('x').map((item) => item.id), <String>['alpha']);

    registry.clearFilters();
    expect(registry.filter('x').map((item) => item.id), <String>['beta', 'alpha']);

    registry.unregister('beta');
    expect(registry.contains('beta'), isFalse);
  });
}

RichTextDocument _document(String text) {
  return _documentWithId('p1', text);
}

RichTextDocument _documentWithId(String id, String text) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: id,
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: text)],
      ),
    ],
  );
}

RichTextDocument _twoParagraphDocument(String first, String second) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: first)],
      ),
      TextBlockNode(
        id: 'p2',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: second)],
      ),
    ],
  );
}

RichTextDocument _codeDocument(String code) {
  return RichTextDocument(
    blocks: <BlockNode>[
      CodeBlockNode(id: 'code1', code: code),
    ],
  );
}

RichTextDocument _imageDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      ImageBlockNode(id: 'img1', assetId: 'asset1'),
    ],
  );
}

RichTextDocument _tableDocument(String text) {
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

DocumentSelection _objectSelection(String blockId, int blockIndex) {
  final base = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(blockId),
    offset: 0,
  );
  return DocumentSelection(base: base, extent: base.copyWith(offset: 1));
}

DocumentSelection _tableCellSelection({required int offset}) {
  final position = DocumentPosition.tableCell(
    tableBlockId: 'table1',
    blockIndex: 0,
    tableRowIndex: 0,
    tableColumnIndex: 0,
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}

class _SlashTriggerCase {
  const _SlashTriggerCase({
    required this.description,
    required this.editor,
    this.isOpen = false,
  });

  final String description;
  final WenzRichTextController editor;
  final bool isOpen;
}

class _SlashActivationCase {
  const _SlashActivationCase({
    required this.itemId,
    required this.verify,
  });

  final String itemId;
  final void Function(BlockNode block) verify;
}

import 'package:flutter/foundation.dart';

import '../core/commands/inline_editing.dart';
import '../core/model/attributes.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/table_model.dart';
import '../core/position/document_position.dart';
import 'wenz_rich_text_controller.dart';

typedef SlashMenuAction = void Function(
  WenzRichTextController editor,
  SlashMenuContext context,
);

typedef SlashMenuItemFilter = bool Function(SlashMenuItem item, String query);

typedef SlashMenuItemSorter = int Function(
  SlashMenuItem a,
  SlashMenuItem b,
  String query,
);

class SlashMenuItem {
  const SlashMenuItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.action,
    this.description = '',
    this.keywords = const <String>[],
    this.handlesTriggerDeletion = false,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final List<String> keywords;
  final SlashMenuAction action;
  final bool handlesTriggerDeletion;

  bool matches(String query) {
    if (query.isEmpty) {
      return true;
    }
    final normalized = query.toLowerCase();
    return id.toLowerCase().contains(normalized) ||
        title.toLowerCase().contains(normalized) ||
        description.toLowerCase().contains(normalized) ||
        keywords.any((keyword) => keyword.toLowerCase().contains(normalized));
  }
}

class SlashMenuRegistry {
  SlashMenuRegistry([
    Iterable<SlashMenuItem> items = const <SlashMenuItem>[],
  ]) {
    for (final item in items) {
      register(item);
    }
  }

  factory SlashMenuRegistry.defaults() {
    return SlashMenuRegistry(defaultSlashMenuItems());
  }

  final Map<String, SlashMenuItem> _items = <String, SlashMenuItem>{};
  final List<SlashMenuItemFilter> _filters = <SlashMenuItemFilter>[];
  SlashMenuItemSorter? _sorter;

  List<SlashMenuItem> get items => List<SlashMenuItem>.unmodifiable(
        _items.values,
      );

  void register(SlashMenuItem item) {
    _items[item.id] = item;
  }

  void registerAll(Iterable<SlashMenuItem> items) {
    for (final item in items) {
      register(item);
    }
  }

  void unregister(String id) {
    _items.remove(id);
  }

  bool contains(String id) => _items.containsKey(id);

  SlashMenuItem? operator [](String id) => _items[id];

  void addFilter(SlashMenuItemFilter filter) {
    _filters.add(filter);
  }

  bool removeFilter(SlashMenuItemFilter filter) {
    return _filters.remove(filter);
  }

  void clearFilters() {
    _filters.clear();
  }

  void setSorter(SlashMenuItemSorter? sorter) {
    _sorter = sorter;
  }

  List<SlashMenuItem> filter(String query) {
    final result = <SlashMenuItem>[
      for (final item in _items.values)
        if (item.matches(query) &&
            _filters.every((filter) => filter(item, query)))
          item,
    ];
    final sorter = _sorter;
    if (sorter != null) {
      result.sort((a, b) => sorter(a, b, query));
    }
    return result;
  }
}

class SlashMenuTrigger {
  const SlashMenuTrigger({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.start,
    required this.end,
    required this.query,
  });

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int start;
  final int end;
  final String query;

  DocumentSelection get selection {
    final base = DocumentPosition(
      blockId: blockId,
      blockIndex: blockIndex,
      path: path,
      offset: start,
    );
    final extent = DocumentPosition(
      blockId: blockId,
      blockIndex: blockIndex,
      path: path,
      offset: end,
    );
    return DocumentSelection(base: base, extent: extent);
  }
}

class SlashMenuContext {
  const SlashMenuContext({
    required this.trigger,
    required this.generatedId,
  });

  final SlashMenuTrigger trigger;
  final String Function(String prefix) generatedId;

  int get blockIndex => trigger.blockIndex;
}

class SlashMenuController extends ChangeNotifier {
  SlashMenuController({
    required WenzRichTextController editor,
    SlashMenuRegistry? registry,
  })  : _editor = editor,
        registry = registry ?? SlashMenuRegistry.defaults() {
    _editor.addListener(_handleEditorChanged);
    refresh();
  }

  WenzRichTextController get editor => _editor;
  WenzRichTextController _editor;

  final SlashMenuRegistry registry;

  SlashMenuTrigger? get trigger => _trigger;
  SlashMenuTrigger? _trigger;

  String get query => _trigger?.query ?? '';

  List<SlashMenuItem> get items => List<SlashMenuItem>.unmodifiable(_items);
  List<SlashMenuItem> _items = const <SlashMenuItem>[];

  int get highlightedIndex => _highlightedIndex;
  int _highlightedIndex = 0;

  bool get isOpen => _trigger != null && _items.isNotEmpty && !_closedManually;

  SlashMenuItem? get highlightedItem {
    if (!isOpen ||
        _highlightedIndex < 0 ||
        _highlightedIndex >= _items.length) {
      return null;
    }
    return _items[_highlightedIndex];
  }

  bool _closedManually = false;
  List<String> _documentBlockIds = const <String>[];
  int _generatedSequence = 0;

  void attachEditor(WenzRichTextController editor) {
    if (identical(_editor, editor)) {
      return;
    }
    _editor.removeListener(_handleEditorChanged);
    _editor = editor;
    _editor.addListener(_handleEditorChanged);
    refresh();
  }

  void refresh() {
    final nextDocumentBlockIds = _blockIdsFor(_editor.document.blocks);
    final structureChanged =
        !listEquals(_documentBlockIds, nextDocumentBlockIds);
    final nextTrigger = _detectTrigger(_editor);
    final sameTrigger = _sameTrigger(_trigger, nextTrigger);
    final selectionOnlyTriggerChange =
        _editor.lastChangedBlockIds?.isEmpty == true &&
            !_editor.lastChangeWasCompositionOnly &&
            !sameTrigger;
    final closeForStructureChange = structureChanged && _trigger != null;
    _documentBlockIds = nextDocumentBlockIds;
    _trigger = nextTrigger;
    if (closeForStructureChange || selectionOnlyTriggerChange) {
      _closedManually = true;
    } else if (!sameTrigger) {
      _closedManually = false;
    }
    _items = nextTrigger == null
        ? const <SlashMenuItem>[]
        : registry.filter(nextTrigger.query);
    if (_items.isEmpty) {
      _highlightedIndex = 0;
    } else if (_highlightedIndex >= _items.length) {
      _highlightedIndex = _items.length - 1;
    }
    notifyListeners();
  }

  void close() {
    if (_closedManually) {
      return;
    }
    _closedManually = true;
    notifyListeners();
  }

  void selectIndex(int index) {
    if (_items.isEmpty) {
      return;
    }
    final next = index.clamp(0, _items.length - 1).toInt();
    if (next == _highlightedIndex) {
      return;
    }
    _highlightedIndex = next;
    notifyListeners();
  }

  void moveHighlight(int delta) {
    if (_items.isEmpty || delta == 0) {
      return;
    }
    final next = (_highlightedIndex + delta) % _items.length;
    _highlightedIndex = next < 0 ? next + _items.length : next;
    notifyListeners();
  }

  bool activateHighlighted() {
    final item = highlightedItem;
    if (item == null) {
      return false;
    }
    return activate(item);
  }

  bool activate(SlashMenuItem item) {
    final activeTrigger = _detectTrigger(_editor);
    if (activeTrigger == null) {
      _trigger = null;
      _items = const <SlashMenuItem>[];
      _highlightedIndex = 0;
      notifyListeners();
      return false;
    }
    _closedManually = true;
    if (!item.handlesTriggerDeletion) {
      _editor.deleteSelection(activeTrigger.selection);
    }
    item.action(
      _editor,
      SlashMenuContext(
        trigger: activeTrigger,
        generatedId: _nextGeneratedId,
      ),
    );
    _trigger = null;
    _items = const <SlashMenuItem>[];
    _highlightedIndex = 0;
    notifyListeners();
    return true;
  }

  String _nextGeneratedId(String prefix) {
    _generatedSequence += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_generatedSequence';
  }

  void _handleEditorChanged() {
    refresh();
  }

  @override
  void dispose() {
    _editor.removeListener(_handleEditorChanged);
    super.dispose();
  }
}

List<SlashMenuItem> defaultSlashMenuItems() {
  return <SlashMenuItem>[
    SlashMenuItem(
      id: 'heading',
      title: 'Heading',
      description: 'Large section title',
      icon: 'title',
      keywords: const <String>['h1', 'title'],
      handlesTriggerDeletion: true,
      action: (editor, context) {
        _replaceTriggerWithTextBlock(
          editor,
          context,
          type: BlockType.heading,
          attributes: const BlockAttributes(level: 1),
        );
      },
    ),
    SlashMenuItem(
      id: 'list',
      title: 'Bulleted list',
      description: 'Unordered list item',
      icon: 'list',
      keywords: const <String>['bullet', 'unordered'],
      handlesTriggerDeletion: true,
      action: (editor, context) {
        _replaceTriggerWithTextBlock(
          editor,
          context,
          type: BlockType.listItem,
          attributes: const BlockAttributes(listType: 'bullet'),
        );
      },
    ),
    SlashMenuItem(
      id: 'todo',
      title: 'Todo',
      description: 'Task list item',
      icon: 'check_box',
      keywords: const <String>['task', 'checkbox'],
      handlesTriggerDeletion: true,
      action: (editor, context) {
        _replaceTriggerWithTextBlock(
          editor,
          context,
          type: BlockType.listItem,
          attributes: const BlockAttributes(listType: 'task', checked: false),
        );
      },
    ),
    SlashMenuItem(
      id: 'quote',
      title: 'Quote',
      description: 'Quoted block',
      icon: 'format_quote',
      keywords: const <String>['blockquote'],
      handlesTriggerDeletion: true,
      action: (editor, context) {
        _replaceTriggerWithTextBlock(editor, context, type: BlockType.quote);
      },
    ),
    SlashMenuItem(
      id: 'code',
      title: 'Code block',
      description: 'Preformatted code',
      icon: 'code',
      keywords: const <String>['pre'],
      handlesTriggerDeletion: true,
      action: (editor, context) {
        _replaceTriggerWithObjectBlock(
          editor,
          context,
          (block, content) => CodeBlockNode(
            id: block.id,
            code: content.map((node) => node.plainText).join(),
          ),
          (block, blockIndex) => DocumentSelection(
            base: DocumentPosition.code(
              blockId: block.id,
              blockIndex: blockIndex,
              offset: 0,
            ),
            extent: DocumentPosition.code(
              blockId: block.id,
              blockIndex: blockIndex,
              offset: 0,
            ),
          ),
        );
      },
    ),
    SlashMenuItem(
      id: 'table',
      title: 'Table',
      description: '3 by 3 table',
      icon: 'table_chart',
      keywords: const <String>['grid'],
      handlesTriggerDeletion: true,
      action: (editor, context) {
        final tableId = context.generatedId('table');
        _replaceTriggerWithObjectBlock(
          editor,
          context,
          (block, content) => TableBlockNode(
            id: tableId,
            table: _createSlashTable(tableId, 3, 3, context.generatedId),
          ),
          (block, blockIndex) => _tableCellSelection(tableId, blockIndex),
        );
      },
    ),
    SlashMenuItem(
      id: 'image',
      title: 'Image',
      description: 'Image placeholder',
      icon: 'image',
      keywords: const <String>['media', 'picture'],
      handlesTriggerDeletion: true,
      action: (editor, context) {
        _replaceTriggerWithObjectBlock(
          editor,
          context,
          (block, content) => ImageBlockNode(
            id: block.id,
            assetId: context.generatedId('image'),
          ),
          (block, blockIndex) {
            final base = DocumentPosition(
              blockId: block.id,
              blockIndex: blockIndex,
              path: PositionPath.blockObject(block.id),
              offset: 0,
            );
            final extent = base.copyWith(offset: 1);
            return DocumentSelection(base: base, extent: extent);
          },
        );
      },
    ),
    SlashMenuItem(
      id: 'video',
      title: 'Video',
      description: 'Video placeholder',
      icon: 'video',
      keywords: const <String>['media', 'movie', 'play', '视频'],
      handlesTriggerDeletion: true,
      action: (editor, context) {
        _replaceTriggerWithObjectBlock(
          editor,
          context,
          (block, content) => VideoBlockNode(
            id: block.id,
            assetId: context.generatedId('video'),
            title: 'Video placeholder',
            aspectRatio: VideoBlockNode.defaultAspectRatio,
          ),
          (block, blockIndex) {
            final base = DocumentPosition(
              blockId: block.id,
              blockIndex: blockIndex,
              path: PositionPath.blockObject(block.id),
              offset: 0,
            );
            final extent = base.copyWith(offset: 1);
            return DocumentSelection(base: base, extent: extent);
          },
        );
      },
    ),
  ];
}

void _replaceTriggerWithTextBlock(
  WenzRichTextController editor,
  SlashMenuContext context,
  {
  required BlockType type,
  BlockAttributes attributes = const BlockAttributes(),
}) {
  _replaceTriggerBlock(
    editor,
    context,
    (block, content) => TextBlockNode(
      id: block.id,
      type: type,
      attributes: attributes,
      content: content,
    ),
    (block, blockIndex, textLength) {
      final position = DocumentPosition.text(
        blockId: block.id,
        blockIndex: blockIndex,
        offset: textLength,
      );
      return DocumentSelection(base: position, extent: position);
    },
  );
}

void _replaceTriggerWithObjectBlock(
  WenzRichTextController editor,
  SlashMenuContext context,
  BlockNode Function(TextBlockNode block, List<InlineNode> content) buildBlock,
  DocumentSelection Function(BlockNode block, int blockIndex) buildSelection,
) {
  _replaceTriggerBlockWithBlocks(
    editor,
    context,
    (block, content) {
      final split = _splitContentAroundTrigger(block, context.trigger);
      final insertedBlock = buildBlock(block, content);
      final blocks = <BlockNode>[
        if (split.before.isNotEmpty)
          TextBlockNode(
            id: block.id,
            type: block.type,
            attributes: block.attributes,
            content: split.before,
          ),
        insertedBlock,
        if (split.after.isNotEmpty)
          TextBlockNode(
            id: context.generatedId('${block.id}-after'),
            type: block.type,
            attributes: block.attributes,
            content: split.after,
          ),
      ];
      final insertedIndex = context.blockIndex + (split.before.isEmpty ? 0 : 1);
      return _SlashReplacement(
        blocks: blocks,
        selection: buildSelection(insertedBlock, insertedIndex),
      );
    },
  );
}

void _replaceTriggerBlock(
  WenzRichTextController editor,
  SlashMenuContext context,
  BlockNode Function(TextBlockNode block, List<InlineNode> content) buildBlock,
  DocumentSelection Function(BlockNode block, int blockIndex, int caretOffset)
      buildSelection,
) {
  _replaceTriggerBlockWithBlocks(
    editor,
    context,
    (block, content) {
      final nextBlock = buildBlock(block, content);
      final caretOffset = context.trigger.start
          .clamp(0, inlineNodesLength(content))
          .toInt();
      return _SlashReplacement(
        blocks: <BlockNode>[nextBlock],
        selection: buildSelection(nextBlock, context.blockIndex, caretOffset),
      );
    },
  );
}

void _replaceTriggerBlockWithBlocks(
  WenzRichTextController editor,
  SlashMenuContext context,
  _SlashReplacement Function(TextBlockNode block, List<InlineNode> content)
      buildReplacement,
) {
  final index = context.blockIndex;
  if (index < 0 || index >= editor.document.blocks.length) {
    return;
  }
  final block = editor.document.blocks[index];
  if (block is! TextBlockNode) {
    return;
  }
  final start = context.trigger.start.clamp(0, block.plainText.length).toInt();
  final end = context.trigger.end.clamp(start, block.plainText.length).toInt();
  final content = deleteInline(block.content, start, end);
  final replacement = buildReplacement(block, content);
  editor.replaceBlocks(
    index: index,
    deleteCount: 1,
    blocks: replacement.blocks,
    selection: replacement.selection,
  );
}

_SlashContentSplit _splitContentAroundTrigger(
  TextBlockNode block,
  SlashMenuTrigger trigger,
) {
  final start = trigger.start.clamp(0, block.plainText.length).toInt();
  final end = trigger.end.clamp(start, block.plainText.length).toInt();
  final before = splitInline(block.content, start).before;
  final after = splitInline(block.content, end).after;
  return _SlashContentSplit(before: before, after: after);
}

DocumentSelection _tableCellSelection(String tableId, int blockIndex) {
  final position = DocumentPosition.tableCell(
    tableBlockId: tableId,
    blockIndex: blockIndex,
    tableRowIndex: 0,
    tableColumnIndex: 0,
    offset: 0,
  );
  return DocumentSelection(base: position, extent: position);
}

TableModel _createSlashTable(
  String tableId,
  int rowCount,
  int columnCount,
  String Function(String prefix) generatedId,
) {
  return TableModel(
    rows: <List<TableCellNode>>[
      for (var rowIndex = 0; rowIndex < rowCount; rowIndex++)
        <TableCellNode>[
          for (var columnIndex = 0; columnIndex < columnCount; columnIndex++)
            TableCellNode(
              id: generatedId('$tableId-cell-$rowIndex-$columnIndex'),
              blocks: <BlockNode>[
                TextBlockNode(
                  id: generatedId('$tableId-p-$rowIndex-$columnIndex'),
                  type: BlockType.paragraph,
                  content: const <InlineNode>[],
                ),
              ],
            ),
        ],
    ],
  );
}

class _SlashReplacement {
  const _SlashReplacement({
    required this.blocks,
    required this.selection,
  });

  final List<BlockNode> blocks;
  final DocumentSelection selection;
}

class _SlashContentSplit {
  const _SlashContentSplit({
    required this.before,
    required this.after,
  });

  final List<InlineNode> before;
  final List<InlineNode> after;
}

SlashMenuTrigger? _detectTrigger(WenzRichTextController editor) {
  if (!editor.canEdit) {
    return null;
  }
  if (editor.isApplyingComposingTextInput || editor.compositionState != null) {
    return null;
  }
  final selection = editor.selection;
  if (selection == null || !selection.isCollapsed) {
    return null;
  }
  final position = selection.extent;
  if (position.blockId.isEmpty) {
    return null;
  }
  if (!position.path.isBlockText) {
    return null;
  }
  if (position.blockIndex < 0 ||
      position.blockIndex >= editor.document.blocks.length) {
    return null;
  }
  final block = editor.document.blocks[position.blockIndex];
  if (block is! TextBlockNode) {
    return null;
  }
  if (block.id != position.blockId) {
    return null;
  }
  final text = block.plainText;
  final caret = position.offset.clamp(0, text.length).toInt();
  final slashStart = _slashStartBeforeCaret(text, caret);
  if (slashStart == null) {
    return null;
  }
  return SlashMenuTrigger(
    blockId: block.id,
    blockIndex: position.blockIndex,
    path: position.path,
    start: slashStart,
    end: caret,
    query: text.substring(slashStart + 1, caret),
  );
}

List<String> _blockIdsFor(List<BlockNode> blocks) {
  return <String>[
    for (final block in blocks) block.id,
  ];
}

int? _slashStartBeforeCaret(String text, int caret) {
  var index = caret - 1;
  while (index >= 0) {
    final codeUnit = text.codeUnitAt(index);
    if (_isQueryTerminator(codeUnit)) {
      return null;
    }
    if (codeUnit == 0x2F) {
      if (index == 0 || _isTriggerBoundary(text.codeUnitAt(index - 1))) {
        return index;
      }
      return null;
    }
    index -= 1;
  }
  return null;
}

bool _isQueryTerminator(int codeUnit) {
  return codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D;
}

bool _isTriggerBoundary(int codeUnit) {
  return _isQueryTerminator(codeUnit);
}

bool _sameTrigger(SlashMenuTrigger? a, SlashMenuTrigger? b) {
  if (a == null || b == null) {
    return a == b;
  }
  return a.blockId == b.blockId &&
      a.blockIndex == b.blockIndex &&
      a.path == b.path &&
      a.start == b.start &&
      a.end == b.end &&
      a.query == b.query;
}

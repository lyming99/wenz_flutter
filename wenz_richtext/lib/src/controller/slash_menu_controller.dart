import 'package:flutter/foundation.dart';

import '../core/model/block_node.dart';
import '../core/position/document_position.dart';
import 'wenz_rich_text_controller.dart';

typedef SlashMenuAction = void Function(
  WenzRichTextController editor,
  SlashMenuContext context,
);

class SlashMenuItem {
  const SlashMenuItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.action,
    this.description = '',
    this.keywords = const <String>[],
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final List<String> keywords;
  final SlashMenuAction action;

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
  SlashMenuRegistry([Iterable<SlashMenuItem> items = const <SlashMenuItem>[]]) {
    for (final item in items) {
      register(item);
    }
  }

  factory SlashMenuRegistry.defaults() {
    return SlashMenuRegistry(defaultSlashMenuItems());
  }

  final Map<String, SlashMenuItem> _items = <String, SlashMenuItem>{};

  List<SlashMenuItem> get items => List<SlashMenuItem>.unmodifiable(
        _items.values,
      );

  void register(SlashMenuItem item) {
    _items[item.id] = item;
  }

  void unregister(String id) {
    _items.remove(id);
  }

  List<SlashMenuItem> filter(String query) {
    return <SlashMenuItem>[
      for (final item in _items.values)
        if (item.matches(query)) item,
    ];
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
    final nextTrigger = _detectTrigger(_editor);
    final sameTrigger = _sameTrigger(_trigger, nextTrigger);
    _trigger = nextTrigger;
    if (!sameTrigger) {
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
    if (_trigger == null && _closedManually) {
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
    final activeTrigger = _trigger;
    if (activeTrigger == null) {
      return false;
    }
    _closedManually = true;
    _editor.deleteSelection(activeTrigger.selection);
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
      action: (editor, context) {
        editor.setBlockType(type: BlockType.heading, level: 1);
      },
    ),
    SlashMenuItem(
      id: 'list',
      title: 'Bulleted list',
      description: 'Unordered list item',
      icon: 'list',
      keywords: const <String>['bullet', 'unordered'],
      action: (editor, context) {
        editor.setBlockType(type: BlockType.listItem);
      },
    ),
    SlashMenuItem(
      id: 'todo',
      title: 'Todo',
      description: 'Task list item',
      icon: 'check_box',
      keywords: const <String>['task', 'checkbox'],
      action: (editor, context) {
        editor.toggleTodo();
      },
    ),
    SlashMenuItem(
      id: 'quote',
      title: 'Quote',
      description: 'Quoted block',
      icon: 'format_quote',
      keywords: const <String>['blockquote'],
      action: (editor, context) {
        editor.setBlockType(type: BlockType.quote);
      },
    ),
    SlashMenuItem(
      id: 'code',
      title: 'Code block',
      description: 'Preformatted code',
      icon: 'code',
      keywords: const <String>['pre'],
      action: (editor, context) {
        _replaceCurrentBlock(
          editor,
          context,
          (block) => CodeBlockNode(id: block.id, code: block.plainText),
          (block) => DocumentSelection(
            base: DocumentPosition.code(
              blockId: block.id,
              blockIndex: context.blockIndex,
              offset: 0,
            ),
            extent: DocumentPosition.code(
              blockId: block.id,
              blockIndex: context.blockIndex,
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
      action: (editor, context) {
        final tableId = context.generatedId('table');
        final selection = DocumentSelection(
          base: DocumentPosition.tableCell(
            tableBlockId: tableId,
            blockIndex: context.blockIndex,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 0,
          ),
          extent: DocumentPosition.tableCell(
            tableBlockId: tableId,
            blockIndex: context.blockIndex,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 0,
          ),
        );
        editor.insertTable(
          index: context.blockIndex,
          tableId: tableId,
          rowCount: 3,
          columnCount: 3,
          selection: selection,
        );
      },
    ),
    SlashMenuItem(
      id: 'image',
      title: 'Image',
      description: 'Image placeholder',
      icon: 'image',
      keywords: const <String>['media', 'picture'],
      action: (editor, context) {
        _replaceCurrentBlock(
          editor,
          context,
          (block) => ImageBlockNode(
            id: block.id,
            assetId: context.generatedId('image'),
          ),
          (block) {
            final base = DocumentPosition(
              blockId: block.id,
              blockIndex: context.blockIndex,
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

void _replaceCurrentBlock(
  WenzRichTextController editor,
  SlashMenuContext context,
  BlockNode Function(TextBlockNode block) buildBlock,
  DocumentSelection Function(BlockNode block) buildSelection,
) {
  final index = context.blockIndex;
  if (index < 0 || index >= editor.document.blocks.length) {
    return;
  }
  final block = editor.document.blocks[index];
  if (block is! TextBlockNode) {
    return;
  }
  final nextBlock = buildBlock(block);
  editor.replaceBlocks(
    index: index,
    deleteCount: 1,
    blocks: <BlockNode>[nextBlock],
    selection: buildSelection(nextBlock),
  );
}

SlashMenuTrigger? _detectTrigger(WenzRichTextController editor) {
  final selection = editor.selection;
  if (selection == null || !selection.isCollapsed) {
    return null;
  }
  final position = selection.extent;
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

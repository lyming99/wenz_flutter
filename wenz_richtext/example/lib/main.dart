import 'package:flutter/material.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'test_host.dart';

void main() {
  runApp(const WenzRichTextExampleApp());
}

/// Example [MediaResolver] (acceptance task B6): renders image blocks whose
/// `assetId` is an http(s) URL via [Image.network], with an `errorBuilder`
/// fallback so a failed load shows a message instead of crashing. Video/file
/// blocks are left to the built-in placeholder.
class _NetworkImageResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is! ImageBlockNode) {
      return null;
    }
    final url = block.assetId;
    if (!url.startsWith('http')) {
      // Not a network URL — let the placeholder render.
      return null;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(
                value: progress.cumulativeBytesLoaded /
                    (progress.expectedTotalBytes ?? 1),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => const SizedBox(
          height: 80,
          child: Center(child: Text('⚠ image load failed')),
        ),
      ),
    );
  }
}

class WenzRichTextExampleApp extends StatelessWidget {
  const WenzRichTextExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wenz RichText',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const EditorWorkbench(),
    );
  }
}

class EditorWorkbench extends StatefulWidget {
  const EditorWorkbench({super.key});

  @override
  State<EditorWorkbench> createState() => _EditorWorkbenchState();
}

class _EditorWorkbenchState extends State<EditorWorkbench> {
  late final WenzRichTextController _controller;
  late final ToolbarController _toolbar;
  final MediaResolver _mediaResolver = _NetworkImageResolver();
  var _nextId = 0;
  var _showDebugOverlay = false;

  /// Most recent controller callback event, shown in the inspector's Events
  /// section as a live demonstration of onChanged / onSelectionChanged /
  /// onCommandExecuted (acceptance task B5).
  String _lastEvent = '—';

  @override
  void initState() {
    super.initState();
    _controller = WenzRichTextController(
      document: _sampleDocument(),
      selection: _collapsed('intro', 1, 18),
      mediaResolver: _mediaResolver,
    )..addListener(_handleControllerChanged);
    _toolbar = ToolbarController(_controller)..addListener(_handleControllerChanged);
    // Wire the three business-integration callbacks. They fire synchronously
    // before notifyListeners, so reading controller state here is safe.
    _controller.onChanged = (doc) {
      _lastEvent = 'Doc changed · blocks=${doc.blocks.length}';
    };
    _controller.onSelectionChanged = (selection) {
      if (selection == null) {
        _lastEvent = 'Selection cleared';
      } else if (selection.isCollapsed) {
        _lastEvent =
            'Selection · caret @block ${selection.extent.blockIndex}+${selection.extent.offset}';
      } else {
        _lastEvent =
            'Selection · range ${selection.start.offset}→${selection.end.offset}';
      }
    };
    _controller.onCommandExecuted = (command, change) {
      _lastEvent = 'Command · ${command.description} (${change.after.blocks.length} blocks)';
    };
  }

  @override
  void dispose() {
    _toolbar
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wenz RichText'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Undo',
            onPressed: _controller.canUndo ? _controller.undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: _controller.canRedo ? _controller.redo : null,
            icon: const Icon(Icons.redo),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: WenzEditorTestHost(
        controller: _controller,
        child: Row(
          children: <Widget>[
          SizedBox(
            width: 280,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border(
                  right: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: _InspectorPanel(
                controller: _controller,
                showDebugOverlay: _showDebugOverlay,
                lastEvent: _lastEvent,
                onToggleDebugOverlay: (value) {
                  setState(() => _showDebugOverlay = value);
                },
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                _Toolbar(
                  controller: _controller,
                  toolbar: _toolbar,
                  onInsertCode: _insertCodeBlock,
                  onInsertTable: _insertTable,
                  onInsertImage: _insertImage,
                  onInsertRow: _insertTableRow,
                  onInsertColumn: _insertTableColumn,
                  onDeleteRow: _deleteTableRow,
                  onDeleteColumn: _deleteTableColumn,
                  onMergeCells: _mergeSelectedCells,
                  onSplitCell: _splitSelectedCell,
                ),
                Expanded(
                  child: ColoredBox(
                    color: theme.colorScheme.surface,
                    child: WenzRichTextEditor(
                      controller: _controller,
                      autofocus: true,
                      padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
                      blockSpacing: 14,
                      textStyle: theme.textTheme.bodyLarge,
                      showDebugOverlay: _showDebugOverlay,
                      mediaResolver: _mediaResolver,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _insertCodeBlock() {
    final id = _newId('code');
    _controller.insertBlocks(
      index: _controller.document.blocks.length,
      blocks: <BlockNode>[
        CodeBlockNode(
          id: id,
          language: 'dart',
          code: "controller.insertText('Hello');",
        ),
      ],
      selection: _codeCollapsed(id, _controller.document.blocks.length, 0),
    );
  }

  void _insertTable() {
    _controller.insertTable(
      index: _currentBlockInsertionIndex(),
      tableId: _newId('table'),
      rowCount: 2,
      columnCount: 3,
    );
  }

  void _insertImage() {
    final id = _newId('image');
    _controller.insertBlocks(
      index: _currentBlockInsertionIndex(),
      blocks: <BlockNode>[
        ImageBlockNode(
          id: id,
          assetId: 'https://picsum.photos/seed/$id/640/360',
          file: 'inserted.jpg',
          width: 640,
          height: 360,
        ),
      ],
    );
  }

  /// Resolves the table block + cell coordinates under the current caret, or
  /// null when the caret is not inside a table cell.
  _TableContext? _currentTableContext() {
    final selection = _controller.selection;
    final path = selection?.extent.path;
    if (path == null || !path.isTableCellText) {
      return null;
    }
    final blockIndex = selection!.extent.blockIndex;
    if (blockIndex < 0 || blockIndex >= _controller.document.blocks.length) {
      return null;
    }
    final block = _controller.document.blocks[blockIndex];
    if (block is! TableBlockNode) {
      return null;
    }
    return _TableContext(
      blockIndex: blockIndex,
      rowIndex: path.tableRowIndex!,
      columnIndex: path.tableColumnIndex!,
    );
  }

  void _insertTableRow() {
    final ctx = _currentTableContext();
    if (ctx == null) {
      return;
    }
    _controller.insertTableRow(
      blockIndex: ctx.blockIndex,
      rowIndex: ctx.rowIndex + 1,
    );
  }

  void _insertTableColumn() {
    final ctx = _currentTableContext();
    if (ctx == null) {
      return;
    }
    _controller.insertTableColumn(
      blockIndex: ctx.blockIndex,
      columnIndex: ctx.columnIndex + 1,
    );
  }

  void _deleteTableRow() {
    final ctx = _currentTableContext();
    if (ctx == null) {
      return;
    }
    _controller.deleteTableRow(
      blockIndex: ctx.blockIndex,
      rowIndex: ctx.rowIndex,
    );
  }

  void _deleteTableColumn() {
    final ctx = _currentTableContext();
    if (ctx == null) {
      return;
    }
    _controller.deleteTableColumn(
      blockIndex: ctx.blockIndex,
      columnIndex: ctx.columnIndex,
    );
  }

  /// Merges the selected cell range, or (when the caret is collapsed) the
  /// 2x2 block anchored at the current cell so the demo is usable without a
  /// multi-cell drag.
  void _mergeSelectedCells() {
    final selection = _controller.selection;
    final range = selection?.tableCellRange;
    if (range != null && !range.isSingleCell) {
      _controller.mergeTableCells(
        blockIndex: range.blockIndex,
        startRow: range.startRow,
        startColumn: range.startColumn,
        endRow: range.endRow,
        endColumn: range.endColumn,
      );
      return;
    }
    final ctx = _currentTableContext();
    if (ctx == null) {
      return;
    }
    _controller.mergeTableCells(
      blockIndex: ctx.blockIndex,
      startRow: ctx.rowIndex,
      startColumn: ctx.columnIndex,
      endRow: ctx.rowIndex + 1,
      endColumn: ctx.columnIndex + 1,
    );
  }

  void _splitSelectedCell() {
    final ctx = _currentTableContext();
    if (ctx == null) {
      return;
    }
    _controller.splitTableCell(
      blockIndex: ctx.blockIndex,
      rowIndex: ctx.rowIndex,
      columnIndex: ctx.columnIndex,
    );
  }

  String _newId(String prefix) {
    _nextId += 1;
    return '$prefix-$_nextId';
  }

  int _currentBlockInsertionIndex() {
    final selection = _controller.selection;
    final blockCount = _controller.document.blocks.length;
    if (selection == null) {
      return blockCount;
    }
    final position = selection.extent;
    final index = position.blockIndex.clamp(0, blockCount).toInt();
    if (position.path.isTableCellText) {
      return (index + 1).clamp(0, blockCount).toInt();
    }
    if (position.path.isBlockObject && position.offset > 0) {
      return (index + 1).clamp(0, blockCount).toInt();
    }
    return index;
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.toolbar,
    required this.onInsertCode,
    required this.onInsertTable,
    required this.onInsertImage,
    required this.onInsertRow,
    required this.onInsertColumn,
    required this.onDeleteRow,
    required this.onDeleteColumn,
    required this.onMergeCells,
    required this.onSplitCell,
  });

  final WenzRichTextController controller;
  final ToolbarController toolbar;
  final VoidCallback onInsertCode;
  final VoidCallback onInsertTable;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertRow;
  final VoidCallback onInsertColumn;
  final VoidCallback onDeleteRow;
  final VoidCallback onDeleteColumn;
  final VoidCallback onMergeCells;
  final VoidCallback onSplitCell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Table structure actions only make sense when the caret is inside a cell.
    final inTable = toolbar.canTableStruct;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _MarkButton(
              icon: Icons.format_bold,
              label: 'Bold',
              toolbar: toolbar,
              mark: TextMark.bold,
            ),
            _MarkButton(
              icon: Icons.format_italic,
              label: 'Italic',
              toolbar: toolbar,
              mark: TextMark.italic,
            ),
            _MarkButton(
              icon: Icons.format_underline,
              label: 'Underline',
              toolbar: toolbar,
              mark: TextMark.underline,
            ),
            _MarkButton(
              icon: Icons.format_strikethrough,
              label: 'Strikethrough',
              toolbar: toolbar,
              mark: TextMark.lineThrough,
            ),
            _MarkButton(
              icon: Icons.comment,
              label: 'Remark',
              toolbar: toolbar,
              mark: TextMark.remark,
            ),
            IconButton(
              tooltip: 'Clear style',
              onPressed: toolbar.canFormatInline ? toolbar.clearStyle : null,
              icon: const Icon(Icons.format_clear),
            ),
            IconButton(
              tooltip: 'Link',
              isSelected: toolbar.linkUrl != null,
              onPressed: toolbar.canSetLink
                  ? () => _showLinkDialog(context)
                  : null,
              icon: const Icon(Icons.link),
            ),
            const SizedBox(width: 8),
            _BlockTypeButton(
              icon: Icons.title,
              label: 'Heading 1',
              toolbar: toolbar,
              active: toolbar.isHeading(1),
              onPressed: () => toolbar.setHeading(1),
            ),
            _BlockTypeButton(
              icon: Icons.title,
              label: 'Heading 2',
              toolbar: toolbar,
              active: toolbar.isHeading(2),
              onPressed: () => toolbar.setHeading(2),
            ),
            _BlockTypeButton(
              icon: Icons.title,
              label: 'Heading 3',
              toolbar: toolbar,
              active: toolbar.isHeading(3),
              onPressed: () => toolbar.setHeading(3),
            ),
            _BlockTypeButton(
              icon: Icons.notes,
              label: 'Paragraph',
              toolbar: toolbar,
              active: toolbar.isParagraph,
              onPressed: toolbar.setParagraph,
            ),
            _BlockTypeButton(
              icon: Icons.format_quote,
              label: 'Quote',
              toolbar: toolbar,
              active: toolbar.isQuoteBlock,
              onPressed: toolbar.toggleQuoteBlock,
            ),
            const SizedBox(width: 8),
            _BlockTypeButton(
              icon: Icons.checklist,
              label: 'Task list',
              toolbar: toolbar,
              active: toolbar.isTodo,
              onPressed: toolbar.setTodo,
            ),
            _BlockTypeButton(
              icon: Icons.format_list_numbered,
              label: 'Ordered list',
              toolbar: toolbar,
              active: toolbar.isOrderedList,
              onPressed: toolbar.setOrderedList,
            ),
            _BlockTypeButton(
              icon: Icons.format_list_bulleted,
              label: 'Unordered list',
              toolbar: toolbar,
              active: toolbar.isUnorderedList,
              onPressed: toolbar.setUnorderedList,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Indent',
              onPressed: toolbar.canIndent ? toolbar.indent : null,
              icon: const Icon(Icons.format_indent_increase),
            ),
            IconButton(
              tooltip: 'Outdent',
              onPressed: toolbar.canOutdent ? toolbar.outdent : null,
              icon: const Icon(Icons.format_indent_decrease),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Insert code',
              onPressed: onInsertCode,
              icon: const Icon(Icons.code),
            ),
            IconButton(
              tooltip: 'Insert table',
              onPressed: onInsertTable,
              icon: const Icon(Icons.table_chart),
            ),
            IconButton(
              tooltip: 'Insert image',
              onPressed: onInsertImage,
              icon: const Icon(Icons.image),
            ),
            if (inTable) ...<Widget>[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Add row',
                onPressed: onInsertRow,
                icon: const Icon(Icons.table_rows),
              ),
              IconButton(
                tooltip: 'Add column',
                onPressed: onInsertColumn,
                icon: const Icon(Icons.view_column),
              ),
              IconButton(
                tooltip: 'Delete row',
                onPressed: onDeleteRow,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(
                tooltip: 'Delete column',
                onPressed: onDeleteColumn,
                icon: const Icon(Icons.highlight_remove_outlined),
              ),
              IconButton(
                tooltip: 'Merge cells',
                onPressed: onMergeCells,
                icon: const Icon(Icons.call_merge),
              ),
              IconButton(
                tooltip: 'Split cell',
                onPressed: onSplitCell,
                icon: const Icon(Icons.call_split),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showLinkDialog(BuildContext context) async {
    final current = toolbar.linkUrl ?? '';
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Link URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com',
            labelText: 'URL',
          ),
        ),
        actions: <Widget>[
          if (toolbar.linkUrl != null)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result == null) {
      return;
    }
    // Empty string means clear the link.
    toolbar.setLink(result.isEmpty ? null : result);
  }
}

/// A boolean-mark toggle button (bold/italic/underline/…) that highlights
/// when the mark is active across the whole selection and is disabled when
/// the caret isn't inside a text block.
class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.icon,
    required this.label,
    required this.toolbar,
    required this.mark,
  });

  final IconData icon;
  final String label;
  final ToolbarController toolbar;
  final TextMark mark;

  @override
  Widget build(BuildContext context) {
    final active = toolbar.isMarkActive(mark);
    return IconButton.filledTonal(
      tooltip: label,
      isSelected: active,
      onPressed: toolbar.canToggleMark ? () => toolbar.toggleMark(mark) : null,
      icon: Icon(icon),
    );
  }
}

/// A block-type button (heading/paragraph/list) bound to [toolbar] enable +
/// active state. Disables on non-text blocks; highlights when active.
class _BlockTypeButton extends StatelessWidget {
  const _BlockTypeButton({
    required this.icon,
    required this.label,
    required this.toolbar,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final ToolbarController toolbar;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: label,
      isSelected: active,
      onPressed: toolbar.canSetBlockType ? onPressed : null,
      icon: Icon(icon),
    );
  }
}

class _TableContext {
  const _TableContext({
    required this.blockIndex,
    required this.rowIndex,
    required this.columnIndex,
  });

  final int blockIndex;
  final int rowIndex;
  final int columnIndex;
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.controller,
    required this.showDebugOverlay,
    required this.lastEvent,
    required this.onToggleDebugOverlay,
  });

  final WenzRichTextController controller;
  final bool showDebugOverlay;
  final String lastEvent;
  final ValueChanged<bool> onToggleDebugOverlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selection = controller.selection;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Document', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          _MetricRow(
            label: 'Blocks',
            value: '${controller.document.blocks.length}',
          ),
          _MetricRow(
            label: 'Characters',
            value: '${controller.document.plainText.length}',
          ),
          _MetricRow(
            label: 'Undo',
            value: controller.canUndo ? 'ready' : 'empty',
          ),
          _MetricRow(
            label: 'Redo',
            value: controller.canRedo ? 'ready' : 'empty',
          ),
          const SizedBox(height: 20),
          Text('Selection', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Text(
            selection == null
                ? 'Tap a text block to place the caret.'
                : selection.isCollapsed
                ? 'Collapsed at block ${selection.extent.blockIndex}, offset ${selection.extent.offset}.'
                : 'Range ${selection.start.offset} to ${selection.end.offset}.',
            style: theme.textTheme.bodyMedium,
          ),
          if (selection != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'path: ${selection.extent.path.toString()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Events', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Latest controller callback (onChanged / onSelectionChanged / '
            'onCommandExecuted).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              lastEvent,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Debug overlay',
              style: theme.textTheme.bodyMedium,
            ),
            subtitle: Text(
              'Show block id / index / path / offset on the active block.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            value: showDebugOverlay,
            onChanged: onToggleDebugOverlay,
          ),
          const Spacer(),
          Text(
            'Type to insert text. Use Enter, Backspace, Delete, arrows, and Shift+arrows.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

RichTextDocument _sampleDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'title',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Wenz RichText self-owned editor')],
      ),
      TextBlockNode(
        id: 'intro',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(
            text: 'This example is rendered and edited by the local model. ',
          ),
          TextRun(
            text: 'Select text with Shift+arrows',
            attributes: TextAttributes(bold: true, color: 0xFF0F766E),
          ),
          TextRun(text: ', then try the toolbar.'),
        ],
      ),
      TextBlockNode(
        id: 'task',
        type: BlockType.listItem,
        attributes: BlockAttributes(listType: 'task', checked: false),
        content: <InlineNode>[TextRun(text: 'Keep the model deterministic')],
      ),
      TextBlockNode(
        id: 'quote',
        type: BlockType.quote,
        content: <InlineNode>[
          TextRun(text: 'Controller commands own document mutation.'),
        ],
      ),
      CodeBlockNode(
        id: 'code',
        language: 'dart',
        code: 'final json = controller.toJson();',
      ),
      TableBlockNode(
        id: 'table',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'cell-a',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-a-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'Command')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-b',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-b-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'History')],
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
                    content: <InlineNode>[TextRun(text: 'Insert text')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-d',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-d-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'Undo/redo')],
                  ),
                ],
              ),
            ],
          ],
          columnAlignments: <int, String>{1: 'center'},
        ),
      ),
      ImageBlockNode(
        id: 'image',
        assetId: 'https://picsum.photos/seed/wenz/1200/675',
        file: 'sample.jpg',
        width: 1200,
        height: 675,
      ),
    ],
  );
}

DocumentSelection _collapsed(String blockId, int blockIndex, int offset) {
  final position = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockText(blockId),
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}

DocumentSelection _codeCollapsed(String blockId, int blockIndex, int offset) {
  final position = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockCode(blockId),
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}

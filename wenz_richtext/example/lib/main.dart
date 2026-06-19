import 'package:flutter/material.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  runApp(const WenzRichTextExampleApp());
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
  var _nextId = 0;
  var _showDebugOverlay = false;

  @override
  void initState() {
    super.initState();
    _controller = WenzRichTextController(
      document: _sampleDocument(),
      selection: _collapsed('intro', 1, 18),
    )..addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
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
      body: Row(
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
                  onInsertCode: _insertCodeBlock,
                  onInsertTable: _insertTable,
                  onInsertImage: _insertImage,
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
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      index: _controller.document.blocks.length,
      tableId: _newId('table'),
      rowCount: 2,
      columnCount: 3,
    );
  }

  void _insertImage() {
    _controller.insertBlocks(
      index: _controller.document.blocks.length,
      blocks: <BlockNode>[
        ImageBlockNode(
          id: _newId('image'),
          assetId: 'local-preview',
          file: 'preview.png',
          width: 640,
          height: 360,
        ),
      ],
    );
  }

  String _newId(String prefix) {
    _nextId += 1;
    return '$prefix-$_nextId';
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.onInsertCode,
    required this.onInsertTable,
    required this.onInsertImage,
  });

  final WenzRichTextController controller;
  final VoidCallback onInsertCode;
  final VoidCallback onInsertTable;
  final VoidCallback onInsertImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            IconButton.filledTonal(
              tooltip: 'Bold',
              onPressed: () =>
                  controller.formatText(const TextAttributes(bold: true)),
              icon: const Icon(Icons.format_bold),
            ),
            IconButton.filledTonal(
              tooltip: 'Italic',
              onPressed: () =>
                  controller.formatText(const TextAttributes(italic: true)),
              icon: const Icon(Icons.format_italic),
            ),
            IconButton.filledTonal(
              tooltip: 'Clear style',
              onPressed: controller.clearStyle,
              icon: const Icon(Icons.format_clear),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Heading',
              onPressed: () =>
                  controller.setBlockType(type: BlockType.heading, level: 2),
              icon: const Icon(Icons.title),
            ),
            IconButton(
              tooltip: 'Paragraph',
              onPressed: () =>
                  controller.setBlockType(type: BlockType.paragraph),
              icon: const Icon(Icons.notes),
            ),
            IconButton(
              tooltip: 'Task item',
              onPressed: () => controller.setBlockType(
                type: BlockType.listItem,
                listType: 'task',
                checked: false,
              ),
              icon: const Icon(Icons.checklist),
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
          ],
        ),
      ),
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.controller,
    required this.showDebugOverlay,
    required this.onToggleDebugOverlay,
  });

  final WenzRichTextController controller;
  final bool showDebugOverlay;
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
        assetId: 'sample-image',
        file: 'asset-placeholder.png',
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

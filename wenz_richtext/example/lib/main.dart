import 'dart:async';

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
                value:
                    progress.cumulativeBytesLoaded /
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

BlockRendererRegistry _createExampleBlockRenderers() {
  final registry = BlockRendererRegistry();
  WenzRichTextEditor.installDefaultRenderers(registry);
  registry.registerEmbed('crm-card', (_, renderContext) {
    final block = renderContext.block as BlockEmbedNode;
    return WenzObjectBlockSurface(
      renderContext: renderContext,
      child: _CrmCardEmbed(block: block),
    );
  });
  return registry;
}

class _CrmCardEmbed extends StatelessWidget {
  const _CrmCardEmbed({required this.block});

  final BlockEmbedNode block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = block.data['title'] as String? ?? block.displayText;
    final owner = block.data['owner'] as String? ?? 'Unassigned';
    final stage = block.data['stage'] as String? ?? 'Open';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(title),
        subtitle: Text('Owner: $owner · Stage: $stage'),
        trailing: Chip(
          label: Text(block.normalizedEmbedType),
          visualDensity: VisualDensity.compact,
          labelStyle: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _InMemoryDraftAdapter {
  String? latestJson;
  int? latestRevision;
  DateTime? savedAt;

  Future<void> save(AutoSaveSnapshot snapshot) {
    return Future<void>.delayed(const Duration(milliseconds: 120), () {
      latestJson = snapshot.json;
      latestRevision = snapshot.revision;
      savedAt = DateTime.now();
    });
  }
}

const Key _importExportExportMarkdownKey = Key('import-export-export-markdown');
const Key _importExportExportHtmlKey = Key('import-export-export-html');
const Key _importExportLoadMarkdownKey = Key('import-export-load-markdown');
const Key _importExportLoadHtmlKey = Key('import-export-load-html');

const _markdownImportExportDemo = '''
# Markdown import demo

This paragraph includes **bold**, *italic*, and [a link](https://example.com).

- [x] Checked task
- Plain list item

```dart
controller.loadMarkdown(source);
```

| Format | Status |
| --- | --- |
| Markdown | imported |

![diagram](https://example.com/diagram.png "Round-trip caption")

![video](https://example.com/demo.mp4)

[Spec PDF](https://example.com/spec.pdf)
''';

const _htmlImportExportDemo = '''
<h1>HTML import demo</h1>
<p>HTML paragraph with <strong>bold</strong>, <em>italic</em>, <a href="https://example.com">a link</a>, and <img src="https://example.com/inline.png" alt="inline badge" data-caption="Inline badge" width="24" height="24"> inline media.</p>
<ul>
  <li><input type="checkbox" checked disabled> Checked task</li>
  <li>Plain list item</li>
</ul>
<pre><code class="language-dart">controller.loadHtml(source);</code></pre>
<table>
  <tr><td rowspan="2" colspan="2">Merged</td><td>Status</td></tr>
  <tr><td>imported</td></tr>
</table>
<figure>
  <img src="https://example.com/diagram.png" alt="diagram" width="320" data-width="640" data-height="360">
  <figcaption>Round-trip caption</figcaption>
</figure>
<video src="https://example.com/demo.mp4" data-asset-id="video-demo"></video>
<a href="https://example.com/spec.pdf" data-wenz-block="file" data-asset-id="file-demo" data-file="spec.pdf" data-size="4096" data-mime-type="application/pdf">Spec PDF</a>
''';

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
  late final WenzDocumentStatsController _stats;
  late final WenzAutoSaveController _autosave;
  final MediaResolver _mediaResolver = _NetworkImageResolver();
  final BlockRendererRegistry _blockRenderers = _createExampleBlockRenderers();
  final _draftAdapter = _InMemoryDraftAdapter();
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
    _toolbar = ToolbarController(_controller)
      ..addListener(_handleControllerChanged);
    _stats = WenzDocumentStatsController(editor: _controller)
      ..addListener(_handleControllerChanged);
    _autosave = WenzAutoSaveController(
      editor: _controller,
      debounceDuration: const Duration(milliseconds: 800),
      onSave: _draftAdapter.save,
    )..addListener(_handleControllerChanged);
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
      _lastEvent =
          'Command · ${command.description} (${change.after.blocks.length} blocks)';
    };
  }

  @override
  void dispose() {
    _toolbar
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _stats
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _autosave
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
                  stats: _stats.stats,
                  autosave: _autosave.state,
                  draftBytes: _draftAdapter.latestJson?.length ?? 0,
                  showDebugOverlay: _showDebugOverlay,
                  lastEvent: _lastEvent,
                  onSaveNow: () {
                    unawaited(_autosave.saveNow());
                  },
                  onExportMarkdown: () {
                    _showImportExportPreview(
                      format: 'Markdown',
                      source: _controller.toMarkdown(),
                    );
                  },
                  onExportHtml: () {
                    _showImportExportPreview(
                      format: 'HTML',
                      source: _controller.toHtml(),
                    );
                  },
                  onLoadMarkdownDemo: _loadMarkdownImportExportDemo,
                  onLoadHtmlDemo: _loadHtmlImportExportDemo,
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
                    onInsertCallout: _insertCallout,
                    onInsertTable: _insertTable,
                    onInsertImage: _insertImage,
                    onInsertFile: _insertFile,
                    onInsertEmbed: _insertBlockEmbed,
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
                        blockRenderers: _blockRenderers,
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

  void _showImportExportPreview({
    required String format,
    required String source,
  }) {
    _lastEvent = 'Export · $format (${source.length} chars)';
    setState(() {});
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            title: Text('$format export preview'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: SelectableText(
                  source,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _loadMarkdownImportExportDemo() {
    _controller.loadMarkdown(_markdownImportExportDemo);
    _lastEvent =
        'Import · Markdown demo (${_controller.document.blocks.length} blocks)';
    setState(() {});
  }

  void _loadHtmlImportExportDemo() {
    _controller.loadHtml(_htmlImportExportDemo);
    _lastEvent =
        'Import · HTML demo (${_controller.document.blocks.length} blocks)';
    setState(() {});
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

  void _insertCallout() {
    final id = _newId('callout');
    final index = _currentBlockInsertionIndex();
    _controller.insertBlocks(
      index: index,
      blocks: <BlockNode>[
        CalloutBlockNode(
          id: id,
          variant: 'info',
          title: 'Tip',
          icon: '💡',
          content: const <InlineNode>[
            TextRun(text: 'Use the type dropdown to switch callout styles.'),
          ],
        ),
      ],
      selection: _collapsed(id, index, 0),
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

  void _insertFile() {
    final id = _newId('file');
    _controller.insertFile(
      index: _currentBlockInsertionIndex(),
      blockId: id,
      assetId: 'attachment-$id',
      name: 'product-brief.pdf',
      size: 245760,
      mimeType: 'application/pdf',
      downloadUrl: 'https://example.com/files/product-brief.pdf',
      uploadStatus: FileUploadStatus.uploaded,
    );
  }

  void _insertBlockEmbed() {
    final id = _newId('embed');
    _controller.insertBlockEmbed(
      index: _currentBlockInsertionIndex(),
      blockId: id,
      embedType: 'crm-card',
      data: <String, Object?>{
        'recordId': 'crm-$id',
        'title': 'Acme renewal',
        'owner': 'Ada',
        'stage': 'Proposal',
      },
      fallbackText: 'Acme renewal',
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
    required this.onInsertCallout,
    required this.onInsertTable,
    required this.onInsertImage,
    required this.onInsertFile,
    required this.onInsertEmbed,
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
  final VoidCallback onInsertCallout;
  final VoidCallback onInsertTable;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertFile;
  final VoidCallback onInsertEmbed;
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
            IconButton(
              tooltip: 'Formula',
              onPressed: toolbar.canFormatInline
                  ? () => controller.insertFormula('E=mc^2')
                  : null,
              icon: const Icon(Icons.functions),
            ),
            IconButton(
              tooltip: 'Mention',
              onPressed: toolbar.canFormatInline
                  ? () => controller.insertMention('u-demo', 'Ada')
                  : null,
              icon: const Icon(Icons.alternate_email),
            ),
            IconButton(
              tooltip: 'Emoji',
              onPressed: toolbar.canFormatInline
                  ? () => controller.insertEmoji('😀', shortName: 'grinning')
                  : null,
              icon: const Icon(Icons.emoji_emotions),
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
              tooltip: 'Insert callout',
              onPressed: onInsertCallout,
              icon: const Icon(Icons.tips_and_updates),
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
            IconButton(
              tooltip: 'Insert file',
              onPressed: onInsertFile,
              icon: const Icon(Icons.attach_file),
            ),
            IconButton(
              tooltip: 'Insert CRM embed',
              onPressed: onInsertEmbed,
              icon: const Icon(Icons.badge_outlined),
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
    final result = await showWenzLinkEditDialog(
      context: context,
      initialUrl: toolbar.linkUrl ?? '',
      canRemove: toolbar.linkUrl != null,
    );
    if (result == null) {
      return;
    }
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
    required this.stats,
    required this.autosave,
    required this.draftBytes,
    required this.showDebugOverlay,
    required this.lastEvent,
    required this.onSaveNow,
    required this.onExportMarkdown,
    required this.onExportHtml,
    required this.onLoadMarkdownDemo,
    required this.onLoadHtmlDemo,
    required this.onToggleDebugOverlay,
  });

  final WenzRichTextController controller;
  final DocumentStats stats;
  final AutoSaveState autosave;
  final int draftBytes;
  final bool showDebugOverlay;
  final String lastEvent;
  final VoidCallback onSaveNow;
  final VoidCallback onExportMarkdown;
  final VoidCallback onExportHtml;
  final VoidCallback onLoadMarkdownDemo;
  final VoidCallback onLoadHtmlDemo;
  final ValueChanged<bool> onToggleDebugOverlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selection = controller.selection;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Text('Document', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        _MetricRow(label: 'Blocks', value: '${stats.blockCount}'),
        _MetricRow(label: 'Paragraphs', value: '${stats.paragraphCount}'),
        _MetricRow(label: 'Headings', value: '${stats.headingCount}'),
        _MetricRow(label: 'Images', value: '${stats.imageCount}'),
        _MetricRow(label: 'Words', value: '${stats.wordCount}'),
        _MetricRow(label: 'Characters', value: '${stats.characterCount}'),
        _MetricRow(
          label: 'Text chars',
          value: '${stats.characterCountExcludingWhitespace}',
        ),
        _MetricRow(
          label: 'Read time',
          value: stats.readingTimeMinutes == 0
              ? '0 min'
              : '${stats.readingTimeMinutes} min',
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
        Text('Autosave', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Debounced draft save through an external adapter.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _MetricRow(
          label: 'Status',
          value: _autoSaveStatusLabel(autosave.status),
        ),
        _MetricRow(label: 'Dirty', value: autosave.isDirty ? 'yes' : 'clean'),
        _MetricRow(label: 'Revision', value: '${autosave.revision}'),
        _MetricRow(label: 'Draft bytes', value: '$draftBytes'),
        _MetricRow(
          label: 'Last saved',
          value: _formatClockTime(autosave.lastSavedAt),
        ),
        if (autosave.error != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            'Error: ${autosave.error}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: autosave.isSaving ? null : onSaveNow,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save now'),
          ),
        ),
        const SizedBox(height: 20),
        Text('Import/export demo', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Preview the current document as Markdown/HTML, or replace it with '
          'codec samples that cover links, lists, code, tables, images, video, '
          'and file fallbacks.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              key: _importExportExportMarkdownKey,
              onPressed: onExportMarkdown,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Export Markdown'),
            ),
            OutlinedButton.icon(
              key: _importExportExportHtmlKey,
              onPressed: onExportHtml,
              icon: const Icon(Icons.code),
              label: const Text('Export HTML'),
            ),
            OutlinedButton.icon(
              key: _importExportLoadMarkdownKey,
              onPressed: onLoadMarkdownDemo,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Load Markdown sample'),
            ),
            OutlinedButton.icon(
              key: _importExportLoadHtmlKey,
              onPressed: onLoadHtmlDemo,
              icon: const Icon(Icons.file_download_done_outlined),
              label: const Text('Load HTML sample'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Markdown reloads file blocks as linked text; Wenz HTML preserves '
          'file/video data-* metadata.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('Debug overlay', style: theme.textTheme.bodyMedium),
          subtitle: Text(
            'Show block id / index / path / offset on the active block.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          value: showDebugOverlay,
          onChanged: onToggleDebugOverlay,
        ),
        const SizedBox(height: 20),
        Text(
          'Type to insert text. Use Enter, Backspace, Delete, arrows, and Shift+arrows.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

String _autoSaveStatusLabel(AutoSaveStatus status) {
  return switch (status) {
    AutoSaveStatus.clean => 'clean',
    AutoSaveStatus.dirty => 'dirty',
    AutoSaveStatus.scheduled => 'scheduled',
    AutoSaveStatus.saving => 'saving',
    AutoSaveStatus.failed => 'failed',
  };
}

String _formatClockTime(DateTime? value) {
  if (value == null) {
    return '—';
  }
  final local = value.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}:'
      '${_twoDigits(local.second)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

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
        id: 'inline-embeds',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(text: 'Inline embeds: '),
          InlineEmbed(
            embedType: 'formula',
            data: <String, Object?>{'text': 'E=mc^2'},
          ),
          TextRun(text: ' '),
          InlineEmbed(
            embedType: 'emoji',
            data: <String, Object?>{'emoji': '😀', 'shortName': 'grinning'},
          ),
          TextRun(text: ' '),
          InlineEmbed(
            embedType: 'mention',
            data: <String, Object?>{'id': 'u-demo', 'label': 'Ada'},
          ),
        ],
      ),
      TextBlockNode(
        id: 'quote',
        type: BlockType.quote,
        content: <InlineNode>[
          TextRun(text: 'Controller commands own document mutation.'),
        ],
      ),
      CalloutBlockNode(
        id: 'callout',
        variant: 'success',
        title: 'Callout ready',
        icon: '✅',
        content: <InlineNode>[
          TextRun(text: 'The default renderer supports type switching.'),
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
      FileBlockNode(
        id: 'file-sample',
        assetId: 'sample-attachment',
        name: 'release-notes.pdf',
        size: 532480,
        mimeType: 'application/pdf',
        downloadUrl: 'https://example.com/files/release-notes.pdf',
        uploadStatus: FileUploadStatus.uploaded,
      ),
      BlockEmbedNode(
        id: 'crm-sample',
        embedType: 'crm-card',
        data: <String, Object?>{
          'recordId': 'crm-1001',
          'title': 'Acme renewal',
          'owner': 'Ada',
          'stage': 'Proposal',
        },
        fallbackText: 'Acme renewal',
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

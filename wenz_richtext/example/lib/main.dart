import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'example_video_player.dart';
import 'test_host.dart';

void main() {
  runApp(const WenzRichTextExampleApp());
}

const _exampleSeedColor = Color(0xFF0F766E);
const _themeToggleKey = ValueKey<String>('wenz-example-theme-toggle');
const _editorSurfaceKey = ValueKey<String>('wenz-example-editor-surface');

ThemeData _exampleTheme(Brightness brightness) {
  final background =
      brightness == Brightness.dark ? Colors.black : Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: _exampleSeedColor,
    brightness: brightness,
  ).copyWith(surface: background);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    useMaterial3: true,
  );
}

Color _exampleEditorBackground(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.black
      : Colors.white;
}

/// Example [MediaResolver]: images use [Image.network], while videos are handed
/// to [ExampleVideoPlayer] (asset / network / local-file sources). Blocks
/// without a usable URL return `null` so the built-in placeholder remains
/// visible.
class _ExampleMediaResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is ImageBlockNode) {
      return _resolveImage(block);
    }
    if (block is VideoBlockNode) {
      return _resolveVideo(context, block);
    }
    return null;
  }

  Widget? _resolveImage(ImageBlockNode block) {
    final url = block.assetId;
    if (!url.startsWith('http')) {
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

  Widget? _resolveVideo(BuildContext context, VideoBlockNode block) {
    // Dispatch by source type so the real player plays registered assets,
    // http(s) streams, and local file paths. An empty effective source still
    // returns null, preserving the built-in placeholder fallback for blocks
    // without a usable URL (e.g. the `video-placeholder` sample).
    final source = block.effectivePlaybackUrl.trim();
    if (source.isEmpty) {
      return null;
    }
    final ExampleVideoSource videoSource;
    if (source.startsWith('http://') || source.startsWith('https://')) {
      videoSource = ExampleVideoSource.network(source);
    } else if (source.startsWith('assets/')) {
      videoSource = ExampleVideoSource.asset(source);
    } else {
      videoSource = ExampleVideoSource.file(source);
    }
    return ExampleVideoPlayer(
      source: videoSource,
      aspectRatio: block.effectiveAspectRatio,
      coverUrl: block.coverUrl,
    );
  }
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

class WenzRichTextExampleApp extends StatefulWidget {
  const WenzRichTextExampleApp({super.key});

  @override
  State<WenzRichTextExampleApp> createState() => _WenzRichTextExampleAppState();
}

class _WenzRichTextExampleAppState extends State<WenzRichTextExampleApp> {
  var _themeMode = ThemeMode.light;

  void _toggleThemeMode() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wenz RichText',
      debugShowCheckedModeBanner: false,
      theme: _exampleTheme(Brightness.light),
      darkTheme: _exampleTheme(Brightness.dark),
      themeMode: _themeMode,
      home: EditorWorkbench(
        themeMode: _themeMode,
        onToggleThemeMode: _toggleThemeMode,
      ),
    );
  }
}

class EditorWorkbench extends StatefulWidget {
  const EditorWorkbench({
    super.key,
    required this.themeMode,
    required this.onToggleThemeMode,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleThemeMode;

  @override
  State<EditorWorkbench> createState() => _EditorWorkbenchState();
}

class _EditorWorkbenchState extends State<EditorWorkbench> {
  // The bootstrap owns the controller, the registries, and the derived
  // controllers in one assembly step. The example keeps non-nullable handles to
  // the four controllers it actually drives (toolbar / stats / autosave + the
  // controller itself) so the toolbar and inspector stay terse; the slash-menu
  // controller is wired into the editor automatically by buildEditor.
  late final WenzEditorBootstrap _bootstrap;
  late final WenzRichTextController _controller;
  late final ToolbarController _toolbar;
  late final WenzDocumentStatsController _stats;
  late final WenzAutoSaveController _autosave;
  final MediaResolver _mediaResolver = _ExampleMediaResolver();
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
    _bootstrap = WenzEditorBootstrap.create(
      WenzEditorConfiguration(
        document: _sampleDocument(),
        selection: _collapsed('intro', 1, 18),
        mediaResolver: _mediaResolver,
        // CRM record card as a business block embed. The bootstrap seeds the
        // built-in renderers first and layers this builder on top, so default
        // blocks keep working alongside the embed.
        blockEmbedRenderers: <String, BlockRendererBuilder>{
          'crm-card': (_, renderContext) {
            final block = renderContext.block as BlockEmbedNode;
            return WenzObjectBlockSurface(
              renderContext: renderContext,
              child: _CrmCardEmbed(block: block),
            );
          },
        },
        // Autosave is opt-in: it needs a host-supplied sink. The example
        // persists snapshots in memory and reports state in the inspector.
        enableAutosave: true,
        onAutosave: _draftAdapter.save,
        autosaveDebounce: const Duration(milliseconds: 800),
        // The example drives the toolbar / stats / slash-menu but does not
        // expose a find&replace or outline surface, so those derived
        // controllers stay off and the editor is wired exactly as before.
        enableFindReplace: false,
        enableOutline: false,
        // The three business-integration callbacks fire synchronously before
        // notifyListeners, so reading controller state here is safe.
        onChanged: (doc) {
          _lastEvent = 'Doc changed · blocks=${doc.blocks.length}';
        },
        onSelectionChanged: (selection) {
          if (selection == null) {
            _lastEvent = 'Selection cleared';
          } else if (selection.isCollapsed) {
            _lastEvent =
                'Selection · caret @block ${selection.extent.blockIndex}+${selection.extent.offset}';
          } else {
            _lastEvent =
                'Selection · range ${selection.start.offset}→${selection.end.offset}';
          }
        },
        onCommandExecuted: (command, change) {
          _lastEvent =
              'Command · ${command.description} (${change.after.blocks.length} blocks)';
        },
      ),
    );
    _controller = _bootstrap.controller;
    _toolbar = _bootstrap.toolbarController!;
    _stats = _bootstrap.statsController!;
    _autosave = _bootstrap.autosaveController!;
    // Drive setState from the assembled controllers so the toolbar and inspector
    // stay in sync with the document, selection, stats, and autosave.
    _controller.addListener(_handleControllerChanged);
    _toolbar.addListener(_handleControllerChanged);
    _stats.addListener(_handleControllerChanged);
    _autosave.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    // Detach the host setState listeners before the bootstrap releases the
    // controllers. The bootstrap disposes the derived controllers (listeners of
    // the editor) before the controller itself, matching the hand-wired order.
    _controller.removeListener(_handleControllerChanged);
    _toolbar.removeListener(_handleControllerChanged);
    _stats.removeListener(_handleControllerChanged);
    _autosave.removeListener(_handleControllerChanged);
    _bootstrap.dispose();
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
            tooltip: '撤销',
            onPressed: _controller.canUndo ? _controller.undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: '重做',
            onPressed: _controller.canRedo ? _controller.redo : null,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            key: _themeToggleKey,
            tooltip: widget.themeMode == ThemeMode.dark
                ? '切换浅色主题'
                : '切换深色主题',
            onPressed: widget.onToggleThemeMode,
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
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
                    onInsertVideo: _insertVideo,
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
                      key: _editorSurfaceKey,
                      color: _exampleEditorBackground(context),
                      child: _bootstrap.buildEditor(
                        autofocus: true,
                        padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
                        blockSpacing: 14,
                        textStyle: theme.textTheme.bodyLarge,
                        defaultTextColor: theme.colorScheme.onSurface,
                        showDebugOverlay: _showDebugOverlay,
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

  void _insertVideo() {
    final id = _newId('video');
    _toolbar.insertVideo(
      blockId: id,
      assetId: 'video-$id',
      // Insert a real playable source (local asset) instead of the dead
      // example.com URL, so the inserted block plays in the example app.
      file: 'assets/videos/sample.mp4',
      coverUrl: 'https://picsum.photos/seed/$id/960/540',
      title: 'Inserted product tour',
      description: 'Played by the example MediaResolver + media_kit player.',
      aspectRatio: VideoBlockNode.defaultAspectRatio,
      uploadStatus: FileUploadStatus.uploaded,
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
    required this.onInsertVideo,
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
  final VoidCallback onInsertVideo;
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
              label: '加粗',
              toolbar: toolbar,
              mark: TextMark.bold,
            ),
            _MarkButton(
              icon: Icons.format_italic,
              label: '斜体',
              toolbar: toolbar,
              mark: TextMark.italic,
            ),
            _MarkButton(
              icon: Icons.format_underline,
              label: '下划线',
              toolbar: toolbar,
              mark: TextMark.underline,
            ),
            _MarkButton(
              icon: Icons.format_strikethrough,
              label: '删除线',
              toolbar: toolbar,
              mark: TextMark.lineThrough,
            ),
            _MarkButton(
              icon: Icons.comment,
              label: '备注',
              toolbar: toolbar,
              mark: TextMark.remark,
            ),
            _TextColorButton(
              label: '品牌色',
              color: const Color(0xFF0F766E),
              toolbar: toolbar,
            ),
            _TextColorButton(
              label: '强调色',
              color: const Color(0xFFD81B60),
              toolbar: toolbar,
            ),
            IconButton(
              tooltip: toolbar.textColorMixed
                  ? '清除混合字体颜色'
                  : toolbar.textColor == null
                      ? '无内联字体颜色'
                      : '清除字体颜色',
              onPressed:
                  toolbar.canFormatInline ? toolbar.clearTextColor : null,
              icon: Icon(
                Icons.format_color_reset,
                color: toolbar.textColor == null
                    ? null
                    : Color(toolbar.textColor!),
              ),
            ),
            IconButton(
              tooltip: '清除样式',
              onPressed: toolbar.canFormatInline ? toolbar.clearStyle : null,
              icon: const Icon(Icons.format_clear),
            ),
            IconButton(
              tooltip: '链接',
              isSelected: toolbar.linkUrl != null,
              onPressed: toolbar.canSetLink
                  ? () => _showLinkDialog(context)
                  : null,
              icon: const Icon(Icons.link),
            ),
            IconButton(
              tooltip: '公式',
              onPressed: toolbar.canFormatInline
                  ? () => controller.insertFormula('E=mc^2')
                  : null,
              icon: const Icon(Icons.functions),
            ),
            IconButton(
              tooltip: '提及',
              onPressed: toolbar.canFormatInline
                  ? () => controller.insertMention('u-demo', 'Ada')
                  : null,
              icon: const Icon(Icons.alternate_email),
            ),
            IconButton(
              tooltip: '表情',
              onPressed: toolbar.canFormatInline
                  ? () => controller.insertEmoji('😀', shortName: 'grinning')
                  : null,
              icon: const Icon(Icons.emoji_emotions),
            ),
            const SizedBox(width: 8),
            _BlockTypeButton(
              icon: Icons.title,
              label: '一级标题',
              toolbar: toolbar,
              active: toolbar.isHeading(1),
              onPressed: () => toolbar.setHeading(1),
            ),
            _BlockTypeButton(
              icon: Icons.title,
              label: '二级标题',
              toolbar: toolbar,
              active: toolbar.isHeading(2),
              onPressed: () => toolbar.setHeading(2),
            ),
            _BlockTypeButton(
              icon: Icons.title,
              label: '三级标题',
              toolbar: toolbar,
              active: toolbar.isHeading(3),
              onPressed: () => toolbar.setHeading(3),
            ),
            _BlockTypeButton(
              icon: Icons.notes,
              label: '段落',
              toolbar: toolbar,
              active: toolbar.isParagraph,
              onPressed: toolbar.setParagraph,
            ),
            _BlockTypeButton(
              icon: Icons.format_quote,
              label: '引用',
              toolbar: toolbar,
              active: toolbar.isQuoteBlock,
              onPressed: toolbar.toggleQuoteBlock,
            ),
            const SizedBox(width: 8),
            _BlockTypeButton(
              icon: Icons.checklist,
              label: '任务列表',
              toolbar: toolbar,
              active: toolbar.isTodo,
              onPressed: toolbar.setTodo,
            ),
            _BlockTypeButton(
              icon: Icons.format_list_numbered,
              label: '有序列表',
              toolbar: toolbar,
              active: toolbar.isOrderedList,
              onPressed: toolbar.setOrderedList,
            ),
            _BlockTypeButton(
              icon: Icons.format_list_bulleted,
              label: '无序列表',
              toolbar: toolbar,
              active: toolbar.isUnorderedList,
              onPressed: toolbar.setUnorderedList,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '增加缩进',
              onPressed: toolbar.canIndent ? toolbar.indent : null,
              icon: const Icon(Icons.format_indent_increase),
            ),
            IconButton(
              tooltip: '减少缩进',
              onPressed: toolbar.canOutdent ? toolbar.outdent : null,
              icon: const Icon(Icons.format_indent_decrease),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '插入代码',
              onPressed: onInsertCode,
              icon: const Icon(Icons.code),
            ),
            IconButton(
              tooltip: '插入提示块',
              onPressed: onInsertCallout,
              icon: const Icon(Icons.tips_and_updates),
            ),
            IconButton(
              tooltip: '插入表格',
              onPressed: onInsertTable,
              icon: const Icon(Icons.table_chart),
            ),
            IconButton(
              tooltip: '插入图片',
              onPressed: onInsertImage,
              icon: const Icon(Icons.image),
            ),
            IconButton(
              tooltip: '插入视频',
              onPressed: toolbar.canInsertVideo ? onInsertVideo : null,
              icon: const Icon(Icons.smart_display),
            ),
            IconButton(
              tooltip: '插入文件',
              onPressed: onInsertFile,
              icon: const Icon(Icons.attach_file),
            ),
            IconButton(
              tooltip: '插入客户关系管理嵌入',
              onPressed: onInsertEmbed,
              icon: const Icon(Icons.badge_outlined),
            ),
            if (inTable) ...<Widget>[
              const SizedBox(width: 8),
              IconButton(
                tooltip: '添加行',
                onPressed: onInsertRow,
                icon: const Icon(Icons.table_rows),
              ),
              IconButton(
                tooltip: '添加列',
                onPressed: onInsertColumn,
                icon: const Icon(Icons.view_column),
              ),
              IconButton(
                tooltip: '删除行',
                onPressed: onDeleteRow,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(
                tooltip: '删除列',
                onPressed: onDeleteColumn,
                icon: const Icon(Icons.highlight_remove_outlined),
              ),
              IconButton(
                tooltip: '合并单元格',
                onPressed: onMergeCells,
                icon: const Icon(Icons.call_merge),
              ),
              IconButton(
                tooltip: '拆分单元格',
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

class _TextColorButton extends StatelessWidget {
  const _TextColorButton({
    required this.label,
    required this.color,
    required this.toolbar,
  });

  final String label;
  final Color color;
  final ToolbarController toolbar;

  @override
  Widget build(BuildContext context) {
    final active =
        toolbar.textColor == color.toARGB32() && !toolbar.textColorMixed;
    return IconButton.filledTonal(
      tooltip: label,
      isSelected: active,
      onPressed: toolbar.canFormatInline
          ? () => toolbar.setTextColor(color)
          : null,
      icon: Icon(Icons.format_color_text, color: color),
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
      VideoBlockNode(
        id: 'video-placeholder',
        assetId: '',
        title: 'Video upload placeholder',
        description: 'No playback URL yet; the built-in placeholder is used.',
        uploadStatus: FileUploadStatus.pending,
      ),
      VideoBlockNode(
        id: 'video-sample',
        assetId: 'video-sample-asset',
        // Point at the local asset registered in example/pubspec.yaml
        // (copied from d:/video). The example MediaResolver reads the
        // `assets/` prefix as a real playback source, so this block plays on
        // startup. `playbackUrl` stays empty so it is never a dead example.com
        // URL; `effectivePlaybackUrl` falls back to `file`.
        file: 'assets/videos/sample.mp4',
        coverUrl: 'https://picsum.photos/seed/wenz-video/960/540',
        title: 'Sample product walkthrough',
        description: 'Played by the example MediaResolver + media_kit player.',
        aspectRatio: VideoBlockNode.defaultAspectRatio,
        uploadStatus: FileUploadStatus.uploaded,
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

import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'example_video_player.dart';
import 'flowchart/flowchart_model.dart';
import 'flowchart/flowchart_plugin.dart';
import 'flowchart/flowchart_view.dart';
import 'local_image_view.dart';
import 'outline_panel.dart';
import 'test_host.dart';
import 'ai/conversation_list_page.dart';

void main() {
  runApp(const WenzRichTextExampleApp());
}

const _exampleSeedColor = Color(0xFF0F766E);
const _exampleFontFamily = '微软雅黑';
const _themeToggleKey = ValueKey<String>('wenz-example-theme-toggle');
const _editorSurfaceKey = ValueKey<String>('wenz-example-editor-surface');
const double _topBarActionExtent = 48.0;
const double _topBarActionTrailingPadding = 8.0;
const double _topBarActionsWidth =
    _topBarActionExtent * 6 + _topBarActionTrailingPadding;
const _resolverVideoPlayerBorderRadius = BorderRadius.zero;
const _imageFileTypeGroup = XTypeGroup(
  label: 'Images',
  extensions: <String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
  mimeTypes: <String>[
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
  ],
);

const List<WenzMentionCandidate> _exampleMentionCandidates =
    <WenzMentionCandidate>[
  WenzMentionCandidate(
    id: 'u-ada',
    label: 'Ada Lovelace',
    description: 'Product architecture',
    data: <String, Object?>{
      'email': 'ada@example.com',
      'department': 'Product',
    },
  ),
  WenzMentionCandidate(
    id: 'u-grace',
    label: 'Grace Hopper',
    description: 'Compiler platform',
    data: <String, Object?>{
      'email': 'grace@example.com',
      'department': 'Engineering',
    },
  ),
  WenzMentionCandidate(
    id: 'u-alan',
    label: 'Alan Turing',
    description: 'Research review',
    data: <String, Object?>{
      'email': 'alan@example.com',
      'department': 'Research',
    },
  ),
  WenzMentionCandidate(
    id: 'team-design',
    label: 'Design Team',
    description: 'Shared design channel',
    data: <String, Object?>{
      'kind': 'team',
      'department': 'Design',
    },
  ),
];

Future<List<WenzMentionCandidate>> _searchExampleMentions(
  WenzMentionSearchRequest request,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 160));
  final query = request.query.trim().toLowerCase();
  if (query.isEmpty) {
    return _exampleMentionCandidates;
  }
  return _exampleMentionCandidates.where((candidate) {
    final searchable = <String>[
      candidate.id,
      candidate.label,
      candidate.description ?? '',
      ...candidate.data.values.whereType<String>(),
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }).toList(growable: false);
}

ThemeData _exampleTheme(Brightness brightness) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: _exampleSeedColor,
    brightness: brightness,
  );
  final background = brightness == Brightness.dark
      ? baseScheme.surfaceContainer
      : Colors.white;
  final scheme = baseScheme.copyWith(surface: background);
  return ThemeData(
    colorScheme: scheme,
    fontFamily: _exampleFontFamily,
    scaffoldBackgroundColor: background,
    useMaterial3: true,
  );
}

Color _exampleEditorBackground(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceContainer
      : Colors.white;
}

/// Example [MediaResolver]: images use [Image.network] or the same local-file
/// helper for toolbar selections, external image paste/drop temp files, and
/// file:// URIs; videos are handed to [ExampleVideoPlayer] (asset / network /
/// local-file sources). Blocks without a usable source return `null` so the
/// built-in placeholder remains visible; local file failures render helper
/// fallbacks.
class _ExampleMediaResolver implements MediaResolver {
  const _ExampleMediaResolver({this.videoPlaybackFactory});

  final ExampleVideoPlaybackFactory? videoPlaybackFactory;

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
    final url = block.assetId.trim();
    if (url.startsWith('http')) {
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
    final localImage = buildLocalImageView(block.file);
    if (localImage == null) {
      return null;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: localImage,
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
    final entry = WenzRichTextMediaResolveScope.maybeVideoEntryOf(context);
    if (entry == WenzRichTextVideoMediaResolveEntry.dialog) {
      // `dialog` is the resolver-entry compatibility name; the editor now
      // hosts this player on a viewport-sized, square-corner fullscreen route.
      return ExampleVideoPlayer.fullscreen(
        source: videoSource,
        aspectRatio: block.effectiveAspectRatio,
        coverUrl: block.coverUrl,
        playbackFactory: videoPlaybackFactory,
      );
    }
    // The editor frame owns embedded rounded clipping. Keep the inline resolved
    // player square so it does not carry an inner ClipRRect(8) inside the block.
    return ExampleVideoPlayer(
      source: videoSource,
      aspectRatio: block.effectiveAspectRatio,
      coverUrl: block.coverUrl,
      borderRadius: _resolverVideoPlayerBorderRadius,
      playbackFactory: videoPlaybackFactory,
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

> ## Quoted heading
> 1. Quoted ordered item
> 1. [x] Quoted ordered todo

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
<blockquote>
  <h2>Quoted heading</h2>
  <ol>
    <li>Quoted ordered item</li>
    <li><input type="checkbox" checked disabled> Quoted ordered todo</li>
  </ol>
</blockquote>
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
  const WenzRichTextExampleApp({
    super.key,
    this.videoPlaybackFactory,
  });

  final ExampleVideoPlaybackFactory? videoPlaybackFactory;

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
        videoPlaybackFactory: widget.videoPlaybackFactory,
      ),
    );
  }
}

class EditorWorkbench extends StatefulWidget {
  const EditorWorkbench({
    super.key,
    required this.themeMode,
    required this.onToggleThemeMode,
    this.videoPlaybackFactory,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleThemeMode;
  final ExampleVideoPlaybackFactory? videoPlaybackFactory;

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
  late final WenzOutlineController _outline;
  late final MediaResolver _mediaResolver;
  final _draftAdapter = _InMemoryDraftAdapter();

  // AI conversation module — initialized once at startup.
  final AIConfigManager _aiConfigManager = AIConfigManager();
  late final ConversationManager _aiConversationManager;

  var _nextId = 0;
  var _showDebugOverlay = false;
  var _isPickingImage = false;

  // Side-panel toggles. Find/replace docks above the editor; comments dock as
  // a sidebar (desktop) or a bottom sheet (mobile).
  var _showFindReplace = false;
  var _showComments = false;
  late final List<CommentThread> _commentThreads;

  /// Most recent controller callback event, shown in the inspector's Events
  /// section as a live demonstration of onChanged / onSelectionChanged /
  /// onCommandExecuted (acceptance task B5).
  String _lastEvent = '—';

  @override
  void initState() {
    super.initState();
    _mediaResolver = _ExampleMediaResolver(
      videoPlaybackFactory: widget.videoPlaybackFactory,
    );
    _bootstrap = WenzEditorBootstrap.create(
      WenzEditorConfiguration(
        document: _sampleDocument(),
        selection: _collapsed('intro', 1, 18),
        mediaResolver: _mediaResolver,
        mentionSearch: _searchExampleMentions,
        onMentionTap: _showMentionDetails,
        // Link opening is host policy. The core package reports the link URL
        // and document position; the example uses url_launcher on the app side.
        onOpenLink: (url, _) => _openLink(url),
        // Keep external image input enabled in the example so local image files
        // inserted from the toolbar, platform image paste adapters, or file
        // drops all flow into ImageBlockNode.file and the resolver below.
        enableExternalImageInput: true,
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
          // Flowchart via the config-injection path. Registered here AND
          // through FlowchartPlugin (see `plugins` below) so the example
          // demonstrates both integration paths side by side. The bootstrap
          // applies host configuration last (defaults → plugins → host), so
          // this entry overrides the plugin's identical builder and wins —
          // exercising the host-overrides-plugin merge rule. Either path alone
          // is sufficient; pick one in production. Dragging is gated on
          // `renderContext.canEdit` inside the view, and a finished drag writes
          // the new coordinates back through `updateBlockEmbed` (history,
          // callbacks, and the permission gate all apply).
          kFlowchartEmbedType: flowchartRendererBuilder(
            onWriteBack: (blockId, data) => _controller.updateBlockEmbed(
              blockId: blockId,
              data: data,
            ),
          ),
        },
        // `/流程图` slash entry + toolbar descriptor via the config-injection
        // path. FlowchartPlugin (below) contributes the same items; host
        // configuration wins on the shared id because it is applied last.
        slashMenuItems: <SlashMenuItem>[flowchartSlashMenuItem()],
        toolbarItems: <WenzToolbarItem>[flowchartToolbarItem()],
        // Flowchart via the reusable-plugin path: install() registers the
        // renderer, slash item, and toolbar item in one step, reusing the same
        // builders/descriptors as the config-injection entries above. Any host
        // can drop FlowchartPlugin() into this list for the full flowchart
        // surface without touching its own configuration maps — the path to
        // choose when the same component is shared across multiple hosts.
        plugins: <WenzRichTextPlugin>[const FlowchartPlugin()],
        // Mermaid diagrams: opt-in via the configuration flag and independent
        // from the custom Flowchart embed above. The preview uses the package's
        // pure Flutter painter, so the example needs no WebView, native
        // bridge, network service, or external process.
        enableMermaidDiagrams: true,
        // Autosave is opt-in: it needs a host-supplied sink. The example
        // persists snapshots in memory and reports state in the inspector.
        enableAutosave: true,
        onAutosave: _draftAdapter.save,
        autosaveDebounce: const Duration(milliseconds: 800),
        // The example drives the toolbar / stats / slash-menu and renders an
        // outline tree on the right, so the outline controller is enabled; the
        // find&replace surface stays off. The editor is wired exactly as before.
        enableFindReplace: true,
        enableOutline: true,
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
    _outline = _bootstrap.outlineController!;
    // Drive setState from the assembled controllers so the toolbar, inspector,
    // and outline tree stay in sync with the document, selection, stats,
    // autosave, and outline (fold) state.
    _controller.addListener(_handleControllerChanged);
    _toolbar.addListener(_handleControllerChanged);
    _stats.addListener(_handleControllerChanged);
    _autosave.addListener(_handleControllerChanged);
    _outline.addListener(_handleControllerChanged);

    // Initialize AI conversation module.
    _aiConversationManager = ConversationManager();
    unawaited(_aiConfigManager.initialize());
    unawaited(_aiConversationManager.initialize(_aiConfigManager));

    // Sample comment threads anchored to the seed document, so the comment
    // sidebar / mobile bottom sheet has content to render.
    _commentThreads = _sampleCommentThreads();
  }

  /// Find/replace toggle — docks the panel above the editor on every form
  /// factor (it is a bar, not a sidebar).
  void _toggleFindReplace() {
    setState(() {
      _showFindReplace = !_showFindReplace;
    });
  }

  /// Comments toggle — on phone-sized surfaces the sidebar opens as a
  /// full-width bottom sheet; on wide surfaces it docks as a fixed-width
  /// sidebar overlay on the right.
  void _toggleComments(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).shortestSide < 600;
    if (isMobile) {
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (sheetContext) => SizedBox(
            // The sidebar's inner list uses Expanded, so it needs a bounded
            // height; cap the sheet at 60% of the viewport.
            height: MediaQuery.sizeOf(sheetContext).height * 0.6,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: _buildCommentSidebar(),
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _showComments = !_showComments;
    });
  }

  Widget _buildCommentSidebar() {
    return WenzCommentSidebar(
      threads: _commentThreads,
      onSelectThread: (thread) {
        _lastEvent = 'Comment · ${thread.id}';
        setState(() {});
      },
    );
  }

  List<CommentThread> _sampleCommentThreads() {
    final created = DateTime(2026, 7, 1, 10, 0);
    return <CommentThread>[
      CommentThread(
        id: 'comment-intro',
        anchor: CommentAnchor(
          blockId: 'intro',
          blockIndex: 1,
          path: PositionPath.blockText('intro'),
          startOffset: 0,
          endOffset: 40,
        ),
        messages: <CommentEntry>[
          CommentEntry(
            id: 'm1',
            authorName: 'Ada',
            text: 'Sharpen the intro — lead with the value prop.',
            createdAt: created,
          ),
        ],
        createdAt: created,
      ),
      CommentThread(
        id: 'comment-task',
        anchor: CommentAnchor(
          blockId: 'task',
          blockIndex: 2,
          path: PositionPath.blockText('task'),
          startOffset: 0,
          endOffset: 10,
        ),
        messages: <CommentEntry>[
          CommentEntry(
            id: 'm2',
            authorName: 'Grace',
            text: 'Should this be checked off already?',
            createdAt: created,
          ),
        ],
        createdAt: created,
        status: CommentThreadStatus.resolved,
        resolvedAt: created,
      ),
    ];
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
    _outline.removeListener(_handleControllerChanged);
    _bootstrap.dispose();
    _aiConfigManager.dispose();
    _aiConversationManager.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openAiConversations(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationListPage(
          conversationManager: _aiConversationManager,
          configManager: _aiConfigManager,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Phone-sized surfaces (shortestSide < 600) collapse the side panels into a
    // Drawer so the editor gets the full width; wider surfaces keep the original
    // three-column body. The breakpoint matches EditorTokens' mobile split.
    final isCompact = MediaQuery.sizeOf(context).shortestSide < 600;
    final useMobileToolbar = _bootstrap.shouldUseMobileLayout(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wenz RichText',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          _ExampleTopBarActions(
            canUndo: _controller.canUndo,
            canRedo: _controller.canRedo,
            onUndo: _controller.undo,
            onRedo: _controller.redo,
            onOpenAiConversations: () => _openAiConversations(context),
            onToggleFindReplace: _toggleFindReplace,
            showFindReplace: _showFindReplace,
            onToggleComments: () => _toggleComments(context),
            showComments: _showComments,
            themeMode: widget.themeMode,
            onToggleThemeMode: widget.onToggleThemeMode,
          ),
        ],
      ),
      // On phone-sized screens the inspector + outline move into a Drawer. The
      // AppBar auto-shows the menu toggle whenever a drawer is attached, so no
      // custom leading button is needed; on wide screens there is no drawer
      // and the leading slot stays empty as before.
      drawer: isCompact ? _buildSidePanelsDrawer(theme) : null,
      body: WenzEditorTestHost(
        controller: _controller,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (isCompact) {
              return _buildEditorColumn(
                theme,
                context,
                useMobileToolbar: useMobileToolbar,
              );
            }
            return Row(
              children: <Widget>[
                SizedBox(width: 280, child: _buildInspectorPanel(theme)),
                Expanded(
                  // Comment sidebar docks over the editor's right edge on wide
                  // surfaces (fixed 320 width); on phones it is a bottom sheet.
                  child: Stack(
                    children: <Widget>[
                      _buildEditorColumn(
                        theme,
                        context,
                        useMobileToolbar: useMobileToolbar,
                      ),
                      if (_showComments)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: _buildCommentSidebar(),
                        ),
                    ],
                  ),
                ),
                _buildOutlineRail(theme),
              ],
            );
          },
        ),
      ),
    );
  }

  WenzDefaultDesktopToolbarActions _desktopToolbarActions() {
    return WenzDefaultDesktopToolbarActions(
      onInsertImage: (_) => _insertImage(),
      onInsertVideo: (_) => _insertVideo(),
      onInsertFile: (_) => _insertFile(),
      onInsertBlockEmbed: (_) => _insertBlockEmbed(),
      isPickingImage: _isPickingImage,
    );
  }

  WenzDefaultMobileToolbarActions _mobileToolbarActions() {
    return WenzDefaultMobileToolbarActions(
      onInsertImage: (_) => _insertImage(),
      onInsertVideo: (_) => _insertVideo(),
      onInsertFile: (_) => _insertFile(),
      onInsertBlockEmbed: (_) => _insertBlockEmbed(),
      isPickingImage: _isPickingImage,
    );
  }

  /// Editor column shared by compact and wide layouts.
  ///
  /// Desktop layout keeps the toolbar above the editor. Mobile layout puts the
  /// toolbar at the bottom so the fixed main bar and expanded mobile panels take
  /// layout space instead of covering find/replace or editor content.
  Widget _buildEditorColumn(
    ThemeData theme,
    BuildContext context, {
    required bool useMobileToolbar,
  }) {
    final findController = _bootstrap.findReplaceController;
    return Column(
      children: <Widget>[
        if (_showFindReplace && findController != null)
          WenzFindReplacePanel(
            controller: findController,
            onClose: () => setState(() => _showFindReplace = false),
          ),
        if (!useMobileToolbar)
          _bootstrap.buildDefaultDesktopToolbar(
            actions: _desktopToolbarActions(),
          ),
        Expanded(
          child: ColoredBox(
            key: _editorSurfaceKey,
            color: _exampleEditorBackground(context),
            child: SafeArea(
              top: false,
              bottom: !useMobileToolbar,
              child: _buildEditor(theme),
            ),
          ),
        ),
        if (useMobileToolbar)
          _bootstrap.buildDefaultMobileToolbar(
            actions: _mobileToolbarActions(),
          ),
      ],
    );
  }

  /// Left inspector sidebar for the wide layout — 280px wide with the original
  /// surface fill and trailing border.
  Widget _buildInspectorPanel(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: _buildInspectorContent(),
    );
  }

  /// Right-side outline tree for the wide layout, with the original separating
  /// left border.
  Widget _buildOutlineRail(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: ExampleOutlinePanel(
        outlineController: _outline,
      ),
    );
  }

  /// The inspector panel widget itself, factored out so the wide sidebar and
  /// the compact Drawer share one construction site.
  Widget _buildInspectorContent() {
    return _InspectorPanel(
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
    );
  }

  /// Phone-sized Drawer holding the outline tree (top) and inspector (bottom),
  /// replacing the side columns that move off-screen on narrow layouts.
  Widget _buildSidePanelsDrawer(ThemeData theme) {
    return Drawer(
      child: SafeArea(
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Column(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom:
                          BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                  child: ExampleOutlinePanel(
                    outlineController: _outline,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: _buildInspectorContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  WenzRichTextEditor _buildEditor(ThemeData theme) {
    return _bootstrap.buildEditor(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
      blockSpacing: 14,
      textStyle: theme.textTheme.bodyLarge,
      defaultTextColor: theme.colorScheme.onSurface,
      autofocus: true,
      showDebugOverlay: _showDebugOverlay,
    );
  }

  void _showMentionDetails(WenzMentionTapDetails details) {
    if (!mounted) {
      return;
    }
    _lastEvent = 'Mention · ${details.label ?? details.id ?? 'unknown'}';
    setState(() {});
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return _MentionDetailsDialog(details: details);
        },
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

  Future<void> _insertImage() async {
    if (_isPickingImage || !_toolbar.canInsertImage) {
      return;
    }
    setState(() {
      _isPickingImage = true;
    });
    try {
      final insertionIndex = _toolbar.currentBlockInsertionIndex();
      final imageFile = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[_imageFileTypeGroup],
      );
      if (!mounted || imageFile == null) {
        return;
      }
      final source = imageFile.path.trim();
      if (source.isEmpty) {
        _showImageSelectionError('无法读取所选图片路径。');
        return;
      }
      try {
        final fileSize = await imageFile.length();
        if (fileSize <= 0) {
          _showImageSelectionError('所选图片文件为空。');
          return;
        }
      } catch (_) {
        if (mounted) {
          _showImageSelectionError('无法访问所选图片文件。');
        }
        return;
      }
      if (!mounted) {
        return;
      }
      final fileName = imageFile.name.trim();
      final label = fileName.isEmpty
          ? source.split(RegExp(r'[\\/]')).last
          : fileName;
      final id = _newId('image');
      _toolbar.insertImage(
        index: insertionIndex,
        blockId: id,
        file: source,
        caption: label,
        altText: label,
      );
    } catch (_) {
      if (mounted) {
        _showImageSelectionError('选择图片失败，请重试。');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  void _showImageSelectionError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _insertVideo() {
    if (!_toolbar.canInsertVideo) {
      return;
    }
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
      index: _toolbar.currentBlockInsertionIndex(),
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
      index: _toolbar.currentBlockInsertionIndex(),
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

  String _newId(String prefix) {
    _nextId += 1;
    return '$prefix-$_nextId';
  }

  /// Opens a link when the host activates one (Ctrl/Cmd+click on link text, or
  /// the link hover overlay's "open" action). Only browser URLs are handed to
  /// url_launcher; malformed values or unsupported schemes are ignored so link
  /// activation never mutates the editor or throws into gesture handling.
  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !_isBrowserLink(uri)) {
      return;
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Opening a link is best-effort host policy; unsupported platforms or
      // launcher failures must not affect the editor document/selection.
    }
  }

  bool _isBrowserLink(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'http' || scheme == 'https') &&
        uri.hasAuthority &&
        uri.host.trim().isNotEmpty;
  }
}

class _ExampleTopBarActions extends StatelessWidget {
  const _ExampleTopBarActions({
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onOpenAiConversations,
    required this.onToggleFindReplace,
    required this.showFindReplace,
    required this.onToggleComments,
    required this.showComments,
    required this.themeMode,
    required this.onToggleThemeMode,
  });

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onOpenAiConversations;
  final VoidCallback onToggleFindReplace;
  final bool showFindReplace;
  final VoidCallback onToggleComments;
  final bool showComments;
  final ThemeMode themeMode;
  final VoidCallback onToggleThemeMode;

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;
    return SizedBox(
      width: _topBarActionsWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          _TopBarActionButton(
            tooltip: '查找替换',
            onPressed: onToggleFindReplace,
            icon: Icons.search,
            selected: showFindReplace,
          ),
          _TopBarActionButton(
            tooltip: '批注',
            onPressed: onToggleComments,
            icon: Icons.mode_comment_outlined,
            selected: showComments,
          ),
          _TopBarActionButton(
            tooltip: '撤销',
            onPressed: canUndo ? onUndo : null,
            icon: Icons.undo,
          ),
          _TopBarActionButton(
            tooltip: '重做',
            onPressed: canRedo ? onRedo : null,
            icon: Icons.redo,
          ),
          _TopBarActionButton(
            tooltip: 'AI 对话',
            onPressed: onOpenAiConversations,
            icon: Icons.auto_awesome,
          ),
          _TopBarActionButton(
            key: _themeToggleKey,
            tooltip: isDark ? '切换浅色主题' : '切换深色主题',
            onPressed: onToggleThemeMode,
            icon: isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
          const SizedBox(width: _topBarActionTrailingPadding),
        ],
      ),
    );
  }
}

class _TopBarActionButton extends StatelessWidget {
  const _TopBarActionButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.selected = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: _topBarActionExtent,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        isSelected: selected,
        selectedIcon: Icon(icon),
        icon: Icon(icon),
        style: selected
            ? IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
              )
            : null,
      ),
    );
  }
}

class _MentionDetailsDialog extends StatelessWidget {
  const _MentionDetailsDialog({required this.details});

  final WenzMentionTapDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = details.label ?? details.id ?? 'Unknown mention';
    final entries = details.data.entries.toList(growable: false);
    return AlertDialog(
      title: Text('提及详情 · $label'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _MentionDetailRow(label: 'ID', value: details.id ?? '—'),
              _MentionDetailRow(label: 'Label', value: details.label ?? '—'),
              _MentionDetailRow(
                label: 'Block',
                value: '${details.blockIndex} · ${details.blockId}',
              ),
              _MentionDetailRow(
                label: 'Path',
                value: details.path.toString(),
              ),
              _MentionDetailRow(
                label: 'Offset',
                value: '${details.offset}',
              ),
              const SizedBox(height: 14),
              Text('Payload', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                Text(
                  'No payload',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final entry in entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${entry.key}: ${_mentionPayloadValue(entry.value)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _MentionDetailRow extends StatelessWidget {
  const _MentionDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

String _mentionPayloadValue(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is String) {
    return value;
  }
  return value.toString();
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
          'codec samples that cover links, lists, quoted headings/todos, code, '
          'tables, images, video, and file fallbacks.',
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
          'file/video data-* metadata; both keep blockquote semantics on '
          'headings, lists, and todo items.',
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
  // Not `const`: the flowchart sample is built through the `flowchartBlockEmbed`
  // helper so the seed data matches the renderer's data contract exactly.
  return RichTextDocument(
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
          TextRun(text: ', try the toolbar, or '),
          TextRun(
            text: 'open the project page',
            attributes: TextAttributes(url: 'https://github.com/'),
          ),
          TextRun(text: '.'),
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
            data: _exampleMentionCandidates.first.toMentionData(),
          ),
        ],
      ),
      TextBlockNode(
        id: 'quoted-heading',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 2, quoted: true),
        content: <InlineNode>[
          TextRun(text: 'Quoted heading keeps heading semantics.'),
        ],
      ),
      TextBlockNode(
        id: 'quoted-task',
        type: BlockType.listItem,
        attributes: BlockAttributes(
          listType: 'task',
          checked: true,
          quoted: true,
        ),
        content: <InlineNode>[
          TextRun(text: 'Quoted todo keeps checkbox state.'),
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
      CodeBlockNode(
        id: 'mermaid-sample',
        language: 'mermaid',
        code: 'flowchart TD\n'
            '  Start([客户提交续约申请]) --> Intake[销售录入线索与需求]\n'
            '  Intake --> Review{资料是否完整?}\n'
            '  Review -->|完整| Quote[生成报价与审批单]\n'
            '  Review -->|缺失| Patch[补充客户资料]\n'
            '  Patch --> Intake\n'
            '  Quote --> Risk{合同金额超过阈值?}\n'
            '  Risk -->|是| Legal[法务复核条款]\n'
            '  Risk -->|否| Sign[发送电子签署]\n'
            '  Legal --> Sign\n'
            '  Sign --> Won([归档并通知客户成功])\n'
            '  Sign -->|客户退回| Revise[调整方案]\n'
            '  Revise --> Quote',
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
      flowchartBlockEmbed(
        id: 'flowchart-sample',
        document: FlowchartDocument.sample(),
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


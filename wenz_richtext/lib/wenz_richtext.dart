/// Wenz RichText — self-owned rich text editor.
///
/// # API stability (as of stage 6)
///
/// This package is pre-`0.1.0` and its public surface is still stabilising.
/// APIs fall into three tiers:
///
/// - **Stable core (tier 1)**: the standard external interface — the
///   recommended facade entry point [WenzEditorConfiguration] +
///   [WenzEditorBootstrap] (assemble → build the editor widget → read/write
///   data → dispose), the document model
///   ([RichTextDocument], [BlockNode], [InlineNode], [TableModel],
///   [CommentAnchor], [CommentThread], [CommentEntry], [RevisionRange],
///   [RevisionChange]),
///   position/selection model ([DocumentPosition], [DocumentSelection],
///   [PositionPath]), [WenzRichTextController] (including the incremental-
///   rebuild signal [WenzRichTextController.lastChangedBlockIds]),
///   [HistoryManager], the core
///   text/block/style commands ([InsertTextCommand], [DeleteSelectionCommand],
///   [EnterCommand], [FormatTextCommand], [SetBlockTypeCommand], …), the
///   selection commands ([MoveCaretCommand], [MoveCaretByWordCommand],
///   [MoveCaretToBlockBoundaryCommand], [MoveCaretToDocumentBoundaryCommand],
///   [SelectAllCommand], [MoveTableCellCommand],
///   [MoveTableCellVerticalCommand]), [ClipboardService],
///   [RichClipboardAdapter], external image input contracts
///   ([ExternalImageInput], [ExternalImageClipboardData],
///   [ExternalImageClipboardReader], [ExternalImageStore],
///   [ExternalImageBlockDescription]), and [EditorTextInputClient]. These are
///   the intended integration points and change only with a documented reason.
/// - **Stabilising (tier 2)**: [WenzRichTextEditor] widget,
///   [WenzLinkInteractionCallback], [WenzRichTextEditorAccessibility],
///   editor context-menu descriptors ([WenzEditorContextMenuConfiguration],
///   [WenzEditorContextMenuContext], [WenzEditorContextMenuItem]),
///   [DocumentSchema],
///   the rich/legacy JSON codecs, the plain-text codec ([PlainTextCodec]),
///   the Markdown codec ([MarkdownCodec]), the HTML codec ([HtmlCodec]),
///   the schema migration framework ([DocumentMigration],
///   [DocumentMigrationRegistry], [V1ToV2DocumentMigration]), semantic inline
///   commands ([SetLinkCommand], [AutoLinkUrlsCommand], [ToggleMarkCommand],
///   [InsertInlineEmbedCommand]) and controller helpers for formula, mention,
///   emoji, inline image embeds, and block embeds, block structure commands
///   ([IndentCommand], [ToggleTodoCommand], [SetTodoCheckedCommand],
///   [SetCodeLanguageCommand],
///   [IndentCodeBlockCommand], [SetCalloutVariantCommand],
///   [UpdateCalloutBlockCommand], [ToggleQuoteCommand]), media-block commands
///   ([InsertVideoBlockCommand], [UpdateImageBlockCommand],
///   [UpdateFileBlockCommand], [UpdateVideoBlockCommand],
///   [DeleteVideoBlockCommand]), the command pipeline/registry
///   ([CommandMiddleware], [CommandRegistry], [CommandDescriptor],
///   [WenzEditorPermission]), the plugin
///   install surface ([WenzRichTextPlugin], [WenzPluginBundle],
///   [WenzPluginContext], [WenzPluginApiStatus]), the
///   callout block model ([CalloutBlockNode] with variant/title/icon metadata),
///   generic business block embed model ([BlockEmbedNode]),
///   rendering extension point ([BlockRendererRegistry],
///   [BlockRendererBuilder], [BlockRenderContext], [TableToolbarActionIntent],
///   [WenzObjectBlockSurface], [MediaResolver], [InlineEmbedRenderer],
///   [InlineEmbedRendererRegistry]), mention integration contracts
///   ([WenzMentionSearchCallback], [WenzMentionSearchRequest],
///   [WenzMentionCandidate], [WenzMentionTapCallback],
///   [WenzMentionTapDetails]), video insertion via slash menu / toolbar
///   helpers without a bundled player dependency, the
///   toolbar binding ([ToolbarController], [ToolbarState],
///   [WenzToolbarItemRegistry]) and optional default desktop toolbar
///   ([WenzDefaultDesktopToolbar]), the controller change
///   callbacks ([WenzRichTextController.onChanged],
///   [WenzRichTextController.onSelectionChanged],
///   [WenzRichTextController.onCommandExecuted]), find/replace state and UI
///   ([WenzFindReplaceController], [FindReplaceMatch],
///   [FindReplaceOptions], [WenzFindReplacePanel]), slash-menu state and UI
///   ([SlashMenuController], [SlashMenuRegistry], [SlashMenuItem],
///   [WenzSlashMenuOverlay]), outline state ([WenzOutlineController],
///   [OutlineItem]), document statistics ([WenzDocumentStatsController],
///   [DocumentStats]), autosave dirty-state helpers
///   ([WenzAutoSaveController], [AutoSaveState], [AutoSaveSnapshot]),
///   application-owned version snapshots ([DocumentVersionSnapshot],
///   [DocumentVersionSnapshotJsonCodec]),
///   revision commands ([InsertRevisionTextCommand],
///   [MarkDeletionRevisionCommand], [MarkFormatRevisionCommand],
///   [AcceptRevisionCommand], [RejectRevisionCommand]),
///   collaboration adapter primitives ([WenzCollaborationAdapter],
///   [WenzCollaborationController], [WenzRemoteSelectionUpdate]), comment
///   sidebar UI ([WenzCommentSidebar]), block anchor command
///   ([SetBlockAnchorCommand]), the
///   structured error types
///   ([DocumentDecodeException], [UnknownCommandException]) and the no-throw
///   safe-entry helpers ([WenzRichTextController.tryLoadJson],
///   [TryLoadResult], [WenzRichTextController.tryExecuteCommand]). The codec
///   JSON shape is versioned but migration tooling is not yet in place.
/// - **Experimental (tier 3)**: the table command family
///   ([InsertTableCommand], [InsertTableRowCommand], [InsertTableColumnCommand],
///   [DeleteTableRowCommand], [DeleteTableColumnCommand],
///   [SetTableColumnAlignmentCommand], [SetTableColumnWidthCommand],
///   [SetTableCellHeaderCommand], [SetTableCellBackgroundCommand],
///   [MergeTableCellsCommand], [SplitTableCellCommand],
///   [InsertTableCellTextCommand], [DeleteTableCellTextCommand],
///   [FormatTableCellTextCommand]) plus stage-3 rich block models such as
///   [VideoBlockNode], [FileBlockNode], and [BlockEmbedNode]. The default table renderer now provides a command-backed
///   floating toolbar and column-width drag handles. [FileBlockNode] includes
///   attachment metadata (`mimeType`, `downloadUrl`, upload status/error) but
///   retry/upload orchestration remains a business-layer concern; the low-level
///   table cell editing contract (see `docs/selection_model.md`) may still evolve.
/// - **Experimental (tier 3)**: the AI conversation module
///   ([AIConfigManager], [ConversationManager], [AIConfig], [OpenAIConfig],
///   [DeepSeekConfig], [Conversation], [ChatMessage], [AIService],
///   [AIServiceFactory], [AIServiceException]) — AI-powered chat with
///   OpenAI / DeepSeek backends, managed through ChangeNotifier-based managers
///   with JSON file persistence.
///
/// See `docs/optimization_roadmap.md` for the stage breakdown,
/// `docs/architecture.md` for the layer overview,
/// `docs/integration_guide.md` for the standard external interface contract
/// (the recommended `WenzEditorConfiguration` + `WenzEditorBootstrap` entry
/// point and the tier 1/tier 2/internal stability boundary),
/// `docs/api_reference.md` for the public-API surface,
/// `docs/schema_and_commands.md` for schema/command extension points,
/// `docs/selection_model.md` for the selection contract,
/// `docs/selection_engine.md` for the cross-block selection/layout design,
/// `docs/input_system.md` for the IME/clipboard/external-image input/shortcut design,
/// and `docs/migration_guide.md` for adopting the package from legacy data.
library wenz_richtext;

export 'src/codecs/document_errors.dart';
export 'src/codecs/document_migration.dart';
export 'src/codecs/document_version_snapshot_codec.dart';
export 'src/codecs/html_codec.dart';
export 'src/codecs/legacy_wen_json_codec.dart';
export 'src/codecs/markdown_codec.dart';
export 'src/codecs/plain_text_codec.dart';
export 'src/codecs/rich_text_json_codec.dart';
export 'src/collaboration/collaboration_adapter.dart';
export 'src/controller/autosave_controller.dart';
export 'src/controller/document_stats_controller.dart';
export 'src/controller/document_export_snapshot.dart';
export 'src/controller/find_replace_controller.dart';
export 'src/controller/outline_controller.dart';
export 'src/controller/slash_menu_controller.dart';
export 'src/controller/toolbar_controller.dart';
export 'src/controller/wenz_rich_text_controller.dart';
export 'src/core/commands/block_commands.dart';
export 'src/core/commands/block_structure_commands.dart';
export 'src/core/commands/command_executor.dart';
export 'src/core/commands/command_registry.dart';
export 'src/core/commands/editor_command.dart';
export 'src/core/commands/inline_commands.dart';
export 'src/core/commands/inline_editing.dart';
export 'src/core/commands/markdown_shortcut_commands.dart';
export 'src/core/commands/revision_commands.dart';
export 'src/core/commands/selection_commands.dart';
export 'src/core/commands/style_commands.dart';
export 'src/core/commands/table_commands.dart';
export 'src/core/commands/text_commands.dart';
export 'src/core/model/attributes.dart';
export 'src/core/model/block_node.dart';
export 'src/core/model/comment_model.dart';
export 'src/core/model/document_version_snapshot.dart';
export 'src/core/model/inline_node.dart';
export 'src/core/model/list_numbering.dart';
export 'src/core/model/revision_model.dart';
export 'src/core/model/rich_text_document.dart';
export 'src/core/model/table_model.dart';
export 'src/core/position/document_position.dart';
export 'src/core/schema/document_schema.dart';
export 'src/core/transaction/change_set.dart';
export 'src/core/transaction/document_session.dart';
export 'src/exporters/document_conversion_plan.dart';
export 'src/history/history_manager.dart';
export 'src/input/clipboard_service.dart';
export 'src/input/clipboard_debug_log.dart';
export 'src/input/composition_state.dart';
export 'src/input/editor_text_input_client.dart';
export 'src/input/external_image_clipboard_reader.dart';
export 'src/input/external_image_insertion.dart';
export 'src/input/external_image_input.dart';
export 'src/input/rich_clipboard_adapter.dart';
export 'src/input/shortcut_manager.dart';
export 'src/plugins/editor_plugin.dart';
export 'src/plugins/mermaid_diagram_plugin.dart'
    show
        MermaidDiagramConfig,
        MermaidDiagramPlugin,
        MermaidRenderer,
        NativeMermaidRenderer;
export 'src/mermaid/mermaid.dart'
    show
        ArrowType,
        DeviceType,
        DiagramDirection,
        DiagramType,
        EdgeStyle,
        GanttChartData,
        GanttSection,
        GanttTask,
        GanttTaskStatus,
        InteractiveMermaidDiagram,
        KanbanChartData,
        KanbanColumn,
        KanbanPriority,
        KanbanTask,
        LineType,
        MermaidColors,
        MermaidDeviceConfig,
        MermaidDiagram,
        MermaidDiagramData,
        MermaidEdge,
        MermaidNode,
        MermaidParseResult,
        MermaidParser,
        MermaidResponsiveConfig,
        MermaidStyle,
        MermaidThemeMode,
        MermaidThemes,
        MermaidCacheStatus,
        MermaidRenderDiagnosticEvent,
        MermaidRenderDiagnostics,
        MermaidRenderErrorCode,
        MermaidRenderFailure,
        MermaidRenderLimits,
        MermaidRenderMetrics,
        MermaidRenderOutcome,
        MermaidRenderRequest,
        MermaidRenderResult,
        MermaidRenderStage,
        MermaidRenderTheme,
        NativeMermaidRenderService,
        NativeMermaidRenderServiceStats,
        DefaultNativeMermaidRenderService,
        mermaidSourceDigest,
        mermaidViewportBucket,
        MindmapConnection,
        MindmapData,
        MindmapNode,
        MindmapNodeShape,
        MessageType,
        NodeShape,
        NodeStyle,
        ParticipantType,
        PieChartData,
        PieSlice,
        RadarAxis,
        RadarChartData,
        RadarCurve,
        RadarGraticule,
        SequenceMessage,
        SequenceParticipant,
        Subgraph,
        SubgraphStyle,
        TimelineChartData,
        TimelineEvent,
        TimelineSection,
        XYChartData,
        XYChartOrientation,
        XYChartSeries,
        XYSeriesType;
export 'src/integration/wenz_editor_bootstrap.dart';
export 'src/integration/wenz_editor_configuration.dart';
export 'src/widgets/block_renderer_registry.dart';
export 'src/widgets/block_layout_index.dart';
export 'src/widgets/comment_sidebar.dart';
export 'src/widgets/code_syntax_highlighter.dart'
    show CodeSyntaxHighlighter, CodeSyntaxPalette;
export 'src/widgets/color_picker_painters.dart';
export 'src/widgets/default_desktop_toolbar.dart';
export 'src/widgets/default_mobile_toolbar.dart';
export 'src/widgets/desktop_selection_toolbar_overlay.dart';
export 'src/widgets/editor_context_menu.dart';
export 'src/widgets/find_replace_panel.dart';
export 'src/widgets/inline_embed_renderer.dart';
export 'src/widgets/media_resource_action.dart';
export 'src/widgets/link_edit_dialog.dart';
export 'src/widgets/mermaid/mermaid_code_block_widget.dart'
    show MermaidCodeBlockWidget;
export 'src/widgets/link_hover_overlay.dart';
export 'src/widgets/lucide_toolbar_icons.dart'
    show WenzLucideToolbarIcon, WenzLucideToolbarIcons;
export 'src/widgets/media_resolver.dart';
export 'src/widgets/outline_tree.dart' show WenzOutlineTree, WenzOutlinePanel;
export 'src/widgets/rgb_spectrum_picker.dart';
export 'src/widgets/rich_text_color_picker_dialog.dart';
export 'src/widgets/slash_menu_overlay.dart';
export 'src/widgets/wenz_rich_text_editor.dart';

// ---------------------------------------------------------------------------
// AI conversation module (tier 3 — experimental)
// ---------------------------------------------------------------------------

export 'src/ai/models/ai_config.dart'
    show
        AIProvider,
        ThinkingDepth,
        DeepSeekThinkingMode,
        AIConfig,
        OpenAIConfig,
        DeepSeekConfig;
export 'src/ai/models/conversation.dart'
    show MessageRole, ConversationStatus, ChatMessage, Conversation;
export 'src/ai/services/ai_service.dart'
    show AIService, AIServiceFactory, AIServiceException;
export 'src/ai/ai_config_manager.dart' show AIConfigManager;
export 'src/ai/conversation_manager.dart' show ConversationManager;

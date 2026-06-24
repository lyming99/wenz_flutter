/// Wenz RichText — self-owned rich text editor.
///
/// # API stability (as of stage 6)
///
/// This package is pre-`0.1.0` and its public surface is still stabilising.
/// APIs fall into three tiers:
///
/// - **Stable core (tier 1)**: document model
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
///   [MoveTableCellVerticalCommand]), [ClipboardService], and
///   [EditorTextInputClient]. These are the intended integration points and
///   change only with a documented reason.
/// - **Stabilising (tier 2)**: [WenzRichTextEditor] widget,
///   [WenzRichTextEditorAccessibility], [DocumentSchema],
///   the rich/legacy JSON codecs, the plain-text codec ([PlainTextCodec]),
///   the Markdown codec ([MarkdownCodec]), the HTML codec ([HtmlCodec]),
///   the schema migration framework ([DocumentMigration],
///   [DocumentMigrationRegistry], [V1ToV2DocumentMigration]), semantic inline
///   commands ([SetLinkCommand], [AutoLinkUrlsCommand], [ToggleMarkCommand],
///   [InsertInlineEmbedCommand]) and controller helpers for formula, mention,
///   emoji, inline image embeds, and block embeds, block structure commands
///   ([IndentCommand], [ToggleTodoCommand], [SetCodeLanguageCommand],
///   [IndentCodeBlockCommand], [SetCalloutVariantCommand],
///   [UpdateCalloutBlockCommand], [ToggleQuoteCommand]), media-block metadata commands
///   ([UpdateImageBlockCommand], [UpdateFileBlockCommand]), the command pipeline/registry
///   ([CommandMiddleware], [CommandRegistry], [CommandDescriptor],
///   [WenzEditorPermission]), the plugin
///   install surface ([WenzRichTextPlugin], [WenzPluginBundle],
///   [WenzPluginContext], [WenzPluginApiStatus]), the
///   callout block model ([CalloutBlockNode] with variant/title/icon metadata),
///   generic business block embed model ([BlockEmbedNode]),
///   rendering extension point ([BlockRendererRegistry],
///   [BlockRendererBuilder], [BlockRenderContext], [TableToolbarActionIntent],
///   [WenzObjectBlockSurface], [MediaResolver], [InlineEmbedRenderer],
///   [InlineEmbedRendererRegistry]), the
///   toolbar binding ([ToolbarController], [ToolbarState],
///   [WenzToolbarItemRegistry]), the controller change
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
///   [FileBlockNode] and [BlockEmbedNode]. The default table renderer now provides a command-backed
///   floating toolbar and column-width drag handles. [FileBlockNode] includes
///   attachment metadata (`mimeType`, `downloadUrl`, upload status/error) but
///   retry/upload orchestration remains a business-layer concern; the low-level
///   table cell editing contract (see `docs/selection_model.md`) may still evolve.
///
/// See `docs/optimization_roadmap.md` for the stage breakdown,
/// `docs/architecture.md` for the layer overview,
/// `docs/api_reference.md` for the public-API surface,
/// `docs/schema_and_commands.md` for schema/command extension points,
/// `docs/selection_model.md` for the selection contract,
/// `docs/selection_engine.md` for the cross-block selection/layout design,
/// `docs/input_system.md` for the IME/clipboard/shortcut/command-merge design,
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
export 'src/input/composition_state.dart';
export 'src/input/editor_text_input_client.dart';
export 'src/input/shortcut_manager.dart';
export 'src/plugins/editor_plugin.dart';
export 'src/widgets/block_renderer_registry.dart';
export 'src/widgets/comment_sidebar.dart';
export 'src/widgets/find_replace_panel.dart';
export 'src/widgets/inline_embed_renderer.dart';
export 'src/widgets/link_edit_dialog.dart';
export 'src/widgets/media_resolver.dart';
export 'src/widgets/slash_menu_overlay.dart';
export 'src/widgets/wenz_rich_text_editor.dart';

/// Wenz RichText — self-owned rich text editor.
///
/// # API stability (as of stage 3)
///
/// This package is pre-`0.1.0` and its public surface is still stabilising.
/// APIs fall into three tiers:
///
/// - **Stable core (tier 1)**: document model
///   ([RichTextDocument], [BlockNode], [InlineNode], [TableModel]),
///   position/selection model ([DocumentPosition], [DocumentSelection],
///   [PositionPath]), [WenzRichTextController], [HistoryManager], the core
///   text/block/style commands ([InsertTextCommand], [DeleteSelectionCommand],
///   [EnterCommand], [FormatTextCommand], [SetBlockTypeCommand], …), the
///   selection commands ([MoveCaretCommand], [MoveCaretByWordCommand],
///   [MoveCaretToBlockBoundaryCommand], [MoveCaretToDocumentBoundaryCommand],
///   [SelectAllCommand]), [ClipboardService], and [EditorTextInputClient].
///   These are the intended integration points and change only with a
///   documented reason.
/// - **Stabilising (tier 2)**: [WenzRichTextEditor] widget, [DocumentSchema],
///   the rich/legacy JSON codecs, semantic inline commands ([SetLinkCommand],
///   [ToggleMarkCommand], [InsertInlineEmbedCommand]), block structure commands
///   ([IndentCommand], [ToggleTodoCommand], [SetCodeLanguageCommand],
///   [ToggleQuoteCommand]), and the command pipeline/registry
///   ([CommandMiddleware], [CommandRegistry], [CommandDescriptor]). The codec
///   JSON shape is versioned but migration tooling is not yet in place.
/// - **Experimental (tier 3)**: the table command family
///   ([InsertTableCommand], [InsertTableRowCommand], [InsertTableColumnCommand],
///   [DeleteTableRowCommand], [DeleteTableColumnCommand],
///   [SetTableColumnAlignmentCommand], [SetTableColumnWidthCommand],
///   [SetTableCellHeaderCommand], [SetTableCellBackgroundCommand],
///   [MergeTableCellsCommand], [SplitTableCellCommand],
///   [InsertTableCellTextCommand], [DeleteTableCellTextCommand],
///   [FormatTableCellTextCommand]) plus stage-3 rich block models such as [CalloutBlockNode] and [FileBlockNode]. Full
///   table editing is delivered in stage 4; until then these commands work but
///   the cell editing contract (see `docs/selection_model.md`) is expected to
///   change.
///
/// See `docs/optimization_roadmap.md` for the stage breakdown,
/// `docs/schema_and_commands.md` for schema/command extension points,
/// `docs/selection_model.md` for the selection contract,
/// `docs/selection_engine.md` for the cross-block selection/layout design, and
/// `docs/input_system.md` for the IME/clipboard/shortcut/command-merge design.
library wenz_richtext;

export 'src/codecs/legacy_wen_json_codec.dart';
export 'src/codecs/rich_text_json_codec.dart';
export 'src/controller/wenz_rich_text_controller.dart';
export 'src/core/commands/block_commands.dart';
export 'src/core/commands/block_structure_commands.dart';
export 'src/core/commands/command_executor.dart';
export 'src/core/commands/command_registry.dart';
export 'src/core/commands/editor_command.dart';
export 'src/core/commands/inline_commands.dart';
export 'src/core/commands/inline_editing.dart';
export 'src/core/commands/selection_commands.dart';
export 'src/core/commands/style_commands.dart';
export 'src/core/commands/table_commands.dart';
export 'src/core/commands/text_commands.dart';
export 'src/core/model/attributes.dart';
export 'src/core/model/block_node.dart';
export 'src/core/model/inline_node.dart';
export 'src/core/model/rich_text_document.dart';
export 'src/core/model/table_model.dart';
export 'src/core/position/document_position.dart';
export 'src/core/schema/document_schema.dart';
export 'src/core/transaction/change_set.dart';
export 'src/core/transaction/document_session.dart';
export 'src/history/history_manager.dart';
export 'src/input/clipboard_service.dart';
export 'src/input/composition_state.dart';
export 'src/input/editor_text_input_client.dart';
export 'src/widgets/wenz_rich_text_editor.dart';

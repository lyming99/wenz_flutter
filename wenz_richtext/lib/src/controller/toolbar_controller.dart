import 'package:flutter/widgets.dart';

import '../core/commands/inline_commands.dart';
import '../core/commands/inline_editing.dart';
import '../core/commands/table_cell_editing.dart';
import '../core/model/attributes.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/rich_text_document.dart';
import '../core/position/document_position.dart';
import 'wenz_rich_text_controller.dart';

typedef WenzToolbarItemAction = void Function(
  WenzRichTextController editor,
  ToolbarState state,
);

typedef WenzToolbarItemPredicate = bool Function(ToolbarState state);

/// Headless toolbar item descriptor contributed by a plugin.
///
/// The package intentionally does not ship a fixed toolbar widget. Hosts can
/// render these descriptors in Material, Cupertino, or business-specific UI and
/// call [action] with the current [ToolbarState].
class WenzToolbarItem {
  const WenzToolbarItem({
    required this.id,
    required this.title,
    required this.action,
    this.icon,
    this.tooltip,
    this.priority = 0,
    this.isEnabled,
    this.isActive,
  });

  /// Unique item id, usually namespaced by plugin.
  final String id;

  final String title;
  final String? icon;
  final String? tooltip;

  /// Lower values should be rendered earlier by host toolbars.
  final int priority;

  final WenzToolbarItemPredicate? isEnabled;
  final WenzToolbarItemPredicate? isActive;
  final WenzToolbarItemAction action;

  bool enabledFor(ToolbarState state) => isEnabled?.call(state) ?? true;

  bool activeFor(ToolbarState state) => isActive?.call(state) ?? false;
}

/// Registry for toolbar descriptors contributed by plugins.
class WenzToolbarItemRegistry {
  WenzToolbarItemRegistry([
    Iterable<WenzToolbarItem> items = const <WenzToolbarItem>[],
  ]) {
    for (final item in items) {
      register(item);
    }
  }

  final Map<String, WenzToolbarItem> _items = <String, WenzToolbarItem>{};

  List<WenzToolbarItem> get items {
    final ordered = _items.values.toList()
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        if (byPriority != 0) {
          return byPriority;
        }
        return a.id.compareTo(b.id);
      });
    return List<WenzToolbarItem>.unmodifiable(ordered);
  }

  void register(WenzToolbarItem item) {
    _items[item.id] = item;
  }

  void unregister(String id) {
    _items.remove(id);
  }

  bool has(String id) => _items.containsKey(id);

  WenzToolbarItem? operator [](String id) => _items[id];
}

/// Table cell coordinates currently targeted by toolbar table actions.
class WenzToolbarTableContext {
  const WenzToolbarTableContext({
    required this.blockIndex,
    required this.rowIndex,
    required this.columnIndex,
    required this.range,
  });

  final int blockIndex;
  final int rowIndex;
  final int columnIndex;
  final TableCellRange range;
}

/// A read-only snapshot of the toolbar-relevant state derived from a
/// [WenzRichTextController]'s current document + selection.
///
/// [ToolbarController] recomputes a fresh snapshot every time the host
/// controller notifies, then exposes it via [ToolbarController.state]. The
/// snapshot is immutable and value-equal, so callers can short-circuit
/// rebuilds when nothing changed.
class ToolbarState {
  const ToolbarState({
    required this.hasSelection,
    required this.canFormatInline,
    required this.canToggleMark,
    required this.canSetLink,
    required this.canSetBlockType,
    required this.canSetCodeLanguage,
    required this.canIndent,
    required this.canOutdent,
    required this.canToggleTodo,
    required this.canToggleQuote,
    required this.isQuoteBlock,
    required this.canTableStruct,
    required this.canSetAlignment,
    this.tableCellIsHeader,
    this.tableCellBackgroundColor,
    this.alignment,
    required this.alignmentMixed,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.lineThrough,
    required this.remark,
    required this.textColor,
    required this.textColorMixed,
    required this.linkUrl,
    required this.uniformBlockType,
    required this.uniformListType,
    required this.uniformHeadingLevel,
    required this.codeLanguage,
    required this.canUndo,
    required this.canRedo,
  });

  /// Whether any selection is active (collapsed caret counts).
  final bool hasSelection;

  /// Whether inline text formatting (FormatTextCommand) can apply — requires
  /// the selection to sit inside a [TextBlockNode] text path. A collapsed
  /// caret still qualifies because it sets the typing attributes for the next
  /// input.
  final bool canFormatInline;

  /// Whether a boolean mark toggle (ToggleMarkCommand) can apply — same rule
  /// as [canFormatInline] but ToggleMarkCommand additionally requires a single
  /// block + path, so cross-block ranges are disabled.
  final bool canToggleMark;

  /// Whether set/clear link can apply. SetLinkCommand requires a single block
  /// + single path, so cross-block ranges are disabled.
  final bool canSetLink;

  /// Whether block type switch (SetBlockTypeCommand) can apply — requires the
  /// selection to cover at least one [TextBlockNode]. Only text-block types
  /// (paragraph/heading/listItem) are switchable; quote is toggled separately as
  /// a block decoration.
  final bool canSetBlockType;

  /// Whether the selection sits inside a [CodeBlockNode] and the toolbar can
  /// change its language.
  final bool canSetCodeLanguage;

  final bool canIndent;
  final bool canOutdent;
  final bool canToggleTodo;
  final bool canToggleQuote;

  /// Whether every selected text block currently carries quote decoration.
  final bool isQuoteBlock;

  /// Whether table structure commands (add/remove row/column, merge, split)
  /// make sense — the caret must sit inside a table cell.
  final bool canTableStruct;

  /// Whether selection-level alignment can apply. For ordinary blocks this
  /// maps to block alignment; for table-cell selections it maps to cell-level
  /// alignment.
  final bool canSetAlignment;
  final bool? tableCellIsHeader;
  final int? tableCellBackgroundColor;

  /// The explicit alignment shared by the current selection. `null` with
  /// [alignmentMixed] false means no explicit alignment; `null` with
  /// [alignmentMixed] true means the selected blocks/cells mix alignments.
  final String? alignment;
  final bool alignmentMixed;

  /// `true` when **every** text run in the selection has the mark set. A
  /// mixed range (some on, some off) reports `false` (indeterminate) so the
  /// toolbar does not paint an active highlight.
  final bool bold;
  final bool italic;
  final bool underline;
  final bool lineThrough;
  final bool remark;

  /// The single inline font color shared by the selection as `0xAARRGGBB`.
  /// `null` with [textColorMixed] false means no inline color; `null` with
  /// [textColorMixed] true means the range mixes multiple color states.
  final int? textColor;
  final bool textColorMixed;

  /// The link URL shared by every run in the selection, or `null` when the
  /// selection has no link or mixes different URLs. For a collapsed caret,
  /// this is the URL of the run immediately left of the caret.
  final String? linkUrl;

  /// The single [BlockType] every block in the selection shares, or `null`
  /// when the selection spans multiple types (or none).
  final BlockType? uniformBlockType;

  /// The canonical listType shared by every listItem block in the selection.
  /// Values: `'ordered'`, `'task'`, or `null` (unordered). Non-`listItem`
  /// selections report `null`.
  final String? uniformListType;

  /// The heading level shared by every block when they are all headings, else
  /// `null`.
  final int? uniformHeadingLevel;

  /// Current [CodeBlockNode.language] when the selection is inside a code
  /// block, or `null` outside code blocks.
  final String? codeLanguage;

  final bool canUndo;
  final bool canRedo;

  /// Whether a boolean mark is active across the whole selection.
  bool isMarkActive(TextMark mark) {
    return switch (mark) {
      TextMark.bold => bold,
      TextMark.italic => italic,
      TextMark.underline => underline,
      TextMark.lineThrough => lineThrough,
      TextMark.remark => remark,
    };
  }

  /// Whether the selection is entirely a given text-block type.
  bool isBlockType(BlockType type) => uniformBlockType == type;

  /// Whether the selection is entirely a heading at [level].
  bool isHeading(int level) =>
      uniformBlockType == BlockType.heading && uniformHeadingLevel == level;

  bool isAlignment(String? value) => !alignmentMixed && alignment == value;

  bool get isParagraph => uniformBlockType == BlockType.paragraph;
  bool get isTodo =>
      uniformBlockType == BlockType.listItem && uniformListType == 'task';
  bool get isOrderedList =>
      uniformBlockType == BlockType.listItem && uniformListType == 'ordered';
  bool get isUnorderedList =>
      uniformBlockType == BlockType.listItem && uniformListType == null;

  static const ToolbarState empty = ToolbarState(
    hasSelection: false,
    canFormatInline: false,
    canToggleMark: false,
    canSetLink: false,
    canSetBlockType: false,
    canSetCodeLanguage: false,
    canIndent: false,
    canOutdent: false,
    canToggleTodo: false,
    canToggleQuote: false,
    isQuoteBlock: false,
    canTableStruct: false,
    canSetAlignment: false,
    alignment: null,
    alignmentMixed: false,
    bold: false,
    italic: false,
    underline: false,
    lineThrough: false,
    remark: false,
    textColor: null,
    textColorMixed: false,
    linkUrl: null,
    uniformBlockType: null,
    uniformListType: null,
    uniformHeadingLevel: null,
    codeLanguage: null,
    canUndo: false,
    canRedo: false,
  );

  ToolbarState copyWith({
    bool? hasSelection,
    bool? canFormatInline,
    bool? canToggleMark,
    bool? canSetLink,
    bool? canSetBlockType,
    bool? canSetCodeLanguage,
    bool? canIndent,
    bool? canOutdent,
    bool? canToggleTodo,
    bool? canToggleQuote,
    bool? isQuoteBlock,
    bool? canTableStruct,
    bool? canSetAlignment,
    Object? tableCellIsHeader = _sentinel,
    Object? tableCellBackgroundColor = _sentinel,
    Object? alignment = _sentinel,
    bool? alignmentMixed,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? lineThrough,
    bool? remark,
    Object? textColor = _sentinel,
    bool? textColorMixed,
    Object? linkUrl = _sentinel,
    BlockType? uniformBlockType,
    Object? uniformListType = _sentinel,
    Object? uniformHeadingLevel = _sentinel,
    Object? codeLanguage = _sentinel,
    bool? canUndo,
    bool? canRedo,
  }) {
    return ToolbarState(
      hasSelection: hasSelection ?? this.hasSelection,
      canFormatInline: canFormatInline ?? this.canFormatInline,
      canToggleMark: canToggleMark ?? this.canToggleMark,
      canSetLink: canSetLink ?? this.canSetLink,
      canSetBlockType: canSetBlockType ?? this.canSetBlockType,
      canSetCodeLanguage: canSetCodeLanguage ?? this.canSetCodeLanguage,
      canIndent: canIndent ?? this.canIndent,
      canOutdent: canOutdent ?? this.canOutdent,
      canToggleTodo: canToggleTodo ?? this.canToggleTodo,
      canToggleQuote: canToggleQuote ?? this.canToggleQuote,
      isQuoteBlock: isQuoteBlock ?? this.isQuoteBlock,
      canTableStruct: canTableStruct ?? this.canTableStruct,
      canSetAlignment: canSetAlignment ?? this.canSetAlignment,
      tableCellIsHeader: identical(tableCellIsHeader, _sentinel)
          ? this.tableCellIsHeader
          : tableCellIsHeader as bool?,
      tableCellBackgroundColor: identical(tableCellBackgroundColor, _sentinel)
          ? this.tableCellBackgroundColor
          : tableCellBackgroundColor as int?,
      alignment: identical(alignment, _sentinel)
          ? this.alignment
          : alignment as String?,
      alignmentMixed: alignmentMixed ?? this.alignmentMixed,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      lineThrough: lineThrough ?? this.lineThrough,
      remark: remark ?? this.remark,
      textColor:
          identical(textColor, _sentinel) ? this.textColor : textColor as int?,
      textColorMixed: textColorMixed ?? this.textColorMixed,
      linkUrl:
          identical(linkUrl, _sentinel) ? this.linkUrl : linkUrl as String?,
      uniformBlockType: uniformBlockType ?? this.uniformBlockType,
      uniformListType: identical(uniformListType, _sentinel)
          ? this.uniformListType
          : uniformListType as String?,
      uniformHeadingLevel: identical(uniformHeadingLevel, _sentinel)
          ? this.uniformHeadingLevel
          : uniformHeadingLevel as int?,
      codeLanguage: identical(codeLanguage, _sentinel)
          ? this.codeLanguage
          : codeLanguage as String?,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ToolbarState &&
        other.hasSelection == hasSelection &&
        other.canFormatInline == canFormatInline &&
        other.canToggleMark == canToggleMark &&
        other.canSetLink == canSetLink &&
        other.canSetBlockType == canSetBlockType &&
        other.canSetCodeLanguage == canSetCodeLanguage &&
        other.canIndent == canIndent &&
        other.canOutdent == canOutdent &&
        other.canToggleTodo == canToggleTodo &&
        other.canToggleQuote == canToggleQuote &&
        other.isQuoteBlock == isQuoteBlock &&
        other.canTableStruct == canTableStruct &&
        other.canSetAlignment == canSetAlignment &&
        other.tableCellIsHeader == tableCellIsHeader &&
        other.tableCellBackgroundColor == tableCellBackgroundColor &&
        other.alignment == alignment &&
        other.alignmentMixed == alignmentMixed &&
        other.bold == bold &&
        other.italic == italic &&
        other.underline == underline &&
        other.lineThrough == lineThrough &&
        other.remark == remark &&
        other.textColor == textColor &&
        other.textColorMixed == textColorMixed &&
        other.linkUrl == linkUrl &&
        other.uniformBlockType == uniformBlockType &&
        other.uniformListType == uniformListType &&
        other.uniformHeadingLevel == uniformHeadingLevel &&
        other.codeLanguage == codeLanguage &&
        other.canUndo == canUndo &&
        other.canRedo == canRedo;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hash(
        hasSelection,
        canFormatInline,
        canToggleMark,
        canSetLink,
        canSetBlockType,
        canSetCodeLanguage,
        canIndent,
        canOutdent,
        canToggleTodo,
        canToggleQuote,
        isQuoteBlock,
        canTableStruct,
        canSetAlignment,
        tableCellIsHeader,
        tableCellBackgroundColor,
        alignment,
        alignmentMixed,
      ),
      Object.hash(
        bold,
        italic,
        underline,
        lineThrough,
        remark,
        textColor,
        textColorMixed,
        linkUrl,
        uniformBlockType,
        uniformListType,
        uniformHeadingLevel,
        codeLanguage,
        canUndo,
        canRedo,
      ),
    );
  }
}

const Object _sentinel = Object();

/// Drives a toolbar UI from a [WenzRichTextController].
///
/// Listens to the host controller (a [ChangeNotifier]) and exposes a
/// [ToolbarState] snapshot that tracks the active selection's inline marks,
/// link URL, block type, and the enable/disable state of every command the
/// toolbar surfaces. Mutating helpers ([toggleBold], [setHeading], …) forward
/// to the host controller's typed command methods so the toolbar and the
/// editor share one execution path.
///
/// The controller is a [ChangeNotifier] itself: rebuilds in a widget tree
/// should subscribe via [addListener] and read [state]. Remember to [dispose]
/// to detach from the host.
class ToolbarController extends ChangeNotifier {
  ToolbarController(this._host) {
    _host.addListener(_handleHostChanged);
    _recompute();
  }

  final WenzRichTextController _host;
  int _generatedBlockId = 0;

  ToolbarState _state = ToolbarState.empty;
  ToolbarState get state => _state;

  // ---- Convenience accessors backed by the snapshot -------------------------

  bool get canFormatInline => _state.canFormatInline;
  bool get canToggleMark => _state.canToggleMark;
  bool get canSetLink => _state.canSetLink;
  bool get canSetBlockType => _state.canSetBlockType;
  bool get canSetCodeLanguage => _state.canSetCodeLanguage;
  bool get canIndent => _state.canIndent;
  bool get canOutdent => _state.canOutdent;
  bool get canToggleTodo => _state.canToggleTodo;
  bool get canToggleQuote => _state.canToggleQuote;
  bool get canTableStruct => _state.canTableStruct;
  bool get canSetAlignment => _state.canSetAlignment;
  bool get canInsertBlock => _host.canEdit;
  bool get canInsertImage => _host.canEdit;
  bool get canInsertVideo => _host.canEdit;
  bool? get tableCellIsHeader => _state.tableCellIsHeader;
  int? get tableCellBackgroundColor => _state.tableCellBackgroundColor;
  String? get alignment => _state.alignment;
  bool get alignmentMixed => _state.alignmentMixed;
  bool isAlignment(String? value) => _state.isAlignment(value);

  bool get bold => _state.bold;
  bool get italic => _state.italic;
  bool get underline => _state.underline;
  bool get lineThrough => _state.lineThrough;
  bool get remark => _state.remark;
  int? get textColor => _state.textColor;
  bool get textColorMixed => _state.textColorMixed;
  bool isMarkActive(TextMark mark) => _state.isMarkActive(mark);

  String? get linkUrl => _state.linkUrl;

  BlockType? get uniformBlockType => _state.uniformBlockType;
  String? get uniformListType => _state.uniformListType;
  int? get uniformHeadingLevel => _state.uniformHeadingLevel;
  String? get codeLanguage => _state.codeLanguage;
  bool isBlockType(BlockType type) => _state.isBlockType(type);
  bool isHeading(int level) => _state.isHeading(level);
  bool get isParagraph => _state.isParagraph;
  bool get isQuoteBlock => _state.isQuoteBlock;
  bool get isTodo => _state.isTodo;
  bool get isOrderedList => _state.isOrderedList;
  bool get isUnorderedList => _state.isUnorderedList;

  // ---- Mutating helpers ----------------------------------------------------

  void toggleBold() => _toggleMark(TextMark.bold);
  void toggleItalic() => _toggleMark(TextMark.italic);
  void toggleUnderline() => _toggleMark(TextMark.underline);
  void toggleLineThrough() => _toggleMark(TextMark.lineThrough);
  void toggleRemark() => _toggleMark(TextMark.remark);

  /// Generic toggle for any [TextMark]. Disabled (no-op) when
  /// [canToggleMark] is false. Lets the toolbar drive an arbitrary mark
  /// without one method per button.
  void toggleMark(TextMark mark) => _toggleMark(mark);

  void _toggleMark(TextMark mark) {
    if (!_state.canToggleMark) {
      return;
    }
    _host.execute(ToggleMarkCommand(mark));
  }

  void setLink(String? url) {
    if (!_state.canSetLink) {
      return;
    }
    _host.setLink(url);
  }

  void setTextColor(Color color) {
    setTextColorValue(color.toARGB32());
  }

  void setTextColorValue(int color) {
    if (!_state.canFormatInline) {
      return;
    }
    _host.setTextColorValue(color);
  }

  void clearTextColor() {
    if (!_state.canFormatInline) {
      return;
    }
    _host.clearTextColor();
  }

  void clearStyle() {
    if (!_state.canFormatInline) {
      return;
    }
    _host.clearStyle();
  }

  void setAlignment(String? alignment) {
    if (!_state.canSetAlignment) {
      return;
    }
    _host.setAlignment(alignment);
  }

  void clearAlignment() => setAlignment(null);

  void setHeading(int level) => _setBlockType(BlockType.heading, level: level);
  void setParagraph() => _setBlockType(BlockType.paragraph);
  void toggleQuoteBlock() {
    if (_state.canToggleQuote) {
      _host.toggleQuote();
    }
  }

  void setTodo() =>
      _setBlockType(BlockType.listItem, listType: 'task', checked: false);
  void setOrderedList() =>
      _setBlockType(BlockType.listItem, listType: 'ordered');
  void setUnorderedList() => _setBlockType(BlockType.listItem, listType: null);

  void setCodeLanguage(String language) {
    if (_state.canSetCodeLanguage) {
      _host.setCodeLanguage(language);
    }
  }

  void _setBlockType(
    BlockType type, {
    int? level,
    String? listType,
    bool? checked,
  }) {
    if (!_state.canSetBlockType) {
      return;
    }
    _host.setBlockType(
      type: type,
      level: level,
      listType: listType,
      checked: checked,
    );
  }

  void indent() {
    if (_state.canIndent) {
      _host.indent();
    }
  }

  void outdent() {
    if (_state.canOutdent) {
      _host.outdent();
    }
  }

  void toggleTodoBlock() {
    if (_state.canToggleTodo) {
      _host.toggleTodo();
    }
  }

  int currentBlockInsertionIndex() {
    final selection = _host.selection;
    final blockCount = _host.document.blocks.length;
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

  WenzToolbarTableContext? get tableContext {
    final selection = _host.selection;
    final path = selection?.extent.path;
    final range = selection?.tableCellRange;
    if (selection == null ||
        path == null ||
        range == null ||
        !path.isTableCellText) {
      return null;
    }
    final blockIndex = selection.extent.blockIndex;
    final block = _blockAt(_host.document, blockIndex);
    if (block is! TableBlockNode) {
      return null;
    }
    final rowIndex = path.tableRowIndex;
    final columnIndex = path.tableColumnIndex;
    if (rowIndex == null ||
        columnIndex == null ||
        block.table.cellAt(rowIndex, columnIndex) == null) {
      return null;
    }
    return WenzToolbarTableContext(
      blockIndex: blockIndex,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      range: range,
    );
  }

  void insertCodeBlock({
    int? index,
    String? blockId,
    String language = '',
    String code = '',
    DocumentSelection? selection,
  }) {
    if (!canInsertBlock) {
      return;
    }
    final insertionIndex = index ?? currentBlockInsertionIndex();
    final id = blockId ?? _nextBlockId('code');
    _host.insertBlocks(
      index: insertionIndex,
      blocks: <BlockNode>[
        CodeBlockNode(id: id, language: language, code: code),
      ],
      selection: selection ??
          DocumentSelection(
            base: DocumentPosition(
              blockId: id,
              blockIndex: insertionIndex,
              path: PositionPath.blockCode(id),
              offset: 0,
            ),
            extent: DocumentPosition(
              blockId: id,
              blockIndex: insertionIndex,
              path: PositionPath.blockCode(id),
              offset: 0,
            ),
          ),
    );
  }

  void insertCallout({
    int? index,
    String? blockId,
    String variant = CalloutBlockNode.infoVariant,
    String title = 'Tip',
    String icon = '',
    List<InlineNode> content = const <InlineNode>[],
    DocumentSelection? selection,
  }) {
    if (!canInsertBlock) {
      return;
    }
    final insertionIndex = index ?? currentBlockInsertionIndex();
    final id = blockId ?? _nextBlockId('callout');
    _host.insertBlocks(
      index: insertionIndex,
      blocks: <BlockNode>[
        CalloutBlockNode(
          id: id,
          variant: variant,
          title: title,
          icon: icon,
          content: content,
        ),
      ],
      selection: selection ??
          DocumentSelection(
            base: DocumentPosition(
              blockId: id,
              blockIndex: insertionIndex,
              path: PositionPath.blockText(id),
              offset: 0,
            ),
            extent: DocumentPosition(
              blockId: id,
              blockIndex: insertionIndex,
              path: PositionPath.blockText(id),
              offset: 0,
            ),
          ),
    );
  }

  void insertTable({
    int? index,
    String? tableId,
    int rowCount = 3,
    int columnCount = 3,
    DocumentSelection? selection,
  }) {
    if (!canInsertBlock) {
      return;
    }
    _host.insertTable(
      index: index ?? currentBlockInsertionIndex(),
      tableId: tableId ?? _nextBlockId('table'),
      rowCount: rowCount,
      columnCount: columnCount,
      selection: selection,
    );
  }

  void insertImage({
    int? index,
    required String blockId,
    String assetId = '',
    String file = '',
    int width = 0,
    int height = 0,
    double? showWidth,
    double? showHeight,
    String caption = '',
    String altText = '',
    DocumentSelection? selection,
  }) {
    if (!canInsertImage) {
      return;
    }
    _host.insertImage(
      index: index ?? currentBlockInsertionIndex(),
      blockId: blockId,
      assetId: assetId,
      file: file,
      width: width,
      height: height,
      showWidth: showWidth,
      showHeight: showHeight,
      caption: caption,
      altText: altText,
      selection: selection,
    );
  }

  void insertVideo({
    int? index,
    required String blockId,
    String assetId = '',
    String playbackUrl = '',
    String file = '',
    String coverUrl = '',
    String title = '',
    String description = '',
    double? aspectRatio,
    FileUploadStatus uploadStatus = FileUploadStatus.none,
    String uploadError = '',
    DocumentSelection? selection,
  }) {
    if (!canInsertVideo) {
      return;
    }
    _host.insertVideo(
      index: index ?? currentBlockInsertionIndex(),
      blockId: blockId,
      assetId: assetId,
      playbackUrl: playbackUrl,
      file: file,
      coverUrl: coverUrl,
      title: title,
      description: description,
      aspectRatio: aspectRatio,
      uploadStatus: uploadStatus,
      uploadError: uploadError,
      selection: selection,
    );
  }

  void undo() => _host.undo();
  void redo() => _host.redo();

  void insertTableRow() {
    final context = tableContext;
    if (context == null || !_state.canTableStruct) {
      return;
    }
    _host.insertTableRow(
      blockIndex: context.blockIndex,
      rowIndex: context.rowIndex + 1,
    );
  }

  void insertTableColumn() {
    final context = tableContext;
    if (context == null || !_state.canTableStruct) {
      return;
    }
    _host.insertTableColumn(
      blockIndex: context.blockIndex,
      columnIndex: context.columnIndex + 1,
    );
  }

  void deleteTableRow() {
    final context = tableContext;
    if (context == null || !_state.canTableStruct) {
      return;
    }
    _host.deleteTableRow(
      blockIndex: context.blockIndex,
      rowIndex: context.rowIndex,
    );
  }

  void deleteTableColumn() {
    final context = tableContext;
    if (context == null || !_state.canTableStruct) {
      return;
    }
    _host.deleteTableColumn(
      blockIndex: context.blockIndex,
      columnIndex: context.columnIndex,
    );
  }

  void mergeTableCells() {
    final context = tableContext;
    if (context == null || !_state.canTableStruct) {
      return;
    }
    final range = context.range;
    if (!range.isSingleCell) {
      _host.mergeTableCells(
        blockIndex: range.blockIndex,
        startRow: range.startRow,
        startColumn: range.startColumn,
        endRow: range.endRow,
        endColumn: range.endColumn,
      );
      return;
    }
    _host.mergeTableCells(
      blockIndex: context.blockIndex,
      startRow: context.rowIndex,
      startColumn: context.columnIndex,
      endRow: context.rowIndex + 1,
      endColumn: context.columnIndex + 1,
    );
  }

  void splitTableCell() {
    final context = tableContext;
    if (context == null || !_state.canTableStruct) {
      return;
    }
    _host.splitTableCell(
      blockIndex: context.blockIndex,
      rowIndex: context.rowIndex,
      columnIndex: context.columnIndex,
    );
  }

  String _nextBlockId(String prefix) {
    String id;
    do {
      _generatedBlockId += 1;
      id = '$prefix-$_generatedBlockId';
    } while (_containsBlockId(_host.document.blocks, id));
    return id;
  }

  bool _containsBlockId(List<BlockNode> blocks, String id) {
    for (final block in blocks) {
      if (block.id == id) {
        return true;
      }
      if (block is TableBlockNode) {
        for (final row in block.table.rows) {
          for (final cell in row) {
            if (_containsBlockId(cell.blocks, id)) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  // ---- Lifecycle ------------------------------------------------------------

  void _handleHostChanged() {
    _recompute();
  }

  @override
  void dispose() {
    _host.removeListener(_handleHostChanged);
    super.dispose();
  }

  // ---- Snapshot computation -------------------------------------------------

  void _recompute() {
    final selection = _host.selection;
    final document = _host.document;

    if (selection == null) {
      _state = ToolbarState.empty.copyWith(
        canUndo: _host.canUndo,
        canRedo: _host.canRedo,
      );
      notifyListeners();
      return;
    }

    final extent = selection.extent;
    final start = selection.start;
    final end = selection.end;
    final isCollapsed = selection.isCollapsed;
    final extentBlock = _blockAt(document, extent.blockIndex);

    final extentTextBlock = extentBlock is TextBlockNode ? extentBlock : null;
    final extentCodeBlock =
        extentBlock is CodeBlockNode && extent.path.isBlockCode
            ? extentBlock
            : null;
    // A table cell's text lives inside a TableBlockNode, so resolve the cell's
    // first text block separately — the inline format/link/mark commands route
    // to cell-aware variants and the toolbar must read/write marks there too.
    final extentCellTextBlock = extent.path.isTableCellText
        ? tableCellTextBlockForPosition(document, extent)
        : null;
    final extentOnText = (extentTextBlock != null && extent.path.isBlockText) ||
        extentCellTextBlock != null;
    final singleBlock =
        start.blockIndex == end.blockIndex && start.path == end.path;

    // Active inline attributes over the selection.
    final InlineAttributeSummary inlineSummary;
    if (!isCollapsed) {
      if (extentCellTextBlock != null && singleBlock) {
        // Same-cell range inside a table cell: read marks off the cell's text.
        inlineSummary = _collectRangeAttributesForContent(
          extentCellTextBlock.content,
          start.offset,
          end.offset,
        );
      } else {
        inlineSummary = _collectRangeAttributes(document, start, end);
      }
    } else if (extentTextBlock case final textBlock?) {
      inlineSummary = InlineAttributeSummary.single(
        _typingAttributes(textBlock, extent.offset),
      );
    } else if (extentCellTextBlock case final cellTextBlock?) {
      inlineSummary = InlineAttributeSummary.single(
        _typingAttributes(cellTextBlock, extent.offset),
      );
    } else {
      inlineSummary = InlineAttributeSummary.empty;
    }

    // Block type uniformity across the selection.
    final blockSummary = _collectBlockType(document, start, end);

    final tableCellRange = selection.tableCellRange;
    final inTable = extent.path.isTableCellText;
    final cellStyle = _collectTableCellStyle(document, tableCellRange);
    final blockAlignment = tableCellRange == null
        ? _collectBlockAlignment(document, start, end)
        : _AlignmentSummary.empty;
    final alignment = cellStyle != null
        ? cellStyle.alignment
        : blockAlignment.alignment;
    final alignmentMixed =
        cellStyle?.alignmentMixed ?? blockAlignment.alignmentMixed;
    final canEdit = _host.canEdit;

    _state = ToolbarState(
      hasSelection: true,
      // FormatTextCommand applies to any TextBlockNode text range (collapsed
      // caret included — it sets typing attributes via the next input).
      canFormatInline: canEdit && extentOnText,
      // ToggleMarkCommand requires a single block + single path.
      canToggleMark: canEdit && extentOnText && singleBlock,
      // SetLinkCommand requires a single block + single path.
      canSetLink: canEdit && extentOnText && singleBlock,
      // SetBlockTypeCommand switches text-block types only.
      canSetBlockType: canEdit && blockSummary.hasTextBlock,
      canSetCodeLanguage: canEdit && extentCodeBlock != null,
      canIndent: canEdit && blockSummary.hasTextBlock,
      canOutdent:
          canEdit && blockSummary.hasTextBlock && blockSummary.anyIndent,
      // ToggleTodoCommand / ToggleQuoteCommand operate on text blocks.
      canToggleTodo: canEdit && blockSummary.hasTextBlock,
      canToggleQuote: canEdit && blockSummary.hasTextBlock,
      isQuoteBlock: blockSummary.allTextBlocksQuoted,
      canTableStruct: canEdit && inTable,
      canSetAlignment: canEdit &&
          (cellStyle != null ||
              (blockAlignment.hasAlignableBlock &&
                  !blockAlignment.hasTableBlock)),
      tableCellIsHeader: cellStyle?.isHeader,
      tableCellBackgroundColor: cellStyle?.backgroundColor,
      alignment: alignment,
      alignmentMixed: alignmentMixed,
      bold: inlineSummary.bold,
      italic: inlineSummary.italic,
      underline: inlineSummary.underline,
      lineThrough: inlineSummary.lineThrough,
      remark: inlineSummary.remark,
      textColor: inlineSummary.color,
      textColorMixed: inlineSummary.colorMixed,
      linkUrl: inlineSummary.url,
      uniformBlockType: blockSummary.uniformType,
      uniformListType: blockSummary.uniformListType,
      uniformHeadingLevel: blockSummary.uniformHeadingLevel,
      codeLanguage: extentCodeBlock?.language,
      canUndo: _host.canUndo,
      canRedo: _host.canRedo,
    );
    notifyListeners();
  }

  /// Typing attributes = attributes of the run immediately left of [offset],
  /// so a freshly placed caret inherits the surrounding style.
  TextAttributes _typingAttributes(TextBlockNode block, int offset) {
    var cursor = 0;
    TextAttributes? last;
    for (final node in block.content) {
      final length = inlineLength(node);
      final nodeEnd = cursor + length;
      if (node is TextRun && cursor <= offset) {
        last = node.attributes;
      }
      if (nodeEnd >= offset) {
        break;
      }
      cursor = nodeEnd;
    }
    return last ?? const TextAttributes();
  }

  InlineAttributeSummary _collectRangeAttributes(
    RichTextDocument document,
    DocumentPosition start,
    DocumentPosition end,
  ) {
    var bold = true;
    var italic = true;
    var underline = true;
    var lineThrough = true;
    var remark = true;
    String? url;
    var urlSet = false;
    int? color;
    var colorSet = false;
    var colorMixed = false;
    var sawAny = false;

    for (var i = start.blockIndex; i <= end.blockIndex; i++) {
      final block = _blockAt(document, i);
      if (block is! TextBlockNode) {
        // Non-text blocks in range don't carry marks; treat their inline
        // coverage as empty so we don't falsely clear a mark.
        continue;
      }
      final rangeStart = i == start.blockIndex ? start.offset : 0;
      final rangeEnd =
          i == end.blockIndex ? end.offset : inlineNodesLength(block.content);

      final partial = _scanAttributes(
        block.content,
        rangeStart,
        rangeEnd,
        bold: bold,
        italic: italic,
        underline: underline,
        lineThrough: lineThrough,
        remark: remark,
        url: url,
        urlSet: urlSet,
        color: color,
        colorSet: colorSet,
        colorMixed: colorMixed,
        sawAny: sawAny,
      );
      bold = partial.bold;
      italic = partial.italic;
      underline = partial.underline;
      lineThrough = partial.lineThrough;
      remark = partial.remark;
      url = partial.url;
      urlSet = partial.urlSet;
      color = partial.color;
      colorSet = partial.colorSet;
      colorMixed = partial.colorMixed;
      sawAny = partial.sawAny;
    }

    if (!sawAny) {
      return InlineAttributeSummary.empty;
    }
    return InlineAttributeSummary(
      bold: bold,
      italic: italic,
      underline: underline,
      lineThrough: lineThrough,
      remark: remark,
      url: url,
      color: colorMixed ? null : color,
      colorMixed: colorMixed,
    );
  }

  /// Same as [_collectRangeAttributes] but for a single inline content list
  /// (a cell's text block). Used by table-cell selections, which resolve to
  /// one content list rather than top-level blocks.
  InlineAttributeSummary _collectRangeAttributesForContent(
    List<InlineNode> content,
    int rangeStart,
    int rangeEnd,
  ) {
    final partial = _scanAttributes(
      content,
      rangeStart,
      rangeEnd,
      bold: true,
      italic: true,
      underline: true,
      lineThrough: true,
      remark: true,
      url: null,
      urlSet: false,
      color: null,
      colorSet: false,
      colorMixed: false,
      sawAny: false,
    );
    if (!partial.sawAny) {
      return InlineAttributeSummary.empty;
    }
    return InlineAttributeSummary(
      bold: partial.bold,
      italic: partial.italic,
      underline: partial.underline,
      lineThrough: partial.lineThrough,
      remark: partial.remark,
      url: partial.url,
      color: partial.colorMixed ? null : partial.color,
      colorMixed: partial.colorMixed,
    );
  }

  _AlignmentSummary _collectBlockAlignment(
    RichTextDocument document,
    DocumentPosition start,
    DocumentPosition end,
  ) {
    var hasAlignableBlock = false;
    var hasTableBlock = false;
    var alignmentMixed = false;
    String? uniformAlignment;

    for (var i = start.blockIndex; i <= end.blockIndex; i++) {
      final block = _blockAt(document, i);
      if (block == null) {
        continue;
      }
      if (block is TableBlockNode) {
        hasTableBlock = true;
        continue;
      }
      if (!hasAlignableBlock) {
        hasAlignableBlock = true;
        uniformAlignment = block.attributes.alignment;
        continue;
      }
      if (uniformAlignment != block.attributes.alignment) {
        alignmentMixed = true;
      }
    }

    return _AlignmentSummary(
      alignment: alignmentMixed ? null : uniformAlignment,
      alignmentMixed: alignmentMixed,
      hasAlignableBlock: hasAlignableBlock,
      hasTableBlock: hasTableBlock,
    );
  }

  _TableCellStyleSummary? _collectTableCellStyle(
    RichTextDocument document,
    TableCellRange? range,
  ) {
    if (range == null) {
      return null;
    }
    final block = _blockAt(document, range.blockIndex);
    if (block is! TableBlockNode || block.id != range.tableBlockId) {
      return null;
    }

    var hasCell = false;
    var headerMixed = false;
    var backgroundMixed = false;
    var alignmentMixed = false;
    bool? uniformHeader;
    int? uniformBackground;
    String? uniformAlignment;

    for (var row = range.startRow; row <= range.endRow; row++) {
      for (var column = range.startColumn;
          column <= range.endColumn;
          column++) {
        final cell = block.table.cellAt(row, column);
        if (cell == null || cell.covered) {
          continue;
        }
        if (!hasCell) {
          hasCell = true;
          uniformHeader = cell.isHeader;
          uniformBackground = cell.backgroundColor;
          uniformAlignment = cell.alignment;
          continue;
        }
        if (uniformHeader != cell.isHeader) {
          headerMixed = true;
        }
        if (uniformBackground != cell.backgroundColor) {
          backgroundMixed = true;
        }
        if (uniformAlignment != cell.alignment) {
          alignmentMixed = true;
        }
      }
    }

    if (!hasCell) {
      return null;
    }
    return _TableCellStyleSummary(
      isHeader: headerMixed ? null : uniformHeader,
      backgroundColor: backgroundMixed ? null : uniformBackground,
      alignment: alignmentMixed ? null : uniformAlignment,
      alignmentMixed: alignmentMixed,
    );
  }

  /// Scans [content] over [rangeStart, rangeEnd) and folds each run's marks
  /// into the running tallies. Shared by the block-range and cell-content
  /// attribute collectors.
  _AttributeScan _scanAttributes(
    List<InlineNode> content,
    int rangeStart,
    int rangeEnd, {
    required bool bold,
    required bool italic,
    required bool underline,
    required bool lineThrough,
    required bool remark,
    required String? url,
    required bool urlSet,
    required int? color,
    required bool colorSet,
    required bool colorMixed,
    required bool sawAny,
  }) {
    var cursor = 0;
    for (final node in content) {
      final nodeStart = cursor;
      final nodeEnd = cursor + inlineLength(node);
      cursor = nodeEnd;
      // Overlap test against [rangeStart, rangeEnd).
      if (nodeEnd <= rangeStart || nodeStart >= rangeEnd) {
        continue;
      }
      if (node is! TextRun) {
        continue;
      }
      sawAny = true;
      if (node.attributes.bold != true) {
        bold = false;
      }
      if (node.attributes.italic != true) {
        italic = false;
      }
      if (node.attributes.underline != true) {
        underline = false;
      }
      if (node.attributes.lineThrough != true) {
        lineThrough = false;
      }
      if (node.attributes.remark != true) {
        remark = false;
      }
      if (!urlSet) {
        url = node.attributes.url;
        urlSet = true;
      } else if (node.attributes.url != url) {
        url = null;
      }
      if (!colorSet) {
        color = node.attributes.color;
        colorSet = true;
      } else if (node.attributes.color != color) {
        color = null;
        colorMixed = true;
      }
    }
    return _AttributeScan(
      bold: bold,
      italic: italic,
      underline: underline,
      lineThrough: lineThrough,
      remark: remark,
      url: url,
      urlSet: urlSet,
      color: color,
      colorSet: colorSet,
      colorMixed: colorMixed,
      sawAny: sawAny,
    );
  }

  _BlockTypeSummary _collectBlockType(
    RichTextDocument document,
    DocumentPosition start,
    DocumentPosition end,
  ) {
    BlockType? uniformType;
    var blockTypeMixed = false;
    String? uniformListType;
    var listTypeMixed = false;
    int? uniformHeadingLevel;
    var headingLevelMixed = false;
    var hasTextBlock = false;
    var allTextBlocksQuoted = true;
    var anyIndent = false;
    var seenAny = false;

    for (var i = start.blockIndex; i <= end.blockIndex; i++) {
      final block = _blockAt(document, i);
      if (block == null) {
        continue;
      }
      if (block is! TextBlockNode) {
        // Mixed with a non-text block: no uniform type. Keep scanning so
        // hasTextBlock stays accurate for the remaining blocks.
        allTextBlocksQuoted = false;
        if (seenAny) {
          blockTypeMixed = true;
        }
        seenAny = true;
        continue;
      }
      hasTextBlock = true;
      if (block.type != BlockType.quote && !block.attributes.isQuoted) {
        allTextBlocksQuoted = false;
      }
      if (block.attributes.indent != null && block.attributes.indent! > 0) {
        anyIndent = true;
      }
      if (!seenAny) {
        uniformType = block.type;
        uniformListType = _canonicalListType(block);
        uniformHeadingLevel =
            block.type == BlockType.heading ? block.attributes.level : null;
        seenAny = true;
      } else {
        if (block.type != uniformType) {
          blockTypeMixed = true;
        }
        final candidateListType = _canonicalListType(block);
        if (candidateListType != uniformListType) {
          listTypeMixed = true;
        }
        if (block.type == BlockType.heading) {
          if (block.attributes.level != uniformHeadingLevel) {
            headingLevelMixed = true;
          }
        } else if (uniformHeadingLevel != null) {
          headingLevelMixed = true;
        }
      }
    }

    return _BlockTypeSummary(
      uniformType: blockTypeMixed ? null : uniformType,
      uniformListType: listTypeMixed ? null : uniformListType,
      uniformHeadingLevel: headingLevelMixed ? null : uniformHeadingLevel,
      hasTextBlock: hasTextBlock,
      allTextBlocksQuoted: hasTextBlock && allTextBlocksQuoted,
      anyIndent: anyIndent,
    );
  }

  /// Normalises the stored listType to the canonical values the schema emits
  /// post-normalize: `'ordered'` / `'task'` / `null` (unordered). Legacy
  /// aliases are mapped so the toolbar reads the same value the schema would.
  String? _canonicalListType(TextBlockNode block) {
    if (block.type != BlockType.listItem) {
      return null;
    }
    final raw = block.attributes.listType;
    switch (raw) {
      case 'ordered':
      case 'oli':
        return 'ordered';
      case 'task':
      case 'check':
        return 'task';
      default:
        return null;
    }
  }

  BlockNode? _blockAt(RichTextDocument document, int index) {
    if (index < 0 || index >= document.blocks.length) {
      return null;
    }
    return document.blocks[index];
  }
}

/// Aggregated inline attributes across a selection. Each bool is `true` only
/// when every covered run has the mark set; the URL/color is `null` when the
/// range has none. Color additionally exposes [colorMixed] to distinguish no
/// inline color from mixed color states.
class InlineAttributeSummary {
  const InlineAttributeSummary({
    required this.bold,
    required this.italic,
    required this.underline,
    required this.lineThrough,
    required this.remark,
    required this.url,
    required this.color,
    required this.colorMixed,
  });

  factory InlineAttributeSummary.single(TextAttributes attrs) {
    return InlineAttributeSummary(
      bold: attrs.bold == true,
      italic: attrs.italic == true,
      underline: attrs.underline == true,
      lineThrough: attrs.lineThrough == true,
      remark: attrs.remark == true,
      url: attrs.url,
      color: attrs.color,
      colorMixed: false,
    );
  }

  static const InlineAttributeSummary empty = InlineAttributeSummary(
    bold: false,
    italic: false,
    underline: false,
    lineThrough: false,
    remark: false,
    url: null,
    color: null,
    colorMixed: false,
  );

  final bool bold;
  final bool italic;
  final bool underline;
  final bool lineThrough;
  final bool remark;
  final String? url;
  final int? color;
  final bool colorMixed;
}

class _TableCellStyleSummary {
  const _TableCellStyleSummary({
    required this.isHeader,
    required this.backgroundColor,
    required this.alignment,
    required this.alignmentMixed,
  });

  final bool? isHeader;
  final int? backgroundColor;
  final String? alignment;
  final bool alignmentMixed;
}

class _AlignmentSummary {
  const _AlignmentSummary({
    required this.alignment,
    required this.alignmentMixed,
    required this.hasAlignableBlock,
    required this.hasTableBlock,
  });

  static const _AlignmentSummary empty = _AlignmentSummary(
    alignment: null,
    alignmentMixed: false,
    hasAlignableBlock: false,
    hasTableBlock: false,
  );

  final String? alignment;
  final bool alignmentMixed;
  final bool hasAlignableBlock;
  final bool hasTableBlock;
}

/// Running tallies produced by [ToolbarController._scanAttributes] while
/// folding a content list's inline marks. Private to the attribute collectors.
class _AttributeScan {
  const _AttributeScan({
    required this.bold,
    required this.italic,
    required this.underline,
    required this.lineThrough,
    required this.remark,
    required this.url,
    required this.urlSet,
    required this.color,
    required this.colorSet,
    required this.colorMixed,
    required this.sawAny,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool lineThrough;
  final bool remark;
  final String? url;
  final bool urlSet;
  final int? color;
  final bool colorSet;
  final bool colorMixed;
  final bool sawAny;
}

class _BlockTypeSummary {
  const _BlockTypeSummary({
    this.uniformType,
    this.uniformListType,
    this.uniformHeadingLevel,
    required this.hasTextBlock,
    required this.allTextBlocksQuoted,
    required this.anyIndent,
  });

  final BlockType? uniformType;
  final String? uniformListType;
  final int? uniformHeadingLevel;
  final bool hasTextBlock;
  final bool allTextBlocksQuoted;
  final bool anyIndent;
}

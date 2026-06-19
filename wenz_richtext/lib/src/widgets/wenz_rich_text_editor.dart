import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/wenz_rich_text_controller.dart';
import '../core/commands/inline_editing.dart';
import '../core/model/attributes.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/table_model.dart';
import '../core/position/document_position.dart';
import '../input/composition_state.dart';
import '../input/editor_text_input_client.dart';
import '../rendering/text_layout_service.dart';
import 'block_geometry_registry.dart';
import 'selection_gesture_overlay.dart';

const _caretKey = ValueKey<String>('wenz-richtext-caret');
const _selectionHighlightKey = ValueKey<String>(
  'wenz-richtext-selection-highlight',
);

class WenzRichTextEditor extends StatefulWidget {
  const WenzRichTextEditor({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.all(16),
    this.blockSpacing = 8,
    this.textStyle,
    this.physics,
    this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    this.showDebugOverlay = false,
    this.enableIme = true,
  });

  final WenzRichTextController controller;
  final EdgeInsetsGeometry padding;
  final double blockSpacing;
  final TextStyle? textStyle;
  final ScrollPhysics? physics;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool readOnly;

  /// When true, overlays the active block's id, index, path, and caret offset
  /// for debugging selection behaviour. Does not affect layout or offsets.
  final bool showDebugOverlay;

  /// When true (default), attaches a [TextInput] connection on focus so the
  /// platform IME drives character entry via composition deltas. Set false to
  /// fall back to direct key-event character insertion (used by headless
  /// widget tests that inject characters via [sendKeyEvent]).
  final bool enableIme;

  @override
  State<WenzRichTextEditor> createState() => _WenzRichTextEditorState();
}

class _WenzRichTextEditorState extends State<WenzRichTextEditor> {
  FocusNode? _internalFocusNode;
  FocusNode? _listenedFocusNode;
  int _generatedBlockCount = 0;
  late final EditorTextInputClient _inputClient;
  late final BlockGeometryRegistry _registry = BlockGeometryRegistry();
  late final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _inputClient = EditorTextInputClient(widget.controller);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant WenzRichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _listenedFocusNode?.removeListener(_handleFocusChanged);
    _inputClient.detach();
    _scrollController.dispose();
    _registry.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleFocusChanged() {
    if (!mounted) {
      return;
    }
    final focusNode = _effectiveFocusNode;
    if (widget.enableIme && focusNode.hasFocus && !widget.readOnly) {
      _inputClient.attach();
    } else {
      _inputClient.detach();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final focusNode = _effectiveFocusNode;
    _syncFocusListener(focusNode);
    final blocks = widget.controller.document.blocks;
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show a caret only in editable mode. Read-only mode still allows
    // selection (see _handleSelectionChanged) but has no editing caret.
    final showCaret = !widget.readOnly &&
        focusNode.hasFocus &&
        widget.controller.selection?.isCollapsed == true;
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) {
        children.add(SizedBox(height: widget.blockSpacing));
      }
      children.add(
        _BlockRenderer(
          block: blocks[i],
          blockIndex: i,
          selection: widget.controller.selection,
          compositionState: widget.controller.compositionState,
          registry: _registry,
          showCaret: showCaret,
          textStyle: widget.textStyle,
          showDebugOverlay: widget.showDebugOverlay,
        ),
      );
    }

    final editor = SingleChildScrollView(
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    return Focus(
      focusNode: focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: SelectionGestureOverlay(
        registry: _registry,
        scrollController: _scrollController,
        focusNode: focusNode,
        readOnly: widget.readOnly,
        onSelectionChanged: _handleSelectionChanged,
        child: editor,
      ),
    );
  }

  void _handleSelectionChanged(DocumentSelection selection) {
    widget.controller.setSelection(selection);
    // A selection change from the gesture overlay repositions the caret, so
    // refresh the IME buffer so the platform input follows the new location.
    _inputClient.syncBuffer();
  }

  FocusNode get _effectiveFocusNode {
    return widget.focusNode ??
        (_internalFocusNode ??= FocusNode(debugLabel: 'WenzRichTextEditor'));
  }

  void _syncFocusListener(FocusNode focusNode) {
    if (_listenedFocusNode == focusNode) {
      return;
    }
    _listenedFocusNode?.removeListener(_handleFocusChanged);
    focusNode.addListener(_handleFocusChanged);
    _listenedFocusNode = focusNode;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final shift = keyboard.isShiftPressed;
    final primary = keyboard.isControlPressed || keyboard.isMetaPressed;

    // Ctrl/Cmd + ... shortcuts (Copy is allowed in read-only mode).
    if (primary) {
      final result = _handleShortcut(event.logicalKey, shift);
      if (result != null) {
        return result;
      }
      // Unrecognised Ctrl/Cmd combo: let it propagate (e.g. browser Ctrl+S,
      // dev tools) rather than swallowing everything.
      return KeyEventResult.ignored;
    }

    if (widget.readOnly) {
      // In read-only mode only copy works; everything else is ignored.
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab) {
      widget.controller.moveTableCell(forward: !shift);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.controller.moveCaretBackward(expandSelection: shift);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      widget.controller.moveCaretForward(expandSelection: shift);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      widget.controller.moveCaretToBlockBoundary(
        forward: false,
        expandSelection: shift,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      widget.controller.moveCaretToBlockBoundary(
        forward: true,
        expandSelection: shift,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      widget.controller.moveCaretToBlockBoundary(
        forward: false,
        expandSelection: shift,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      widget.controller.moveCaretToBlockBoundary(
        forward: true,
        expandSelection: shift,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      widget.controller.deleteBackward();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      widget.controller.deleteForward();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      widget.controller.enter(newBlockId: _nextBlockId());
      return KeyEventResult.handled;
    }
    // Plain character input. When the IME bridge is attached, character entry
    // arrives via TextEditingDelta and we let the platform own it (return
    // ignored). When IME is not attached (e.g. headless tests), fall back to
    // inserting the key event's character directly.
    final character = event.character;
    if (character == null ||
        character.isEmpty ||
        _isControlCharacter(character)) {
      return KeyEventResult.ignored;
    }
    if (_inputClient.isAttached) {
      return KeyEventResult.ignored;
    }
    widget.controller.insertText(character);
    return KeyEventResult.handled;
  }

  /// Handles Ctrl/Cmd + key shortcuts. Returns `null` when the combo is not a
  /// recognised shortcut (the caller decides whether to swallow or ignore).
  KeyEventResult? _handleShortcut(LogicalKeyboardKey key, bool shift) {
    final controller = widget.controller;
    if (key == LogicalKeyboardKey.keyA) {
      // Select-all is allowed in read-only mode (read-only supports
      // selection/copy workflows).
      controller.selectAll();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyZ) {
      if (widget.readOnly) {
        return KeyEventResult.ignored;
      }
      if (shift) {
        controller.redo();
      } else {
        controller.undo();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyY) {
      if (widget.readOnly) {
        return KeyEventResult.ignored;
      }
      controller.redo();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      controller.moveCaretByWord(forward: false, expandSelection: shift);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      controller.moveCaretByWord(forward: true, expandSelection: shift);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      controller.moveCaretToDocumentBoundary(
        forward: false,
        expandSelection: shift,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      controller.moveCaretToDocumentBoundary(
        forward: true,
        expandSelection: shift,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyC) {
      // Copy works in read-only mode too.
      _handleCopy();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyX) {
      if (widget.readOnly) {
        return KeyEventResult.ignored;
      }
      _handleCut();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyV) {
      if (widget.readOnly) {
        return KeyEventResult.ignored;
      }
      _handlePaste();
      return KeyEventResult.handled;
    }
    return null;
  }

  Future<void> _handleCopy() async {
    final payload = widget.controller.copySelection();
    if (payload == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: payload));
  }

  Future<void> _handleCut() async {
    final payload = widget.controller.cutSelection();
    if (payload == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: payload));
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }
    widget.controller.pasteText(text);
  }

  String _nextBlockId() {
    _generatedBlockCount += 1;
    return 'block-${DateTime.now().microsecondsSinceEpoch}-$_generatedBlockCount';
  }
}

class _BlockRenderer extends StatelessWidget {
  const _BlockRenderer({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    this.textStyle,
    this.showDebugOverlay = false,
  });

  final BlockNode block;
  final int blockIndex;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: EdgeInsetsDirectional.only(
        start: (block.attributes.indent ?? 0) * 24,
      ),
      child: switch (block) {
        final TextBlockNode textBlock => _TextBlockRenderer(
            block: textBlock,
            blockIndex: blockIndex,
            selection: selection,
            compositionState: compositionState,
            registry: registry,
            showCaret: showCaret,
            textStyle: textStyle,
            showDebugOverlay: showDebugOverlay,
          ),
        final CodeBlockNode codeBlock => _CodeBlockRenderer(
            block: codeBlock,
            blockIndex: blockIndex,
            selection: selection,
            compositionState: compositionState,
            registry: registry,
            showCaret: showCaret,
            showDebugOverlay: showDebugOverlay,
          ),
        final ImageBlockNode imageBlock => _MediaPlaceholder(
            label: 'image',
            value: _assetLabel(imageBlock.assetId, imageBlock.file),
          ),
        final TableBlockNode tableBlock => _TableBlockRenderer(
            block: tableBlock,
            blockIndex: blockIndex,
            selection: selection,
            compositionState: compositionState,
            registry: registry,
            showCaret: showCaret,
            textStyle: textStyle,
            showDebugOverlay: showDebugOverlay,
          ),
        final DividerBlockNode _ => const Divider(height: 1),
        final VideoBlockNode videoBlock => _MediaPlaceholder(
            label: 'video',
            value: _assetLabel(videoBlock.assetId, videoBlock.file),
          ),
        final CalloutBlockNode calloutBlock => _CalloutRenderer(
            block: calloutBlock,
            textStyle: textStyle,
          ),
        final FileBlockNode fileBlock => _MediaPlaceholder(
            label: 'file',
            value: fileBlock.name.isNotEmpty ? fileBlock.name : fileBlock.assetId,
          ),
        _ => Text(block.plainText),
      },
    );
    return child;
  }
}

class _TextBlockRenderer extends StatelessWidget {
  const _TextBlockRenderer({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    this.textStyle,
    this.showDebugOverlay = false,
  });

  final TextBlockNode block;
  final int blockIndex;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = _blockTextStyle(
      context,
      block,
      textStyle ?? DefaultTextStyle.of(context).style,
    );
    final compositionRange = _localCompositionRange(
      compositionState,
      block.id,
      blockIndex,
      PositionPath.blockText(block.id),
    );
    final text = _TextSelectionSurface(
      blockId: block.id,
      blockIndex: blockIndex,
      path: PositionPath.blockText(block.id),
      textLength: inlineNodesLength(block.content),
      textSpan: TextSpan(
        style: effectiveStyle,
        children: _inlineSpansFor(
          block.content,
          effectiveStyle,
          compositionRange,
        ),
      ),
      textAlign: _textAlign(block.attributes.alignment),
      minHeight: (effectiveStyle.fontSize ?? 14) * 1.35,
      selection: selection,
      showCaret: showCaret,
      registry: registry,
      showDebugOverlay: showDebugOverlay,
    );
    final prefix = _prefixFor(block);
    if (prefix == null) {
      return text;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 32,
          child: Text(prefix, style: effectiveStyle, textAlign: TextAlign.end),
        ),
        const SizedBox(width: 8),
        Expanded(child: text),
      ],
    );
  }
}

class _CodeBlockRenderer extends StatelessWidget {
  const _CodeBlockRenderer({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    this.showDebugOverlay = false,
  });

  final CodeBlockNode block;
  final int blockIndex;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final bool showDebugOverlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codeStyle = theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          fontSize: 13,
        ) ??
        const TextStyle(fontFamily: 'monospace', fontSize: 13);
    final compositionRange = _localCompositionRange(
      compositionState,
      block.id,
      blockIndex,
      PositionPath.blockCode(block.id),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _TextSelectionSurface(
          blockId: block.id,
          blockIndex: blockIndex,
          path: PositionPath.blockCode(block.id),
          textLength: block.code.length,
          textSpan: _codeSpan(block.code, codeStyle, compositionRange),
          textAlign: TextAlign.start,
          minHeight: (codeStyle.fontSize ?? 13) * 1.35,
          selection: selection,
          showCaret: showCaret,
          registry: registry,
          showDebugOverlay: showDebugOverlay,
        ),
      ),
    );
  }
}

class _TableBlockRenderer extends StatelessWidget {
  const _TableBlockRenderer({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    this.textStyle,
    this.showDebugOverlay = false,
  });

  final TableBlockNode block;
  final int blockIndex;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;

  @override
  Widget build(BuildContext context) {
    final table = block.table;
    final columnCount = table.columnCount;
    if (table.rowCount == 0 || columnCount == 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final effectiveStyle = textStyle ?? DefaultTextStyle.of(context).style;
    return Table(
      border: TableBorder.all(color: theme.dividerColor),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: <int, TableColumnWidth>{
        for (var i = 0; i < columnCount; i++)
          i: table.columnWidths[i] == null
              ? const FlexColumnWidth()
              : FixedColumnWidth(table.columnWidths[i]!),
      },
      children: <TableRow>[
        for (var rowIndex = 0; rowIndex < table.rowCount; rowIndex++)
          TableRow(
            children: <Widget>[
              for (var columnIndex = 0;
                  columnIndex < columnCount;
                  columnIndex++)
                _TableCellSurface(
                  tableBlock: block,
                  blockIndex: blockIndex,
                  rowIndex: rowIndex,
                  columnIndex: columnIndex,
                  cell: table.cellAt(rowIndex, columnIndex),
                  textStyle: effectiveStyle,
                  textAlign: _textAlign(table.columnAlignments[columnIndex]),
                  selection: selection,
                  compositionState: compositionState,
                  registry: registry,
                  showCaret: showCaret,
                  highlightWholeCell: _shouldHighlightTableCell(
                    selection,
                    block.id,
                    blockIndex,
                    rowIndex,
                    columnIndex,
                  ),
                  showDebugOverlay: showDebugOverlay,
                ),
            ],
          ),
      ],
    );
  }
}

bool _shouldHighlightTableCell(
  DocumentSelection? selection,
  String tableBlockId,
  int blockIndex,
  int rowIndex,
  int columnIndex,
) {
  final range = selection?.tableCellRange;
  if (range == null || range.isSingleCell) {
    return false;
  }
  return range.tableBlockId == tableBlockId &&
      range.blockIndex == blockIndex &&
      range.containsCell(rowIndex, columnIndex);
}

class _TableCellSurface extends StatelessWidget {
  const _TableCellSurface({
    required this.tableBlock,
    required this.blockIndex,
    required this.rowIndex,
    required this.columnIndex,
    required this.cell,
    required this.textStyle,
    required this.textAlign,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    required this.highlightWholeCell,
    required this.showDebugOverlay,
  });

  final TableBlockNode tableBlock;
  final int blockIndex;
  final int rowIndex;
  final int columnIndex;
  final TableCellNode? cell;
  final TextStyle textStyle;
  final TextAlign textAlign;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final bool highlightWholeCell;
  final bool showDebugOverlay;

  @override
  Widget build(BuildContext context) {
    if (cell?.covered ?? false) {
      return const SizedBox.shrink();
    }
    final path = PositionPath.tableCellText(
      tableBlock.id,
      rowIndex,
      columnIndex,
    );
    final compositionRange = _localCompositionRange(
      compositionState,
      tableBlock.id,
      blockIndex,
      path,
    );
    final text = cell?.plainText ?? '';
    final displayText = text.isEmpty ? ' ' : text;
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.primary.withAlpha(54);
    final effectiveTextStyle = (cell?.isHeader ?? false)
        ? textStyle.copyWith(fontWeight: FontWeight.w600)
        : textStyle;
    final backgroundColor = cell?.backgroundColor == null
        ? null
        : Color(cell!.backgroundColor!);
    final surface = _TextSelectionSurface(
      blockId: tableBlock.id,
      blockIndex: blockIndex,
      path: path,
      textLength: text.length,
      textSpan: _codeSpan(displayText, effectiveTextStyle, compositionRange),
      textAlign: textAlign,
      minHeight: (textStyle.fontSize ?? 14) * 1.35,
      selection: selection,
      showCaret: showCaret,
      registry: registry,
      showDebugOverlay: showDebugOverlay,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: <Widget>[
            if (highlightWholeCell)
              Positioned.fill(
                child: DecoratedBox(
                  key: _selectionHighlightKey,
                  decoration: BoxDecoration(color: highlightColor),
                ),
              ),
            surface,
          ],
        ),
      ),
    );
  }
}

class _TextSelectionSurface extends StatefulWidget {
  const _TextSelectionSurface({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.textLength,
    required this.textSpan,
    required this.textAlign,
    required this.minHeight,
    required this.selection,
    required this.showCaret,
    required this.registry,
    required this.showDebugOverlay,
  });

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int textLength;
  final InlineSpan textSpan;
  final TextAlign textAlign;
  final double minHeight;
  final DocumentSelection? selection;
  final bool showCaret;
  final BlockGeometryRegistry registry;
  final bool showDebugOverlay;

  @override
  State<_TextSelectionSurface> createState() => _TextSelectionSurfaceState();
}

class _TextSelectionSurfaceState extends State<_TextSelectionSurface> {
  final TextLayoutService _layoutService = TextLayoutService();
  final GlobalKey _surfaceKey = GlobalKey();
  double _lastMaxWidth = 0;

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(covariant _TextSelectionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blockId != widget.blockId || oldWidget.path != widget.path) {
      widget.registry.unregister(oldWidget.blockId, oldWidget.path);
    }
    if (oldWidget.blockId != widget.blockId ||
        oldWidget.blockIndex != widget.blockIndex ||
        oldWidget.path != widget.path ||
        oldWidget.textLength != widget.textLength ||
        oldWidget.textSpan != widget.textSpan) {
      _register();
    }
  }

  @override
  void dispose() {
    widget.registry.unregister(widget.blockId, widget.path);
    _layoutService.forget();
    super.dispose();
  }

  void _register() {
    widget.registry.register(
      BlockEntry(
        blockId: widget.blockId,
        blockIndex: widget.blockIndex,
        path: widget.path,
        textLength: widget.textLength,
        key: _surfaceKey,
        positionFromLocal: _offsetForLocalPosition,
        wordRangeAt: _wordRangeAt,
      ),
    );
  }

  int _offsetForLocalPosition(Offset localPosition) {
    final painter = _layoutService.layout(
      span: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: Directionality.of(context),
      maxWidth: _lastMaxWidth,
    );
    return _layoutService.offsetAt(painter, localPosition, widget.textLength);
  }

  TextRange _wordRangeAt(int offset) {
    final painter = _layoutService.layout(
      span: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: Directionality.of(context),
      maxWidth: _lastMaxWidth,
    );
    return _layoutService.wordRangeAt(painter, offset);
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final selectionRange = _selectionRangeForPath(
      widget.selection,
      widget.blockIndex,
      widget.path,
      widget.textLength,
    );
    final caretOffset = _caretOffsetForPath(
      widget.selection,
      widget.showCaret,
      widget.blockId,
      widget.path,
      widget.textLength,
    );
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.primary.withAlpha(54);
    final caretColor = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        _lastMaxWidth = maxWidth;
        // Warm the layout cache so painters and hit-testing reuse the same
        // laid-out TextPainter this frame.
        _layoutService.layout(
          span: widget.textSpan,
          textAlign: widget.textAlign,
          textDirection: direction,
          maxWidth: maxWidth,
        );
        final text = CustomPaint(
          painter: _SelectionHighlightPainter(
            layoutService: _layoutService,
            textSpan: widget.textSpan,
            textAlign: widget.textAlign,
            textDirection: direction,
            maxWidth: maxWidth,
            range: selectionRange,
            color: highlightColor,
          ),
          foregroundPainter: _CaretPainter(
            layoutService: _layoutService,
            textSpan: widget.textSpan,
            textAlign: widget.textAlign,
            textDirection: direction,
            maxWidth: maxWidth,
            caretOffset: caretOffset,
            color: caretColor,
            textLength: widget.textLength,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            child: RichText(
              text: widget.textSpan,
              textAlign: widget.textAlign,
              textDirection: direction,
            ),
          ),
        );

        // Gestures live in the document-level SelectionGestureOverlay; the
        // surface only renders text, highlight, caret, and registers its
        // geometry for cross-block hit-testing.
        return Stack(
          key: _surfaceKey,
          children: <Widget>[
            text,
            if (selectionRange != null)
              const Positioned.fill(
                child: IgnorePointer(
                  child: SizedBox(key: _selectionHighlightKey),
                ),
              ),
            if (caretOffset != null)
              const Positioned.fill(
                child: IgnorePointer(child: SizedBox(key: _caretKey)),
              ),
            if (widget.showDebugOverlay)
              Positioned(
                top: 0,
                right: 0,
                child: IgnorePointer(
                  child: _DebugSelectionTag(
                    blockId: widget.blockId,
                    blockIndex: widget.blockIndex,
                    path: widget.path,
                    offset: caretOffset ?? selectionRange?.end,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DebugSelectionTag extends StatelessWidget {
  const _DebugSelectionTag({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.offset,
  });

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int? offset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withAlpha(220),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '#$blockIndex ${blockId.isEmpty ? "<blockId>" : blockId}\n'
        '${path.toString()}\n'
        'offset=${offset ?? "-"}',
        style: theme.textTheme.labelSmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _LocalSelectionRange {
  const _LocalSelectionRange({required this.start, required this.end});

  final int start;
  final int end;
}

class _SelectionHighlightPainter extends CustomPainter {
  const _SelectionHighlightPainter({
    required this.layoutService,
    required this.textSpan,
    required this.textAlign,
    required this.textDirection,
    required this.maxWidth,
    required this.range,
    required this.color,
  });

  final TextLayoutService layoutService;
  final InlineSpan textSpan;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double maxWidth;
  final _LocalSelectionRange? range;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final range = this.range;
    if (range == null || range.start == range.end) {
      return;
    }
    final painter = layoutService.layout(
      span: textSpan,
      textAlign: textAlign,
      textDirection: textDirection,
      maxWidth: maxWidth,
    );
    final boxes = layoutService.selectionBoxes(painter, range.start, range.end);
    final paint = Paint()..color = color;
    for (final box in boxes) {
      canvas.drawRect(box.toRect(), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionHighlightPainter oldDelegate) {
    return oldDelegate.textSpan != textSpan ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.maxWidth != maxWidth ||
        oldDelegate.range?.start != range?.start ||
        oldDelegate.range?.end != range?.end ||
        oldDelegate.color != color;
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter({
    required this.layoutService,
    required this.textSpan,
    required this.textAlign,
    required this.textDirection,
    required this.maxWidth,
    required this.caretOffset,
    required this.color,
    required this.textLength,
  });

  final TextLayoutService layoutService;
  final InlineSpan textSpan;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double maxWidth;
  final int? caretOffset;
  final Color color;
  final int textLength;

  @override
  void paint(Canvas canvas, Size size) {
    final caretOffset = this.caretOffset;
    if (caretOffset == null) {
      return;
    }
    final painter = layoutService.layout(
      span: textSpan,
      textAlign: textAlign,
      textDirection: textDirection,
      maxWidth: maxWidth,
    );
    final safeOffset = caretOffset.clamp(0, textLength).toInt();
    final caretTop = layoutService.caretOffset(painter, safeOffset);
    final height = layoutService.caretHeight(painter, safeOffset) ?? 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    canvas.drawLine(caretTop, caretTop.translate(0, height), paint);
  }

  @override
  bool shouldRepaint(covariant _CaretPainter oldDelegate) {
    return oldDelegate.textSpan != textSpan ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.maxWidth != maxWidth ||
        oldDelegate.caretOffset != caretOffset ||
        oldDelegate.color != color ||
        oldDelegate.textLength != textLength;
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text('[$label: $value]'),
      ),
    );
  }
}

class _CalloutRenderer extends StatelessWidget {
  const _CalloutRenderer({required this.block, this.textStyle});

  final CalloutBlockNode block;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = textStyle ?? DefaultTextStyle.of(context).style;
    final tint = _calloutTint(theme, block.variant);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: RichText(
          text: TextSpan(
            style: base,
            children: block.content
                .map((node) => _inlineSpanFor(node, base, decorate: false))
                .toList(),
          ),
        ),
      ),
    );
  }
}

Color _calloutTint(ThemeData theme, String variant) {
  final scheme = theme.colorScheme;
  switch (variant) {
    case 'warning':
      return scheme.errorContainer.withAlpha(80);
    case 'success':
      return scheme.primaryContainer.withAlpha(80);
    case 'info':
    default:
      return scheme.surfaceContainerHighest;
  }
}

TextStyle _blockTextStyle(
  BuildContext context,
  TextBlockNode block,
  TextStyle baseStyle,
) {
  final theme = Theme.of(context);
  return switch (block.type) {
    BlockType.heading => baseStyle.merge(
        theme.textTheme.titleLarge?.copyWith(
          fontSize: _headingSize(block.attributes.level),
          fontWeight: FontWeight.w700,
        ),
      ),
    BlockType.quote => baseStyle.merge(
        theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
      ),
    _ => baseStyle.merge(theme.textTheme.bodyMedium),
  };
}

/// Builds the inline spans for a text block, overlaying the IME composition
/// decoration (underline) on the runs that fall inside [compositionRange].
List<InlineSpan> _inlineSpansFor(
  List<InlineNode> nodes,
  TextStyle baseStyle,
  _LocalSelectionRange? compositionRange,
) {
  if (compositionRange == null) {
    return nodes
        .map((node) => _inlineSpanFor(node, baseStyle, decorate: false))
        .toList();
  }
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final node in nodes) {
    final length = inlineLength(node);
    final nodeStart = cursor;
    final nodeEnd = cursor + length;
    cursor = nodeEnd;
    final overlaps =
        nodeEnd > compositionRange.start && nodeStart < compositionRange.end;
    spans.add(_inlineSpanFor(node, baseStyle, decorate: overlaps));
  }
  return spans;
}

TextSpan _inlineSpanFor(
  InlineNode node,
  TextStyle baseStyle, {
  bool decorate = false,
}) {
  final style = decorate
      ? _textStyleForAttributes(baseStyle, node is TextRun ? node.attributes : const TextAttributes())
          .copyWith(decoration: TextDecoration.underline)
      : switch (node) {
          final TextRun textRun =>
            _textStyleForAttributes(baseStyle, textRun.attributes),
          final InlineEmbed embed =>
            _textStyleForAttributes(baseStyle, embed.attributes),
          _ => baseStyle,
        };
  return switch (node) {
    final TextRun textRun => TextSpan(text: textRun.text, style: style),
    final InlineEmbed embed =>
      TextSpan(text: _embedDisplayText(embed), style: style),
    _ => TextSpan(text: node.plainText, style: style),
  };
}

String _embedDisplayText(InlineEmbed embed) {
  return switch (embed.embedType) {
    'mention' => '@${embed.data['label'] ?? embed.data['id'] ?? ''}',
    'image' => '[img]',
    'formula' => '[formula]',
    _ => '[${embed.embedType}]',
  };
}

/// Splits a code string into up to three spans, underlining the composition
/// region.
TextSpan _codeSpan(
  String code,
  TextStyle codeStyle,
  _LocalSelectionRange? compositionRange,
) {
  if (compositionRange == null || compositionRange.start == compositionRange.end) {
    return TextSpan(text: code, style: codeStyle);
  }
  final start = compositionRange.start.clamp(0, code.length).toInt();
  final end = compositionRange.end.clamp(start, code.length).toInt();
  final children = <TextSpan>[
    if (start > 0) TextSpan(text: code.substring(0, start), style: codeStyle),
    TextSpan(
      text: code.substring(start, end),
      style: codeStyle.copyWith(decoration: TextDecoration.underline),
    ),
    if (end < code.length) TextSpan(text: code.substring(end), style: codeStyle),
  ];
  return TextSpan(style: codeStyle, children: children);
}

/// Maps a [CompositionState] to a local offset range when it targets the given
/// block/path, otherwise returns null.
_LocalSelectionRange? _localCompositionRange(
  CompositionState? state,
  String blockId,
  int blockIndex,
  PositionPath path,
) {
  if (state == null ||
      state.blockId != blockId ||
      state.blockIndex != blockIndex ||
      state.path != path ||
      state.isEmpty) {
    return null;
  }
  return _LocalSelectionRange(
    start: state.startOffset,
    end: state.endOffset,
  );
}

int? _caretOffsetForPath(
  DocumentSelection? selection,
  bool showCaret,
  String blockId,
  PositionPath path,
  int textLength,
) {
  if (!showCaret || selection == null || !selection.isCollapsed) {
    return null;
  }
  final position = selection.extent;
  if (position.blockId != blockId || position.path != path) {
    return null;
  }
  return position.offset.clamp(0, textLength).toInt();
}

_LocalSelectionRange? _selectionRangeForPath(
  DocumentSelection? selection,
  int blockIndex,
  PositionPath path,
  int textLength,
) {
  if (selection == null || selection.isCollapsed) {
    return null;
  }
  final start = selection.start;
  final end = selection.end;
  int? localStart;
  int? localEnd;

  if (start.blockIndex == blockIndex && start.path == path) {
    localStart = start.offset;
  } else if (blockIndex > start.blockIndex) {
    localStart = 0;
  }

  if (end.blockIndex == blockIndex && end.path == path) {
    localEnd = end.offset;
  } else if (blockIndex < end.blockIndex) {
    localEnd = textLength;
  }

  if (localStart == null || localEnd == null) {
    return null;
  }
  final safeStart = localStart.clamp(0, textLength).toInt();
  final safeEnd = localEnd.clamp(0, textLength).toInt();
  if (safeStart == safeEnd) {
    return null;
  }
  return _LocalSelectionRange(
    start: safeStart < safeEnd ? safeStart : safeEnd,
    end: safeStart < safeEnd ? safeEnd : safeStart,
  );
}

TextStyle _textStyleForAttributes(TextStyle baseStyle, TextAttributes attrs) {
  final decorations = <TextDecoration>[
    if (attrs.underline == true || attrs.url != null) TextDecoration.underline,
    if (attrs.lineThrough == true) TextDecoration.lineThrough,
  ];
  return baseStyle.copyWith(
    color: attrs.color != null
        ? Color(attrs.color!)
        : attrs.url != null
            ? Colors.blue
            : null,
    backgroundColor: attrs.background != null ? Color(attrs.background!) : null,
    fontWeight: attrs.bold == true ? FontWeight.w700 : null,
    fontStyle: attrs.italic == true ? FontStyle.italic : null,
    fontSize: attrs.fontSize,
    fontFamily: attrs.fontFamily,
    decoration:
        decorations.isEmpty ? null : TextDecoration.combine(decorations),
  );
}

TextAlign _textAlign(String? alignment) {
  return switch (alignment) {
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    'justify' => TextAlign.justify,
    _ => TextAlign.start,
  };
}

double _headingSize(int? level) {
  return switch (level) {
    1 => 24,
    2 => 21,
    3 => 18,
    _ => 16,
  };
}

String? _prefixFor(TextBlockNode block) {
  return switch (block.type) {
    BlockType.quote => '|',
    BlockType.listItem => switch (block.attributes.listType) {
        'ordered' => '1.',
        'task' => block.attributes.checked == true ? '[x]' : '[ ]',
        _ => '-',
      },
    _ => null,
  };
}

String _assetLabel(String assetId, String file) {
  if (file.isNotEmpty) {
    return file;
  }
  if (assetId.isNotEmpty) {
    return assetId;
  }
  return 'unknown';
}

bool _isControlCharacter(String character) {
  // Reject C0 control characters (and DEL). Previously only \n \r \t were
  // filtered, which let other control chars from IME/composition events slip
  // through and corrupt the document.
  final codeUnit = character.codeUnitAt(0);
  return codeUnit < 0x20 || codeUnit == 0x7F;
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../controller/wenz_rich_text_controller.dart';
import '../core/commands/table_cell_editing.dart';
import '../core/model/block_node.dart';
import '../core/position/document_position.dart';
import 'composition_state.dart';

/// Bridges the platform text input (IME) to the editor document model.
///
/// Uses the [DeltaTextInputClient] mixin so it receives [TextEditingDelta]
/// streams, which describe precisely what the IME changed. Each delta is
/// translated into editor commands on the bound [WenzRichTextController]; the
/// composing region is mirrored to
/// [WenzRichTextController.setCompositionState] for rendering.
///
/// In addition to shuttling text deltas, the client reports the caret's
/// geometry to the platform so the system IME (e.g. the Chinese pinyin
/// candidate window) positions itself at the caret rather than at a default
/// screen location. The widget layer supplies [caretRectProvider], which
/// returns the caret's global [Rect]; it is pushed to the platform via
/// [TextInputConnection.setEditableSizeAndTransform] on attach and whenever
/// the caret moves.
///
/// Scope (stage 1): IME edits target the caret's current editable block. The
/// platform is shown a single-block plain-text buffer (the current block's
/// text), so deltas map cleanly onto offsets within that block. Cross-block
/// edits still go through the key-event path (Enter, arrows) which bypass IME.
class EditorTextInputClient with DeltaTextInputClient {
  EditorTextInputClient(this._controller);

  final WenzRichTextController _controller;
  TextInputConnection? _connection;

  /// The buffer currently shown to the platform: the plain text of the
  /// focused block plus the caret/composing regions expressed against it.
  TextEditingValue _buffer = TextEditingValue.empty;

  /// Injected by the widget layer: returns the current caret's global [Rect]
  /// (top-left + height), or `null` when no caret is visible. Used to position
  /// the platform IME candidate window at the caret.
  Rect? Function()? caretRectProvider;

  /// Injected by the widget layer: returns TextField-style geometry for the
  /// active editable surface. Prefer this over [caretRectProvider] because the
  /// platform expects the editable box transform plus local caret/composing
  /// rects, not a caret-sized editable box.
  EditorTextInputGeometry? Function()? textInputGeometryProvider;

  /// Injected by the widget layer: returns the [FlutterView.viewId] the editor
  /// is currently attached to, or `null` when no view is resolvable yet (e.g.
  /// before the editor is mounted). The platform text-input engine (notably
  /// Android) rejects `setClient` with `PlatformException(Bad Arguments, ...
  /// view ID is null)` when the [TextInputConfiguration.viewId] is missing, so
  /// this must be populated before [attach] runs.
  int? Function()? viewIdProvider;

  /// Injected by the widget layer: handles platform text-input selectors
  /// (macOS/iOS-style commands such as `moveLeft:` or `deleteBackward:`).
  /// The widget layer owns focus, read-only state, clipboard, and geometry, so
  /// it is the right place to translate these selectors into editor commands.
  void Function(String selectorName)? performSelectorHandler;

  bool get isAttached => _connection?.attached ?? false;

  /// Attaches to the platform text input, seeding the buffer from the
  /// controller's current selection.
  void attach() {
    _syncBuffer();
    if (_connection != null && _connection!.attached) {
      _connection!.show();
      _reportCaretGeometry();
      return;
    }
    final viewId = viewIdProvider?.call();
    _lastViewId = viewId;
    _connection = TextInput.attach(
      this,
      TextInputConfiguration(
        // A null viewId makes Android's engine reject setClient ("view ID is
        // null"). The widget layer resolves the current FlutterView id.
        viewId: viewId,
        enableDeltaModel: true,
        inputType: TextInputType.multiline,
        autocorrect: false,
        enableSuggestions: false,
        inputAction: TextInputAction.newline,
      ),
    );
    _connection!.show();
    // setEditingState must run only once the engine has a client bound (set in
    // attach). The connection is attached synchronously, so this is safe; the
    // guard avoids the "Set editing state has been invoked, but no client is
    // set" error that surfaces when attach races with a concurrent close.
    if (_connection!.attached) {
      _connection!.setEditingState(_buffer);
    }
    _reportCaretGeometry();
  }

  /// Detaches from the platform and clears any composition state.
  void detach() {
    _connection?.close();
    _connection = null;
    _controller.setCompositionState(null);
  }

  /// Pushes the current caret rect to the platform so the IME candidate
  /// window follows the caret. No-op when not attached or when no caret is
  /// available.
  void _reportCaretGeometry() {
    final connection = _connection;
    if (connection == null || !connection.attached) {
      return;
    }
    final geometry = textInputGeometryProvider?.call();
    if (geometry != null) {
      _lastReportedCaretRect = geometry.globalCaretRect;
      _lastReportedLocalCaretRect = geometry.caretRect;
      _lastReportedComposingRect = geometry.composingRect;
      _lastReportedEditableSize = geometry.editableSize;
      connection.setEditableSizeAndTransform(
        geometry.editableSize,
        geometry.transform,
      );
      connection.setCaretRect(geometry.caretRect);
      connection.setComposingRect(geometry.composingRect);
      return;
    }

    final rect = caretRectProvider?.call();
    if (rect == null) {
      return;
    }
    _lastReportedCaretRect = rect;
    final localCaretRect = Offset.zero & rect.size;
    _lastReportedLocalCaretRect = localCaretRect;
    _lastReportedComposingRect = localCaretRect;
    _lastReportedEditableSize = rect.size;
    // The transform's translation is the caret's global top-left; the size is
    // the caret rect's height (a thin caret). Platforms use this to anchor the
    // candidate window just below the caret line.
    connection.setEditableSizeAndTransform(
      rect.size,
      Matrix4.translationValues(rect.left, rect.top, 0),
    );
    connection.setCaretRect(localCaretRect);
    connection.setComposingRect(localCaretRect);
  }

  /// The caret rect most recently pushed to the platform IME, or `null` when
  /// none has been reported. Exposed for tests that verify the candidate
  /// window follows the caret.
  @visibleForTesting
  Rect? get lastReportedCaretRect => _lastReportedCaretRect;
  Rect? _lastReportedCaretRect;

  @visibleForTesting
  Rect? get lastReportedLocalCaretRect => _lastReportedLocalCaretRect;
  Rect? _lastReportedLocalCaretRect;

  @visibleForTesting
  Rect? get lastReportedComposingRect => _lastReportedComposingRect;
  Rect? _lastReportedComposingRect;

  @visibleForTesting
  Size? get lastReportedEditableSize => _lastReportedEditableSize;
  Size? _lastReportedEditableSize;

  /// The [FlutterView.viewId] most recently pushed into the text-input
  /// configuration, or `null` when no provider was wired up. Exposed for tests
  /// that verify the view id is forwarded (Android rejects a null viewId).
  @visibleForTesting
  int? get lastConfigurationViewId => _lastViewId;
  int? _lastViewId;

  /// Rebuilds the platform buffer from the current selection/block. Called on
  /// attach and whenever the caret moves to a different block or the document
  /// changes externally.
  void _syncBuffer() {
    final selection = _controller.selection;
    _buffer = _editingValueForSelection(
      selection,
      composing: _composingRangeForSelection(selection),
    );
  }

  TextEditingValue _editingValueForSelection(
    DocumentSelection? selection, {
    TextRange composing = TextRange.empty,
  }) {
    if (selection == null) {
      return TextEditingValue.empty;
    }

    if (!selection.isCollapsed && !_isSingleTextInputTarget(selection)) {
      return TextEditingValue.empty;
    }

    final position = selection.extent;
    final text = _plainTextForPosition(position);
    final safeComposing = _clampTextRange(composing, text.length);
    if (selection.isCollapsed) {
      final offset = position.offset.clamp(0, text.length).toInt();
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: offset),
        composing: safeComposing,
      );
    }

    final baseOffset = selection.base.offset.clamp(0, text.length).toInt();
    final extentOffset = selection.extent.offset.clamp(0, text.length).toInt();
    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
      ),
      composing: safeComposing,
    );
  }

  bool _isSingleTextInputTarget(DocumentSelection selection) {
    return selection.base.blockId == selection.extent.blockId &&
        selection.base.blockIndex == selection.extent.blockIndex &&
        selection.base.path == selection.extent.path;
  }

  TextRange _clampTextRange(TextRange range, int textLength) {
    if (range == TextRange.empty) {
      return TextRange.empty;
    }
    final start = range.start.clamp(0, textLength).toInt();
    final end = range.end.clamp(start, textLength).toInt();
    return TextRange(start: start, end: end);
  }

  TextRange _composingRangeForSelection(DocumentSelection? selection) {
    final composition = _controller.compositionState;
    if (selection == null ||
        composition == null ||
        composition.blockId != selection.extent.blockId ||
        composition.blockIndex != selection.extent.blockIndex ||
        composition.path != selection.extent.path) {
      return TextRange.empty;
    }
    return TextRange(
      start: composition.startOffset,
      end: composition.endOffset,
    );
  }

  String _plainTextForPosition(DocumentPosition position) {
    if (position.path.isTableCellText) {
      return tableCellTargetFromPosition(
            _controller.session,
            position,
          )?.plainText ??
          '';
    }
    final block = _blockAt(position.blockIndex);
    return block?.plainText ?? '';
  }

  BlockNode? _blockAt(int index) {
    if (index < 0 || index >= _controller.document.blocks.length) {
      return null;
    }
    return _controller.document.blocks[index];
  }

  // ---- DeltaTextInputClient ----

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    _controller.runWithInputUpdate(() {
      for (final delta in textEditingDeltas) {
        _applyDelta(delta);
      }
    });
  }

  void _applyDelta(TextEditingDelta delta) {
    void apply() {
      if (delta is TextEditingDeltaInsertion) {
        _handleInsertion(delta);
      } else if (delta is TextEditingDeltaDeletion) {
        _handleDeletion(delta);
      } else if (delta is TextEditingDeltaReplacement) {
        _handleReplacement(delta);
      } else if (delta is TextEditingDeltaNonTextUpdate) {
        _handleNonTextUpdate(delta);
      }
      _syncBuffer();
    }

    if (delta.composing == TextRange.empty) {
      apply();
    } else {
      _controller.runWithComposingTextInput(apply);
    }
  }

  void _handleInsertion(TextEditingDeltaInsertion delta) {
    final text = delta.textInserted;
    if (text.isEmpty) {
      return;
    }
    final activeSelection = _controller.selection;
    if (activeSelection != null && !activeSelection.isCollapsed) {
      final shift =
          activeSelection.start.offset - _safeOffset(delta.insertionOffset);
      _controller.insertText(text);
      _syncSelection(_shiftSelection(delta.selection, shift));
      _syncComposition(_shiftRange(delta.composing, shift));
      return;
    }
    final offset = _effectiveInsertionOffset(delta.insertionOffset);
    _placeCaretAt(offset);
    _controller.insertText(text);
    final shift = offset - delta.insertionOffset;
    _syncSelection(_shiftSelection(delta.selection, shift));
    _syncComposition(_shiftRange(delta.composing, shift));
  }

  void _handleDeletion(TextEditingDeltaDeletion delta) {
    final activeSelection = _controller.selection;
    if (activeSelection != null && !activeSelection.isCollapsed) {
      final platformAnchor = _rangeStartOr(
        delta.deletedRange,
        fallback: _selectionStartOrZero(delta.selection),
      );
      final shift = activeSelection.start.offset - platformAnchor;
      _controller.deleteSelection(activeSelection);
      _syncSelection(_shiftSelection(delta.selection, shift));
      _syncComposition(_shiftRange(delta.composing, shift));
      return;
    }
    final deleted = delta.deletedRange;
    final shift = _rangeShiftForActiveComposition(deleted);
    final actualDeleted = _shiftRange(deleted, shift);
    if (actualDeleted.start < actualDeleted.end) {
      _deleteRange(actualDeleted.start, actualDeleted.end);
    }
    _syncSelection(_shiftSelection(delta.selection, shift));
    _syncComposition(_shiftRange(delta.composing, shift));
  }

  void _handleReplacement(TextEditingDeltaReplacement delta) {
    final activeSelection = _controller.selection;
    if (activeSelection != null && !activeSelection.isCollapsed) {
      final platformAnchor = _rangeStartOr(delta.replacedRange, fallback: 0);
      final shift = activeSelection.start.offset - platformAnchor;
      if (delta.replacementText.isEmpty) {
        _controller.deleteSelection(activeSelection);
      } else {
        _controller.insertText(delta.replacementText);
      }
      _syncSelection(_shiftSelection(delta.selection, shift));
      _syncComposition(_shiftRange(delta.composing, shift));
      return;
    }
    final replaced = delta.replacedRange;
    final shift = _rangeShiftForActiveComposition(replaced);
    final actualReplaced = _shiftRange(replaced, shift);
    if (actualReplaced.start < actualReplaced.end) {
      _deleteRange(actualReplaced.start, actualReplaced.end);
    }
    _placeCaretAt(actualReplaced.start);
    if (delta.replacementText.isNotEmpty) {
      _controller.insertText(delta.replacementText);
    }
    _syncSelection(_shiftSelection(delta.selection, shift));
    _syncComposition(_shiftRange(delta.composing, shift));
  }

  void _handleNonTextUpdate(TextEditingDeltaNonTextUpdate delta) {
    _syncSelection(delta.selection);
    _syncComposition(delta.composing);
  }

  void _deleteRange(int start, int end) {
    if (start >= end) {
      return;
    }
    final selection = _controller.selection;
    if (selection == null) {
      return;
    }
    final position = selection.extent;
    // Build a selection spanning [start, end) in the current block and delete.
    _controller.deleteSelection(
      DocumentSelection(
        base: position.copyWith(offset: start),
        extent: position.copyWith(offset: end),
      ),
    );
  }

  int _effectiveInsertionOffset(int platformOffset) {
    final selection = _controller.selection;
    if (selection == null || !selection.isCollapsed) {
      return platformOffset;
    }
    return selection.extent.offset;
  }

  int _safeOffset(int offset) => offset < 0 ? 0 : offset;

  int _rangeStartOr(TextRange range, {required int fallback}) {
    if (range == TextRange.empty || range.start < 0) {
      return fallback;
    }
    return range.start;
  }

  int _selectionStartOrZero(TextSelection selection) {
    final base = selection.baseOffset;
    final extent = selection.extentOffset;
    if (base < 0 && extent < 0) {
      return 0;
    }
    if (base < 0) {
      return extent;
    }
    if (extent < 0) {
      return base;
    }
    return base < extent ? base : extent;
  }

  int _rangeShiftForActiveComposition(TextRange platformRange) {
    final composition = _controller.compositionState;
    if (composition == null ||
        platformRange == TextRange.empty ||
        platformRange.start >= platformRange.end) {
      return 0;
    }
    final platformLength = platformRange.end - platformRange.start;
    final compositionLength = composition.endOffset - composition.startOffset;
    if (platformLength != compositionLength) {
      return 0;
    }
    return composition.startOffset - platformRange.start;
  }

  TextSelection _shiftSelection(TextSelection selection, int shift) {
    if (shift == 0 || selection.baseOffset < 0 || selection.extentOffset < 0) {
      return selection;
    }
    return TextSelection(
      baseOffset: selection.baseOffset + shift,
      extentOffset: selection.extentOffset + shift,
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  TextRange _shiftRange(TextRange range, int shift) {
    if (shift == 0 || range == TextRange.empty) {
      return range;
    }
    return TextRange(start: range.start + shift, end: range.end + shift);
  }

  void _placeCaretAt(int offset) {
    final selection = _controller.selection;
    if (selection == null) {
      return;
    }
    final position = selection.extent.copyWith(offset: offset);
    _controller.setSelection(
      DocumentSelection(base: position, extent: position),
    );
  }

  void _syncSelection(TextSelection platformSelection) {
    final selection = _controller.selection;
    if (selection == null ||
        platformSelection.baseOffset < 0 ||
        platformSelection.extentOffset < 0) {
      return;
    }
    final position = selection.extent;
    final textLength = _plainTextForPosition(position).length;
    final baseOffset =
        platformSelection.baseOffset.clamp(0, textLength).toInt();
    final extentOffset =
        platformSelection.extentOffset.clamp(0, textLength).toInt();
    final base = position.copyWith(offset: baseOffset);
    final extent = position.copyWith(offset: extentOffset);
    _controller.setSelection(DocumentSelection(base: base, extent: extent));
  }

  void _syncComposition(TextRange composing) {
    final selection = _controller.selection;
    // Only TextRange.empty (start == -1) means "no composition". A collapsed
    // range (start == end == n) is a valid composition region that simply has
    // no characters yet — some IMEs emit it at the start/end of a session.
    // Clearing it would drop the composition semantics mid-session; we keep it
    // (it renders as a zero-width range, i.e. no underline, which is correct).
    if (selection == null || composing == TextRange.empty) {
      _controller.setCompositionState(null);
      return;
    }
    final position = selection.extent;
    final textLength = _plainTextForPosition(position).length;
    final safeComposing = _clampTextRange(composing, textLength);
    _controller.setCompositionState(
      CompositionState(
        blockId: position.blockId,
        blockIndex: position.blockIndex,
        path: position.path,
        startOffset: safeComposing.start,
        endOffset: safeComposing.end,
      ),
    );
  }

  // ---- TextInputClient ----

  @override
  void updateEditingValue(TextEditingValue value) {
    // Non-delta fallback. Some desktop IMEs still exercise this path during
    // composition, so handle it like EditableText: diff the previous editing
    // value against the new one and apply only the changed span.
    void apply() {
      final activeSelection = _controller.selection;
      if (activeSelection != null &&
          !activeSelection.isCollapsed &&
          !_isSingleTextInputTarget(activeSelection)) {
        _replaceCrossTargetSelectionFromEditingValue(activeSelection, value);
        return;
      }
      if (_applyDetachedCompositionEditingValue(value)) {
        return;
      }
      final old = _buffer;
      if (old.text != value.text) {
        final diff = _TextDiff.between(old.text, value.text);
        if (diff.oldStart < diff.oldEnd) {
          _deleteRange(diff.oldStart, diff.oldEnd);
        }
        _placeCaretAt(diff.oldStart);
        if (diff.replacement.isNotEmpty) {
          _controller.insertText(diff.replacement);
        }
      }
      _syncSelection(value.selection);
      _syncComposition(value.composing);
      _syncBuffer();
    }

    _controller.runWithInputUpdate(() {
      if (value.composing == TextRange.empty) {
        apply();
      } else {
        _controller.runWithComposingTextInput(apply);
      }
    });
  }

  void _replaceCrossTargetSelectionFromEditingValue(
    DocumentSelection selection,
    TextEditingValue value,
  ) {
    final shift = selection.start.offset;
    if (value.text.isEmpty) {
      _controller.deleteSelection(selection);
    } else {
      _controller.insertText(value.text);
    }
    _syncSelection(_shiftSelection(value.selection, shift));
    _syncComposition(_shiftRange(value.composing, shift));
    _syncBuffer();
  }

  bool _applyDetachedCompositionEditingValue(TextEditingValue value) {
    final composition = _controller.compositionState;
    final selection = _controller.selection;
    if (composition == null ||
        selection == null ||
        _buffer.text == value.text) {
      return false;
    }
    final position = selection.extent;
    if (composition.blockId != position.blockId ||
        composition.blockIndex != position.blockIndex ||
        composition.path != position.path) {
      return false;
    }

    final currentText = _plainTextForPosition(position);
    final start = composition.startOffset.clamp(0, currentText.length).toInt();
    final end = composition.endOffset.clamp(start, currentText.length).toInt();
    if (_looksLikeFullBlockEditingValue(value.text, currentText, start, end)) {
      return false;
    }

    // Some IMEs keep sending only their local composing buffer after we expose
    // an empty platform value for a cross-target selection. Map that local
    // buffer back onto the document's active composing range.
    if (start < end) {
      _deleteRange(start, end);
    }
    _placeCaretAt(start);
    if (value.text.isNotEmpty) {
      _controller.insertText(value.text);
    }
    final shift = start - _rangeStartOr(value.composing, fallback: 0);
    _syncSelection(_shiftSelection(value.selection, shift));
    _syncComposition(_shiftRange(value.composing, shift));
    _syncBuffer();
    return true;
  }

  bool _looksLikeFullBlockEditingValue(
    String nextText,
    String currentText,
    int composingStart,
    int composingEnd,
  ) {
    final prefix = currentText.substring(0, composingStart);
    final suffix = currentText.substring(composingEnd);
    return nextText.startsWith(prefix) && nextText.endsWith(suffix);
  }

  @override
  void performAction(TextInputAction action) {
    // Multiline editor: block creation is handled by the Enter key-event path.
  }

  @override
  void connectionClosed() {
    _connection = null;
    _controller.setCompositionState(null);
  }

  @override
  TextEditingValue? get currentTextEditingValue => _buffer;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void performSelector(String selectorName) {
    performSelectorHandler?.call(selectorName);
  }

  @override
  void showToolbar() {}

  // ---- Test hooks ----

  /// Exposed for tests: the current buffer being negotiated with the platform.
  @visibleForTesting
  TextEditingValue get currentBuffer => _buffer;

  @visibleForTesting
  void injectDelta(TextEditingDelta delta) => _applyDelta(delta);

  /// Rebuilds the platform buffer from the controller's current selection.
  /// Called by the widget layer when a gesture or command repositions the
  /// caret, so the platform IME follows the new location.
  void syncBuffer() {
    _syncBuffer();
    // Do not echo editing state back to the platform while an IME composition
    // is active. TextField lets the IME own its composing buffer; pushing here
    // can reset the platform-side range and make pinyin text stick in the
    // document instead of being replaced by the committed Chinese character.
    if (_controller.compositionState == null) {
      _pushEditingState();
    }
    _reportCaretGeometry();
  }

  @visibleForTesting
  void syncBufferForTest() => _syncBuffer();

  void _pushEditingState() {
    final connection = _connection;
    if (connection == null || !connection.attached) {
      return;
    }
    connection.setEditingState(_buffer);
  }
}

class _TextDiff {
  const _TextDiff({
    required this.oldStart,
    required this.oldEnd,
    required this.replacement,
  });

  final int oldStart;
  final int oldEnd;
  final String replacement;

  static _TextDiff between(String oldText, String newText) {
    var start = 0;
    final shortest =
        oldText.length < newText.length ? oldText.length : newText.length;
    while (start < shortest &&
        oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
      start += 1;
    }

    var oldEnd = oldText.length;
    var newEnd = newText.length;
    while (oldEnd > start &&
        newEnd > start &&
        oldText.codeUnitAt(oldEnd - 1) == newText.codeUnitAt(newEnd - 1)) {
      oldEnd -= 1;
      newEnd -= 1;
    }

    return _TextDiff(
      oldStart: start,
      oldEnd: oldEnd,
      replacement: newText.substring(start, newEnd),
    );
  }
}

class EditorTextInputGeometry {
  const EditorTextInputGeometry({
    required this.editableSize,
    required this.transform,
    required this.caretRect,
    required this.composingRect,
    required this.globalCaretRect,
  });

  final Size editableSize;
  final Matrix4 transform;
  final Rect caretRect;
  final Rect composingRect;
  final Rect globalCaretRect;
}

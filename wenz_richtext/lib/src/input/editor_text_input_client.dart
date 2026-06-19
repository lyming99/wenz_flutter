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

  bool get isAttached => _connection?.attached ?? false;

  /// Attaches to the platform text input, seeding the buffer from the
  /// controller's current selection.
  void attach() {
    _syncBuffer();
    if (_connection != null && _connection!.attached) {
      _connection!.show();
      return;
    }
    _connection = TextInput.attach(
      this,
      const TextInputConfiguration(
        enableDeltaModel: true,
        inputType: TextInputType.multiline,
        autocorrect: false,
        enableSuggestions: false,
        inputAction: TextInputAction.newline,
      ),
    );
    _connection!.show();
    _connection!.setEditingState(_buffer);
  }

  /// Detaches from the platform and clears any composition state.
  void detach() {
    _connection?.close();
    _connection = null;
    _controller.setCompositionState(null);
  }

  /// Rebuilds the platform buffer from the current selection/block. Called on
  /// attach and whenever the caret moves to a different block or the document
  /// changes externally.
  void _syncBuffer() {
    final selection = _controller.selection;
    if (selection == null || !selection.isCollapsed) {
      _buffer = TextEditingValue.empty;
      return;
    }
    final position = selection.extent;
    final text = _plainTextForPosition(position);
    final offset = position.offset.clamp(0, text.length).toInt();
    _buffer = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
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
    for (final delta in textEditingDeltas) {
      _applyDelta(delta);
    }
  }

  void _applyDelta(TextEditingDelta delta) {
    if (delta is TextEditingDeltaInsertion) {
      _handleInsertion(delta);
    } else if (delta is TextEditingDeltaDeletion) {
      _handleDeletion(delta);
    } else if (delta is TextEditingDeltaReplacement) {
      _handleReplacement(delta);
    } else if (delta is TextEditingDeltaNonTextUpdate) {
      _handleNonTextUpdate(delta);
    }
    // Keep our buffer in lockstep with the platform's view.
    _buffer = delta.apply(_buffer);
  }

  void _handleInsertion(TextEditingDeltaInsertion delta) {
    final offset = delta.insertionOffset;
    final text = delta.textInserted;
    if (text.isEmpty) {
      return;
    }
    _placeCaretAt(offset);
    _controller.insertText(text);
    _syncComposition(delta.composing);
  }

  void _handleDeletion(TextEditingDeltaDeletion delta) {
    final deleted = delta.deletedRange;
    if (deleted.start < deleted.end) {
      _deleteRange(deleted.start, deleted.end);
    }
    _syncComposition(delta.composing);
  }

  void _handleReplacement(TextEditingDeltaReplacement delta) {
    final replaced = delta.replacedRange;
    if (replaced.start < replaced.end) {
      _deleteRange(replaced.start, replaced.end);
    }
    _placeCaretAt(replaced.start);
    if (delta.replacementText.isNotEmpty) {
      _controller.insertText(delta.replacementText);
    }
    _syncComposition(delta.composing);
  }

  void _handleNonTextUpdate(TextEditingDeltaNonTextUpdate delta) {
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

  void _syncComposition(TextRange composing) {
    final selection = _controller.selection;
    if (selection == null ||
        composing == TextRange.empty ||
        composing.isCollapsed) {
      _controller.setCompositionState(null);
      return;
    }
    final position = selection.extent;
    _controller.setCompositionState(
      CompositionState(
        blockId: position.blockId,
        blockIndex: position.blockIndex,
        path: position.path,
        startOffset: composing.start,
        endOffset: composing.end,
      ),
    );
  }

  // ---- TextInputClient ----

  @override
  void updateEditingValue(TextEditingValue value) {
    // Non-delta fallback. Rarely hit when delta model is enabled, but kept for
    // completeness: treat the whole buffer as replaced.
    final old = _buffer;
    if (old.text != value.text) {
      if (old.text.isNotEmpty) {
        _deleteRange(0, old.text.length);
      }
      _placeCaretAt(0);
      if (value.text.isNotEmpty) {
        _controller.insertText(value.text);
      }
    }
    _syncComposition(value.composing);
    _buffer = value;
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
  void performSelector(String selectorName) {}

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
  void syncBuffer() => _syncBuffer();

  @visibleForTesting
  void syncBufferForTest() => _syncBuffer();
}

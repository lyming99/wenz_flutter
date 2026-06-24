import 'package:flutter/services.dart';

enum EditorShortcutDisposition {
  handled,
  ignored,
  passThrough,
}

enum EditorShortcutIntent {
  selectAll,
  undo,
  redo,
  copy,
  cut,
  paste,
  find,
  replace,
  moveTableCellBackward,
  moveTableCellForward,
  moveCaretBackward,
  moveCaretForward,
  moveCaretUp,
  moveCaretDown,
  moveCaretToBlockStart,
  moveCaretToBlockEnd,
  moveCaretByWordBackward,
  moveCaretByWordForward,
  moveCaretToDocumentStart,
  moveCaretToDocumentEnd,
  pageUp,
  pageDown,
  deleteBackward,
  deleteForward,
  enter,
  insertCharacter,
}

class EditorShortcutResolution {
  const EditorShortcutResolution._({
    required this.disposition,
    this.intent,
    this.expandSelection = false,
    this.character,
  });

  const EditorShortcutResolution.handled(
    EditorShortcutIntent intent, {
    bool expandSelection = false,
    String? character,
  }) : this._(
          disposition: EditorShortcutDisposition.handled,
          intent: intent,
          expandSelection: expandSelection,
          character: character,
        );

  const EditorShortcutResolution.ignored()
      : this._(disposition: EditorShortcutDisposition.ignored);

  const EditorShortcutResolution.passThrough()
      : this._(disposition: EditorShortcutDisposition.passThrough);

  final EditorShortcutDisposition disposition;
  final EditorShortcutIntent? intent;
  final bool expandSelection;
  final String? character;
}

/// Resolves keyboard events into editor shortcut intents.
///
/// This class is pure keymap logic: it does not mutate the controller, touch the
/// clipboard, or know about widget state beyond the flags passed into [resolve].
class EditorShortcutManager {
  const EditorShortcutManager();

  EditorShortcutResolution resolve(
    KeyEvent event, {
    required bool shiftPressed,
    required bool primaryPressed,
    required bool readOnly,
    required bool imeEnabled,
    required bool inputClientAttached,
    bool findEnabled = false,
    bool replaceEnabled = false,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return const EditorShortcutResolution.ignored();
    }

    if (primaryPressed) {
      return _resolvePrimaryShortcut(
        event.logicalKey,
        shiftPressed: shiftPressed,
        readOnly: readOnly,
        findEnabled: findEnabled,
        replaceEnabled: replaceEnabled,
      );
    }

    if (readOnly) {
      return const EditorShortcutResolution.ignored();
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab) {
      return EditorShortcutResolution.handled(
        shiftPressed
            ? EditorShortcutIntent.moveTableCellBackward
            : EditorShortcutIntent.moveTableCellForward,
      );
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretBackward,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretForward,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretUp,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretDown,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.home) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretToBlockStart,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.end) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretToBlockEnd,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.pageUp) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.pageUp,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.pageDown) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.pageDown,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.backspace) {
      return const EditorShortcutResolution.handled(
        EditorShortcutIntent.deleteBackward,
      );
    }
    if (key == LogicalKeyboardKey.delete) {
      return const EditorShortcutResolution.handled(
        EditorShortcutIntent.deleteForward,
      );
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return const EditorShortcutResolution.handled(
        EditorShortcutIntent.enter,
      );
    }

    final character = event.character;
    if (character == null ||
        character.isEmpty ||
        _isControlCharacter(character)) {
      return const EditorShortcutResolution.ignored();
    }
    if (imeEnabled || inputClientAttached) {
      return const EditorShortcutResolution.ignored();
    }
    return EditorShortcutResolution.handled(
      EditorShortcutIntent.insertCharacter,
      character: character,
    );
  }

  EditorShortcutResolution _resolvePrimaryShortcut(
    LogicalKeyboardKey key, {
    required bool shiftPressed,
    required bool readOnly,
    required bool findEnabled,
    required bool replaceEnabled,
  }) {
    if (key == LogicalKeyboardKey.keyA) {
      return const EditorShortcutResolution.handled(
        EditorShortcutIntent.selectAll,
      );
    }
    if (key == LogicalKeyboardKey.keyZ) {
      if (readOnly) {
        return const EditorShortcutResolution.ignored();
      }
      return EditorShortcutResolution.handled(
        shiftPressed ? EditorShortcutIntent.redo : EditorShortcutIntent.undo,
      );
    }
    if (key == LogicalKeyboardKey.keyY) {
      if (readOnly) {
        return const EditorShortcutResolution.ignored();
      }
      return const EditorShortcutResolution.handled(
        EditorShortcutIntent.redo,
      );
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretByWordBackward,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretByWordForward,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.home) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretToDocumentStart,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.end) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretToDocumentEnd,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.keyC) {
      return const EditorShortcutResolution.handled(
        EditorShortcutIntent.copy,
      );
    }
    if (key == LogicalKeyboardKey.keyX) {
      if (readOnly) {
        return const EditorShortcutResolution.ignored();
      }
      return const EditorShortcutResolution.handled(EditorShortcutIntent.cut);
    }
    if (key == LogicalKeyboardKey.keyV) {
      if (readOnly) {
        return const EditorShortcutResolution.ignored();
      }
      return const EditorShortcutResolution.handled(EditorShortcutIntent.paste);
    }
    if (key == LogicalKeyboardKey.keyF && findEnabled) {
      return const EditorShortcutResolution.handled(EditorShortcutIntent.find);
    }
    if (key == LogicalKeyboardKey.keyH && replaceEnabled && !readOnly) {
      return const EditorShortcutResolution.handled(
        EditorShortcutIntent.replace,
      );
    }
    return const EditorShortcutResolution.passThrough();
  }
}

bool _isControlCharacter(String character) {
  final codeUnit = character.codeUnitAt(0);
  return codeUnit < 0x20 || codeUnit == 0x7F;
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  const manager = EditorShortcutManager();

  EditorShortcutResolution resolve(
    KeyEvent event, {
    bool shift = false,
    bool primary = false,
    bool readOnly = false,
    bool imeEnabled = false,
    bool inputClientAttached = false,
    bool findEnabled = false,
    bool replaceEnabled = false,
  }) {
    return manager.resolve(
      event,
      shiftPressed: shift,
      primaryPressed: primary,
      readOnly: readOnly,
      imeEnabled: imeEnabled,
      inputClientAttached: inputClientAttached,
      findEnabled: findEnabled,
      replaceEnabled: replaceEnabled,
    );
  }

  test('ignores key-up events', () {
    final result = resolve(_up(LogicalKeyboardKey.keyA));

    expect(result.disposition, EditorShortcutDisposition.ignored);
    expect(result.intent, isNull);
  });

  test('allows select-all in read-only mode', () {
    final result = resolve(
      _down(LogicalKeyboardKey.keyA),
      primary: true,
      readOnly: true,
    );

    expect(result.disposition, EditorShortcutDisposition.handled);
    expect(result.intent, EditorShortcutIntent.selectAll);
  });

  test('passes through unknown primary shortcuts', () {
    final result = resolve(_down(LogicalKeyboardKey.keyS), primary: true);

    expect(result.disposition, EditorShortcutDisposition.passThrough);
    expect(result.intent, isNull);
  });

  test('blocks undo and paste in read-only mode', () {
    final undo = resolve(
      _down(LogicalKeyboardKey.keyZ),
      primary: true,
      readOnly: true,
    );
    final paste = resolve(
      _down(LogicalKeyboardKey.keyV),
      primary: true,
      readOnly: true,
    );

    expect(undo.disposition, EditorShortcutDisposition.ignored);
    expect(paste.disposition, EditorShortcutDisposition.ignored);
  });

  test('maps primary shift z to redo', () {
    final result = resolve(
      _down(LogicalKeyboardKey.keyZ),
      primary: true,
      shift: true,
    );

    expect(result.intent, EditorShortcutIntent.redo);
  });

  test('maps find and replace only when enabled', () {
    final disabled = resolve(_down(LogicalKeyboardKey.keyF), primary: true);
    final findEnabled = resolve(
      _down(LogicalKeyboardKey.keyF),
      primary: true,
      findEnabled: true,
    );
    final replaceEnabled = resolve(
      _down(LogicalKeyboardKey.keyH),
      primary: true,
      replaceEnabled: true,
    );
    final readOnlyReplace = resolve(
      _down(LogicalKeyboardKey.keyH),
      primary: true,
      readOnly: true,
      replaceEnabled: true,
    );

    expect(disabled.disposition, EditorShortcutDisposition.passThrough);
    expect(findEnabled.intent, EditorShortcutIntent.find);
    expect(replaceEnabled.intent, EditorShortcutIntent.replace);
    expect(readOnlyReplace.disposition, EditorShortcutDisposition.passThrough);
  });

  test('maps primary arrow with shift to word movement with expansion', () {
    final result = resolve(
      _down(LogicalKeyboardKey.arrowLeft),
      primary: true,
      shift: true,
    );

    expect(result.intent, EditorShortcutIntent.moveCaretByWordBackward);
    expect(result.expandSelection, isTrue);
  });

  test('maps shift tab to backward table-cell movement', () {
    final result = resolve(_down(LogicalKeyboardKey.tab), shift: true);

    expect(result.intent, EditorShortcutIntent.moveTableCellBackward);
  });

  test('maps key repeat navigation events', () {
    final result = resolve(_repeat(LogicalKeyboardKey.arrowRight));

    expect(result.disposition, EditorShortcutDisposition.handled);
    expect(result.intent, EditorShortcutIntent.moveCaretForward);
  });

  test('maps plain character only when IME is not active', () {
    final character = resolve(_down(LogicalKeyboardKey.keyA, character: 'a'));
    final ime = resolve(
      _down(LogicalKeyboardKey.keyA, character: 'a'),
      imeEnabled: true,
    );
    final attached = resolve(
      _down(LogicalKeyboardKey.keyA, character: 'a'),
      inputClientAttached: true,
    );

    expect(character.intent, EditorShortcutIntent.insertCharacter);
    expect(character.character, 'a');
    expect(ime.disposition, EditorShortcutDisposition.ignored);
    expect(attached.disposition, EditorShortcutDisposition.ignored);
  });

  test('ignores control characters', () {
    final result = resolve(
      _down(LogicalKeyboardKey.enter, character: '\n'),
    );

    expect(result.intent, EditorShortcutIntent.enter);

    final control = resolve(
      _down(LogicalKeyboardKey.keyA, character: '\u0001'),
    );
    expect(control.disposition, EditorShortcutDisposition.ignored);
  });
}

KeyDownEvent _down(LogicalKeyboardKey key, {String? character}) {
  return KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: key,
    timeStamp: Duration.zero,
    character: character,
  );
}

KeyRepeatEvent _repeat(LogicalKeyboardKey key, {String? character}) {
  return KeyRepeatEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: key,
    timeStamp: Duration.zero,
    character: character,
  );
}

KeyUpEvent _up(LogicalKeyboardKey key) {
  return KeyUpEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: key,
    timeStamp: Duration.zero,
  );
}

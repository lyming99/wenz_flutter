import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

/// Types [text] into the workbench by committing it as the IME would.
///
/// The editor runs with `enableIme: true` (the production desktop path); in
/// that mode a plain `sendKeyEvent(character)` is swallowed by the
/// `TextInput` connection (see `wenz_rich_text_editor.dart` `_handleKeyEvent`:
/// it returns `ignored` when `_inputClient.isAttached`). So character entry is
/// driven the same way a real IME commits a candidate — through the
/// controller's text insertion path. Structural keys (Backspace, arrows,
/// Enter, Home/End, Ctrl+ shortcuts) below still use real key events.
Future<void> typeText(
  WidgetTester tester,
  WenzRichTextController controller,
  String text,
) async {
  controller.insertText(text);
  await tester.pump();
}

/// Sends a single key event (no character semantics). Use for structural keys
/// like arrows, Backspace, Enter, Home, End.
Future<void> sendKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// Sends a Ctrl(+Shift)+key shortcut as a real desktop key chord.
Future<void> sendCtrlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyEvent(key);
  if (shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

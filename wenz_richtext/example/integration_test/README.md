# Integration tests

Desktop-flavoured UI automation for the editor's core editing flows. Each file
drives a realistic workbench (MaterialApp + Scaffold + toolbar + scrollable
editor at a 1280×800 viewport) through real key events, pointer events, and
toolbar button taps, then asserts on both the document model and the rendered
spans.

## Running

Run each file individually against the headless `flutter-tester` device:

```bash
cd example
flutter test integration_test/editor_keyboard_test.dart -d flutter-tester
flutter test integration_test/editor_mouse_test.dart    -d flutter-tester
flutter test integration_test/editor_richtext_test.dart -d flutter-tester
flutter test integration_test/editor_table_test.dart    -d flutter-tester
```

Or, to exercise the real desktop shell, target the platform device instead:

```bash
cd example
flutter test integration_test/editor_keyboard_test.dart -d windows
```

> **Why one file at a time?** `flutter test integration_test` (directory mode)
> re-launches the host app per file and is unreliable for multi-file
> integration suites on desktop ("Failed to launch … log reader failed
> unexpectedly"). This is a Flutter tooling limitation, not a test defect —
> every file passes when invoked on its own.

## Coverage

| File | Scenario |
| --- | --- |
| `editor_keyboard_test.dart` | Typing, Backspace/Delete, Enter splitting, arrow keys, Home/End, Ctrl+A select-all |
| `editor_mouse_test.dart` | Tap to place caret, drag to select, double-tap word, triple-tap block, cross-block drag |
| `editor_richtext_test.dart` | Bold/Italic toolbar, heading block type, Ctrl+Z undo, Ctrl+Shift+Z redo, copy/paste |
| `editor_table_test.dart` | Cell typing, backspace, Tab navigation, Tab new row, arrow up/down, Enter newline, select-all covering table cells |
| `editor_ime_test.dart` | Chinese (CJK) text commit via the IME path, mixed CJK/ASCII, Chinese selection + delete |
| `editor_pointer_precision_test.dart` | Click resolves to the tapped offset, start/end/middle, successive clicks, multi-line wrap, pointer-up drift |
| `editor_selection_refresh_test.dart` | Repeated drag-select within a block updates the highlight, collapse clears highlight + shows caret, cross-block highlight |

The IME caret-position reporting (so the platform pinyin candidate window follows the caret) is unit-tested in the package at `test/input/editor_text_input_client_test.dart` (`attach reports the caret rect …`).

## Helpers

- `helpers/test_app.dart` — `TestWorkbench` + `pumpWorkbench`, an in-memory
  `Clipboard` mock, and a default-caret placement so headless entry has
  somewhere to land.
- `helpers/keyboard_helpers.dart` — `typeText` (commits text as the IME would),
  `sendKey`, `sendCtrlShortcut`.
- `helpers/pointer_helpers.dart` — `tapAtTextOffset`, `dragInsideText`,
  `dragBetweenText`, `multiTapText`.
- `helpers/expect_helpers.dart` — `isCaretVisible`, `isSelectionHighlightVisible`,
  `richTextStyle`, `styleOfRun`.

## Notes on the grey-box hook

The controller is held by `TestWorkbench`, so tests read `document` /
`selection` / `canUndo` directly. `lib/test_host.dart` additionally exposes the
production `EditorWorkbench`'s controller via an `InheritedWidget`
(`WenzEditorTestHost.of`) for any future test that drives the real example app.

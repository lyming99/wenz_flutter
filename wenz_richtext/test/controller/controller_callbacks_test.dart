import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

/// B5 — verifies the controller-level change callbacks fire at the right time
/// and in the right order. See `docs/acceptance_report.md` task B5.
void main() {
  group('controller callbacks', () {
    test('execute with content change fires onChanged + onCommandExecuted', () {
      final controller = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      var docChanges = 0;
      var selectionChanges = 0;
      var commandRuns = 0;
      RichTextDocument? docSeen;
      EditorCommand? cmdSeen;
      ChangeSet? changeSeen;

      controller.onChanged = (doc) {
        docChanges++;
        docSeen = doc;
      };
      controller.onSelectionChanged = (_) => selectionChanges++;
      controller.onCommandExecuted = (cmd, change) {
        commandRuns++;
        cmdSeen = cmd;
        changeSeen = change;
      };

      controller.insertText('A');

      expect(docChanges, 1);
      expect(selectionChanges, 1, reason: 'caret advances after insert');
      expect(commandRuns, 1);
      expect(docSeen!.plainText, 'AHello');
      expect(controller.document.plainText, 'AHello');
      expect(cmdSeen, isA<InsertTextCommand>());
      expect(changeSeen!.after.plainText, 'AHello');

      controller.dispose();
    });

    test('caret-only command fires onSelectionChanged but not onChanged', () {
      final controller = WenzRichTextController(
        document: _doc(),
        // Caret at offset 0 → moving forward changes selection.
        selection: collapsedTextSelection('p1', 0, 0),
      );
      var docChanges = 0;
      var selectionChanges = 0;
      var commandRuns = 0;

      controller.onChanged = (_) => docChanges++;
      controller.onSelectionChanged = (_) => selectionChanges++;
      controller.onCommandExecuted = (_, __) => commandRuns++;

      controller.moveCaretForward();

      expect(docChanges, 0, reason: 'no document content change');
      expect(selectionChanges, 1);
      expect(commandRuns, 1, reason: 'a command still ran (selection changed)');

      controller.dispose();
    });

    test('noop command fires none of the callbacks', () {
      final controller = WenzRichTextController(
        document: _doc(),
        // Caret at the very start: moving backward is a no-op.
        selection: collapsedTextSelection('p1', 0, 0),
      );
      var docChanges = 0;
      var selectionChanges = 0;
      var commandRuns = 0;

      controller.onChanged = (_) => docChanges++;
      controller.onSelectionChanged = (_) => selectionChanges++;
      controller.onCommandExecuted = (_, __) => commandRuns++;

      controller.moveCaretBackward();

      expect(docChanges, 0);
      expect(selectionChanges, 0);
      expect(commandRuns, 0);

      controller.dispose();
    });

    test('setSelection fires onSelectionChanged only when value differs', () {
      final controller = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      var docChanges = 0;
      var selectionChanges = 0;
      DocumentSelection? lastSelection;

      controller.onChanged = (_) => docChanges++;
      controller.onSelectionChanged = (sel) {
        selectionChanges++;
        lastSelection = sel;
      };

      // Same value: no callback.
      controller.setSelection(collapsedTextSelection('p1', 0, 0));
      expect(selectionChanges, 0);

      // Different value: fires.
      controller.setSelection(collapsedTextSelection('p1', 0, 2));
      expect(selectionChanges, 1);
      expect(lastSelection!.extent.offset, 2);
      expect(docChanges, 0);

      controller.dispose();
    });

    test('replaceDocument fires onChanged', () {
      final controller = WenzRichTextController(document: _doc());
      var docChanges = 0;
      var selectionChanges = 0;
      RichTextDocument? seen;

      controller.onChanged = (doc) {
        docChanges++;
        seen = doc;
      };
      controller.onSelectionChanged = (_) => selectionChanges++;

      controller.replaceDocument(
        const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'q1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Fresh')],
            ),
          ],
        ),
      );

      expect(docChanges, 1);
      expect(seen!.plainText, 'Fresh');
      expect(selectionChanges, 0, reason: 'replaceDocument leaves selection to caller');

      controller.dispose();
    });

    test('undo/redo fire onChanged but not onCommandExecuted', () {
      final controller = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      var docChanges = 0;
      var commandRuns = 0;

      controller.onChanged = (_) => docChanges++;
      controller.onCommandExecuted = (_, __) => commandRuns++;

      controller.insertText('A');
      // Reset counters after the insert so we isolate undo's behaviour.
      docChanges = 0;
      commandRuns = 0;

      controller.undo();
      expect(docChanges, 1);
      expect(commandRuns, 0, reason: 'undo has no originating command object');

      controller.redo();
      expect(docChanges, 2);
      expect(commandRuns, 0);

      controller.dispose();
    });

    test('callbacks fire before notifyListeners', () {
      final controller = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      // The listener flips this flag; onChanged asserts it has NOT yet run by
      // checking the flag is still false when onChanged fires.
      var listenerRanBeforeOnChanged = false;
      var onChangedSawListenerState = true;

      controller.onChanged = (_) {
        // If the listener had already run this frame, listenerRan would be
        // true. We expect false here (callback precedes notifyListeners).
        onChangedSawListenerState = listenerRanBeforeOnChanged;
      };
      controller.onCommandExecuted = (_, __) {};
      controller.addListener(() => listenerRanBeforeOnChanged = true);

      controller.insertText('A');

      expect(onChangedSawListenerState, isFalse,
          reason: 'onChanged must fire before notifyListeners');
      expect(listenerRanBeforeOnChanged, isTrue);

      controller.dispose();
    });

    test('executeCommand (registry) fires onCommandExecuted with built command', () {
      final controller = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      controller.registry.register(
        CommandDescriptor(
          name: 'insertHey',
          factory: (args) =>
              InsertTextCommand(args.readString('text') ?? 'hey'),
        ),
      );
      EditorCommand? cmdSeen;
      var commandRuns = 0;
      controller.onCommandExecuted = (cmd, _) {
        commandRuns++;
        cmdSeen = cmd;
      };

      controller.executeCommand('insertHey', <String, Object?>{'text': 'Hey'});

      expect(commandRuns, 1);
      expect(cmdSeen, isA<InsertTextCommand>());
      expect(controller.document.plainText, 'HeyHello');

      controller.dispose();
    });

    test('onCommandExecuted receives the exact command instance passed to execute', () {
      final controller = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      EditorCommand? received;
      controller.onCommandExecuted = (cmd, _) => received = cmd;

      const sent = InsertTextCommand('Z');
      controller.execute(sent);

      // Same identity — the callback gets the command object the caller passed.
      expect(identical(received, sent), isTrue);

      controller.dispose();
    });

    test('code block plain paste emits one command and listener notification',
        () {
      final pastedCode = '${List<String>.generate(
        520,
        (index) => 'final value$index = $index;',
      ).join('\n')}\n';
      final controller = WenzRichTextController(
        document: _codeDoc('void main() {}'),
        selection: collapsedCodeSelection('code1', 0, 5),
      );
      var docChanges = 0;
      var selectionChanges = 0;
      var commandRuns = 0;
      var listenerNotifications = 0;
      EditorCommand? commandSeen;

      controller.onChanged = (_) => docChanges++;
      controller.onSelectionChanged = (_) => selectionChanges++;
      controller.onCommandExecuted = (command, _) {
        commandRuns++;
        commandSeen = command;
      };
      controller.addListener(() => listenerNotifications++);

      controller.pasteText(pastedCode);

      final block = controller.document.blocks.single as CodeBlockNode;
      expect(block.code, 'void ${pastedCode}main() {}');
      expect(controller.selection?.extent.offset, 5 + pastedCode.length);
      expect(docChanges, 1);
      expect(selectionChanges, 1);
      expect(commandRuns, 1);
      expect(listenerNotifications, 1);
      expect(commandSeen, isA<InsertTextCommand>());

      controller.dispose();
    });
  });
}

RichTextDocument _doc() => const RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'p1',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'Hello')],
        ),
      ],
    );

RichTextDocument _codeDoc(String code) => RichTextDocument(
      blocks: <BlockNode>[
        CodeBlockNode(id: 'code1', code: code, language: 'dart'),
      ],
    );

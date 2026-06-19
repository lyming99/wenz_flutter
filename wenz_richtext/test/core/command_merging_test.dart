import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  group('command merging', () {
    test('consecutive insertText coalesces into a single undo step', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const InsertTextCommand('a'));
      executor.execute(const InsertTextCommand('b'));
      executor.execute(const InsertTextCommand('c'));

      expect(session.document.plainText, 'abc');
      expect(session.canUndo, isTrue);
      // One coalesced undo step reverts the whole run.
      session.undo();
      expect(session.document.plainText, '');
      expect(session.canUndo, isFalse);
    });

    test('insertText with different attributes does not merge', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const InsertTextCommand('a'));
      executor.execute(
        const InsertTextCommand('b', attributes: TextAttributes(bold: true)),
      );

      expect(session.document.plainText, 'ab');
      // Two separate undo steps.
      expect(session.canUndo, isTrue);
      session.undo();
      expect(session.document.plainText, 'a');
      expect(session.canUndo, isTrue);
      session.undo();
      expect(session.document.plainText, '');
      expect(session.canUndo, isFalse);
    });

    test('caret movement breaks an insert coalesce run', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'xx')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const InsertTextCommand('a'));
      // Move the caret (records no history but breaks the run).
      executor.execute(
        const MoveCaretCommand(CaretMovementDirection.forward),
      );
      executor.execute(const InsertTextCommand('b'));

      expect(session.document.plainText, 'axbx');
      // Two undo steps: 'a' insertion, then 'b' insertion.
      session.undo();
      expect(session.document.plainText, 'axx');
      session.undo();
      expect(session.document.plainText, 'xx');
      expect(session.canUndo, isFalse);
    });

    test('non-contiguous insertText does not merge', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'ab')],
            ),
          ],
        ),
        // Caret at offset 0 to start.
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const InsertTextCommand('X')); // -> 'Xab', caret 1
      // Jump the caret to the end without a movement command: set selection
      // directly, then insert. The contiguity check must reject the merge.
      session.selection = collapsedTextSelection('p1', 0, 4);
      executor.execute(const InsertTextCommand('Y')); // -> 'XabY', caret 5

      expect(session.document.plainText, 'XabY');
      // Two undo steps because the caret was repositioned between inserts.
      session.undo();
      expect(session.document.plainText, 'Xab');
      session.undo();
      expect(session.document.plainText, 'ab');
      expect(session.canUndo, isFalse);
    });

    test('consecutive deleteBackward coalesces into one undo step', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abc')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 3),
      );
      final executor = CommandExecutor(session);

      executor.execute(const DeleteBackwardCommand());
      executor.execute(const DeleteBackwardCommand());

      expect(session.document.plainText, 'a');
      session.undo();
      // One coalesced step restores both deleted characters.
      expect(session.document.plainText, 'abc');
      expect(session.canUndo, isFalse);
    });

    test('deleteBackward and deleteForward do not merge with each other', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abc')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 1),
      );
      final executor = CommandExecutor(session);

      executor.execute(const DeleteBackwardCommand()); // -> 'bc'
      session.selection = collapsedTextSelection('p1', 0, 0);
      executor.execute(const DeleteForwardCommand()); // -> 'c'

      expect(session.document.plainText, 'c');
      // Two undo steps (different command types).
      session.undo();
      expect(session.document.plainText, 'bc');
      session.undo();
      expect(session.document.plainText, 'abc');
      expect(session.canUndo, isFalse);
    });

    test('enter command does not merge with insertText', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'ab')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 1),
      );
      final executor = CommandExecutor(session);

      executor.execute(const InsertTextCommand('X'));
      executor.execute(const EnterCommand(newBlockId: 'p2'));
      executor.execute(const InsertTextCommand('Y'));

      expect(session.document.blocks, hasLength(2));
      // Three undo steps.
      session.undo(); // Y
      session.undo(); // enter
      session.undo(); // X
      expect(session.document.plainText, 'ab');
      expect(session.canUndo, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('WenzRichTextController.updateCalloutBlock', () {
    test('updates callout metadata and participates in undo redo', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            CalloutBlockNode(
              id: 'co1',
              variant: 'info',
              title: 'Before',
              icon: 'ℹ️',
              content: <InlineNode>[TextRun(text: 'body')],
            ),
          ],
        ),
      );

      final change = controller.updateCalloutBlock(
        blockIndex: 0,
        variant: 'warning',
        title: 'Watch out',
        icon: '⚠️',
      );

      expect(change.description, 'updateCalloutBlock');
      var callout = controller.document.blocks.single as CalloutBlockNode;
      expect(callout.variant, 'warning');
      expect(callout.title, 'Watch out');
      expect(callout.icon, '⚠️');

      expect(controller.undo(), isTrue);
      callout = controller.document.blocks.single as CalloutBlockNode;
      expect(callout.variant, 'info');
      expect(callout.title, 'Before');
      expect(callout.icon, 'ℹ️');

      expect(controller.redo(), isTrue);
      callout = controller.document.blocks.single as CalloutBlockNode;
      expect(callout.variant, 'warning');
      expect(callout.title, 'Watch out');
      expect(callout.icon, '⚠️');

      controller.dispose();
    });

    test('clears custom title and icon to restore defaults', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            CalloutBlockNode(
              id: 'co1',
              variant: 'success',
              title: 'Done',
              icon: '🎉',
              content: <InlineNode>[TextRun(text: 'body')],
            ),
          ],
        ),
      );

      controller.updateCalloutBlock(blockIndex: 0, title: '', icon: '');

      final callout = controller.document.blocks.single as CalloutBlockNode;
      expect(callout.title, isEmpty);
      expect(callout.icon, isEmpty);
      expect(callout.effectiveTitle, 'Success');
      expect(callout.effectiveIcon, '✅');

      controller.dispose();
    });
  });
}

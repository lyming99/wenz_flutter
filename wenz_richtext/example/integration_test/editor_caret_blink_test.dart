import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'helpers/expect_helpers.dart';
import 'helpers/keyboard_helpers.dart';
import 'helpers/pointer_helpers.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('caret blink', () {
    testWidgets('the caret keeps repainting across multiple blink periods '
        'without errors', (tester) async {
      // A visible caret drives a repeating ticker; pumping through several
      // full blink periods must not throw and must keep the caret mounted.
      final workbench = await pumpWorkbench(tester);
      final controller = workbench.controller;

      await typeText(tester, controller, 'abc');
      expect(isCaretVisible(tester), isTrue);

      // Pump well past one full blink period (~530ms) in steps. The caret
      // widget must remain present throughout and no exception may surface.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.byKey(const ValueKey<String>('wenz-richtext-caret')),
            findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the caret disappears (no blink ticker) when the selection is '
        'non-collapsed', (tester) async {
      // While a range is selected the caret is hidden; pumping should settle
      // (no repeating ticker running) and the caret key must be absent.
      await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcdef')],
            ),
          ],
        ),
      );

      // Select a range so the caret hides.
      await dragInsideText(tester, 'abcdef', fromOffset: 0, toOffset: 3);
      final controller = (tester.widget<WenzRichTextEditor>(
        find.byType(WenzRichTextEditor),
      )).controller;
      expect(controller.selection?.isCollapsed, isFalse);
      expect(isCaretVisible(tester), isFalse);

      // With the caret hidden the blink ticker stops, so the frame queue
      // settles within the default timeout.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

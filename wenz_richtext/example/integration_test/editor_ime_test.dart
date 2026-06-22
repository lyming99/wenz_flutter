import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/keyboard_helpers.dart';
import 'helpers/pointer_helpers.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('IME / Chinese input', () {
    testWidgets('commits Chinese characters via the IME insertion path', (
      tester,
    ) async {
      // The IME commits CJK text as a TextEditingDeltaInsertion; the
      // controller's insertText path is what receives it. This test verifies
      // that Chinese characters are not filtered and land in the document.
      final workbench = await pumpWorkbench(tester);
      final controller = workbench.controller;

      await typeText(tester, controller, '你好世界');

      expect(controller.document.plainText, '你好世界');
      expect(richTextWith('你好世界'), findsOneWidget);
    });

    testWidgets('commits mixed CJK and ASCII text', (tester) async {
      final workbench = await pumpWorkbench(tester);
      final controller = workbench.controller;

      await typeText(tester, controller, 'Hello 世界!');

      expect(controller.document.plainText, 'Hello 世界!');
      expect(richTextWith('Hello 世界!'), findsOneWidget);
    });

    testWidgets('Chinese text can be selected and deleted', (tester) async {
      final workbench = await pumpWorkbench(tester);
      final controller = workbench.controller;

      await typeText(tester, controller, '你好');
      // Drag-select the whole run, then delete it.
      await dragInsideText(tester, '你好', fromOffset: 0, toOffset: 2);
      expect(controller.selection?.isCollapsed, isFalse);

      await sendKey(tester, LogicalKeyboardKey.backspace);
      expect(controller.document.plainText, '');
    });
  });
}

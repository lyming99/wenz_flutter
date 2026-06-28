import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('theme toggle', () {
    testWidgets('switches editor surface while preserving document content', (
      tester,
    ) async {
      const text = 'Theme switching keeps content';
      await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: text)],
            ),
          ],
        ),
      );

      Color editorSurfaceColor() {
        return tester
            .widget<ColoredBox>(find.byKey(testEditorSurfaceKey))
            .color;
      }

      expect(find.text(text), findsOneWidget);
      expect(editorSurfaceColor(), Colors.white);
      expect(find.byTooltip('切换深色主题'), findsOneWidget);

      await tester.tap(find.byKey(testThemeToggleKey));
      await tester.pumpAndSettle();

      expect(find.text(text), findsOneWidget);
      expect(editorSurfaceColor(), Colors.black);
      expect(find.byTooltip('切换浅色主题'), findsOneWidget);

      await tester.tap(find.byKey(testThemeToggleKey));
      await tester.pumpAndSettle();

      expect(find.text(text), findsOneWidget);
      expect(editorSurfaceColor(), Colors.white);
      expect(find.byTooltip('切换深色主题'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('mouse cursor', () {
    testWidgets('editable editor shows the text (I-beam) cursor on hover', (
      tester,
    ) async {
      await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'hello')],
            ),
          ],
        ),
      );

      final region = _mouseRegionOverEditor(tester);
      expect(region, isNotNull);
      expect(region!.cursor, SystemMouseCursors.text);
    });

    testWidgets('read-only editor shows the default (arrow) cursor', (
      tester,
    ) async {
      final workbench = TestWorkbench(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'hello')],
            ),
          ],
        ),
      );
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      installTestClipboard();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: workbench.controller,
              readOnly: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final region = _mouseRegionOverEditor(tester);
      expect(region, isNotNull);
      expect(region!.cursor, SystemMouseCursors.basic);
    });
  });
}

/// Finds the [MouseRegion] wrapping the editor surface. Returns `null` when the
/// editor is not mounted.
MouseRegion? _mouseRegionOverEditor(WidgetTester tester) {
  final element = find
      .byType(MouseRegion)
      .evaluate()
      .where((e) => _isUnderEditor(e))
      .firstOrNull;
  if (element == null) {
    // Fall back to any MouseRegion in the tree (the editor's own).
    final any = find.byType(MouseRegion);
    if (any.evaluate().isEmpty) {
      return null;
    }
    return tester.widget(any) as MouseRegion;
  }
  return element.widget as MouseRegion;
}

bool _isUnderEditor(Element element) {
  bool under = false;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget is WenzRichTextEditor) {
      under = true;
      return false;
    }
    return true;
  });
  return under;
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets('custom code colors do not change the popup menu brightness', (
    tester,
  ) async {
    const blockId = 'code1';
    final path = PositionPath.blockCode(blockId);
    final position = DocumentPosition(
      blockId: blockId,
      blockIndex: 0,
      path: path,
      offset: 0,
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(
            id: blockId,
            code: 'final answer = 42;',
            language: 'dart',
          ),
        ],
      ),
      selection: DocumentSelection(base: position, extent: position),
    );
    const codeTheme = WenzCodeBlockThemeData(
      backgroundColor: Color(0xFF102030),
      foregroundColor: Color(0xFFF4F6F8),
      borderColor: Color(0xFF506070),
      accentColor: Color(0xFF80D8C8),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true).copyWith(
          extensions: const <ThemeExtension<dynamic>>[codeTheme],
        ),
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    final codeSurface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('wenz-richtext-code-block-code1')),
    );
    final decoration = codeSurface.decoration as BoxDecoration;
    expect(decoration.color, codeTheme.backgroundColor);
    expect((decoration.border! as Border).top.color, codeTheme.accentColor);

    await tester.tap(find.byTooltip('切换代码语言'));
    await tester.pumpAndSettle();

    final pythonLabel = find.text('python');
    final menuMaterial = find.ancestor(
      of: pythonLabel,
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.elevation == 3,
      ),
    );
    expect(menuMaterial, findsOneWidget);
    expect(
      tester.widget<Material>(menuMaterial).color,
      const Color(0xFFF8F9FA),
    );
    expect(
      Theme.of(tester.element(pythonLabel)).brightness,
      Brightness.light,
    );
  });
}

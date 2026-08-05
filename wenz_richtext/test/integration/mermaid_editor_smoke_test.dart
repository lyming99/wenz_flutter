import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../mermaid/mermaid_fixtures.dart';

Future<void> _waitForDiagram(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (find.byType(MermaidDiagram).evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  fail('Timed out waiting for the editor Mermaid preview.');
}

void main() {
  for (final fixture in supportedMermaidFixtures) {
    testWidgets(
      'editor opens ${fixture.name}, previews, returns to source, and preserves DSL',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final bootstrap = WenzEditorBootstrap.create(
          WenzEditorConfiguration(
            document: RichTextDocument(
              blocks: <BlockNode>[
                CodeBlockNode(
                  id: 'mermaid-${fixture.name}',
                  language: 'mermaid',
                  code: fixture.cjk,
                ),
              ],
            ),
            enableMermaidDiagrams: true,
            enableToolbar: false,
            enableOutline: false,
            enableStats: false,
            enableFindReplace: false,
            enableSlashMenu: false,
          ),
        );
        addTearDown(bootstrap.dispose);
        final before = bootstrap.toMarkdown();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: bootstrap.buildEditor(enableIme: false),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(MermaidCodeBlockWidget), findsOneWidget);
        await tester.tap(
          find.byKey(
            const ValueKey<String>('wenz-richtext-mermaid-toggle'),
          ),
        );
        await tester.pump();
        await _waitForDiagram(tester);

        final result =
            tester.widget<MermaidDiagram>(find.byType(MermaidDiagram)).result;
        expect(result.diagramType, fixture.type);
        expect(bootstrap.toMarkdown(), before);

        await tester.tap(
          find.byKey(
            const ValueKey<String>('wenz-richtext-mermaid-toggle'),
          ),
        );
        await tester.pump();
        expect(find.byType(MermaidDiagram), findsNothing);
        expect(find.byType(MermaidCodeBlockWidget), findsOneWidget);
        expect(bootstrap.toMarkdown(), before);
      },
    );
  }
}

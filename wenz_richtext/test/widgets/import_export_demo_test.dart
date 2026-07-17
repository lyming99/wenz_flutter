// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../../example/lib/main.dart';
import '../../example/lib/test_host.dart';

void main() {
  testWidgets('example loads markdown sample and previews export', (
    tester,
  ) async {
    await tester.pumpWidget(const WenzRichTextExampleApp());
    await tester.pump();

    await _tapInspectorAction(
      tester,
      const Key('import-export-load-markdown'),
    );
    await tester.pump();

    final controller = WenzEditorTestHost.of(
      tester.element(find.byType(WenzRichTextEditor)),
    )!;
    final heading = controller.document.blocks.first as TextBlockNode;

    expect(heading.type, BlockType.heading);
    expect(heading.plainText, 'Markdown import demo');
    expect(
        controller.document.blocks.whereType<VideoBlockNode>(), hasLength(1));
    expect(controller.toMarkdown(),
        contains('![video](https://example.com/demo.mp4)'));

    await _tapInspectorAction(
      tester,
      const Key('import-export-export-markdown'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Markdown export preview'), findsOneWidget);
    expect(find.textContaining('# Markdown import demo'), findsOneWidget);
  });

  testWidgets('example loads html sample with file metadata', (tester) async {
    await tester.pumpWidget(const WenzRichTextExampleApp());
    await tester.pump();

    await _tapInspectorAction(
      tester,
      const Key('import-export-load-html'),
    );
    await tester.pump();

    final controller = WenzEditorTestHost.of(
      tester.element(find.byType(WenzRichTextEditor)),
    )!;
    final paragraph = controller.document.blocks[1] as TextBlockNode;
    final inlineImage = paragraph.content.whereType<InlineEmbed>().single;
    final table = controller.document.blocks.whereType<TableBlockNode>().single;
    final fileBlock =
        controller.document.blocks.whereType<FileBlockNode>().single;

    expect(controller.document.blocks.first.plainText, 'HTML import demo');
    expect(inlineImage.data['assetId'], 'https://example.com/inline.png');
    expect(inlineImage.data['caption'], 'Inline badge');
    expect(table.table.rows[0][0].rowSpan, 2);
    expect(table.table.rows[0][0].columnSpan, 2);
    expect(table.table.rows[0][1].covered, isTrue);
    expect(table.table.rows[1][0].covered, isTrue);
    expect(fileBlock.assetId, 'file-demo');
    expect(fileBlock.file, 'spec.pdf');
    expect(fileBlock.mimeType, 'application/pdf');
    final html = controller.toHtml();
    expect(html, contains('data-caption="Inline badge"'));
    expect(html, contains('rowspan="2"'));
    expect(html, contains('colspan="2"'));
    expect(html, contains('data-wenz-block="file"'));

    await _tapInspectorAction(
      tester,
      const Key('import-export-export-html'),
    );
    await tester.pumpAndSettle();

    expect(find.text('HTML export preview'), findsOneWidget);
    expect(find.textContaining('rowspan="2"'), findsOneWidget);
  });
}

Future<void> _tapInspectorAction(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  tester.widget<OutlinedButton>(finder).onPressed?.call();
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('isolate export matches synchronous JSON markdown and plain text',
      () async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
          TextBlockNode(
            id: 'li1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'Item')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
    );
    addTearDown(controller.dispose);
    controller.insertText('!');

    final synchronous = await controller.exportSnapshot();
    final isolated = await controller.exportSnapshot(useIsolate: true);

    expect(isolated.json, synchronous.json);
    expect(isolated.markdown, synchronous.markdown);
    expect(isolated.plainText, synchronous.plainText);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  const service = ClipboardService();
  const source = RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'li1',
        type: BlockType.listItem,
        content: <InlineNode>[TextRun(text: 'clipboard item')],
      ),
    ],
  );
  final selection = DocumentSelection(
    base: DocumentPosition.text(blockId: 'li1', blockIndex: 0, offset: 0),
    extent: DocumentPosition.text(blockId: 'li1', blockIndex: 0, offset: 14),
  );

  test('normalizes Windows CRLF private header without adding a second prefix',
      () {
    final payload = service.copyPayload(source, selection)!;
    final windowsValue = payload.wenzRichText.replaceFirst('\n', '\r\n');
    final snapshot = RichClipboardSnapshot(wenzRichText: windowsValue);

    final normalized = snapshot.wenzRichTextForPaste;

    expect(normalized, payload.wenzRichText);
    expect(
      normalized!.split(_wenzHeaderForTest).length - 1,
      1,
    );
    final paste = service.parse(normalized);
    expect(paste.isBlocks, isTrue);
    expect(paste.blocks.single.type, BlockType.listItem);
    expect(paste.text, 'clipboard item');
  });

  test('recovers repeated LF and CRLF private headers', () {
    final payload = service.copyPayload(source, selection)!;
    final windowsValue = payload.wenzRichText.replaceFirst('\n', '\r\n');
    final repeated = '$wenzClipboardPrefix$windowsValue';

    final normalized = normalizeWenzClipboardPayload(repeated);
    final paste = service.parse(repeated);

    expect(normalized, payload.wenzRichText);
    expect(paste.isBlocks, isTrue);
    expect(paste.text, 'clipboard item');
  });

  test('invalid private data falls back to HTML and then plain text', () {
    final htmlPaste = service.parseFormats(
      wenzRichText: 'invalid private payload',
      html: '<ul><li>html fallback</li></ul>',
      plainText: 'plain fallback',
    );
    final plainPaste = service.parseFormats(
      wenzRichText: 'invalid private payload',
      plainText: 'plain fallback',
    );

    expect(htmlPaste, isNotNull);
    expect(htmlPaste!.isBlocks, isTrue);
    expect(htmlPaste.blocks.single.type, BlockType.listItem);
    expect(htmlPaste.text, 'html fallback');
    expect(plainPaste, isNotNull);
    expect(plainPaste!.isRich, isFalse);
    expect(plainPaste.text, 'plain fallback');
  });
}

const String _wenzHeaderForTest = 'wenz-richtext-json:v1';

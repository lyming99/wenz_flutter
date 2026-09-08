import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  const codec = MarkdownCodec();

  group('CommonMark backslash escapes', () {
    for (final source in <String>[
      r'C:\Users\name\file.txt',
      r'D:\project\wenz_flutter',
      r'\a \Z \1 \中 \。 \ ',
      'trailing\\',
    ]) {
      test('preserves non-escapes: $source', () {
        expect(codec.decode(source).plainText, source);
      });
    }

    for (final code in <int>[
      for (var c = 0x21; c <= 0x2f; c++) c,
      for (var c = 0x3a; c <= 0x40; c++) c,
      for (var c = 0x5b; c <= 0x60; c++) c,
      for (var c = 0x7b; c <= 0x7e; c++) c,
    ]) {
      test('escapes ASCII punctuation U+${code.toRadixString(16)}', () {
        final punctuation = String.fromCharCode(code);
        expect(
            codec.decode('a \\$punctuation z').plainText, 'a $punctuation z');
      });
    }

    test('Markdown escapes remain meaningful for paths', () {
      expect(codec.decode(r'C:\_cache').plainText, 'C:_cache');
      expect(codec.decode(r'\\server\share').plainText, r'\server\share');
    });

    test('code spans and fenced code preserve literal paths', () {
      const path = r'\\server\share\_cache\[a]\file.txt';
      expect(codec.decode('`$path`').plainText, path);
      final block =
          codec.decode('```text\n$path\n```').blocks.single as CodeBlockNode;
      expect(block.code, path);
    });

    test('nested emphasis and link labels preserve paths', () {
      const path = r'C:\Users\name';
      for (final source in [
        '**$path**',
        '*$path*',
        '[$path](https://example.com)'
      ]) {
        expect(codec.decode(source).plainText, path);
      }
    });

    test('plain-text paste and repeated Markdown export do not double escape',
        () {
      const path = r'\\server\share\_cache\[a]\file.txt';
      const clipboard = ClipboardService();
      expect(clipboard.parse(path).text, path);
      expect(clipboard.parse(path, format: ClipboardPasteFormat.plainText).text,
          path);
      var document = const RichTextDocument(blocks: <BlockNode>[
        TextBlockNode(
            id: 'p',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: path)]),
      ]);
      for (var i = 0; i < 3; i++) {
        document = codec.decode(codec.encode(document));
        expect(document.plainText, path);
      }
    });

    test('explicit Markdown paste uses the same escape rules', () {
      const path = r'C:\Users\name';
      final paste = const ClipboardService()
          .parse(path, format: ClipboardPasteFormat.markdown);
      expect(paste.blocks.map((block) => block.plainText).join('\n'), path);
    });
  });
}

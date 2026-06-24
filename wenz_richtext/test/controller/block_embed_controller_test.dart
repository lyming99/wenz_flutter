import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('WenzRichTextController block embeds', () {
    test('insertBlockEmbed writes metadata and participates in undo redo', () {
      final controller = WenzRichTextController();

      final change = controller.insertBlockEmbed(
        blockId: 'embed1',
        embedType: 'crm-card',
        data: <String, Object?>{'recordId': '42'},
        fallbackText: 'Acme account',
      );

      expect(change.description, 'insertBlocks');
      final block = controller.document.blocks.last as BlockEmbedNode;
      expect(block.embedType, 'crm-card');
      expect(block.data, containsPair('recordId', '42'));
      expect(block.fallbackText, 'Acme account');

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks.last, isA<TextBlockNode>());

      expect(controller.redo(), isTrue);
      expect(controller.document.blocks.last, isA<BlockEmbedNode>());

      controller.dispose();
    });
  });
}

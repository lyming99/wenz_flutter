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

  group('WenzRichTextController.updateBlockEmbed', () {
    test('refreshes data in place and participates in undo redo', () {
      final controller = WenzRichTextController();
      controller.insertBlockEmbed(
        blockId: 'flowchart',
        embedType: 'flowchart',
        data: const <String, Object?>{
          'nodes': <Object?>[
            <String, Object?>{
              'id': 'start',
              'label': '开始',
              'x': 0,
              'y': 0,
              'kind': 'start',
            },
          ],
          'direction': 'TB',
          'version': 1,
        },
        fallbackText: '流程图',
      );

      final change = controller.updateBlockEmbed(
        blockId: 'flowchart',
        data: const <String, Object?>{
          'nodes': <Object?>[
            <String, Object?>{
              'id': 'start',
              'label': '开始',
              'x': 42,
              'y': 88,
              'kind': 'start',
            },
            <String, Object?>{
              'id': 'end',
              'label': '结束',
              'x': 42,
              'y': 160,
              'kind': 'end',
            },
          ],
          'direction': 'TB',
          'version': 1,
        },
      );

      expect(change.description, 'replaceBlocks');
      expect(change.isNoop, isFalse);
      // The block id is preserved so selection and geometry stay stable.
      final block = controller.document.blocks.last as BlockEmbedNode;
      expect(block.id, 'flowchart');
      expect(block.embedType, 'flowchart');
      final nodes = block.data['nodes'] as List<Object?>;
      expect(nodes, hasLength(2));
      final movedStart = Map<String, Object?>.from(nodes.first as Map);
      expect(movedStart['x'], 42);
      expect(movedStart['y'], 88);

      expect(controller.undo(), isTrue);
      final undone = controller.document.blocks.last as BlockEmbedNode;
      expect((undone.data['nodes'] as List<Object?>), hasLength(1));

      expect(controller.redo(), isTrue);
      final redone = controller.document.blocks.last as BlockEmbedNode;
      expect((redone.data['nodes'] as List<Object?>), hasLength(2));

      controller.dispose();
    });

    test('fires change callbacks through the command layer', () {
      final controller = WenzRichTextController();
      controller.insertBlockEmbed(
        blockId: 'flowchart',
        embedType: 'flowchart',
        data: const <String, Object?>{'version': 1},
        fallbackText: '流程图',
      );

      var changedCalls = 0;
      var commandCalls = 0;
      controller.onChanged = (_) => changedCalls += 1;
      controller.onCommandExecuted = (command, change) => commandCalls += 1;

      controller.updateBlockEmbed(
        blockId: 'flowchart',
        data: const <String, Object?>{'version': 2},
      );

      expect(changedCalls, greaterThan(0));
      expect(commandCalls, greaterThan(0));
      expect(
        (controller.document.blocks.last as BlockEmbedNode).data['version'],
        2,
      );

      controller.dispose();
    });

    test('is a no-op for a missing block or no arguments', () {
      final controller = WenzRichTextController();
      controller.insertBlockEmbed(
        blockId: 'flowchart',
        embedType: 'flowchart',
        data: const <String, Object?>{'version': 1},
        fallbackText: '流程图',
      );

      final missing = controller.updateBlockEmbed(
        blockId: 'missing',
        data: const <String, Object?>{'version': 2},
      );
      expect(missing.isNoop, isTrue);

      final noArgs = controller.updateBlockEmbed(blockId: 'flowchart');
      expect(noArgs.isNoop, isTrue);

      // Both no-op attempts leave the existing block untouched.
      expect(
        (controller.document.blocks.last as BlockEmbedNode).data['version'],
        1,
      );

      controller.dispose();
    });

    test('insertBlockEmbed and updateBlockEmbed are blocked by read permission',
        () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            BlockEmbedNode(
              id: 'flowchart',
              embedType: 'flowchart',
              data: <String, Object?>{'version': 1},
              fallbackText: '流程图',
            ),
          ],
        ),
        permission: WenzEditorPermission.read,
      );

      final insertChange = controller.insertBlockEmbed(
        blockId: 'blocked-insert',
        embedType: 'flowchart',
        data: const <String, Object?>{'version': 1},
        fallbackText: '流程图',
      );
      expect(insertChange.isNoop, isTrue);
      expect(insertChange.description, 'permission:blocked:insertBlocks');
      expect(controller.document.blocks, hasLength(1));

      final updateChange = controller.updateBlockEmbed(
        blockId: 'flowchart',
        data: const <String, Object?>{'version': 2},
      );
      expect(updateChange.isNoop, isTrue);
      expect(updateChange.description, 'permission:blocked:replaceBlocks');
      // The seed embed is untouched: no history recorded, data unchanged.
      expect(
        (controller.document.blocks.single as BlockEmbedNode).data['version'],
        1,
      );
      expect(controller.canUndo, isFalse);

      controller.dispose();
    });
  });
}

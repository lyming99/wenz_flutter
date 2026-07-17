import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets(
    'configuration forwards media resource handler to block render context',
    (tester) async {
      const image = ImageBlockNode(
        id: 'image-1',
        assetId: 'asset-1',
        file: 'file:///tmp/image.png',
      );
      final dispatched = <MediaResourceActionIntent>[];
      Future<void> handler(MediaResourceActionIntent intent) async {
        dispatched.add(intent);
      }

      BlockRenderContext? capturedContext;
      final configuration = WenzEditorConfiguration(
        document: const RichTextDocument(blocks: <BlockNode>[image]),
        permission: WenzEditorPermission.read,
        enableExternalDragDrop: false,
        onMediaResourceAction: handler,
        blockRenderers: <BlockType, BlockRendererBuilder>{
          BlockType.image: (context, renderContext) {
            capturedContext = renderContext;
            return const SizedBox(height: 40, child: Text('host image'));
          },
        },
      );
      final bootstrap = WenzEditorBootstrap.create(configuration);
      addTearDown(bootstrap.dispose);

      final editor = bootstrap.buildEditor();
      expect(editor.onMediaResourceAction, same(handler));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: editor),
        ),
      );
      await tester.pump();

      final renderContext = capturedContext;
      expect(renderContext, isNotNull);
      expect(renderContext!.canEdit, isFalse);
      expect(renderContext.onMediaResourceAction, same(handler));

      final intent = MediaResourceActionIntent(
        action: MediaResourceAction.copyImage,
        blockIndex: renderContext.blockIndex,
        mediaType: MediaResourceType.image,
        block: renderContext.block,
      );
      await renderContext.onMediaResourceAction!(intent);

      expect(dispatched, <MediaResourceActionIntent>[intent]);
      expect(dispatched.single.block, same(image));
    },
  );

  test('handler is optional and copyWith can preserve or clear it', () async {
    expect(
      const WenzEditorConfiguration().onMediaResourceAction,
      isNull,
    );

    Future<void> handler(MediaResourceActionIntent intent) async {}
    final configuration = WenzEditorConfiguration(
      onMediaResourceAction: handler,
    );

    expect(configuration.copyWith().onMediaResourceAction, same(handler));
    expect(
      configuration.copyWith(onMediaResourceAction: null).onMediaResourceAction,
      isNull,
    );
  });
}

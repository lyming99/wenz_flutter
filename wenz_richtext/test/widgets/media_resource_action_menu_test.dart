import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets('image and video menus expose host resource actions',
      (tester) async {
    final intents = <MediaResourceActionIntent>[];
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(
            id: 'image-1',
            assetId: 'image-asset',
            file: 'image.png',
          ),
          VideoBlockNode(
            id: 'video-1',
            assetId: 'video-asset',
            file: 'video.mp4',
          ),
        ],
      ),
      selection: _objectSelection('image-1', 0),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
            onMediaResourceAction: (intent) async => intents.add(intent),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();
    for (final label in const <String>[
      '打开图片路径',
      '复制图片路径',
      '查看图片详情',
      '复制内存图片',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('查看图片详情'));
    await tester.pumpAndSettle();
    expect(intents, hasLength(1));
    expect(intents.single.action, MediaResourceAction.showDetails);
    expect(intents.single.mediaType, MediaResourceType.image);

    controller.setSelection(_objectSelection('video-1', 1));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();
    for (final label in const <String>[
      '打开视频路径',
      '复制视频路径',
      '查看视频详情',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('复制内存图片'), findsNothing);
    await tester.tap(find.text('查看视频详情'));
    await tester.pumpAndSettle();
    expect(intents, hasLength(2));
    expect(intents.last.action, MediaResourceAction.showDetails);
    expect(intents.last.mediaType, MediaResourceType.video);
  });
}

DocumentSelection _objectSelection(String blockId, int blockIndex) {
  final position = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(blockId),
    offset: 0,
  );
  return DocumentSelection(base: position, extent: position);
}

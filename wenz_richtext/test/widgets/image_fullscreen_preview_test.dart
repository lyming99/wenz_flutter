import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets(
    'image preview fills changing root viewports and closes by button or Esc',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'word-image',
              assetId: 'word-original',
              file: 'word-original.png',
              width: 2400,
              height: 1600,
              altText: 'Word original image',
            ),
          ],
        ),
        selection: objectBlockSelection('word-image', 0),
      );
      addTearDown(controller.dispose);

      Future<void> pumpAt(Size size) async {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  height: 240,
                  child: WenzRichTextEditor(
                    controller: controller,
                    mediaResolver: const _ImageResolver(),
                    enableIme: false,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      Future<void> openAndExpectViewport(Size size) async {
        await tester.tap(find.byTooltip('预览媒体'));
        await tester.pumpAndSettle();

        final surface = find.byKey(_surfaceKey);
        final viewport = find.byKey(_viewportKey);
        final viewer = find.byKey(_viewerKey);
        expect(find.byType(Dialog), findsNothing);
        expect(tester.getSize(surface), size);
        expect(tester.getSize(viewport), size);
        expect(tester.getTopLeft(surface), Offset.zero);
        expect(tester.getTopLeft(viewport), Offset.zero);
        expect(viewer, findsOneWidget);

        final interactiveViewer = tester.widget<InteractiveViewer>(viewer);
        expect(interactiveViewer.panEnabled, isTrue);
        expect(interactiveViewer.scaleEnabled, isTrue);
        expect(interactiveViewer.minScale, lessThan(1));
        expect(interactiveViewer.maxScale, greaterThan(1));
        expect(
          find.descendant(
            of: surface,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == 'Word original image',
            ),
          ),
          findsOneWidget,
        );
      }

      const compactSize = Size(640, 480);
      await pumpAt(compactSize);
      await openAndExpectViewport(compactSize);
      expect(find.byTooltip('关闭图片预览'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭图片预览'));
      await tester.pumpAndSettle();
      expect(find.byKey(_surfaceKey), findsNothing);

      const maximizedSize = Size(1440, 900);
      await pumpAt(maximizedSize);
      await openAndExpectViewport(maximizedSize);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_surfaceKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

const _surfaceKey =
    ValueKey<String>('wenz-richtext-image-fullscreen-surface-word-image');
const _viewportKey =
    ValueKey<String>('wenz-richtext-image-fullscreen-viewport-word-image');
const _viewerKey =
    ValueKey<String>('wenz-richtext-image-fullscreen-viewer-word-image');

class _ImageResolver implements MediaResolver {
  const _ImageResolver();

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    return block is ImageBlockNode
        ? const ColoredBox(color: Colors.blue)
        : null;
  }
}

DocumentSelection objectBlockSelection(String blockId, int blockIndex) {
  final start = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(blockId),
    offset: 0,
  );
  return DocumentSelection(
    base: start,
    extent: start.copyWith(offset: 1),
  );
}

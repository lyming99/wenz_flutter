import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

/// B6 — verifies the [MediaResolver] injection point: injected resolvers take
/// over image/video/file block rendering, returning `null` falls back to the
/// built-in placeholder, and a throwing resolver does not crash the editor.
/// See `docs/acceptance_report.md` task B6 / acceptance item 8.3.
void main() {
  group('MediaResolver injection', () {
    testWidgets('resolver widget wins over the placeholder', (tester) async {
      final resolver = _RecordingResolver();
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'img1', assetId: 'resolved-id', file: 'a.png'),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              mediaResolver: resolver,
              enableIme: false,
            ),
          ),
        ),
      );

      expect(find.text('resolved:resolved-id'), findsOneWidget);
      // Placeholder is NOT rendered for this block — the resolver widget wins
      // over both the empty-state and load-failure placeholder copy.
      expect(find.text('图片占位'), findsNothing);
      expect(find.text('图片加载失败'), findsNothing);
      // The resolver received the right block with its fields intact.
      expect(resolver.seenImageAssetIds, ['resolved-id']);
    });

    testWidgets('resolver can render a local image file source',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'img1',
              assetId: '',
              file: '/tmp/local-image.png',
              caption: 'Local image',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              mediaResolver: _SourceAwareImageResolver(),
              enableIme: false,
            ),
          ),
        ),
      );

      expect(find.text('local:/tmp/local-image.png'), findsOneWidget);
      expect(find.text('Local image'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
    });

    testWidgets('empty image source falls back to the built-in placeholder',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'img1', assetId: '', file: ''),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              mediaResolver: _SourceAwareImageResolver(),
              enableIme: false,
            ),
          ),
        ),
      );

      expect(find.text('local:'), findsNothing);
      expect(find.text('network:'), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('network image source remains resolver driven',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'img1',
              assetId: 'https://cdn.example.com/hero.png',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              mediaResolver: _SourceAwareImageResolver(),
              enableIme: false,
            ),
          ),
        ),
      );

      expect(find.text('network:https://cdn.example.com/hero.png'),
          findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
    });

    testWidgets('resolver returning null falls back to placeholder',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'img1', assetId: 'local', file: 'local.png'),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              // A resolver that declines every block.
              mediaResolver: _NullResolver(),
              enableIme: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('video resolver returning null falls back to placeholder',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(
              id: 'v1',
              assetId: 'clip-null',
              title: 'Null resolver clip',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              mediaResolver: _NullResolver(),
              enableIme: false,
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>('wenz-richtext-video-placeholder-v1'),
        ),
        findsOneWidget,
      );
      expect(find.text('Null resolver clip'), findsWidgets);
      expect(find.text('[video: clip-null]'), findsOneWidget);
    });

    testWidgets('no resolver: placeholder renders as before (regression)',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'img1', assetId: 'hero', file: 'hero.png'),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      // Empty placeholder (no resolver / resolver declines) renders the neutral
      // 简体中文 empty-state copy inside the shared figure chrome.
      expect(find.text('图片占位'), findsOneWidget);
      expect(find.text('插入后将在此显示图片'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-image-frame-img1')),
        findsOneWidget,
      );
    });

    testWidgets('default file renderer shows failure state', (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            FileBlockNode(
              id: 'f1',
              assetId: 'doc-1',
              name: 'report.pdf',
              size: 4096,
              mimeType: 'application/pdf',
              uploadStatus: FileUploadStatus.failed,
              uploadError: 'network timeout',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey<String>('wenz-richtext-file-card-f1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('wenz-richtext-file-size-f1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('wenz-richtext-file-meta-f1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('wenz-richtext-file-status-f1')),
          findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('4 KB'), findsOneWidget);
      expect(find.text('application/pdf'), findsOneWidget);
      expect(find.text('Upload failed · network timeout'), findsOneWidget);
    });

    testWidgets('default image renderer shows figure chrome and caption',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'img1',
              assetId: 'hero',
              file: 'hero.png',
              caption: 'Hero caption',
              altText: 'Hero alt',
              showWidth: 240,
              showHeight: 160,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-image-block-img1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-image-frame-img1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-image-size-img1')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.text('Hero caption'), findsOneWidget);
      final sizedBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey<String>('wenz-richtext-image-size-img1')),
      );
      expect(sizedBox.width, 240);
      expect(sizedBox.height, 160);
    });

    testWidgets(
        'image resolver custom empty and failed paths share finite frame',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'resolved', assetId: 'resolved-asset'),
            ImageBlockNode(id: 'empty', assetId: 'empty-asset'),
            ImageBlockNode(id: 'failed', assetId: 'failed-asset'),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 420,
                height: 900,
                child: WenzRichTextEditor(
                  controller: controller,
                  mediaResolver: const _MixedImageFrameResolver(),
                  padding: EdgeInsets.zero,
                  enableIme: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('resolver image'), findsOneWidget);
      expect(find.text('图片占位'), findsOneWidget);
      expect(find.text('图片加载失败'), findsOneWidget);
      expect(find.text('无法显示该图片，请重新上传'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('resolver-image-widget')),
        findsOneWidget,
      );

      _expectFiniteImageFrame(tester, 'resolved');
      _expectFiniteImageFrame(tester, 'empty');
      _expectFiniteImageFrame(tester, 'failed');

      final exception = tester.takeException();
      expect(exception, isA<StateError>());
      expect(exception.toString(), contains('resolver blew up'));
    });

    testWidgets('default video renderer shows title source cover and aspect',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(
              id: 'v1',
              assetId: 'clip-1',
              playbackUrl: 'https://cdn.example.test/clip.mp4',
              coverUrl: 'poster.png',
              title: 'Launch demo',
              description: 'Quarterly launch reel',
              aspectRatio: 2,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>('wenz-richtext-video-placeholder-v1'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('https://cdn.example.test/clip.mp4'),
        findsWidgets,
      );
      expect(
        find.text('[video: https://cdn.example.test/clip.mp4]'),
        findsOneWidget,
      );
      expect(find.text('Cover: poster.png'), findsOneWidget);

      final aspectRatio = tester.widget<AspectRatio>(
        find.byKey(
          const ValueKey<String>('wenz-richtext-video-aspect-v1'),
        ),
      );
      expect(aspectRatio.aspectRatio, 2);

      // The cover preview renders a play button whose icon is scaled by the
      // frame size and clamped to the design token (24px max).
      final playIcon = tester.widget<Icon>(
        find.byIcon(Icons.play_arrow_rounded),
      );
      expect(playIcon.size, isNotNull);
      expect(playIcon.size!, lessThanOrEqualTo(24));
    });

    testWidgets(
        'video preview uses square clipping while keeping resolver content finite',
        (tester) async {
      const previewKey = ValueKey<String>('resolver-preview-video-player');
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(
              id: 'v-preview',
              assetId: 'clip-preview',
              playbackUrl: 'https://cdn.example.test/preview.mp4',
              aspectRatio: 16 / 9,
            ),
          ],
        ),
        selection: _objectBlockSelection('v-preview', 0),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              mediaResolver: const _PreviewVideoResolver(previewKey),
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('预览媒体'));
      await tester.pumpAndSettle();

      final dialogFinder = find.byType(Dialog);
      expect(dialogFinder, findsOneWidget);
      final dialog = tester.widget<Dialog>(dialogFinder);
      expect(dialog.backgroundColor, Colors.black);
      expect(dialog.clipBehavior, Clip.hardEdge);
      final shape = dialog.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      final roundedShape = shape! as RoundedRectangleBorder;
      expect(roundedShape.borderRadius, BorderRadius.zero);
      expect(
        find.descendant(
          of: dialogFinder,
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
      );

      final previewFinder = find.descendant(
        of: dialogFinder,
        matching: find.byKey(previewKey),
      );
      expect(previewFinder, findsOneWidget);
      final previewSize = tester.getSize(previewFinder);
      expect(previewSize.width.isFinite, isTrue);
      expect(previewSize.height.isFinite, isTrue);
      expect(previewSize.width, greaterThan(0));
      expect(previewSize.height, greaterThan(0));
      expect(previewSize.width, lessThanOrEqualTo(720));
      expect(previewSize.height, lessThanOrEqualTo(560));
      expect(
        previewSize.width / previewSize.height,
        moreOrLessEquals(16 / 9, epsilon: 0.05),
      );
    });

    testWidgets('resolver also drives video and file blocks', (tester) async {
      final resolver = _RecordingResolver();
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(
              id: 'v1',
              assetId: 'clip-1',
              playbackUrl: 'https://cdn.example.test/clip-1.mp4',
            ),
            FileBlockNode(id: 'f1', assetId: 'doc-1', name: 'report.pdf'),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              mediaResolver: resolver,
              enableIme: false,
            ),
          ),
        ),
      );

      expect(find.text('resolved:clip-1'), findsOneWidget);
      expect(find.text('resolved:doc-1'), findsOneWidget);
      // Placeholders are replaced.
      expect(find.text('[video: clip-1]'), findsNothing);
      expect(find.text('[file: report.pdf]'), findsNothing);
      expect(
        resolver.seenVideos.single.playbackUrl,
        'https://cdn.example.test/clip-1.mp4',
      );
    });

    testWidgets('default block embed renderer shows fallback and formula',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            BlockEmbedNode(
              id: 'e1',
              embedType: 'custom',
              fallbackText: 'Fallback preview',
              data: <String, Object?>{
                'title': 'Payload title',
                'url': 'https://example.test/embed',
              },
            ),
            BlockEmbedNode(
              id: 'f1',
              embedType: 'formula',
              data: <String, Object?>{'text': 'x^2 + y^2'},
              fallbackText: 'x^2 + y^2',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-embed-card-e1')),
        findsOneWidget,
      );
      expect(find.text('CUSTOM'), findsOneWidget);
      expect(find.text('Fallback preview'), findsOneWidget);
      expect(find.text('title: Payload title'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-formula-card-f1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-formula-preview-f1')),
        findsOneWidget,
      );
      expect(find.text('x^2 + y^2'), findsWidgets);
    });

    testWidgets('a throwing resolver falls back to placeholder, no crash',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'img1', assetId: 'boom', file: 'boom.png'),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              mediaResolver: _ThrowingResolver(),
              enableIme: false,
            ),
          ),
        ),
      );

      // The editor caught the resolver error and rendered the placeholder.
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      // Catch-and-fallback renders the load-failure placeholder, visually
      // distinct from the neutral empty-state copy above.
      expect(find.text('图片加载失败'), findsOneWidget);
      expect(find.text('无法显示该图片，请重新上传'), findsOneWidget);
      expect(find.text('图片占位'), findsNothing);
      // The editor tree is still intact.
      expect(find.byType(WenzRichTextEditor), findsOneWidget);
      // The error was reported (not swallowed) so it surfaces in dev tools —
      // drain it so the test framework treats the caught-and-reported error as
      // expected rather than a failure.
      final exception = tester.takeException();
      expect(exception, isA<StateError>());
      expect(exception.toString(), contains('resolver blew up'));
    });

    testWidgets('a throwing video resolver falls back to placeholder',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(
              id: 'v1',
              assetId: 'boom-video',
              title: 'Broken clip',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              mediaResolver: _ThrowingResolver(),
              enableIme: false,
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>('wenz-richtext-video-placeholder-v1'),
        ),
        findsOneWidget,
      );
      // Catch-and-fallback renders the load-failure slot, so the cover-preview
      // metadata (source label, cover chip) and play button are suppressed.
      expect(find.text('[video: boom-video]'), findsNothing);
      expect(find.text('视频加载失败'), findsOneWidget);
      expect(find.text('无法播放该视频，请重新上传'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byType(WenzRichTextEditor), findsOneWidget);

      final exception = tester.takeException();
      expect(exception, isA<StateError>());
      expect(exception.toString(), contains('resolver blew up'));
    });

    testWidgets('resolver receives the full block including showWidth/Height',
        (tester) async {
      final resolver = _RecordingResolver();
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'img1',
              assetId: 'sized',
              file: 'sized.png',
              width: 640,
              height: 360,
              showWidth: 320,
              showHeight: 180,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              mediaResolver: resolver,
              enableIme: false,
            ),
          ),
        ),
      );

      final seen = resolver.seenImages.single;
      expect(seen.width, 640);
      expect(seen.height, 360);
      expect(seen.showWidth, 320);
      expect(seen.showHeight, 180);
    });

    testWidgets('image empty and failed placeholders render distinct copy',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'fine', assetId: 'fine-asset', file: 'fine.png'),
            ImageBlockNode(id: 'boom', assetId: 'boom-asset', file: 'boom.png'),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              // Throws only for the 'boom' block; declines the rest.
              mediaResolver: const _SelectiveThrowingResolver('boom'),
              enableIme: false,
            ),
          ),
        ),
      );

      // 'fine' declined (no widget, didn't throw) → neutral empty-state copy.
      expect(find.text('图片占位'), findsOneWidget);
      expect(find.text('插入后将在此显示图片'), findsOneWidget);
      // 'boom' threw → catch-and-fallback → load-failure copy.
      expect(find.text('图片加载失败'), findsOneWidget);
      expect(find.text('无法显示该图片，请重新上传'), findsOneWidget);
      // Both slots surface image_outlined for screen-reader parity; the empty
      // and failure states are distinguished by tone + copy, not by icon.
      expect(find.byIcon(Icons.image_outlined), findsNWidgets(2));
      expect(tester.takeException(), isA<StateError>());
    });

    testWidgets('video cover and failed placeholders render distinct chrome',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(id: 'fine', assetId: 'fine-video', title: 'Cover'),
            VideoBlockNode(id: 'boom', assetId: 'boom-video', title: 'Broken'),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              mediaResolver: const _SelectiveThrowingResolver('boom'),
              enableIme: false,
            ),
          ),
        ),
      );

      // 'fine' (no widget, didn't throw) → cover preview with a play button.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      // 'boom' threw → load-failure slot: failure copy + videocam_outlined, and
      // no play button (the cover preview is suppressed).
      expect(find.text('视频加载失败'), findsOneWidget);
      expect(find.text('无法播放该视频，请重新上传'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(tester.takeException(), isA<StateError>());
    });

    testWidgets('video frame normalizes unsafe aspect ratios',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(id: 'wide', assetId: 'w', aspectRatio: 10),
            VideoBlockNode(id: 'tall', assetId: 't', aspectRatio: 0.05),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );

      // _safeVideoAspectRatio clamps to [1/3, 4].
      final wideAspect = tester.widget<AspectRatio>(
        find.byKey(const ValueKey<String>('wenz-richtext-video-aspect-wide')),
      );
      expect(wideAspect.aspectRatio, 4);
      final tallAspect = tester.widget<AspectRatio>(
        find.byKey(const ValueKey<String>('wenz-richtext-video-aspect-tall')),
      );
      expect(tallAspect.aspectRatio, closeTo(1 / 3, 0.0001));

      // The clamped aspect drives the frame height: the wide frame is ~width/4
      // (not width/10), as long as that height stays inside the [96, 420] clamp.
      final wideFrame = tester.getRect(
        find.byKey(const ValueKey<String>('wenz-richtext-video-frame-wide')),
      );
      final expectedHeight = wideFrame.width / 4;
      if (expectedHeight >= 96 && expectedHeight <= 420) {
        expect(wideFrame.height, closeTo(expectedHeight, 1.0));
      }
    });

    test('controller exposes the injected mediaResolver', () {
      final resolver = _RecordingResolver();
      final controller = WenzRichTextController(
          document: const RichTextDocument(), mediaResolver: resolver);
      expect(controller.mediaResolver, same(resolver));
      controller.dispose();
    });
  });
}

DocumentSelection _objectBlockSelection(String blockId, int blockIndex) {
  final base = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(blockId),
    offset: 0,
  );
  final extent = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(blockId),
    offset: 1,
  );
  return DocumentSelection(base: base, extent: extent);
}

void _expectFiniteImageFrame(WidgetTester tester, String blockId) {
  final frameFinder = find.byKey(
    ValueKey<String>('wenz-richtext-image-frame-$blockId'),
  );
  final imageSizeFinder = find.byKey(
    ValueKey<String>('wenz-richtext-image-size-$blockId'),
  );
  expect(frameFinder, findsOneWidget);
  expect(imageSizeFinder, findsOneWidget);

  final frameSize = tester.getSize(frameFinder);
  final imageSize = tester.getSize(imageSizeFinder);
  expect(frameSize.width.isFinite, isTrue);
  expect(frameSize.height.isFinite, isTrue);
  expect(frameSize.width, greaterThan(0));
  expect(frameSize.height, greaterThan(0));
  expect(imageSize.width, moreOrLessEquals(frameSize.width, epsilon: 0.75));
  expect(imageSize.height, moreOrLessEquals(frameSize.height, epsilon: 0.75));
  expect(
    frameSize.height,
    moreOrLessEquals(frameSize.width / 2, epsilon: 1),
  );
}

/// Records the blocks it was asked to resolve and returns a deterministic
/// `Text('resolved:<assetId>')` for image/video/file blocks; declines
/// anything else.
class _RecordingResolver implements MediaResolver {
  final List<String> seenImageAssetIds = <String>[];
  final List<ImageBlockNode> seenImages = <ImageBlockNode>[];
  final List<VideoBlockNode> seenVideos = <VideoBlockNode>[];

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is ImageBlockNode) {
      seenImageAssetIds.add(block.assetId);
      seenImages.add(block);
      return Text('resolved:${block.assetId}');
    }
    if (block is VideoBlockNode) {
      seenVideos.add(block);
      return Text('resolved:${block.assetId}');
    }
    if (block is FileBlockNode) {
      return Text('resolved:${block.assetId}');
    }
    return null;
  }
}

class _SourceAwareImageResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is! ImageBlockNode) {
      return null;
    }
    final source = block.file.isNotEmpty ? block.file : block.assetId;
    if (source.isEmpty) {
      return null;
    }
    if (source.startsWith('http')) {
      return Text('network:$source');
    }
    return Text('local:$source');
  }
}

class _NullResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) => null;
}

class _PreviewVideoResolver implements MediaResolver {
  const _PreviewVideoResolver(this.key);

  final Key key;

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is! VideoBlockNode) {
      return null;
    }
    return ColoredBox(
      key: key,
      color: Colors.blue,
    );
  }
}

class _MixedImageFrameResolver implements MediaResolver {
  const _MixedImageFrameResolver();

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is! ImageBlockNode) {
      return null;
    }
    return switch (block.id) {
      'resolved' => const ColoredBox(
          key: ValueKey<String>('resolver-image-widget'),
          color: Colors.amber,
          child: Center(child: Text('resolver image')),
        ),
      'failed' => throw StateError('resolver blew up'),
      _ => null,
    };
  }
}

class _ThrowingResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    throw StateError('resolver blew up');
  }
}

/// A [MediaResolver] that throws for a single block (identified by
/// [throwForBlockId]) and declines (returns null) for every other block. Used
/// to render the empty and load-failure placeholders side by side in one tree,
/// proving the catch-and-fallback path is visually distinct from the empty slot.
class _SelectiveThrowingResolver implements MediaResolver {
  const _SelectiveThrowingResolver(this.throwForBlockId);

  final String throwForBlockId;

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block.id == throwForBlockId) {
      throw StateError('resolver blew up');
    }
    return null;
  }
}

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
      // over both empty-state and load-failure placeholder visuals.
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
      expect(find.text('Local image'), findsNothing);
      final image = controller.document.blocks.single as ImageBlockNode;
      expect(image.caption, 'Local image');
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Local image'), findsWidgets);
      semantics.dispose();
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

    testWidgets('network image source remains resolver driven', (tester) async {
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

    testWidgets('resolver image output fills intrinsic frames', (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'local',
              assetId: '',
              file: '/tmp/local-image.png',
              width: 300,
              height: 100,
            ),
            ImageBlockNode(
              id: 'network',
              assetId: 'https://cdn.example.com/network.png',
              width: 240,
              height: 120,
            ),
            ImageBlockNode(
              id: 'custom',
              assetId: 'custom-image',
              width: 120,
              height: 240,
            ),
            ImageBlockNode(id: 'legacy', assetId: 'legacy-unsized'),
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
                  mediaResolver: const _FrameFillingImageResolver(),
                  padding: EdgeInsets.zero,
                  enableIme: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      _expectResolverImageFillsFrame(
        tester,
        'local',
        expectedAspectRatio: 3,
      );
      _expectResolverImageFillsFrame(
        tester,
        'network',
        expectedAspectRatio: 2,
      );
      _expectResolverImageFillsFrame(
        tester,
        'custom',
        expectedAspectRatio: 0.5,
      );
      _expectFiniteImageFrame(tester, 'legacy');
      expect(
        find.byKey(const ValueKey<String>('resolver-frame-image-legacy')),
        findsNothing,
      );
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets(
        'resolver image widgets stay inside one frame across fill oversized tiny and image-like content',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'fill',
              assetId: 'fill-image',
              width: 300,
              height: 150,
            ),
            ImageBlockNode(
              id: 'oversized',
              assetId: 'oversized-image',
              width: 280,
              height: 140,
            ),
            ImageBlockNode(
              id: 'tiny',
              assetId: 'tiny-image',
              width: 320,
              height: 160,
            ),
            ImageBlockNode(
              id: 'imageLike',
              assetId: 'image-like',
              showWidth: 180,
              showHeight: 120,
            ),
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
                  mediaResolver: const _DiverseImageFrameResolver(),
                  padding: EdgeInsets.zero,
                  enableIme: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      _expectResolverHostMatchesFrame(
        tester,
        'fill',
        expectedAspectRatio: 2,
      );
      _expectResolverHostMatchesFrame(
        tester,
        'oversized',
        expectedAspectRatio: 2,
      );
      _expectResolverHostMatchesFrame(
        tester,
        'tiny',
        expectedAspectRatio: 2,
      );
      _expectResolverHostMatchesFrame(
        tester,
        'imageLike',
        expectedAspectRatio: 1.5,
      );

      final oversizedFrameRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('wenz-richtext-image-frame-oversized'),
        ),
      );
      final oversizedLeafRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('resolver-leaf-image-oversized'),
        ),
      );
      expect(oversizedLeafRect.left, lessThan(oversizedFrameRect.left));
      expect(oversizedLeafRect.top, lessThan(oversizedFrameRect.top));
      expect(oversizedLeafRect.right, greaterThan(oversizedFrameRect.right));
      expect(
        oversizedLeafRect.bottom,
        greaterThan(oversizedFrameRect.bottom),
      );

      final tinyFrameRect = tester.getRect(
        find.byKey(const ValueKey<String>('wenz-richtext-image-frame-tiny')),
      );
      final tinyLeafRect = tester.getRect(
        find.byKey(const ValueKey<String>('resolver-leaf-image-tiny')),
      );
      _expectRectWithin(tinyLeafRect, tinyFrameRect, epsilon: 0.75);

      expect(tester.takeException(), isNull);
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
        selection: _objectBlockSelection('v1', 0),
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
      final inlineDecoration = tester
          .widget<DecoratedBox>(
            find.byKey(
              const ValueKey<String>('wenz-richtext-video-placeholder-v1'),
            ),
          )
          .decoration as BoxDecoration;
      expect(inlineDecoration.borderRadius, isNotNull);
      expect(inlineDecoration.boxShadow, isNotEmpty);

      await tester.pump();
      await tester.tap(find.byTooltip('预览媒体'));
      await tester.pumpAndSettle();

      final surface = find.byKey(
        const ValueKey<String>(
          'wenz-richtext-video-fullscreen-surface-v1',
        ),
      );
      final frame = find.byKey(
        const ValueKey<String>(
          'wenz-richtext-video-fullscreen-frame-v1',
        ),
      );
      expect(surface, findsOneWidget);
      expect(frame, findsOneWidget);
      final frameRect = tester.getRect(frame);
      expect(frameRect.width.isFinite, isTrue);
      expect(frameRect.height.isFinite, isTrue);
      expect(frameRect.width, greaterThan(0));
      expect(frameRect.height, greaterThan(0));
      _expectRectClose(frameRect, tester.getRect(surface));
      expect(
        find.descendant(of: surface, matching: find.byType(ClipRRect)),
        findsNothing,
      );
      final fullscreenPlaceholder = find.descendant(
        of: surface,
        matching: find.byKey(
          const ValueKey<String>('wenz-richtext-video-placeholder-v1'),
        ),
      );
      final fullscreenDecoration = tester
          .widget<DecoratedBox>(fullscreenPlaceholder)
          .decoration as BoxDecoration;
      expect(fullscreenDecoration.borderRadius, isNull);
      expect(fullscreenDecoration.boxShadow, isNull);
      expect(find.text('[video: clip-null]'), findsNWidgets(2));

      await tester.tap(find.byTooltip('关闭视频预览'));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
    });

    testWidgets('no resolver: placeholder hides visible copy', (tester) async {
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
      // Empty placeholder (no resolver / resolver declines) keeps only the
      // neutral image visual inside the shared figure chrome.
      expect(find.text('图片占位'), findsNothing);
      expect(find.text('插入后将在此显示图片'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-image-frame-img1')),
        findsOneWidget,
      );
    });

    testWidgets('image placeholder hides visible copy', (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'img1',
              assetId: 'hero',
              file: 'hero.png',
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

      expect(find.text('图片上传中'), findsNothing);
      expect(find.text('正在处理，请稍候…'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-image-frame-img1')),
        findsOneWidget,
      );
      final placeholderVisualCount =
          find.byIcon(Icons.image_outlined).evaluate().length +
              find.byType(CircularProgressIndicator).evaluate().length;
      expect(placeholderVisualCount, greaterThanOrEqualTo(1));
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

    testWidgets('default image renderer hides caption text but keeps metadata',
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
      expect(find.text('Hero caption'), findsNothing);
      final image = controller.document.blocks.single as ImageBlockNode;
      expect(image.caption, 'Hero caption');
      expect(image.altText, 'Hero alt');
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Hero alt'), findsWidgets);
      semantics.dispose();
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
            ImageBlockNode(
              id: 'resolved',
              assetId: 'resolved-asset',
              width: 300,
              height: 100,
            ),
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
      expect(find.text('图片占位'), findsNothing);
      expect(find.text('图片加载失败'), findsNothing);
      expect(find.text('无法显示该图片，请重新上传'), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey<String>('resolver-image-widget')),
        findsOneWidget,
      );

      _expectFiniteImageFrame(
        tester,
        'resolved',
        expectedAspectRatio: 3,
      );
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
              showWidth: 320,
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
      final frameRect = tester.getRect(
        find.byKey(const ValueKey<String>('wenz-richtext-video-frame-v1')),
      );
      expect(frameRect.width, moreOrLessEquals(320, epsilon: 0.75));
      expect(frameRect.height, moreOrLessEquals(160, epsilon: 0.75));
      final placeholderRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('wenz-richtext-video-placeholder-v1'),
        ),
      );
      expect(placeholderRect.left, greaterThanOrEqualTo(frameRect.left));
      expect(placeholderRect.right, lessThanOrEqualTo(frameRect.right));
      expect(placeholderRect.top, greaterThanOrEqualTo(frameRect.top));
      expect(placeholderRect.bottom, lessThanOrEqualTo(frameRect.bottom));

      // The cover preview renders a play button whose icon is scaled by the
      // frame size and clamped to the design token (24px max).
      final playIcon = tester.widget<Icon>(
        find.byIcon(Icons.play_arrow_rounded),
      );
      expect(playIcon.size, isNotNull);
      expect(playIcon.size!, lessThanOrEqualTo(24));
    });

    testWidgets(
        'video preview fills viewport with tight finite square-corner frame',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const previewKey = ValueKey<String>('resolver-preview-video-player');
      final resolver = _PreviewVideoResolver(previewKey);
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
              mediaResolver: resolver,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('预览媒体'));
      await tester.pumpAndSettle();

      final surfaceFinder = find.byKey(
        const ValueKey<String>(
          'wenz-richtext-video-fullscreen-surface-v-preview',
        ),
      );
      final viewportFinder = find.byKey(
        const ValueKey<String>(
          'wenz-richtext-video-fullscreen-viewport-v-preview',
        ),
      );
      final frameFinder = find.byKey(
        const ValueKey<String>(
          'wenz-richtext-video-fullscreen-frame-v-preview',
        ),
      );
      expect(surfaceFinder, findsOneWidget);
      expect(viewportFinder, findsOneWidget);
      expect(frameFinder, findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      const viewportRect = Rect.fromLTWH(0, 0, 1000, 700);
      expect(tester.getRect(surfaceFinder), viewportRect);
      expect(tester.getRect(viewportFinder), viewportRect);
      expect(tester.getRect(frameFinder), viewportRect);
      expect(
        tester.widget<Material>(surfaceFinder).color,
        Colors.black,
      );
      expect(
        find.descendant(
          of: surfaceFinder,
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
      );

      final previewFinder = find.descendant(
        of: surfaceFinder,
        matching: find.byKey(previewKey),
      );
      expect(previewFinder, findsOneWidget);
      expect(tester.getRect(previewFinder), tester.getRect(frameFinder));
      final previewSize = tester.getSize(previewFinder);
      expect(previewSize.width.isFinite, isTrue);
      expect(previewSize.height.isFinite, isTrue);
      expect(previewSize.width, greaterThan(0));
      expect(previewSize.height, greaterThan(0));
      expect(previewSize, const Size(1000, 700));
      expect(resolver.fullscreenConstraints, isNotNull);
      final fullscreenConstraints = resolver.fullscreenConstraints!;
      expect(fullscreenConstraints.isTight, isTrue);
      expect(fullscreenConstraints.biggest, const Size(1000, 700));
      expect(find.byTooltip('关闭视频预览'), findsOneWidget);

      await tester.tap(find.byTooltip('关闭视频预览'));
      await tester.pumpAndSettle();
      expect(surfaceFinder, findsNothing);
    });

    testWidgets('video resolver scope distinguishes inline and dialog entries',
        (tester) async {
      final resolver = _VideoEntryRecordingResolver();
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(
              id: 'v-entry',
              assetId: 'clip-entry',
              playbackUrl: 'https://cdn.example.test/entry.mp4',
              aspectRatio: 16 / 9,
            ),
          ],
        ),
        selection: _objectBlockSelection('v-entry', 0),
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
      await tester.pump();

      expect(
        resolver.entries,
        contains(WenzRichTextVideoMediaResolveEntry.inline),
      );
      expect(
        resolver.entries,
        isNot(contains(WenzRichTextVideoMediaResolveEntry.dialog)),
      );
      expect(
        find.byKey(const ValueKey<String>('resolver-video-inline-v-entry')),
        findsOneWidget,
      );
      expect(resolver.inlinePlayerKeys, hasLength(1));
      expect(resolver.dialogPlayerKeys, isEmpty);
      final inlinePlayerKey = resolver.inlinePlayerKeys.single;
      final inlinePlayerState = inlinePlayerKey.currentState;
      expect(inlinePlayerState, isNotNull);

      await tester.tap(find.byTooltip('预览媒体'));
      await tester.pumpAndSettle();

      expect(
        resolver.entries,
        contains(WenzRichTextVideoMediaResolveEntry.dialog),
      );
      final fullscreenFinder = find.byKey(
        const ValueKey<String>(
          'wenz-richtext-video-fullscreen-surface-v-entry',
        ),
      );
      expect(fullscreenFinder, findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(
        find.descendant(
          of: fullscreenFinder,
          matching: find.byKey(
            const ValueKey<String>('resolver-video-dialog-v-entry'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('resolver-video-inline-v-entry')),
        findsOneWidget,
      );
      expect(resolver.inlinePlayerKeys, hasLength(1));
      expect(resolver.dialogPlayerKeys, hasLength(1));
      final dialogPlayerKey = resolver.dialogPlayerKeys.single;
      expect(dialogPlayerKey, isNot(same(inlinePlayerKey)));
      expect(inlinePlayerKey.currentState, same(inlinePlayerState));
      expect(dialogPlayerKey.currentState, isNotNull);
      expect(dialogPlayerKey.currentState, isNot(same(inlinePlayerState)));
    });

    testWidgets(
        'fullscreen handoff creates one dialog resolver session per route',
        (tester) async {
      final resolver = _VideoEntryRecordingResolver();
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(
              id: 'v-guarded',
              assetId: 'clip-guarded',
              playbackUrl: 'https://cdn.example.test/guarded.mp4',
            ),
          ],
        ),
        selection: _objectBlockSelection('v-guarded', 0),
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
      await tester.pump();
      await tester.pump();

      final inlinePlayerKey = resolver.inlinePlayerKeys.single;
      final inlinePlayerState = inlinePlayerKey.currentState;
      final previewButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.open_in_full),
      );
      final openPreview = previewButton.onPressed!;
      openPreview();
      openPreview();
      await tester.pumpAndSettle();

      final surface = find.byKey(
        const ValueKey<String>(
          'wenz-richtext-video-fullscreen-surface-v-guarded',
        ),
      );
      expect(surface, findsOneWidget);
      expect(resolver.dialogPlayerKeys, hasLength(1));
      final firstDialogPlayerKey = resolver.dialogPlayerKeys.single;
      expect(firstDialogPlayerKey.currentState, isNotNull);
      expect(inlinePlayerKey.currentState, same(inlinePlayerState));

      openPreview();
      await tester.pump();
      expect(surface, findsOneWidget);
      expect(resolver.dialogPlayerKeys, hasLength(1));

      await tester.tap(find.byTooltip('关闭视频预览'));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(firstDialogPlayerKey.currentState, isNull);
      expect(inlinePlayerKey.currentState, same(inlinePlayerState));
      expect(find.byTooltip('预览媒体'), findsOneWidget);

      await tester.tap(find.byTooltip('预览媒体'));
      await tester.pumpAndSettle();
      expect(surface, findsOneWidget);
      expect(resolver.dialogPlayerKeys, hasLength(2));
      expect(resolver.dialogPlayerKeys.last.currentState, isNotNull);
      expect(resolver.dialogPlayerKeys.last, isNot(same(firstDialogPlayerKey)));
      expect(inlinePlayerKey.currentState, same(inlinePlayerState));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(find.byTooltip('预览媒体'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
      // distinct from the neutral empty-state above, without visible copy.
      expect(find.text('图片加载失败'), findsNothing);
      expect(find.text('无法显示该图片，请重新上传'), findsNothing);
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
        selection: _objectBlockSelection('v1', 0),
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

      await tester.pump();
      await tester.tap(find.byTooltip('预览媒体'));
      await tester.pumpAndSettle();

      final surface = find.byKey(
        const ValueKey<String>(
          'wenz-richtext-video-fullscreen-surface-v1',
        ),
      );
      final frame = find.byKey(
        const ValueKey<String>(
          'wenz-richtext-video-fullscreen-frame-v1',
        ),
      );
      expect(surface, findsOneWidget);
      expect(frame, findsOneWidget);
      expect(find.text('视频加载失败'), findsNWidgets(2));
      final frameRect = tester.getRect(frame);
      expect(frameRect.width, greaterThan(0));
      expect(frameRect.height, greaterThan(0));
      expect(frameRect.width.isFinite, isTrue);
      expect(frameRect.height.isFinite, isTrue);
      _expectRectClose(frameRect, tester.getRect(surface));
      expect(
        find.descendant(of: surface, matching: find.byType(ClipRRect)),
        findsNothing,
      );
      final fullscreenPlaceholder = find.descendant(
        of: surface,
        matching: find.byKey(
          const ValueKey<String>('wenz-richtext-video-placeholder-v1'),
        ),
      );
      final fullscreenDecoration = tester
          .widget<DecoratedBox>(fullscreenPlaceholder)
          .decoration as BoxDecoration;
      expect(fullscreenDecoration.borderRadius, isNull);
      expect(fullscreenDecoration.boxShadow, isNull);

      final previewException = tester.takeException();
      expect(previewException, isA<StateError>());
      expect(previewException.toString(), contains('resolver blew up'));

      await tester.tap(find.byTooltip('关闭视频预览'));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
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
              caption: 'Sized caption',
              altText: 'Sized alt',
              width: 640,
              height: 360,
              showWidth: 320,
              showHeight: 180,
            ),
            VideoBlockNode(
              id: 'v-sized',
              assetId: 'sized-video',
              playbackUrl: 'https://cdn.example.test/sized.mp4',
              aspectRatio: 5 / 3,
              showWidth: 300,
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
      expect(seen.caption, 'Sized caption');
      expect(seen.altText, 'Sized alt');
      expect(seen.showWidth, 320);
      expect(seen.showHeight, 180);
      final seenVideo = resolver.seenVideos.single;
      expect(seenVideo.playbackUrl, 'https://cdn.example.test/sized.mp4');
      expect(seenVideo.aspectRatio, 5 / 3);
      expect(seenVideo.showWidth, 300);
      expect(seenVideo.showHeight, 180);
      final videoFrameRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('wenz-richtext-video-frame-v-sized'),
        ),
      );
      expect(videoFrameRect.width, moreOrLessEquals(300, epsilon: 0.75));
      expect(videoFrameRect.height, moreOrLessEquals(180, epsilon: 0.75));
      final resolverTextRect = tester.getRect(
        find.text('resolved:sized-video'),
      );
      expect(resolverTextRect.left, greaterThanOrEqualTo(videoFrameRect.left));
      expect(resolverTextRect.right, lessThanOrEqualTo(videoFrameRect.right));
      expect(resolverTextRect.top, greaterThanOrEqualTo(videoFrameRect.top));
      expect(resolverTextRect.bottom, lessThanOrEqualTo(videoFrameRect.bottom));
    });

    testWidgets('image empty and failed placeholders hide visible copy',
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

      // 'fine' declined (no widget, didn't throw) → neutral empty-state visual.
      expect(find.text('图片占位'), findsNothing);
      expect(find.text('插入后将在此显示图片'), findsNothing);
      // 'boom' threw → catch-and-fallback → load-failure visual.
      expect(find.text('图片加载失败'), findsNothing);
      expect(find.text('无法显示该图片，请重新上传'), findsNothing);
      // Both slots surface image_outlined for screen-reader parity; the empty
      // and failure states are distinguished by tone, not visible copy.
      final imageIcons = tester
          .widgetList<Icon>(
            find.byIcon(Icons.image_outlined),
          )
          .toList();
      expect(imageIcons, hasLength(2));
      expect(imageIcons.map((icon) => icon.color).toSet(), hasLength(2));
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

    testWidgets('video frame normalizes unsafe aspect ratios', (tester) async {
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

void _expectFiniteImageFrame(
  WidgetTester tester,
  String blockId, {
  double expectedAspectRatio = 2,
}) {
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
    moreOrLessEquals(frameSize.width / expectedAspectRatio, epsilon: 1),
  );
}

void _expectResolverImageFillsFrame(
  WidgetTester tester,
  String blockId, {
  required double expectedAspectRatio,
}) {
  _expectFiniteImageFrame(
    tester,
    blockId,
    expectedAspectRatio: expectedAspectRatio,
  );
  final frameRect = tester.getRect(
    find.byKey(ValueKey<String>('wenz-richtext-image-frame-$blockId')),
  );
  final resolverRect = tester.getRect(
    find.byKey(ValueKey<String>('resolver-frame-image-$blockId')),
  );
  _expectRectClose(resolverRect, frameRect, epsilon: 0.75);
}

void _expectResolverHostMatchesFrame(
  WidgetTester tester,
  String blockId, {
  required double expectedAspectRatio,
}) {
  _expectFiniteImageFrame(
    tester,
    blockId,
    expectedAspectRatio: expectedAspectRatio,
  );
  final frameRect = tester.getRect(
    find.byKey(ValueKey<String>('wenz-richtext-image-frame-$blockId')),
  );
  final hostRect = tester.getRect(
    find.byKey(ValueKey<String>('resolver-host-image-$blockId')),
  );
  _expectRectClose(hostRect, frameRect, epsilon: 0.75);
}

void _expectRectClose(Rect actual, Rect expected, {double epsilon = 0.001}) {
  expect(actual.left, moreOrLessEquals(expected.left, epsilon: epsilon));
  expect(actual.top, moreOrLessEquals(expected.top, epsilon: epsilon));
  expect(actual.right, moreOrLessEquals(expected.right, epsilon: epsilon));
  expect(actual.bottom, moreOrLessEquals(expected.bottom, epsilon: epsilon));
}

void _expectRectWithin(Rect actual, Rect expected, {double epsilon = 0.001}) {
  expect(actual.left, greaterThanOrEqualTo(expected.left - epsilon));
  expect(actual.top, greaterThanOrEqualTo(expected.top - epsilon));
  expect(actual.right, lessThanOrEqualTo(expected.right + epsilon));
  expect(actual.bottom, lessThanOrEqualTo(expected.bottom + epsilon));
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

class _FrameFillingImageResolver implements MediaResolver {
  const _FrameFillingImageResolver();

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is! ImageBlockNode) {
      return null;
    }
    final source = block.file.isNotEmpty ? block.file : block.assetId;
    final shouldResolve = source.startsWith('/tmp/') ||
        source.startsWith('https://') ||
        source == 'custom-image';
    if (!shouldResolve) {
      return null;
    }
    return SizedBox.expand(
      key: ValueKey<String>('resolver-frame-image-${block.id}'),
      child: const ColoredBox(color: Colors.teal),
    );
  }
}

class _NullResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) => null;
}

class _VideoEntryRecordingResolver implements MediaResolver {
  final List<WenzRichTextVideoMediaResolveEntry?> entries =
      <WenzRichTextVideoMediaResolveEntry?>[];
  final List<GlobalKey<_VideoEntryPlayerState>> inlinePlayerKeys =
      <GlobalKey<_VideoEntryPlayerState>>[];
  final List<GlobalKey<_VideoEntryPlayerState>> dialogPlayerKeys =
      <GlobalKey<_VideoEntryPlayerState>>[];

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is! VideoBlockNode) {
      return null;
    }
    final entry = WenzRichTextMediaResolveScope.maybeVideoEntryOf(context);
    entries.add(entry);
    final label = switch (entry) {
      WenzRichTextVideoMediaResolveEntry.inline => 'inline',
      WenzRichTextVideoMediaResolveEntry.dialog => 'dialog',
      null => 'none',
    };
    final playerKey = GlobalKey<_VideoEntryPlayerState>(
      debugLabel: 'resolver-video-$label-${block.id}',
    );
    if (entry == WenzRichTextVideoMediaResolveEntry.inline) {
      inlinePlayerKeys.add(playerKey);
    } else if (entry == WenzRichTextVideoMediaResolveEntry.dialog) {
      dialogPlayerKeys.add(playerKey);
    }
    return _VideoEntryPlayer(
      key: playerKey,
      contentKey: ValueKey<String>('resolver-video-$label-${block.id}'),
      color: entry == WenzRichTextVideoMediaResolveEntry.dialog
          ? Colors.green
          : Colors.blue,
    );
  }
}

class _VideoEntryPlayer extends StatefulWidget {
  const _VideoEntryPlayer({
    super.key,
    required this.contentKey,
    required this.color,
  });

  final Key contentKey;
  final Color color;

  @override
  State<_VideoEntryPlayer> createState() => _VideoEntryPlayerState();
}

class _VideoEntryPlayerState extends State<_VideoEntryPlayer> {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: widget.contentKey,
      color: widget.color,
    );
  }
}

class _PreviewVideoResolver implements MediaResolver {
  _PreviewVideoResolver(this.key);

  final Key key;
  BoxConstraints? fullscreenConstraints;

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is! VideoBlockNode) {
      return null;
    }
    final entry = WenzRichTextMediaResolveScope.maybeVideoEntryOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (entry == WenzRichTextVideoMediaResolveEntry.dialog) {
          fullscreenConstraints = constraints;
        }
        return ColoredBox(
          key: key,
          color: Colors.blue,
        );
      },
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

class _DiverseImageFrameResolver implements MediaResolver {
  const _DiverseImageFrameResolver();

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is! ImageBlockNode) {
      return null;
    }
    return switch (block.id) {
      'fill' => const SizedBox.expand(
          key: ValueKey<String>('resolver-host-image-fill'),
          child: ColoredBox(color: Colors.teal),
        ),
      'oversized' => const SizedBox.expand(
          key: ValueKey<String>('resolver-host-image-oversized'),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: ValueKey<String>('resolver-leaf-image-oversized'),
              width: 1200,
              height: 900,
              child: ColoredBox(color: Colors.orange),
            ),
          ),
        ),
      'tiny' => const SizedBox.expand(
          key: ValueKey<String>('resolver-host-image-tiny'),
          child: Center(
            child: SizedBox(
              key: ValueKey<String>('resolver-leaf-image-tiny'),
              width: 24,
              height: 16,
              child: ColoredBox(color: Colors.pink),
            ),
          ),
        ),
      'imageLike' => const SizedBox.expand(
          key: ValueKey<String>('resolver-host-image-imageLike'),
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 360,
              height: 240,
              child: ColoredBox(color: Colors.indigo),
            ),
          ),
        ),
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

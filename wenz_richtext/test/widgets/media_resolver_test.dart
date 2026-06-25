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
      // Placeholder is NOT rendered for this block.
      expect(find.text('[image: a.png]'), findsNothing);
      // The resolver received the right block with its fields intact.
      expect(resolver.seenImageAssetIds, ['resolved-id']);
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
      expect(find.text('Launch demo'), findsWidgets);
      expect(
        find.text('[video: https://cdn.example.test/clip.mp4]'),
        findsOneWidget,
      );
      expect(find.text('Quarterly launch reel'), findsOneWidget);
      expect(find.text('Cover: poster.png'), findsOneWidget);

      final aspectRatio = tester.widget<AspectRatio>(
        find.byKey(
          const ValueKey<String>('wenz-richtext-video-aspect-v1'),
        ),
      );
      expect(aspectRatio.aspectRatio, 2);
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
      expect(find.text('[video: boom-video]'), findsOneWidget);
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

    test('controller exposes the injected mediaResolver', () {
      final resolver = _RecordingResolver();
      final controller = WenzRichTextController(
          document: const RichTextDocument(), mediaResolver: resolver);
      expect(controller.mediaResolver, same(resolver));
      controller.dispose();
    });
  });
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

class _NullResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) => null;
}

class _ThrowingResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    throw StateError('resolver blew up');
  }
}

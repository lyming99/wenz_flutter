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

      expect(find.text('[image: local.png]'), findsOneWidget);
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

      expect(find.text('[image: hero.png]'), findsOneWidget);
    });

    testWidgets('default file renderer shows metadata and upload failure',
        (tester) async {
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

      expect(find.text('report.pdf'), findsOneWidget);
      expect(
          find.text('4 KB · application/pdf · Upload failed'), findsOneWidget);
      expect(find.text('network timeout'), findsOneWidget);
    });

    testWidgets('default image renderer shows caption', (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'img1',
              assetId: 'hero',
              file: 'hero.png',
              caption: 'Hero caption',
              altText: 'Hero alt',
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

      expect(find.text('[image: hero.png]'), findsOneWidget);
      expect(find.text('Hero caption'), findsOneWidget);
    });

    testWidgets('resolver also drives video and file blocks', (tester) async {
      final resolver = _RecordingResolver();
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(id: 'v1', assetId: 'clip-1'),
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
      expect(find.text('[image: boom.png]'), findsOneWidget);
      // The editor tree is still intact.
      expect(find.byType(WenzRichTextEditor), findsOneWidget);
      // The error was reported (not swallowed) so it surfaces in dev tools —
      // drain it so the test framework treats the caught-and-reported error as
      // expected rather than a failure.
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

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is ImageBlockNode) {
      seenImageAssetIds.add(block.assetId);
      seenImages.add(block);
      return Text('resolved:${block.assetId}');
    }
    if (block is VideoBlockNode) {
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

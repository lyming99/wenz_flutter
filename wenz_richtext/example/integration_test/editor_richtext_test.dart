import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'helpers/expect_helpers.dart';
import 'helpers/keyboard_helpers.dart';
import 'helpers/pointer_helpers.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('rich text formatting & history', () {
    testWidgets('Bold toolbar button bolds the selected run', (tester) async {
      await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'hello')],
            ),
          ],
        ),
      );

      await dragInsideText(tester, 'hello', fromOffset: 0, toOffset: 5);
      await tester.tap(find.byTooltip('加粗'));
      await tester.pump();

      // The whole run "hello" is now bold.
      final style = styleOfRun(tester, 'hello', 'hello');
      expect(style?.fontWeight, FontWeight.w700);
    });

    testWidgets('Italic toolbar button italicises the selected run', (
      tester,
    ) async {
      await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'hello')],
            ),
          ],
        ),
      );

      await dragInsideText(tester, 'hello', fromOffset: 0, toOffset: 5);
      await tester.tap(find.byTooltip('斜体'));
      await tester.pump();

      final style = styleOfRun(tester, 'hello', 'hello');
      expect(style?.fontStyle, FontStyle.italic);
    });

    testWidgets('Heading toolbar button switches block type', (tester) async {
      await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Title')],
            ),
          ],
        ),
      );

      // Place the caret anywhere in the block to give it block-type context.
      await tapAtTextOffset(tester, 'Title', 2);
      await tester.tap(find.byTooltip('标题'));
      await tester.pump();

      // Heading level 1 renders at fontSize 24 with bold weight.
      final style = richTextStyle(tester, 'Title');
      expect(style?.fontSize, 24);
      expect(style?.fontWeight, FontWeight.w700);
    });

    testWidgets('Ctrl+Z undoes a typed insertion', (tester) async {
      final workbench = await pumpWorkbench(tester);
      final controller = workbench.controller;

      await typeText(tester, controller, 'abc');
      expect(controller.document.plainText, 'abc');
      expect(controller.canUndo, isTrue);

      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyZ);
      // One coalesced undo step reverts the whole typed run.
      expect(controller.document.plainText, '');
    });

    testWidgets('Ctrl+Shift+Z redoes the undone insertion', (tester) async {
      final workbench = await pumpWorkbench(tester);
      final controller = workbench.controller;

      await typeText(tester, controller, 'abc');
      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(controller.document.plainText, '');

      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(controller.document.plainText, 'abc');
    });

    testWidgets('copy and paste duplicate the selection', (tester) async {
      // Start with "abc", select it, copy, move caret to end, paste.
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abc')],
            ),
          ],
        ),
      );
      final controller = workbench.controller;

      await dragInsideText(tester, 'abc', fromOffset: 0, toOffset: 3);

      // Ctrl+C copies the rich payload into the clipboard.
      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();

      // Collapse the caret to the end of the block (a non-collapsed selection
      // would be replaced on paste, yielding "abc" instead of "abcabc").
      await tapAtTextOffset(tester, 'abc', 3);

      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();

      expect(controller.document.plainText, 'abcabc');
      expect(richTextWith('abcabc'), findsOneWidget);
    });

    testWidgets('video insert, select, copy paste, and import export', (
      tester,
    ) async {
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Intro')],
            ),
          ],
        ),
      );
      final controller = workbench.controller;

      controller.insertVideo(
        index: 1,
        blockId: 'video1',
        assetId: 'video-asset',
        playbackUrl: 'https://cdn.example.com/video.mp4',
        file: 'local/video.mp4',
        coverUrl: 'https://cdn.example.com/cover.jpg',
        title: 'Launch clip',
        description: 'Product launch overview',
        aspectRatio: 16 / 9,
        uploadStatus: FileUploadStatus.uploaded,
      );
      await tester.pumpAndSettle();

      expect(_videoBlockFinder('video1'), findsOneWidget);
      expect(_videoBlocks(controller), hasLength(1));
      _expectVideoMetadata(_videoBlocks(controller).single);

      await tester.tapAt(tester.getCenter(_videoBlockFinder('video1')));
      await tester.pump();

      final selected = controller.selection;
      expect(selected, isNotNull);
      expect(selected!.isCollapsed, isFalse);
      expect(selected.start.blockId, 'video1');
      expect(selected.start.path.isBlockObject, isTrue);
      expect(selected.end.blockId, 'video1');
      expect(selected.end.offset, 1);

      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();

      workbench.placeCaretAt('p1', 0, 'Intro'.length);
      await tester.pump();

      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();

      _expectDuplicatedVideos(controller);

      final jsonExport = controller.toJson();
      final markdownExport = controller.toMarkdown();
      final htmlExport = controller.toHtml();
      expect(jsonExport, contains('"type":"video"'));
      expect(markdownExport, contains('wenz-video'));
      expect(htmlExport, contains('data-wenz-block="video"'));

      controller.loadJson(jsonExport);
      await tester.pumpAndSettle();
      _expectDuplicatedVideos(controller);

      controller.loadMarkdown(markdownExport);
      await tester.pumpAndSettle();
      _expectDuplicatedVideos(controller);

      controller.loadHtml(htmlExport);
      await tester.pumpAndSettle();
      _expectDuplicatedVideos(controller);
    });
  });
}

Finder _videoBlockFinder(String blockId) {
  return find.byKey(ValueKey<String>('wenz-richtext-video-block-$blockId'));
}

List<VideoBlockNode> _videoBlocks(WenzRichTextController controller) {
  return controller.document.blocks.whereType<VideoBlockNode>().toList(
    growable: false,
  );
}

void _expectDuplicatedVideos(WenzRichTextController controller) {
  final videos = _videoBlocks(controller);
  expect(videos, hasLength(2));
  for (final video in videos) {
    _expectVideoMetadata(video);
  }
}

void _expectVideoMetadata(VideoBlockNode video) {
  expect(video.assetId, 'video-asset');
  expect(video.playbackUrl, 'https://cdn.example.com/video.mp4');
  expect(video.file, 'local/video.mp4');
  expect(video.coverUrl, 'https://cdn.example.com/cover.jpg');
  expect(video.title, 'Launch clip');
  expect(video.description, 'Product launch overview');
  expect(video.aspectRatio, 16 / 9);
  expect(video.uploadStatus, FileUploadStatus.uploaded);
}

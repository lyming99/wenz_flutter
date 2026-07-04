import 'dart:async';
import 'dart:io';

// ignore_for_file: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';
import 'package:wenz_richtext_example/main.dart';

const _expectedExampleFontFamily = '微软雅黑';

const List<int> _tinyPngBytes = <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0a,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
];

void main() {
  testWidgets('renders editor workbench', (tester) async {
    await _pumpWorkbench(tester);

    expect(find.text('Wenz RichText'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);
    expect(find.byIcon(Icons.format_bold), findsOneWidget);
    expect(find.byIcon(Icons.table_chart), findsOneWidget);
  });

  testWidgets('uses Microsoft YaHei as the default example font',
      (tester) async {
    await _pumpWorkbench(tester);

    final editorFinder = find.byType(WenzRichTextEditor);
    final editorContext = tester.element(editorFinder);
    final theme = Theme.of(editorContext);
    final editor = tester.widget<WenzRichTextEditor>(editorFinder);

    expect(theme.textTheme.bodyLarge?.fontFamily, _expectedExampleFontFamily);
    expect(editor.textStyle?.fontFamily, _expectedExampleFontFamily);
    expect(editor.enableExternalImageInput, isTrue);
  });

  testWidgets('mention search insert and details dialog are wired',
      (tester) async {
    await _pumpWorkbench(tester);
    var editor = tester.widget<WenzRichTextEditor>(
      find.byType(WenzRichTextEditor),
    );
    expect(editor.mentionSearch, isNotNull);
    expect(editor.onMentionTap, isNotNull);

    final searchResults = await Future<List<WenzMentionCandidate>>.value(
      editor.mentionSearch!(const WenzMentionSearchRequest(query: 'gr')),
    );
    expect(searchResults.map((candidate) => candidate.label),
        contains('Grace Hopper'));

    final controller = _editorController(tester);
    final mentionCountBefore = _mentionEmbeds(controller).length;

    await tester.tap(find.byTooltip('插入提及'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Grace Hopper'), findsOneWidget);

    await tester.tap(find.text('Grace Hopper'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final mentions = _mentionEmbeds(controller);
    expect(mentions, hasLength(mentionCountBefore + 1));
    final inserted = mentions.last;
    expect(inserted.data['id'], 'u-grace');
    expect(inserted.data['label'], 'Grace Hopper');
    expect(inserted.data['email'], 'grace@example.com');

    editor = tester.widget<WenzRichTextEditor>(find.byType(WenzRichTextEditor));
    editor.onMentionTap!(
      WenzMentionTapDetails(
        embed: inserted,
        position: DocumentPosition.text(
          blockId: 'intro',
          blockIndex: 1,
          offset: 18,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('提及详情 · Grace Hopper'), findsOneWidget);
    expect(find.text('email: grace@example.com'), findsOneWidget);
    expect(find.text('department: Engineering'), findsOneWidget);
  });

  testWidgets('image toolbar picker inserts the selected local image',
      (tester) async {
    final fakeSelector = _FakeFileSelectorPlatform(
      _imageFile(
        r'C:\tmp\selected.png',
        name: 'selected.png',
      ),
    );
    _installFakeFileSelector(fakeSelector);
    await _pumpWorkbench(tester);

    await tester.tap(find.byTooltip('插入图片'));
    await tester.pump();
    await tester.pump();

    expect(fakeSelector.openFileCallCount, 1);
    expect(
      fakeSelector.acceptedExtensions,
      containsAll(<String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']),
    );
    final images = _editorController(tester)
        .document
        .blocks
        .whereType<ImageBlockNode>()
        .toList();
    expect(images, hasLength(2));
    expect(images.last.file, r'C:\tmp\selected.png');
    expect(images.last.caption, 'selected.png');
    expect(images.last.altText, 'selected.png');
    expect(find.text('selected.png'), findsWidgets);
  });

  testWidgets('video toolbar button inserts a playable video block',
      (tester) async {
    await _pumpWorkbench(tester);
    final controller = _editorController(tester);
    final videoCountBefore =
        controller.document.blocks.whereType<VideoBlockNode>().length;

    await tester.tap(find.byTooltip('插入视频'));
    await tester.pump();
    await tester.pump();

    final videos =
        controller.document.blocks.whereType<VideoBlockNode>().toList();
    expect(videos, hasLength(videoCountBefore + 1));
    final inserted = videos.last;
    expect(inserted.file, 'assets/videos/sample.mp4');
    expect(inserted.title, 'Inserted product tour');
    expect(inserted.description,
        'Played by the example MediaResolver + media_kit player.');
    expect(inserted.coverUrl, isNotEmpty);
    expect(inserted.aspectRatio, VideoBlockNode.defaultAspectRatio);
    expect(inserted.uploadStatus, FileUploadStatus.uploaded);
  });

  testWidgets('local resolver renders pasted and dropped local image captions',
      (tester) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'wenz_example_image_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final pastedFile = File(
      '${tempDir.path}${Platform.pathSeparator}pasted-local.png',
    );
    final droppedFile = File(
      '${tempDir.path}${Platform.pathSeparator}dropped-local.png',
    );
    await pastedFile.writeAsBytes(_tinyPngBytes);
    await droppedFile.writeAsBytes(_tinyPngBytes);

    await _pumpWorkbench(tester);
    final editor = tester.widget<WenzRichTextEditor>(
      find.byType(WenzRichTextEditor),
    );
    expect(editor.enableExternalImageInput, isTrue);

    final result = editor.controller.pasteExternalImages(
      <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: pastedFile.path,
          caption: 'Pasted local',
          altText: 'Pasted local',
        ),
        ExternalImageBlockDescription(
          file: droppedFile.uri.toString(),
          caption: 'Dropped local',
          altText: 'Dropped local',
        ),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(result.isSuccess, isTrue);
    expect(result.insertedImageCount, 2);
    expect(find.text('Pasted local'), findsOneWidget);
    expect(find.text('Dropped local'), findsOneWidget);
    expect(_fileImageFinder(pastedFile), findsOneWidget);
    expect(_fileImageFinder(droppedFile), findsOneWidget);
  });

  testWidgets('image toolbar picker cancellation leaves the document unchanged',
      (tester) async {
    final fakeSelector = _FakeFileSelectorPlatform(null);
    _installFakeFileSelector(fakeSelector);
    await _pumpWorkbench(tester);
    final controller = _editorController(tester);
    final blockCountBefore = controller.document.blocks.length;
    final imageCountBefore =
        controller.document.blocks.whereType<ImageBlockNode>().length;
    final canUndoBefore = controller.canUndo;

    await tester.tap(find.byTooltip('插入图片'));
    await tester.pump();
    await tester.pump();

    expect(fakeSelector.openFileCallCount, 1);
    expect(controller.document.blocks, hasLength(blockCountBefore));
    expect(controller.document.blocks.whereType<ImageBlockNode>(),
        hasLength(imageCountBefore));
    expect(controller.canUndo, canUndoBefore);
    expect(find.text('cancelled.png'), findsNothing);
    expect(find.byTooltip('插入图片'), findsOneWidget);
  });

  testWidgets('image toolbar picker errors do not insert an image',
      (tester) async {
    final fakeSelector = _FakeFileSelectorPlatform.throwing(
      StateError('picker failed'),
    );
    _installFakeFileSelector(fakeSelector);
    await _pumpWorkbench(tester);
    final controller = _editorController(tester);
    final blockCountBefore = controller.document.blocks.length;
    final imageCountBefore =
        controller.document.blocks.whereType<ImageBlockNode>().length;
    final canUndoBefore = controller.canUndo;

    await tester.tap(find.byTooltip('插入图片'));
    await tester.pump();
    await tester.pump();

    expect(fakeSelector.openFileCallCount, 1);
    expect(controller.document.blocks, hasLength(blockCountBefore));
    expect(controller.document.blocks.whereType<ImageBlockNode>(),
        hasLength(imageCountBefore));
    expect(controller.canUndo, canUndoBefore);
    expect(find.text('选择图片失败，请重试。'), findsOneWidget);
    expect(find.byTooltip('插入图片'), findsOneWidget);
  });

  testWidgets('image toolbar picker rejects empty selected paths',
      (tester) async {
    final fakeSelector = _FakeFileSelectorPlatform(
      _imageFile('', name: 'empty.png'),
    );
    _installFakeFileSelector(fakeSelector);
    await _pumpWorkbench(tester);
    final controller = _editorController(tester);
    final blockCountBefore = controller.document.blocks.length;
    final imageCountBefore =
        controller.document.blocks.whereType<ImageBlockNode>().length;
    final canUndoBefore = controller.canUndo;

    await tester.tap(find.byTooltip('插入图片'));
    await tester.pump();
    await tester.pump();

    expect(fakeSelector.openFileCallCount, 1);
    expect(controller.document.blocks, hasLength(blockCountBefore));
    expect(controller.document.blocks.whereType<ImageBlockNode>(),
        hasLength(imageCountBefore));
    expect(controller.canUndo, canUndoBefore);
    expect(find.text('无法读取所选图片路径。'), findsOneWidget);
    expect(find.byTooltip('插入图片'), findsOneWidget);
  });

  testWidgets('image toolbar picker ignores repeated taps while pending',
      (tester) async {
    final pendingSelection = Completer<XFile?>();
    final fakeSelector = _FakeFileSelectorPlatform.pending(
      pendingSelection.future,
    );
    _installFakeFileSelector(fakeSelector);
    await _pumpWorkbench(tester);
    final controller = _editorController(tester);
    final blockCountBefore = controller.document.blocks.length;
    final imageCountBefore =
        controller.document.blocks.whereType<ImageBlockNode>().length;
    final canUndoBefore = controller.canUndo;

    await tester.tap(find.byTooltip('插入图片'));
    await tester.pump();

    expect(fakeSelector.openFileCallCount, 1);
    expect(find.byTooltip('正在选择图片'), findsOneWidget);

    await tester.tap(find.byTooltip('正在选择图片'), warnIfMissed: false);
    await tester.pump();

    expect(fakeSelector.openFileCallCount, 1);

    pendingSelection.complete(null);
    await tester.pump();
    await tester.pump();

    expect(controller.document.blocks, hasLength(blockCountBefore));
    expect(controller.document.blocks.whereType<ImageBlockNode>(),
        hasLength(imageCountBefore));
    expect(controller.canUndo, canUndoBefore);
    expect(find.byTooltip('插入图片'), findsOneWidget);
  });

  testWidgets('flowchart toolbar button inserts an editable flowchart embed',
      (tester) async {
    await _pumpWorkbench(tester);
    final controller = _editorController(tester);
    int flowchartCount() => controller.document.blocks
        .whereType<BlockEmbedNode>()
        .where((block) => block.embedType == 'flowchart')
        .length;
    final before = flowchartCount();

    await tester.tap(find.byTooltip('插入流程图'));
    await tester.pump();
    await tester.pump();

    expect(flowchartCount(), before + 1);
    final inserted = controller.document.blocks
        .whereType<BlockEmbedNode>()
        .lastWhere((block) => block.embedType == 'flowchart');
    expect(inserted.data['direction'], 'TB');
    // The registered renderer paints the sample graph's header near the caret.
    expect(find.text('流程图 · 5 节点'), findsWidgets);
  });

  testWidgets(
      'flowchart embed falls back to the default embed renderer without a builder',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          BlockEmbedNode(
            id: 'flowchart',
            embedType: 'flowchart',
            data: <String, Object?>{'direction': 'TB'},
            fallbackText: '流程图',
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    // No `blockEmbedRenderers` entry for `flowchart`: the editor falls back to
    // the generic BlockType.embed renderer, which renders the embed's
    // displayText (the fallbackText) without throwing.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(controller: controller),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('流程图'), findsOneWidget);
  });
}

Future<void> _pumpWorkbench(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const WenzRichTextExampleApp());
}

WenzRichTextController _editorController(WidgetTester tester) {
  return tester.widget<WenzRichTextEditor>(find.byType(WenzRichTextEditor))
      .controller;
}

List<InlineEmbed> _mentionEmbeds(WenzRichTextController controller) {
  final mentions = <InlineEmbed>[];
  for (final block in controller.document.blocks) {
    if (block is TextBlockNode) {
      mentions.addAll(
        block.content
            .whereType<InlineEmbed>()
            .where((embed) => embed.embedType == 'mention'),
      );
    } else if (block is CalloutBlockNode) {
      mentions.addAll(
        block.content
            .whereType<InlineEmbed>()
            .where((embed) => embed.embedType == 'mention'),
      );
    }
  }
  return mentions;
}

Finder _fileImageFinder(File file) {
  return find.byWidgetPredicate(
    (widget) {
      if (widget is! Image) {
        return false;
      }
      final image = widget.image;
      if (image is FileImage) {
        return image.file.path == file.path;
      }
      if (image is ResizeImage && image.imageProvider is FileImage) {
        return (image.imageProvider as FileImage).file.path == file.path;
      }
      return false;
    },
    description: 'Image.file(${file.path})',
  );
}

void _installFakeFileSelector(_FakeFileSelectorPlatform fakeSelector) {
  final previousPlatform = FileSelectorPlatform.instance;
  FileSelectorPlatform.instance = fakeSelector;
  addTearDown(() => FileSelectorPlatform.instance = previousPlatform);
}

XFile _imageFile(String path, {required String name}) {
  return XFile(
    path,
    name: name,
    mimeType: 'image/png',
    length: 8,
  );
}

class _FakeFileSelectorPlatform extends FileSelectorPlatform {
  _FakeFileSelectorPlatform(XFile? nextFile)
      : _openFile = (() async => nextFile);

  _FakeFileSelectorPlatform.throwing(Object error)
      : _openFile = (() async => throw error);

  _FakeFileSelectorPlatform.pending(Future<XFile?> pendingFile)
      : _openFile = (() => pendingFile);

  final Future<XFile?> Function() _openFile;
  int openFileCallCount = 0;
  List<XTypeGroup>? acceptedTypeGroups;

  List<String> get acceptedExtensions {
    return acceptedTypeGroups
            ?.expand((group) => group.extensions ?? const <String>[])
            .toList() ??
        const <String>[];
  }

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    openFileCallCount += 1;
    this.acceptedTypeGroups = acceptedTypeGroups;
    return _openFile();
  }
}

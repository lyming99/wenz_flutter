import 'dart:async';
import 'dart:io';

// ignore_for_file: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';
import 'package:wenz_richtext_example/example_video_player.dart';
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
  testWidgets('wide layout renders editor workbench with desktop toolbar', (tester) async {
    await _pumpWorkbench(tester);

    expect(find.text('Wenz RichText'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);
    expect(find.byType(WenzDefaultDesktopToolbar), findsOneWidget);
    expect(find.byType(WenzDefaultMobileToolbar), findsNothing);
    expect(find.byTooltip('加粗'), findsOneWidget);
    expect(find.byTooltip('插入元素'), findsOneWidget);
  });

  testWidgets('compact mobile layout uses the default mobile toolbar',
      (tester) async {
    await _pumpWorkbench(
      tester,
      physicalSize: const Size(390, 844),
      platform: TargetPlatform.android,
    );

    expect(find.byType(WenzDefaultMobileToolbar), findsOneWidget);
    expect(find.byType(WenzDefaultDesktopToolbar), findsNothing);
    expect(find.byTooltip('打开插入面板'), findsOneWidget);
    expect(find.byTooltip('收起键盘'), findsOneWidget);
  });

  testWidgets('example mermaid sample enters the diagram preview path',
      (tester) async {
    await _pumpWorkbench(tester);

    final controller = _editorController(tester);
    final mermaid = controller.document.blocks
        .whereType<CodeBlockNode>()
        .singleWhere((block) => block.id == 'mermaid-sample');

    expect(mermaid.language, 'mermaid');
    expect(mermaid.code, startsWith('flowchart TD'));
    expect(mermaid.code, contains('Revise --> Quote'));
    expect(find.byType(MermaidCodeBlockWidget), findsOneWidget);
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

  testWidgets('workbench wires link opening callback into the editor',
      (tester) async {
    await _pumpWorkbench(tester);

    final editor = tester.widget<WenzRichTextEditor>(
      find.byType(WenzRichTextEditor),
    );
    expect(editor.onOpenLink, isNotNull);
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

    await _tapDesktopInsertMenuItem(tester, '插入图片');
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

    await _tapDesktopInsertMenuItem(tester, '插入视频');
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

  testWidgets('file toolbar button inserts an attachment block',
      (tester) async {
    await _pumpWorkbench(tester);
    final controller = _editorController(tester);
    final fileCountBefore =
        controller.document.blocks.whereType<FileBlockNode>().length;

    await _tapDesktopInsertMenuItem(tester, '插入文件');
    await tester.pump();

    final files = controller.document.blocks.whereType<FileBlockNode>().toList();
    expect(files, hasLength(fileCountBefore + 1));
    final inserted = files.last;
    expect(inserted.assetId, startsWith('attachment-file-'));
    expect(inserted.name, 'product-brief.pdf');
    expect(inserted.size, 245760);
    expect(inserted.mimeType, 'application/pdf');
    expect(inserted.downloadUrl, 'https://example.com/files/product-brief.pdf');
    expect(inserted.uploadStatus, FileUploadStatus.uploaded);
  });

  testWidgets('business embed toolbar button inserts the CRM card block',
      (tester) async {
    await _pumpWorkbench(tester);
    final controller = _editorController(tester);
    final crmCountBefore = controller.document.blocks
        .whereType<BlockEmbedNode>()
        .where((block) => block.embedType == 'crm-card')
        .length;

    await _tapDesktopInsertMenuItem(tester, '插入业务嵌入');
    await tester.pump();

    final crmCards = controller.document.blocks
        .whereType<BlockEmbedNode>()
        .where((block) => block.embedType == 'crm-card')
        .toList();
    expect(crmCards, hasLength(crmCountBefore + 1));
    final inserted = crmCards.last;
    expect(inserted.data['title'], 'Acme renewal');
    expect(inserted.data['owner'], 'Ada');
    expect(inserted.data['stage'], 'Proposal');
    expect(inserted.fallbackText, 'Acme renewal');
  });

  test('example video player exposes embedded and fullscreen corner modes', () {
    const source = ExampleVideoSource.asset('assets/videos/sample.mp4');

    const embedded = ExampleVideoPlayer(source: source);
    expect(embedded.borderRadius, ExampleVideoPlayer.defaultBorderRadius);

    const fullscreen = ExampleVideoPlayer.fullscreen(source: source);
    expect(fullscreen.borderRadius, BorderRadius.zero);
    expect(fullscreen.source, source);
    expect(fullscreen.aspectRatio, ExampleVideoPlayer.defaultAspectRatio);
  });

  testWidgets('fullscreen example player has no rounded clip', (tester) async {
    final embeddedPlayback = _FakeExampleVideoPlayback();
    await _pumpExampleVideoPlayer(tester, embeddedPlayback);
    expect(
      find.byKey(
        const ValueKey<String>('example-video-player-rounded-clip'),
      ),
      findsOneWidget,
    );

    final fullscreenPlayback = _FakeExampleVideoPlayback();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 640,
              child: ExampleVideoPlayer.fullscreen(
                source: const ExampleVideoSource.asset(
                  'assets/videos/sample.mp4',
                ),
                playbackFactory: () => fullscreenPlayback,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final player = find.byType(ExampleVideoPlayer);
    expect(
      find.byKey(
        const ValueKey<String>('example-video-player-square-clip'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: player, matching: find.byType(ClipRRect)),
      findsNothing,
    );
  });

  testWidgets(
      'example video player applies first tap and serializes rapid playback intent',
      (tester) async {
    final playback = _FakeExampleVideoPlayback();
    await _pumpExampleVideoPlayer(tester, playback);

    final tapLayer = find.byKey(
      const ValueKey<String>('example-video-player-tap-layer'),
    );
    expect(tapLayer, findsOneWidget);
    expect(find.byTooltip('播放'), findsOneWidget);

    await tester.tap(tapLayer);
    await _pumpVideoCommands(tester);

    expect(playback.commands, <String>['play']);
    expect(find.byTooltip('暂停'), findsOneWidget);

    // A lagging backend `playing:false` event cannot undo the user's play
    // intent and force a second click.
    playback.emitPlaying(false);
    await tester.pump();
    expect(find.byTooltip('暂停'), findsOneWidget);

    await tester.tap(tapLayer);
    await _pumpVideoCommands(tester);
    expect(playback.commands, <String>['play', 'pause']);
    expect(find.byTooltip('播放'), findsOneWidget);

    // Two clicks issued before either command settles are applied in order and
    // finish paused, without relying on a stale stream value to choose a toggle.
    await tester.tap(tapLayer);
    await tester.tap(tapLayer);
    await _pumpVideoCommands(tester);
    expect(
      playback.commands,
      <String>['play', 'pause', 'play', 'pause'],
    );
    expect(find.byTooltip('播放'), findsOneWidget);

    playback.emitCompleted(true);
    await tester.pump();
    playback.commands.clear();

    await tester.tap(tapLayer);
    await _pumpVideoCommands(tester);
    expect(playback.commands, <String>['seek:0', 'play']);
    expect(find.byTooltip('暂停'), findsOneWidget);
  });

  testWidgets('rapid taps coalesce when their final target is already applied',
      (tester) async {
    final playGate = Completer<void>();
    final playback = _FakeExampleVideoPlayback(playGate: playGate.future);
    await _pumpExampleVideoPlayer(tester, playback);
    final tapLayer = find.byKey(
      const ValueKey<String>('example-video-player-tap-layer'),
    );

    await tester.tap(tapLayer);
    await tester.tap(tapLayer);
    await tester.tap(tapLayer);
    await tester.pump();
    expect(playback.commands, <String>['play']);

    playGate.complete();
    await _pumpVideoCommands(tester);
    expect(playback.commands, <String>['play']);
    expect(find.byTooltip('暂停'), findsOneWidget);
  });

  testWidgets('video controls own their hit regions without toggling the canvas',
      (tester) async {
    final playback = _FakeExampleVideoPlayback();
    await _pumpExampleVideoPlayer(tester, playback);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('example-video-player-play-button'),
      ),
    );
    await _pumpVideoCommands(tester);
    expect(playback.commands, <String>['play']);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('example-video-player-progress'),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('example-video-player-mute-button'),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('example-video-player-volume'),
      ),
    );
    await tester.pump();

    expect(playback.commands.where((command) => command == 'play'), hasLength(1));
    expect(playback.commands.where((command) => command == 'pause'), isEmpty);
    expect(playback.commands, contains('volume:0'));
    expect(
      playback.commands
          .where((command) => command.startsWith('volume:'))
          .length,
      greaterThanOrEqualTo(2),
    );

    playback.emitBuffering(true);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    playback.emitBuffering(false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('video initialization errors and disposal stay contained',
      (tester) async {
    var emptyFactoryCalls = 0;
    await _pumpExampleVideoPlayer(
      tester,
      _FakeExampleVideoPlayback(),
      source: const ExampleVideoSource.asset(''),
      factoryOverride: () {
        emptyFactoryCalls++;
        return _FakeExampleVideoPlayback();
      },
    );
    expect(emptyFactoryCalls, 0);
    expect(find.text('视频无法播放'), findsOneWidget);

    final failing = _FakeExampleVideoPlayback(
      openError: StateError('open failed'),
    );
    await _pumpExampleVideoPlayer(tester, failing);
    expect(find.text('视频无法播放'), findsOneWidget);
    expect(find.byKey(
      const ValueKey<String>('example-video-player-tap-layer'),
    ), findsNothing);

    final pendingOpen = Completer<void>();
    final pending = _FakeExampleVideoPlayback(openGate: pendingOpen.future);
    await _pumpExampleVideoPlayer(tester, pending);
    expect(pending.openedSources, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    pendingOpen.complete();
    await tester.pump();
    expect(pending.disposeCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'example video resolver keeps source dispatch and returns square player',
      (tester) async {
    await _pumpWorkbench(tester);
    final editorFinder = find.byType(WenzRichTextEditor);
    final editor = tester.widget<WenzRichTextEditor>(editorFinder);
    final resolver = editor.mediaResolver;
    expect(resolver, isNotNull);
    final context = tester.element(editorFinder);

    ExampleVideoPlayer resolve(VideoBlockNode block) {
      final resolved = resolver!.resolve(context, block);
      expect(resolved, isA<ExampleVideoPlayer>());
      return resolved! as ExampleVideoPlayer;
    }

    final assetPlayer = resolve(
      const VideoBlockNode(
        id: 'asset-video',
        assetId: 'asset-video-id',
        file: 'assets/videos/sample.mp4',
      ),
    );
    expect(assetPlayer.source.kind, ExampleVideoSourceKind.asset);
    expect(assetPlayer.source.uri, 'assets/videos/sample.mp4');
    expect(assetPlayer.borderRadius, BorderRadius.zero);

    final networkPlayer = resolve(
      const VideoBlockNode(
        id: 'network-video',
        assetId: 'network-video-id',
        playbackUrl: 'https://cdn.example.test/demo.mp4',
      ),
    );
    expect(networkPlayer.source.kind, ExampleVideoSourceKind.network);
    expect(networkPlayer.source.uri, 'https://cdn.example.test/demo.mp4');
    expect(networkPlayer.borderRadius, BorderRadius.zero);

    final filePlayer = resolve(
      const VideoBlockNode(
        id: 'file-video',
        assetId: 'file-video-id',
        file: r'C:\media\demo.mp4',
      ),
    );
    expect(filePlayer.source.kind, ExampleVideoSourceKind.file);
    expect(filePlayer.source.uri, r'C:\media\demo.mp4');
    expect(filePlayer.borderRadius, BorderRadius.zero);

    late BuildContext fullscreenContext;
    await tester.pumpWidget(
      MaterialApp(
        home: WenzRichTextMediaResolveScope(
          videoEntry: WenzRichTextVideoMediaResolveEntry.dialog,
          child: Builder(
            builder: (context) {
              fullscreenContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    final fullscreenResolved = resolver!.resolve(
      fullscreenContext,
      const VideoBlockNode(
        id: 'fullscreen-video',
        assetId: 'fullscreen-video-id',
        playbackUrl: 'https://cdn.example.test/fullscreen.mp4',
      ),
    );
    expect(fullscreenResolved, isA<ExampleVideoPlayer>());
    final fullscreenPlayer = fullscreenResolved! as ExampleVideoPlayer;
    expect(fullscreenPlayer.source.kind, ExampleVideoSourceKind.network);
    expect(fullscreenPlayer.borderRadius, BorderRadius.zero);
    expect(fullscreenPlayer.playbackFactory, isNotNull);
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

    await _tapDesktopInsertMenuItem(tester, '插入图片');
    await tester.pump();
    await tester.pump();

    expect(fakeSelector.openFileCallCount, 1);
    expect(controller.document.blocks, hasLength(blockCountBefore));
    expect(controller.document.blocks.whereType<ImageBlockNode>(),
        hasLength(imageCountBefore));
    expect(controller.canUndo, canUndoBefore);
    expect(find.text('cancelled.png'), findsNothing);
    expect(find.byTooltip('插入元素'), findsOneWidget);
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

    await _tapDesktopInsertMenuItem(tester, '插入图片');
    await tester.pump();
    await tester.pump();

    expect(fakeSelector.openFileCallCount, 1);
    expect(controller.document.blocks, hasLength(blockCountBefore));
    expect(controller.document.blocks.whereType<ImageBlockNode>(),
        hasLength(imageCountBefore));
    expect(controller.canUndo, canUndoBefore);
    expect(find.text('选择图片失败，请重试。'), findsOneWidget);
    expect(find.byTooltip('插入元素'), findsOneWidget);
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

    await _tapDesktopInsertMenuItem(tester, '插入图片');
    await tester.pump();
    await tester.pump();

    expect(fakeSelector.openFileCallCount, 1);
    expect(controller.document.blocks, hasLength(blockCountBefore));
    expect(controller.document.blocks.whereType<ImageBlockNode>(),
        hasLength(imageCountBefore));
    expect(controller.canUndo, canUndoBefore);
    expect(find.text('无法读取所选图片路径。'), findsOneWidget);
    expect(find.byTooltip('插入元素'), findsOneWidget);
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

    await _tapDesktopInsertMenuItem(tester, '插入图片');

    expect(fakeSelector.openFileCallCount, 1);

    await _openDesktopInsertMenu(tester);
    expect(find.text('正在选择图片'), findsOneWidget);

    await tester.tap(find.text('正在选择图片'), warnIfMissed: false);
    await tester.pump();

    expect(fakeSelector.openFileCallCount, 1);

    pendingSelection.complete(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('插入图片'), findsOneWidget);

    expect(controller.document.blocks, hasLength(blockCountBefore));
    expect(controller.document.blocks.whereType<ImageBlockNode>(),
        hasLength(imageCountBefore));
    expect(controller.canUndo, canUndoBefore);
    expect(find.byTooltip('插入元素'), findsOneWidget);
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

Future<void> _pumpExampleVideoPlayer(
  WidgetTester tester,
  _FakeExampleVideoPlayback playback, {
  ExampleVideoSource source =
      const ExampleVideoSource.asset('assets/videos/sample.mp4'),
  ExampleVideoPlaybackFactory? factoryOverride,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 640,
            child: ExampleVideoPlayer(
              source: source,
              playbackFactory: factoryOverride ?? () => playback,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpVideoCommands(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpWorkbench(
  WidgetTester tester, {
  Size physicalSize = const Size(1600, 1200),
  TargetPlatform? platform,
}) async {
  if (platform != null) {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
  }
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    WenzRichTextExampleApp(
      videoPlaybackFactory: _FakeExampleVideoPlayback.new,
    ),
  );
}

Future<void> _openDesktopInsertMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('插入元素'));
  await tester.pump();
}

Future<void> _tapDesktopInsertMenuItem(
  WidgetTester tester,
  String label,
) async {
  await _openDesktopInsertMenu(tester);
  final item = find.text(label).last;
  expect(item, findsOneWidget);
  await tester.tap(item);
  await tester.pump();
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

class _FakeExampleVideoPlayback implements ExampleVideoPlayback {
  _FakeExampleVideoPlayback({
    this.openError,
    this.openGate,
    this.playGate,
  });

  final Object? openError;
  final Future<void>? openGate;
  final Future<void>? playGate;

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast(sync: true);
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast(sync: true);
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast(sync: true);
  final StreamController<bool> _completedController =
      StreamController<bool>.broadcast(sync: true);
  final StreamController<bool> _bufferingController =
      StreamController<bool>.broadcast(sync: true);
  final StreamController<String> _errorController =
      StreamController<String>.broadcast(sync: true);

  final List<ExampleVideoSource> openedSources = <ExampleVideoSource>[];
  final List<String> commands = <String>[];
  int disposeCalls = 0;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<bool> get completedStream => _completedController.stream;

  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  Future<void> open(ExampleVideoSource source) async {
    openedSources.add(source);
    _durationController.add(const Duration(minutes: 2));
    _playingController.add(false);
    _bufferingController.add(false);
    final error = openError;
    if (error != null) {
      throw error;
    }
    final gate = openGate;
    if (gate != null) {
      await gate;
    }
  }

  @override
  Future<void> play() async {
    commands.add('play');
    final gate = playGate;
    if (gate != null) {
      await gate;
    }
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
  }

  @override
  Future<void> seek(Duration position) async {
    commands.add('seek:${position.inMilliseconds}');
    _positionController.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    commands.add('volume:${_compactDouble(volume)}');
  }

  @override
  Widget buildVideoSurface() {
    return const ColoredBox(
      key: ValueKey<String>('fake-example-video-surface'),
      color: Colors.black,
    );
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  void emitPlaying(bool playing) {
    _playingController.add(playing);
  }

  void emitCompleted(bool completed) {
    _completedController.add(completed);
  }

  void emitBuffering(bool buffering) {
    _bufferingController.add(buffering);
  }
}

String _compactDouble(double value) {
  return value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2);
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

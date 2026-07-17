import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  test('document plainText joins block text', () {
    const document = RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'p1',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'hello')],
        ),
        CodeBlockNode(id: 'c1', code: 'print(1);', language: 'dart'),
      ],
    );

    expect(document.plainText, 'hello\nprint(1);');
  });

  test('position compares block, path, and offset', () {
    const first = DocumentPosition(
      blockId: 'a',
      blockIndex: 0,
      path: PositionPath(<Object>['block', 'a', 'text']),
      offset: 3,
    );
    const second = DocumentPosition(
      blockId: 'a',
      blockIndex: 0,
      path: PositionPath(<Object>['block', 'a', 'text']),
      offset: 5,
    );

    expect(first.compareTo(second), lessThan(0));
    expect(
      const DocumentSelection(base: second, extent: first).start,
      same(first),
    );
  });

  test('image block round trips caption alt text and display size', () {
    const image = ImageBlockNode(
      id: 'img1',
      assetId: 'hero',
      file: 'hero.png',
      width: 640,
      height: 360,
      showWidth: 320,
      showHeight: 180,
      caption: 'Hero caption',
      altText: 'Hero alt',
    );

    final decoded = BlockNode.fromJson(image.toJson()) as ImageBlockNode;

    expect(decoded.assetId, 'hero');
    expect(decoded.file, 'hero.png');
    expect(decoded.width, 640);
    expect(decoded.height, 360);
    expect(decoded.showWidth, 320);
    expect(decoded.showHeight, 180);
    expect(decoded.caption, 'Hero caption');
    expect(decoded.altText, 'Hero alt');
    expect(decoded.plainText, 'Hero caption');
  });

  test('image block accepts legacy alt key as altText', () {
    final decoded = BlockNode.fromJson(<String, Object?>{
      'id': 'img1',
      'type': 'image',
      'assetId': 'hero',
      'alt': 'Legacy alt',
    }) as ImageBlockNode;

    expect(decoded.altText, 'Legacy alt');
  });

  test('video block round trips media protocol fields', () {
    const video = VideoBlockNode(
      id: 'video1',
      assetId: 'asset-1',
      playbackUrl: 'https://cdn.example.com/video.mp4',
      file: 'file:///tmp/video.mp4',
      coverUrl: 'https://cdn.example.com/poster.jpg',
      title: 'Launch demo',
      description: 'Two minute walkthrough',
      aspectRatio: 16 / 9,
      showWidth: 480,
      showHeight: 270,
      uploadStatus: FileUploadStatus.failed,
      uploadError: 'network timeout',
      attributes: BlockAttributes(alignment: 'center'),
    );

    final decoded = BlockNode.fromJson(video.toJson()) as VideoBlockNode;

    expect(decoded.assetId, 'asset-1');
    expect(decoded.playbackUrl, 'https://cdn.example.com/video.mp4');
    expect(decoded.file, 'file:///tmp/video.mp4');
    expect(decoded.coverUrl, 'https://cdn.example.com/poster.jpg');
    expect(decoded.title, 'Launch demo');
    expect(decoded.description, 'Two minute walkthrough');
    expect(decoded.aspectRatio, closeTo(16 / 9, 0.0001));
    expect(decoded.effectiveAspectRatio, closeTo(16 / 9, 0.0001));
    expect(decoded.showWidth, 480);
    expect(decoded.showHeight, 270);
    expect(decoded.attributes.alignment, 'center');
    expect(decoded.toJson()['attrs'], <String, Object?>{'alignment': 'center'});
    expect(decoded.uploadStatus, FileUploadStatus.failed);
    expect(decoded.uploadError, 'network timeout');
    expect(decoded.hasSource, isTrue);
    expect(decoded.effectivePlaybackUrl, 'https://cdn.example.com/video.mp4');
    expect(decoded.plainText, 'Launch demo');
  });

  test('video block accepts aliases and safe defaults', () {
    final legacy = BlockNode.fromJson(<String, Object?>{
      'id': 'video2',
      'type': 'video',
      'assetId': 'asset-2',
      'src': 'https://cdn.example.com/legacy.mp4',
      'localFile': '/tmp/legacy.mp4',
      'poster': 'https://cdn.example.com/legacy.jpg',
      'caption': 'Legacy title',
      'desc': 'Legacy description',
      'width': 640,
      'height': 360,
      'uploadStatus': 'unknown-status',
      'unknown': <String, Object?>{'ignored': true},
    }) as VideoBlockNode;

    expect(legacy.playbackUrl, 'https://cdn.example.com/legacy.mp4');
    expect(legacy.file, '/tmp/legacy.mp4');
    expect(legacy.coverUrl, 'https://cdn.example.com/legacy.jpg');
    expect(legacy.title, 'Legacy title');
    expect(legacy.description, 'Legacy description');
    expect(legacy.aspectRatio, closeTo(16 / 9, 0.0001));
    expect(legacy.uploadStatus, FileUploadStatus.none);

    final missing = BlockNode.fromJson(<String, Object?>{
      'id': 'video3',
      'type': 'video',
      'unknown': 'ignored',
    }) as VideoBlockNode;

    expect(missing.assetId, isEmpty);
    expect(missing.playbackUrl, isEmpty);
    expect(missing.file, isEmpty);
    expect(missing.coverUrl, isEmpty);
    expect(missing.title, isEmpty);
    expect(missing.description, isEmpty);
    expect(missing.aspectRatio, isNull);
    expect(missing.effectiveAspectRatio,
        closeTo(VideoBlockNode.defaultAspectRatio, 0.0001));
    expect(missing.showWidth, isNull);
    expect(missing.showHeight, isNull);
    expect(missing.uploadStatus, FileUploadStatus.none);
    expect(missing.uploadError, isEmpty);
  });

  test('video block copyWith updates and clears display size', () {
    const video = VideoBlockNode(
      id: 'video4',
      assetId: 'asset-4',
      playbackUrl: 'https://cdn.example.com/video4.mp4',
      coverUrl: 'https://cdn.example.com/video4.jpg',
      title: 'Resizable clip',
      description: 'Keep metadata',
      aspectRatio: 16 / 9,
      showWidth: 640,
      showHeight: 360,
      uploadStatus: FileUploadStatus.uploaded,
      attributes: BlockAttributes(alignment: 'right'),
    );

    final resized = video.copyWith(showWidth: 320, showHeight: 180);

    expect(resized.assetId, 'asset-4');
    expect(resized.playbackUrl, 'https://cdn.example.com/video4.mp4');
    expect(resized.coverUrl, 'https://cdn.example.com/video4.jpg');
    expect(resized.title, 'Resizable clip');
    expect(resized.description, 'Keep metadata');
    expect(resized.aspectRatio, 16 / 9);
    expect(resized.showWidth, 320);
    expect(resized.showHeight, 180);
    expect(resized.uploadStatus, FileUploadStatus.uploaded);
    expect(resized.attributes.alignment, 'right');

    final cleared = resized.copyWith(
      clearShowWidth: true,
      clearShowHeight: true,
    );

    expect(cleared.showWidth, isNull);
    expect(cleared.showHeight, isNull);
    expect(cleared.title, 'Resizable clip');
    expect(cleared.attributes.alignment, 'right');
    expect(cleared.uploadStatus, FileUploadStatus.uploaded);
  });

  test('block embed round trips data and fallback text', () {
    const block = BlockEmbedNode(
      id: 'embed1',
      embedType: 'crm-card',
      data: <String, Object?>{'recordId': '42', 'title': 'Acme'},
      fallbackText: 'Acme account',
    );

    final decoded = BlockNode.fromJson(block.toJson()) as BlockEmbedNode;

    expect(decoded.type, BlockType.embed);
    expect(decoded.embedType, 'crm-card');
    expect(decoded.data, containsPair('recordId', '42'));
    expect(decoded.displayText, 'Acme account');
    expect(decoded.plainText, 'Acme account');
  });

  test('block attributes round trip anchor', () {
    const block = TextBlockNode(
      id: 'h1',
      type: BlockType.heading,
      attributes: BlockAttributes(level: 2, anchor: 'intro'),
      content: <InlineNode>[TextRun(text: 'Intro')],
    );

    final decoded = BlockNode.fromJson(block.toJson()) as TextBlockNode;

    expect(decoded.attributes.level, 2);
    expect(decoded.attributes.anchor, 'intro');
    expect(decoded.toJson()['attrs'], containsPair('anchor', 'intro'));
  });
}

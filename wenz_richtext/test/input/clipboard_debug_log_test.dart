import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  late bool originalEnabled;
  late int originalLimit;
  late void Function(String message) originalSink;

  setUp(() {
    originalEnabled = WenzClipboardDebugLog.enabled;
    originalLimit = WenzClipboardDebugLog.maxPreviewCharacters;
    originalSink = WenzClipboardDebugLog.sink;
  });

  tearDown(() {
    WenzClipboardDebugLog.enabled = originalEnabled;
    WenzClipboardDebugLog.maxPreviewCharacters = originalLimit;
    WenzClipboardDebugLog.sink = originalSink;
  });

  test('writes searchable structured events with truncated previews', () {
    final messages = <String>[];
    WenzClipboardDebugLog.enabled = true;
    WenzClipboardDebugLog.maxPreviewCharacters = 32;
    WenzClipboardDebugLog.sink = messages.add;

    WenzClipboardDebugLog.event(
      'parse.request',
      fields: <String, Object?>{
        'format': 'text/html',
        'payload': WenzClipboardDebugLog.text('line one\nline two long'),
      },
    );

    expect(messages, hasLength(1));
    expect(messages.single, startsWith('[wenz_richtext][clipboard]'));
    expect(messages.single, contains('parse.request'));
    expect(messages.single, contains('format="text/html"'));
    expect(messages.single, contains(r'line one\nli'));
    expect(messages.single, contains('…'));
  });

  test('can be disabled without invoking the configured sink', () {
    final messages = <String>[];
    WenzClipboardDebugLog.enabled = false;
    WenzClipboardDebugLog.sink = messages.add;

    WenzClipboardDebugLog.event('copy.request');

    expect(messages, isEmpty);
  });

  test('copy and parse emit payload kind and list block diagnostics', () {
    final messages = <String>[];
    WenzClipboardDebugLog.enabled = true;
    WenzClipboardDebugLog.sink = messages.add;
    const document = RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'li1',
          type: BlockType.listItem,
          content: <InlineNode>[TextRun(text: 'diagnostic item')],
        ),
      ],
    );
    final start = DocumentPosition.text(
      blockId: 'li1',
      blockIndex: 0,
      offset: 0,
    );
    final end = DocumentPosition.text(
      blockId: 'li1',
      blockIndex: 0,
      offset: 15,
    );
    const service = ClipboardService();

    final payload = service.copyPayload(
      document,
      DocumentSelection(base: start, extent: end),
    )!;
    service.parse(payload.wenzRichText);

    expect(messages.any((message) => message.contains('copy.request')), isTrue);
    expect(
      messages.any(
        (message) =>
            message.contains('copy.payload-built') &&
            message.contains('kind="blocks"') &&
            message.contains('type:listItem'),
      ),
      isTrue,
    );
    expect(
      messages.any(
        (message) =>
            message.contains('parse.result') &&
            message.contains('source="wenz-private"') &&
            message.contains('kind="blocks"'),
      ),
      isTrue,
    );
  });
}

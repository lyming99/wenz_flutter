import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

/// C7 — verifies the controller's no-throw safe-entry helpers (`tryLoadJson`,
/// `tryExecuteCommand`) and that `loadJson` still throws a structured
/// [DocumentDecodeException]. See `docs/acceptance_report.md` task C7 /
/// acceptance item 9.4.
void main() {
  group('WenzRichTextController.tryLoadJson', () {
    test('ok: replaces document and fires onChanged', () {
      final controller = WenzRichTextController(
        document: _doc('original'),
      );
      var changes = 0;
      controller.onChanged = (_) => changes++;

      const codec = RichTextJsonCodec();
      final goodJson = codec.encode(_doc('loaded'));

      final result = controller.tryLoadJson(goodJson);

      expect(result.ok, isTrue);
      expect(result.document, isNotNull);
      expect(result.document!.plainText, 'loaded');
      expect(controller.document.plainText, 'loaded');
      expect(changes, 1);

      controller.dispose();
    });

    test('failed (malformed rich JSON): leaves document untouched, no callback',
        () {
      final controller = WenzRichTextController(document: _doc('original'));
      final before = controller.document;
      final changedBefore = controller.lastChangedBlockIds;
      var changes = 0;
      var selectionChanges = 0;
      var commandRuns = 0;
      controller.onChanged = (_) => changes++;
      controller.onSelectionChanged = (_) => selectionChanges++;
      controller.onCommandExecuted = (_, __) => commandRuns++;

      final result = controller.tryLoadJson('{not valid json');

      expect(result.ok, isFalse);
      expect(result.document, isNull);
      expect(result.error, isA<DocumentDecodeException>());
      // Document, selection, history, and change-tracking are untouched.
      expect(controller.document, same(before));
      expect(controller.document.plainText, 'original');
      expect(controller.lastChangedBlockIds, same(changedBefore));
      expect(changes, 0);
      expect(selectionChanges, 0);
      expect(commandRuns, 0);

      controller.dispose();
    });

    test('failed (malformed legacy JSON): same guarantees as rich path', () {
      final controller = WenzRichTextController(document: _doc('original'));
      var changes = 0;
      controller.onChanged = (_) => changes++;

      final result = controller.tryLoadJson('{bad', legacy: true);

      expect(result.ok, isFalse);
      expect(result.error, isA<DocumentDecodeException>());
      expect(controller.document.plainText, 'original');
      expect(changes, 0);

      controller.dispose();
    });

    test('loadJson still throws DocumentDecodeException (back-compat)', () {
      final controller = WenzRichTextController(document: _doc('original'));
      expect(
        () => controller.loadJson('{not json'),
        throwsA(isA<DocumentDecodeException>()),
      );
      // On throw the document is untouched.
      expect(controller.document.plainText, 'original');
      controller.dispose();
    });
  });

  group('WenzRichTextController.tryExecuteCommand', () {
    test('unknown command returns false without touching the document', () {
      final controller = WenzRichTextController(
        document: _doc('hello'),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      var changes = 0;
      var selectionChanges = 0;
      var commandRuns = 0;
      controller.onChanged = (_) => changes++;
      controller.onSelectionChanged = (_) => selectionChanges++;
      controller.onCommandExecuted = (_, __) => commandRuns++;

      final ok = controller.tryExecuteCommand('does-not-exist', {});

      expect(ok, isFalse);
      expect(controller.document.plainText, 'hello');
      expect(changes, 0);
      expect(selectionChanges, 0);
      expect(commandRuns, 0);

      controller.dispose();
    });

    test('registered command executes and returns true', () {
      final controller = WenzRichTextController(
        document: _doc(''),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      controller.registry.register(
        CommandDescriptor(
          name: 'insertHello',
          factory: (args) =>
              InsertTextCommand(args.readString('text') ?? 'hello'),
        ),
      );

      final ok = controller.tryExecuteCommand(
        'insertHello',
        <String, Object?>{'text': 'world'},
      );

      expect(ok, isTrue);
      expect(controller.document.plainText, 'world');

      controller.dispose();
    });

    test('executeCommand still throws UnknownCommandException (back-compat)',
        () {
      final controller = WenzRichTextController();
      expect(
        () => controller.executeCommand('nope', {}),
        throwsA(isA<UnknownCommandException>()),
      );
      controller.dispose();
    });
  });

  group('WenzRichTextController.tryLoadJsonAuto', () {
    // tryLoadJsonAuto is the lazy-migration entry point: it auto-detects
    // whether a stored note is the legacy wenz_editor array format or the
    // current Rich JSON object format, and reports which one it found so the
    // host can upgrade the note on its next save.

    test('detects and decodes legacy array format', () {
      final controller = WenzRichTextController(document: _doc('original'));
      var changes = 0;
      controller.onChanged = (_) => changes++;

      // A wenz_editor-style bare array payload.
      const legacyJson =
          '[{"type":"text","level":0,"children":[{"type":"text","text":"legacy note"}]}]';

      final result = controller.tryLoadJsonAuto(legacyJson);

      expect(result.ok, isTrue);
      expect(result.format, JsonLoadFormat.legacy);
      expect(result.document!.plainText, 'legacy note');
      expect(controller.document.plainText, 'legacy note');
      expect(changes, 1);

      controller.dispose();
    });

    test('detects and decodes current Rich JSON object format', () {
      final controller = WenzRichTextController(document: _doc('original'));

      final currentJson = const RichTextJsonCodec().encode(_doc('current'));

      final result = controller.tryLoadJsonAuto(currentJson);

      expect(result.ok, isTrue);
      expect(result.format, JsonLoadFormat.current);
      expect(result.document!.plainText, 'current');

      controller.dispose();
    });

    test('detects wrapped legacy blocks and preserves every known block type',
        () {
      final controller = WenzRichTextController(document: _doc('original'));
      final wrappedLegacyJson = jsonEncode(<String, Object?>{
        'blocks': <Object?>[
          <String, Object?>{
            'type': 'title',
            'level': 2,
            'text': 'Legacy heading',
          },
          <String, Object?>{'type': 'text', 'text': 'Legacy body'},
          <String, Object?>{
            'type': 'text',
            'itemType': 'oli',
            'text': 'Ordered item',
          },
          <String, Object?>{
            'type': 'text',
            'itemType': 'check',
            'text': 'Task item',
          },
          <String, Object?>{
            'type': 'quote',
            'level': 2,
            'text': 'Quoted heading',
          },
          <String, Object?>{
            'type': 'code',
            'language': 'dart',
            'code': 'void main() {}',
          },
          <String, Object?>{
            'type': 'image',
            'id': 'legacy-image',
            'file': 'legacy.png',
            'width': 320,
            'height': 180,
          },
          <String, Object?>{
            'type': 'table',
            'rows': <Object?>[
              <Object?>[
                <String, Object?>{'type': 'text', 'text': 'Cell'},
              ],
            ],
          },
          <String, Object?>{'type': 'line'},
          <String, Object?>{
            'type': 'video',
            'id': 'legacy-video',
            'file': 'legacy.mp4',
            'width': 1920,
            'height': 1080,
          },
        ],
      });

      final result = controller.tryLoadJsonAuto(wrappedLegacyJson);

      expect(result.ok, isTrue);
      expect(result.format, JsonLoadFormat.legacy);
      final blocks = result.document!.blocks;
      expect(blocks, hasLength(10));
      expect(blocks[0].type, BlockType.heading);
      expect(blocks[0].attributes.level, 2);
      expect(blocks[1].type, BlockType.paragraph);
      expect(blocks[2].type, BlockType.listItem);
      expect(blocks[2].attributes.listType, 'ordered');
      expect(blocks[3].type, BlockType.listItem);
      expect(blocks[3].attributes.listType, 'task');
      expect(blocks[3].attributes.checked, isFalse);
      expect(blocks[4].type, BlockType.heading);
      expect(blocks[4].attributes.isQuoted, isTrue);
      expect(blocks[5], isA<CodeBlockNode>());
      expect(blocks[6], isA<ImageBlockNode>());
      expect((blocks[6] as ImageBlockNode).assetId, 'legacy-image');
      expect(blocks[7], isA<TableBlockNode>());
      expect(
          (blocks[7] as TableBlockNode).table.cellAt(0, 0)?.plainText, 'Cell');
      expect(blocks[8], isA<DividerBlockNode>());
      expect(blocks[9], isA<VideoBlockNode>());

      controller.dispose();
    });

    test('failed (malformed JSON): leaves document untouched, format null', () {
      final controller = WenzRichTextController(document: _doc('original'));
      final before = controller.document;
      var changes = 0;
      controller.onChanged = (_) => changes++;

      final result = controller.tryLoadJsonAuto('{not valid json');

      expect(result.ok, isFalse);
      expect(result.format, isNull);
      expect(result.error, isNotNull);
      expect(controller.document, same(before));
      expect(controller.document.plainText, 'original');
      expect(changes, 0);

      controller.dispose();
    });

    test('empty array is detected as legacy (empty document)', () {
      // wenzflow stores empty notes as "[]" — must not be mistaken for a
      // decode failure.
      final controller = WenzRichTextController(document: _doc('original'));

      final result = controller.tryLoadJsonAuto('[]');

      expect(result.ok, isTrue);
      expect(result.format, JsonLoadFormat.legacy);
      expect(result.document!.blocks, isEmpty);

      controller.dispose();
    });

    test(
        'lazy migration: loaded as legacy, re-saved via toJson() upgrades to '
        'current format', () {
      // This is the core lazy-migration contract — a round-trip through
      // tryLoadJsonAuto + toJson() converts a legacy note to the new format,
      // so the *next* load detects it as current.
      final controller = WenzRichTextController(document: _doc(''));

      const legacyJson =
          '[{"type":"title","level":1,"children":[{"type":"text","text":"升级"}]}]';
      var firstResult = controller.tryLoadJsonAuto(legacyJson);
      expect(firstResult.format, JsonLoadFormat.legacy);

      // Re-save: toJson() always emits the current Rich JSON format.
      final upgradedJson = controller.toJson();
      controller.dispose();

      // Re-load the upgraded payload: it must now be detected as current.
      final controller2 = WenzRichTextController(document: _doc(''));
      var secondResult = controller2.tryLoadJsonAuto(upgradedJson);
      expect(secondResult.ok, isTrue);
      expect(secondResult.format, JsonLoadFormat.current);
      expect(secondResult.document!.plainText, '升级');
      controller2.dispose();
    });
  });
}

RichTextDocument _doc(String text) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: text)],
      ),
    ],
  );
}

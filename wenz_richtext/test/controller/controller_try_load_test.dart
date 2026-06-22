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

      final result =
          controller.tryLoadJson('{bad', legacy: true);

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

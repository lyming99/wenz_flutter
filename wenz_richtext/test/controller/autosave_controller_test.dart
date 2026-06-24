import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  group('WenzAutoSaveController', () {
    test('marks dirty on document changes and ignores selection-only changes', () {
      final host = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final autosave = WenzAutoSaveController(
        editor: host,
        onSave: (_) async {},
      );
      var notifications = 0;
      autosave.addListener(() => notifications++);

      host.setSelection(collapsedTextSelection('p1', 0, 1));

      expect(autosave.isDirty, isFalse);
      expect(autosave.status, AutoSaveStatus.clean);
      expect(notifications, 0);

      host.insertText('A');

      expect(autosave.isDirty, isTrue);
      expect(autosave.status, AutoSaveStatus.scheduled);
      expect(autosave.revision, 1);
      expect(notifications, 1);

      autosave.dispose();
      host.dispose();
    });

    test('debounces saves and marks the current snapshot clean', () async {
      final host = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final saved = <AutoSaveSnapshot>[];
      final autosave = WenzAutoSaveController(
        editor: host,
        debounceDuration: const Duration(milliseconds: 5),
        onSave: (snapshot) async {
          saved.add(snapshot);
        },
      );

      host.insertText('A');
      host.insertText('B');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(saved, hasLength(1));
      expect(saved.single.revision, 2);
      expect(autosave.isDirty, isFalse);
      expect(autosave.status, AutoSaveStatus.clean);
      expect(autosave.lastSavedAt, isNotNull);

      autosave.dispose();
      host.dispose();
    });

    test('failed save keeps dirty state and exposes the error', () async {
      final host = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final autosave = WenzAutoSaveController(
        editor: host,
        debounceDuration: const Duration(seconds: 1),
        onSave: (_) async {
          throw StateError('offline');
        },
      );

      host.insertText('A');
      await autosave.saveNow();

      expect(autosave.isDirty, isTrue);
      expect(autosave.status, AutoSaveStatus.failed);
      expect(autosave.error, isA<StateError>());

      autosave.dispose();
      host.dispose();
    });

    test('markClean supports external persistence flows', () async {
      final host = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      var saves = 0;
      final autosave = WenzAutoSaveController(
        editor: host,
        debounceDuration: const Duration(milliseconds: 20),
        onSave: (_) async {
          saves++;
        },
      );

      host.insertText('A');
      autosave.markClean();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(autosave.isDirty, isFalse);
      expect(autosave.status, AutoSaveStatus.clean);
      expect(autosave.lastSavedAt, isNotNull);
      expect(saves, 0);

      autosave.dispose();
      host.dispose();
    });
  });
}

RichTextDocument _doc() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Hello')],
      ),
    ],
  );
}

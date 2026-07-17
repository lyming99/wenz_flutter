import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('DocumentVersionSnapshot', () {
    test('round trips document, author metadata, and diff placeholders', () {
      final snapshot = DocumentVersionSnapshot(
        id: 'v2',
        document: _doc('Hello'),
        createdAt: DateTime.utc(2026, 6, 24, 10),
        authorId: 'u1',
        authorName: 'Ada',
        description: 'Before publishing',
        baseSnapshotId: 'v1',
        metadata: const <String, Object?>{
          'diff': <String, Object?>{
            'status': 'reserved',
          },
        },
      );
      const codec = DocumentVersionSnapshotJsonCodec();

      final decoded = codec.decode(codec.encode(snapshot));

      expect(decoded.id, 'v2');
      expect(decoded.authorId, 'u1');
      expect(decoded.authorName, 'Ada');
      expect(decoded.description, 'Before publishing');
      expect(decoded.baseSnapshotId, 'v1');
      expect(decoded.metadata['diff'], isA<Map>());
      expect(decoded.restoreDocument().plainText, 'Hello');
      expect(decoded.toJson(), snapshot.toJson());
    });

    test('captures and restores document copies', () {
      final source = _doc('Original');
      final snapshot = DocumentVersionSnapshot(
        id: 'v1',
        document: source,
        createdAt: DateTime.utc(2026, 6, 24),
      );

      source.blocks.clear();
      final restored = snapshot.restoreDocument();
      restored.blocks.clear();

      expect(snapshot.document.plainText, 'Original');
      expect(snapshot.restoreDocument().plainText, 'Original');
    });

    test('codec round trips snapshot lists', () {
      const codec = DocumentVersionSnapshotJsonCodec();
      final snapshots = <DocumentVersionSnapshot>[
        DocumentVersionSnapshot(
          id: 'v1',
          document: _doc('One'),
          createdAt: DateTime.utc(2026, 6, 24),
        ),
        DocumentVersionSnapshot(
          id: 'v2',
          document: _doc('Two'),
          createdAt: DateTime.utc(2026, 6, 25),
          baseSnapshotId: 'v1',
        ),
      ];

      final decoded = codec.decodeList(codec.encodeList(snapshots));

      expect(decoded.map((snapshot) => snapshot.id), <String>['v1', 'v2']);
      expect(decoded.last.restoreDocument().plainText, 'Two');
    });

    test('controller creates and restores version snapshots', () {
      final controller = WenzRichTextController(document: _doc('Draft'));
      final snapshot = controller.createVersionSnapshot(
        id: 'draft-v1',
        createdAt: DateTime.utc(2026, 6, 24),
        authorName: 'Ada',
      );
      var changes = 0;
      controller.onChanged = (_) => changes++;

      controller.replaceDocument(_doc('Changed'));
      controller.restoreVersionSnapshot(snapshot);

      expect(controller.document.plainText, 'Draft');
      expect(snapshot.authorName, 'Ada');
      expect(changes, 2);
    });

    test('invalid snapshot JSON throws a structured decode error', () {
      const codec = DocumentVersionSnapshotJsonCodec();

      expect(
        () => codec.decode('{"id":"bad","document":[]}'),
        throwsA(isA<DocumentDecodeException>()),
      );
      expect(
        () => codec.decodeList('{"not":"a list"}'),
        throwsA(isA<DocumentDecodeException>()),
      );
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

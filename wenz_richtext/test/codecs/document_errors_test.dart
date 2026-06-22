import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

/// C7 — verifies the codecs raise structured [DocumentDecodeException]s instead
/// of leaking raw [FormatException] / [StateError] / cast errors. See
/// `docs/acceptance_report.md` task C7 / acceptance item 9.4.
void main() {
  group('RichTextJsonCodec.decode error handling', () {
    const codec = RichTextJsonCodec();

    test('malformed JSON raises DocumentDecodeException with raw chain', () {
      late DocumentDecodeException caught;
      try {
        codec.decode('{not valid json');
      } on DocumentDecodeException catch (error) {
        caught = error;
      }
      expect(caught.reason, 'Source is not valid JSON.');
      expect(caught.raw, isA<FormatException>());
    });

    test('non-object root raises DocumentDecodeException', () {
      late DocumentDecodeException caught;
      try {
        codec.decode('[]');
      } on DocumentDecodeException catch (error) {
        caught = error;
      }
      expect(caught.reason, 'Rich text JSON must be an object.');
    });

    test('inflation failure is wrapped as DocumentDecodeException', () {
      // `attrs.checked` is a string — `as bool?` throws a type error inside
      // `BlockAttributes.fromJson`, which the codec must wrap.
      final source = jsonEncode(<String, Object?>{
        'version': 1,
        'blocks': <Object?>[
          <String, Object?>{
            'id': 'b1',
            'type': 'paragraph',
            'attrs': <String, Object?>{'checked': 'not-a-bool'},
            'content': <Object?>[],
          },
        ],
      });

      late DocumentDecodeException caught;
      try {
        codec.decode(source);
      } on DocumentDecodeException catch (error) {
        caught = error;
      }
      expect(caught.reason, 'Failed to inflate document from JSON.');
      // The originating type error is preserved for diagnostics.
      expect(caught.raw, isNotNull);
    });

    test('missing migration step surfaces as DocumentDecodeException', () {
      // Registry declares currentVersion 3 but registers nothing, so a
      // version-1 document cannot migrate up.
      final codec = RichTextJsonCodec(
        migrations: DocumentMigrationRegistry(currentVersion: 3),
      );
      final source = jsonEncode(<String, Object?>{
        'version': 1,
        'blocks': <Object?>[],
      });

      late DocumentDecodeException caught;
      try {
        codec.decode(source);
      } on DocumentDecodeException catch (error) {
        caught = error;
      }
      expect(caught.reason, contains('Schema migration failed'));
      expect(caught.raw, isNotNull);
    });

    test('happy path still decodes normally', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'hi')],
          ),
        ],
      );
      final encoded = codec.encode(document);
      final decoded = codec.decode(encoded);
      expect(decoded.plainText, 'hi');
    });
  });

  group('LegacyWenJsonCodec.decode error handling', () {
    const codec = LegacyWenJsonCodec();

    test('malformed JSON raises DocumentDecodeException', () {
      expect(
        () => codec.decode('{broken'),
        throwsA(
          allOf(
            isA<DocumentDecodeException>(),
            predicate<DocumentDecodeException>(
              (e) => e.reason == 'Source is not valid JSON.',
            ),
          ),
        ),
      );
    });

    test('non-list, non-object-with-blocks root raises DocumentDecodeException',
        () {
      expect(
        () => codec.decode('"just a string"'),
        throwsA(
          predicate<DocumentDecodeException>(
            (e) => e.reason == 'Legacy Wen JSON must be a block list.',
          ),
        ),
      );
    });

    test('non-numeric table alignment keys are tolerated, not fatal', () {
      // Older payloads sometimes keyed alignments by string; `int.parse` used
      // to throw a bare FormatException here. Now the bad key is skipped.
      final source = jsonEncode(<String, Object?>{
        'blocks': <Object?>[
          <String, Object?>{
            'type': 'table',
            'id': 't1',
            'alignments': <String, String>{'not-a-number': 'right'},
            'rows': <Object?>[],
          },
        ],
      });
      final decoded = codec.decode(source);
      expect(decoded.blocks, hasLength(1));
      final table = decoded.blocks.single as TableBlockNode;
      expect(table.table.columnAlignments, isEmpty);
    });

    test('non-object block entries are skipped, siblings still decode', () {
      final source = jsonEncode(<String, Object?>{
        'blocks': <Object?>[
          'i-am-a-string-not-a-block',
          <String, Object?>{
            'type': 'text',
            'text': 'kept',
          },
        ],
      });
      final decoded = codec.decode(source);
      expect(decoded.blocks, hasLength(1));
      expect(decoded.plainText, 'kept');
    });

    test('happy path still decodes legacy block list', () {
      const source =
          '[{"type":"text","children":[{"type":"text","text":"Legacy"}]}]';
      final decoded = codec.decode(source);
      expect(decoded.plainText, 'Legacy');
    });
  });

  group('decodeWithMigrations helper', () {
    test('malformed JSON raises DocumentDecodeException', () {
      final registry = DocumentMigrationRegistry()
        ..register(const V1ToV2DocumentMigration());
      expect(
        () => decodeWithMigrations('{bad', registry),
        throwsA(isA<DocumentDecodeException>()),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('DocumentMigrationRegistry', () {
    test('returns the json unchanged when already at currentVersion', () {
      final registry = DocumentMigrationRegistry()
        ..register(const V1ToV2DocumentMigration());
      final json = <String, Object?>{
        'version': 2,
        'blocks': <Object?>[],
      };

      expect(identical(registry.migrateToCurrent(json), json), isTrue);
    });

    test('returns the json unchanged above currentVersion (forward compat)',
        () {
      final registry = DocumentMigrationRegistry()
        ..register(const V1ToV2DocumentMigration());
      final json = <String, Object?>{
        'version': 99,
        'blocks': <Object?>[],
      };

      // Future versions pass through untouched so a newer doc doesn't crash
      // an older reader.
      expect(registry.migrateToCurrent(json)['version'], 99);
    });

    test('treats a missing version field as version 1', () {
      final registry = DocumentMigrationRegistry()
        ..register(const V1ToV2DocumentMigration());
      final json = <String, Object?>{
        'blocks': <Object?>[
          <String, Object?>{'type': 'paragraph'},
        ],
      };

      final migrated = registry.migrateToCurrent(json);
      expect(migrated['version'], 2);
      // The block got a back-filled id.
      final block = (migrated['blocks'] as List).first as Map;
      expect(block['id'], 'block-0');
    });

    test('throws when an intermediate migration step is missing', () {
      // Registry claims currentVersion 3 but only has a v1→v2 step; the
      // v2→v3 hop is absent, so the chain cannot complete.
      final registry = DocumentMigrationRegistry(currentVersion: 3)
        ..register(const V1ToV2DocumentMigration());
      final json = <String, Object?>{
        'version': 1,
        'blocks': <Object?>[],
      };

      expect(() => registry.migrateToCurrent(json), throwsStateError);
    });
  });

  group('V1ToV2DocumentMigration', () {
    test('back-fills missing block ids deterministically', () {
      const migration = V1ToV2DocumentMigration();
      final json = <String, Object?>{
        'version': 1,
        'blocks': <Object?>[
          <String, Object?>{'type': 'paragraph'},
          <String, Object?>{'id': '', 'type': 'paragraph'},
          <String, Object?>{'id': 'keep-me', 'type': 'paragraph'},
        ],
      };

      final migrated = migration.migrate(json);
      expect(migrated['version'], 2);
      final blocks = migrated['blocks'] as List;
      expect((blocks[0] as Map)['id'], 'block-0');
      expect((blocks[1] as Map)['id'], 'block-1');
      // Existing non-empty ids are preserved.
      expect((blocks[2] as Map)['id'], 'keep-me');
    });

    test('canonicalises legacy unordered listType to omitted', () {
      const migration = V1ToV2DocumentMigration();
      final json = <String, Object?>{
        'version': 1,
        'blocks': <Object?>[
          <String, Object?>{
            'id': 'b0',
            'type': 'listItem',
            'attrs': <String, Object?>{'listType': 'unordered'},
          },
          <String, Object?>{
            'id': 'b1',
            'type': 'listItem',
            'attrs': <String, Object?>{'listType': 'li'},
          },
          <String, Object?>{
            'id': 'b2',
            'type': 'listItem',
            'attrs': <String, Object?>{'listType': 'ordered'},
          },
        ],
      };

      final migrated = migration.migrate(json);
      final blocks = migrated['blocks'] as List;
      // 'unordered' and 'li' dropped (canonical = omitted); 'ordered' kept.
      expect((blocks[0] as Map)['attrs'], <String, Object?>{});
      expect((blocks[1] as Map)['attrs'], <String, Object?>{});
      expect(
        ((blocks[2] as Map)['attrs'] as Map)['listType'],
        'ordered',
      );
    });

    test('leaves unrecognised fields untouched', () {
      const migration = V1ToV2DocumentMigration();
      final json = <String, Object?>{
        'version': 1,
        'blocks': <Object?>[],
        'metadata': <String, Object?>{'author': 'seed'},
      };

      final migrated = migration.migrate(json);
      // Unknown top-level fields survive (forward-compatible readers).
      expect(migrated['metadata'], <String, Object?>{'author': 'seed'});
    });
  });

  group('RichTextJsonCodec with migrations', () {
    test('decodes a v1 document through the registry into a v2 model', () {
      final registry = DocumentMigrationRegistry()
        ..register(const V1ToV2DocumentMigration());
      final codec = RichTextJsonCodec(migrations: registry);

      // v1 source: blocks without ids + legacy listType.
      const source = '''
{
  "version": 1,
  "blocks": [
    {"type": "paragraph"},
    {"type": "listItem", "attrs": {"listType": "unordered"}}
  ]
}
''';

      final doc = codec.decode(source);
      expect(doc.version, 2);
      expect(doc.blocks, hasLength(2));
      // Ids were back-filled; listType canonicalised to null by the schema
      // normaliser after inflation.
      expect(doc.blocks[0].id, 'block-0');
      expect(doc.blocks[1].attributes.listType, isNull);
    });

    test('decode without registry leaves version 1 documents as-is', () {
      const codec = RichTextJsonCodec();
      const source = '{"version": 1, "blocks": []}';

      final doc = codec.decode(source);
      expect(doc.version, 1);
    });
  });

  group('decodeWithMigrations helper', () {
    test('parses source and runs the chain', () {
      final registry = DocumentMigrationRegistry()
        ..register(const V1ToV2DocumentMigration());

      const source = '{"version": 1, "blocks": []}';
      final json = decodeWithMigrations(source, registry);

      expect(json['version'], 2);
    });

    test('rejects non-object JSON', () {
      final registry = DocumentMigrationRegistry()
        ..register(const V1ToV2DocumentMigration());

      expect(
        () => decodeWithMigrations('[]', registry),
        throwsA(isA<DocumentDecodeException>()),
      );
    });
  });
}

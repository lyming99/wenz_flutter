import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/src/elements/unknown_element.dart';
import 'package:wenz_draw/src/serialization/canvas_document.dart';
import 'package:wenz_draw/src/serialization/canvas_serializer.dart';
import 'package:wenz_draw/src/serialization/document_format_exception.dart';
import 'package:wenz_draw/src/serialization/document_migrator.dart';

/// Phase C robustness tests: load-time fault tolerance, write-time validation,
/// and the full migration path.
void main() {
  group('Load fault tolerance (C-3)', () {
    test('an element with an unknown type is preserved as UnknownElement', () {
      final json = {
        'schemaVersion': '2.0',
        'layers': <Map<String, dynamic>>[],
        'elements': [
          {
            'type': 'future_flowchart',
            'id': 'fut-1',
            'rect': {'left': 0, 'top': 0, 'right': 10, 'bottom': 10},
            'someNewField': 42,
          },
        ],
      };

      final result = CanvasSerializer.fromJsonWithWarnings(json);
      expect(result.document.elements.length, 1);
      final element = result.document.elements.single;
      expect(element, isA<UnknownElement>());
      final unknown = element as UnknownElement;
      expect(unknown.id, 'fut-1');
      // Raw JSON is preserved verbatim so a newer app can read it back.
      expect(unknown.rawJson['type'], 'future_flowchart');
      expect(unknown.rawJson['someNewField'], 42);
      // Unknown types are NOT a warning — they round-trip silently.
      expect(result.warnings, isEmpty);
    });

    test(
        'a malformed element that throws is downgraded instead of crashing the '
        'document', () {
      final json = {
        'schemaVersion': '2.0',
        'layers': <Map<String, dynamic>>[],
        'elements': [
          // Good element.
          {
            'type': 'rect',
            'id': 'good-1',
            'rect': {'left': 0, 'top': 0, 'right': 50, 'bottom': 50},
          },
          // Bad element: type is null, which triggers the default branch but
          // has no id. We force a parse failure via a bogus structure that
          // elementFromJson cannot handle cleanly.
          {'type': 'rect', 'rect': 'not-a-map'},
          // Non-object entry.
          'just-a-string',
        ],
      };

      final warnings = <DocumentFormatWarning>[];
      final result = CanvasSerializer.fromJsonWithWarnings(
        json,
        onWarning: warnings.add,
      );

      // The good element survives; the bad ones do not abort the load.
      expect(result.document.elements.length, greaterThanOrEqualTo(1));
      expect(result.document.elements.any((e) => e.id == 'good-1'), isTrue);
      expect(result.hasWarnings, isTrue);
      expect(result.warnings, equals(warnings));
    });

    test('a negative-width rect is kept and reported as a warning', () {
      final json = {
        'schemaVersion': '2.0',
        'layers': <Map<String, dynamic>>[],
        'elements': [
          {
            'type': 'rect',
            'id': 'bad-rect',
            // right < left → negative width.
            'rect': {'left': 100, 'top': 0, 'right': 50, 'bottom': 50},
          },
        ],
      };

      final result = CanvasSerializer.fromJsonWithWarnings(json);
      expect(result.document.elements.length, 1);
      expect(result.warnings.length, 1);
      expect(result.warnings.first.field, 'rect');
      expect(result.warnings.first.elementId, 'bad-rect');
    });

    test('fatal: layers is not an array throws DocumentFormatException', () {
      final json = {
        'schemaVersion': '2.0',
        'layers': 'should-be-a-list',
        'elements': <Map<String, dynamic>>[],
      };
      expect(
        () => CanvasSerializer.fromJson(json),
        throwsA(isA<DocumentFormatException>()),
      );
    });

    test('fatal: empty document throws', () {
      expect(
        () => CanvasSerializer.fromJson(<String, dynamic>{}),
        throwsA(isA<DocumentFormatException>()),
      );
    });
  });

  group('Write validation (C-1)', () {
    test('validateForSave returns no warnings for a clean document', () {
      final json = {
        'schemaVersion': '2.0',
        'elements': [
          {
            'type': 'rect',
            'id': 'r1',
            'rect': {'left': 0, 'top': 0, 'right': 10, 'bottom': 10},
          },
        ],
      };
      expect(CanvasSerializer.validateForSave(json), isEmpty);
    });

    test('validateForSave flags missing id', () {
      final json = {
        'elements': [
          {
            'type': 'rect',
            'rect': {'left': 0, 'top': 0, 'right': 10, 'bottom': 10},
          },
        ],
      };
      final warnings = CanvasSerializer.validateForSave(json);
      expect(warnings.length, 1);
      expect(warnings.first.field, 'id');
    });

    test('validateForSave flags negative rect', () {
      final json = {
        'elements': [
          {
            'type': 'rect',
            'id': 'r1',
            'rect': {'left': 100, 'top': 0, 'right': 50, 'bottom': 50},
          },
        ],
      };
      final warnings = CanvasSerializer.validateForSave(json);
      expect(warnings.length, 1);
      expect(warnings.first.field, 'rect');
    });

    test('validateForSave flags non-object element', () {
      final json = {
        'elements': ['a-string', 42],
      };
      final warnings = CanvasSerializer.validateForSave(json);
      expect(warnings.length, 2);
    });

    test('validateForSave is a no-op on empty / non-document maps', () {
      expect(CanvasSerializer.validateForSave(<String, dynamic>{}), isEmpty);
      expect(CanvasSerializer.validateForSave({'foo': 'bar'}), isEmpty);
    });
  });

  group('Migration path (C-4)', () {
    test('schema-1.0 upgrades to 2.0 and seeds optional sections', () {
      final migrated = DocumentMigrator.migrate({
        'version': '1.0',
        'layers': [
          {'id': 'l1', 'name': 'Layer'},
        ],
        'elements': [
          {
            'type': 'rect',
            'id': 'r1',
            'rect': {'left': 0, 'top': 0, 'right': 10, 'bottom': 10},
          },
        ],
      });
      expect(migrated['schemaVersion'], '2.0');
      expect(migrated.containsKey('version'), isFalse);
      expect(migrated['metadata'], isA<Map>());
      expect(migrated['viewport'], isA<Map>());
      expect(migrated['assets'], isA<List>());
      // Element data is untouched.
      expect((migrated['elements'] as List).length, 1);
    });

    test('schema-1.1 upgrades to 2.0', () {
      final migrated = DocumentMigrator.migrate({
        'version': '1.1',
        'layers': <Map<String, dynamic>>[],
        'elements': <Map<String, dynamic>>[],
      });
      expect(migrated['schemaVersion'], '2.0');
      expect(migrated.containsKey('version'), isFalse);
    });

    test('schema-2.0 passes through unchanged', () {
      final doc = {
        'schemaVersion': '2.0',
        'metadata': {'title': 'X'},
        'layers': <Map<String, dynamic>>[],
        'elements': <Map<String, dynamic>>[],
      };
      final migrated = DocumentMigrator.migrate(Map<String, dynamic>.from(doc));
      expect(migrated['schemaVersion'], '2.0');
      expect(migrated['metadata']['title'], 'X');
    });

    test('a future/unknown schema version is left as-is (no corruption)', () {
      final doc = {
        'schemaVersion': '9.9',
        'futureField': {'keepMe': true},
        'layers': <Map<String, dynamic>>[],
        'elements': <Map<String, dynamic>>[],
      };
      final migrated = DocumentMigrator.migrate(Map<String, dynamic>.from(doc));
      // Unknown version: migrator does not touch it.
      expect(migrated['schemaVersion'], '9.9');
      expect(migrated['futureField']['keepMe'], isTrue);
    });

    test('a document with no version key is treated as current', () {
      final migrated = DocumentMigrator.migrate({
        'layers': <Map<String, dynamic>>[],
        'elements': <Map<String, dynamic>>[],
      });
      expect(migrated['schemaVersion'], DocumentSchema.current);
    });

    test('full round-trip: legacy 1.0 loads into a 2.0 document', () {
      final json = CanvasSerializer.fromJson({
        'version': '1.0',
        'layers': [
          {'id': 'main', 'name': 'Main'},
        ],
        'elements': [
          {
            'type': 'rect',
            'id': 'r1',
            'rect': {'left': 0, 'top': 0, 'right': 40, 'bottom': 40},
          },
        ],
      });
      expect(json.schemaVersion, '2.0');
      expect(json.layers.first.id, 'main');
      expect(json.elements.first.id, 'r1');
    });
  });

  group('Round-trip matrix (C-6)', () {
    test('a mixed document survives save → validate → load → reload', () {
      // Build a representative document with several element kinds.
      final original = {
        'schemaVersion': '2.0',
        'metadata': {'title': 'Matrix', 'appId': 'test'},
        'viewport': {'scale': 1.25, 'centerX': 100, 'centerY': 200},
        'layers': [
          {'id': 'main', 'name': 'Main'},
          {'id': 'notes', 'name': 'Notes', 'visible': false},
        ],
        'elements': [
          {
            'type': 'rect',
            'id': 'r1',
            'rect': {'left': 0, 'top': 0, 'right': 80, 'bottom': 60},
            'label': 'Box',
          },
          {
            'type': 'ellipse',
            'id': 'e1',
            'rect': {'left': 100, 'top': 100, 'right': 200, 'bottom': 180},
          },
          {
            'type': 'text',
            'id': 't1',
            'position': {'x': 10, 'y': 10},
            'text': 'Hello',
          },
        ],
      };

      // 1. Pre-save validation is clean.
      expect(CanvasSerializer.validateForSave(original), isEmpty);

      // 2. Load.
      final loaded = CanvasSerializer.fromJson(original);
      expect(loaded.metadata.title, 'Matrix');
      expect(loaded.viewport.scale, 1.25);
      expect(loaded.layers.length, 2);
      expect(loaded.layers[1].isVisible, isFalse);
      expect(loaded.elements.length, 3);
      expect(loaded.elements.map((e) => e.id).toSet(), {'r1', 'e1', 't1'});

      // 3. Re-serialize and reload — values must be stable across two passes.
      final reserialized = loaded.toJson();
      final reloaded = CanvasSerializer.fromJson(reserialized);
      expect(reloaded.metadata.title, 'Matrix');
      expect(reloaded.viewport.scale, 1.25);
      expect(reloaded.elements.map((e) => e.id).toSet(), {'r1', 'e1', 't1'});
    });

    test('unknown elements survive multiple round-trips verbatim', () {
      final original = {
        'schemaVersion': '2.0',
        'layers': <Map<String, dynamic>>[],
        'elements': [
          {
            'type': 'novel_element',
            'id': 'novel-1',
            'payload': {'x': 1, 'nested': [1, 2, 3]},
          },
        ],
      };

      var doc = CanvasSerializer.fromJson(original);
      for (var i = 0; i < 3; i++) {
        doc = CanvasSerializer.fromJson(doc.toJson());
        final element = doc.elements.single as UnknownElement;
        expect(element.id, 'novel-1');
        expect(element.rawJson['type'], 'novel_element');
        expect(element.rawJson['payload']['nested'], [1, 2, 3]);
      }
    });
  });
}

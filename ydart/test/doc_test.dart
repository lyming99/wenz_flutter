import 'package:test/test.dart';
import 'package:ydart/utils/y_doc.dart';

void main() {
  group('YDocTests', () {
    late YDoc doc1;
    late YDoc doc2;

    setUp(() {
      doc1 = YDoc();
      doc1.clientId = 0;
      doc2 = YDoc();
      doc2.clientId = 0;
      expect(doc1.clientId, equals(doc2.clientId));

      doc1.getArray('a').insert(0, [1, 2]);
      doc2.applyUpdateV2(doc1.encodeStateAsUpdateV2());
      expect(doc1.clientId, isNot(equals(doc2.clientId)));
    });

    test('TestClientIdDuplicateChange', () {
      expect(doc1.clientId, isNot(equals(doc2.clientId)));
    });

    test('TestGetTypeEmptyId', () {
      doc1.getText('').insert(0, 'h');
      doc1.getText().insert(1, 'i');

      doc2.applyUpdateV2(doc1.encodeStateAsUpdateV2());

      expect(doc2.getText().toString(), equals('hi'));
      expect(doc2.getText('').toString(), equals('hi'));
    });

    test('TestSubdoc', () {
      YDoc doc = YDoc();
      doc.load();

      {
        late List<List<String>> events;
        doc.subdocsChanged.add((loaded, added, removed) {
          events = [
            added.map((d) => d.guid).toList(),
            removed.map((d) => d.guid).toList(),
            loaded.map((d) => d.guid).toList(),
          ];
        });

        var subdocs = doc.getMap('mysubdocs');
        var docA = YDoc(YDocOptions()..guid = 'a');
        docA.load();
        subdocs.set('a', docA);
        expect(events[0], equals(['a']));
        expect(events[1], equals([]));
        expect(events[2], equals(['a']));
        events = [];
        (subdocs.get('a') as YDoc).load();
        expect(events, equals([]));
        events = [];

        (subdocs.get('a') as YDoc).destroy();
        expect(events[0], equals(['a']));
        expect(events[1], equals(['a']));
        expect(events[2], equals([]));
        events = [];

        (subdocs.get('a') as YDoc).load();
        expect(events[0], equals([]));
        expect(events[1], equals([]));
        expect(events[2], equals(['a']));
        events = [];

        subdocs.set('b', YDoc(YDocOptions()..guid = 'a'));
        expect(events[0], equals(['a']));
        expect(events[1], equals([]));
        expect(events[2], equals([]));
        events = [];

        (subdocs.get('b') as YDoc).load();
        expect(events[0], equals([]));
        expect(events[1], equals([]));
        expect(events[2], equals(['a']));
        events = [];

        var docC = YDoc(YDocOptions()..guid = 'c');
        docC.load();
        subdocs.set('c', docC);
        expect(events[0], equals(['c']));
        expect(events[1], equals([]));
        expect(events[2], equals(['c']));
        events = [];

        var guids = doc.subdocs.map((e) => e.guid).toSet().toList();
        guids.sort();
        expect(guids, equals(['a', 'c']));
      }

      var doc2 = YDoc();
      {

        expect(doc2.getSubdocGuids().length, equals(0));

        late List<List<String>> events;
        doc2.subdocsChanged.add((loaded, added, removed) {
          events = [
            added.map((d) => d.guid).toList(),
            removed.map((d) => d.guid).toList(),
            loaded.map((d) => d.guid).toList(),
          ];
        });
        doc2.applyUpdateV2(doc.encodeStateAsUpdateV2());
        expect(events[0], equals(['a', 'a', 'c']));
        expect(events[1], equals([]));
        expect(events[2], equals([]));
        events = [];

        (doc2.getMap('mysubdocs').get('a') as YDoc).load();
        expect(events[0], equals([]));
        expect(events[1], equals([]));
        expect(events[2], equals(['a']));
        events = [];

        var guids = doc2.getSubdocGuids().toList();
        guids.sort();
        expect(guids, equals(['a', 'c']));

        doc2.getMap('mysubdocs').delete('a');
        expect(events[0], equals([]));
        expect(events[1], equals(['a']));
        expect(events[2], equals([]));
        events = [];

        guids = doc2.getSubdocGuids().toList();
        guids.sort();
        expect(guids, equals(['a', 'c']));
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';
import 'package:wenz_draw/wenz_draw_mindmap.dart';

void main() {
  group('MindmapNodeData serialization', () {
    test('round-trips through widgetData', () {
      const data = MindmapNodeData(
        id: 'n1',
        text: 'Branch',
        parentId: 'root',
        side: MindmapNodeSide.right,
        isCollapsed: false,
        isRoot: false,
        order: 2,
        color: 0xFFE3F2FD,
        textColor: 0xFF1F2937,
        fillColor: 0xFFAA0000,
        todoEnabled: true,
        todoDone: false,
        linkUrl: 'https://example.com',
      );

      final restored = MindmapNodeData.fromWidgetData(data.toWidgetData());

      expect(restored.id, 'n1');
      expect(restored.text, 'Branch');
      expect(restored.parentId, 'root');
      expect(restored.side, MindmapNodeSide.right);
      expect(restored.isRoot, isFalse);
      expect(restored.order, 2);
      expect(restored.fillColor, 0xFFAA0000);
      expect(restored.todoEnabled, isTrue);
      expect(restored.linkUrl, 'https://example.com');
    });

    test('omits nullable fields when unset', () {
      const data = MindmapNodeData(id: 'n2', text: 'Leaf');
      final json = data.toWidgetData();
      expect(json.containsKey('parentId'), isFalse);
      expect(json.containsKey('fillColor'), isFalse);
      expect(json.containsKey('linkUrl'), isFalse);
    });
  });

  group('MindmapNode tree', () {
    test('find and findParent walk the tree', () {
      final root = MindmapNode(
        id: 'root',
        text: 'Root',
        children: [
          MindmapNode(id: 'a', text: 'A', children: [
            MindmapNode(id: 'a1', text: 'A1'),
          ]),
          MindmapNode(id: 'b', text: 'B'),
        ],
      );

      expect(root.find('a1')?.text, 'A1');
      expect(root.find('missing'), isNull);
      expect(root.findParent('a1')?.id, 'a');
      expect(root.findParent('a')?.id, 'root');
      expect(root.findParent('root'), isNull);
    });

    test('clone is deep', () {
      final original = MindmapNode(
        id: 'root',
        text: 'Root',
        children: [MindmapNode(id: 'c', text: 'C')],
      );
      final copy = original.clone();
      copy.children.first.text = 'Changed';

      expect(copy.children.first.text, 'Changed');
      expect(original.children.first.text, 'C');
    });
  });

  group('MindmapNodeSide', () {
    test('fromString parses known and unknown values', () {
      expect(MindmapNodeSide.fromString('right'), MindmapNodeSide.right);
      expect(MindmapNodeSide.fromString('left'), MindmapNodeSide.left);
      expect(MindmapNodeSide.fromString('center'), MindmapNodeSide.center);
      expect(MindmapNodeSide.fromString(null), MindmapNodeSide.center);
      expect(MindmapNodeSide.fromString('bogus'), MindmapNodeSide.center);
    });

    test('toValueString round-trips', () {
      for (final side in MindmapNodeSide.values) {
        expect(MindmapNodeSide.fromString(side.toValueString()), side);
      }
    });
  });

  group('registerMindmapModule', () {
    tearDown(unregisterMindmapModule);

    test('registers the mindmap_node builder', () {
      registerMindmapModule();
      expect(
        WidgetElementRegistry.hasBuilder(kMindmapNodeWidgetType),
        isTrue,
      );
    });

    test('installs the provided link opener', () async {
      final opener = _RecordingLinkOpener();
      registerMindmapModule(linkOpener: opener);

      final opened = await MindmapLinkOpenerHolder.current.open(
        Uri.parse('https://example.com'),
      );

      expect(opened, isTrue);
      expect(opener.calls.single.toString(), 'https://example.com');
    });

    test('defaults to a no-op link opener', () {
      MindmapLinkOpenerHolder.reset();
      expect(
        MindmapLinkOpenerHolder.current,
        isNot(isA<_RecordingLinkOpener>()),
      );
    });

    test('unregisterMindmapModule removes builder and resets opener', () {
      registerMindmapModule(linkOpener: _RecordingLinkOpener());
      unregisterMindmapModule();
      expect(
        WidgetElementRegistry.hasBuilder(kMindmapNodeWidgetType),
        isFalse,
      );
    });
  });
}

class _RecordingLinkOpener implements MindmapLinkOpener {
  final List<Uri> calls = [];

  @override
  Future<bool> open(Uri uri) async {
    calls.add(uri);
    return true;
  }
}

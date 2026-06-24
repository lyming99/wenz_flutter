import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  group('Wenz collaboration adapter', () {
    test('remote selection updates round trip through JSON', () {
      final updatedAt = DateTime.utc(2026, 6, 24, 9);
      final update = WenzRemoteSelectionUpdate(
        clientId: 'client-b',
        peer: const WenzCollaborationPeer(
          id: 'user-b',
          displayName: 'Bob',
          color: 0xFF3366FF,
        ),
        selection: DocumentSelection(
          base: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 2,
          ),
          extent: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 8,
          ),
        ),
        updatedAt: updatedAt,
        metadata: const <String, Object?>{'source': 'test'},
      );

      final decoded = WenzRemoteSelectionUpdate.fromJson(update.toJson());

      expect(decoded, update);
      expect(decoded.isClear, isFalse);
      expect(decoded.isCursor, isFalse);
    });

    test('controller publishes local document and selection changes', () async {
      final host = WenzRichTextController(
        document: _doc('Hello'),
        selection: collapsedTextSelection('p1', 0, 5),
      );
      var hostCallbackCount = 0;
      host.onChanged = (_) => hostCallbackCount++;
      final adapter = _FakeCollaborationAdapter();
      final collaboration = WenzCollaborationController(
        editor: host,
        adapter: adapter,
        localClientId: 'client-a',
        localPeer: const WenzCollaborationPeer(
          id: 'user-a',
          displayName: 'Alice',
        ),
        clock: () => DateTime.utc(2026, 6, 24, 10),
      );

      host.insertText('!');
      await Future<void>.delayed(Duration.zero);

      expect(hostCallbackCount, 1);
      expect(collaboration.localRevision, 1);
      expect(adapter.documentChanges, hasLength(1));
      expect(adapter.documentChanges.single.clientId, 'client-a');
      expect(adapter.documentChanges.single.document.plainText, 'Hello!');
      expect(adapter.documentChanges.single.changedBlockIds, <String>{'p1'});
      expect(adapter.selectionUpdates, hasLength(1));
      expect(adapter.selectionUpdates.single.selection?.extent.offset, 6);

      host.setSelection(collapsedTextSelection('p1', 0, 0));
      await Future<void>.delayed(Duration.zero);

      expect(adapter.documentChanges, hasLength(1));
      expect(adapter.selectionUpdates, hasLength(2));
      expect(adapter.selectionUpdates.last.selection?.extent.offset, 0);

      collaboration.dispose();
      await adapter.close();
      host.dispose();
    });

    test('controller applies remote updates without echoing them', () async {
      final host = WenzRichTextController(
        document: _doc('Local'),
        selection: collapsedTextSelection('p1', 0, 5),
      );
      final adapter = _FakeCollaborationAdapter();
      final collaboration = WenzCollaborationController(
        editor: host,
        adapter: adapter,
        localClientId: 'client-a',
      );
      var notifications = 0;
      collaboration.addListener(() => notifications++);

      adapter.emitDocumentUpdate(
        WenzRemoteDocumentUpdate(
          clientId: 'client-b',
          document: _doc('Remote'),
          selection: collapsedTextSelection('p1', 0, 6),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(host.document.plainText, 'Remote');
      expect(host.selection?.extent.offset, 6);
      expect(adapter.documentChanges, isEmpty);

      adapter.emitSelectionUpdate(
        WenzRemoteSelectionUpdate(
          clientId: 'client-b',
          selection: collapsedTextSelection('p1', 0, 3),
          updatedAt: DateTime.utc(2026, 6, 24, 11),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(collaboration.remoteSelections, hasLength(1));
      expect(collaboration.remoteSelections.single.isCursor, isTrue);
      expect(notifications, 1);

      adapter.emitSelectionUpdate(
        WenzRemoteSelectionUpdate(
          clientId: 'client-b',
          updatedAt: DateTime.utc(2026, 6, 24, 12),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(collaboration.remoteSelections, isEmpty);
      expect(notifications, 2);

      collaboration.dispose();
      await adapter.close();
      host.dispose();
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

class _FakeCollaborationAdapter extends WenzCollaborationAdapter {
  final StreamController<WenzRemoteDocumentUpdate> _documentUpdates =
      StreamController<WenzRemoteDocumentUpdate>.broadcast();
  final StreamController<WenzRemoteSelectionUpdate> _selectionUpdates =
      StreamController<WenzRemoteSelectionUpdate>.broadcast();

  final List<WenzLocalDocumentChange> documentChanges =
      <WenzLocalDocumentChange>[];
  final List<WenzRemoteSelectionUpdate> selectionUpdates =
      <WenzRemoteSelectionUpdate>[];

  @override
  Stream<WenzRemoteDocumentUpdate> get remoteDocumentUpdates {
    return _documentUpdates.stream;
  }

  @override
  Stream<WenzRemoteSelectionUpdate> get remoteSelectionUpdates {
    return _selectionUpdates.stream;
  }

  @override
  Future<void> publishDocumentChange(WenzLocalDocumentChange change) async {
    documentChanges.add(change);
  }

  @override
  Future<void> publishSelection(WenzRemoteSelectionUpdate update) async {
    selectionUpdates.add(update);
  }

  void emitDocumentUpdate(WenzRemoteDocumentUpdate update) {
    _documentUpdates.add(update);
  }

  void emitSelectionUpdate(WenzRemoteSelectionUpdate update) {
    _selectionUpdates.add(update);
  }

  @override
  Future<void> close() async {
    await _documentUpdates.close();
    await _selectionUpdates.close();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  test('comment anchor round trips document selection semantics', () {
    final selection = DocumentSelection(
      base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 2),
      extent: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 7),
    );

    final anchor = CommentAnchor.fromSelection(selection);
    final decoded = CommentAnchor.fromJson(anchor.toJson());

    expect(anchor.selection, selection);
    expect(decoded, anchor);
    expect(decoded.selection, selection);
  });

  test('text attributes can mark inline comment anchors', () {
    const attributes = TextAttributes(
      remark: true,
      commentIds: <String>['thread-1'],
    );

    final decoded = TextAttributes.fromJson(attributes.toJson());

    expect(decoded.commentIds, <String>['thread-1']);
    expect(decoded.remark, isTrue);
    expect(decoded.isEmpty, isFalse);
    expect(decoded, attributes);
  });

  test('rich JSON saves and restores comment threads with document', () {
    final thread = _thread();
    final document = RichTextDocument(
      blocks: <BlockNode>[
        const TextBlockNode(
          id: 'p1',
          type: BlockType.paragraph,
          content: <InlineNode>[
            TextRun(
              text: 'Hello comments',
              attributes: TextAttributes(commentIds: <String>['thread-1']),
            ),
          ],
        ),
      ],
      comments: <CommentThread>[thread],
    );

    const codec = RichTextJsonCodec();
    final decoded = codec.decode(codec.encode(document));
    final decodedRun = (decoded.blocks.single as TextBlockNode).content.single;

    expect(decoded.comments, <CommentThread>[thread]);
    expect((decodedRun as TextRun).attributes.commentIds, <String>['thread-1']);
  });

  test('comment thread status helpers resolve and reopen', () {
    final resolvedAt = DateTime.utc(2026, 1, 3, 9);
    final reopenedAt = DateTime.utc(2026, 1, 4, 9);

    final resolved = _thread().resolve(resolvedAt: resolvedAt);
    final reopened = resolved.reopen(updatedAt: reopenedAt);

    expect(resolved.isResolved, isTrue);
    expect(resolved.resolvedAt, resolvedAt);
    expect(reopened.isOpen, isTrue);
    expect(reopened.resolvedAt, isNull);
    expect(reopened.updatedAt, reopenedAt);
  });
}

CommentThread _thread() {
  return CommentThread(
    id: 'thread-1',
    anchor: CommentAnchor(
      blockId: 'p1',
      blockIndex: 0,
      path: PositionPath.blockText('p1'),
      startOffset: 2,
      endOffset: 7,
    ),
    messages: <CommentEntry>[
      CommentEntry(
        id: 'message-1',
        authorId: 'u1',
        authorName: 'Alice',
        text: 'Please clarify this sentence.',
        createdAt: DateTime.utc(2026, 1, 2, 8, 30),
      ),
    ],
    createdAt: DateTime.utc(2026, 1, 2, 8, 30),
  );
}

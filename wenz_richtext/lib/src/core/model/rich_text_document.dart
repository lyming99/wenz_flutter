import 'block_node.dart';
import 'comment_model.dart';
import 'revision_model.dart';

class RichTextDocument {
  const RichTextDocument({
    this.version = 1,
    this.blocks = const <BlockNode>[],
    this.comments = const <CommentThread>[],
    this.revisions = const <RevisionChange>[],
  });

  final int version;
  final List<BlockNode> blocks;
  final List<CommentThread> comments;
  final List<RevisionChange> revisions;

  bool get isEmpty => blocks.isEmpty || plainText.isEmpty;

  String get plainText => blocks.map((block) => block.plainText).join('\n');

  RichTextDocument copy() {
    return RichTextDocument(
      version: version,
      blocks: blocks.map((block) => block.copy()).toList(),
      comments: comments.map((thread) => thread.copy()).toList(),
      revisions: revisions.map((revision) => revision.copy()).toList(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': version,
      'blocks': blocks.map((block) => block.toJson()).toList(),
      if (comments.isNotEmpty)
        'comments': comments.map((thread) => thread.toJson()).toList(),
      if (revisions.isNotEmpty)
        'revisions': revisions.map((revision) => revision.toJson()).toList(),
    };
  }

  factory RichTextDocument.fromJson(Map<String, Object?> json) {
    final rawBlocks = json['blocks'];
    final rawComments = json['comments'];
    final rawRevisions = json['revisions'];
    return RichTextDocument(
      version: _asInt(json['version'], fallback: 1),
      blocks: rawBlocks is List
          ? rawBlocks
              .whereType<Map>()
              .map(
                (block) => BlockNode.fromJson(Map<String, Object?>.from(block)),
              )
              .toList()
          : const <BlockNode>[],
      comments: rawComments is List
          ? rawComments
              .whereType<Map>()
              .map((thread) => CommentThread.fromJson(
                    Map<String, Object?>.from(thread),
                  ))
              .toList()
          : const <CommentThread>[],
      revisions: rawRevisions is List
          ? rawRevisions
              .whereType<Map>()
              .map((revision) => RevisionChange.fromJson(
                    Map<String, Object?>.from(revision),
                  ))
              .toList()
          : const <RevisionChange>[],
    );
  }
}

int _asInt(Object? value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

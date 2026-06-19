import 'dart:convert';

import '../model/rich_text_document.dart';
import '../position/document_position.dart';

class ChangeSet {
  const ChangeSet({
    required this.before,
    required this.after,
    this.selectionBefore,
    this.selectionAfter,
    this.description = '',
    this.metadata,
  });

  final RichTextDocument before;
  final RichTextDocument after;
  final DocumentSelection? selectionBefore;
  final DocumentSelection? selectionAfter;
  final String description;

  /// Optional command metadata for observers such as command pipeline hooks.
  final Map<String, Object?>? metadata;

  bool get isNoop => jsonEncode(before.toJson()) == jsonEncode(after.toJson());
}

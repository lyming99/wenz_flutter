import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../codecs/markdown_codec.dart';
import '../codecs/plain_text_codec.dart';
import '../codecs/rich_text_json_codec.dart';
import '../core/model/rich_text_document.dart';

@immutable
class DocumentExportSnapshot {
  const DocumentExportSnapshot({
    required this.json,
    required this.markdown,
    required this.plainText,
  });

  final String json;
  final String markdown;
  final String plainText;
}

/// Builds all persistence formats from one immutable document revision.
///
/// Large hosts can set [useIsolate] to move codec and JSON work off the UI
/// isolate. The caller remains responsible for comparing its revision after
/// await and scheduling another snapshot when newer edits arrived.
Future<DocumentExportSnapshot> buildDocumentExportSnapshot(
  RichTextDocument document, {
  bool useIsolate = false,
}) {
  if (!useIsolate) {
    return SynchronousFuture<DocumentExportSnapshot>(
      _encodeDocumentSnapshot(document),
    );
  }
  final detachedSnapshot = document.asPersistentSnapshot();
  return Isolate.run(() => _encodeDocumentSnapshot(detachedSnapshot));
}

DocumentExportSnapshot _encodeDocumentSnapshot(RichTextDocument document) {
  return DocumentExportSnapshot(
    json: const RichTextJsonCodec().encode(document),
    markdown: const MarkdownCodec().encode(document),
    plainText: const PlainTextCodec().encode(document),
  );
}

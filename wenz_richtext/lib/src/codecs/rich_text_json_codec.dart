import 'dart:convert';

import '../core/model/rich_text_document.dart';
import 'document_errors.dart';
import 'document_migration.dart';

class RichTextJsonCodec {
  const RichTextJsonCodec({this.migrations});

  /// Optional migration registry applied during [decode] to lift older
  /// schema versions up to the current one before inflating the model.
  /// `null` (default) means documents are decoded as-is — callers loading
  /// legacy data should pass a registry with the relevant steps registered.
  final DocumentMigrationRegistry? migrations;

  String encode(RichTextDocument document) {
    return jsonEncode(document.toJson());
  }

  /// Decodes [source] into a [RichTextDocument].
  ///
  /// Always throws a [DocumentDecodeException] on failure (malformed JSON,
  /// wrong root type, a gap in the migration chain, or an invalid block
  /// shape); the originating error is preserved on [DocumentDecodeException.raw].
  /// Use `WenzRichTextController.tryLoadJson` for a no-throw entry point.
  RichTextDocument decode(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw DocumentDecodeException(
        'Source is not valid JSON.',
        raw: error,
      );
    }
    if (decoded is! Map) {
      throw const DocumentDecodeException(
        'Rich text JSON must be an object.',
      );
    }
    var json = Map<String, Object?>.from(decoded);
    final registry = migrations;
    if (registry != null) {
      try {
        json = registry.migrateToCurrent(json);
      } on Object catch (error) {
        throw DocumentDecodeException(
          'Schema migration failed: $error',
          raw: error,
        );
      }
    }
    try {
      return RichTextDocument.fromJson(json);
    } on DocumentDecodeException {
      rethrow;
    } on Object catch (error) {
      throw DocumentDecodeException(
        'Failed to inflate document from JSON.',
        raw: error,
      );
    }
  }
}

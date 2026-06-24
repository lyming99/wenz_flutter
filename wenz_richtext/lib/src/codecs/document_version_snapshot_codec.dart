import 'dart:convert';

import '../core/model/document_version_snapshot.dart';
import 'document_errors.dart';

/// JSON codec for application-owned document version snapshots.
class DocumentVersionSnapshotJsonCodec {
  const DocumentVersionSnapshotJsonCodec();

  String encode(DocumentVersionSnapshot snapshot) {
    return jsonEncode(snapshot.toJson());
  }

  DocumentVersionSnapshot decode(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw DocumentDecodeException(
        'Version snapshot JSON is not valid JSON.',
        raw: error,
      );
    }
    if (decoded is! Map) {
      throw const DocumentDecodeException(
        'Version snapshot JSON must be an object.',
      );
    }
    try {
      return DocumentVersionSnapshot.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } on DocumentDecodeException {
      rethrow;
    } on Object catch (error) {
      throw DocumentDecodeException(
        'Failed to inflate version snapshot from JSON.',
        raw: error,
      );
    }
  }

  String encodeList(Iterable<DocumentVersionSnapshot> snapshots) {
    return jsonEncode(
      snapshots.map((snapshot) => snapshot.toJson()).toList(growable: false),
    );
  }

  List<DocumentVersionSnapshot> decodeList(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw DocumentDecodeException(
        'Version snapshot list JSON is not valid JSON.',
        raw: error,
      );
    }
    if (decoded is! List) {
      throw const DocumentDecodeException(
        'Version snapshot list JSON must be an array.',
      );
    }
    try {
      return decoded
          .map((item) => DocumentVersionSnapshot.fromJson(
                Map<String, Object?>.from(item as Map),
              ))
          .toList(growable: false);
    } on DocumentDecodeException {
      rethrow;
    } on Object catch (error) {
      throw DocumentDecodeException(
        'Failed to inflate version snapshot list from JSON.',
        raw: error,
      );
    }
  }
}

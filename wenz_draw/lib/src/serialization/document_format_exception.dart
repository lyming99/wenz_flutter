/// Thrown when a canvas document fails structural validation.
///
/// The loader distinguishes two severities so hosts can decide whether to abort
/// or salvage a partially-corrupt document:
///
/// - [DocumentFormatSeverity.fatal] — the document is unusable (not a map,
///   wrong schema, missing the `elements`/`layers` sections entirely). The
///   loader rethrows these; the host should show an error.
/// - [DocumentFormatSeverity.recoverable] — an individual element is malformed
///   (bad `type`, negative rect, missing `id`). The loader skips the element,
///   preserves its raw JSON as an `UnknownElement`, and reports the problem via
///   the optional [DocumentFormatWarning] callback. Loading continues.
class DocumentFormatException implements Exception {
  const DocumentFormatException(
    this.message, {
    this.severity = DocumentFormatSeverity.fatal,
    this.elementId,
    this.elementType,
    this.field,
  });

  /// Human-readable description of what failed.
  final String message;

  /// Whether the host can keep going ([recoverable]) or must abort ([fatal]).
  final DocumentFormatSeverity severity;

  /// The id of the offending element, when known.
  final String? elementId;

  /// The declared `type` of the offending element, when known.
  final String? elementType;

  /// The specific field that failed validation, when applicable.
  final String? field;

  @override
  String toString() {
    final parts = <String>['DocumentFormatException($severity): $message'];
    if (elementType != null) parts.add('type=$elementType');
    if (elementId != null) parts.add('id=$elementId');
    if (field != null) parts.add('field=$field');
    return parts.join(' ');
  }
}

/// Severity of a [DocumentFormatException].
enum DocumentFormatSeverity {
  /// The whole document cannot be loaded; the loader rethrows.
  fatal,

  /// Only part of the document is bad; the loader skips and continues.
  recoverable,
}

/// A recoverable problem reported during loading rather than thrown, so a
/// single bad element does not sink the whole document.
///
/// Hosts pass a callback to `CanvasSerializer.fromJson` (or `loadDocument`) to
/// collect these — e.g. to log them or surface a "N elements skipped" toast.
class DocumentFormatWarning {
  const DocumentFormatWarning(
    this.message, {
    this.elementId,
    this.elementType,
    this.field,
    this.rawJson,
  });

  final String message;
  final String? elementId;
  final String? elementType;
  final String? field;

  /// The original JSON of the element that was skipped/downgraded, if any.
  final Map<String, dynamic>? rawJson;

  DocumentFormatException toException() => DocumentFormatException(
        message,
        severity: DocumentFormatSeverity.recoverable,
        elementId: elementId,
        elementType: elementType,
        field: field,
      );

  @override
  String toString() {
    final parts = <String>['Warning: $message'];
    if (elementType != null) parts.add('type=$elementType');
    if (elementId != null) parts.add('id=$elementId');
    if (field != null) parts.add('field=$field');
    return parts.join(' ');
  }
}

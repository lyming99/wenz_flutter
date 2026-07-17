/// Structured errors raised by document import/export paths and the command
/// registry.
///
/// These replace the raw [FormatException] / [ArgumentError] that the codecs
/// and [CommandRegistry] used to throw, so callers can catch import/execution
/// failures with a typed handler instead of sniffing error strings. The
/// originating error (if any) is preserved on [raw] so no diagnostic
/// information is lost — this mirrors a cause-chain without depending on
/// `dart:async`'s internal traceback.
library document_errors;

/// Raised when a document JSON payload (rich or legacy) cannot be decoded.
///
/// Surfaces a short [reason], an optional [jsonPath] pointing at the offending
/// fragment (e.g. `'blocks[2]'`), and the [raw] error that triggered the
/// failure (typically a [FormatException] or a [TypeError]). Callers that want
/// a no-throw entry point should use
/// `WenzRichTextController.tryLoadJson` instead of catching this directly.
class DocumentDecodeException implements Exception {
  const DocumentDecodeException(
    this.reason, {
    this.jsonPath,
    this.raw,
  });

  /// Human-readable description of what went wrong, e.g.
  /// `'Rich text JSON must be an object.'`.
  final String reason;

  /// Optional dotted/indexed path into the payload, e.g. `'blocks[3].rows'`.
  /// `null` when the failure is at the top level (malformed JSON, wrong root
  /// type) and no finer location is known.
  final String? jsonPath;

  /// The originating error, preserved for diagnostics. May be `null` when the
  /// exception was synthesised (e.g. a structural validation failure) rather
  /// than translated from a throw.
  final Object? raw;

  @override
  String toString() {
    final path = jsonPath;
    return path == null
        ? 'DocumentDecodeException: $reason'
        : 'DocumentDecodeException: $reason at $path';
  }
}

/// Raised by [CommandRegistry.build] (and therefore by
/// `WenzRichTextController.executeCommand`) when a command name has not been
/// registered.
///
/// Replaces the previous bare [ArgumentError]; callers that previously caught
/// `ArgumentError` should catch this instead. Use
/// `WenzRichTextController.tryExecuteCommand` for a no-throw entry point.
class UnknownCommandException implements Exception {
  const UnknownCommandException(this.name);

  /// The unrecognised command name.
  final String name;

  @override
  String toString() => 'UnknownCommandException: no command registered for '
      'name "$name".';
}

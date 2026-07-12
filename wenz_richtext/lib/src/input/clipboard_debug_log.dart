import 'package:flutter/foundation.dart';

import '../core/position/document_position.dart';

/// Configurable diagnostic logging for the rich-text clipboard pipeline.
///
/// Logging is enabled automatically in debug builds. It can be enabled while
/// diagnosing a profile/release integration before constructing the editor:
///
/// ```dart
/// WenzClipboardDebugLog.enabled = true;
/// ```
///
/// Payload previews are whitespace-normalised and truncated so copying a large
/// document does not flood the console. Applications may replace [sink] to
/// forward the messages to their own logging service.
class WenzClipboardDebugLog {
  WenzClipboardDebugLog._();

  static const String prefix = '[wenz_richtext][clipboard]';

  static bool enabled = kDebugMode;

  static int maxPreviewCharacters = 240;

  static void Function(String message) sink = debugPrint;

  static void event(
    String name, {
    Map<String, Object?> fields = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) {
      return;
    }
    final details = fields.entries
        .map((entry) => '${entry.key}=${_formatValue(entry.value)}')
        .join(' ');
    sink('$prefix $name${details.isEmpty ? '' : ' $details'}');
    if (error != null) {
      sink('$prefix $name error=${_formatValue(error)}');
    }
    if (stackTrace != null) {
      sink('$prefix $name stack=${preview(stackTrace.toString())}');
    }
  }

  static String preview(String? value) {
    if (value == null) {
      return '<null>';
    }
    final normalised = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', r'\n')
        .replaceAll(RegExp(r'[\t ]+'), ' ')
        .trim();
    final limit = maxPreviewCharacters < 0 ? 0 : maxPreviewCharacters;
    if (normalised.length <= limit) {
      return normalised;
    }
    return '${normalised.substring(0, limit)}…';
  }

  static String text(String? value) {
    return value == null
        ? '<null>'
        : 'length:${value.length},preview:"${preview(value)}"';
  }

  static String selection(DocumentSelection? selection) {
    if (selection == null) {
      return '<null>';
    }
    final start = selection.start;
    final end = selection.end;
    return 'collapsed:${selection.isCollapsed},'
        'start:${start.blockIndex}/${start.blockId}/${start.path}@${start.offset},'
        'end:${end.blockIndex}/${end.blockId}/${end.path}@${end.offset},'
        'tableRange:${selection.tableCellRange}';
  }

  static String _formatValue(Object? value) {
    if (value == null) {
      return '<null>';
    }
    if (value is String) {
      return '"${preview(value)}"';
    }
    return value.toString();
  }
}

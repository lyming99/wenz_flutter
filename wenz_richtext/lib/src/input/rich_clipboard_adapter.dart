import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart' as super_clipboard;

import 'clipboard_debug_log.dart';
import 'clipboard_service.dart';
import 'external_image_clipboard_reader.dart';
import 'external_image_input.dart';

/// `super_clipboard` value format for the private Wenz rich-text payload.
///
/// The stored value is the same string as [ClipboardCopyPayload.wenzRichText],
/// including [wenzClipboardPrefix], so legacy plain-text rich payloads and the
/// private format can share the same parser.
const super_clipboard.ValueFormat<String> wenzRichTextSuperClipboardFormat =
    super_clipboard.SimpleValueFormat<String>(
  fallback: super_clipboard.SimplePlatformCodec<String>(
    formats: <String>[wenzRichTextClipboardFormat],
    onDecode: _decodeClipboardString,
  ),
);

/// `super_clipboard` value format for Markdown clipboard snippets.
const super_clipboard.ValueFormat<String> markdownSuperClipboardFormat =
    super_clipboard.SimpleValueFormat<String>(
  ios: super_clipboard.SimplePlatformCodec<String>(
    formats: <String>[
      'net.daringfireball.markdown',
      markdownClipboardFormat,
      'text/x-markdown',
    ],
    onDecode: _decodeClipboardString,
  ),
  macos: super_clipboard.SimplePlatformCodec<String>(
    formats: <String>[
      'net.daringfireball.markdown',
      markdownClipboardFormat,
      'text/x-markdown',
    ],
    onDecode: _decodeClipboardString,
  ),
  fallback: super_clipboard.SimplePlatformCodec<String>(
    formats: <String>[
      markdownClipboardFormat,
      'text/x-markdown',
    ],
    onDecode: _decodeClipboardString,
  ),
);

/// Shared default rich clipboard adapter for package and app integrations.
const RichClipboardAdapter defaultRichClipboardAdapter = RichClipboardAdapter();

/// Platform clipboard bridge for Wenz rich-text copy and paste flavours.
///
/// Writes prefer `super_clipboard` multi-format data:
/// [wenzRichTextClipboardFormat], [htmlClipboardFormat], and
/// [plainTextClipboardFormat]. If multi-format writing is unavailable or fails,
/// the adapter falls back to Flutter's plain-text clipboard using only
/// [ClipboardCopyPayload.plainText].
class RichClipboardAdapter {
  const RichClipboardAdapter({
    this.externalImageClipboardReader = defaultExternalImageClipboardReader,
  });

  /// Optional platform reader for image clipboard inputs.
  final ExternalImageClipboardReader? externalImageClipboardReader;

  /// Alias for [writeCopyPayload].
  Future<void> write(ClipboardCopyPayload payload) {
    return writeCopyPayload(payload);
  }

  /// Alias for [tryWriteCopyPayload].
  Future<bool> tryWrite(ClipboardCopyPayload payload) {
    return tryWriteCopyPayload(payload);
  }

  /// Writes a structured copy payload to the platform clipboard.
  Future<void> writeCopyPayload(ClipboardCopyPayload payload) async {
    await tryWriteCopyPayload(payload);
  }

  /// Writes a structured copy payload and reports whether any write path worked.
  Future<bool> tryWriteCopyPayload(ClipboardCopyPayload payload) async {
    WenzClipboardDebugLog.event(
      'platform.write-request',
      fields: <String, Object?>{
        'wenz': WenzClipboardDebugLog.text(payload.wenzRichText),
        'html': WenzClipboardDebugLog.text(payload.html),
        'plain': WenzClipboardDebugLog.text(payload.plainText),
      },
    );
    if (await _tryWriteSuperClipboardPayload(payload)) {
      WenzClipboardDebugLog.event(
        'platform.write-result',
        fields: const <String, Object?>{
          'success': true,
          'path': 'super_clipboard-multi-format',
        },
      );
      return true;
    }
    final success = await tryWritePlainText(payload.plainText);
    WenzClipboardDebugLog.event(
      'platform.write-result',
      fields: <String, Object?>{
        'success': success,
        'path': 'plain-text-fallback',
      },
    );
    return success;
  }

  /// Writes readable plain text only.
  Future<void> writePlainText(String text) async {
    await tryWritePlainText(text);
  }

  /// Writes readable plain text only and reports whether the write worked.
  Future<bool> tryWritePlainText(String text) async {
    if (await _tryWriteSuperClipboardPlainText(text)) {
      return true;
    }
    return _tryWriteFlutterPlainText(text);
  }

  /// Builds the multi-format clipboard item used by [writeCopyPayload].
  super_clipboard.DataWriterItem createCopyPayloadItem(
    ClipboardCopyPayload payload,
  ) {
    final item = super_clipboard.DataWriterItem();
    item.add(wenzRichTextSuperClipboardFormat(payload.wenzRichText));
    item.add(super_clipboard.Formats.htmlText(payload.html));
    item.add(super_clipboard.Formats.plainText(payload.plainText));
    return item;
  }

  /// Reads all rich clipboard flavours that the platform exposes.
  ///
  /// The returned snapshot keeps formats separate so editor paste code can
  /// choose its own priority and still reuse [ClipboardService.parseFormats].
  Future<RichClipboardSnapshot> read({
    bool includeExternalImages = true,
  }) async {
    WenzClipboardDebugLog.event(
      'platform.read-request',
      fields: <String, Object?>{
        'includeExternalImages': includeExternalImages,
      },
    );
    final richData = await _readSuperClipboardFormats();
    final externalData = includeExternalImages
        ? await _readExternalClipboardData()
        : const ExternalImageClipboardData();
    final fallbackPlainText =
        richData.plainText ?? await _readFlutterPlainText();
    final snapshot = RichClipboardSnapshot(
      wenzRichText: richData.wenzRichText,
      html: _firstNonEmptyText(richData.html, externalData.html),
      markdown: _firstNonEmptyText(richData.markdown, externalData.markdown),
      plainText: _firstNonEmptyText(
        fallbackPlainText,
        externalData.plainText,
      ),
      images: externalData.images,
    );
    WenzClipboardDebugLog.event(
      'platform.read-result',
      fields: <String, Object?>{
        'wenz': WenzClipboardDebugLog.text(snapshot.wenzRichText),
        'legacyWenzInPlain': snapshot.hasLegacyWenzPlainText,
        'html': WenzClipboardDebugLog.text(snapshot.html),
        'markdown': WenzClipboardDebugLog.text(snapshot.markdown),
        'plain': WenzClipboardDebugLog.text(snapshot.plainText),
        'imageCount': snapshot.images.length,
        'preferredFormat': snapshot.preferredText?.clipboardFormat,
      },
    );
    return snapshot;
  }

  Future<bool> _tryWriteSuperClipboardPayload(
    ClipboardCopyPayload payload,
  ) async {
    final clipboard = super_clipboard.SystemClipboard.instance;
    if (clipboard == null) {
      WenzClipboardDebugLog.event(
        'platform.write-multi-unavailable',
        fields: const <String, Object?>{
          'reason': 'SystemClipboard.instance=null'
        },
      );
      return false;
    }
    try {
      await clipboard.write(<super_clipboard.DataWriterItem>[
        createCopyPayloadItem(payload),
      ]);
      return true;
    } on Object catch (error, stackTrace) {
      WenzClipboardDebugLog.event(
        'platform.write-multi-failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> _tryWriteSuperClipboardPlainText(String text) async {
    final clipboard = super_clipboard.SystemClipboard.instance;
    if (clipboard == null) {
      WenzClipboardDebugLog.event(
        'platform.write-plain-super-unavailable',
        fields: const <String, Object?>{
          'reason': 'SystemClipboard.instance=null'
        },
      );
      return false;
    }
    try {
      final item = super_clipboard.DataWriterItem()
        ..add(super_clipboard.Formats.plainText(text));
      await clipboard.write(<super_clipboard.DataWriterItem>[item]);
      WenzClipboardDebugLog.event(
        'platform.write-plain-super-success',
        fields: <String, Object?>{'text': WenzClipboardDebugLog.text(text)},
      );
      return true;
    } on Object catch (error, stackTrace) {
      WenzClipboardDebugLog.event(
        'platform.write-plain-super-failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> _tryWriteFlutterPlainText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      WenzClipboardDebugLog.event(
        'platform.write-plain-flutter-success',
        fields: <String, Object?>{'text': WenzClipboardDebugLog.text(text)},
      );
      return true;
    } on Object catch (error, stackTrace) {
      WenzClipboardDebugLog.event(
        'platform.write-plain-flutter-failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<RichClipboardSnapshot> _readSuperClipboardFormats() async {
    final clipboard = super_clipboard.SystemClipboard.instance;
    if (clipboard == null) {
      WenzClipboardDebugLog.event(
        'platform.read-multi-unavailable',
        fields: const <String, Object?>{
          'reason': 'SystemClipboard.instance=null'
        },
      );
      return const RichClipboardSnapshot();
    }
    try {
      final reader = await clipboard.read();
      return RichClipboardSnapshot(
        wenzRichText: await _readValue(
          reader,
          wenzRichTextSuperClipboardFormat,
          wenzRichTextClipboardFormat,
        ),
        html: await _readValue(
          reader,
          super_clipboard.Formats.htmlText,
          htmlClipboardFormat,
        ),
        markdown: await _readValue(
          reader,
          markdownSuperClipboardFormat,
          markdownClipboardFormat,
        ),
        plainText: await _readValue(
          reader,
          super_clipboard.Formats.plainText,
          plainTextClipboardFormat,
        ),
      );
    } on Object catch (error, stackTrace) {
      WenzClipboardDebugLog.event(
        'platform.read-multi-failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const RichClipboardSnapshot();
    }
  }

  Future<String?> _readValue(
    super_clipboard.ClipboardDataReader reader,
    super_clipboard.ValueFormat<String> format,
    String label,
  ) async {
    try {
      final canProvide = reader.canProvide(format);
      WenzClipboardDebugLog.event(
        'platform.read-format-available',
        fields: <String, Object?>{
          'format': label,
          'available': canProvide,
        },
      );
      if (!canProvide) {
        return null;
      }
      final value = _nonEmptyText(await reader.readValue(format));
      WenzClipboardDebugLog.event(
        'platform.read-format-value',
        fields: <String, Object?>{
          'format': label,
          'value': WenzClipboardDebugLog.text(value),
        },
      );
      return value;
    } on Object catch (error, stackTrace) {
      WenzClipboardDebugLog.event(
        'platform.read-format-failed',
        fields: <String, Object?>{'format': label},
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<ExternalImageClipboardData> _readExternalClipboardData() async {
    final reader = externalImageClipboardReader;
    if (reader == null) {
      WenzClipboardDebugLog.event(
        'platform.read-external-images-skipped',
        fields: const <String, Object?>{'reason': 'reader=null'},
      );
      return const ExternalImageClipboardData();
    }
    try {
      return await reader.read();
    } on Object catch (error, stackTrace) {
      WenzClipboardDebugLog.event(
        'platform.read-external-images-failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const ExternalImageClipboardData();
    }
  }

  Future<String?> _readFlutterPlainText() async {
    try {
      final value =
          _nonEmptyText((await Clipboard.getData('text/plain'))?.text);
      WenzClipboardDebugLog.event(
        'platform.read-plain-flutter-result',
        fields: <String, Object?>{'value': WenzClipboardDebugLog.text(value)},
      );
      return value;
    } on Object catch (error, stackTrace) {
      WenzClipboardDebugLog.event(
        'platform.read-plain-flutter-failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}

/// Snapshot of the platform clipboard flavours relevant to Wenz paste.
class RichClipboardSnapshot {
  const RichClipboardSnapshot({
    this.wenzRichText,
    this.html,
    this.markdown,
    this.plainText,
    this.images = const <ExternalImageInput>[],
  });

  /// Private Wenz rich-text payload, when available.
  final String? wenzRichText;

  /// HTML snippet, when available.
  final String? html;

  /// Markdown snippet, when available.
  final String? markdown;

  /// Readable plain text, when available.
  final String? plainText;

  /// External image candidates read from the clipboard.
  final List<ExternalImageInput> images;

  bool get hasWenzRichText => _nonEmptyText(wenzRichText) != null;

  bool get hasLegacyWenzPlainText => legacyWenzRichText != null;

  bool get hasHtml => _nonEmptyText(html) != null;

  bool get hasMarkdown => _nonEmptyText(markdown) != null;

  bool get hasPlainText => _nonEmptyText(plainText) != null;

  bool get hasImages => images.isNotEmpty;

  bool get hasText =>
      hasWenzRichText ||
      hasLegacyWenzPlainText ||
      hasHtml ||
      hasMarkdown ||
      hasPlainText;

  bool get isEmpty => !hasText && !hasImages;

  /// Legacy rich payload stored in text/plain by older copy paths.
  String? get legacyWenzRichText {
    final text = _nonEmptyText(plainText);
    if (text == null || !hasWenzClipboardPrefix(text)) {
      return null;
    }
    return normalizeWenzClipboardPayload(text);
  }

  /// Internal payload normalized for [ClipboardService.parse].
  String? get wenzRichTextForPaste {
    final rich = _nonEmptyText(wenzRichText);
    if (rich != null) {
      return normalizeWenzClipboardPayload(rich);
    }
    return legacyWenzRichText;
  }

  /// Preferred text flavour using Wenz paste priority.
  RichClipboardTextData? get preferredText {
    final privateRich = _nonEmptyText(wenzRichText);
    if (privateRich != null) {
      return RichClipboardTextData(
        text: normalizeWenzClipboardPayload(privateRich),
        format: ClipboardPasteFormat.auto,
        clipboardFormat: wenzRichTextClipboardFormat,
      );
    }
    final rich = legacyWenzRichText;
    if (rich != null) {
      return RichClipboardTextData(
        text: rich,
        format: ClipboardPasteFormat.auto,
        clipboardFormat: plainTextClipboardFormat,
      );
    }
    final htmlText = _nonEmptyText(html);
    if (htmlText != null) {
      return RichClipboardTextData(
        text: htmlText,
        format: ClipboardPasteFormat.html,
        clipboardFormat: htmlClipboardFormat,
      );
    }
    final markdownText = _nonEmptyText(markdown);
    if (markdownText != null) {
      return RichClipboardTextData(
        text: markdownText,
        format: ClipboardPasteFormat.markdown,
        clipboardFormat: markdownClipboardFormat,
      );
    }
    final text = _nonEmptyText(plainText);
    if (text != null) {
      return RichClipboardTextData(
        text: text,
        format: ClipboardPasteFormat.plainText,
        clipboardFormat: plainTextClipboardFormat,
      );
    }
    return null;
  }

  /// Parses the preferred text flavour with [service].
  ClipboardPaste? parseWith([
    ClipboardService service = const ClipboardService(),
  ]) {
    return service.parseFormats(
      wenzRichText: wenzRichTextForPaste,
      html: html,
      markdown: markdown,
      plainText: plainText,
    );
  }

  ExternalImageClipboardData toExternalImageClipboardData() {
    return ExternalImageClipboardData(
      plainText: plainText,
      html: html,
      markdown: markdown,
      images: images,
    );
  }
}

/// A single text clipboard flavour selected from [RichClipboardSnapshot].
class RichClipboardTextData {
  const RichClipboardTextData({
    required this.text,
    required this.format,
    required this.clipboardFormat,
  });

  final String text;

  final ClipboardPasteFormat format;

  /// MIME/format identifier for the source flavour.
  final String clipboardFormat;

  bool get isWenzRichText =>
      clipboardFormat == wenzRichTextClipboardFormat ||
      hasWenzClipboardPrefix(text);
}

Future<String?> _decodeClipboardString(
  super_clipboard.PlatformDataProvider dataProvider,
  super_clipboard.PlatformFormat format,
) async {
  final value = await dataProvider.getData(format);
  WenzClipboardDebugLog.event(
    'platform.decode-value',
    fields: <String, Object?>{
      'platformFormat': format,
      'runtimeType': value?.runtimeType,
      'isNull': value == null,
      'byteLength': value is List<int> ? value.length : null,
      'string': value is String ? WenzClipboardDebugLog.text(value) : null,
    },
  );
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  if (value is Uint8List) {
    return utf8.decode(value, allowMalformed: true);
  }
  if (value is TypedData) {
    return utf8.decode(
      value.buffer.asUint8List(value.offsetInBytes, value.lengthInBytes),
      allowMalformed: true,
    );
  }
  if (value is List<int>) {
    return utf8.decode(value, allowMalformed: true);
  }
  if (value is Map && value.isEmpty) {
    return '';
  }
  return null;
}

String? _firstNonEmptyText(String? first, String? second) {
  return _nonEmptyText(first) ?? _nonEmptyText(second);
}

String? _nonEmptyText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : value;
}

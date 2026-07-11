import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart' as super_clipboard;

import 'clipboard_service.dart';
import 'external_image_clipboard_reader.dart';
import 'external_image_input.dart';

/// `super_clipboard` value format for the private Wenz rich-text payload.
///
/// The stored value is the same string as [ClipboardCopyPayload.wenzRichText],
/// including [wenzClipboardPrefix], so legacy plain-text rich payloads and the
/// private format can share the same parser.
final super_clipboard.ValueFormat<String> wenzRichTextSuperClipboardFormat =
    super_clipboard.SimpleValueFormat<String>(
  fallback: super_clipboard.SimplePlatformCodec<String>(
    formats: const <String>[wenzRichTextClipboardFormat],
    onDecode: _decodeClipboardString,
  ),
);

/// `super_clipboard` value format for Markdown clipboard snippets.
final super_clipboard.ValueFormat<String> markdownSuperClipboardFormat =
    super_clipboard.SimpleValueFormat<String>(
  ios: super_clipboard.SimplePlatformCodec<String>(
    formats: const <String>[
      'net.daringfireball.markdown',
      markdownClipboardFormat,
      'text/x-markdown',
    ],
    onDecode: _decodeClipboardString,
  ),
  macos: super_clipboard.SimplePlatformCodec<String>(
    formats: const <String>[
      'net.daringfireball.markdown',
      markdownClipboardFormat,
      'text/x-markdown',
    ],
    onDecode: _decodeClipboardString,
  ),
  fallback: super_clipboard.SimplePlatformCodec<String>(
    formats: const <String>[
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
    if (await _tryWriteSuperClipboardPayload(payload)) {
      return true;
    }
    return tryWritePlainText(payload.plainText);
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
    final richData = await _readSuperClipboardFormats();
    final externalData = includeExternalImages
        ? await _readExternalClipboardData()
        : const ExternalImageClipboardData();
    final fallbackPlainText = richData.plainText == null
        ? await _readFlutterPlainText()
        : richData.plainText;
    return RichClipboardSnapshot(
      wenzRichText: richData.wenzRichText,
      html: _firstNonEmptyText(richData.html, externalData.html),
      markdown: _firstNonEmptyText(richData.markdown, externalData.markdown),
      plainText: _firstNonEmptyText(
        fallbackPlainText,
        externalData.plainText,
      ),
      images: externalData.images,
    );
  }

  Future<bool> _tryWriteSuperClipboardPayload(
    ClipboardCopyPayload payload,
  ) async {
    final clipboard = super_clipboard.SystemClipboard.instance;
    if (clipboard == null) {
      return false;
    }
    try {
      await clipboard.write(<super_clipboard.DataWriterItem>[
        createCopyPayloadItem(payload),
      ]);
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> _tryWriteSuperClipboardPlainText(String text) async {
    final clipboard = super_clipboard.SystemClipboard.instance;
    if (clipboard == null) {
      return false;
    }
    try {
      final item = super_clipboard.DataWriterItem()
        ..add(super_clipboard.Formats.plainText(text));
      await clipboard.write(<super_clipboard.DataWriterItem>[item]);
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> _tryWriteFlutterPlainText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } on Object {
      return false;
    }
  }

  Future<RichClipboardSnapshot> _readSuperClipboardFormats() async {
    final clipboard = super_clipboard.SystemClipboard.instance;
    if (clipboard == null) {
      return const RichClipboardSnapshot();
    }
    try {
      final reader = await clipboard.read();
      return RichClipboardSnapshot(
        wenzRichText: await _readValue(
          reader,
          wenzRichTextSuperClipboardFormat,
        ),
        html: await _readValue(reader, super_clipboard.Formats.htmlText),
        markdown: await _readValue(reader, markdownSuperClipboardFormat),
        plainText: await _readValue(reader, super_clipboard.Formats.plainText),
      );
    } on Object {
      return const RichClipboardSnapshot();
    }
  }

  Future<String?> _readValue(
    super_clipboard.ClipboardDataReader reader,
    super_clipboard.ValueFormat<String> format,
  ) async {
    try {
      if (!reader.canProvide(format)) {
        return null;
      }
      return _nonEmptyText(await reader.readValue(format));
    } on Object {
      return null;
    }
  }

  Future<ExternalImageClipboardData> _readExternalClipboardData() async {
    final reader = externalImageClipboardReader;
    if (reader == null) {
      return const ExternalImageClipboardData();
    }
    try {
      return await reader.read();
    } on Object {
      return const ExternalImageClipboardData();
    }
  }

  Future<String?> _readFlutterPlainText() async {
    try {
      return _nonEmptyText((await Clipboard.getData('text/plain'))?.text);
    } on Object {
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
    if (text == null || !text.startsWith(wenzClipboardPrefix)) {
      return null;
    }
    return text;
  }

  /// Internal payload normalized for [ClipboardService.parse].
  String? get wenzRichTextForPaste {
    final rich = _nonEmptyText(wenzRichText);
    if (rich != null) {
      return _ensureWenzClipboardPrefix(rich);
    }
    return legacyWenzRichText;
  }

  /// Preferred text flavour using Wenz paste priority.
  RichClipboardTextData? get preferredText {
    final privateRich = _nonEmptyText(wenzRichText);
    if (privateRich != null) {
      return RichClipboardTextData(
        text: _ensureWenzClipboardPrefix(privateRich),
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
      text.startsWith(wenzClipboardPrefix);
}

Future<String?> _decodeClipboardString(
  super_clipboard.PlatformDataProvider dataProvider,
  super_clipboard.PlatformFormat format,
) async {
  final value = await dataProvider.getData(format);
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

String _ensureWenzClipboardPrefix(String value) {
  return value.startsWith(wenzClipboardPrefix)
      ? value
      : '$wenzClipboardPrefix$value';
}

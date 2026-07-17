import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:super_clipboard/super_clipboard.dart' as super_clipboard;

import 'external_image_input.dart';

/// Shared default clipboard reader for platform image inputs.
const ExternalImageClipboardReader defaultExternalImageClipboardReader =
    DefaultExternalImageClipboardReader();

final super_clipboard.ValueFormat<String> _markdownTextClipboardFormat =
    super_clipboard.SimpleValueFormat<String>(
  ios: super_clipboard.SimplePlatformCodec<String>(
    formats: const <String>[
      'net.daringfireball.markdown',
      'text/markdown',
      'text/x-markdown',
    ],
    onDecode: _decodeClipboardString,
  ),
  macos: super_clipboard.SimplePlatformCodec<String>(
    formats: const <String>[
      'net.daringfireball.markdown',
      'text/markdown',
      'text/x-markdown',
    ],
    onDecode: _decodeClipboardString,
  ),
  fallback: super_clipboard.SimplePlatformCodec<String>(
    formats: const <String>[
      'text/markdown',
      'text/x-markdown',
    ],
    onDecode: _decodeClipboardString,
  ),
);

/// Default [ExternalImageClipboardReader] backed by `super_clipboard`.
///
/// It reads common image clipboard flavors as memory images and translates
/// file URI / path flavors into [ExternalImageInput] candidates. Platform
/// failures are contained so callers can safely fall back to text paste.
class DefaultExternalImageClipboardReader
    implements ExternalImageClipboardReader {
  const DefaultExternalImageClipboardReader();

  @override
  Future<ExternalImageClipboardData> read() async {
    final clipboard = super_clipboard.SystemClipboard.instance;
    if (clipboard == null) {
      return const ExternalImageClipboardData();
    }

    final super_clipboard.ClipboardReader reader;
    try {
      reader = await clipboard.read();
    } on Object {
      return const ExternalImageClipboardData();
    }

    final plainText = await _readValue(reader, super_clipboard.Formats.plainText);
    final html = await _readValue(reader, super_clipboard.Formats.htmlText);
    final markdown = await _readValue(reader, _markdownTextClipboardFormat);
    final images = <ExternalImageInput>[];
    final seen = <String>{};

    void addImage(ExternalImageInput? input) {
      if (input == null) {
        return;
      }
      if (seen.add(_dedupeKey(input))) {
        images.add(input);
      }
    }

    for (final item in reader.items) {
      final fileInput = await _readFileUriInput(item);
      if (fileInput != null && fileInput.isAccepted) {
        addImage(fileInput);
        final memoryInput = await _readMemoryImageInput(item);
        if (memoryInput != null && memoryInput.isAccepted) {
          addImage(_memoryFallbackForFileInput(memoryInput, fileInput));
        }
        continue;
      }

      final memoryInput = await _readMemoryImageInput(item);
      if (memoryInput != null) {
        addImage(memoryInput);
        continue;
      }

      addImage(fileInput);
      addImage(await _readUnsupportedUriInput(item));
    }

    for (final location in _imageLocationsFromPlainText(plainText)) {
      addImage(
        ExternalImageInput.fileLocation(
          location: location,
          source: ExternalImageInputSource.clipboard,
        ),
      );
    }

    return ExternalImageClipboardData(
      plainText: plainText,
      html: html,
      markdown: markdown,
      images: images,
    );
  }

  Future<String?> _readValue(
    super_clipboard.ClipboardDataReader reader,
    super_clipboard.ValueFormat<String> format,
  ) async {
    try {
      final value = await reader.readValue(format);
      final normalized = value?.trim();
      return normalized == null || normalized.isEmpty ? null : value;
    } on Object {
      return null;
    }
  }

  Future<ExternalImageInput?> _readFileUriInput(
    super_clipboard.ClipboardDataReader reader,
  ) async {
    if (!reader.canProvide(super_clipboard.Formats.fileUri)) {
      return null;
    }
    try {
      final uri = await reader.readValue(super_clipboard.Formats.fileUri);
      if (uri == null) {
        return null;
      }
      return ExternalImageInput.fileUri(
        uri: uri,
        source: ExternalImageInputSource.clipboard,
        fileName: await _readSuggestedName(reader),
      );
    } on Object {
      return ExternalImageInput.rejected(
        kind: ExternalImageInputKind.fileUri,
        source: ExternalImageInputSource.clipboard,
        reason: ExternalImageInputRejectionReason.fileAccessFailed,
        message: 'Failed to read clipboard file URI.',
      );
    }
  }

  Future<ExternalImageInput?> _readUnsupportedUriInput(
    super_clipboard.ClipboardDataReader reader,
  ) async {
    if (!reader.canProvide(super_clipboard.Formats.uri)) {
      return null;
    }
    try {
      final namedUri = await reader.readValue(super_clipboard.Formats.uri);
      final uri = namedUri?.uri;
      if (uri == null || uri.scheme.toLowerCase() == 'file') {
        return null;
      }
      return ExternalImageInput.fileUri(
        uri: uri,
        source: ExternalImageInputSource.clipboard,
        fileName: namedUri?.name,
      );
    } on Object {
      return ExternalImageInput.rejected(
        kind: ExternalImageInputKind.fileUri,
        source: ExternalImageInputSource.clipboard,
        reason: ExternalImageInputRejectionReason.fileAccessFailed,
        message: 'Failed to read clipboard URI.',
      );
    }
  }

  Future<ExternalImageInput?> _readMemoryImageInput(
    super_clipboard.ClipboardDataReader reader,
  ) async {
    for (final format in _imageFormats) {
      if (!reader.canProvide(format.format)) {
        continue;
      }
      final input = await _readMemoryImageFile(reader, format);
      if (input != null) {
        return input;
      }
    }
    return null;
  }

  Future<ExternalImageInput?> _readMemoryImageFile(
    super_clipboard.ClipboardDataReader reader,
    _ClipboardImageFormat format,
  ) {
    final completer = Completer<ExternalImageInput?>();

    void complete(ExternalImageInput? input) {
      if (!completer.isCompleted) {
        completer.complete(input);
      }
    }

    try {
      final progress = reader.getFile(
        format.format,
        (file) async {
          try {
            final bytes = _asBytes(await file.readAll());
            complete(
              ExternalImageInput.memory(
                bytes: bytes,
                source: ExternalImageInputSource.clipboard,
                mimeType: format.mimeType,
                fileName: _normalizeString(file.fileName) ??
                    await _readSuggestedName(reader),
              ),
            );
          } on Object {
            complete(
              ExternalImageInput.rejected(
                kind: ExternalImageInputKind.memory,
                source: ExternalImageInputSource.clipboard,
                reason: ExternalImageInputRejectionReason.fileAccessFailed,
                message: 'Failed to read clipboard image bytes.',
                mimeType: format.mimeType,
              ),
            );
          }
        },
        onError: (Object error) {
          complete(
            ExternalImageInput.rejected(
              kind: ExternalImageInputKind.memory,
              source: ExternalImageInputSource.clipboard,
              reason: ExternalImageInputRejectionReason.fileAccessFailed,
              message: 'Failed to read clipboard image bytes.',
              mimeType: format.mimeType,
            ),
          );
        },
      );
      if (progress == null) {
        complete(null);
      }
    } on Object {
      complete(
        ExternalImageInput.rejected(
          kind: ExternalImageInputKind.memory,
          source: ExternalImageInputSource.clipboard,
          reason: ExternalImageInputRejectionReason.fileAccessFailed,
          message: 'Failed to read clipboard image bytes.',
          mimeType: format.mimeType,
        ),
      );
    }
    return completer.future;
  }

  Future<String?> _readSuggestedName(
    super_clipboard.DataReader reader,
  ) async {
    try {
      return _normalizeString(await reader.getSuggestedName());
    } on Object {
      return null;
    }
  }

  Uint8List _asBytes(Object value) {
    if (value is Uint8List) {
      return value;
    }
    if (value is List<int>) {
      return Uint8List.fromList(value);
    }
    return Uint8List(0);
  }

  Iterable<String> _imageLocationsFromPlainText(String? text) sync* {
    final normalized = _normalizeString(text);
    if (normalized == null) {
      return;
    }
    for (final rawLine in normalized.split(RegExp(r'[\r\n]+'))) {
      final location = _normalizeLocation(rawLine);
      if (location == null || !_looksLikeImageLocation(location)) {
        continue;
      }
      yield location;
    }
  }

  bool _looksLikeImageLocation(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && !_isWindowsDrivePath(value)) {
      return uri.scheme.toLowerCase() == 'file' ||
          externalImageExtensionFromFileName(value) != null;
    }
    return _isWindowsDrivePath(value) ||
        value.startsWith('/') ||
        value.startsWith(r'\') ||
        externalImageExtensionFromFileName(value) != null;
  }

  bool _isWindowsDrivePath(String value) {
    return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);
  }

  String? _normalizeLocation(String value) {
    var trimmed = value.trim();
    if (trimmed.length >= 2) {
      final first = trimmed.codeUnitAt(0);
      final last = trimmed.codeUnitAt(trimmed.length - 1);
      if ((first == 0x22 && last == 0x22) ||
          (first == 0x27 && last == 0x27)) {
        trimmed = trimmed.substring(1, trimmed.length - 1).trim();
      }
    }
    return _normalizeString(trimmed);
  }

  String? _normalizeString(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _dedupeKey(ExternalImageInput input) {
    return switch (input.kind) {
      ExternalImageInputKind.memory =>
        'memory:${input.mimeType}:${input.fileName}:${input.sizeBytes}',
      ExternalImageInputKind.filePath => 'path:${input.filePath}',
      ExternalImageInputKind.fileUri => 'uri:${input.fileUri}',
    };
  }

  ExternalImageInput _memoryFallbackForFileInput(
    ExternalImageInput memoryInput,
    ExternalImageInput fileInput,
  ) {
    final bytes = memoryInput.bytes;
    final fileName = _normalizeString(fileInput.fileName);
    if (bytes == null ||
        fileName == null ||
        fileName == _normalizeString(memoryInput.fileName)) {
      return memoryInput;
    }
    return ExternalImageInput.memory(
      bytes: bytes,
      source: memoryInput.source,
      mimeType: memoryInput.mimeType,
      fileName: fileName,
    );
  }
}

const List<_ClipboardImageFormat> _imageFormats = <_ClipboardImageFormat>[
  _ClipboardImageFormat(super_clipboard.Formats.png, 'image/png'),
  _ClipboardImageFormat(super_clipboard.Formats.jpeg, 'image/jpeg'),
  _ClipboardImageFormat(super_clipboard.Formats.gif, 'image/gif'),
  _ClipboardImageFormat(super_clipboard.Formats.webp, 'image/webp'),
  _ClipboardImageFormat(super_clipboard.Formats.bmp, 'image/bmp'),
];

class _ClipboardImageFormat {
  const _ClipboardImageFormat(this.format, this.mimeType);

  final super_clipboard.FileFormat format;
  final String mimeType;
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

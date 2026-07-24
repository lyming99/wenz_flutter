import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:super_clipboard/super_clipboard.dart' as super_clipboard;

import 'external_image_file_access_stub.dart'
    if (dart.library.io) 'external_image_file_access_io.dart' as file_access;
import 'external_image_input.dart';

/// Checks whether a clipboard HTML image location is an accessible local file.
typedef ExternalImageFileExists = Future<bool> Function(String location);

/// Shared default clipboard reader for platform image inputs.
const ExternalImageClipboardReader defaultExternalImageClipboardReader =
    DefaultExternalImageClipboardReader();

const super_clipboard.ValueFormat<String> _markdownTextClipboardFormat =
    super_clipboard.SimpleValueFormat<String>(
  ios: super_clipboard.SimplePlatformCodec<String>(
    formats: <String>[
      'net.daringfireball.markdown',
      'text/markdown',
      'text/x-markdown',
    ],
    onDecode: _decodeClipboardString,
  ),
  macos: super_clipboard.SimplePlatformCodec<String>(
    formats: <String>[
      'net.daringfireball.markdown',
      'text/markdown',
      'text/x-markdown',
    ],
    onDecode: _decodeClipboardString,
  ),
  fallback: super_clipboard.SimplePlatformCodec<String>(
    formats: <String>[
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

    final plainText =
        await _readValue(reader, super_clipboard.Formats.plainText);
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

    for (final input in await externalImageInputsFromClipboardHtml(html)) {
      addImage(input);
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
      if ((first == 0x22 && last == 0x22) || (first == 0x27 && last == 0x27)) {
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

/// Extracts accessible local image candidates from Word-compatible HTML.
///
/// Both regular `img` elements and Office VML `imagedata` elements are read.
/// Relative filenames are resolved against a local `base` URL or the CF_HTML
/// `SourceURL` header. Remote, data, and inaccessible locations are ignored.
Future<List<ExternalImageInput>> externalImageInputsFromClipboardHtml(
  String? clipboardHtml, {
  ExternalImageFileExists fileExists = file_access.externalImageFileExists,
}) async {
  final source = clipboardHtml?.trim();
  if (source == null || source.isEmpty) {
    return const <ExternalImageInput>[];
  }

  final document = html_parser.parse(source.replaceAll('\u0000', ''));
  final baseLocations = _localHtmlBaseLocations(document, source);
  final inputs = <ExternalImageInput>[];
  final seenLocations = <String>{};

  for (final element in document.querySelectorAll('*')) {
    if (!_isClipboardImageElement(element)) {
      continue;
    }
    for (final attributeName in _htmlImageSourceAttributes) {
      final rawLocation = _attributeValue(element, attributeName)?.trim();
      if (rawLocation == null || rawLocation.isEmpty) {
        continue;
      }
      final location = _resolveLocalHtmlImageLocation(
        rawLocation,
        baseLocations,
      );
      if (location == null ||
          externalImageExtensionFromFileName(location) == null) {
        continue;
      }
      final key = _normalizedHtmlImageLocationKey(location);
      if (!seenLocations.add(key) || !await fileExists(location)) {
        continue;
      }
      inputs.add(
        ExternalImageInput.fileLocation(
          location: location,
          source: ExternalImageInputSource.clipboard,
        ),
      );
    }
  }
  return inputs;
}

const List<String> _htmlImageSourceAttributes = <String>[
  'data-original-src',
  'data-original',
  'originalsrc',
  'o:href',
  'xlink:href',
  'href',
  'src',
];

bool _isClipboardImageElement(html_dom.Element element) {
  final localName = element.localName?.toLowerCase() ?? '';
  return localName == 'img' ||
      localName == 'imagedata' ||
      localName.endsWith(':imagedata');
}

String? _attributeValue(html_dom.Element element, String name) {
  final direct = element.attributes[name];
  if (direct != null) {
    return direct;
  }
  final normalizedName = name.toLowerCase();
  for (final entry in element.attributes.entries) {
    if (entry.key.toString().toLowerCase() == normalizedName) {
      return entry.value;
    }
  }
  return null;
}

List<String> _localHtmlBaseLocations(
  html_dom.Document document,
  String source,
) {
  final locations = <String>[];
  final baseHref = document.querySelector('base')?.attributes['href'];
  if (baseHref != null && _isLocalHtmlLocation(baseHref)) {
    locations.add(baseHref.trim());
  }
  final sourceUrl = RegExp(
    r'^SourceURL:(.+)$',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(source)?.group(1)?.trim();
  if (sourceUrl != null && _isLocalHtmlLocation(sourceUrl)) {
    locations.add(sourceUrl);
  }
  return locations;
}

String? _resolveLocalHtmlImageLocation(
  String rawLocation,
  List<String> baseLocations,
) {
  final location = _stripHtmlLocationQuotes(rawLocation);
  if (_isAbsoluteLocalHtmlLocation(location)) {
    return location;
  }
  if (_hasNonFileScheme(location)) {
    return null;
  }
  for (final baseLocation in baseLocations) {
    final resolved = _resolveRelativeHtmlLocation(baseLocation, location);
    if (resolved != null) {
      return resolved;
    }
  }
  return location;
}

String _stripHtmlLocationQuotes(String value) {
  var result = value.trim();
  if (result.length >= 2 &&
      ((result.startsWith('"') && result.endsWith('"')) ||
          (result.startsWith("'") && result.endsWith("'")))) {
    result = result.substring(1, result.length - 1).trim();
  }
  return result;
}

bool _isLocalHtmlLocation(String value) {
  final location = value.trim();
  return _isAbsoluteLocalHtmlLocation(location) || !_hasNonFileScheme(location);
}

bool _isAbsoluteLocalHtmlLocation(String value) {
  if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value) ||
      value.startsWith(r'\\') ||
      value.startsWith('/')) {
    return true;
  }
  return Uri.tryParse(value)?.scheme.toLowerCase() == 'file';
}

bool _hasNonFileScheme(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.hasScheme && uri.scheme.toLowerCase() != 'file';
}

String? _resolveRelativeHtmlLocation(String base, String relative) {
  final baseUri = Uri.tryParse(base);
  if (baseUri != null && baseUri.scheme.toLowerCase() == 'file') {
    final directoryBase = baseUri.path.endsWith('/')
        ? baseUri
        : baseUri.replace(
            pathSegments: <String>[
              ...baseUri.pathSegments.take(baseUri.pathSegments.length - 1),
              '',
            ],
          );
    return directoryBase.resolve(relative).toString();
  }

  final normalizedBase = base.replaceAll('\\', '/');
  if (!_isAbsoluteLocalHtmlLocation(normalizedBase)) {
    return null;
  }
  final slash = normalizedBase.lastIndexOf('/');
  final directory = normalizedBase.endsWith('/')
      ? normalizedBase
      : slash < 0
          ? '$normalizedBase/'
          : normalizedBase.substring(0, slash + 1);
  return '$directory$relative';
}

String _normalizedHtmlImageLocationKey(String location) {
  final uri = Uri.tryParse(location);
  var path = uri != null && uri.scheme.toLowerCase() == 'file'
      ? Uri.decodeFull(uri.path)
      : location;
  path = path.replaceAll('\\', '/');
  if (RegExp(r'^/[a-zA-Z]:/').hasMatch(path)) {
    path = path.substring(1);
  }
  return 'file:${path.toLowerCase()}';
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

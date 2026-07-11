import 'dart:typed_data';

/// Supported image filename extensions for platform clipboard/drop inputs.
///
/// Values are lower-case and do not include the leading dot.
const Set<String> supportedExternalImageExtensions = <String>{
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
};

/// Supported image MIME types for platform clipboard/drop inputs.
const Set<String> supportedExternalImageMimeTypes = <String>{
  'image/png',
  'image/jpg',
  'image/jpeg',
  'image/gif',
  'image/webp',
  'image/bmp',
  'image/x-bmp',
  'image/x-ms-bmp',
};

/// Prefix used by the default IO store when materialising in-memory images.
const String externalImageTempFilePrefix = 'wenz-external-image';

/// Human-readable label used when an external image has no filename metadata.
const String defaultExternalImageCaption = 'Pasted image';

const Map<String, String> _extensionByMimeType = <String, String>{
  'image/png': 'png',
  'image/jpg': 'jpg',
  'image/jpeg': 'jpg',
  'image/gif': 'gif',
  'image/webp': 'webp',
  'image/bmp': 'bmp',
  'image/x-bmp': 'bmp',
  'image/x-ms-bmp': 'bmp',
};

final RegExp _windowsDrivePathPattern = RegExp(r'^[a-zA-Z]:[\\/]');

/// Platform source that produced an external image candidate.
enum ExternalImageInputSource {
  clipboard,
  drop,
}

/// Storage shape exposed by a platform clipboard/drop image candidate.
enum ExternalImageInputKind {
  memory,
  filePath,
  fileUri,
}

/// Why an [ExternalImageInput] candidate was rejected.
enum ExternalImageInputRejectionReason {
  emptyData,
  missingFileLocation,
  directory,
  unsupportedUriScheme,
  unsupportedImageType,
  fileNotFound,
  notAFile,
  fileAccessFailed,
  writeFailed,
  unsupportedPlatform,
}

/// Rejection details for an external image candidate.
class ExternalImageInputRejection {
  const ExternalImageInputRejection({
    required this.reason,
    required this.message,
  });

  final ExternalImageInputRejectionReason reason;

  /// Stable diagnostic text intended for logs/tests, not end-user UI.
  final String message;
}

/// Minimal image-block data produced from an external image input.
class ExternalImageBlockDescription {
  const ExternalImageBlockDescription({
    required this.file,
    required this.caption,
    required this.altText,
    this.width,
    this.height,
  });

  factory ExternalImageBlockDescription.fromInput({
    required ExternalImageInput input,
    required String file,
    ExternalImagePixelSize? pixelSize,
    int? width,
    int? height,
  }) {
    final label = externalImageDisplayName(input);
    final resolvedPixelSize =
        pixelSize ?? _positivePixelSize(width ?? 0, height ?? 0);
    return ExternalImageBlockDescription(
      file: file,
      caption: label,
      altText: label,
      width: resolvedPixelSize?.width,
      height: resolvedPixelSize?.height,
    );
  }

  /// Local file path that can be assigned to `ImageBlockNode.file`.
  final String file;

  final String caption;

  final String altText;

  /// Image pixel width in display orientation when it can be read from bytes.
  final int? width;

  /// Image pixel height in display orientation when it can be read from bytes.
  final int? height;
}

/// Positive pixel dimensions in display orientation read from an image payload.
class ExternalImagePixelSize {
  const ExternalImagePixelSize({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
}

/// Result of preparing an [ExternalImageInput] for insertion.
class ExternalImageStoreResult {
  const ExternalImageStoreResult.success(this.description) : rejection = null;

  const ExternalImageStoreResult.failure(this.rejection) : description = null;

  final ExternalImageBlockDescription? description;

  final ExternalImageInputRejection? rejection;

  bool get isSuccess => description != null;

  bool get isFailure => rejection != null;
}

/// Stores or validates platform image input before it becomes an image block.
abstract interface class ExternalImageStore {
  Future<ExternalImageStoreResult> prepare(ExternalImageInput input);
}

/// Platform clipboard snapshot translated into stable editor input values.
class ExternalImageClipboardData {
  const ExternalImageClipboardData({
    this.plainText,
    this.html,
    this.markdown,
    this.images = const <ExternalImageInput>[],
  });

  final String? plainText;
  final String? html;
  final String? markdown;
  final List<ExternalImageInput> images;

  bool get hasImages => images.isNotEmpty;

  bool get hasText =>
      _normalizeOptionalString(plainText) != null ||
      _normalizeOptionalString(html) != null ||
      _normalizeOptionalString(markdown) != null;
}

/// Reads image-capable clipboard flavors without leaking plugin-specific types.
abstract interface class ExternalImageClipboardReader {
  Future<ExternalImageClipboardData> read();
}

/// Platform-neutral image candidate from the system clipboard or external drop.
///
/// This type intentionally contains only stable Dart values. Platform adapters
/// that use packages such as `super_clipboard` or `super_drag_and_drop` should
/// translate plugin-specific objects into this contract before crossing into
/// editor/controller code.
class ExternalImageInput {
  const ExternalImageInput._({
    required this.kind,
    required this.source,
    this.bytes,
    this.filePath,
    this.fileUri,
    this.mimeType,
    this.fileName,
    this.sizeBytes,
    this.rejection,
  });

  /// Creates an in-memory image candidate.
  factory ExternalImageInput.memory({
    required Uint8List bytes,
    required ExternalImageInputSource source,
    String? mimeType,
    String? fileName,
  }) {
    final normalizedMimeType = normalizeExternalImageMimeType(mimeType);
    final normalizedFileName = _normalizeOptionalString(fileName);
    final rejection = _validateImageCandidate(
      bytes: bytes,
      mimeType: normalizedMimeType,
      fileName: normalizedFileName,
      sizeBytes: bytes.lengthInBytes,
    );
    return ExternalImageInput._(
      kind: ExternalImageInputKind.memory,
      source: source,
      bytes: Uint8List.fromList(bytes),
      mimeType: normalizedMimeType,
      fileName: normalizedFileName,
      sizeBytes: bytes.lengthInBytes,
      rejection: rejection,
    );
  }

  /// Creates a file-path image candidate.
  factory ExternalImageInput.filePath({
    required String path,
    required ExternalImageInputSource source,
    String? mimeType,
    String? fileName,
    int? sizeBytes,
  }) {
    final normalizedPath = path.trim();
    final normalizedMimeType = normalizeExternalImageMimeType(mimeType);
    final normalizedFileName = _normalizeOptionalString(fileName) ??
        _normalizeOptionalString(_lastPathSegment(normalizedPath));
    final rejection = _validateImageCandidate(
      fileLocation: normalizedPath,
      mimeType: normalizedMimeType,
      fileName: normalizedFileName ?? normalizedPath,
      sizeBytes: sizeBytes,
      rejectEmptyLocation: true,
    );
    return ExternalImageInput._(
      kind: ExternalImageInputKind.filePath,
      source: source,
      filePath: normalizedPath,
      mimeType: normalizedMimeType,
      fileName: normalizedFileName,
      sizeBytes: sizeBytes,
      rejection: rejection,
    );
  }

  /// Creates a file-URI image candidate.
  factory ExternalImageInput.fileUri({
    required Uri uri,
    required ExternalImageInputSource source,
    String? mimeType,
    String? fileName,
    int? sizeBytes,
  }) {
    final normalizedMimeType = normalizeExternalImageMimeType(mimeType);
    final normalizedFileName = _normalizeOptionalString(fileName) ??
        _normalizeOptionalString(
          uri.pathSegments.isEmpty ? null : uri.pathSegments.last,
        );
    ExternalImageInputRejection? rejection;
    if (uri.scheme.toLowerCase() != 'file') {
      rejection = const ExternalImageInputRejection(
        reason: ExternalImageInputRejectionReason.unsupportedUriScheme,
        message: 'Only file:// image URIs are supported.',
      );
    } else {
      rejection = _validateImageCandidate(
        fileLocation: uri.path,
        mimeType: normalizedMimeType,
        fileName: normalizedFileName ?? uri.path,
        sizeBytes: sizeBytes,
        rejectEmptyLocation: true,
      );
    }
    return ExternalImageInput._(
      kind: ExternalImageInputKind.fileUri,
      source: source,
      fileUri: uri,
      mimeType: normalizedMimeType,
      fileName: normalizedFileName,
      sizeBytes: sizeBytes,
      rejection: rejection,
    );
  }

  /// Parses a platform location as either a `file://` URI or a local path.
  factory ExternalImageInput.fileLocation({
    required String location,
    required ExternalImageInputSource source,
    String? mimeType,
    String? fileName,
    int? sizeBytes,
  }) {
    final normalizedLocation = location.trim();
    final uri = Uri.tryParse(normalizedLocation);
    if (uri != null &&
        uri.hasScheme &&
        !_windowsDrivePathPattern.hasMatch(normalizedLocation)) {
      return ExternalImageInput.fileUri(
        uri: uri,
        source: source,
        mimeType: mimeType,
        fileName: fileName,
        sizeBytes: sizeBytes,
      );
    }
    return ExternalImageInput.filePath(
      path: normalizedLocation,
      source: source,
      mimeType: mimeType,
      fileName: fileName,
      sizeBytes: sizeBytes,
    );
  }

  /// Creates a rejected candidate when a platform adapter can diagnose a
  /// failure before bytes/path data is available.
  factory ExternalImageInput.rejected({
    required ExternalImageInputKind kind,
    required ExternalImageInputSource source,
    required ExternalImageInputRejectionReason reason,
    required String message,
    String? mimeType,
    String? fileName,
    int? sizeBytes,
  }) {
    return ExternalImageInput._(
      kind: kind,
      source: source,
      mimeType: normalizeExternalImageMimeType(mimeType),
      fileName: _normalizeOptionalString(fileName),
      sizeBytes: sizeBytes,
      rejection: ExternalImageInputRejection(
        reason: reason,
        message: message,
      ),
    );
  }

  final ExternalImageInputKind kind;
  final ExternalImageInputSource source;

  /// Raw image bytes for [ExternalImageInputKind.memory].
  final Uint8List? bytes;

  /// Local filesystem path for [ExternalImageInputKind.filePath].
  final String? filePath;

  /// Local file URI for [ExternalImageInputKind.fileUri].
  final Uri? fileUri;

  /// Normalized lower-case MIME type without parameters.
  final String? mimeType;

  /// Platform-provided or inferred filename.
  final String? fileName;

  /// Known byte length when the platform exposes it.
  final int? sizeBytes;

  /// Non-null when this candidate was rejected during safe validation.
  final ExternalImageInputRejection? rejection;

  bool get isAccepted => rejection == null;

  bool get isRejected => rejection != null;

  /// Best known supported extension for this image candidate.
  String? get imageExtension {
    return externalImageExtensionFromMimeType(mimeType) ??
        externalImageExtensionFromFileName(fileName) ??
        externalImageExtensionFromFileName(filePath) ??
        externalImageExtensionFromFileName(fileUri?.path) ??
        externalImageExtensionFromBytes(bytes);
  }
}

/// Returns whether [input] is a syntactically usable external image candidate.
///
/// This is the editor-side gate before attempting slower platform/file IO.
/// It intentionally stays conservative: directory-like locations, empty memory
/// payloads, unsupported URI schemes, and unsupported image signatures/types
/// are rejected here so drag/drop hover UI does not activate for obviously
/// invalid candidates.
bool isUsableExternalImageInput(ExternalImageInput input) {
  if (!input.isAccepted) {
    return false;
  }
  switch (input.kind) {
    case ExternalImageInputKind.memory:
      final bytes = input.bytes;
      return bytes != null &&
          bytes.isNotEmpty &&
          externalImageExtensionFromBytes(bytes) != null;
    case ExternalImageInputKind.filePath:
      final path = _normalizeOptionalString(input.filePath);
      return path != null &&
          !_looksLikeDirectoryLocation(path) &&
          input.imageExtension != null;
    case ExternalImageInputKind.fileUri:
      final uri = input.fileUri;
      return uri != null &&
          uri.scheme.toLowerCase() == 'file' &&
          input.imageExtension != null;
  }
}

/// Returns the default caption/alt text label for an external image.
String externalImageDisplayName(
  ExternalImageInput input, {
  String fallback = defaultExternalImageCaption,
}) {
  final uri = input.fileUri;
  final uriFileName =
      uri == null || uri.pathSegments.isEmpty ? null : uri.pathSegments.last;
  return _fileStemFromName(input.fileName) ??
      _fileStemFromName(input.filePath) ??
      _fileStemFromName(uriFileName) ??
      _normalizeOptionalString(fallback) ??
      defaultExternalImageCaption;
}

/// Returns a normalized MIME type, or `null` for missing/blank input.
String? normalizeExternalImageMimeType(String? mimeType) {
  final value = _normalizeOptionalString(mimeType);
  if (value == null) {
    return null;
  }
  final normalized = value.split(';').first.trim().toLowerCase();
  return normalized.isEmpty ? null : normalized;
}

bool isSupportedExternalImageMimeType(String? mimeType) {
  final normalized = normalizeExternalImageMimeType(mimeType);
  return normalized != null &&
      supportedExternalImageMimeTypes.contains(normalized);
}

bool isSupportedExternalImageFileName(String? fileName) {
  final extension = externalImageExtensionFromFileName(fileName);
  return extension != null &&
      supportedExternalImageExtensions.contains(extension);
}

String? externalImageExtensionFromMimeType(String? mimeType) {
  final normalized = normalizeExternalImageMimeType(mimeType);
  if (normalized == null) {
    return null;
  }
  return _extensionByMimeType[normalized];
}

String? externalImageExtensionFromFileName(String? fileName) {
  final value = _normalizeOptionalString(fileName);
  if (value == null) {
    return null;
  }
  final withoutQuery = value.split('?').first.split('#').first;
  final segment = _lastPathSegment(withoutQuery);
  final dotIndex = segment.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == segment.length - 1) {
    return null;
  }
  final extension = segment.substring(dotIndex + 1).toLowerCase();
  return supportedExternalImageExtensions.contains(extension)
      ? extension
      : null;
}

String? externalImageExtensionFromBytes(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  if (_startsWith(bytes, const <int>[
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
  ])) {
    return 'png';
  }
  if (_startsWith(bytes, const <int>[0xff, 0xd8, 0xff])) {
    return 'jpg';
  }
  if (_startsWithAscii(bytes, 'GIF87a') || _startsWithAscii(bytes, 'GIF89a')) {
    return 'gif';
  }
  if (bytes.length >= 12 &&
      _startsWithAscii(bytes, 'RIFF') &&
      _asciiAt(bytes, 8, 'WEBP')) {
    return 'webp';
  }
  if (_startsWithAscii(bytes, 'BM')) {
    return 'bmp';
  }
  return null;
}

/// Reads display-oriented pixel dimensions from supported image bytes.
///
/// The result is derived only from the image payload. Invalid, incomplete, or
/// unsupported bytes return `null` so image storage can keep its existing
/// rejection or graceful-degradation path.
ExternalImagePixelSize? externalImagePixelSizeFromBytes(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  try {
    if (_startsWith(bytes, const <int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ])) {
      return _pngPixelSize(bytes);
    }
    if (_startsWith(bytes, const <int>[0xff, 0xd8, 0xff])) {
      return _jpegPixelSize(bytes);
    }
    if (_startsWithAscii(bytes, 'GIF87a') ||
        _startsWithAscii(bytes, 'GIF89a')) {
      return _gifPixelSize(bytes);
    }
    if (bytes.length >= 12 &&
        _startsWithAscii(bytes, 'RIFF') &&
        _asciiAt(bytes, 8, 'WEBP')) {
      return _webpPixelSize(bytes);
    }
    if (_startsWithAscii(bytes, 'BM')) {
      return _bmpPixelSize(bytes);
    }
  } on Object {
    return null;
  }
  return null;
}

ExternalImageInputRejection? _validateImageCandidate({
  Uint8List? bytes,
  String? fileLocation,
  String? mimeType,
  String? fileName,
  int? sizeBytes,
  bool rejectEmptyLocation = false,
}) {
  if (bytes != null && bytes.isEmpty) {
    return const ExternalImageInputRejection(
      reason: ExternalImageInputRejectionReason.emptyData,
      message: 'Image bytes are empty.',
    );
  }
  if (sizeBytes != null && sizeBytes <= 0) {
    return const ExternalImageInputRejection(
      reason: ExternalImageInputRejectionReason.emptyData,
      message: 'Image size is empty.',
    );
  }
  final location = _normalizeOptionalString(fileLocation);
  if (rejectEmptyLocation && location == null) {
    return const ExternalImageInputRejection(
      reason: ExternalImageInputRejectionReason.missingFileLocation,
      message: 'Image file location is empty.',
    );
  }
  if (location != null && _looksLikeDirectoryLocation(location)) {
    return const ExternalImageInputRejection(
      reason: ExternalImageInputRejectionReason.directory,
      message: 'Image file location points to a directory.',
    );
  }
  final hasSupportedType = isSupportedExternalImageMimeType(mimeType) ||
      isSupportedExternalImageFileName(fileName) ||
      isSupportedExternalImageFileName(location) ||
      externalImageExtensionFromBytes(bytes) != null;
  if (!hasSupportedType) {
    return const ExternalImageInputRejection(
      reason: ExternalImageInputRejectionReason.unsupportedImageType,
      message: 'Image type is not supported.',
    );
  }
  return null;
}

ExternalImagePixelSize? _pngPixelSize(Uint8List bytes) {
  if (bytes.length < 24 || !_asciiAt(bytes, 12, 'IHDR')) {
    return null;
  }
  return _positivePixelSize(
    _uint32BigEndian(bytes, 16),
    _uint32BigEndian(bytes, 20),
  );
}

ExternalImagePixelSize? _jpegPixelSize(Uint8List bytes) {
  int? orientation;
  var offset = 2;
  while (offset < bytes.length) {
    while (offset < bytes.length && bytes[offset] != 0xff) {
      offset++;
    }
    while (offset < bytes.length && bytes[offset] == 0xff) {
      offset++;
    }
    if (offset >= bytes.length) {
      return null;
    }

    final marker = bytes[offset++];
    if (marker == 0xd9 || marker == 0xda) {
      return null;
    }
    if (_isStandaloneJpegMarker(marker)) {
      continue;
    }
    if (offset + 2 > bytes.length) {
      return null;
    }

    final segmentLength = _uint16BigEndian(bytes, offset);
    if (segmentLength < 2) {
      return null;
    }
    final segmentDataStart = offset + 2;
    final segmentEnd = offset + segmentLength;
    if (segmentEnd > bytes.length) {
      return null;
    }

    if (marker == 0xe1) {
      orientation ??= _jpegExifOrientation(
        bytes,
        segmentDataStart,
        segmentEnd,
      );
    }
    if (_isJpegStartOfFrameMarker(marker)) {
      if (segmentDataStart + 5 > segmentEnd) {
        return null;
      }
      return _orientedJpegPixelSize(
        width: _uint16BigEndian(bytes, segmentDataStart + 3),
        height: _uint16BigEndian(bytes, segmentDataStart + 1),
        orientation: orientation,
      );
    }
    offset = segmentEnd;
  }
  return null;
}

int? _jpegExifOrientation(
  Uint8List bytes,
  int segmentStart,
  int segmentEnd,
) {
  if (segmentEnd - segmentStart < 14 ||
      !_asciiAt(bytes, segmentStart, 'Exif') ||
      bytes[segmentStart + 4] != 0x00 ||
      bytes[segmentStart + 5] != 0x00) {
    return null;
  }

  final tiffStart = segmentStart + 6;
  final littleEndian = _tiffLittleEndian(bytes, tiffStart, segmentEnd);
  if (littleEndian == null) {
    return null;
  }
  if (_uint16Endian(bytes, tiffStart + 2, littleEndian) != 42) {
    return null;
  }

  final ifdOffset = _uint32Endian(bytes, tiffStart + 4, littleEndian);
  if (ifdOffset > segmentEnd - tiffStart - 2) {
    return null;
  }

  final ifdStart = tiffStart + ifdOffset;
  final entryCount = _uint16Endian(bytes, ifdStart, littleEndian);
  final entriesStart = ifdStart + 2;
  if (entryCount > (segmentEnd - entriesStart) ~/ 12) {
    return null;
  }

  for (var index = 0; index < entryCount; index++) {
    final entryStart = entriesStart + index * 12;
    final tag = _uint16Endian(bytes, entryStart, littleEndian);
    if (tag != 0x0112) {
      continue;
    }

    final type = _uint16Endian(bytes, entryStart + 2, littleEndian);
    final count = _uint32Endian(bytes, entryStart + 4, littleEndian);
    if (type != 3 || count != 1) {
      return null;
    }
    final orientation = _uint16Endian(bytes, entryStart + 8, littleEndian);
    return orientation >= 1 && orientation <= 8 ? orientation : null;
  }
  return null;
}

ExternalImagePixelSize? _orientedJpegPixelSize({
  required int width,
  required int height,
  required int? orientation,
}) {
  if (orientation != null && orientation >= 5 && orientation <= 8) {
    return _positivePixelSize(height, width);
  }
  return _positivePixelSize(width, height);
}

ExternalImagePixelSize? _gifPixelSize(Uint8List bytes) {
  if (bytes.length < 10) {
    return null;
  }
  return _positivePixelSize(
    _uint16LittleEndian(bytes, 6),
    _uint16LittleEndian(bytes, 8),
  );
}

ExternalImagePixelSize? _webpPixelSize(Uint8List bytes) {
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final chunkSize = _uint32LittleEndian(bytes, offset + 4);
    final dataOffset = offset + 8;
    final dataEnd = dataOffset + chunkSize;
    if (dataEnd > bytes.length) {
      return null;
    }

    final size = _asciiAt(bytes, offset, 'VP8X')
        ? _webpExtendedPixelSize(bytes, dataOffset, chunkSize)
        : _asciiAt(bytes, offset, 'VP8L')
            ? _webpLosslessPixelSize(bytes, dataOffset, chunkSize)
            : _asciiAt(bytes, offset, 'VP8 ')
                ? _webpLossyPixelSize(bytes, dataOffset, chunkSize)
                : null;
    if (size != null) {
      return size;
    }

    offset = dataEnd + (chunkSize.isOdd ? 1 : 0);
  }
  return null;
}

ExternalImagePixelSize? _webpExtendedPixelSize(
  Uint8List bytes,
  int dataOffset,
  int chunkSize,
) {
  if (chunkSize < 10) {
    return null;
  }
  return _positivePixelSize(
    _uint24LittleEndian(bytes, dataOffset + 4) + 1,
    _uint24LittleEndian(bytes, dataOffset + 7) + 1,
  );
}

ExternalImagePixelSize? _webpLosslessPixelSize(
  Uint8List bytes,
  int dataOffset,
  int chunkSize,
) {
  if (chunkSize < 5 || bytes[dataOffset] != 0x2f) {
    return null;
  }
  final b0 = bytes[dataOffset + 1];
  final b1 = bytes[dataOffset + 2];
  final b2 = bytes[dataOffset + 3];
  final b3 = bytes[dataOffset + 4];
  return _positivePixelSize(
    (((b1 & 0x3f) << 8) | b0) + 1,
    (((b3 & 0x0f) << 10) | (b2 << 2) | ((b1 & 0xc0) >> 6)) + 1,
  );
}

ExternalImagePixelSize? _webpLossyPixelSize(
  Uint8List bytes,
  int dataOffset,
  int chunkSize,
) {
  if (chunkSize < 10 ||
      bytes[dataOffset + 3] != 0x9d ||
      bytes[dataOffset + 4] != 0x01 ||
      bytes[dataOffset + 5] != 0x2a) {
    return null;
  }
  return _positivePixelSize(
    _uint16LittleEndian(bytes, dataOffset + 6) & 0x3fff,
    _uint16LittleEndian(bytes, dataOffset + 8) & 0x3fff,
  );
}

ExternalImagePixelSize? _bmpPixelSize(Uint8List bytes) {
  if (bytes.length < 26) {
    return null;
  }
  final dibHeaderSize = _uint32LittleEndian(bytes, 14);
  if (dibHeaderSize == 12) {
    return _positivePixelSize(
      _uint16LittleEndian(bytes, 18),
      _uint16LittleEndian(bytes, 20),
    );
  }
  if (dibHeaderSize >= 40) {
    return _positivePixelSize(
      _int32LittleEndian(bytes, 18),
      _int32LittleEndian(bytes, 22).abs(),
    );
  }
  return null;
}

ExternalImagePixelSize? _positivePixelSize(int width, int height) {
  if (width <= 0 || height <= 0) {
    return null;
  }
  return ExternalImagePixelSize(width: width, height: height);
}

bool _isStandaloneJpegMarker(int marker) {
  return marker == 0x01 || marker == 0xd8 || marker >= 0xd0 && marker <= 0xd7;
}

bool _isJpegStartOfFrameMarker(int marker) {
  return switch (marker) {
    0xc0 ||
    0xc1 ||
    0xc2 ||
    0xc3 ||
    0xc5 ||
    0xc6 ||
    0xc7 ||
    0xc9 ||
    0xca ||
    0xcb ||
    0xcd ||
    0xce ||
    0xcf =>
      true,
    _ => false,
  };
}

int _uint16BigEndian(Uint8List bytes, int offset) {
  return bytes[offset] << 8 | bytes[offset + 1];
}

int _uint16LittleEndian(Uint8List bytes, int offset) {
  return bytes[offset] | bytes[offset + 1] << 8;
}

int _uint24LittleEndian(Uint8List bytes, int offset) {
  return bytes[offset] | bytes[offset + 1] << 8 | bytes[offset + 2] << 16;
}

int _uint32BigEndian(Uint8List bytes, int offset) {
  return bytes[offset] << 24 |
      bytes[offset + 1] << 16 |
      bytes[offset + 2] << 8 |
      bytes[offset + 3];
}

int _uint32LittleEndian(Uint8List bytes, int offset) {
  return bytes[offset] |
      bytes[offset + 1] << 8 |
      bytes[offset + 2] << 16 |
      bytes[offset + 3] << 24;
}

bool? _tiffLittleEndian(Uint8List bytes, int offset, int end) {
  if (offset + 8 > end) {
    return null;
  }
  if (_asciiAt(bytes, offset, 'II')) {
    return true;
  }
  if (_asciiAt(bytes, offset, 'MM')) {
    return false;
  }
  return null;
}

int _uint16Endian(Uint8List bytes, int offset, bool littleEndian) {
  return littleEndian
      ? _uint16LittleEndian(bytes, offset)
      : _uint16BigEndian(bytes, offset);
}

int _uint32Endian(Uint8List bytes, int offset, bool littleEndian) {
  return littleEndian
      ? _uint32LittleEndian(bytes, offset)
      : _uint32BigEndian(bytes, offset);
}

int _int32LittleEndian(Uint8List bytes, int offset) {
  final value = _uint32LittleEndian(bytes, offset);
  return value & 0x80000000 == 0 ? value : value - 0x100000000;
}

String? _normalizeOptionalString(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _lastPathSegment(String value) {
  final slash = value.lastIndexOf('/');
  final backslash = value.lastIndexOf('\\');
  final index = slash > backslash ? slash : backslash;
  if (index < 0 || index == value.length - 1) {
    return value;
  }
  return value.substring(index + 1);
}

String? _fileStemFromName(String? value) {
  final normalized = _normalizeOptionalString(value);
  if (normalized == null) {
    return null;
  }
  final withoutQuery = normalized.split('?').first.split('#').first;
  final segment = _decodePathSegment(_lastPathSegment(withoutQuery));
  final cleanSegment = _normalizeOptionalString(segment);
  if (cleanSegment == null) {
    return null;
  }
  final dotIndex = cleanSegment.lastIndexOf('.');
  final stem =
      dotIndex <= 0 ? cleanSegment : cleanSegment.substring(0, dotIndex);
  return _normalizeOptionalString(stem);
}

String _decodePathSegment(String value) {
  try {
    return Uri.decodeComponent(value);
  } on FormatException {
    return value;
  }
}

bool _looksLikeDirectoryLocation(String value) {
  return value.endsWith('/') || value.endsWith('\\');
}

bool _startsWith(Uint8List bytes, List<int> signature) {
  if (bytes.length < signature.length) {
    return false;
  }
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) {
      return false;
    }
  }
  return true;
}

bool _startsWithAscii(Uint8List bytes, String signature) {
  return _asciiAt(bytes, 0, signature);
}

bool _asciiAt(Uint8List bytes, int offset, String signature) {
  if (bytes.length < offset + signature.length) {
    return false;
  }
  for (var i = 0; i < signature.length; i++) {
    if (bytes[offset + i] != signature.codeUnitAt(i)) {
      return false;
    }
  }
  return true;
}

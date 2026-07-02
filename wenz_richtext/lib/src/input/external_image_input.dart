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
  });

  factory ExternalImageBlockDescription.fromInput({
    required ExternalImageInput input,
    required String file,
  }) {
    final label = externalImageDisplayName(input);
    return ExternalImageBlockDescription(
      file: file,
      caption: label,
      altText: label,
    );
  }

  /// Local file path that can be assigned to `ImageBlockNode.file`.
  final String file;

  final String caption;

  final String altText;
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

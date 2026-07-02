import 'dart:io';

import 'external_image_input.dart';

/// Creates the default IO-backed external image store.
ExternalImageStore createDefaultExternalImageStore() =>
    const ExternalImageIoStore();

/// IO implementation that validates existing image files and stores bytes.
class ExternalImageIoStore implements ExternalImageStore {
  const ExternalImageIoStore({
    this.tempDirectory,
    this.now,
  });

  final Directory? tempDirectory;
  final DateTime Function()? now;

  @override
  Future<ExternalImageStoreResult> prepare(ExternalImageInput input) async {
    final rejection = input.rejection;
    if (rejection != null) {
      return ExternalImageStoreResult.failure(rejection);
    }
    return switch (input.kind) {
      ExternalImageInputKind.memory => _prepareMemory(input),
      ExternalImageInputKind.filePath => _prepareFile(input),
      ExternalImageInputKind.fileUri => _prepareFile(input),
    };
  }

  Future<ExternalImageStoreResult> _prepareMemory(
    ExternalImageInput input,
  ) async {
    final bytes = input.bytes;
    if (bytes == null || bytes.isEmpty) {
      return const ExternalImageStoreResult.failure(
        ExternalImageInputRejection(
          reason: ExternalImageInputRejectionReason.emptyData,
          message: 'Image bytes are empty.',
        ),
      );
    }
    final extension = input.imageExtension;
    if (extension == null) {
      return const ExternalImageStoreResult.failure(
        ExternalImageInputRejection(
          reason: ExternalImageInputRejectionReason.unsupportedImageType,
          message: 'Image type is not supported.',
        ),
      );
    }

    File? outputFile;
    try {
      final directory = await _ensureTempDirectory();
      outputFile = await _createTempFile(directory, extension);
      await outputFile.writeAsBytes(bytes, flush: true);
      return ExternalImageStoreResult.success(
        ExternalImageBlockDescription.fromInput(
          input: input,
          file: outputFile.path,
        ),
      );
    } on Object catch (error) {
      if (outputFile != null) {
        await _deletePartialFile(outputFile);
      }
      return ExternalImageStoreResult.failure(
        ExternalImageInputRejection(
          reason: ExternalImageInputRejectionReason.writeFailed,
          message: 'Failed to store external image bytes: $error',
        ),
      );
    }
  }

  Future<ExternalImageStoreResult> _prepareFile(
    ExternalImageInput input,
  ) async {
    final resolution = _fileForInput(input);
    final resolutionRejection = resolution.rejection;
    if (resolutionRejection != null) {
      return ExternalImageStoreResult.failure(resolutionRejection);
    }
    final file = resolution.file;
    if (file == null) {
      return const ExternalImageStoreResult.failure(
        ExternalImageInputRejection(
          reason: ExternalImageInputRejectionReason.missingFileLocation,
          message: 'Image file location is empty.',
        ),
      );
    }

    try {
      final type = await FileSystemEntity.type(file.path, followLinks: true);
      if (type == FileSystemEntityType.notFound) {
        return const ExternalImageStoreResult.failure(
          ExternalImageInputRejection(
            reason: ExternalImageInputRejectionReason.fileNotFound,
            message: 'Image file does not exist.',
          ),
        );
      }
      if (type == FileSystemEntityType.directory) {
        return const ExternalImageStoreResult.failure(
          ExternalImageInputRejection(
            reason: ExternalImageInputRejectionReason.directory,
            message: 'Image file location points to a directory.',
          ),
        );
      }
      if (type != FileSystemEntityType.file) {
        return const ExternalImageStoreResult.failure(
          ExternalImageInputRejection(
            reason: ExternalImageInputRejectionReason.notAFile,
            message: 'Image file location is not a regular file.',
          ),
        );
      }
      final length = await file.length();
      if (length <= 0) {
        return const ExternalImageStoreResult.failure(
          ExternalImageInputRejection(
            reason: ExternalImageInputRejectionReason.emptyData,
            message: 'Image file is empty.',
          ),
        );
      }
      final canonicalPath = await _canonicalFilePath(file);
      return ExternalImageStoreResult.success(
        ExternalImageBlockDescription.fromInput(
          input: input,
          file: canonicalPath,
        ),
      );
    } on Object catch (error) {
      return ExternalImageStoreResult.failure(
        ExternalImageInputRejection(
          reason: ExternalImageInputRejectionReason.fileAccessFailed,
          message: 'Failed to access external image file: $error',
        ),
      );
    }
  }

  _FileResolution _fileForInput(ExternalImageInput input) {
    return switch (input.kind) {
      ExternalImageInputKind.filePath => _fileFromPath(input.filePath),
      ExternalImageInputKind.fileUri => _fileFromUri(input.fileUri),
      ExternalImageInputKind.memory => const _FileResolution.failure(
          ExternalImageInputRejection(
            reason: ExternalImageInputRejectionReason.missingFileLocation,
            message: 'Image file location is empty.',
          ),
        ),
    };
  }

  _FileResolution _fileFromPath(String? path) {
    final normalized = path?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const _FileResolution.failure(
        ExternalImageInputRejection(
          reason: ExternalImageInputRejectionReason.missingFileLocation,
          message: 'Image file location is empty.',
        ),
      );
    }
    return _FileResolution.file(File(normalized));
  }

  _FileResolution _fileFromUri(Uri? uri) {
    if (uri == null) {
      return const _FileResolution.failure(
        ExternalImageInputRejection(
          reason: ExternalImageInputRejectionReason.missingFileLocation,
          message: 'Image file location is empty.',
        ),
      );
    }
    try {
      return _FileResolution.file(File.fromUri(uri));
    } on Object catch (error) {
      return _FileResolution.failure(
        ExternalImageInputRejection(
          reason: ExternalImageInputRejectionReason.fileAccessFailed,
          message: 'Failed to read file URI: $error',
        ),
      );
    }
  }

  Future<Directory> _ensureTempDirectory() async {
    final directory = tempDirectory ??
        Directory(_joinPath(
          Directory.systemTemp.path,
          'wenz_richtext_external_images',
        ));
    return directory.create(recursive: true);
  }

  Future<File> _createTempFile(Directory directory, String extension) async {
    final timestamp =
        (now ?? DateTime.now)().toUtc().microsecondsSinceEpoch.toString();
    for (var attempt = 0; attempt < 1000; attempt++) {
      final suffix = attempt == 0 ? '' : '-$attempt';
      final path = _joinPath(
        directory.path,
        '$externalImageTempFilePrefix-$timestamp$suffix.$extension',
      );
      final file = File(path);
      try {
        return await file.create(exclusive: true);
      } on FileSystemException {
        if (await file.exists()) {
          continue;
        }
        rethrow;
      }
    }
    throw FileSystemException(
      'Unable to allocate a unique image temp file.',
      directory.path,
    );
  }

  Future<String> _canonicalFilePath(File file) async {
    try {
      return await file.resolveSymbolicLinks();
    } on FileSystemException {
      return file.absolute.path;
    }
  }

  Future<void> _deletePartialFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Best-effort cleanup only; the original write error is more useful.
    }
  }
}

class _FileResolution {
  const _FileResolution.file(this.file) : rejection = null;

  const _FileResolution.failure(this.rejection) : file = null;

  final File? file;
  final ExternalImageInputRejection? rejection;
}

String _joinPath(String parent, String child) {
  if (parent.endsWith(Platform.pathSeparator)) {
    return '$parent$child';
  }
  return '$parent${Platform.pathSeparator}$child';
}

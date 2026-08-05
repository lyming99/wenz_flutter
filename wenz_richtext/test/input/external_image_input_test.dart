import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/src/input/external_image_input.dart';
import 'package:wenz_richtext/src/input/external_image_store_io.dart' as io;
import 'package:wenz_richtext/src/input/external_image_store_stub.dart' as stub;

void main() {
  group('ExternalImageInput', () {
    test('detects supported image types from MIME, extension, and bytes', () {
      expect(isSupportedExternalImageMimeType('image/jpeg; charset=binary'),
          isTrue);
      expect(isSupportedExternalImageFileName('photo.WEBP'), isTrue);
      expect(isSupportedExternalImageFileName('scan.bmp'), isTrue);
      expect(isSupportedExternalImageMimeType('image/x-ms-bmp'), isTrue);
      expect(externalImageExtensionFromBytes(_pngBytes), 'png');
      expect(externalImageExtensionFromBytes(_jpegBytes), 'jpg');
      expect(externalImageExtensionFromBytes(_gifBytes), 'gif');
      expect(externalImageExtensionFromBytes(_webpBytes), 'webp');
      expect(externalImageExtensionFromBytes(_bmpBytes), 'bmp');
      expect(
        externalImageExtensionFromBytes(Uint8List.fromList(<int>[1, 2, 3])),
        isNull,
      );
    });

    test('parses platform file locations without throwing', () {
      final windowsPath = ExternalImageInput.fileLocation(
        location: r'C:\tmp\photo.PNG',
        source: ExternalImageInputSource.clipboard,
      );
      final posixPath = ExternalImageInput.filePath(
        path: '/tmp/photo.jpeg',
        source: ExternalImageInputSource.drop,
      );
      final remoteUri = ExternalImageInput.fileLocation(
        location: 'https://example.test/photo.png',
        source: ExternalImageInputSource.drop,
      );

      expect(windowsPath.kind, ExternalImageInputKind.filePath);
      expect(windowsPath.isAccepted, isTrue);
      expect(posixPath.imageExtension, 'jpeg');
      expect(remoteUri.isRejected, isTrue);
      expect(
        remoteUri.rejection?.reason,
        ExternalImageInputRejectionReason.unsupportedUriScheme,
      );
    });

    test('rejects empty, directory, and non-image candidates early', () {
      final emptyMemory = ExternalImageInput.memory(
        bytes: Uint8List(0),
        source: ExternalImageInputSource.clipboard,
        mimeType: 'image/png',
      );
      final directory = ExternalImageInput.filePath(
        path: '/tmp/images/',
        source: ExternalImageInputSource.drop,
      );
      final textFile = ExternalImageInput.filePath(
        path: '/tmp/readme.txt',
        source: ExternalImageInputSource.drop,
      );

      expect(emptyMemory.rejection?.reason,
          ExternalImageInputRejectionReason.emptyData);
      expect(directory.rejection?.reason,
          ExternalImageInputRejectionReason.directory);
      expect(textFile.rejection?.reason,
          ExternalImageInputRejectionReason.unsupportedImageType);
    });

    test('derives display names from decoded file URI path segments', () {
      final input = ExternalImageInput.fileUri(
        uri: Uri.parse('file:///tmp/Screen%20Shot%201.png'),
        source: ExternalImageInputSource.clipboard,
      );

      expect(input.isAccepted, isTrue);
      expect(externalImageDisplayName(input), 'Screen Shot 1');
    });
  });

  group('ExternalImageIoStore', () {
    test('writes memory images to the configured temp directory', () async {
      final tempDir = await _createTempDir();
      final store = io.ExternalImageIoStore(
        tempDirectory: tempDir,
        now: () => DateTime.fromMicrosecondsSinceEpoch(42, isUtc: true),
      );
      final input = ExternalImageInput.memory(
        bytes: _pngBytes,
        source: ExternalImageInputSource.clipboard,
        mimeType: 'image/png',
      );

      final result = await store.prepare(input);

      expect(result.isSuccess, isTrue);
      final description = result.description!;
      final output = File(description.file);
      expect(output.parent.path, tempDir.path);
      expect(_basename(output.path), '$externalImageTempFilePrefix-42.png');
      expect(await output.readAsBytes(), _pngBytes);
      expect(description.caption, defaultExternalImageCaption);
      expect(description.altText, defaultExternalImageCaption);
    });

    test('derives image descriptions from memory filenames', () async {
      final tempDir = await _createTempDir();
      final store = io.ExternalImageIoStore(tempDirectory: tempDir);
      final input = ExternalImageInput.memory(
        bytes: _jpegBytes,
        source: ExternalImageInputSource.clipboard,
        fileName: 'Screen Shot 1.JPG',
      );

      final result = await store.prepare(input);

      expect(result.isSuccess, isTrue);
      final description = result.description!;
      expect(description.file, endsWith('.jpg'));
      expect(description.caption, 'Screen Shot 1');
      expect(description.altText, 'Screen Shot 1');
    });

    test('uses bytes signatures when memory image metadata is missing',
        () async {
      final tempDir = await _createTempDir();
      final store = io.ExternalImageIoStore(
        tempDirectory: tempDir,
        now: () => DateTime.fromMicrosecondsSinceEpoch(84, isUtc: true),
      );
      final input = ExternalImageInput.memory(
        bytes: _bmpBytes,
        source: ExternalImageInputSource.clipboard,
      );

      final result = await store.prepare(input);

      expect(result.isSuccess, isTrue);
      expect(_basename(result.description!.file),
          '$externalImageTempFilePrefix-84.bmp');
      expect(result.description!.caption, defaultExternalImageCaption);
    });

    test('validates existing file paths and file URIs', () async {
      final tempDir = await _createTempDir();
      final pathFile = File(_joinPath(tempDir.path, 'photo.jpg'));
      final uriFile = File(_joinPath(tempDir.path, 'uri image.webp'));
      await pathFile.writeAsBytes(_jpegBytes);
      await uriFile.writeAsBytes(_webpBytes);
      final store = io.ExternalImageIoStore(tempDirectory: tempDir);

      final pathResult = await store.prepare(
        ExternalImageInput.filePath(
          path: pathFile.path,
          source: ExternalImageInputSource.drop,
        ),
      );
      final uriResult = await store.prepare(
        ExternalImageInput.fileUri(
          uri: uriFile.uri,
          source: ExternalImageInputSource.clipboard,
        ),
      );

      expect(pathResult.isSuccess, isTrue);
      expect(
        pathResult.description!.file,
        await pathFile.resolveSymbolicLinks(),
      );
      expect(pathResult.description!.caption, 'photo');
      expect(uriResult.isSuccess, isTrue);
      expect(uriResult.description!.file, await uriFile.resolveSymbolicLinks());
      expect(uriResult.description!.caption, 'uri image');
    });

    test('returns diagnostic failures for invalid files and write errors',
        () async {
      final tempDir = await _createTempDir();
      final store = io.ExternalImageIoStore(tempDirectory: tempDir);
      final emptyImage = File(_joinPath(tempDir.path, 'empty.png'));
      final imageDirectory = Directory(_joinPath(tempDir.path, 'folder.png'));
      await emptyImage.create();
      await imageDirectory.create();

      final emptyResult = await store.prepare(
        ExternalImageInput.filePath(
          path: emptyImage.path,
          source: ExternalImageInputSource.drop,
        ),
      );
      final directoryResult = await store.prepare(
        ExternalImageInput.filePath(
          path: imageDirectory.path,
          source: ExternalImageInputSource.drop,
        ),
      );
      final textResult = await store.prepare(
        ExternalImageInput.filePath(
          path: _joinPath(tempDir.path, 'note.txt'),
          source: ExternalImageInputSource.drop,
        ),
      );
      final missingResult = await store.prepare(
        ExternalImageInput.filePath(
          path: _joinPath(tempDir.path, 'missing.png'),
          source: ExternalImageInputSource.drop,
        ),
      );
      final blockedTempRoot = File(_joinPath(tempDir.path, 'not-a-directory'));
      await blockedTempRoot.writeAsBytes(<int>[1]);
      final blockedStore = io.ExternalImageIoStore(
        tempDirectory: Directory(blockedTempRoot.path),
      );
      final writeResult = await blockedStore.prepare(
        ExternalImageInput.memory(
          bytes: _pngBytes,
          source: ExternalImageInputSource.clipboard,
          mimeType: 'image/png',
        ),
      );

      expect(emptyResult.rejection?.reason,
          ExternalImageInputRejectionReason.emptyData);
      expect(directoryResult.rejection?.reason,
          ExternalImageInputRejectionReason.directory);
      expect(textResult.rejection?.reason,
          ExternalImageInputRejectionReason.unsupportedImageType);
      expect(missingResult.rejection?.reason,
          ExternalImageInputRejectionReason.fileNotFound);
      expect(writeResult.rejection?.reason,
          ExternalImageInputRejectionReason.writeFailed);
    });
  });

  group('ExternalImageStubStore', () {
    test('keeps unsupported platforms as no-op failures', () async {
      final input = ExternalImageInput.memory(
        bytes: _pngBytes,
        source: ExternalImageInputSource.clipboard,
        mimeType: 'image/png',
      );

      final result = await (const stub.ExternalImageStubStore()).prepare(input);

      expect(result.isFailure, isTrue);
      expect(result.rejection?.reason,
          ExternalImageInputRejectionReason.unsupportedPlatform);
    });
  });
}

final Uint8List _pngBytes = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
]);

final Uint8List _jpegBytes = Uint8List.fromList(<int>[
  0xff,
  0xd8,
  0xff,
  0x00,
]);

final Uint8List _webpBytes = Uint8List.fromList(<int>[
  0x52,
  0x49,
  0x46,
  0x46,
  0x00,
  0x00,
  0x00,
  0x00,
  0x57,
  0x45,
  0x42,
  0x50,
]);

final Uint8List _gifBytes = Uint8List.fromList(<int>[
  0x47,
  0x49,
  0x46,
  0x38,
  0x39,
  0x61,
]);

final Uint8List _bmpBytes = Uint8List.fromList(<int>[
  0x42,
  0x4d,
  0x00,
  0x00,
]);

Future<Directory> _createTempDir() async {
  final directory =
      await Directory.systemTemp.createTemp('wenz_external_image_input_test_');
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return directory;
}

String _joinPath(String parent, String child) {
  if (parent.endsWith(Platform.pathSeparator)) {
    return '$parent$child';
  }
  return '$parent${Platform.pathSeparator}$child';
}

String _basename(String path) {
  final slash = path.lastIndexOf('/');
  final backslash = path.lastIndexOf('\\');
  final index = slash > backslash ? slash : backslash;
  if (index < 0 || index == path.length - 1) {
    return path;
  }
  return path.substring(index + 1);
}

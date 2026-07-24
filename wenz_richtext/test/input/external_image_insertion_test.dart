import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('Word clipboard image insertion candidates', () {
    test('prefers the original file and consumes its bitmap flavor once',
        () async {
      final original = ExternalImageInput.fileUri(
        uri: Uri.parse('file:///C:/Temp/Word/image001.png'),
        source: ExternalImageInputSource.clipboard,
        fileName: 'image001.png',
      );
      final bitmap = _bitmap('image001.png');
      final store = _RecordingStore(<ExternalImageInput, Object>{
        original: _description('original-asset', 2400, 1600),
        bitmap: _description('bitmap-asset', 300, 200),
      });

      final descriptions = await prepareExternalImagesForInsertion(
        <ExternalImageInput>[original, bitmap],
        store: store,
      );

      expect(store.inputs, <ExternalImageInput>[original]);
      expect(descriptions, hasLength(1));
      expect(descriptions.single.file, 'original-asset');
      expect(descriptions.single.width, 2400);
      expect(descriptions.single.height, 1600);
    });

    test('uses the rendered bitmap when the original file cannot be stored',
        () async {
      final original = ExternalImageInput.filePath(
        path: r'C:\Temp\Word\missing-image001.png',
        source: ExternalImageInputSource.clipboard,
      );
      final bitmap = _bitmap('missing-image001.png');
      final store = _RecordingStore(<ExternalImageInput, Object>{
        original: const ExternalImageInputRejection(
          reason: ExternalImageInputRejectionReason.fileNotFound,
          message: 'Word temporary file expired.',
        ),
        bitmap: _description('bitmap-fallback', 300, 200),
      });

      final descriptions = await prepareExternalImagesForInsertion(
        <ExternalImageInput>[original, bitmap],
        store: store,
      );

      expect(store.inputs, <ExternalImageInput>[original, bitmap]);
      expect(descriptions, hasLength(1));
      expect(descriptions.single.file, 'bitmap-fallback');
      expect(descriptions.single.width, 300);
      expect(descriptions.single.height, 200);
    });

    test('keeps distinct Word images in clipboard order without duplicates',
        () async {
      final firstOriginal = ExternalImageInput.filePath(
        path: r'C:\Temp\Word\image001.png',
        source: ExternalImageInputSource.clipboard,
      );
      final firstBitmap = _bitmap('image001.png');
      final secondOriginal = ExternalImageInput.filePath(
        path: r'C:\Temp\Word\image002.png',
        source: ExternalImageInputSource.clipboard,
      );
      final secondBitmap = _bitmap('image002.png');
      final store = _RecordingStore(<ExternalImageInput, Object>{
        firstOriginal: _description('first-original', 1800, 1200),
        firstBitmap: _description('first-bitmap', 300, 200),
        secondOriginal: _description('second-original', 1600, 900),
        secondBitmap: _description('second-bitmap', 320, 180),
      });

      final descriptions = await prepareExternalImagesForInsertion(
        <ExternalImageInput>[
          firstOriginal,
          firstBitmap,
          secondOriginal,
          secondBitmap,
        ],
        store: store,
      );

      expect(
        store.inputs,
        <ExternalImageInput>[firstOriginal, secondOriginal],
      );
      expect(
        descriptions.map((description) => description.file),
        <String>['first-original', 'second-original'],
      );
    });
  });
}

ExternalImageInput _bitmap(String fileName) {
  return ExternalImageInput.memory(
    bytes: Uint8List.fromList(_fakePngBytes(width: 300, height: 200)),
    source: ExternalImageInputSource.clipboard,
    mimeType: 'image/png',
    fileName: fileName,
  );
}

ExternalImageBlockDescription _description(
  String file,
  int width,
  int height,
) {
  return ExternalImageBlockDescription(
    file: file,
    caption: file,
    altText: file,
    width: width,
    height: height,
  );
}

List<int> _fakePngBytes({required int width, required int height}) {
  return <int>[
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    0x00,
    0x00,
    0x00,
    0x0d,
    0x49,
    0x48,
    0x44,
    0x52,
    (width >> 24) & 0xff,
    (width >> 16) & 0xff,
    (width >> 8) & 0xff,
    width & 0xff,
    (height >> 24) & 0xff,
    (height >> 16) & 0xff,
    (height >> 8) & 0xff,
    height & 0xff,
  ];
}

class _RecordingStore implements ExternalImageStore {
  _RecordingStore(this.results);

  final Map<ExternalImageInput, Object> results;
  final List<ExternalImageInput> inputs = <ExternalImageInput>[];

  @override
  Future<ExternalImageStoreResult> prepare(ExternalImageInput input) async {
    inputs.add(input);
    final result = results[input];
    if (result is ExternalImageBlockDescription) {
      return ExternalImageStoreResult.success(result);
    }
    return ExternalImageStoreResult.failure(
      result! as ExternalImageInputRejection,
    );
  }
}

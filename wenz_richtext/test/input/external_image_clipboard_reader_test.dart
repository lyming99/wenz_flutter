import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('Word clipboard HTML image extraction', () {
    test('reads accessible file URI from CF_HTML img before fallback data',
        () async {
      final directory = await Directory.systemTemp.createTemp('wenz-word-img-');
      addTearDown(() => directory.delete(recursive: true));
      final original = File('${directory.path}${Platform.pathSeparator}原图.png');
      await original.writeAsBytes(const <int>[1]);
      final html = '''Version:1.0\r
StartHTML:0000000105\r
EndHTML:0000000300\r
SourceURL:about:blank\r
<html><body><!--StartFragment-->
<img src="${original.uri}">
<!--EndFragment--></body></html>''';

      final inputs = await externalImageInputsFromClipboardHtml(html);

      expect(inputs, hasLength(1));
      expect(inputs.single.kind, ExternalImageInputKind.fileUri);
      expect(inputs.single.fileUri, original.uri);
      expect(inputs.single.fileName, '原图.png');
      expect(inputs.single.isAccepted, isTrue);
    });

    test('reads local path and Office VML image data sources', () async {
      final checkedLocations = <String>[];
      const localPath = r'C:\Users\tester\AppData\Local\Temp\original.jpg';
      const vmlUri = 'file:///C:/Users/tester/AppData/Local/Temp/vector.png';
      const html = '''<html xmlns:v="urn:schemas-microsoft-com:vml"><body>
<img src="$localPath">
<v:shape><v:imagedata src="$vmlUri" o:title=""></v:imagedata></v:shape>
</body></html>''';

      final inputs = await externalImageInputsFromClipboardHtml(
        html,
        fileExists: (location) async {
          checkedLocations.add(location);
          return true;
        },
      );

      expect(checkedLocations, <String>[localPath, vmlUri]);
      expect(inputs, hasLength(2));
      expect(inputs[0].kind, ExternalImageInputKind.filePath);
      expect(inputs[0].filePath, localPath);
      expect(inputs[0].fileName, 'original.jpg');
      expect(inputs[1].kind, ExternalImageInputKind.fileUri);
      expect(inputs[1].fileUri, Uri.parse(vmlUri));
      expect(inputs[1].fileName, 'vector.png');
    });

    test('resolves filenames against local base and keeps originals first',
        () async {
      final checkedLocations = <String>[];
      const html =
          '''<html><head><base href="file:///C:/Temp/Word/"></head><body>
<img data-original-src="original.png" src="preview.png">
</body></html>''';

      final inputs = await externalImageInputsFromClipboardHtml(
        html,
        fileExists: (location) async {
          checkedLocations.add(location);
          return true;
        },
      );

      expect(
        checkedLocations,
        <String>[
          'file:///C:/Temp/Word/original.png',
          'file:///C:/Temp/Word/preview.png',
        ],
      );
      expect(inputs.map((input) => input.fileName), <String>[
        'original.png',
        'preview.png',
      ]);
    });

    test('uses a local CF_HTML SourceURL to resolve a filename', () async {
      const html = '''Version:1.0\r
SourceURL:file:///C:/Temp/Word/document.docx\r
<html><body><img src="media/image1.png"></body></html>''';

      final inputs = await externalImageInputsFromClipboardHtml(
        html,
        fileExists: (location) async => true,
      );

      expect(inputs, hasLength(1));
      expect(
        inputs.single.fileUri,
        Uri.parse('file:///C:/Temp/Word/media/image1.png'),
      );
      expect(inputs.single.fileName, 'image1.png');
    });

    test('ignores remote, non-image, duplicate, and inaccessible sources',
        () async {
      const html = '''<html><body>
<img src="https://example.com/remote.png">
<img src="data:image/png;base64,AAAA">
<img src="file:///C:/Temp/readme.txt">
<img src="file:///C:/Temp/missing.png">
<img src="file:///C:/Temp/available.png">
<v:imagedata src="C:\\Temp\\available.png"></v:imagedata>
</body></html>''';

      final inputs = await externalImageInputsFromClipboardHtml(
        html,
        fileExists: (location) async => location.endsWith('available.png'),
      );

      expect(inputs, hasLength(1));
      expect(inputs.single.fileName, 'available.png');
    });

    test('returns no candidates for empty or ordinary non-local HTML',
        () async {
      expect(await externalImageInputsFromClipboardHtml(null), isEmpty);
      expect(await externalImageInputsFromClipboardHtml('  '), isEmpty);
      expect(
        await externalImageInputsFromClipboardHtml(
          '<p>Text only</p><img src="https://example.com/image.png">',
          fileExists: (_) async => true,
        ),
        isEmpty,
      );
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/src/canvas/image_loader.dart';
import 'package:wenz_draw/src/elements/image_element.dart';
import 'package:wenz_draw/src/serialization/canvas_serializer.dart';

void main() {
  group('ImageSource', () {
    test('isEmpty is true when no reference is set', () {
      expect(const ImageSource().isEmpty, isTrue);
    });

    test('isEmpty is false when any reference is set', () {
      expect(const ImageSource(base64: 'abc').isEmpty, isFalse);
      expect(const ImageSource(url: 'https://x').isEmpty, isFalse);
      expect(const ImageSource(filePath: '/a/b.png').isEmpty, isFalse);
    });

    test('equality covers all fields', () {
      const a = ImageSource(base64: 'abc', maxWidth: 100);
      const b = ImageSource(base64: 'abc', maxWidth: 100);
      const c = ImageSource(base64: 'abc', maxWidth: 200);
      expect(a, b);
      expect(a, isNot(c));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('ImageLoaderRegistry built-ins', () {
    test('base64 loader decodes a tiny PNG', () async {
      final png = await _encodePng(2, 2);
      final base64 = _base64(png);
      final registry = _freshRegistry();
      addTearDown(registry.clear);

      final image = await registry.load(ImageSource(base64: base64));
      expect(image, isNotNull);
      expect(image!.width, 2);
      expect(image.height, 2);
    });

    test('raw-bytes loader decodes identical bytes', () async {
      final png = await _encodePng(3, 1);
      final registry = _freshRegistry();
      addTearDown(registry.clear);

      final image = await registry.load(
        ImageSource(bytes: Uint8List.fromList(png)),
      );
      expect(image, isNotNull);
      expect(image!.width, 3);
    });

    test('returns null for an empty source', () async {
      final registry = _freshRegistry();
      addTearDown(registry.clear);
      expect(await registry.load(const ImageSource()), isNull);
    });

    test('caches repeat lookups for the same source', () async {
      final png = await _encodePng(2, 2);
      final base64 = _base64(png);
      final registry = _freshRegistry();
      addTearDown(registry.clear);

      final first = await registry.load(ImageSource(base64: base64));
      final second = await registry.load(ImageSource(base64: base64));
      expect(identical(first, second), isTrue);
    });
  });

  group('ImageLoaderRegistry custom loaders', () {
    test('a registered custom loader wins for supported sources', () async {
      final registry = _freshRegistry();
      addTearDown(registry.clear);
      final fake = _FakeImageLoader();
      registry.register(fake);

      final image = await registry.load(
        const ImageSource(assetId: 'oss://bucket/key.png'),
      );
      expect(image, same(fake.fakeImage));
      expect(fake.loadCalls, 1);
    });

    test('evict disposes and forces a re-decode', () async {
      final registry = _freshRegistry();
      addTearDown(registry.clear);
      final fake = _FakeImageLoader();
      registry.register(fake);

      await registry.load(const ImageSource(assetId: 'oss://bucket/key.png'));
      expect(fake.fakeImage.disposed, isFalse);
      registry.evict(const ImageSource(assetId: 'oss://bucket/key.png'));
      expect(fake.fakeImage.disposed, isTrue);
    });
  });

  group('ImageElement.toImageSource', () {
    test('imageData takes priority over url and filePath', () {
      const element = ImageElement(
        id: 'i1',
        rect: Rect.fromLTWH(0, 0, 10, 10),
        imageData: 'base64data',
        url: 'https://example.com/a.png',
        filePath: '/tmp/a.png',
      );
      final source = element.toImageSource();
      expect(source.base64, 'base64data');
      expect(source.url, isNull);
      expect(source.filePath, isNull);
    });

    test('url is used when imageData is absent', () {
      const element = ImageElement(
        id: 'i1',
        rect: Rect.fromLTWH(0, 0, 10, 10),
        url: 'https://example.com/a.png',
        filePath: '/tmp/a.png',
      );
      final source = element.toImageSource();
      expect(source.url, 'https://example.com/a.png');
      expect(source.filePath, isNull);
    });

    test('filePath is used when only it is present', () {
      const element = ImageElement(
        id: 'i1',
        rect: Rect.fromLTWH(0, 0, 10, 10),
        filePath: '/tmp/a.png',
      );
      final source = element.toImageSource();
      expect(source.filePath, '/tmp/a.png');
    });

    test('empty source when nothing is set', () {
      const element = ImageElement(
        id: 'i1',
        rect: Rect.fromLTWH(0, 0, 10, 10),
      );
      expect(element.toImageSource().isEmpty, isTrue);
    });
  });

  group('ImageElement serialization round-trip', () {
    test('preserves url and filePath', () {
      const element = ImageElement(
        id: 'img-1',
        rect: Rect.fromLTWH(10, 20, 100, 80),
        url: 'https://cdn.example.com/photo.png',
        filePath: '/home/user/photo.png',
        fit: BoxFit.cover,
        rotation: 0.5,
        opacity: 0.8,
        zIndex: 7,
      );

      final json = element.toJson();
      final restored = CanvasSerializer.elementFromJson(json) as ImageElement;

      expect(restored.id, 'img-1');
      expect(restored.url, 'https://cdn.example.com/photo.png');
      expect(restored.filePath, '/home/user/photo.png');
      expect(restored.fit, BoxFit.cover);
      expect(restored.rotation, 0.5);
      expect(restored.opacity, 0.8);
      expect(restored.zIndex, 7);
      expect(restored.rect, const Rect.fromLTWH(10, 20, 100, 80));
    });

    test('preserves imageData (base64) and omits null sources', () {
      const element = ImageElement(
        id: 'img-2',
        rect: Rect.fromLTWH(0, 0, 10, 10),
        imageData: 'base64payload',
      );

      final json = element.toJson();
      expect(json.containsKey('url'), isFalse);
      expect(json.containsKey('filePath'), isFalse);
      expect(json['imageData'], 'base64payload');

      final restored = CanvasSerializer.elementFromJson(json) as ImageElement;
      expect(restored.imageData, 'base64payload');
    });
  });
}

/// Builds a registry with built-ins but otherwise isolated from the shared
/// singleton, so tests do not pollute global state.
ImageLoaderRegistry _freshRegistry() {
  final registry = ImageLoaderRegistry.forTesting();
  registry.ensureBuiltInsRegistered();
  return registry;
}

Future<List<int>> _encodePng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const Color(0xFFFF0000),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return byteData!.buffer.asUint8List().toList();
}

String _base64(List<int> bytes) => base64.encode(bytes);

class _FakeImageLoader extends ImageLoader {
  final _DisposableFakeImage fakeImage = _DisposableFakeImage();

  int loadCalls = 0;

  @override
  bool supports(ImageSource source) => source.assetId != null;

  @override
  Future<ui.Image> load(ImageSource source) async {
    loadCalls++;
    return fakeImage;
  }
}

class _DisposableFakeImage implements ui.Image {
  bool disposed = false;

  @override
  int get width => 1;

  @override
  int get height => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #dispose) {
      disposed = true;
      return null;
    }
    return super.noSuchMethod(invocation);
  }
}

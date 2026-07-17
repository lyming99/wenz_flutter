import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/src/canvas/canvas_controller.dart';
import 'package:wenz_draw/src/canvas/image_loader.dart';
import 'package:wenz_draw/src/elements/image_element.dart';
import 'package:wenz_draw/src/infinite_canvas/canvas_transform.dart';
import 'package:wenz_draw/src/infinite_canvas/infinite_canvas_config.dart';
import 'package:wenz_draw/src/infinite_canvas/infinite_canvas_controller.dart';
import 'package:wenz_draw/src/infinite_canvas/infinite_canvas_widget.dart';
import 'package:wenz_draw/src/serialization/canvas_serializer.dart';
import 'package:wenz_draw/src/tools/pan_tool.dart';
import 'package:wenz_draw/src/widgets/canvas_image_resolver.dart';

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

  group('CanvasImageResolver', () {
    test(
      'resolves existing images immediately while pan stays active',
      () async {
        final registry = _freshRegistry();
        final fake = _FakeImageLoader();
        registry.register(fake);
        final controller = CanvasController()..imageLoaders = registry;
        controller.addElement(
          const ImageElement(
            id: 'existing-image',
            rect: Rect.fromLTWH(0, 0, 100, 80),
            url: 'https://example.com/existing.png',
          ),
          record: false,
        );
        controller.setTool(PanTool.idValue);

        final resolver = CanvasImageResolver(controller);
        try {
          await pumpEventQueue();

          final resolved =
              controller.elementById('existing-image') as ImageElement;
          expect(resolved.image, same(fake.fakeImage));
          expect(fake.loadCalls, 1);
          expect(controller.currentTool?.id, PanTool.idValue);
        } finally {
          resolver.dispose();
          controller.dispose();
          registry.clear();
        }
      },
    );

    testWidgets('rebinds when the canvas widget controller changes', (
      tester,
    ) async {
      final registry = _freshRegistry();
      final fake = _FakeImageLoader();
      registry.register(fake);
      final firstCanvasController = CanvasController();
      final firstViewController = InfiniteCanvasController(
        canvasController: firstCanvasController,
      );
      final secondCanvasController = CanvasController()
        ..imageLoaders = registry;
      final secondViewController = InfiniteCanvasController(
        canvasController: secondCanvasController,
      );
      secondCanvasController.addElement(
        const ImageElement(
          id: 'replacement-image',
          // Keep the fake ui.Image outside the viewport so the engine never
          // attempts to paint it; this test only exercises resolver rebinding.
          rect: Rect.fromLTWH(10000, 10000, 100, 80),
          url: 'https://example.com/replacement.png',
        ),
        record: false,
      );

      Widget board(InfiniteCanvasController controller) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.square(
            dimension: 100,
            child: InfiniteCanvasWidget(controller: controller),
          ),
        );
      }

      try {
        await tester.pumpWidget(board(firstViewController));
        await tester.pump();
        await tester.pumpWidget(board(secondViewController));
        await tester.pump();

        final resolved =
            secondCanvasController.elementById('replacement-image')
                as ImageElement;
        expect(resolved.image, same(fake.fakeImage));
        expect(fake.loadCalls, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        firstViewController.dispose();
        firstCanvasController.dispose();
        secondViewController.dispose();
        secondCanvasController.dispose();
        registry.clear();
      }
    });
  });

  group('Image rendering level of detail', () {
    testWidgets(
      'keeps image decoded below threshold and restores content after zoom',
      (tester) async {
        final sourceImage = (await tester.runAsync(
          () => _solidImage(2, 2, const Color(0xFFFF0000)),
        ))!;
        final canvasController = CanvasController();
        final viewController = InfiniteCanvasController(
          canvasController: canvasController,
          transform: const CanvasTransform(scale: 0.2),
        );
        canvasController.addElement(
          ImageElement(
            id: 'image-lod',
            rect: const Rect.fromLTWH(0, 0, 100, 100),
            image: sourceImage,
          ),
          record: false,
        );
        final boundaryKey = GlobalKey();

        try {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: SizedBox.square(
                  dimension: 100,
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: InfiniteCanvasWidget(
                      controller: viewController,
                      config: const InfiniteCanvasConfig(
                        showGrid: false,
                        gridType: GridType.none,
                        backgroundColor: Colors.white,
                        imageContentMinScale: 0.25,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          // The first frame reports the viewport size; the second paints the
          // now-visible element segment.
          await tester.pump();
          await tester.pump();

          expect(
            (canvasController.elementById('image-lod') as ImageElement).image,
            same(sourceImage),
          );
          expect(
            (await _pixelColor(tester, boundaryKey, 10, 10)).toARGB32(),
            const Color(0xFFE5E7EB).toARGB32(),
          );

          viewController.zoomTo(0.5, focalPoint: Offset.zero);
          await tester.pump();

          expect(
            (await _pixelColor(tester, boundaryKey, 10, 10)).toARGB32(),
            const Color(0xFFFF0000).toARGB32(),
          );
          expect(
            (canvasController.elementById('image-lod') as ImageElement).image,
            same(sourceImage),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          viewController.dispose();
          canvasController.dispose();
          sourceImage.dispose();
        }
      },
    );
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
      const element = ImageElement(id: 'i1', rect: Rect.fromLTWH(0, 0, 10, 10));
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

Future<ui.Image> _solidImage(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

Future<Color> _pixelColor(
  WidgetTester tester,
  GlobalKey boundaryKey,
  int x,
  int y,
) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final rendered = await boundary.toImage();
    try {
      final data = await rendered.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final offset = (y * rendered.width + x) * 4;
      return Color.fromARGB(
        data!.getUint8(offset + 3),
        data.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
      );
    } finally {
      rendered.dispose();
    }
  }))!;
}

String _base64(List<int> bytes) => base64.encode(bytes);

class _FakeImageLoader extends ImageLoader {
  final _DisposableFakeImage fakeImage = _DisposableFakeImage();

  int loadCalls = 0;

  @override
  bool supports(ImageSource source) =>
      source.assetId != null || source.url != null;

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

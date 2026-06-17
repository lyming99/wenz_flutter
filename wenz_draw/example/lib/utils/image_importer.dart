import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

// This file is the *intake* path: the user picks a local image, we decode it
// (downsampling very large photos) and store the bytes as base64 inside the
// ImageElement. The SDK's CanvasImageResolver then keeps the in-memory
// ui.Image in sync after save/load round-trips via the base64 built-in loader.
//
// To let ImageElements reference images *without* inlining base64 — e.g. by
// remote URL or an OSS key — implement an ImageLoader and register it on the
// controller:
//
//   controller.imageLoaders.register(MyOssImageLoader());
//
// Then create the element with that source:
//
//   ImageElement(id: ..., rect: ..., url: 'https://cdn.example.com/x.png');
//
// The resolver will fetch + decode it on demand; the element's JSON only
// stores the URL, keeping documents small.

const int maxImportedImageBytes = 24 * 1024 * 1024;
const int maxDecodedImageSide = 2048;
const double maxInitialImageWorldSide = 460;
const double minInitialImageWorldSide = 96;

const XTypeGroup _imageTypeGroup = XTypeGroup(
  label: 'Images',
  extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
  mimeTypes: <String>[
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
    'image/bmp',
  ],
);

class ImportedCanvasImage {
  const ImportedCanvasImage({
    required this.name,
    required this.image,
    required this.imageData,
    required this.sourceSize,
    required this.decodedSize,
    required this.byteLength,
  });

  final String name;
  final ui.Image image;
  final String imageData;
  final Size sourceSize;
  final Size decodedSize;
  final int byteLength;

  bool get wasDownsampled => decodedSize != sourceSize;
}

Future<ImportedCanvasImage?> pickCanvasImageFile() async {
  final file = await openFile(acceptedTypeGroups: const [_imageTypeGroup]);
  if (file == null) {
    return null;
  }

  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw const FormatException('Selected image is empty.');
  }
  if (bytes.lengthInBytes > maxImportedImageBytes) {
    final limitMb = (maxImportedImageBytes / (1024 * 1024)).round();
    throw FormatException('Image is larger than ${limitMb}MB.');
  }

  final decoded = await _decodeOptimizedImage(bytes);
  return ImportedCanvasImage(
    name: file.name,
    image: decoded.image,
    imageData: base64Encode(bytes),
    sourceSize: decoded.sourceSize,
    decodedSize: decoded.decodedSize,
    byteLength: bytes.lengthInBytes,
  );
}

Rect initialImageRectForViewport(Size sourceSize, Rect visibleWorldRect) {
  final aspect = sourceSize.width <= 0 || sourceSize.height <= 0
      ? 1.0
      : sourceSize.width / sourceSize.height;
  final maxWorldWidth = math.min(
    maxInitialImageWorldSide,
    visibleWorldRect.width * 0.72,
  );
  final maxWorldHeight = math.min(
    maxInitialImageWorldSide,
    visibleWorldRect.height * 0.72,
  );
  final widthFromHeight = maxWorldHeight * aspect;
  final heightFromWidth = maxWorldWidth / aspect;
  final size = widthFromHeight <= maxWorldWidth
      ? Size(widthFromHeight, maxWorldHeight)
      : Size(maxWorldWidth, heightFromWidth);
  final safeWidth = size.width.clamp(
    minInitialImageWorldSide,
    maxInitialImageWorldSide,
  );
  final safeHeight = size.height.clamp(
    minInitialImageWorldSide / aspect.clamp(0.25, 4.0),
    maxInitialImageWorldSide,
  );
  return Rect.fromCenter(
    center: visibleWorldRect.center,
    width: safeWidth.toDouble(),
    height: safeHeight.toDouble(),
  );
}

Future<_DecodedImage> _decodeOptimizedImage(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final sourceWidth = descriptor.width;
    final sourceHeight = descriptor.height;
    final longestSide = math.max(sourceWidth, sourceHeight);
    final decodeScale = longestSide > maxDecodedImageSide
        ? maxDecodedImageSide / longestSide
        : 1.0;
    final targetWidth = math.max(1, (sourceWidth * decodeScale).round());
    final targetHeight = math.max(1, (sourceHeight * decodeScale).round());
    codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    return _DecodedImage(
      image: frame.image,
      sourceSize: Size(sourceWidth.toDouble(), sourceHeight.toDouble()),
      decodedSize: Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      ),
    );
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

class _DecodedImage {
  const _DecodedImage({
    required this.image,
    required this.sourceSize,
    required this.decodedSize,
  });

  final ui.Image image;
  final Size sourceSize;
  final Size decodedSize;
}

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../canvas/image_loader.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

@immutable
class ImageElement extends CanvasElement {
  const ImageElement({
    required this.id,
    required this.rect,
    this.image,
    this.imageData,
    this.url,
    this.filePath,
    this.fit = BoxFit.contain,
    this.rotation = 0,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
    this.groupId,
  });

  static const elementType = 'image';

  @override
  final String id;
  final Rect rect;
  final ui.Image? image;

  /// Base64-encoded image data. When [image] is null but
  /// [imageData] is present, the image can be decoded at load time.
  final String? imageData;

  /// Remote HTTP(S) URL the image is fetched from. Mutually exclusive with
  /// [imageData] and [filePath] as the decode source.
  final String? url;

  /// Absolute path to a file on the local filesystem. Requires a host-supplied
  /// [ImageLoader] (the SDK ships no file loader, since `dart:io` is absent on
  /// the web).
  final String? filePath;
  final BoxFit fit;
  @override
  final double rotation;

  @override
  final String layerId;
  @override
  final bool visible;
  @override
  final double opacity;
  @override
  final int zIndex;

  @override
  final String? groupId;

  @override
  String get type => elementType;

  @override
  Rect get bounds => rotation != 0 ? rotatedRectBounds(rect, rotation) : rect;

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    final localPoint = rotation != 0
        ? inverseRotatePoint(worldPoint, rotation, rect.center)
        : worldPoint;
    return rect.inflate(tolerance).contains(localPoint);
  }

  @override
  ImageElement copyWith({
    String? id,
    Rect? rect,
    ui.Image? image,
    Object? imageData = _unset,
    Object? url = _unset,
    Object? filePath = _unset,
    BoxFit? fit,
    double? rotation,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    Object? groupId = _unset,
  }) {
    return ImageElement(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      image: image ?? this.image,
      imageData: identical(imageData, _unset)
          ? this.imageData
          : imageData as String?,
      url: identical(url, _unset) ? this.url : url as String?,
      filePath: identical(filePath, _unset)
          ? this.filePath
          : filePath as String?,
      fit: fit ?? this.fit,
      rotation: rotation ?? this.rotation,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  ImageElement translate(Offset delta) {
    return copyWith(rect: rect.shift(delta));
  }

  @override
  ImageElement scaleElement(double factor, {Offset? pivot}) {
    final origin = pivot ?? rect.center;
    return copyWith(
      rect: Rect.fromPoints(
        scalePoint(rect.topLeft, factor, origin),
        scalePoint(rect.bottomRight, factor, origin),
      ),
    );
  }

  @override
  ImageElement rotateElement(double radians, {Offset? pivot}) {
    final origin = pivot ?? rect.center;
    final nextCenter = rotatePoint(rect.center, radians, origin);
    return copyWith(
      rect: Rect.fromCenter(
        center: nextCenter,
        width: rect.width,
        height: rect.height,
      ),
      rotation: rotation + radians,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'layerId': layerId,
      'visible': visible,
      'opacity': opacity,
      'zIndex': zIndex,
      'groupId': groupId,
      'rect': {
        'left': rect.left,
        'top': rect.top,
        'right': rect.right,
        'bottom': rect.bottom,
      },
      'fit': fit.name,
      if (rotation != 0) 'rotation': rotation,
      if (imageData != null) 'imageData': imageData,
      if (url != null) 'url': url,
      if (filePath != null) 'filePath': filePath,
    };
  }

  /// Builds the [ImageSource] this element resolves through when its in-memory
  /// [image] is null (e.g. after deserialization). [imageData] takes priority
  /// over [url], which takes priority over [filePath]. Returns an empty source
  /// when none are set, in which case no loader will match.
  ImageSource toImageSource() {
    if (imageData != null) {
      return ImageSource(base64: imageData);
    }
    if (url != null) {
      return ImageSource(url: url);
    }
    if (filePath != null) {
      return ImageSource(filePath: filePath);
    }
    return const ImageSource();
  }

  static const _unset = Object();

  /// Encodes a [ui.Image] to a base64 PNG string suitable for serialization.
  static Future<String> encodeImageToBase64(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode image to PNG');
    }
    return base64Encode(byteData.buffer.asUint8List());
  }

  /// Decodes a base64 PNG string into a [ui.Image].
  static Future<ui.Image> decodeBase64Image(String base64Data) async {
    final bytes = Uint8List.fromList(base64Decode(base64Data));
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class ImageElementRenderer extends ElementRenderer<ImageElement> {
  const ImageElementRenderer();

  @override
  void render(Canvas canvas, ImageElement element) {
    if (!element.visible) {
      return;
    }

    canvas.save();
    if (element.rotation != 0) {
      canvas.translate(element.rect.center.dx, element.rect.center.dy);
      canvas.rotate(element.rotation);
      canvas.translate(-element.rect.center.dx, -element.rect.center.dy);
    }

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: element.opacity)
      ..filterQuality = FilterQuality.low;
    final image = element.image;
    if (image == null) {
      canvas.drawRect(
        element.rect,
        Paint()
          ..color = const Color(0xFFE5E7EB).withValues(alpha: element.opacity),
      );
      canvas.drawRect(
        element.rect,
        Paint()
          ..color = const Color(0xFF64748B).withValues(alpha: element.opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.restore();
      return;
    }

    final fullSource = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final fitted = applyBoxFit(element.fit, fullSource.size, element.rect.size);
    final source = Alignment.center.inscribe(fitted.source, fullSource);
    final destination = Alignment.center.inscribe(
      fitted.destination,
      element.rect,
    );
    canvas.drawImageRect(image, source, destination, paint);
    canvas.restore();
  }

  @override
  bool hitTest(ImageElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}

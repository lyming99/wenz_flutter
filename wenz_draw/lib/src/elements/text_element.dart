import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

@immutable
class TextElement extends CanvasElement {
  TextElement({
    required this.id,
    required this.position,
    required this.text,
    this.style = const TextStyle(
      color: Colors.black,
      fontSize: 24,
      height: 1.2,
    ),
    this.maxWidth,
    this.boxSize,
    this.textAlign = TextAlign.left,
    this.rotation = 0,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
    this.groupId,
  });

  static const elementType = 'text';

  @override
  final String id;
  final Offset position;
  final String text;
  final TextStyle style;
  final double? maxWidth;
  final Size? boxSize;
  final TextAlign textAlign;
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

  late final Size _laidOutSize = _layoutSize();

  @override
  String get type => elementType;

  /// The width used to lay out and wrap the text.
  ///
  /// [boxSize] is the rendered boundary and can shrink to fit short content;
  /// [maxWidth] remains the wrapping limit so subsequent input can grow until
  /// it reaches the user-selected width.
  double? get layoutMaxWidth => maxWidth ?? boxSize?.width;

  /// The dimensions reported by the same [TextPainter] used for rendering.
  Size get renderedSize => _laidOutSize;

  /// Whether this element's persisted box is already content-sized.
  ///
  /// A manually resized text box intentionally remains fixed even if its
  /// content changes. A small tolerance keeps this stable after JSON
  /// round-trips and platform text-layout rounding.
  bool get hasContentSizedBox {
    final size = boxSize;
    return size != null &&
        (size.width - _laidOutSize.width).abs() <= 0.01 &&
        (size.height - _laidOutSize.height).abs() <= 0.01;
  }

  /// Returns an element whose persisted boundary matches its rendered text.
  /// The wrapping limit is deliberately preserved in [maxWidth].
  TextElement fitToRenderedText() => copyWith(boxSize: renderedSize);

  /// The unrotated local rect of this text element.
  Rect get localBounds {
    final size = boxSize ?? _laidOutSize;
    final fallbackHeight = style.fontSize ?? 24;
    return position &
        Size(math.max(size.width, 1), math.max(size.height, fallbackHeight));
  }

  @override
  Rect get bounds {
    final rawBounds = localBounds;
    return rotation != 0
        ? rotatedRectBounds(rawBounds, rotation)
        : rawBounds;
  }

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    final size = boxSize ?? _laidOutSize;
    final fallbackHeight = style.fontSize ?? 24;
    final rawBounds = position &
        Size(math.max(size.width, 1), math.max(size.height, fallbackHeight));
    final localPoint = rotation != 0
        ? inverseRotatePoint(worldPoint, rotation, rawBounds.center)
        : worldPoint;
    return rawBounds.inflate(tolerance).contains(localPoint);
  }

  TextPainter createTextPainter({Color? color, double opacity = 1}) {
    final resolvedColor = color ?? style.color ?? Colors.black;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          color: resolvedColor.withValues(alpha: opacity.clamp(0.0, 1.0)),
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );
    final width = layoutMaxWidth;
    painter.layout(maxWidth: width ?? double.infinity);
    return painter;
  }

  @override
  TextElement copyWith({
    String? id,
    Offset? position,
    String? text,
    TextStyle? style,
    Object? maxWidth = _unset,
    Object? boxSize = _unset,
    TextAlign? textAlign,
    double? rotation,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    Object? groupId = _unset,
  }) {
    return TextElement(
      id: id ?? this.id,
      position: position ?? this.position,
      text: text ?? this.text,
      style: style ?? this.style,
      maxWidth: identical(maxWidth, _unset)
          ? this.maxWidth
          : maxWidth as double?,
      boxSize: identical(boxSize, _unset) ? this.boxSize : boxSize as Size?,
      textAlign: textAlign ?? this.textAlign,
      rotation: rotation ?? this.rotation,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      groupId: identical(groupId, _unset)
          ? this.groupId
          : groupId as String?,
    );
  }

  @override
  TextElement translate(Offset delta) {
    return copyWith(position: position + delta);
  }

  @override
  TextElement scaleElement(double factor, {Offset? pivot}) {
    final origin = pivot ?? bounds.center;
    return copyWith(
      position: scalePoint(position, factor, origin),
      style: style.copyWith(fontSize: (style.fontSize ?? 24) * factor.abs()),
      maxWidth: maxWidth == null ? null : maxWidth! * factor.abs(),
      boxSize: boxSize == null ? null : boxSize! * factor.abs(),
    );
  }

  @override
  TextElement rotateElement(double radians, {Offset? pivot}) {
    final lb = localBounds;
    final oldCenter = lb.center;
    final origin = pivot ?? oldCenter;
    final nextCenter = rotatePoint(oldCenter, radians, origin);
    return copyWith(
      position: nextCenter - Offset(lb.width / 2, lb.height / 2),
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
      'position': {'x': position.dx, 'y': position.dy},
      'text': text,
      if (maxWidth != null) 'maxWidth': maxWidth,
      if (boxSize != null) 'boxSize': _sizeToJson(boxSize!),
      'textAlign': textAlign.name,
      if (rotation != 0) 'rotation': rotation,
      'style': {
        'color': (style.color ?? Colors.black).toARGB32(),
        'fontSize': style.fontSize ?? 24,
        'fontWeight': _fontWeightToJson(style.fontWeight),
        'height': style.height ?? 1.2,
        if (style.fontFamily != null) 'fontFamily': style.fontFamily,
      },
    };
  }

  Size _layoutSize() {
    if (text.isEmpty) {
      final height = style.fontSize ?? 24;
      return Size(layoutMaxWidth ?? 1, height);
    }
    return createTextPainter(opacity: 1).size;
  }

  static const _unset = Object();

  static Map<String, double> _sizeToJson(Size size) {
    return {'width': size.width, 'height': size.height};
  }

  static int _fontWeightToJson(FontWeight? fontWeight) {
    return fontWeight?.value ?? FontWeight.normal.value;
  }
}

class TextElementRenderer extends ElementRenderer<TextElement> {
  const TextElementRenderer();

  @override
  void render(Canvas canvas, TextElement element) {
    if (!element.visible || element.text.isEmpty) {
      return;
    }
    final painter = element.createTextPainter(
      color: element.style.color ?? Colors.black,
      opacity: element.opacity,
    );
    final boxSize = element.boxSize;
    final center = boxSize != null
        ? element.position + boxSize.center(Offset.zero)
        : element.position + Offset(painter.width / 2, painter.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(element.rotation);
    canvas.translate(-center.dx, -center.dy);
    if (boxSize != null) {
      canvas.clipRect(element.position & boxSize);
    }
    painter.paint(canvas, element.position);
    canvas.restore();
  }

  @override
  bool hitTest(TextElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}

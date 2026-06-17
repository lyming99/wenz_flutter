import 'package:flutter/material.dart';

import 'canvas_element.dart';

/// A placeholder for an element whose `type` the loader did not recognize.
///
/// Instead of silently dropping or coercing unknown elements (the old behavior
/// turned them into zero-length lines), the original JSON is preserved verbatim
/// in [rawJson]. When the document is serialized again, that JSON is written
/// back unchanged, so a round-trip through an older app never loses data.
///
/// Bounds and hit-testing fall back to a `rect` field if present, otherwise the
/// element occupies no space and is not selectable — but it is still rendered
/// as a faint placeholder box by [UnknownElementRenderer] so the user can see
/// *something* is there.
@immutable
class UnknownElement extends CanvasElement {
  const UnknownElement({
    required this.id,
    required this.rawJson,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
    this.groupId,
  });

  @override
  final String id;

  /// The complete, original JSON map (including `type`, `id`, etc.). Written
  /// back verbatim by [toJson].
  final Map<String, dynamic> rawJson;

  @override
  String get type => rawJson['type'] as String? ?? 'unknown';

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

  /// Attempts to read a `rect: {left,top,right,bottom}` from [rawJson]. Returns
  /// [Rect.zero] when absent, so unknown elements without geometry are inert.
  @override
  Rect get bounds {
    final rect = rawJson['rect'];
    if (rect is Map<String, dynamic>) {
      return Rect.fromLTRB(
        (rect['left'] as num?)?.toDouble() ?? 0,
        (rect['top'] as num?)?.toDouble() ?? 0,
        (rect['right'] as num?)?.toDouble() ?? 0,
        (rect['bottom'] as num?)?.toDouble() ?? 0,
      );
    }
    return Rect.zero;
  }

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    if (bounds == Rect.zero) return false;
    return bounds.inflate(tolerance).contains(worldPoint);
  }

  @override
  Map<String, dynamic> toJson() {
    // Write back exactly what we received, overlaying any common fields the
    // loader may have normalized (id/layerId/visible/etc.) so edits are not
    // lost while the rest stays untouched.
    return <String, dynamic>{
      ...rawJson,
      'id': id,
      'type': type,
      'layerId': layerId,
      'visible': visible,
      'opacity': opacity,
      'zIndex': zIndex,
      if (groupId != null) 'groupId': groupId,
    };
  }

  @override
  UnknownElement copyWith({
    String? id,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    String? groupId,
  }) {
    return UnknownElement(
      id: id ?? this.id,
      rawJson: rawJson,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      groupId: groupId ?? this.groupId,
    );
  }

  @override
  UnknownElement translate(Offset delta) {
    return copyWith();
  }

  @override
  UnknownElement scaleElement(double factor, {Offset? pivot}) {
    return copyWith();
  }
}

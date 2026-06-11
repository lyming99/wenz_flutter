import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class CanvasLayer {
  const CanvasLayer({
    required this.id,
    required this.name,
    this.isVisible = true,
    this.isLocked = false,
    this.opacity = 1,
    this.blendMode = BlendMode.srcOver,
  });

  static const defaultLayerId = 'default';

  final String id;
  final String name;
  final bool isVisible;
  final bool isLocked;
  final double opacity;
  final BlendMode blendMode;

  CanvasLayer copyWith({
    String? id,
    String? name,
    bool? isVisible,
    bool? isLocked,
    double? opacity,
    BlendMode? blendMode,
  }) {
    return CanvasLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'visible': isVisible,
      'locked': isLocked,
      'opacity': opacity,
      'blendMode': blendMode.name,
    };
  }
}

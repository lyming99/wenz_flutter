import 'package:flutter/foundation.dart';

/// 画布图层（不可变）。
class CanvasLayer {
  /// 图层唯一标识
  final String id;

  /// 图层名称
  final String name;

  /// 是否可见
  final bool isVisible;

  /// 是否锁定（锁定后不可编辑）
  final bool isLocked;

  /// 透明度 0.0~1.0
  final double opacity;

  /// 该图层包含的元素 ID 列表（有序）
  final List<String> elementIds;

  const CanvasLayer({
    required this.id,
    this.name = '未命名图层',
    this.isVisible = true,
    this.isLocked = false,
    this.opacity = 1.0,
    this.elementIds = const [],
  });

  CanvasLayer copyWith({
    String? id,
    String? name,
    bool? isVisible,
    bool? isLocked,
    double? opacity,
    List<String>? elementIds,
  }) {
    return CanvasLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      opacity: opacity ?? this.opacity,
      elementIds: elementIds ?? this.elementIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isVisible': isVisible,
        'isLocked': isLocked,
        'opacity': opacity,
        'elementIds': elementIds,
      };

  factory CanvasLayer.fromJson(Map<String, dynamic> json) => CanvasLayer(
        id: json['id'] as String,
        name: json['name'] as String? ?? '未命名图层',
        isVisible: json['isVisible'] as bool? ?? true,
        isLocked: json['isLocked'] as bool? ?? false,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        elementIds: (json['elementIds'] as List?)?.cast<String>() ?? [],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasLayer &&
          id == other.id &&
          name == other.name &&
          isVisible == other.isVisible &&
          isLocked == other.isLocked &&
          opacity == other.opacity;

  @override
  int get hashCode => Object.hash(id, name, isVisible, isLocked, opacity);
}

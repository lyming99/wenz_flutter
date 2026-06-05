import 'dart:ui' show Color;

import '../canvas/paint_style.dart';

/// 画笔配置（不可变）。
///
/// 描述当前画笔的状态：颜色、宽度、透明度等。
/// 由 ToolManager 持有，工具可通过 controller 访问和修改。
class BrushSettings {
  /// 画笔颜色
  final Color color;

  /// 画笔宽度（世界坐标系）
  final double width;

  /// 透明度 0.0~1.0
  final double opacity;

  const BrushSettings({
    this.color = const Color(0xFF000000),
    this.width = 2.0,
    this.opacity = 1.0,
  });

  /// 转换为 PaintStyle（用于创建元素）
  PaintStyle toPaintStyle() => PaintStyle(
        color: color.value,
        strokeWidth: width,
        opacity: opacity,
      );

  BrushSettings copyWith({
    Color? color,
    double? width,
    double? opacity,
  }) {
    return BrushSettings(
      color: color ?? this.color,
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushSettings &&
          color == other.color &&
          width == other.width &&
          opacity == other.opacity;

  @override
  int get hashCode => Object.hash(color, width, opacity);

  @override
  String toString() => 'BrushSettings(color: $color, width: $width, opacity: $opacity)';
}

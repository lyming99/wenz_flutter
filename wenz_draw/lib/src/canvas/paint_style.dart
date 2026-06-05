import 'dart:ui' show Offset, Rect;

/// 画笔样式模型（不可变）。
///
/// 描述绘制元素的外观：颜色、线宽、线帽、填充等。
class PaintStyle {
  /// 描边颜色
  final int color;

  /// 描边宽度（世界坐标系）
  final double strokeWidth;

  /// 线帽样式（0=butt, 1=round, 2=square）
  final int strokeCap;

  /// 线连接样式（0=miter, 1=round, 2=bevel）
  final int strokeJoin;

  /// 是否启用填充
  final bool fillEnabled;

  /// 填充颜色
  final int fillColor;

  /// 透明度 0.0~1.0
  final double opacity;

  const PaintStyle({
    this.color = 0xFF000000,
    this.strokeWidth = 2.0,
    this.strokeCap = 1, // round
    this.strokeJoin = 1, // round
    this.fillEnabled = false,
    this.fillColor = 0x00000000,
    this.opacity = 1.0,
  });

  PaintStyle copyWith({
    int? color,
    double? strokeWidth,
    int? strokeCap,
    int? strokeJoin,
    bool? fillEnabled,
    int? fillColor,
    double? opacity,
  }) {
    return PaintStyle(
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeCap: strokeCap ?? this.strokeCap,
      strokeJoin: strokeJoin ?? this.strokeJoin,
      fillEnabled: fillEnabled ?? this.fillEnabled,
      fillColor: fillColor ?? this.fillColor,
      opacity: opacity ?? this.opacity,
    );
  }

  Map<String, dynamic> toJson() => {
        'color': color,
        'strokeWidth': strokeWidth,
        'strokeCap': strokeCap,
        'strokeJoin': strokeJoin,
        'fillEnabled': fillEnabled,
        'fillColor': fillColor,
        'opacity': opacity,
      };

  factory PaintStyle.fromJson(Map<String, dynamic> json) => PaintStyle(
        color: json['color'] as int? ?? 0xFF000000,
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
        strokeCap: json['strokeCap'] as int? ?? 1,
        strokeJoin: json['strokeJoin'] as int? ?? 1,
        fillEnabled: json['fillEnabled'] as bool? ?? false,
        fillColor: json['fillColor'] as int? ?? 0x00000000,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaintStyle &&
          color == other.color &&
          strokeWidth == other.strokeWidth &&
          strokeCap == other.strokeCap &&
          strokeJoin == other.strokeJoin &&
          fillEnabled == other.fillEnabled &&
          fillColor == other.fillColor &&
          opacity == other.opacity;

  @override
  int get hashCode => Object.hash(
        color,
        strokeWidth,
        strokeCap,
        strokeJoin,
        fillEnabled,
        fillColor,
        opacity,
      );
}

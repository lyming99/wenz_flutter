import 'dart:ui' show Offset;

/// 路径点（支持压感）。
///
/// 用于 [PathElement] 的点序列，每个点包含位置、压感和时间戳。
class PathPoint {
  /// 世界坐标位置
  final Offset position;

  /// 压感值 0.0~1.0，默认 0.5
  final double pressure;

  /// 时间戳（毫秒），用于速度计算
  final double timestamp;

  const PathPoint({
    required this.position,
    this.pressure = 0.5,
    this.timestamp = 0,
  });

  PathPoint copyWith({
    Offset? position,
    double? pressure,
    double? timestamp,
  }) {
    return PathPoint(
      position: position ?? this.position,
      pressure: pressure ?? this.pressure,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'x': position.dx,
        'y': position.dy,
        'pressure': pressure,
        'timestamp': timestamp,
      };

  factory PathPoint.fromJson(Map<String, dynamic> json) => PathPoint(
        position: Offset(
          (json['x'] as num).toDouble(),
          (json['y'] as num).toDouble(),
        ),
        pressure: (json['pressure'] as num?)?.toDouble() ?? 0.5,
        timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PathPoint &&
          position == other.position &&
          pressure == other.pressure &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(position, pressure, timestamp);

  @override
  String toString() =>
      'PathPoint(position: $position, pressure: $pressure, timestamp: $timestamp)';
}

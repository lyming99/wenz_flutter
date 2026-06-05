import '../infinite_canvas/canvas_transform.dart';

/// 画布全局不可变状态。
///
/// 作为唯一状态源，所有修改通过 copyWith 返回新实例。
class CanvasState {
  /// 当前视图变换
  final CanvasTransform transform;

  /// 是否正在拖拽中
  final bool isDragging;

  /// 是否正在缩放中
  final bool isScaling;

  /// 脏标记：是否有未渲染的变更
  final bool isDirty;

  const CanvasState({
    this.transform = const CanvasTransform(),
    this.isDragging = false,
    this.isScaling = false,
    this.isDirty = false,
  });

  /// 初始默认状态
  static const initial = CanvasState();

  /// 复制并修改部分字段。
  CanvasState copyWith({
    CanvasTransform? transform,
    bool? isDragging,
    bool? isScaling,
    bool? isDirty,
  }) {
    return CanvasState(
      transform: transform ?? this.transform,
      isDragging: isDragging ?? this.isDragging,
      isScaling: isScaling ?? this.isScaling,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CanvasState &&
        other.transform == transform &&
        other.isDragging == isDragging &&
        other.isScaling == isScaling &&
        other.isDirty == isDirty;
  }

  @override
  int get hashCode => Object.hash(transform, isDragging, isScaling, isDirty);

  @override
  String toString() =>
      'CanvasState(transform: $transform, isDragging: $isDragging, '
      'isScaling: $isScaling, isDirty: $isDirty)';
}

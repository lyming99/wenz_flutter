import 'dart:ui' show Canvas, Offset, Size;

import '../elements/canvas_element.dart';
import '../infinite_canvas/canvas_transform.dart';
import '../infinite_canvas/canvas_event.dart';

/// 工具处理结果（sealed class）。
sealed class ToolResult {
  const ToolResult();
}

/// 无操作
class ToolResultNone extends ToolResult {
  const ToolResultNone();
}

/// 产生新元素（松手后提交）
class ToolResultElement extends ToolResult {
  final CanvasElement element;
  const ToolResultElement(this.element);
}

/// 实时预览（拖拽中的临时形状）
class ToolResultPreview extends ToolResult {
  final CanvasElement preview;
  const ToolResultPreview(this.preview);
}

/// 事件已消费（不再传递）
class ToolResultConsumed extends ToolResult {
  const ToolResultConsumed();
}

/// 选择操作
class ToolResultSelect extends ToolResult {
  final Set<String> selectedIds;
  const ToolResultSelect(this.selectedIds);
}

/// 绘制工具抽象接口（策略模式）。
///
/// 每种绘图工具实现此接口，通过 [handleEvent] 处理指针事件。
/// 工具通过 [ToolManager] 注册和切换。
abstract class CanvasTool {
  /// 工具唯一标识
  String get id;

  /// 工具名称（用于 UI 显示）
  String get name;

  /// 工具图标名称（Material Icons 名称）
  String get iconName;

  /// 工具激活时调用
  void onActivate() {}

  /// 工具停用时调用
  void onDeactivate() {}

  /// 处理画布事件。
  ///
  /// 返回 [ToolResult] 告知框架当前操作结果。
  ToolResult handleEvent(CanvasEvent event);

  /// 绘制实时预览（拖拽中的临时形状）。
  ///
  /// [canvas] 已应用视图变换的画布。
  void paintPreview(Canvas canvas, Size size, CanvasTransform transform) {}
}

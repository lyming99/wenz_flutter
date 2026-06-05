import 'package:flutter/foundation.dart';

import 'brush_settings.dart';
import 'canvas_tool.dart';
import '../infinite_canvas/canvas_event.dart';

/// 工具管理器。
///
/// 管理所有注册的工具，维护当前活跃工具和画笔配置。
class ToolManager extends ChangeNotifier {
  final Map<String, CanvasTool> _tools = {};
  CanvasTool? _activeTool;
  BrushSettings _brushSettings = const BrushSettings();

  /// 注册工具。
  void registerTool(CanvasTool tool) {
    _tools[tool.id] = tool;
  }

  /// 批量注册工具。
  void registerTools(List<CanvasTool> tools) {
    for (final tool in tools) {
      _tools[tool.id] = tool;
    }
  }

  /// 设置当前活跃工具。
  void setActiveTool(String toolId) {
    final tool = _tools[toolId];
    if (tool == null) return;

    // 停用旧工具
    _activeTool?.onDeactivate();

    _activeTool = tool;
    tool.onActivate();
    notifyListeners();
  }

  /// 获取当前活跃工具。
  CanvasTool? get activeTool => _activeTool;

  /// 获取所有已注册工具。
  List<CanvasTool> get tools => List.unmodifiable(_tools.values);

  /// 获取所有工具 ID。
  List<String> get toolIds => _tools.keys.toList();

  /// 将事件分发到当前活跃工具。
  ToolResult dispatch(CanvasEvent event) {
    if (_activeTool == null) return const ToolResultNone();
    return _activeTool!.handleEvent(event);
  }

  /// 当前画笔配置。
  BrushSettings get brushSettings => _brushSettings;

  /// 更新画笔配置。
  void updateBrushSettings(BrushSettings settings) {
    _brushSettings = settings;
    notifyListeners();
  }

  /// 取消注册工具。
  void unregisterTool(String toolId) {
    if (_activeTool?.id == toolId) {
      _activeTool?.onDeactivate();
      _activeTool = null;
    }
    _tools.remove(toolId);
    notifyListeners();
  }

  /// 清除所有工具。
  void clear() {
    _activeTool?.onDeactivate();
    _activeTool = null;
    _tools.clear();
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';

import '../canvas/canvas_controller.dart';
import '../infinite_canvas/canvas_event.dart';
import 'brush_settings.dart';
import 'canvas_tool.dart';

class ToolManager extends ChangeNotifier {
  final Map<String, CanvasTool> _tools = {};
  CanvasTool? _activeTool;
  BrushSettings _brushSettings = const BrushSettings();

  void registerTool(CanvasTool tool) {
    _tools[tool.id] = tool;
    _activeTool ??= tool;
    notifyListeners();
  }

  void setActiveTool(String toolId, CanvasController controller) {
    final next = _tools[toolId];
    if (next == null || identical(next, _activeTool)) {
      return;
    }
    _activeTool?.onDeactivate(controller);
    _activeTool = next;
    _activeTool?.onActivate(controller);
    notifyListeners();
  }

  CanvasTool? get activeTool => _activeTool;

  List<CanvasTool> get tools => List<CanvasTool>.unmodifiable(_tools.values);

  ToolResult dispatch(CanvasEvent event, CanvasController controller) {
    return _activeTool?.handleEvent(event, controller) ??
        const ToolResultNone();
  }

  void cancelActiveTool(CanvasController controller) {
    _activeTool?.cancel(controller);
  }

  BrushSettings get brushSettings => _brushSettings;

  void updateBrushSettings(BrushSettings settings) {
    _brushSettings = settings;
    notifyListeners();
  }
}

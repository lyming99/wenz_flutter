import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import '../elements/canvas_element.dart';
import '../elements/path_element.dart';
import '../elements/line_element.dart';
import '../elements/rect_element.dart';
import '../elements/ellipse_element.dart';
import '../elements/arrow_element.dart';
import '../elements/text_element.dart';
import '../history/commands/add_element_command.dart';
import '../history/commands/remove_element_command.dart';
import '../history/history_manager.dart';
import '../tools/brush_settings.dart';
import '../tools/canvas_tool.dart';
import '../tools/tool_manager.dart';
import 'element_manager.dart';
import 'selection_manager.dart';

/// 核心画布控制器。
///
/// 协调 ElementManager、SelectionManager、ToolManager、HistoryManager 等子模块，
/// 提供元素 CRUD、选择、工具管理、撤销/重做、序列化等核心 API。
class CanvasController extends ChangeNotifier {
  final ElementManager _elementManager;
  final SelectionManager _selectionManager;
  final ToolManager _toolManager;
  final HistoryManager _historyManager;

  CanvasController({
    ElementManager? elementManager,
    SelectionManager? selectionManager,
    ToolManager? toolManager,
    HistoryManager? historyManager,
  })  : _elementManager = elementManager ?? ElementManager(),
        _selectionManager = selectionManager ?? SelectionManager(),
        _toolManager = toolManager ?? ToolManager(),
        _historyManager = historyManager ?? HistoryManager();

  // ─── 子管理器访问 ─────────────────────────────────────────

  ElementManager get elementManager => _elementManager;
  SelectionManager get selectionManager => _selectionManager;
  ToolManager get toolManager => _toolManager;
  HistoryManager get historyManager => _historyManager;

  // ─── 元素 CRUD ─────────────────────────────────────────────

  /// 添加元素（通过历史记录）。
  void addElement(CanvasElement element) {
    _historyManager.execute(AddElementCommand(_elementManager, element));
    notifyListeners();
  }

  /// 移除元素（通过历史记录）。
  void removeElement(String id) {
    final element = _elementManager.getElement(id);
    if (element != null) {
      _historyManager
          .execute(RemoveElementCommand(_elementManager, element));
      _selectionManager.removeFromSelection(id);
    }
    notifyListeners();
  }

  /// 更新元素。
  void updateElement(String id, CanvasElement element) {
    _elementManager.updateElement(id, element);
    notifyListeners();
  }

  /// 获取元素。
  CanvasElement? getElement(String id) => _elementManager.getElement(id);

  /// 获取所有元素（按 zIndex 排序）。
  List<CanvasElement> get elements => _elementManager.elements;

  /// 获取视口内可见元素。
  List<CanvasElement> getVisibleElements(Rect visibleRect) {
    return _elementManager.getVisibleElements(visibleRect);
  }

  // ─── 选择 ─────────────────────────────────────────────────

  /// 选中元素。
  void select(String? id, {bool addToSelection = false}) {
    if (id == null) {
      _selectionManager.deselectAll();
    } else {
      _selectionManager.select(id, addToSelection: addToSelection);
    }
    notifyListeners();
  }

  /// 框选。
  void selectInRect(Rect worldRect) {
    _selectionManager.selectInRect(worldRect, elements);
    notifyListeners();
  }

  /// 全选。
  void selectAll() {
    _selectionManager.selectAll(elements);
    notifyListeners();
  }

  /// 取消选择。
  void deselectAll() {
    _selectionManager.deselectAll();
    notifyListeners();
  }

  /// 删除选中元素。
  void deleteSelected() {
    for (final id in _selectionManager.selectedIds.toList()) {
      _elementManager.removeElement(id);
    }
    _selectionManager.clear();
    notifyListeners();
  }

  /// 获取选中的元素。
  List<CanvasElement> get selectedElements =>
      _selectionManager.getSelectedElements(elements);

  /// 是否有选中元素。
  bool get hasSelection => _selectionManager.hasSelection;

  /// 获取选中元素的统一包围盒。
  Rect? get selectionBounds =>
      _selectionManager.getSelectionBounds(elements);

  // ─── 工具管理 ─────────────────────────────────────────────

  /// 设置当前工具。
  void setTool(String toolId) {
    _toolManager.setActiveTool(toolId);
    notifyListeners();
  }

  /// 获取当前工具。
  CanvasTool? get currentTool => _toolManager.activeTool;

  /// 获取所有已注册工具。
  List<CanvasTool> get tools => _toolManager.tools;

  /// 获取/设置画笔配置。
  BrushSettings get brushSettings => _toolManager.brushSettings;

  void updateBrushSettings(BrushSettings settings) {
    _toolManager.updateBrushSettings(settings);
    notifyListeners();
  }

  // ─── 撤销/重做 ─────────────────────────────────────────────

  /// 撤销最近一次操作。
  void undo() {
    _historyManager.undo();
    notifyListeners();
  }

  /// 重做最近一次撤销的操作。
  void redo() {
    _historyManager.redo();
    notifyListeners();
  }

  /// 是否可以撤销。
  bool get canUndo => _historyManager.canUndo;

  /// 是否可以重做。
  bool get canRedo => _historyManager.canRedo;

  // ─── 序列化 ─────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'version': '1.0',
      'elements': _elementManager.elements.map((e) => e.toJson()).toList(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    _elementManager.clear();
    _selectionManager.clear();

    final elementsJson = json['elements'] as List?;
    if (elementsJson != null) {
      for (final elemJson in elementsJson) {
        final element = _deserializeElement(elemJson as Map<String, dynamic>);
        if (element != null) {
          _elementManager.addElement(element);
        }
      }
    }
    notifyListeners();
  }

  static CanvasElement? _deserializeElement(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'path':
        try { return PathElement.fromJson(json); } catch (_) {}
      case 'line':
        try { return LineElement.fromJson(json); } catch (_) {}
      case 'rect':
        try { return RectElement.fromJson(json); } catch (_) {}
      case 'ellipse':
        try { return EllipseElement.fromJson(json); } catch (_) {}
      case 'arrow':
        try { return ArrowElement.fromJson(json); } catch (_) {}
      case 'text':
        try { return TextElement.fromJson(json); } catch (_) {}
    }
    return null;
  }

  // ─── 生命周期 ─────────────────────────────────────────────

  @override
  void dispose() {
    _elementManager.dispose();
    _selectionManager.dispose();
    _toolManager.dispose();
    _historyManager.dispose();
    super.dispose();
  }
}

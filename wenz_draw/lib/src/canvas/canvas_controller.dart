import 'package:flutter/widgets.dart';

import '../elements/canvas_element.dart';
import '../elements/element_registry.dart';
import '../history/commands/add_element_command.dart';
import '../history/commands/batch_command.dart';
import '../history/commands/remove_element_command.dart';
import '../history/commands/update_element_command.dart';
import '../history/canvas_command.dart';
import '../history/history_manager.dart';
import '../infinite_canvas/canvas_event.dart';
import '../layers/auto_layering.dart';
import '../layers/canvas_layer.dart';
import '../layers/layer_manager.dart';
import '../tools/brush_settings.dart';
import '../tools/canvas_tool.dart';
import '../tools/ellipse_tool.dart';
import '../tools/eraser_tool.dart';
import '../tools/highlighter_tool.dart';
import '../tools/line_tool.dart';
import '../tools/pan_tool.dart';
import '../tools/pen_tool.dart';
import '../tools/rect_tool.dart';
import '../tools/select_tool.dart';
import '../tools/text_tool.dart';
import '../tools/arrow_tool.dart';
import '../tools/tool_manager.dart';
import 'canvas_state.dart';
import 'element_manager.dart';

class CanvasController extends ChangeNotifier {
  CanvasController({
    CanvasState initialState = const CanvasState(),
    ToolManager? toolManager,
    HistoryManager? historyManager,
    LayerManager? layerManager,
    this.autoLayeringPolicy = const AutoLayeringPolicy.activeLayer(),
  }) : _state = initialState,
       toolManager = toolManager ?? ToolManager(),
       historyManager = historyManager ?? HistoryManager(),
       layerManager = layerManager ?? LayerManager() {
    ElementRendererRegistry.ensureBuiltInsRegistered();
    _registerBuiltInTools();
    this.historyManager.addListener(notifyListeners);
    this.layerManager.addListener(notifyListeners);
    setTool(PenTool.idValue);
  }

  final ElementManager _elementManager = const ElementManager();
  final AutoLayeringResolver _autoLayeringResolver =
      const AutoLayeringResolver();
  final ToolManager toolManager;
  final HistoryManager historyManager;
  final LayerManager layerManager;
  final AutoLayeringPolicy autoLayeringPolicy;

  CanvasState _state;

  CanvasState get state => _state;
  List<CanvasElement> get elements => _state.elements;
  CanvasElement? get previewElement => _state.previewElement;
  Set<String> get selectedIds => _state.selectedIds;
  Rect? get selectionRect => _state.selectionRect;
  BrushSettings get brushSettings => toolManager.brushSettings;
  CanvasTool? get currentTool => toolManager.activeTool;
  bool get canUndo => historyManager.canUndo;
  bool get canRedo => historyManager.canRedo;
  List<CanvasLayer> get layers => layerManager.layers;
  String get activeLayerId => layerManager.activeLayerId;

  void addElement(
    CanvasElement element, {
    bool record = true,
    bool bringToFront = false,
  }) {
    final prepared = _prepareElementForInsert(
      element,
      bringToFront: bringToFront,
    );
    if (record) {
      historyManager.execute(AddElementCommand(prepared), this);
      return;
    }
    applyElementAdded(prepared);
  }

  void applyElementAdded(CanvasElement element) {
    _state = _state.copyWith(
      elements: _elementManager.add(_state.elements, element),
      previewElement: null,
    );
    notifyListeners();
  }

  void removeElement(String id, {bool record = true}) {
    final element = elementById(id);
    if (element == null) {
      return;
    }
    if (record) {
      historyManager.execute(RemoveElementCommand(element), this);
      return;
    }
    applyElementRemoved(id);
  }

  void applyElementRemoved(String id) {
    _state = _state.copyWith(
      elements: _elementManager.remove(_state.elements, id),
      selectedIds: {..._state.selectedIds}..remove(id),
      previewElement: null,
    );
    notifyListeners();
  }

  void updateElement(String id, CanvasElement element, {bool record = true}) {
    final before = elementById(id);
    if (before == null) {
      return;
    }
    if (record) {
      historyManager.execute(
        UpdateElementCommand(before: before, after: element),
        this,
      );
      return;
    }
    applyElementUpdated(id, element);
  }

  void applyElementUpdated(String id, CanvasElement element) {
    _state = _state.copyWith(
      elements: _elementManager.update(_state.elements, id, element),
    );
    notifyListeners();
  }

  void replaceElements(
    List<CanvasElement> elements, {
    bool clearHistory = true,
  }) {
    _state = _state.copyWith(
      elements: List<CanvasElement>.unmodifiable(elements),
      previewElement: null,
      selectedIds: const <String>{},
      selectionRect: null,
    );
    if (clearHistory) {
      historyManager.clear();
    }
    notifyListeners();
  }

  void setPreviewElement(CanvasElement? element) {
    _state = _state.copyWith(previewElement: element);
    notifyListeners();
  }

  void clearPreview() {
    if (_state.previewElement == null) {
      return;
    }
    _state = _state.copyWith(previewElement: null);
    notifyListeners();
  }

  void setSelectionRect(Rect? rect) {
    _state = _state.copyWith(selectionRect: rect);
    notifyListeners();
  }

  void cancelCurrentInteraction() {
    toolManager.cancelActiveTool(this);
    clearPreview();
  }

  List<CanvasElement> orderedElements({bool visibleOnly = false}) {
    final ordered =
        [
          for (var i = 0; i < _state.elements.length; i++)
            if (!visibleOnly ||
                (_state.elements[i].visible &&
                    isLayerVisible(_state.elements[i].layerId)))
              MapEntry(i, _state.elements[i]),
        ]..sort((a, b) {
          final layerOrder = layerIndexOf(
            a.value.layerId,
          ).compareTo(layerIndexOf(b.value.layerId));
          if (layerOrder != 0) {
            return layerOrder;
          }

          final zOrder = a.value.zIndex.compareTo(b.value.zIndex);
          if (zOrder != 0) {
            return zOrder;
          }
          return a.key.compareTo(b.key);
        });

    return [for (final entry in ordered) entry.value];
  }

  CanvasElement? hitTest(Offset worldPoint, {double tolerance = 5}) {
    return _elementManager.hitTest(
      _state.elements.where((element) => isLayerVisible(element.layerId)),
      worldPoint,
      tolerance: tolerance,
      layerRank: (element) => layerManager.layerIndexOf(element.layerId),
    );
  }

  CanvasElement? elementById(String id) {
    for (final element in _state.elements) {
      if (element.id == id) {
        return element;
      }
    }
    return null;
  }

  void select(String? id, {bool addToSelection = false}) {
    final next = <String>{
      if (addToSelection) ..._state.selectedIds,
      if (id != null) id,
    };
    _state = _state.copyWith(selectedIds: next);
    notifyListeners();
  }

  void setSelection(Set<String> ids) {
    _state = _state.copyWith(selectedIds: Set<String>.unmodifiable(ids));
    notifyListeners();
  }

  void selectInRect(Rect worldRect) {
    setSelection({
      for (final element in elements)
        if (element.visible &&
            isLayerVisible(element.layerId) &&
            element.bounds.overlaps(worldRect))
          element.id,
    });
  }

  void deselectAll() {
    if (_state.selectedIds.isEmpty) {
      return;
    }
    _state = _state.copyWith(selectedIds: const <String>{});
    notifyListeners();
  }

  List<CanvasElement> get selectedElements {
    return [
      for (final element in elements)
        if (_state.selectedIds.contains(element.id)) element,
    ];
  }

  void moveSelected(Offset delta, {bool record = true}) {
    if (delta == Offset.zero || selectedIds.isEmpty) {
      return;
    }

    final commands = [
      for (final element in selectedElements)
        UpdateElementCommand(
          before: element,
          after: element.translate(delta),
          description: 'Move ${element.type}',
        ),
    ];

    if (commands.isEmpty) {
      return;
    }

    if (record) {
      historyManager.execute(
        BatchCommand(commands: commands, description: 'Move selection'),
        this,
      );
      return;
    }

    for (final command in commands) {
      command.execute(this);
    }
  }

  void removeSelected() {
    final commands = [
      for (final element in selectedElements) RemoveElementCommand(element),
    ];
    if (commands.isEmpty) {
      return;
    }
    historyManager.execute(
      BatchCommand(commands: commands, description: 'Remove selection'),
      this,
    );
  }

  void clear({bool record = true}) {
    final commands = [
      for (final element in elements) RemoveElementCommand(element),
    ];
    if (commands.isEmpty) {
      return;
    }
    if (record) {
      historyManager.execute(
        BatchCommand(commands: commands, description: 'Clear canvas'),
        this,
      );
    } else {
      replaceElements(const <CanvasElement>[]);
    }
  }

  void setTool(String toolId) {
    clearPreview();
    toolManager.setActiveTool(toolId, this);
    notifyListeners();
  }

  void updateBrushSettings(BrushSettings settings) {
    toolManager.updateBrushSettings(settings);
    notifyListeners();
  }

  void dispatchCanvasEvent(CanvasEvent event) {
    final result = toolManager.dispatch(event, this);
    _handleToolResult(result);
  }

  void undo() {
    cancelCurrentInteraction();
    historyManager.undo(this);
  }

  void redo() {
    cancelCurrentInteraction();
    historyManager.redo(this);
  }

  void recordCommand(CanvasCommand command) {
    historyManager.record(command);
  }

  void addLayer({String? name}) => layerManager.addLayer(name: name);

  void removeLayer(String id) {
    if (layers.length == 1) {
      return;
    }
    final commands = [
      for (final element in elements)
        if (element.layerId == id) RemoveElementCommand(element),
    ];
    if (commands.isNotEmpty) {
      historyManager.execute(
        BatchCommand(commands: commands, description: 'Remove layer elements'),
        this,
      );
    }
    layerManager.removeLayer(id);
  }

  void setActiveLayer(String id) => layerManager.setActiveLayer(id);

  void toggleLayerVisibility(String id) => layerManager.toggleVisibility(id);

  void toggleLayerLock(String id) => layerManager.toggleLock(id);

  void setLayerOpacity(String id, double opacity) {
    layerManager.setOpacity(id, opacity);
  }

  int layerIndexOf(String id) => layerManager.layerIndexOf(id);

  bool isLayerVisible(String id) => layerManager.isLayerVisible(id);

  bool isLayerLocked(String id) => layerManager.isLayerLocked(id);

  Map<String, dynamic> toJson() {
    return {
      'version': '0.1.0',
      'layers': [for (final layer in layers) layer.toJson()],
      'elements': [for (final element in elements) element.toJson()],
    };
  }

  void _handleToolResult(ToolResult result) {
    switch (result) {
      case ToolResultNone():
        break;
      case ToolResultConsumed():
        break;
      case ToolResultPreview(:final preview):
        setPreviewElement(preview);
      case ToolResultElement(:final element):
        addElement(element, bringToFront: true);
      case ToolResultSelect(:final selectedIds):
        setSelection(selectedIds);
    }
  }

  void _registerBuiltInTools() {
    if (toolManager.tools.isNotEmpty) {
      return;
    }

    toolManager
      ..registerTool(SelectTool())
      ..registerTool(PenTool())
      ..registerTool(HighlighterTool())
      ..registerTool(LineTool())
      ..registerTool(RectTool())
      ..registerTool(EllipseTool())
      ..registerTool(ArrowTool())
      ..registerTool(const TextTool())
      ..registerTool(const EraserTool())
      ..registerTool(const PanTool());
  }

  CanvasElement _prepareElementForInsert(
    CanvasElement element, {
    bool bringToFront = false,
  }) {
    var prepared = _autoLayeringResolver.resolve(
      element: element,
      existingElements: elements,
      activeLayerId: activeLayerId,
      layerExists: (layerId) => layerManager.layerById(layerId) != null,
      policy: autoLayeringPolicy,
      bringToFront: bringToFront,
    );
    return prepared;
  }

  int nextZIndex(String layerId) {
    var maxZ = 0;
    for (final element in elements) {
      if (element.layerId == layerId && element.zIndex > maxZ) {
        maxZ = element.zIndex;
      }
    }
    return maxZ + 1;
  }

  @override
  void dispose() {
    historyManager.removeListener(notifyListeners);
    layerManager.removeListener(notifyListeners);
    super.dispose();
  }
}

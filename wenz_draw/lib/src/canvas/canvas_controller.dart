import 'package:flutter/widgets.dart';

import '../canvas/paint_style.dart';
import '../elements/arrow_element.dart';
import '../elements/canvas_element.dart';
import '../elements/drawio_shape_element.dart';
import '../elements/element_registry.dart';
import '../elements/ellipse_element.dart';
import '../elements/image_element.dart';
import '../elements/line_element.dart';
import '../elements/polyline_element.dart';
import '../elements/rect_element.dart';
import '../elements/text_element.dart';
import '../history/commands/add_element_command.dart';
import '../history/commands/add_layer_command.dart';
import '../history/commands/batch_command.dart';
import '../history/commands/remove_element_command.dart';
import '../history/commands/remove_layer_command.dart';
import '../history/commands/reorder_layer_command.dart';
import '../history/commands/update_element_command.dart';
import '../history/commands/update_layer_command.dart';
import '../history/canvas_command.dart';
import '../history/history_manager.dart';
import '../infinite_canvas/canvas_event.dart';
import '../layers/auto_layering.dart';
import '../layers/canvas_layer.dart';
import '../layers/layer_manager.dart';
import '../routing/connector_routing.dart';
import '../serialization/canvas_serializer.dart';
import '../snap/snap_resolver.dart';
import '../tools/brush_settings.dart';
import '../tools/alignment_tools.dart';
import '../tools/canvas_tool.dart';
import '../tools/ellipse_tool.dart';
import '../tools/eraser_tool.dart';
import '../tools/highlighter_tool.dart';
import '../tools/line_tool.dart';
import '../tools/curve_tool.dart';
import '../tools/pan_tool.dart';
import '../tools/pen_tool.dart';
import '../tools/polyline_tool.dart';
import '../tools/rect_tool.dart';
import '../tools/select_tool.dart';
import '../tools/shape_tool.dart';
import '../tools/text_tool.dart';
import '../tools/arrow_tool.dart';
import '../tools/tool_manager.dart';
import '../utils/uuid_generator.dart';
import 'canvas_state.dart';
import 'element_manager.dart';
import 'spatial_index.dart';

class CanvasController extends ChangeNotifier {
  CanvasController({
    CanvasState initialState = const CanvasState(),
    ToolManager? toolManager,
    HistoryManager? historyManager,
    LayerManager? layerManager,
    this.autoLayeringPolicy = const AutoLayeringPolicy.activeLayer(),
    SnapSettings snapSettings = const SnapSettings(),
    this.connectorRoutingOptions = const ConnectorRoutingOptions(),
  }) : _state = initialState,
       toolManager = toolManager ?? ToolManager(),
       historyManager = historyManager ?? HistoryManager(),
       layerManager = layerManager ?? LayerManager(),
       snapResolver = SnapResolver(settings: snapSettings) {
    ElementRendererRegistry.ensureBuiltInsRegistered();
    _registerBuiltInTools();
    this.historyManager.addListener(notifyListeners);
    this.layerManager.addListener(notifyListeners);
    setTool(PenTool.idValue);
  }

  final ElementManager _elementManager = const ElementManager();
  final SpatialIndex _spatialIndex = SpatialIndex();
  final AutoLayeringResolver _autoLayeringResolver =
      const AutoLayeringResolver();
  final ToolManager toolManager;
  final HistoryManager historyManager;
  final LayerManager layerManager;
  final AutoLayeringPolicy autoLayeringPolicy;
  final ConnectorRoutingOptions connectorRoutingOptions;
  SnapResolver snapResolver;

  CanvasState _state;
  String? _editingTextElementId;
  TextElement? _editingTextOriginal;
  String? _editingShapeLabelElementId;
  CanvasElement? _editingShapeLabelOriginal;

  SnapResult? _snapPreview;

  CanvasState get state => _state;
  String? get editingTextElementId => _editingTextElementId;
  String? get editingShapeLabelElementId => _editingShapeLabelElementId;
  SnapResult? get snapPreview => _snapPreview;
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
    _spatialIndex.invalidate();
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
    if (_snapPreview?.point.elementId == id) {
      _snapPreview = null;
    }
    _spatialIndex.invalidate();
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
    _applyElementUpdated(id, element, notify: true);
  }

  /// Update an element's state without adding to the undo stack.
  /// Set [notify] to false to skip [notifyListeners] (useful during text
  /// editing to avoid rebuilding the entire canvas on every keystroke).
  void _applyElementUpdated(String id, CanvasElement element,
      {bool notify = true}) {
    _state = _state.copyWith(
      elements: _syncSnapBoundElements(
        _elementManager.update(_state.elements, id, element),
        changedElementId: id,
      ),
    );
    _spatialIndex.invalidate();
    if (notify) {
      notifyListeners();
    }
  }

  List<CanvasElement> _syncSnapBoundElements(
    List<CanvasElement> elements, {
    required String changedElementId,
  }) {
    final byId = {for (final element in elements) element.id: element};
    final resolved = <CanvasElement>[];
    var changed = false;
    for (final element in elements) {
      final next = _resolveSnapBoundElement(element, changedElementId, byId);
      resolved.add(next);
      changed = changed || !identical(next, element);
    }
    return changed ? List<CanvasElement>.unmodifiable(resolved) : elements;
  }

  CanvasElement _resolveSnapBoundElement(
    CanvasElement element,
    String changedElementId,
    Map<String, CanvasElement> elementsById,
  ) {
    if (element is LineElement) {
      final start = element.startBinding?.elementId == changedElementId
          ? _resolveSnapBindingFrom(elementsById, element.startBinding)
          : null;
      final end = element.endBinding?.elementId == changedElementId
          ? _resolveSnapBindingFrom(elementsById, element.endBinding)
          : null;
      if (start == null && end == null) {
        return element;
      }
      return element.copyWith(
        start: start ?? element.start,
        end: end ?? element.end,
      );
    }
    if (element is PolylineElement) {
      final start = element.startBinding?.elementId == changedElementId
          ? _resolveSnapBindingFrom(elementsById, element.startBinding)
          : null;
      final end = element.endBinding?.elementId == changedElementId
          ? _resolveSnapBindingFrom(elementsById, element.endBinding)
          : null;
      if (start == null && end == null || element.points.isEmpty) {
        return element;
      }
      final nextStart = start ?? element.start;
      final nextEnd = end ?? element.end;
      return element.copyWith(
        points: routeConnector(
          start: nextStart,
          end: nextEnd,
          startBinding: element.startBinding,
          endBinding: element.endBinding,
          connectorId: element.id,
          previousRoute: element.points,
          quality: connectorRoutingOptions.finalQuality,
          elementsOverride: elements,
        ),
      );
    }
    if (element is ArrowElement) {
      final start = element.startBinding?.elementId == changedElementId
          ? _resolveSnapBindingFrom(elementsById, element.startBinding)
          : null;
      final end = element.endBinding?.elementId == changedElementId
          ? _resolveSnapBindingFrom(elementsById, element.endBinding)
          : null;
      if (start == null && end == null) {
        return element;
      }
      return element.copyWith(
        start: start ?? element.start,
        end: end ?? element.end,
      );
    }
    return element;
  }

  Offset? _resolveSnapBindingFrom(
    Map<String, CanvasElement> elementsById,
    SnapBinding? binding,
  ) {
    if (binding == null) {
      return null;
    }
    final target = elementsById[binding.elementId];
    if (target == null ||
        !target.visible ||
        !isLayerVisible(target.layerId) ||
        isLayerLocked(target.layerId)) {
      return null;
    }
    for (final point in snapResolver.pointsForElement(target)) {
      if (point.anchorId == binding.anchorId) {
        return point.position;
      }
    }
    return null;
  }

  List<Offset> routeConnector({
    required Offset start,
    required Offset end,
    SnapBinding? startBinding,
    SnapBinding? endBinding,
    String? connectorId,
    List<Offset>? previousRoute,
    ConnectorRouteQuality quality = ConnectorRouteQuality.high,
    Iterable<CanvasElement>? elementsOverride,
  }) {
    final service = ConnectorRoutingService(options: connectorRoutingOptions);
    return service
        .route(
          start: start,
          end: end,
          elements: elementsOverride ?? _state.elements,
          isLayerVisible: isLayerVisible,
          isLayerLocked: isLayerLocked,
          startBinding: startBinding,
          endBinding: endBinding,
          connectorId: connectorId,
          previousRoute: previousRoute,
          quality: quality,
        )
        .points;
  }

  void replaceElements(
    List<CanvasElement> elements, {
    bool clearHistory = true,
  }) {
    _editingTextElementId = null;
    _editingTextOriginal = null;
    _editingShapeLabelElementId = null;
    _editingShapeLabelOriginal = null;
    _snapPreview = null;
    _state = _state.copyWith(
      elements: List<CanvasElement>.unmodifiable(elements),
      previewElement: null,
      selectedIds: const <String>{},
      selectionRect: null,
    );
    _spatialIndex.invalidate();
    if (clearHistory) {
      historyManager.clear();
    }
    notifyListeners();
  }

  /// Loads [layers] and [elements] into the controller, replacing all existing
  /// data. History is cleared and the active layer is set to the first layer.
  void loadDocument(
    List<CanvasLayer> layers,
    List<CanvasElement> elements,
  ) {
    if (layers.isNotEmpty) {
      layerManager.replaceLayers(
        layers,
        activeLayerId: layers.first.id,
      );
    }
    replaceElements(elements);
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
    _snapPreview = null;
    notifyListeners();
  }

  void setSnapPreview(SnapResult? result) {
    _snapPreview = result;
    notifyListeners();
  }

  void updateSnapSettings(SnapSettings settings) {
    snapResolver = SnapResolver(settings: settings);
    _snapPreview = null;
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

  Iterable<CanvasElement> elementsInViewport(Rect worldRect) {
    final visible =
        _spatialIndex
            .query(_state.elements, worldRect)
            .where(
              (element) => element.visible && isLayerVisible(element.layerId),
            )
            .toList()
          ..sort((a, b) {
            final layerOrder = layerIndexOf(
              a.layerId,
            ).compareTo(layerIndexOf(b.layerId));
            if (layerOrder != 0) {
              return layerOrder;
            }
            final zOrder = a.zIndex.compareTo(b.zIndex);
            if (zOrder != 0) {
              return zOrder;
            }
            return _state.elements
                .indexOf(a)
                .compareTo(_state.elements.indexOf(b));
          });
    return visible;
  }

  CanvasElement? hitTest(Offset worldPoint, {double tolerance = 5}) {
    return _elementManager.hitTest(
      _spatialIndex
          .queryPoint(_state.elements, worldPoint, tolerance: tolerance)
          .where((element) => isLayerVisible(element.layerId)),
      worldPoint,
      tolerance: tolerance,
      layerRank: (element) => layerManager.layerIndexOf(element.layerId),
    );
  }

  Iterable<CanvasElement> elementsNear(Rect worldRect) {
    return _spatialIndex
        .query(_state.elements, worldRect)
        .where(
          (element) =>
              element.visible &&
              isLayerVisible(element.layerId) &&
              !isLayerLocked(element.layerId),
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

  void addLayer({String? name}) {
    final layer = CanvasLayer(
      id: UuidGenerator.create(),
      name: name ?? 'Layer ${layers.length + 1}',
    );
    historyManager.execute(
      AddLayerCommand(
        layer: layer,
        previousActiveLayerId: activeLayerId,
      ),
      this,
    );
  }

  void removeLayer(String id) {
    if (layers.length == 1) {
      return;
    }
    final layer = layerManager.layerById(id);
    if (layer == null) {
      return;
    }
    final layerIndex = layerManager.layerIndexOf(id);
    final wasActive = activeLayerId == id;
    final layerElements = elements
        .where((element) => element.layerId == id)
        .toList();

    historyManager.execute(
      RemoveLayerCommand(
        layer: layer,
        layerIndex: layerIndex,
        wasActiveLayer: wasActive,
        elements: layerElements,
      ),
      this,
    );
  }

  void setActiveLayer(String id) => layerManager.setActiveLayer(id);

  void toggleLayerVisibility(String id) {
    final layer = layerManager.layerById(id);
    if (layer == null) {
      return;
    }
    historyManager.execute(
      UpdateLayerCommand(
        before: layer,
        after: layer.copyWith(isVisible: !layer.isVisible),
        descriptionText: layer.isVisible ? 'Hide layer' : 'Show layer',
      ),
      this,
    );
  }

  void toggleLayerLock(String id) {
    final layer = layerManager.layerById(id);
    if (layer == null) {
      return;
    }
    historyManager.execute(
      UpdateLayerCommand(
        before: layer,
        after: layer.copyWith(isLocked: !layer.isLocked),
        descriptionText: layer.isLocked ? 'Unlock layer' : 'Lock layer',
      ),
      this,
    );
  }

  void setLayerOpacity(String id, double opacity) {
    final layer = layerManager.layerById(id);
    if (layer == null) {
      return;
    }
    historyManager.execute(
      UpdateLayerCommand(
        before: layer,
        after: layer.copyWith(opacity: opacity.clamp(0.0, 1.0)),
        descriptionText: 'Set layer opacity',
      ),
      this,
    );
  }

  void reorderLayer(int oldIndex, int newIndex) {
    historyManager.execute(
      ReorderLayerCommand(oldIndex: oldIndex, newIndex: newIndex),
      this,
    );
  }

  int layerIndexOf(String id) => layerManager.layerIndexOf(id);

  bool isLayerVisible(String id) => layerManager.isLayerVisible(id);

  bool isLayerLocked(String id) => layerManager.isLayerLocked(id);

  static const _unsetTextStyleValue = Object();
  static const unsetTextStyleValue = _unsetTextStyleValue;

  // ─── Clipboard ────────────────────────────────────────────────
  List<Map<String, dynamic>> _clipboard = const [];

  /// Copies selected elements to the internal clipboard.
  void copySelected() {
    if (selectedIds.isEmpty) {
      return;
    }
    _clipboard = [
      for (final element in selectedElements) element.toJson(),
    ];
  }

  /// Cuts selected elements: copies them then removes them.
  void cutSelected() {
    if (selectedIds.isEmpty) {
      return;
    }
    copySelected();
    removeSelected();
  }

  /// Pastes clipboard elements with a small offset and selects the new ones.
  void paste() {
    if (_clipboard.isEmpty) {
      return;
    }
    final offset = const Offset(20, 20);
    final commands = <AddElementCommand>[];
    final newIds = <String>{};
    for (final json in _clipboard) {
      final newId = UuidGenerator.create();
      final patched = Map<String, dynamic>.from(json)
        ..['id'] = newId;
      final element = CanvasSerializer.elementFromJson(patched);
      final translated = element.translate(offset);
      final prepared = _prepareElementForInsert(translated);
      commands.add(AddElementCommand(prepared));
      newIds.add(prepared.id);
    }
    if (commands.isEmpty) {
      return;
    }
    historyManager.execute(
      BatchCommand(commands: commands, description: 'Paste'),
      this,
    );
    setSelection(newIds);
  }

  // ─── Duplicate ───────────────────────────────────────────────

  /// Duplicates selected elements with a small offset and selects the copies.
  void duplicateSelected() {
    if (selectedIds.isEmpty) {
      return;
    }
    final offset = const Offset(20, 20);
    final commands = <AddElementCommand>[];
    final newIds = <String>{};
    for (final element in selectedElements) {
      final newId = UuidGenerator.create();
      final patched = Map<String, dynamic>.from(element.toJson())
        ..['id'] = newId;
      final clone = CanvasSerializer.elementFromJson(patched);
      final translated = clone.translate(offset);
      final prepared = _prepareElementForInsert(translated);
      commands.add(AddElementCommand(prepared));
      newIds.add(prepared.id);
    }
    if (commands.isEmpty) {
      return;
    }
    historyManager.execute(
      BatchCommand(commands: commands, description: 'Duplicate selection'),
      this,
    );
    setSelection(newIds);
  }

  // ─── Z-Order ─────────────────────────────────────────────────

  /// Brings selected elements to the front (highest z-order) within their
  /// layers.
  void bringSelectedToFront() {
    if (selectedIds.isEmpty) {
      return;
    }
    // Group by layer and compute the max zIndex per layer among
    // non-selected elements.
    final maxZByLayer = <String, int>{};
    for (final element in elements) {
      if (selectedIds.contains(element.id)) {
        continue;
      }
      final current = maxZByLayer[element.layerId] ?? 0;
      if (element.zIndex > current) {
        maxZByLayer[element.layerId] = element.zIndex;
      }
    }
    final commands = <UpdateElementCommand>[];
    final selectedByLayer = <String, List<CanvasElement>>{};
    for (final element in selectedElements) {
      selectedByLayer.putIfAbsent(element.layerId, () => []).add(element);
    }
    for (final entry in selectedByLayer.entries) {
      var nextZ = maxZByLayer[entry.key] ?? 0;
      for (final element in entry.value) {
        nextZ++;
        if (element.zIndex != nextZ) {
          commands.add(
            UpdateElementCommand(
              before: element,
              after: element.copyWith(zIndex: nextZ),
              description: 'Bring to front',
            ),
          );
        }
      }
    }
    if (commands.isEmpty) {
      return;
    }
    historyManager.execute(
      BatchCommand(commands: commands, description: 'Bring to front'),
      this,
    );
  }

  /// Sends selected elements to the back (lowest z-order) within their
  /// layers.
  void sendSelectedToBack() {
    if (selectedIds.isEmpty) {
      return;
    }
    final minZByLayer = <String, int>{};
    for (final element in elements) {
      if (selectedIds.contains(element.id)) {
        continue;
      }
      final current = minZByLayer[element.layerId];
      if (current == null || element.zIndex < current) {
        minZByLayer[element.layerId] = element.zIndex;
      }
    }
    final commands = <UpdateElementCommand>[];
    final selectedByLayer = <String, List<CanvasElement>>{};
    for (final element in selectedElements) {
      selectedByLayer.putIfAbsent(element.layerId, () => []).add(element);
    }
    for (final entry in selectedByLayer.entries) {
      var nextZ = (minZByLayer[entry.key] ?? 1) - entry.value.length;
      for (final element in entry.value) {
        if (element.zIndex != nextZ) {
          commands.add(
            UpdateElementCommand(
              before: element,
              after: element.copyWith(zIndex: nextZ),
              description: 'Send to back',
            ),
          );
        }
        nextZ++;
      }
    }
    if (commands.isEmpty) {
      return;
    }
    historyManager.execute(
      BatchCommand(commands: commands, description: 'Send to back'),
      this,
    );
  }

  // ─── Group / Ungroup ────────────────────────────────────────

  /// Groups selected elements by assigning them a shared groupId.
  /// Selects all grouped elements afterward.
  void groupSelected() {
    if (selectedIds.length < 2) {
      return;
    }
    final groupId = UuidGenerator.create();
    final commands = <UpdateElementCommand>[];
    for (final element in selectedElements) {
      if (element.groupId != groupId) {
        commands.add(
          UpdateElementCommand(
            before: element,
            after: element.copyWith(groupId: groupId),
            description: 'Group',
          ),
        );
      }
    }
    if (commands.isEmpty) {
      return;
    }
    historyManager.execute(
      BatchCommand(commands: commands, description: 'Group elements'),
      this,
    );
  }

  /// Removes the groupId from selected elements.
  /// If only one element is selected and it has a groupId, also selects all
  /// other elements that shared that group before ungrouping.
  void ungroupSelected() {
    if (selectedIds.isEmpty) {
      return;
    }
    // Collect all groupIds from selected elements
    final groupIds = <String>{};
    for (final element in selectedElements) {
      final gid = element.groupId;
      if (gid != null) {
        groupIds.add(gid);
      }
    }
    if (groupIds.isEmpty) {
      return;
    }
    // Collect all elements that belong to these groups (including unselected)
    final toUngroup = <CanvasElement>[];
    for (final element in elements) {
      if (element.groupId != null && groupIds.contains(element.groupId)) {
        toUngroup.add(element);
      }
    }
    final commands = <UpdateElementCommand>[];
    for (final element in toUngroup) {
      commands.add(
        UpdateElementCommand(
          before: element,
          after: element.copyWith(groupId: null),
          description: 'Ungroup',
        ),
      );
    }
    if (commands.isEmpty) {
      return;
    }
    historyManager.execute(
      BatchCommand(commands: commands, description: 'Ungroup elements'),
      this,
    );
    // Select all ungrouped elements
    setSelection({for (final element in toUngroup) element.id});
  }

  /// Returns all elements that share a groupId with any selected element.
  List<CanvasElement> get elementsInSelectedGroups {
    if (selectedIds.isEmpty) {
      return const [];
    }
    final groupIds = <String>{};
    for (final element in selectedElements) {
      final gid = element.groupId;
      if (gid != null) {
        groupIds.add(gid);
      }
    }
    if (groupIds.isEmpty) {
      return selectedElements;
    }
    return [
      for (final element in elements)
        if (element.groupId != null && groupIds.contains(element.groupId))
          element,
    ];
  }

  // ─── Alignment & Distribution ────────────────────────────────

  /// Aligns selected elements to the specified edge/center.
  /// Requires at least 2 selected elements.
  void alignSelected(AlignMode mode) {
    AlignmentTools.align(this, mode);
  }

  /// Distributes selected elements with equal spacing.
  /// Requires at least 3 selected elements.
  void distributeSelected(AlignAxis axis) {
    AlignmentTools.distribute(this, axis);
  }

  void updateTextElementStyle(
    String id, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    TextAlign? textAlign,
    double? lineHeight,
    Object? fontFamily = _unsetTextStyleValue,
    double? maxWidth,
    Size? boxSize,
    bool record = true,
  }) {
    final element = elementById(id);
    if (element is! TextElement) {
      return;
    }
    final nextFontFamily = identical(fontFamily, _unsetTextStyleValue)
        ? element.style.fontFamily
        : fontFamily as String?;
    final nextStyle = TextStyle(
      color: color ?? element.style.color,
      fontSize: fontSize ?? element.style.fontSize,
      fontWeight: fontWeight ?? element.style.fontWeight,
      height: lineHeight ?? element.style.height,
      fontFamily: nextFontFamily,
    );
    updateElement(
      id,
      element.copyWith(
        style: nextStyle,
        textAlign: textAlign,
        maxWidth: maxWidth ?? element.maxWidth,
        boxSize: boxSize ?? element.boxSize,
      ),
      record: record,
    );
  }

  void updateShapePaint(
    String id, {
    Color? fillColor,
    bool clearFill = false,
    Color? strokeColor,
    double? strokeWidth,
    double? opacity,
    bool record = true,
  }) {
    final element = elementById(id);
    PaintStyle? nextFill(PaintStyle? current) {
      if (clearFill) {
        return null;
      }
      if (fillColor == null && opacity == null) {
        return current;
      }
      return (current ?? const PaintStyle()).copyWith(
        color: fillColor,
        opacity: opacity,
        paintingStyle: PaintingStyle.fill,
        strokeWidth: 0,
      );
    }

    switch (element) {
      case DrawioShapeElement e:
        updateElement(
          id,
          e.copyWith(
            fillStyle: nextFill(e.fillStyle),
            strokeStyle: e.strokeStyle.copyWith(
              color: strokeColor,
              opacity: opacity,
              strokeWidth: strokeWidth,
            ),
          ),
          record: record,
        );
      case RectElement e:
        updateElement(
          id,
          e.copyWith(
            fillStyle: nextFill(e.fillStyle),
            strokeStyle: e.strokeStyle.copyWith(
              color: strokeColor,
              opacity: opacity,
              strokeWidth: strokeWidth,
            ),
          ),
          record: record,
        );
      case EllipseElement e:
        updateElement(
          id,
          e.copyWith(
            fillStyle: nextFill(e.fillStyle),
            strokeStyle: e.strokeStyle.copyWith(
              color: strokeColor,
              opacity: opacity,
              strokeWidth: strokeWidth,
            ),
          ),
          record: record,
        );
    }
  }

  void updateShapeLabelStyle(
    String id, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    TextAlign? textAlign,
    double? lineHeight,
    Object? fontFamily = _unsetTextStyleValue,
    bool record = true,
  }) {
    final element = elementById(id);
    if (element is! DrawioShapeElement &&
        element is! RectElement &&
        element is! EllipseElement &&
        element is! LineElement &&
        element is! ArrowElement &&
        element is! PolylineElement) {
      return;
    }
    final style = switch (element) {
      DrawioShapeElement e => e.labelStyle,
      RectElement e => e.labelStyle,
      EllipseElement e => e.labelStyle,
      LineElement e => e.labelStyle,
      ArrowElement e => e.labelStyle,
      PolylineElement e => e.labelStyle,
      _ => const TextStyle(),
    };
    final nextFontFamily = identical(fontFamily, _unsetTextStyleValue)
        ? style.fontFamily
        : fontFamily as String?;
    final nextStyle = TextStyle(
      color: color ?? style.color,
      fontSize: fontSize ?? style.fontSize,
      fontWeight: fontWeight ?? style.fontWeight,
      height: lineHeight ?? style.height,
      fontFamily: nextFontFamily,
    );
    switch (element) {
      case DrawioShapeElement e:
        updateElement(
          id,
          e.copyWith(
            labelStyle: nextStyle,
            labelAlign: textAlign ?? e.labelAlign,
          ),
          record: record,
        );
      case RectElement e:
        updateElement(
          id,
          e.copyWith(
            labelStyle: nextStyle,
            labelAlign: textAlign ?? e.labelAlign,
          ),
          record: record,
        );
      case EllipseElement e:
        updateElement(
          id,
          e.copyWith(
            labelStyle: nextStyle,
            labelAlign: textAlign ?? e.labelAlign,
          ),
          record: record,
        );
      case LineElement e:
        updateElement(id, e.copyWith(labelStyle: nextStyle), record: record);
      case ArrowElement e:
        updateElement(id, e.copyWith(labelStyle: nextStyle), record: record);
      case PolylineElement e:
        updateElement(id, e.copyWith(labelStyle: nextStyle), record: record);
    }
  }

  void resizeTextElement(
    String id,
    Size boxSize, {
    bool record = true,
    double minWidth = 24,
    double minHeight = 24,
  }) {
    final element = elementById(id);
    if (element is! TextElement) {
      return;
    }
    final constrained = Size(
      boxSize.width < minWidth ? minWidth : boxSize.width,
      boxSize.height < minHeight ? minHeight : boxSize.height,
    );
    updateElement(
      id,
      element.copyWith(maxWidth: constrained.width, boxSize: constrained),
      record: record,
    );
  }

  void updateElementRotation(String id, double radians, {bool record = true}) {
    final element = elementById(id);
    if (element is DrawioShapeElement) {
      updateElement(id, element.copyWith(rotation: radians), record: record);
    } else if (element is RectElement) {
      updateElement(id, element.copyWith(rotation: radians), record: record);
    } else if (element is EllipseElement) {
      updateElement(id, element.copyWith(rotation: radians), record: record);
    } else if (element is TextElement) {
      updateElement(id, element.copyWith(rotation: radians), record: record);
    } else if (element is ImageElement) {
      updateElement(id, element.copyWith(rotation: radians), record: record);
    }
  }

  void updateTextContent(String id, String text, {bool record = true}) {
    final element = elementById(id);
    if (element is TextElement) {
      // Skip if text is unchanged.
      if (element.text == text) {
        return;
      }
      updateElement(id, element.copyWith(text: text), record: record);
      return;
    }
    if (element == null) {
      return;
    }
    final next = _copyWithShapeLabel(
      element,
      text.trim().isEmpty ? null : text,
    );
    if (next != null &&
        next.toJson().toString() != element.toJson().toString()) {
      updateElement(id, next, record: record);
    }
  }

  void beginTextEditing(String id) {
    final element = elementById(id);
    if (element is! TextElement) {
      return;
    }
    if (_editingShapeLabelElementId != null) {
      endShapeLabelEditing();
    }
    if (_editingTextElementId == id) {
      return;
    }
    _editingTextElementId = id;
    _editingTextOriginal = element;
    select(id);
  }

  void updateEditingText(String text) {
    final id = _editingTextElementId;
    if (id == null) {
      return;
    }
    final element = elementById(id);
    if (element is! TextElement || element.text == text) {
      return;
    }
    // Silent update: the TextField overlay already shows the text being
    // typed, so there is no need to rebuild the entire canvas on every
    // keystroke.  A single notifyListeners() will fire in endTextEditing().
    _applyElementUpdated(id, element.copyWith(text: text), notify: false);
  }

  void endTextEditing({String? text, bool removeIfEmpty = true}) {
    final id = _editingTextElementId;
    if (id == null) {
      return;
    }
    if (text != null) {
      updateEditingText(text);
    }

    _editingTextElementId = null;
    final original = _editingTextOriginal;
    _editingTextOriginal = null;
    final element = elementById(id);
    if (element is TextElement) {
      if (removeIfEmpty && element.text.trim().isEmpty) {
        removeElement(id);
        return;
      }
      if (original != null && !_sameTextElement(original, element)) {
        historyManager.record(
          UpdateElementCommand(
            before: original,
            after: element,
            description: 'Edit text',
          ),
        );
      }
    }
    notifyListeners();
  }

  void cancelTextEditing() {
    if (_editingTextElementId == null) {
      return;
    }
    _editingTextElementId = null;
    _editingTextOriginal = null;
    notifyListeners();
  }

  void beginShapeLabelEditing(String id) {
    final element = elementById(id);
    if (element is! DrawioShapeElement &&
        element is! RectElement &&
        element is! EllipseElement &&
        element is! LineElement &&
        element is! ArrowElement &&
        element is! PolylineElement) {
      return;
    }
    if (_editingTextElementId != null) {
      endTextEditing();
    }
    if (_editingShapeLabelElementId == id) {
      return;
    }
    _editingShapeLabelElementId = id;
    _editingShapeLabelOriginal = element;
    select(id);
  }

  void updateEditingShapeLabel(String text, {bool clearWhenEmpty = true}) {
    final id = _editingShapeLabelElementId;
    if (id == null) {
      return;
    }
    final element = elementById(id);
    if (element == null) {
      return;
    }
    final label = text.trim().isEmpty && clearWhenEmpty ? null : text;
    final next = _copyWithShapeLabel(element, label);
    if (next == null ||
        next.toJson().toString() == element.toJson().toString()) {
      return;
    }
    // Silent update during editing to avoid canvas rebuild on every keystroke.
    _applyElementUpdated(id, next, notify: false);
  }

  void endShapeLabelEditing({String? text}) {
    final id = _editingShapeLabelElementId;
    if (id == null) {
      return;
    }
    if (text != null) {
      updateEditingShapeLabel(text, clearWhenEmpty: false);
    }
    _editingShapeLabelElementId = null;
    final original = _editingShapeLabelOriginal;
    _editingShapeLabelOriginal = null;
    final element = elementById(id);
    if (original != null &&
        element != null &&
        original.toJson().toString() != element.toJson().toString()) {
      historyManager.record(
        UpdateElementCommand(
          before: original,
          after: element,
          description: 'Edit shape label',
        ),
      );
    }
    notifyListeners();
  }

  void cancelShapeLabelEditing() {
    if (_editingShapeLabelElementId == null) {
      return;
    }
    _editingShapeLabelElementId = null;
    _editingShapeLabelOriginal = null;
    notifyListeners();
  }

  CanvasElement? _copyWithShapeLabel(CanvasElement element, String? label) {
    if (element is DrawioShapeElement) {
      return element.copyWith(label: label);
    }
    if (element is RectElement) {
      return element.copyWith(label: label);
    }
    if (element is EllipseElement) {
      return element.copyWith(label: label);
    }
    if (element is LineElement) {
      return element.copyWith(label: label);
    }
    if (element is ArrowElement) {
      return element.copyWith(label: label);
    }
    if (element is PolylineElement) {
      return element.copyWith(label: label);
    }
    return null;
  }

  bool _sameTextElement(TextElement a, TextElement b) {
    return a.toJson().toString() == b.toJson().toString();
  }

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
      case ToolResultElement(:final element, :final selectAfter):
        addElement(element, bringToFront: true);
        if (element is TextElement) {
          beginTextEditing(element.id);
        } else if (selectAfter) {
          setSelection({element.id});
          setTool(SelectTool.idValue);
        }
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
      ..registerTool(CurveTool())
      ..registerTool(PolylineTool())
      ..registerTool(RectTool())
      ..registerTool(EllipseTool())
      ..registerTool(ShapeTool(shapeKey: 'rhombus', name: 'Rhombus'))
      ..registerTool(ShapeTool(shapeKey: 'triangle', name: 'Triangle'))
      ..registerTool(ShapeTool(shapeKey: 'hexagon', name: 'Hexagon'))
      ..registerTool(
        ShapeTool(shapeKey: 'parallelogram', name: 'Parallelogram'),
      )
      ..registerTool(ShapeTool(shapeKey: 'trapezoid', name: 'Trapezoid'))
      ..registerTool(ShapeTool(shapeKey: 'cylinder', name: 'Cylinder'))
      ..registerTool(
        ShapeTool(shapeKey: 'doubleEllipse', name: 'Double Ellipse'),
      )
      ..registerTool(ShapeTool(shapeKey: 'actor', name: 'Actor'))
      ..registerTool(ShapeTool(shapeKey: 'cloud', name: 'Cloud'))
      ..registerTool(ShapeTool(shapeKey: 'swimlane', name: 'Swimlane'))
      ..registerTool(ShapeTool(shapeKey: 'document', name: 'Document'))
      ..registerTool(ShapeTool(shapeKey: 'note', name: 'Note'))
      ..registerTool(ShapeTool(shapeKey: 'callout', name: 'Callout'))
      ..registerTool(ShapeTool(shapeKey: 'plus', name: 'Plus'))
      ..registerTool(ShapeTool(shapeKey: 'cross', name: 'Cross'))
      ..registerTool(ShapeTool(shapeKey: 'step', name: 'Step'))
      ..registerTool(ShapeTool(shapeKey: 'cube', name: 'Cube'))
      ..registerTool(ArrowTool())
      ..registerTool(const TextTool())
      ..registerTool(EraserTool())
      ..registerTool(const PanTool());
  }

  CanvasElement _prepareElementForInsert(
    CanvasElement element, {
    bool bringToFront = false,
  }) {
    final prepared = _autoLayeringResolver.resolve(
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

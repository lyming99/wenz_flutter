import 'package:flutter/widgets.dart';

import '../elements/canvas_element.dart';

class SelectionManager extends ChangeNotifier {
  final Set<String> _selectedIds = {};

  Set<String> get selectedIds => Set<String>.unmodifiable(_selectedIds);

  bool isSelected(String id) => _selectedIds.contains(id);

  void select(String id, {bool addToSelection = false}) {
    if (!addToSelection) {
      _selectedIds.clear();
    }
    _selectedIds.add(id);
    notifyListeners();
  }

  void setSelection(Set<String> ids) {
    _selectedIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void selectInRect(Rect worldRect, Iterable<CanvasElement> elements) {
    setSelection({
      for (final element in elements)
        if (element.visible && element.bounds.overlaps(worldRect)) element.id,
    });
  }

  void selectAll(Iterable<CanvasElement> elements) {
    setSelection({for (final element in elements) element.id});
  }

  void deselectAll() {
    if (_selectedIds.isEmpty) {
      return;
    }
    _selectedIds.clear();
    notifyListeners();
  }

  List<CanvasElement> selectedElements(Iterable<CanvasElement> elements) {
    return [
      for (final element in elements)
        if (_selectedIds.contains(element.id)) element,
    ];
  }
}

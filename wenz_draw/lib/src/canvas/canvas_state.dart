import 'package:flutter/material.dart';

import '../elements/canvas_element.dart';

@immutable
class CanvasState {
  const CanvasState({
    this.elements = const <CanvasElement>[],
    this.previewElement,
    this.selectionRect,
    this.selectedIds = const <String>{},
    this.backgroundColor = Colors.white,
    this.revision = 0,
  });

  static const _unset = Object();

  final List<CanvasElement> elements;
  final CanvasElement? previewElement;
  final Rect? selectionRect;
  final Set<String> selectedIds;
  final Color backgroundColor;
  final int revision;

  CanvasState copyWith({
    List<CanvasElement>? elements,
    Object? previewElement = _unset,
    Object? selectionRect = _unset,
    Set<String>? selectedIds,
    Color? backgroundColor,
    bool bumpRevision = true,
  }) {
    return CanvasState(
      elements: elements ?? this.elements,
      previewElement: identical(previewElement, _unset)
          ? this.previewElement
          : previewElement as CanvasElement?,
      selectionRect: identical(selectionRect, _unset)
          ? this.selectionRect
          : selectionRect as Rect?,
      selectedIds: selectedIds ?? this.selectedIds,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      revision: revision + (bumpRevision ? 1 : 0),
    );
  }

  Rect? get contentBounds {
    if (elements.isEmpty) {
      return null;
    }

    var bounds = elements.first.bounds;
    for (final element in elements.skip(1)) {
      bounds = bounds.expandToInclude(element.bounds);
    }
    return bounds;
  }
}

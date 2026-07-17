import 'package:flutter/widgets.dart';

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';
import '../history/commands/batch_command.dart';
import '../history/commands/update_element_command.dart';

/// Alignment axis for distributing elements.
enum AlignAxis { horizontal, vertical }

/// Edge or center to align to.
enum AlignMode {
  left,
  right,
  top,
  bottom,
  centerHorizontal,
  centerVertical,
}

/// Alignment and distribution utilities for canvas elements.
class AlignmentTools {
  const AlignmentTools._();

  /// Aligns the selected elements according to [mode].
  /// Uses a [BatchCommand] so the entire alignment is one undo step.
  static void align(
    CanvasController controller,
    AlignMode mode, {
    bool record = true,
  }) {
    final selected = controller.selectedElements;
    if (selected.length < 2) {
      return;
    }

    // Compute the reference value from the selection bounds.
    var left = selected.first.bounds.left;
    var right = selected.first.bounds.right;
    var top = selected.first.bounds.top;
    var bottom = selected.first.bounds.bottom;
    for (final element in selected.skip(1)) {
      final b = element.bounds;
      left = b.left < left ? b.left : left;
      right = b.right > right ? b.right : right;
      top = b.top < top ? b.top : top;
      bottom = b.bottom > bottom ? b.bottom : bottom;
    }

    final commands = <UpdateElementCommand>[];
    for (final element in selected) {
      final b = element.bounds;
      Offset delta = Offset.zero;
      switch (mode) {
        case AlignMode.left:
          delta = Offset(left - b.left, 0);
        case AlignMode.right:
          delta = Offset(right - b.right, 0);
        case AlignMode.top:
          delta = Offset(0, top - b.top);
        case AlignMode.bottom:
          delta = Offset(0, bottom - b.bottom);
        case AlignMode.centerHorizontal:
          final targetCenterX = (left + right) / 2;
          delta = Offset(targetCenterX - b.center.dx, 0);
        case AlignMode.centerVertical:
          final targetCenterY = (top + bottom) / 2;
          delta = Offset(0, targetCenterY - b.center.dy);
      }
      if (delta != Offset.zero) {
        commands.add(
          UpdateElementCommand(
            before: element,
            after: element.translate(delta),
            description: 'Align',
          ),
        );
      }
    }

    if (commands.isEmpty) {
      return;
    }

    final batch = BatchCommand(commands: commands, description: 'Align ${mode.name}');
    if (record) {
      controller.historyManager.execute(batch, controller);
    } else {
      batch.execute(controller);
    }
  }

  /// Distributes selected elements with equal spacing along [axis].
  /// Requires at least 3 selected elements.
  static void distribute(
    CanvasController controller,
    AlignAxis axis, {
    bool record = true,
  }) {
    final selected = controller.selectedElements;
    if (selected.length < 3) {
      return;
    }

    // Sort by the relevant axis
    final sorted = List<CanvasElement>.from(selected)
      ..sort((a, b) {
        final aVal = axis == AlignAxis.horizontal
            ? a.bounds.left
            : a.bounds.top;
        final bVal = axis == AlignAxis.horizontal
            ? b.bounds.left
            : b.bounds.top;
        return aVal.compareTo(bVal);
      });

    final first = sorted.first.bounds;
    final last = sorted.last.bounds;

    double totalGap;
    if (axis == AlignAxis.horizontal) {
      totalGap = (last.right - first.left) -
          sorted.fold(0.0, (sum, e) => sum + e.bounds.width);
    } else {
      totalGap = (last.bottom - first.top) -
          sorted.fold(0.0, (sum, e) => sum + e.bounds.height);
    }

    final gapCount = sorted.length - 1;
    final gap = gapCount > 0 ? totalGap / gapCount : 0.0;

    final commands = <UpdateElementCommand>[];
    double currentPos;
    if (axis == AlignAxis.horizontal) {
      currentPos = first.left;
    } else {
      currentPos = first.top;
    }

    for (final element in sorted) {
      final b = element.bounds;
      Offset delta;
      if (axis == AlignAxis.horizontal) {
        delta = Offset(currentPos - b.left, 0);
        currentPos += b.width + gap;
      } else {
        delta = Offset(0, currentPos - b.top);
        currentPos += b.height + gap;
      }
      if (delta != Offset.zero) {
        commands.add(
          UpdateElementCommand(
            before: element,
            after: element.translate(delta),
            description: 'Distribute',
          ),
        );
      }
    }

    if (commands.isEmpty) {
      return;
    }

    final batch = BatchCommand(
      commands: commands,
      description: 'Distribute ${axis.name}',
    );
    if (record) {
      controller.historyManager.execute(batch, controller);
    } else {
      batch.execute(controller);
    }
  }
}

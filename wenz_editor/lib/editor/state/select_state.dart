import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../cursor/cursor.dart';
import '../edit_controller.dart';

class SelectState with ChangeNotifier {
  WenzEditController editController;
  CursorPosition? _start;
  CursorPosition? _end;
  PointerDownEvent? dragCursorStartEvent;
  Offset? dragCursorStartPosition;

  bool isCursorDragging = false;

  SelectState({
    required this.editController,
  });

  set start(CursorPosition? cursor) {
    _start = cursor;
    editController.onSelectChanged();
    notifyListeners();
  }

  CursorPosition? get start {
    return _start;
  }

  set end(CursorPosition? cursor) {
    _end = cursor;
    editController.onSelectChanged();
    notifyListeners();
  }

  CursorPosition? get end {
    return _end;
  }

  bool get shiftDown => isShiftPressed;

  /// Returns true if the given [KeyboardKey] is pressed.
  bool isKeyPressed(LogicalKeyboardKey key) =>
      RawKeyboard.instance.keysPressed.contains(key);

  /// Returns true if a CTRL modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Use [isKeyPressed] if you need to know which control key was pressed.
  bool get isControlPressed {
    return isKeyPressed(LogicalKeyboardKey.controlLeft) ||
        isKeyPressed(LogicalKeyboardKey.controlRight);
  }

  bool get isShiftPressed {
    return isKeyPressed(LogicalKeyboardKey.shiftLeft) ||
        isKeyPressed(LogicalKeyboardKey.shiftRight);
  }

  bool get hasSelect {
    return start != null && end != null && start != end;
  }

  bool get hasSelectRange {
    var start = realStart;
    var end = realEnd;
    if (start == null || end == null) {
      return false;
    }
    if (start.block?.top != end.block?.top) {
      return true;
    }
    if (start.textPosition?.offset != end.textPosition?.offset) {
      return true;
    }
    return false;
  }

  void clearSelect() {
    start = null;
    end = null;
  }

  void clearSelectIfNoShift() {
    if (!shiftDown) {
      clearSelect();
    }
  }

  CursorPosition? get realStart {
    if ((start?.isValid ?? false) == false ||
        (end?.isValid ?? false) == false) {
      return null;
    }
    if (start!.block!.top < end!.block!.top) {
      return start;
    }
    if (start!.block!.top == end!.block!.top) {
      if (start!.textPosition!.offset < end!.textPosition!.offset) {
        return start;
      }
    }
    return end;
  }

  CursorPosition? get realEnd {
    if ((start?.isValid ?? false) == false ||
        (end?.isValid ?? false) == false) {
      return null;
    }
    if (start!.block!.top < end!.block!.top) {
      return end;
    }
    if (start!.block!.top == end!.block!.top) {
      if (start!.textPosition!.offset < end!.textPosition!.offset) {
        return end;
      }
    }
    return start;
  }

  int get selectLength {
    if (!hasSelect) {
      return 0;
    }
    var ans =
        (start?.textPosition?.offset ?? 0) - (end?.textPosition?.offset ?? 0);
    if (ans < 0) {
      return -ans;
    }
    return ans;
  }

  void swapToRealSelect(WenzEditController controller) {
    var start = realStart;
    var end = realEnd;
    if (start == this.start) {
      return;
    }
    this.start = start;
    this.end = end;
    SchedulerBinding.instance.scheduleFrameCallback((timeStamp) {
      controller.updateWidgetState();
    });
  }
}

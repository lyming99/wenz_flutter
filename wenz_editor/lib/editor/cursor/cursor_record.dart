
import 'dart:collection';

import 'cursor.dart';

class CursorRecord {
  int saveSize = 10;
  Queue<CursorPosition> cursorPositionStack = Queue();

  ///记录光标的窗口位置x坐标用于上下翻页光标计算
  double recordWindowX = 0;

  ///记录光标的窗口位置y坐标用于上下翻页光标计算
  double recordWindowY = 0;

  void updateCursorPosition(CursorPosition cursorPosition) {
    if (cursorPositionStack.isNotEmpty) {
      if (cursorPositionStack.last == cursorPosition) {
        cursorPositionStack.removeLast();
      }
    }
    cursorPositionStack.addLast(cursorPosition.copy);
    if (cursorPositionStack.length > saveSize) {
      cursorPositionStack.removeFirst();
    }
  }

  void updateCursorWindowPosition(
      CursorPosition cursorPosition, double scrollOffset) {
    recordWindowX = cursorPosition.rect?.center.dx ?? recordWindowX;
    recordWindowY = ((cursorPosition.rect?.center.dy ?? 0) +
        (cursorPosition.block?.top ?? 0)) -
        scrollOffset;
  }
}


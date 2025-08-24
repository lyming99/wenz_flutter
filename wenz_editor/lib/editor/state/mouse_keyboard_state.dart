import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MouseKeyboardState {
  int saveSize = 10;
  Queue<PointerHoverEvent> mouseHoverEvent = Queue();
  Queue<PointerDownEvent> mouseDownEvent1 = Queue();
  Queue<PointerMoveEvent> mouseMoveEvent1 = Queue();
  Queue<PointerEvent> mouseDownEvent2 = Queue();
  Queue<PointerEvent> mouseMoveEvent2 = Queue();
  Queue<PointerEvent> mouseUpEvent = Queue();
  Queue<KeyEvent> keyEvent = Queue();
  Queue<int> wheelScrollTime = Queue();
  Queue<double> wheelScrollDelta = Queue();
  bool mouseLeftDown = false;
  int mouseDownTime = 0;
  int mouseClickTime = 0;
  Offset? mouseDownOffset;
  Offset? mouseClickPosition;
  bool mouseDrag = false;
  double mouseClickCount = 0;
  bool enter = true;

  double mouseScrollSpeedX = 0;
  double mouseScrollSpeedY = 0;
  Timer? mouseScrollTimer;

  void clearHoverEvent(){
    mouseHoverEvent.clear();
  }

  bool equalDirection(double a, double b) {
    if (a <= 0 && b <= 0) {
      return true;
    }
    if (a >= 0 && b >= 0) {
      return true;
    }
    return false;
  }

  void onMouseEvent(PointerEvent event) {
    if (event is PointerExitEvent) {
      enter = false;
    }
    if (event is PointerEnterEvent) {
      enter = true;
    }
    event = event.copyWith();
    if (event.buttons == 1) {
      if (event is PointerDownEvent) {
        mouseDownEvent1.addLast(event);
      } else if (event is PointerMoveEvent) {
        mouseMoveEvent1.addLast(event);
      }
    } else if (event.buttons == 2) {
      if (event is PointerDownEvent) {
        mouseDownEvent2.addLast(event);
      } else if (event is PointerMoveEvent) {
        mouseMoveEvent2.addLast(event);
      }
    }
    if (event is PointerHoverEvent) {
      mouseHoverEvent.addLast(event);
    }
    if (mouseDownEvent1.length > saveSize) {
      mouseDownEvent1.removeFirst();
    }
    if (mouseDownEvent2.length > saveSize) {
      mouseDownEvent2.removeFirst();
    }
    if (event is PointerUpEvent) {
      mouseUpEvent.addLast(event);
    }
    if (mouseMoveEvent1.length > saveSize) {
      mouseMoveEvent1.removeFirst();
    }
    if (mouseMoveEvent2.length > saveSize) {
      mouseMoveEvent2.removeFirst();
    }
    if (mouseUpEvent.length > saveSize) {
      mouseUpEvent.removeFirst();
    }
    if (mouseHoverEvent.length > saveSize) {
      mouseHoverEvent.removeFirst();
    }
  }

  void onKeyEvent(FocusNode node, KeyEvent event) {
    keyEvent.addLast(event);
    if (keyEvent.length > saveSize) {
      keyEvent.removeFirst();
    }
  }

  void stopMouseScrollTimer() {
    mouseScrollTimer?.cancel();
    mouseScrollTimer = null;
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wenz_editor/editor/edit_controller.dart';
import 'package:wenz_editor/editor/utils/table_utils.dart';

const _handleKeyEvents = [
  LogicalKeyboardKey.backspace,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.pageDown,
  LogicalKeyboardKey.home,
  LogicalKeyboardKey.end,
  LogicalKeyboardKey.delete,
  LogicalKeyboardKey.numpadEnter,
];

class HotKeyUtils {
  HotKeyUtils._();

  static KeyEventResult onKeyEvent(
      FocusNode node, KeyEvent event, WenzEditController controller) {
    var isControl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    var isShift = HardwareKeyboard.instance.isShiftPressed;
    var isAlt = HardwareKeyboard.instance.isAltPressed;
    var len = controller.inputManager.composing?.text.length;
    if (len != null && len != 0) {
      return KeyEventResult.skipRemainingHandlers;
    }
    if (!controller.focusNode.hasFocus) {
      return KeyEventResult.ignored;
    }
    controller.mouseKeyboardState.onKeyEvent(node, event);
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // tab键
      if (event.physicalKey == PhysicalKeyboardKey.tab) {
        if (HardwareKeyboard.instance.isShiftPressed) {
          controller.removeIndent();
        } else {
          controller.addIndent();
        }
        return KeyEventResult.handled;
      }
      if (event.physicalKey == PhysicalKeyboardKey.keyA) {
        if (isControl) {
          controller.selectAll();
          return KeyEventResult.handled;
        }
      }
      if (event.physicalKey == PhysicalKeyboardKey.pageDown) {
        //下一页
        controller.toPageDown();
        return KeyEventResult.handled;
      }
      if (event.physicalKey == PhysicalKeyboardKey.pageUp) {
        //上一页
        controller.toPageUp();
        return KeyEventResult.handled;
      }

      if (event.physicalKey == PhysicalKeyboardKey.home) {
        //home
        controller.toHome();
        return KeyEventResult.handled;
      }
      if (event.physicalKey == PhysicalKeyboardKey.end) {
        //end
        controller.toEnd();
        return KeyEventResult.handled;
      }
      if (event.physicalKey == PhysicalKeyboardKey.arrowLeft) {
        //left
        controller.toLeft();
        return KeyEventResult.handled;
      }
      if (event.physicalKey == PhysicalKeyboardKey.arrowRight) {
        //right
        controller.toRight();
        return KeyEventResult.handled;
      }
      if (event.physicalKey == PhysicalKeyboardKey.arrowUp) {
        //up
        controller.toUp();
        return KeyEventResult.handled;
      }
      if (event.physicalKey == PhysicalKeyboardKey.arrowDown) {
        //down
        controller.toDown();
        return KeyEventResult.handled;
      }
      if (event.physicalKey == PhysicalKeyboardKey.backspace ||
          event.physicalKey == PhysicalKeyboardKey.delete) {
        controller.delete(event.physicalKey == PhysicalKeyboardKey.backspace);
        controller.record();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        controller.delete(true);
        controller.record();
        return KeyEventResult.handled;
      }
      if (event.physicalKey == PhysicalKeyboardKey.enter ||
          event.physicalKey == PhysicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        if (isControl) {
          if (isShift) {
            controller.addTextBlockBefore();
          } else {
            controller.addTextBlock();
          }
        } else {
          controller.enter();
        }
        controller.record();
        WidgetsBinding.instance.scheduleFrameCallback((timeStamp) {
          controller.refreshCursorPosition();
        });
        return KeyEventResult.handled;
      }

      if (event.physicalKey == PhysicalKeyboardKey.keyC && (isControl)) {
        controller.copySelect(copyText: isAlt);
        return KeyEventResult.handled;
      }
      if (event.physicalKey == PhysicalKeyboardKey.keyX && (isControl)) {
        controller.cut();
        return KeyEventResult.handled;
      }
      if (event.physicalKey == PhysicalKeyboardKey.keyV && (isControl)) {
        controller.paste();
        return KeyEventResult.handled;
      }

      if ((event.physicalKey == PhysicalKeyboardKey.numpad1 ||
              event.physicalKey == PhysicalKeyboardKey.digit1) &&
          (isControl)) {
        controller.setTextLevel(1);
        controller.record();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.numpad2 ||
              event.physicalKey == PhysicalKeyboardKey.digit2) &&
          (isControl)) {
        controller.setTextLevel(2);
        controller.record();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.numpad3 ||
              event.physicalKey == PhysicalKeyboardKey.digit3) &&
          (isControl)) {
        controller.setTextLevel(3);
        controller.record();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.numpad4 ||
              event.physicalKey == PhysicalKeyboardKey.digit4) &&
          (isControl)) {
        controller.setTextLevel(4);
        controller.record();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.numpad5 ||
              event.physicalKey == PhysicalKeyboardKey.digit5) &&
          (isControl)) {
        controller.setTextLevel(5);
        controller.record();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.numpad6 ||
              event.physicalKey == PhysicalKeyboardKey.digit6) &&
          (isControl)) {
        controller.setTextLevel(6);
        controller.record();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.numpad7 ||
              event.physicalKey == PhysicalKeyboardKey.digit7) &&
          (isControl)) {
        controller.setTextLevel(0);
        controller.record();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.numpad8 ||
              event.physicalKey == PhysicalKeyboardKey.digit8) &&
          (isControl)) {
        controller.changeTextToQuote();
        controller.record();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.numpad9 ||
              event.physicalKey == PhysicalKeyboardKey.digit9) &&
          (isControl)) {
        controller.addFormula();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.numpad0 ||
              event.physicalKey == PhysicalKeyboardKey.keyT) &&
          (isControl) &&
          isShift) {
        TableUtils.showAddTableDialog(controller);
        return KeyEventResult.handled;
      }

      if ((event.physicalKey == PhysicalKeyboardKey.keyZ) && (isControl)) {
        controller.undo();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.keyY) && (isControl)) {
        controller.redo();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.keyK) &&
          (isControl) &&
          isAlt) {
        controller.toggleCode();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.keyL) &&
          (isControl) &&
          isShift) {
        controller.addLink();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.keyI) && (isControl)) {
        controller.setItemType();
        return KeyEventResult.handled;
      }
      if ((event.physicalKey == PhysicalKeyboardKey.keyT) && (isControl)) {
        controller.setItemType(itemType: "check");
        return KeyEventResult.handled;
      }
    }
    if (_handleKeyEvents.contains(event.physicalKey)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef InputCallback = Function(
    TextEditingValue value, TextRange? replaceRange);
typedef InputComposingCallback = Function(TextEditingValue value);
typedef InputStartCallback = Function(TextEditingValue value);
typedef ActionCallback = Function(TextInputAction action);

class InputManager with TextInputClient, DeltaTextInputClient {
  InputManager({
    this.inputCallback,
    this.inputComposingCallback,
    this.actionCallback,
    this.onDelete,
  });

  TextEditingValue? composing;
  InputComposingCallback? inputComposingCallback;
  InputStartCallback? inputStartCallback;
  InputCallback? inputCallback;
  TextInputConnection? connection;
  TextEditingValue? textEditingValue;
  ActionCallback? actionCallback;
  Function? onDelete;

  bool get isOpen {
    return connection?.attached == true;
  }

  bool get hasComposing => composing != null && composing!.text.isNotEmpty;

  void openInputMethod() {
    var conn = connection;
    if (conn != null && conn.attached) {
      conn.show();
      fillIosContent();
      return;
    }
    connection?.close();
    connection = TextInput.attach(
      this,
      TextInputConfiguration(
        autocorrect: false,
        viewId: WidgetsBinding.instance.window.viewId,
        smartDashesType: SmartDashesType.disabled,
        inputAction: TextInputAction.newline,
        enableDeltaModel: kIsWeb ? false : (Platform.isAndroid || Platform.isIOS
            ? true
            : false),
      ),
    )
      ..setEditingState(const TextEditingValue());
    connection!.show();
    fillIosContent();
  }

  void closeInputMethod() {
    connection?.close();
    connection = null;
  }

  @override
  void connectionClosed() {
    connection = null;
  }

  @override
  AutofillScope? get currentAutofillScope {
    return null;
  }

  @override
  TextEditingValue? get currentTextEditingValue {
    return textEditingValue;
  }

  @override
  void performAction(TextInputAction action) {
    actionCallback?.call(action);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    print('action:$action');
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void updateEditingValue(TextEditingValue value) {
    if (!value.composing.isValid) {
      if (value.text.isNotEmpty) {
        inputCallback?.call(value, null);
        connection?.setEditingState(const TextEditingValue());
      } else {
        inputStartCallback?.call(value);
      }
    } else {
      inputComposingCallback?.call(value);
    }
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  void updateInputPosition(Size editableSize, Rect? caretRect,
      Rect? composingRect) {
    if (caretRect != null && composingRect != null) {
      Offset? offset = _snapToPhysicalPixel(caretRect.topLeft);
      if (offset != null) {
        connection?.setCaretRect(caretRect.shift(offset));
        connection?.setComposingRect(composingRect.shift(offset));
      }
      Matrix4? to = getTransformTo();
      if (to != null) {
        connection?.setEditableSizeAndTransform(editableSize, to);
      }
      if (connection?.attached == true) {
        connection?.show();
      }
    }
  }

  BuildContext? context;

  Matrix4? getTransformTo() {
    var render = context?.findRenderObject();
    if (render is RenderBox) {
      return render.getTransformTo(null);
    }
    return null;
  }

  Offset? _snapToPhysicalPixel(Offset sourceOffset) {
    var context = this.context;
    if (context == null) {
      return null;
    }
    var render = context.findRenderObject();
    if (render is RenderBox) {
      final Offset globalOffset = render.localToGlobal(sourceOffset);
      final double pixelMultiple =
          1.0 / MediaQuery
              .of(context)
              .devicePixelRatio;
      var ret = Offset(
        globalOffset.dx.isFinite
            ? (globalOffset.dx / pixelMultiple).round() * pixelMultiple -
            globalOffset.dx
            : 0,
        globalOffset.dy.isFinite
            ? (globalOffset.dy / pixelMultiple).round() * pixelMultiple -
            globalOffset.dy
            : 0,
      );
      return ret;
    }
    return null;
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    for (var delta in textEditingDeltas) {
      if (delta is TextEditingDeltaReplacement) {
        inputCallback?.call(
          TextEditingValue(
            text: delta.replacementText,
            composing: delta.composing,
            selection: delta.selection,
          ),
          delta.replacedRange,
        );
      }
      if (delta is TextEditingDeltaInsertion) {
        inputCallback?.call(
            TextEditingValue(
              text: delta.textInserted,
              composing: delta.composing,
              selection: delta.selection,
            ),
            null);
        if (!kIsWeb&&Platform.isIOS) {
          if (delta.composing.isValid) {
            return;
          }
        }
      }
      if (delta is TextEditingDeltaDeletion) {
        if (!kIsWeb&&Platform.isIOS) {
          onDelete?.call();
        }
      }
    }
    fillIosContent();
  }

  void fillIosContent() {
    if (!kIsWeb&&Platform.isIOS) {
      connection?.setEditingState(TextEditingValue(
          text: "-", selection: TextSelection.collapsed(offset: 1)));
    }
  }
}

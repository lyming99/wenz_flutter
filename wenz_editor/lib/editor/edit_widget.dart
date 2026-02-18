import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:wenz_editor/commons/widget/ignore_parent_pointer.dart';
import 'package:wenz_editor/editor/edit_controller.dart';
import 'package:wenz_editor/editor/theme/theme.dart';
import 'package:wenz_editor/editor/utils/menu_utils.dart';
import 'package:wenz_editor/editor/widget/modal_widget.dart';

import 'block/code/colors.dart';
import 'edit_content_widget.dart';

class WenzEditWidget extends StatefulWidget {
  final WenzEditController controller;
  final EditTheme? editTheme;
  final TextStyle? textStyle;
  final String? hintText;

  final PreferredSizeWidget? topWidget;

  final ValueChanged<bool>? onFocusChanged;

  const WenzEditWidget({
    super.key,
    required this.controller,
    this.editTheme,
    this.textStyle,
    this.topWidget,
    this.onFocusChanged,
    this.hintText,
  });

  @override
  State<WenzEditWidget> createState() => WenzEditState();
}

class WenzEditState extends State<WenzEditWidget> {
  bool dropOver = false;
  TextStyle? textStyle;

  static WenzEditState of(BuildContext context) {
    return context.findRootAncestorStateOfType<WenzEditState>()!;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.editTheme?.textStyle != textStyle) {
      textStyle = widget.editTheme?.textStyle;
      widget.controller.relayout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnoreParentMousePointerContainer(
      child: Builder(builder: (context) {
        var editTheme = EditTheme.of(context);
        return ModalContainer(
          controller: widget.controller.modalController,
          child: Material(
            color: Colors.transparent,
            textStyle: TextStyle(
              fontSize: editTheme.fontSize,
              color: editTheme.fontColor,
            ),
            child: DropRegion(
              formats: Formats.standardFormats,
              hitTestBehavior: HitTestBehavior.opaque,
              onDropOver: (event) {
                widget.controller.onDragIn(event);
                if (event.session.allowedOperations
                    .contains(DropOperation.copy)) {
                  return DropOperation.copy;
                } else {
                  return DropOperation.none;
                }
              },
              onDropEnter: (event) {
                setState(() {
                  dropOver = true;
                });
              },
              onDropLeave: (event) {
                setState(() {
                  dropOver = false;
                });
              },
              onDropEnded: (event) {
                setState(() {
                  dropOver = false;
                });
              },
              onPerformDrop: (event) async {
                await widget.controller.performDragIn(event);
              },
              child: Listener(
                onPointerDown: (event) {
                  if (event.buttons == 2) {
                    MenuUtils.showContextMenu(widget.controller, event.localPosition);
                  }
                },
                child: Stack(
                  children: [
                    widget.controller.editable
                        ? MouseRegion(
                            cursor: MaterialStateMouseCursor.textable,
                            child: buildScrollable(),
                          )
                        : buildScrollable(),
                    if (dropOver)
                      Container(
                        color: Colors.black.withOpacity(0.2),
                      ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ListenableBuilder(
                        builder: (context, child) {
                          if (!widget.controller.showTextLength) {
                            return Container();
                          }
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "字数统计: ${widget.controller.textLength}",
                              style: TextStyle(
                                color:
                                    systemColor(context, "textLengthColor"),
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                        listenable: widget.controller,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget buildScrollable() {
    return IgnoreParentPointer(
      ignorePointer: (box, offset) {
        var extend =
            widget.controller.scrollController?.position.maxScrollExtent;
        if (extend == 0) {
          return false;
        }
        var g = box.localToGlobal(Offset(box.size.width, box.size.height));
        if (offset.dx > g.dx - 14 && offset.dx < g.dx) {
          return true;
        }
        return false;
      },
      child: ControlButtonListener(builder: (context, isControl) {
        return Scrollable(
            physics: isControl
                ? const NeverScrollableScrollPhysics()
                : EditScrollPhysics(editController: widget.controller),
            controller: widget.controller.scrollController,
            viewportBuilder: (context, viewportOffset) {
              return EditContentWidget(
                topWidget: widget.topWidget,
                controller: widget.controller,
                viewportOffset: viewportOffset,
                onFocusChanged: widget.onFocusChanged,
                hintText: widget.hintText,
              );
            });
      }),
    );
  }

  void updateState() {
    setState(() {});
  }
}

class EditScrollPhysics extends BouncingScrollPhysics {
  final WenzEditController editController;

  const EditScrollPhysics({
    required this.editController,
    super.decelerationRate = ScrollDecelerationRate.normal,
    super.parent,
  });

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (editController.isFloatWidgetDragging) {
      return 0.0;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  BouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return EditScrollPhysics(
        editController: editController,
        parent: buildParent(ancestor),
        decelerationRate: decelerationRate);
  }

  @override
  bool get allowImplicitScrolling => !editController.isFloatWidgetDragging;

  @override
  bool get allowUserScrolling => !editController.isFloatWidgetDragging;
}

class ControlButtonListener extends StatefulWidget {
  final Widget Function(BuildContext context, bool isCtrlPressed) builder;

  const ControlButtonListener({super.key, required this.builder});

  @override
  State<ControlButtonListener> createState() => _ControlButtonListenerState();
}

class _ControlButtonListenerState extends State<ControlButtonListener> {
  bool _isCtrlPressed = false;

  @override
  void initState() {
    super.initState();
    // 添加全局键盘监听器
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    // 移除全局键盘监听器
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
          event.logicalKey == LogicalKeyboardKey.controlRight ||
          event.logicalKey == LogicalKeyboardKey.control) {
        setState(() {
          _isCtrlPressed = true;
        });
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
          event.logicalKey == LogicalKeyboardKey.controlRight ||
          event.logicalKey == LogicalKeyboardKey.control) {
        setState(() {
          _isCtrlPressed = false;
        });
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder.call(context, _isCtrlPressed);
  }
}

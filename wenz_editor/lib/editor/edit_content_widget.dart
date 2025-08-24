import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:wenz_editor/commons/widget/popup_stack.dart';
import 'package:wenz_editor/editor/edit_controller.dart';
import 'package:wenz_editor/editor/mouse/mouse.dart';
import 'package:wenz_editor/editor/utils/hotkey_utils.dart';
import 'package:wenz_editor/editor/utils/popup_utils.dart';

import 'listener/edit_content_height_notification.dart';
import 'widget/single_widget.dart';

class EditContentWidget extends StatefulWidget {
  final WenzEditController controller;
  final ViewportOffset viewportOffset;
  final PreferredSizeWidget? topWidget;
  final ValueChanged<bool>? onFocusChanged;

  const EditContentWidget({
    super.key,
    this.topWidget,
    required this.controller,
    required this.viewportOffset,
    this.onFocusChanged,
  });

  @override
  State<EditContentWidget> createState() => EditContentWidgetState();
}

class EditContentWidgetState extends State<EditContentWidget> {
  static EditContentWidgetState of(BuildContext context) {
    return context.findRootAncestorStateOfType<EditContentWidgetState>()!;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.topWidget = widget.topWidget;
    widget.controller.onWidgetInitState(this);
    widget.viewportOffset.addListener(updateState);
  }

  void updateState() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.viewportOffset.removeListener(updateState);
    widget.controller.onWidgetDispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EditContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.onWidgetDispose();
      widget.controller.onWidgetInitState(this);
    }
    oldWidget.viewportOffset.removeListener(updateState);
    widget.viewportOffset.addListener(updateState);
    widget.controller.topWidget = widget.topWidget;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.topWidget = widget.topWidget;
  }

  @override
  Widget build(BuildContext context) {
    widget.controller.viewContext = context;
    return LayoutBuilder(
      builder: (context, constraints) {
        try {
          double maxWidth =
              min(widget.controller.maxEditWidth, constraints.maxWidth);
          var blockConstrains = constraints.copyWith(maxWidth: maxWidth);
          widget.controller
              .onLayoutBuild(context, constraints, blockConstrains);
          widget.viewportOffset.applyViewportDimension(constraints.maxHeight);
          var maxExtend = max(0.0,
              widget.controller.getContentHeight() - constraints.maxHeight);
          widget.viewportOffset.applyContentDimensions(0, maxExtend);
          // 通知卡片高度更新，以便列表更新卡片高度
          EditContentHeightNotification(widget.controller.getContentHeight())
              .dispatch(context);
          //显示blockWidgets
          var blockWidgets = widget.controller
              .buildContentBlocksWidget(context, constraints, blockConstrains);
          //计算滚动最大位置
          var cursorWidget = widget.controller.buildCursorWidget();
          if (cursorWidget != null) {
            blockWidgets.add(cursorWidget);
          }
          var contentWidgets = <Widget>[];
          if (widget.controller.blockManager.isEmpty) {
            contentWidgets.add(
              Positioned(
                left: widget.controller.padding.left,
                right: widget.controller.padding.right,
                top: widget.controller.padding.top,
                height: 32,
                child: Text(
                  "请输入内容",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(context).hintColor),
                ),
              ),
            );
          }
          var singleWidgets = <Widget>[];
          var topWidget = widget.controller.topWidget;
          if (topWidget != null) {
            singleWidgets.add(
              Positioned(
                left: widget.controller.padding.left,
                right: widget.controller.padding.right,
                top: widget.controller.padding.top -
                    topWidget.preferredSize.height -
                    widget.viewportOffset.pixels,
                height: topWidget.preferredSize.height,
                child: topWidget,
              ),
            );
          }
          for (var widget in blockWidgets) {
            if (widget is SingleWidget) {
              singleWidgets.add(widget);
            } else {
              contentWidgets.add(widget);
            }
          }
          var floatWidgetXOffset =
              (constraints.maxWidth - blockConstrains.maxWidth) / 2;
          widget.controller.floatWidgetXOffset = floatWidgetXOffset;
          List<PopupPositionWidget> floatWidgets =
              PopupUtils.translatePopupPositionWidget(
                  widget.controller.buildFloatWidgets(context),
                  floatWidgetXOffset,
                  0.0);
          var backgroundWidgets = PopupUtils.translatePopupPositionWidget(
              widget.controller.buildBackgroundWidgets(context),
              floatWidgetXOffset,
              0.0);
          return PopupStack(
            children: [
              //block背景渲染
              ...backgroundWidgets,
              //镶嵌的block
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: blockConstrains.maxWidth,
                  height: blockConstrains.maxHeight,
                  child: Focus(
                    focusNode: widget.controller.focusNode,
                    autofocus: widget.controller.initFocus,
                    onFocusChange: (focus) {
                      widget.onFocusChanged?.call(focus);
                      widget.controller.onFocusChanged(focus);
                    },
                    onKeyEvent: (node, event) {
                      var result = HotKeyUtils.onKeyEvent(
                          node, event, widget.controller);
                      if (widget.controller.inputManager.hasComposing) {
                        return KeyEventResult.skipRemainingHandlers;
                      }
                      return result;
                    },
                    child: GestureDetector(
                      onLongPress: () {
                        HapticFeedback.selectionClick();
                        var eventQueue = widget
                            .controller.mouseKeyboardState.mouseDownEvent1;
                        if (eventQueue.isNotEmpty) {
                          widget.controller
                              .selectWord(eventQueue.last.localPosition);
                        }
                      },
                      child: MouseEventListenerWidget(
                        eventListener: (event, entry) {
                          widget.controller.onMouseEvent(event.copyWith(
                            position: event.position,
                          ));
                        },
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: blockConstrains.maxWidth,
                          height: blockConstrains.maxHeight,
                          child: Stack(
                            children: contentWidgets,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              //独立控制事件的block
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: blockConstrains.maxWidth,
                  height: blockConstrains.maxHeight,
                  child: Stack(
                    children: singleWidgets,
                  ),
                ),
              ),
              //悬浮控件
              ...floatWidgets,
            ],
          );
        } finally {}
      },
    );
  }
}

class DeleteAction extends Action<DeleteCharacterIntent> {
  WenzEditController controller;

  DeleteAction(this.controller);

  @override
  Object? invoke(Intent intent) {
    controller.delete(false);
    return null;
  }
}

// ignore_for_file: use_build_context_synchronously, empty_catches

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:future_progress_dialog/future_progress_dialog.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart' as image_size;
import 'package:pasteboard/pasteboard.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:wenz_editor/commons/service/copy_service.dart';
import 'package:wenz_editor/commons/service/file_manager.dart';
import 'package:wenz_editor/commons/util/file_utils.dart';
import 'package:wenz_editor/commons/util/html/html.dart';
import 'package:wenz_editor/commons/util/image.dart';
import 'package:wenz_editor/commons/util/markdown/markdown.dart';
import 'package:wenz_editor/commons/util/platform_util.dart';
import 'package:wenz_editor/commons/widget/popup_stack.dart';
import 'package:wenz_editor/editor/block/code/code.dart';
import 'package:wenz_editor/editor/block/image/image_block.dart';
import 'package:wenz_editor/editor/block/line/line_block.dart';
import 'package:wenz_editor/editor/block/line/line_element.dart';
import 'package:wenz_editor/editor/block/text/title.dart';
import 'package:wenz_editor/editor/theme/theme.dart';
import 'package:wenz_editor/editor/utils/copy_utils.dart';
import 'package:wenz_editor/editor/utils/link_utils.dart';
import 'package:wenz_editor/editor/widget/formula_dialog.dart';
import 'package:wenz_editor/editor/widget/modal_widget.dart';

import 'block/block.dart';
import 'block/block_manager.dart';
import 'block/element/element.dart';
import 'block/image/image_element.dart';
import 'block/table/table_block.dart';
import 'block/table/table_cell.dart';
import 'block/table/table_element.dart';
import 'block/text/hide_text_mode.dart';
import 'block/text/text.dart';
import 'cursor/cursor.dart';
import 'cursor/cursor_record.dart';
import 'edit_float_widget.dart';
import 'edit_widget.dart';
import 'event/manager.dart';
import 'input/input_manager.dart';
import 'link/link_float_builder.dart';
import 'listener/select_drag_listener.dart';
import 'popup_tool.dart';
import 'state/mouse_keyboard_state.dart';
import 'state/search_state.dart';
import 'state/select_state.dart';
import 'utils/text_utils.dart';
import 'widget/single_widget.dart';

typedef EditWriter = Future Function(List content);

typedef EditReader = Future<List> Function();

class WenzEditController with ChangeNotifier {
  late BuildContext viewContext;
  late EventManager eventManager;
  late BlockManager blockManager;
  late CursorState cursorState;
  late InputManager inputManager;
  late SelectState selectState;
  late MouseKeyboardState mouseKeyboardState;
  late CursorRecord cursorRecord;
  late FocusNode focusNode;
  late SearchState searchState;
  late WenPopupTool popupTool;
  LinkFloatBuilder? linkFloatBuilder;
  PreferredSizeWidget? topWidget;
  CopyService copyService;
  WenzFileManager fileManager;
  Function? onContentChanged;
  ModalController modalController = ModalController();

  bool showHeadList = false;
  EditReader? reader;
  EditWriter? writer;
  EdgeInsets _padding = EdgeInsets.zero;
  State? state;
  bool initFocus = false;
  bool editable = true;
  bool showTextLength = false;
  bool rightMenuShowing = false;
  PointerEvent? rightMenuEvent;
  int? initBlockIndex;
  int? initTextOffset;

  //可视宽度
  double visionWidth = 0;

  //可视高度
  double visionHeight = 0;

  //居中后的offset
  Offset visionOffset = Offset.zero;
  ScrollController? scrollController;
  bool isFloatWidgetDragging = false;

  //挖空
  List<HideTextMode>? hideTextModes;
  double floatWidgetXOffset = 0;
  double maxEditWidth = double.infinity;

  int get textLength => blockManager.textLength;

  void updateOriginPadding(EdgeInsets padding) {
    _padding = padding;
    notifyListeners();
  }

  EdgeInsets get originPadding => _padding;

  EdgeInsets get padding =>
      _padding.copyWith(
          top: _padding.top + (topWidget?.preferredSize.height ?? 0));

  static WenzEditController of(BuildContext context) {
    var widget = context.widget;
    if (widget is WenzEditWidget) {
      return widget.controller;
    }
    return context.findAncestorWidgetOfExactType<WenzEditWidget>()!.controller;
  }

  WenzEditController({
    this.reader,
    this.onContentChanged,
    this.writer,
    this.initFocus = false,
    this.editable = true,
    this.linkFloatBuilder,
    this.hideTextModes,
    EdgeInsets padding = EdgeInsets.zero,
    this.initBlockIndex,
    this.initTextOffset,
    this.scrollController,
    this.maxEditWidth = double.infinity,
    this.showTextLength = false,
    required this.fileManager,
    required this.copyService,
  }) {
    popupTool = WenPopupTool(controller: this);
    scrollController ??= ScrollController();
    eventManager = EventManager();
    blockManager = BlockManager();
    cursorState = CursorState();
    inputManager = InputManager(
      inputCallback: onSystemInputText,
      inputComposingCallback: onInputComposing,
      actionCallback: onInputAction,
      onDelete: () {
        delete(true);
      },
    );
    selectState = SelectState(
      editController: this,
    );
    focusNode = FocusNode();
    mouseKeyboardState = MouseKeyboardState();
    cursorRecord = CursorRecord();
    searchState = SearchState();
    _padding = padding;
  }

  EditTheme get editTheme {
    return EditTheme.of(viewContext);
  }

  double get blockMaxWidth => visionWidth - padding.horizontal;

  double get scrollOffset {
    if (scrollController?.positions.isEmpty == true) {
      return 0;
    }
    try {
      return scrollController?.offset ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> readContent(BuildContext context,
      {bool initContent = false}) async {
    var content = await reader?.call();
    blockManager.changeStack.reset(content ?? []);
    blockManager.parseContent(context, this);
    blockManager.onContentChanged(this);
    _restoreAllCursorPosition();
    //通知界面更新
    eventManager.emit(EventType.contentChanged);

    if (initContent) {
      var blockIndex = initBlockIndex;
      var textOffset = initTextOffset;
      if (blockIndex != null && textOffset != null) {
        gotoPosition(blockIndex, textOffset);
      }
    }
    updateWidgetState();
    notifyListeners();
  }

  Future<void> reset(List content) async {
    blockManager.changeStack.reset(content);
    blockManager.parseContent(viewContext, this);
    blockManager.onContentChanged(this);
  }

  /// 恢复光标、选择位置
  void _restoreAllCursorPosition() {
    _restoreCursorPosition(cursorState.cursorPosition);
    _restoreCursorPosition(cursorState.hoverPosition);
    _restoreCursorPosition(selectState.start);
    _restoreCursorPosition(selectState.end);
  }

  /// 恢复光标位置
  void _restoreCursorPosition(CursorPosition? cursorPosition) {
    if (cursorPosition == null) {
      return;
    }
    var blockIndex = cursorPosition.blockIndex;
    if (blockIndex == null) {
      return;
    }
    var textPosition = cursorPosition.textPosition;
    if (textPosition == null) {
      return;
    }
    if (blockIndex < blockManager.blocks.length) {
      var block = cursorPosition.block = blockManager.blocks[blockIndex];
      cursorPosition.rect = block.getCursorRect(textPosition);
    }
  }

  /// 跳转
  void gotoPosition(int blockIndex, int textOffset) {
    waitLayout(() {
      if (blockIndex < blockManager.blocks.length) {
        blockManager.layoutPreviousBlockWithHeight(viewContext,
            Size(visionWidth, visionHeight), blockIndex, visionWidth);
        var block = blockManager.blocks[blockIndex];
        scrollToBlock(block);
        toPosition(
            block.getCursorPosition(TextPosition(offset: textOffset)), true);
      }
    });
  }

  /// 等待布局完成
  void waitLayout(Function call, {int waitCount = 100}) {
    if (visionWidth > 0 && visionHeight > 0) {
      WidgetsBinding.instance.scheduleFrameCallback((timeStamp) {
        call.call();
      });
    } else {
      if (waitCount > 0) {
        WidgetsBinding.instance.scheduleFrameCallback((timeStamp) {
          waitLayout(call, waitCount: waitCount - 1);
        });
      }
    }
  }

  /// widget init state
  void onWidgetInitState(State state) {
    this.state = state;
    viewContext = state.context;
    eventManager.emit(EventType.initState);
    readContent(
      viewContext,
      initContent: true,
    );
    if (editable) {
      startCursorTimer();
    }
  }

  /// widget dispose
  void onWidgetDispose() {
    inputManager.closeInputMethod();
    eventManager.emit(EventType.disposed);
    stopCursorTimer();
  }

  /// 开始光标闪烁 timer
  void startCursorTimer() {
    cursorState.startCursorTimer(onFlushCursor);
  }

  /// 关闭光标闪烁 timer
  void stopCursorTimer() {
    cursorState.stopCursorTimer();
  }

  /// 刷新光标
  void onFlushCursor() {
    updateWidgetState();
  }

  int updateCount = 0;

  var focusNotifier = ValueNotifier(false);

  /// 更新 widget state
  void updateWidgetState() {
    try {
      state?.setState(() {});
    } catch (e) {}
  }

  /// 创建内容widget，背景绘制
  List<Widget> buildContentBlocksWidget(BuildContext context,
      BoxConstraints parentConstrains, BoxConstraints constrains) {
    viewContext = context;
    if (constrains.maxWidth < 0) {
      return [];
    }

    var blocks = blockManager.layout(
        context, scrollOffset, Size(blockMaxWidth, visionHeight), padding);
    var ret = <Widget>[];
    //构建搜索背景色(黄色)
    for (var block in blocks) {
      var ranges = block.searchRanges;
      if (ranges != null) {
        for (var selection in ranges) {
          var boxes = block.getBoxesForSelection(selection);
          for (var box in boxes) {
            var boxRect = box.toRect().translate(
                padding.left, block.top - scrollOffset + padding.top);
            //边界运算
            boxRect = Rect.fromLTWH(
                padding.left - 1,
                0,
                visionWidth + 2 - padding.left - padding.right,
                visionHeight)
                .intersect(boxRect);
            if (boxRect.width > 0 && boxRect.height > 0) {
              ret.add(Positioned(
                left: boxRect.left,
                top: boxRect.top,
                width: boxRect.width,
                height: boxRect.height,
                child: Container(
                  color: Colors.yellow,
                ),
              ));
            }
          }
        }
      }
    }
    //构建选择颜色
    var selectStart = selectState.realStart;
    var selectEnd = selectState.realEnd;
    for (var block in blocks) {
      block.selected = false;
    }
    if (selectStart != null &&
        selectEnd != null &&
        selectStart.isValid &&
        selectEnd.isValid) {
      var startBlock = selectStart.block!;
      var startPosition = selectStart.textPosition!;
      var endBlock = selectEnd.block!;
      var endPosition = selectEnd.textPosition!;
      if (startBlock.top > endBlock.top) {
        startBlock = selectEnd.block!;
        endBlock = selectStart.block!;
        startPosition = selectEnd.textPosition!;
        endPosition = selectStart.textPosition!;
      }
      //选择高亮
      for (var block in blocks) {
        //判断block的y是否在start block和end block之间
        if (block.top < startBlock.top || block.top > endBlock.top) continue;
        TextPosition drawStart, drawEnd;
        drawStart = block.startPosition;
        drawEnd = block.endPosition;
        if (block.top == startBlock.top) {
          drawStart = startPosition;
        }
        if (block.top == endBlock.top) {
          drawEnd = endPosition;
        }
        block.selected = true;
        block.selectedStart = drawStart;
        block.selectedEnd = drawEnd;
        //边界运算,在背景之后无需绘制
        var blockOffset = block.top - scrollOffset + padding.top;
        if (blockOffset + block.height < 0 || blockOffset > visionHeight) {
          continue;
        }
        var selection = TextSelection.fromPosition(drawStart).extendTo(drawEnd);
        var boxes = block.getBoxesForSelection(selection);
        for (var box in boxes) {
          var boxRect = box
              .toRect()
              .translate(padding.left, block.top - scrollOffset + padding.top);
          //边界运算
          boxRect = Rect.fromLTWH(padding.left - 1, 0,
              visionWidth + 2 - padding.left - padding.right, visionHeight)
              .intersect(boxRect);
          if (boxRect.width > 0 && boxRect.height > 0) {
            ret.add(Positioned(
              left: boxRect.left,
              top: boxRect.top,
              width: boxRect.width,
              height: boxRect.height,
              child: Container(
                color: Theme
                    .of(context)
                    .colorScheme
                    .primaryContainer,
              ),
            ));
          }
        }
      }
    }

    //构建block视图
    for (var block in blocks) {
      var pos = Positioned(
        key: ValueKey(block.hashCode),
        left: padding.left,
        top: block.top - scrollOffset + padding.top,
        width: max(0, constrains.maxWidth - padding.horizontal),
        height: block.height,
        child: constrains.maxWidth - padding.horizontal <= 0
            ? Container()
            : block.buildWidget(context),
      );
      if (block.isSingleBlock) {
        ret.add(SingleWidget(
          child: pos,
        ));
      } else {
        ret.add(pos);
      }
    }
    return ret;
  }

  Widget? buildCursorWidget() {
    if (editable == false) {
      return null;
    }
    if (!focusNode.hasFocus || (focusNode.hasFocus)) {
      var cursorPosition = cursorState.cursorPosition;
      if (cursorPosition == null) {
        return null;
      }
      var blockIndex = cursorPosition.blockIndex;
      var textPosition = cursorPosition.textPosition;
      if (blockIndex == null ||
          textPosition == null ||
          blockIndex >= blockManager.blocks.length) {
        return null;
      }
      var block = blockManager.blocks[blockIndex];
      var rect = block.getCursorRect(textPosition);
      if (rect == null) {
        return null;
      }
      double cursorY = block.top - scrollOffset;
      var cursorRect = rect.translate(padding.left, cursorY + padding.top);
      cursorRect = Rect.fromLTWH(padding.left - 1, 0,
          visionWidth + 2 - padding.left - padding.right, visionHeight)
          .intersect(cursorRect);
      return AnimatedPositioned(
        key: ValueKey(this),
        left: cursorRect.left,
        top: cursorRect.top,
        width: cursorRect.width,
        height: cursorRect.height,
        curve: Curves.linear,
        duration: const Duration(milliseconds: 30),
        child: AnimatedOpacity(
          opacity:
          !focusNode.hasFocus ? 0.2 : (cursorState.freshShowing ? 1 : 0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeIn,
          child: Container(
            color: EditTheme
                .of(viewContext)
                .cursorColor,
          ),
        ),
      );
    }
    return null;
  }

  void relayout() {
    for (var block in blockManager.blocks) {
      block.relayoutFlag = true;
    }
    blockManager.relayoutFlag = true;
    updateWidgetState();
  }

  /// 获取悬浮组件(check box,代码复制按钮,图片复制按钮等控件)
  List<PopupPositionWidget> buildFloatWidgets(BuildContext context) {
    var result = <PopupPositionWidget>[];
    for (var block in blockManager.layoutBlocks) {
      result.addAll(block.buildFloatWidgets());
    }
    result.addAll(LinkUtils.buildLinkFloatWidgets(this, true));
    result.addAll(buildDragSelectFloatWidgets());
    var tool = buildDesktopFloatToolWidget(context);
    if (tool != null) {
      result.add(tool);
    }
    result.sort((a, b) => a.layerIndex.compareTo(b.layerIndex));
    return result;
  }

  List<PopupPositionWidget> buildDragSelectFloatWidgets() {
    if (!isMobile) {
      return [];
    }
    if (!selectState.hasSelect) {
      return [];
    }
    var result = <PopupPositionWidget>[];
    var startCursorSelectWidget =
    buildCursorSelectWidget(selectState.realStart, true);
    var endCursorSelectWidget =
    buildCursorSelectWidget(selectState.realEnd, false);
    if (startCursorSelectWidget != null) {
      result.add(startCursorSelectWidget);
    }
    if (endCursorSelectWidget != null) {
      result.add(endCursorSelectWidget);
    }
    return result;
  }

  PopupPositionWidget? buildCursorSelectWidget(CursorPosition? position,
      bool isStartMode) {
    if (position == null) {
      return null;
    }
    var block = position.block;
    if (block == null) {
      return null;
    }
    var pos = position.textPosition;
    if (pos == null) {
      return null;
    }
    var rect = block.getCursorRect(pos);
    if (rect == null) {
      return null;
    }
    final cursorEventStart =
    rect.bottomCenter.translate(0, block.top - scrollOffset - 10);
    rect = rect.translate(
        padding.left, padding.top + block.top - scrollOffset + rect.height);
    if (isStartMode) {
      rect = rect.translate(-23, 0);
    } else {
      rect = rect.translate(1, 0);
    }
    return PopupPositionWidget(
      key: ValueKey("$hashCode-$isStartMode"),
      keepVision: false,
      layerIndex: 10,
      left: rect.left,
      top: rect.top,
      width: 24,
      height: 24,
      child: MouseRegion(
        cursor: MaterialStateMouseCursor.clickable,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            selectState.swapToRealSelect(this);
            isFloatWidgetDragging = true;
            selectState.dragCursorStartEvent = event;
            selectState.dragCursorStartPosition = cursorEventStart;
            selectState.isCursorDragging = true;
            SelectDragListener.emitChange(viewContext);
            WenzEditState.of(viewContext).updateState();
          },
          onPointerUp: (event) {
            selectState.isCursorDragging = false;
            isFloatWidgetDragging = false;
            WenzEditState.of(viewContext).updateState();
            mouseKeyboardState.stopMouseScrollTimer();
            SelectDragListener.emitChange(viewContext);
          },
          onPointerCancel: (event) {
            isFloatWidgetDragging = false;
            WenzEditState.of(viewContext).updateState();
            mouseKeyboardState.stopMouseScrollTimer();
            SelectDragListener.emitChange(viewContext);
          },
          onPointerMove: (event) {
            startMouseScrollTimer();
            calcMouseScrollSpeed(
                event.localPosition + Offset(rect?.left ?? 0, rect?.top ?? 0));
            var startEvent = selectState.dragCursorStartEvent;
            var startCursorPosition = selectState.dragCursorStartPosition;
            if (startEvent == null || startCursorPosition == null) {
              return;
            }
            var newCursorPosition = startCursorPosition +
                (event.localPosition - startEvent.localPosition);
            var newPosition = getCursorPosition(newCursorPosition);
            if (isStartMode) {
              //必须小于right
              var newBlockIndex = newPosition.blockIndex!;
              var endBlockIndex = selectState.realEnd!.blockIndex!;
              if (newBlockIndex < endBlockIndex) {
                if (selectState.start?.equalsCursorIndex(newPosition) != true) {
                  HapticFeedback.selectionClick();
                }
                selectState.start = newPosition;
                updateWidgetState();
              } else if (newBlockIndex == endBlockIndex) {
                var newTextIndex = newPosition.textPosition!.offset;
                var rightTextIndex = selectState.realEnd!.textPosition!.offset;
                if (newTextIndex <= rightTextIndex) {
                  if (selectState.start?.equalsCursorIndex(newPosition) !=
                      true) {
                    HapticFeedback.selectionClick();
                  }
                  selectState.start = newPosition;
                  updateWidgetState();
                }
              }
            } else {
              //必须大于于start
              var newBlockIndex = newPosition.blockIndex!;
              var startBlockIndex = selectState.realStart!.blockIndex!;
              if (newBlockIndex > startBlockIndex) {
                if (selectState.end?.equalsCursorIndex(newPosition) != true) {
                  HapticFeedback.selectionClick();
                }
                selectState.end = newPosition;
                updateWidgetState();
              } else if (newBlockIndex == startBlockIndex) {
                var newTextIndex = newPosition.textPosition!.offset;
                var leftTextIndex = selectState.realStart!.textPosition!.offset;
                if (newTextIndex >= leftTextIndex) {
                  if (selectState.end?.equalsCursorIndex(newPosition) != true) {
                    HapticFeedback.selectionClick();
                  }
                  selectState.end = newPosition;
                  updateWidgetState();
                }
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.8),
                borderRadius: BorderRadius.only(
                  topLeft:
                  isStartMode ? Radius.circular(24) : Radius.circular(0),
                  topRight:
                  isStartMode ? Radius.circular(0) : Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                )),
          ),
        ),
      ),
    );
  }

  bool get isMobile {
    if (kIsWeb) return false;
    return [
      TargetPlatform.iOS,
      TargetPlatform.android,
    ].contains(defaultTargetPlatform);
  }

  /// 获取悬浮组件(check box,代码复制按钮,图片复制按钮等控件)
  List<PopupPositionWidget> buildBackgroundWidgets(BuildContext context) {
    var result = <PopupPositionWidget>[];
    for (var block in blockManager.layoutBlocks) {
      result.addAll(block.buildBackgroundWidgets());
    }
    result.sort((a, b) => a.layerIndex.compareTo(b.layerIndex));
    return result;
  }

  Offset? getMousePosition() {
    var mousePosition = cursorState.mouseEventPosition;
    if (mouseKeyboardState.mouseHoverEvent.isNotEmpty) {
      var hoverLast = mouseKeyboardState.mouseHoverEvent.last;
      mousePosition = hoverLast.localPosition;
    }
    return mousePosition;
  }

  void updateWindowCursorRecordPosition() {
    var position = cursorState.cursorPosition;
    if (position == null) {
      return;
    }
    cursorRecord.updateCursorWindowPosition(position, scrollOffset);
  }

  ///鼠标事件
  void onMouseEvent(PointerEvent event) {
    var originEvent = event;
    event = originEvent.copyWith(
        position: event.position.translate(-padding.left, -padding.top));
    mouseKeyboardState.onMouseEvent(event);
    if (event is PointerDownEvent) {
      mouseKeyboardState.mouseDrag = false;
      //鼠标左键
      if (event.buttons == 1) {
        mouseKeyboardState.mouseLeftDown = true;
        mouseKeyboardState.mouseDownTime =
            DateTime
                .now()
                .millisecondsSinceEpoch;
        mouseKeyboardState.mouseDownOffset = event.localPosition;
        if (!isMobile) {
          var position = getCursorPosition(event.localPosition);
          //点击down事件：更新光标位置，记录选择开始位置
          if (selectState.shiftDown && cursorState.cursorPosition != null) {
            if (selectState.start == null) {
              recordSelectStart(cursorState.cursorPosition);
            }
            recordSelectEnd(position);
          } else {
            recordSelectStart(position);
          }
          cursorRecord.updateCursorWindowPosition(position, scrollOffset);
          updateCursor(position, applyUpdate: true);
        }
      }
    }
    if (event is PointerMoveEvent) {
      if (mouseKeyboardState.mouseDrag == false) {
        if (event.buttons == 1) {
          var distance =
              (event.localPosition - mouseKeyboardState.mouseDownOffset!)
                  .distance;
          if (distance > 2) {
            mouseKeyboardState.mouseDrag = true;
          }
        }
      } else {
        if (event.buttons == 1) {
          if (!isMobile) {
            startMouseScrollTimer();
            calcMouseScrollSpeed(event.localPosition);
          }
          cursorState.mouseEventPosition = event.localPosition;
          var position = getCursorPosition(event.localPosition);
          if ((false == isMobile) && position.isValid) {
            //鼠标滑动事件：更新cursor位置
            updateCursor(position, applyUpdate: true);
            recordSelectEnd(position);
            updateWidgetState();
          }
        }
      }
    }
    if (event is PointerUpEvent) {
      if (mouseKeyboardState.mouseLeftDown) {
        if (DateTime
            .now()
            .millisecondsSinceEpoch -
            mouseKeyboardState.mouseDownTime <
            300) {
          var dis = calcDistance(
              event.localPosition, mouseKeyboardState.mouseDownOffset);
          if (dis < 10) {
            //click
            if (calcDistance(mouseKeyboardState.mouseClickPosition,
                event.localPosition) <
                10 &&
                DateTime
                    .now()
                    .millisecondsSinceEpoch -
                    mouseKeyboardState.mouseClickTime <
                    300) {
              mouseKeyboardState.mouseClickCount++;
              if (mouseKeyboardState.mouseClickCount == 2) {
                onDoubleClick(event.localPosition);
              }
            } else {
              mouseKeyboardState.mouseClickCount = 1;
              onOneClick(event.localPosition);
            }
            mouseKeyboardState.mouseClickTime =
                DateTime
                    .now()
                    .millisecondsSinceEpoch;
            mouseKeyboardState.mouseClickPosition = event.localPosition;
          } else {
            mouseKeyboardState.mouseClickCount = 0;
            mouseKeyboardState.mouseClickTime = 0;
            mouseKeyboardState.mouseClickPosition = null;
          }
        }
        mouseKeyboardState.mouseDownTime = 0;
      }
      mouseKeyboardState.mouseLeftDown = false;
      mouseKeyboardState.stopMouseScrollTimer();
      if (!mouseKeyboardState.mouseDrag) {
        scrollToCursorPosition();
      }
      mouseKeyboardState.mouseDrag = false;
    }
    if (event is PointerHoverEvent ||
        event is PointerEnterEvent ||
        event is PointerExitEvent ||
        event is PointerMoveEvent) {
      updateHoverCursorPosition();
    }
  }

  ///计算2点的距离
  double calcDistance(Offset? a, Offset? b) {
    a = a ?? Offset.zero;
    b = b ?? Offset.zero;
    var dx = (a.dx) - (b.dx);
    var dy = (a.dy) - (b.dy);
    return sqrt(dy * dy + dx * dx);
  }

  ///双击选择词语
  void selectWord(Offset location) {
    //选择文字
    var cursor = getCursorPosition(location);
    if (cursor.isValid) {
      selectCursor(cursor);
    }
  }

  void selectCursor(CursorPosition cursorPosition) {
    var pos = cursorPosition.textPosition!;
    var block = cursorPosition.block!;
    var range = block.getWordBoundary(pos);
    if (range == null) {
      return;
    }
    var start = TextPosition(
      offset: range.start,
      affinity: TextAffinity.upstream,
    );
    var end = TextPosition(
      offset: range.end,
      affinity: TextAffinity.downstream,
    );
    recordSelectStart(CursorPosition(block: block, textPosition: start));
    updateCursor(
      CursorPosition(
          block: block, textPosition: end, rect: block.getCursorRect(end)),
      applyUpdate: true,
    );
    recordSelectEnd(CursorPosition(block: block, textPosition: end));
    updateWidgetState();
  }

  ///单击
  void onOneClick(Offset location) {
    //弹出输入法
    requestFocus();
    if (editable) {
      inputManager.composing = null;
      inputManager.closeInputMethod();
      inputManager.openInputMethod();
    }
    if (!selectState.shiftDown) {
      selectState.clearSelect();
    }
    var position = getCursorPosition(location);
    cursorRecord.updateCursorWindowPosition(position, scrollOffset);
    updateCursor(position, applyUpdate: true);
    visitSelectElement(
          (block, element) {
        if (block is TextBlock) {
          block.textElement.hideText = false;
        }
        if (element is WenTextElement) {
          element.hideText = false;
          block.relayoutFlag = true;
        }
      },
    );
    if (!selectState.shiftDown && position.isBottom == true) {
      if (!blockManager.lastIsText) {
        addTextBlock();
      }
    }
  }

  ///双击
  void onDoubleClick(Offset location) {
    selectWord(location);
  }

  ///三击
  void onTripleClick(Offset location) {}

  void calcMouseScrollSpeed(Offset position) {
    cursorState.mouseEventPosition = position;
    var dy = position.dy;
    if (dy < 0) {} else if (dy > visionHeight) {
      dy -= visionHeight;
    } else {
      dy = 0;
    }
    dy /= 10;
    var dx = position.dx;
    if (dx < 0) {} else if (dx > visionWidth - padding.left - padding.right) {
      dx -= (visionWidth - padding.left - padding.right);
    } else {
      dx = 0;
    }
    dx /= 10;
    if (isMobile) {
      dx /= 2;
      dy /= 2;
    }
    mouseKeyboardState.mouseScrollSpeedX = dx;
    mouseKeyboardState.mouseScrollSpeedY = dy;
  }

  void startMouseScrollTimer() {
    if (mouseKeyboardState.mouseScrollTimer != null) {
      return;
    }
    mouseKeyboardState.mouseScrollTimer =
        Timer.periodic(const Duration(milliseconds: 10), (timer) {
          //根据速度滚动
          if (mouseKeyboardState.mouseScrollSpeedY != 0 ||
              mouseKeyboardState.mouseScrollSpeedX != 0) {
            scrollVertical(mouseKeyboardState.mouseScrollSpeedY);
            scrollHorizontal(mouseKeyboardState.mouseScrollSpeedX);
            if (isMobile) {
              return;
            }
            var eventPosition = cursorState.mouseEventPosition;
            if (eventPosition != null) {
              var position = getCursorPosition(eventPosition);
              if (position.isValid) {
                //鼠标滑动事件：更新cursor位置
                updateCursor(position, applyUpdate: true);
                recordSelectEnd(position);
                updateWidgetState();
              }
            }
          }
        });
  }

  /// 更新选择的光标
  void updateSelectCursor() {
    try {
      var start = selectState.start;
      var blockStart = blockManager.blocks[start!.blockIndex!];
      selectState.start = blockStart.getCursorPosition(start.textPosition!)
        ..blockIndex = start.blockIndex
        ..blockVisionTop = blockStart.top - scrollOffset;
    } catch (ignore) {}
    try {
      var end = selectState.end;
      var blockEnd = blockManager.blocks[end!.blockIndex!];
      selectState.end = blockEnd.getCursorPosition(end.textPosition!)
        ..blockIndex = end.blockIndex
        ..blockVisionTop = blockEnd.top - scrollOffset;
    } catch (ignore) {}
  }

  /// 刷新光标位置
  void refreshCursorPosition() {
    var cPos = cursorState.cursorPosition;
    var block = cPos?.block;
    var tPos = cPos?.textPosition;
    if (block != null && tPos != null) {
      var index = cPos?.blockIndex;
      if (index != null && index < blockManager.blocks.length) {
        updateCursor(blockManager.blocks[index].getCursorPosition(tPos),
            scrollToShowCursor: false, applyUpdate: false);
      } else {
        updateCursor(block.getCursorPosition(tPos),
            scrollToShowCursor: false, applyUpdate: false);
      }
    }
  }

  ///更新光标位置
  void updateCursor(CursorPosition position,
      {bool scrollToShowCursor = true, bool applyUpdate = false}) {
    var block = position.block;
    if (block != null) {
      position.blockIndex = blockManager.indexOfBlockByBlock(block);
      position.blockVisionTop = block.top - scrollOffset;
    }
    cursorRecord.updateCursorPosition(position);
    var old = cursorState.cursorPosition;
    if (old != null) {
      var oldBlock = old.block;
      if (oldBlock != null) {
        oldBlock.relayoutFlag = true;
        oldBlock.cursorPosition = null;
      }
    }
    cursorState.cursorPosition = position;
    position.block?.cursorPosition = position.textPosition;
    position.block?.relayoutFlag = true;
    startCursorTimer();
    if (!mouseKeyboardState.mouseDrag && scrollToShowCursor) {
      scrollToCursorPosition();
    }
  }

  ///更新鼠标划过位置：用于计算链接是否被划过，滚动时需要更新，鼠标移动时需要更新
  void updateHoverCursorPosition() {
    var event = <PointerEvent>[];
    if (mouseKeyboardState.mouseHoverEvent.isNotEmpty) {
      event.add(mouseKeyboardState.mouseHoverEvent.last);
    }
    if (event.isEmpty) {
      return;
    }
    event.sort((a, b) => a.timeStamp.compareTo(b.timeStamp));
    var location = event.last.localPosition;
    var hover = cursorState.hoverPosition;
    var hoverBlock = hover?.block;
    if (hoverBlock != null) {
      hoverBlock.relayoutFlag = true;
      hoverBlock.hoverPosition = null;
    }
    var position = getHoverCursorPosition(location);
    cursorState.hoverPosition = position;
    hoverBlock = position?.block;
    if (mouseKeyboardState.enter && hoverBlock != null) {
      hoverBlock.relayoutFlag = true;
      hoverBlock.hoverPosition = position?.textPosition;
    }
    updateWidgetState();
  }

  ///更新输入法位置
  void updateInputMethodWindowPosition() {
    if (!(kIsWeb ||
        Platform.isLinux ||
        Platform.isMacOS ||
        Platform.isWindows)) {
      return;
    }
    var position = cursorState.cursorPosition;
    if (selectState.hasSelectRange) {
      position = selectState.realStart;
    }
    var block = position?.block;
    if (position != null && block != null) {
      var composingLength = inputManager.composing?.text.length ?? 0;
      var inputPos =
      max(0, (position.textPosition?.offset ?? 0) - composingLength);
      var inputRect = block.getCursorRect(TextPosition(offset: inputPos));
      if (inputRect == null) {
        return;
      }
      inputManager.updateInputPosition(
        Size(blockMaxWidth, visionHeight),
        inputRect
            .shift(Offset(padding.left, block.top - scrollOffset + padding.top))
            .shift(visionOffset),
        getComposingRect()
            ?.shift(
            Offset(padding.left, block.top - scrollOffset + padding.top))
            .shift(visionOffset),
      );
    }
  }

  Rect? getComposingRect() {
    var composingLength = inputManager.composing?.text.length ?? 0;
    var position = cursorState.cursorPosition;
    var composingPos =
    max(0, (position?.textPosition?.offset ?? 0) - composingLength);
    var boxes = position?.block?.getBoxesForSelection(TextSelection(
        baseOffset: composingPos,
        extentOffset: composingPos + composingLength));
    if (boxes != null) {
      double left = position?.rect?.left ?? 0;
      double right = position?.rect?.right ?? 0;
      double top = position?.rect?.top ?? 0;
      double bottom = position?.rect?.bottom ?? 0;
      for (var box in boxes) {
        var boxRect = box.toRect();
        if (left == double.infinity || left > boxRect.left) {
          left = boxRect.left;
        }
        if (top == double.infinity || top > boxRect.top) {
          top = boxRect.top;
        }

        if (right == double.infinity || right < boxRect.right) {
          right = boxRect.right;
        }
        if (bottom == double.infinity || bottom < boxRect.bottom) {
          bottom = boxRect.bottom;
        }
      }
      return Rect.fromLTRB(left, top, right, bottom);
    }
    return null;
  }

  ///得到光标位置：用于显示光标
  CursorPosition getCursorPosition(Offset eventPosition) {
    var clickPosition = eventPosition.translate(0, scrollOffset);
    var cursorBlock = blockManager.getBlockByOffset(clickPosition.dy);
    TextPosition? textPosition;
    Rect? cursorRect;
    if (cursorBlock != null) {
      var pos = clickPosition.translate(0, -cursorBlock.top);
      textPosition = cursorBlock.getPositionForOffset(pos);
      if (textPosition != null) {
        cursorRect = cursorBlock.getCursorRect(textPosition);
      }
    }
    return CursorPosition(
      block: cursorBlock,
      textPosition: textPosition,
      rect: cursorRect,
      blockIndex: blockManager.indexOfBlock(clickPosition.dy),
      isBottom: blockManager.isBottom(clickPosition.dy),
    );
  }

  ///得到光标位置：用于显示鼠标划过位置(链接)
  CursorPosition? getHoverCursorPosition(Offset eventPosition) {
    var clickPosition = eventPosition.translate(0, scrollOffset);
    var cursorBlock = blockManager.getBlockByOffset(clickPosition.dy);
    TextPosition? textPosition;
    if (cursorBlock != null) {
      if (cursorBlock.top + cursorBlock.height < clickPosition.dy ||
          cursorBlock.top > clickPosition.dy) {
        return null;
      }
      var pos = clickPosition.translate(0, -cursorBlock.top);
      textPosition = cursorBlock.getPositionForOffset(pos);
      if (textPosition != null) {
        var boxes = cursorBlock.getBoxesForSelection(TextSelection(
            baseOffset: max(textPosition.offset - 1, 0),
            extentOffset: min(
              textPosition.offset + 1,
              cursorBlock.length,
            )));
        var ret = false;
        if (boxes.isNotEmpty) {
          for (var box in boxes) {
            if (box.toRect().contains(pos)) {
              ret = true;
              break;
            }
          }
        }
        if (!ret) {
          return null;
        }
      }
    }
    return CursorPosition(
      block: cursorBlock,
      textPosition: textPosition,
    );
  }

  ///记录光标选择开始位置
  void recordSelectStart(CursorPosition? cursorPosition) {
    if (cursorPosition != null && cursorPosition.block != null) {
      cursorPosition.blockVisionTop = cursorPosition.block!.top - scrollOffset;
      cursorPosition.blockIndex =
          blockManager.indexOfBlockByBlock(cursorPosition.block!);
    }
    selectState.start = cursorPosition;
    selectState.end = null;
    if (!isMobile) {
      requestFocus();
    }
  }

  ///记录光标选择开始位置
  void recordSelectEnd(CursorPosition? cursorPosition) {
    if (cursorPosition != null && cursorPosition.block != null) {
      cursorPosition.blockVisionTop = cursorPosition.block!.top - scrollOffset;
      cursorPosition.blockIndex =
          blockManager.indexOfBlockByBlock(cursorPosition.block!);
    }
    selectState.end = cursorPosition;
    if (!isMobile) {
      requestFocus();
    }
  }

  ///布局构建事件
  void onLayoutBuild(BuildContext context,
      BoxConstraints parentConstrains,
      BoxConstraints constrains,) {
    viewContext = context;
    inputManager.context = context;
    for (var block in blockManager.blocks) {
      block.context = context;
    }
    bool sizeChanged = visionWidth != constrains.maxWidth ||
        visionHeight != constrains.maxHeight;
    var oldHeight = visionHeight;
    visionWidth = constrains.maxWidth;
    visionHeight = constrains.maxHeight;
    visionOffset =
        Offset(parentConstrains.maxWidth / 2 - constrains.maxWidth / 2, 0);
    if (sizeChanged) {
      onSizeChanged(context, oldHeight > visionHeight);
    }
    blockManager.layout(context, scrollOffset,
        Size(blockMaxWidth, max(200, visionHeight * 1.5)), padding);
  }

  void onScrollerChanged() {}

  ///窗口大小发生变化
  void onSizeChanged(BuildContext context, bool showCursor) {
    SchedulerBinding.instance.scheduleFrameCallback((timeStamp) {
      var pos = cursorState.cursorPosition;
      if (pos != null && pos.isValid) {
        pos.rect = pos.block?.getCursorRect(pos.textPosition!);
        bool scrollToShowCursor = isMobile && showCursor;
        updateCursor(pos,
            scrollToShowCursor: scrollToShowCursor, applyUpdate: true);
      }
    });
  }

  ///焦点发生变化
  void onFocusChanged(bool focus) {
    focusNotifier.value = focus;
    if (!focus) {
      if (!isMobile) {
        inputManager.closeInputMethod();
        updateWidgetState();
      }
      stopCursorTimer();
    } else {
      if (editable) {
        if (!isMobile) {
          inputManager.openInputMethod();
        }
        showCursorOnOpen();
        startCursorTimer();
      }
    }
  }

  void visitElement(WenzElementVisitor visitor, CursorPosition start,
      CursorPosition end) {
    if (start.block! == end.block) {
      start.block!
          .visitElement(start.textPosition!, end.textPosition!, visitor);
    } else {
      start.block!
          .visitElement(start.textPosition!, start.block!.endPosition, visitor);
      var startBlockIndex =
          start.blockIndex ?? blockManager.indexOfBlockByBlock(start.block!);
      var endBlockIndex =
          end.blockIndex ?? blockManager.indexOfBlockByBlock(end.block!);
      for (var i = startBlockIndex + 1; i < endBlockIndex; i++) {
        var block = blockManager.blocks[i];
        block.visitElement(block.startPosition, block.endPosition, visitor);
      }
      end.block!
          .visitElement(end.block!.startPosition, end.textPosition!, visitor);
    }
  }

  void visitSelectElement(WenzElementVisitor visitor) {
    if (selectState.hasSelect) {
      var start = selectState.realStart;
      var end = selectState.realEnd;
      visitElement(visitor, start!, end!);
    } else {
      var position = cursorState.cursorPosition;
      if (position != null && position.textPosition != null) {
        if (position.textPosition?.affinity == TextAffinity.downstream) {
          var end = position.copy;
          end.textPosition =
              TextPosition(offset: (position.textPosition?.offset ?? 0) + 1);
          visitElement(visitor, position, end);
        } else {
          var start = position.copy;
          start.textPosition =
              TextPosition(offset: (position.textPosition?.offset ?? 0) - 1);
          visitElement(visitor, start, position);
        }
      }
    }
  }

  void visitSelectBlock(WenzBlockVisitor visitor, {bool visitCursor = false}) {
    if (selectState.hasSelect) {
      var start = selectState.realStart;
      var end = selectState.realEnd;
      var startBlockIndex =
          start!.blockIndex ?? blockManager.indexOfBlockByBlock(start.block!);
      var endBlockIndex =
          end!.blockIndex ?? blockManager.indexOfBlockByBlock(end.block!);
      for (var i = startBlockIndex; i <= endBlockIndex; i++) {
        var block = blockManager.blocks[i];
        visitor.call(block);
      }
    } else {
      if (visitCursor) {
        var block = cursorState.cursorPosition?.block;
        if (block != null) {
          visitor.call(block);
        }
      }
    }
  }

  /// 复制
  /// 将选择的富文本转为html和文本
  /// 难点：图片、代码、公式等特殊元素转换存在问题 简单解决只给复制文本、图片、代码元素，其他元素通过id复制
  void copySelect({
    bool copyText = false,
  }) {
    CopyUtils.copySelect(controller: this, copyText: copyText);
  }

  void copyAllText({
    bool copyText = false,
  }) async {
    CopyUtils.copyAll(controller: this, copyText: copyText);
  }

  void copyMarkdown({FilePathBuilder? filePathBuilder}) async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return;
    }
    final item = DataWriterItem();
    item.add(Formats.plainText(getMarkdown(filePathBuilder: filePathBuilder)));
    await clipboard.write([item]);
  }

  String getText() {
    StringBuffer text = StringBuffer();
    for (var block in blockManager.blocks) {
      var element = block.element;
      text.write("\n${element.getText()}");
    }
    return text.toString();
  }

  String getMarkdown({FilePathBuilder? filePathBuilder}) {
    StringBuffer text = StringBuffer();
    for (var block in blockManager.blocks) {
      var element = block.element;

      text.write(
        "\n\n${element.getMarkDown(filePathBuilder: filePathBuilder)}",
      );
    }
    return text.toString();
  }

  void requestFocus() {
    FocusScope.of(viewContext).requestFocus();
    focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      FocusScope.of(viewContext).requestFocus();
      focusNode.requestFocus();
    });
  }

  /// 由系统拖入事件响应
  Future<void> performDragIn(PerformDropEvent event) async {
    var fileList = <String>[];
    for (var item in event.session.items) {
      var dataReader = item.dataReader;
      if (dataReader == null) {
        continue;
      }
      if (!dataReader.canProvide(Formats.fileUri)) {
        continue;
      }
      var comp = Completer();
      dataReader.getValue(Formats.fileUri, (value) {
        if (value is Uri) {
          var path = value.toFilePath();
          fileList.add(path);
        }
        comp.complete();
      });
      await comp.future;
    }
    showMobileDialog(
      context: viewContext,
      builder: (context) =>
          FutureProgressDialog(
                () async {
              for (var file in fileList) {
                var stat = File(file).statSync();
                if (stat.type == FileSystemEntityType.file) {
                  await pasteImage(File(file).readAsBytesSync(),
                      suffix: FileUtils.getFileSuffix(file));
                }
              }
            }(),
          ),
    );
  }

  ///更新光标位置
  void toPosition(CursorPosition? newPosition, bool updateCursorX,
      {bool scrollToShowCursor = true, bool applyUpdate = true}) {
    if (newPosition == null) {
      return;
    }
    var cursorPosition = cursorState.cursorPosition;
    if (selectState.shiftDown) {
      if (selectState.start == null) {
        recordSelectStart(cursorPosition);
      }
      recordSelectEnd(newPosition);
    } else {
      selectState.clearSelect();
    }
    updateCursor(
      newPosition,
      scrollToShowCursor: scrollToShowCursor,
      applyUpdate: applyUpdate,
    );
    if (updateCursorX) {
      cursorRecord.updateCursorWindowPosition(newPosition, scrollOffset);
    }
  }

  ///光标跳到行头
  void toHome() {
    var cursorPosition = cursorState.cursorPosition;
    if (cursorPosition == null || !cursorPosition.isValid) {
      return;
    }
    var block = cursorPosition.block!;
    var range = block.getLineBoundary(cursorPosition.textPosition!);
    if (range != null) {
      var pos = block.getCursorPosition(TextPosition(
        offset: range.start,
        affinity: TextAffinity.downstream,
      ));
      toPosition(pos, true);
    }
  }

  ///光标跳到行尾
  void toEnd() {
    var cursorPosition = cursorState.cursorPosition;
    if (cursorPosition == null || !cursorPosition.isValid) {
      return;
    }
    var block = cursorPosition.block!;
    var range = block.getLineBoundary(cursorPosition.textPosition!);
    if (range != null) {
      var pos = block.getCursorPosition(TextPosition(
        offset: range.end,
        affinity: TextAffinity.upstream,
      ));
      toPosition(pos, true);
    }
  }

  ///光标左移
  void toLeft() {
    if (!selectState.shiftDown && selectState.hasSelect) {
      var pos = selectState.realStart;
      pos = pos!.block!.getCursorPosition(pos.textPosition!);
      toPosition(pos, true);
      return;
    }
    var position = cursorState.cursorPosition;
    if (position == null || !position.isValid) {
      return;
    }
    var block = position.block!;
    layoutPreviousBlock(block);
    var textPosition = position.textPosition!;
    if (textPosition.offset > 0) {
      var newTextPosition = TextPosition(
          offset: textPosition.offset - 1, affinity: TextAffinity.downstream);
      var newRect = block.getCursorRect(newTextPosition);
      toPosition(
          CursorPosition(
            textPosition: newTextPosition,
            rect: newRect,
            block: block,
          ),
          true);
    } else {
      //如果选择了文字，则到选择开始的地方
      var index = blockManager.indexOfBlockByBlock(block);
      if (index > 0) {
        var newBlock = blockManager.blocks[index - 1];
        var textPosition = newBlock.endPosition;
        var cursorRect = newBlock.getCursorRect(textPosition);
        toPosition(
            CursorPosition(
                block: newBlock, textPosition: textPosition, rect: cursorRect),
            true);
      }
    }
  }

  ///光标右移
  void toRight() {
    if (!selectState.shiftDown && selectState.hasSelect) {
      var pos = selectState.realEnd;
      pos = pos!.block!.getCursorPosition(pos.textPosition!);
      toPosition(pos, true);
      return;
    }
    var position = cursorState.cursorPosition;
    if (position == null || !position.isValid) {
      return;
    }
    var block = position.block!;
    layoutNextBlock(block);
    var textPosition = position.textPosition!;
    var blockEndPosition = block.endPosition;
    if (textPosition.offset < blockEndPosition.offset) {
      var newTextPosition = TextPosition(
          offset: textPosition.offset + 1, affinity: TextAffinity.upstream);
      var newRect = block.getCursorRect(newTextPosition);
      toPosition(
          CursorPosition(
            textPosition: newTextPosition,
            rect: newRect,
            block: block,
          ),
          true);
    } else {
      //如果选择了文字，则到选择开始的地方
      var index = blockManager.indexOfBlockByBlock(block);
      if (index + 1 < blockManager.blocks.length) {
        var newBlock = blockManager.blocks[index + 1];
        var textPosition = newBlock.startPosition;
        var cursorRect = newBlock.getCursorRect(textPosition);
        toPosition(
            CursorPosition(
                block: newBlock, textPosition: textPosition, rect: cursorRect),
            true);
      }
    }
  }

  ///光标上移
  void toUp() {
    if (popupTool.isShow) {
      popupTool.toUp();
      return;
    }
    var position = cursorState.cursorPosition;
    if (position == null || !position.isValid) {
      return;
    }
    var block = position.block!;
    if (block.toUp()) {
      return;
    }
    layoutPreviousBlock(block);
    var textPosition = position.textPosition!;
    var lineBoundary = block.getLineBoundary(textPosition);
    if (lineBoundary == null) {
      return;
    }

    if (lineBoundary.start == 0 || lineBoundary.start == -1) {
      //上一个block
      if (block.top == 0) {
        return;
      }
      var blockIndex = blockManager.indexOfBlock(block.top);
      if (blockIndex == -1 || blockIndex == 0) {
        return;
      }
      var upBlock = blockManager.blocks[blockIndex - 1];
      var upBlockPosition = upBlock.getPositionForOffset(
          Offset(cursorRecord.recordWindowX, upBlock.height));
      if (upBlockPosition == null) {
        return;
      }
      var upBlockCursorRect = upBlock.getCursorRect(upBlockPosition);
      toPosition(
          CursorPosition(
            block: upBlock,
            textPosition: upBlockPosition,
            rect: upBlockCursorRect,
          ),
          false);
    } else {
      //上一行
      int pos = lineBoundary.start - 1;
      var y = block
          .getCursorRect(TextPosition(offset: pos))
          ?.center
          .dy;
      if (y == null) {
        return;
      }
      var upTextPosition =
      block.getPositionForOffset(Offset(cursorRecord.recordWindowX, y))!;
      var upRect = block.getCursorRect(upTextPosition);
      toPosition(
          CursorPosition(
            block: block,
            textPosition: upTextPosition,
            rect: upRect,
          ),
          false);
    }
  }

  /// 光标下移
  void toDown() {
    if (popupTool.isShow) {
      popupTool.toDown();
      return;
    }
    var position = cursorState.cursorPosition;
    if (position == null || !position.isValid) {
      return;
    }
    var block = position.block!;
    if (block.toDown()) {
      return;
    }
    layoutNextBlock(block);
    var textPosition = position.textPosition!;
    var lineBoundary = block.getLineBoundary(textPosition);
    if (lineBoundary == null) {
      return;
    }
    if (lineBoundary.end == -1 ||
        lineBoundary.end == block.endPosition.offset) {
      //下一个 block
      int curIndex = blockManager.indexOfBlockByBlock(block);
      if (curIndex + 1 >= blockManager.blocks.length) {
        return;
      }
      var nextBlock = blockManager.blocks[curIndex + 1];
      var nextBlockPosition =
      nextBlock.getPositionForOffset(Offset(cursorRecord.recordWindowX, 0));
      if (nextBlockPosition == null) {
        return;
      }
      var nextBlockRect = nextBlock.getCursorRect(nextBlockPosition);
      toPosition(
          CursorPosition(
            block: nextBlock,
            textPosition: nextBlockPosition,
            rect: nextBlockRect,
          ),
          false);
    } else {
      //下一行
      int pos = lineBoundary.end + 1;
      var y = block
          .getCursorRect(TextPosition(offset: pos))
          ?.center
          .dy;
      if (y == null) {
        return;
      }
      var nextTextPosition =
      block.getPositionForOffset(Offset(cursorRecord.recordWindowX, y));
      if (nextTextPosition == null) {
        return;
      }
      var nextRect = block.getCursorRect(nextTextPosition);
      toPosition(
          CursorPosition(
            block: block,
            textPosition: nextTextPosition,
            rect: nextRect,
          ),
          false);
    }
  }

  /// 下一页
  void toPageDown() {
    layoutNext(visionHeight);
    scrollVertical(visionHeight);
    SchedulerBinding.instance.scheduleFrameCallback((timeStamp) {
      toPosition(
        getCursorPosition(
            Offset(cursorRecord.recordWindowX, cursorRecord.recordWindowY)),
        false,
        scrollToShowCursor: true,
      );
    });
  }

  /// 滚动到上一页
  void toPageUp() {
    layoutPrevious(visionHeight);
    scrollVertical(-visionHeight);
    SchedulerBinding.instance.scheduleFrameCallback((timeStamp) {
      toPosition(
        getCursorPosition(
            Offset(cursorRecord.recordWindowX, cursorRecord.recordWindowY)),
        false,
        scrollToShowCursor: true,
      );
    });
  }

  ///全选
  void selectAll() {
    if (!isMobile) {
      requestFocus();
    }
    var cursorBlock = cursorState.cursorPosition?.block;
    if (cursorBlock != null) {
      if (cursorBlock.canSelectAll) {
        if (!cursorBlock.selectAll()) {
          recordSelectStart(cursorBlock.startCursorPosition);
          recordSelectEnd(cursorBlock.endCursorPosition);
          updateWidgetState();
        }
        return;
      }
    }
    var blocks = blockManager.blocks;
    if (blocks.isEmpty) return;

    var first = blocks.first;
    var end = blocks.last;
    layoutBlock(blocks.first, blocks.length - 10, blocks.length - 1);
    recordSelectStart(CursorPosition(
        block: first,
        textPosition: const TextPosition(offset: 0),
        rect: first.getCursorRect(const TextPosition(offset: 0))));
    end.layout(viewContext, Size(blockMaxWidth, visionHeight));
    var pos = end
        .getPositionForOffset(const Offset(double.infinity, double.infinity))!;

    recordSelectEnd(CursorPosition(
        block: end, textPosition: pos, rect: end.getCursorRect(pos)));
    updateWidgetState();
  }

  ///滚动到光标位置
  ///什么时候需要滚动到光标位置？
  ///拖动时候，更新光标位置时候
  void scrollToCursorPosition() {
    SchedulerBinding.instance.scheduleFrameCallback((timeStamp) {
      scrollToCursorPositionVertical();
      scrollToCursorPositionHorizontal();
      showPopupTool();
    });
  }

  void scrollToCursorPositionVertical() {
    //垂直滚动到光标位置：如果子组件可以滚动，则需要混合滚动(思维导图之类自定义组件可能需要，目前不需要垂直混合滚动)
    var position = cursorState.cursorPosition;
    if (position == null) {
      return;
    }
    var block = position.block;
    var cursorRect = getCursorRect(position);
    if (block == null || cursorRect == null) {
      return;
    }
    if (cursorRect.height > visionHeight - 40) {
      var heightDis = cursorRect.height - visionHeight + 40;
      cursorRect = Rect.fromLTWH(cursorRect.left, cursorRect.top + heightDis,
          cursorRect.width, visionHeight - heightDis);
    }

    var cursorStartY = cursorRect.top + padding.top;
    var cursorEndY = cursorRect.bottom + padding.top;
    var viewStartY = scrollOffset + 10;
    var viewEndY = scrollOffset + visionHeight - 10;
    if (cursorStartY < viewStartY) {
      scrollVertical(cursorStartY - viewStartY);
    }
    if (cursorEndY > viewEndY) {
      scrollVertical(cursorEndY - viewEndY);
    }
  }

  void scrollToCursorPositionHorizontal() {
    //水平滚动必然只有子组件有，所以如果cursor所在block有水平滚动情况才需要计算
    var position = cursorState.cursorPosition;
    if (position == null) {
      return;
    }
    var block = position.block;
    if (block == null) {
      return;
    }
    //如果光标位置小于paddingLeft，需要调节
    block.scrollToCursorPosition(position);
  }

  void scrollHorizontal(double deltaX) {
    //水平滚动必然只有子组件有，所以如果cursor所在block有水平滚动情况才需要计算
    var position = cursorState.cursorPosition;
    if (position == null) {
      return;
    }
    var block = position.block;
    if (block == null) {
      return;
    }
    //如果光标位置小于paddingLeft，需要调节
    block.scrollHorizontal(deltaX);
  }

  ///对指定的index的block进行布局，并且在布局后改变的大小进行锚block定位
  void layoutBlock(WenzBlock anchorBlock, int startBlockIndex,
      int endBlockIndex,
      {bool jump = false}) {
    try {
      startBlockIndex = blockManager.getValidIndex(startBlockIndex);
      endBlockIndex = blockManager.getValidIndex(endBlockIndex);
      var anchor = scrollOffset - anchorBlock.top;
      blockManager.layoutBlockRange(viewContext, startBlockIndex, endBlockIndex,
          Size(blockMaxWidth, visionHeight));
      var newScrollOffset = anchor + anchorBlock.top;
      if (jump) {
        scrollController?.jumpTo(newScrollOffset);
      }
    } catch (e) {}
  }

  ///布局当前block
  void layoutCurrentBlock(WenzBlock anchorBlock, {bool jump = false}) {
    int startBlockIndex = blockManager.indexOfBlockByBlock(anchorBlock);
    var anchor = scrollOffset - anchorBlock.top;
    blockManager.layoutBlockRange(viewContext, startBlockIndex, startBlockIndex,
        Size(blockMaxWidth, visionHeight));
    var newScrollOffset = anchor + anchorBlock.top;
    try {
      if (jump == true) {
        scrollController?.jumpTo(newScrollOffset);
      }
    } catch (e) {}
  }

  ///布局前10个block
  void layoutPreviousBlock(WenzBlock anchorBlock) {
    int index = blockManager.indexOfBlockByBlock(anchorBlock);
    if (index == -1) {
      return;
    }
    int pre = index - 10;
    if (pre < 0) {
      pre = 0;
    }
    layoutBlock(anchorBlock, pre, index);
  }

  ///布局后10个block
  void layoutNextBlock(WenzBlock anchorBlock) {
    int index = blockManager.indexOfBlockByBlock(anchorBlock);
    if (index == -1) {
      return;
    }
    int next = index + 10;
    if (next >= blockManager.blocks.length) {
      next = blockManager.blocks.length - 1;
    }
    layoutBlock(anchorBlock, index, next);
  }

  ///根据高度布局前面n个block
  void layoutPrevious(double height) {
    var anchorIndex = getWindowFirstBlockIndex();
    if (anchorIndex == -1) {
      return;
    }
    var anchor = blockManager.blocks[anchorIndex];
    int index = anchorIndex - 1;
    while (index >= 0) {
      int end = index - 10;
      if (end < 0) {
        end = 0;
      }
      layoutBlock(anchor, end, index);
      if ((blockManager.blocks[end].top - anchor.top).abs() > height) {
        break;
      }
      index = end - 1;
    }
  }

  ///根据高度布局后n个block
  void layoutNext(double height) {
    var anchorIndex = getWindowFirstBlockIndex();
    if (anchorIndex == -1) {
      return;
    }
    var anchor = blockManager.blocks[anchorIndex];
    int index = anchorIndex + 1;
    while (index <= blockManager.blocks.length - 1) {
      int end = index + 10;
      if (end > blockManager.blocks.length - 1) {
        end = blockManager.blocks.length - 1;
      }
      layoutBlock(anchor, index, end);
      if ((blockManager.blocks[end].top - anchor.top).abs() > height) {
        break;
      }
      index = end + 1;
    }
  }

  void relayoutVision() {
    layoutNext(visionHeight * 2);
  }

  ///获取窗口第一个显示的block索引
  int getWindowFirstBlockIndex() {
    return blockManager.indexOfBlock(scrollOffset);
  }

  ///获取窗口最后一个显示的block索引
  int getWindowEndBlockIndex() {
    return blockManager.indexOfBlock(scrollOffset + visionHeight);
  }

  int get currentStartBlockIndex {
    var selectStartBlock = selectState.realStart?.block;
    if (selectStartBlock != null) {
      return blockManager.indexOfBlockByBlock(selectStartBlock);
    }
    var cursorBlock = cursorState.cursorPosition?.block;
    if (cursorBlock != null) {
      return blockManager.indexOfBlockByBlock(cursorBlock);
    }
    return -1;
  }

  int get currentEndBlockIndex {
    var selectStartBlock = selectState.realEnd?.block;
    if (selectStartBlock != null) {
      return blockManager.indexOfBlockByBlock(selectStartBlock);
    }
    var cursorBlock = cursorState.cursorPosition?.block;
    if (cursorBlock != null) {
      return blockManager.indexOfBlockByBlock(cursorBlock);
    }
    return -1;
  }

  void showCursorOnOpen() {
    if (cursorState.cursorPosition == null) {
      if (blockManager.blocks.isNotEmpty) {
        layoutCurrentBlock(blockManager.blocks.first);
        toPosition(blockManager.blocks.first.startCursorPosition, false);
      }
    } else {
      refreshCursorPosition();
    }
  }

  void scrollToBlock(WenzBlock block) {
    scrollVertical(block.top - scrollOffset + padding.top - 10);
  }

  String getSelectText() {
    var ret = "";
    if (selectState.hasSelect) {
      var start = selectState.realStart;
      var end = selectState.realEnd;
      if (start!.block! == end!.block) {
        WenElement element =
        start.block!.copyElement(start.textPosition!, end.textPosition!);
        return element.getText();
      } else {
        String text = "";
        var startSub = start.block!
            .copyElement(start.textPosition!, start.block!.endPosition);
        text += startSub.getText();
        int startIndex = blockManager.indexOfBlockByBlock(start.block!);
        int endIndex = blockManager.indexOfBlockByBlock(end.block!);
        for (int i = startIndex + 1; i < endIndex; i++) {
          text += "\n" + blockManager.blocks[i].element.getText();
        }
        var endSub =
        end.block!.copyElement(end.block!.startPosition, end.textPosition!);
        text += "\n" + endSub.getText();
        return text;
      }
    }
    return ret;
  }

  void onDragIn(DropOverEvent event) {
    var offset = event.position.local;
    offset = offset.translate(-padding.left, -padding.top);
    var cursorPosition = getCursorPosition(offset);
    toPosition(cursorPosition, true);
  }

  String? getBlockType(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= blockManager.blocks.length) {
      return null;
    }
    return blockManager.blocks[blockIndex].element.type;
  }

  void undo() {
    blockManager.undo(this);
  }

  void redo() {
    blockManager.redo(this);
  }

  bool get canUndo {
    return blockManager.canUndo;
  }

  bool get canRedo {
    return blockManager.canRedo;
  }

  bool get currentIsTable => cursorState.cursorPosition?.block is TableBlock;

  double abs(double value) {
    if (value < 0) {
      return -value;
    }
    return value;
  }

  void record() {
    blockManager.record(this);
    notifyListeners();
  }

  /// 滚动
  void scrollVertical(double dy) {
    int index = blockManager.indexOfBlock(dy + scrollOffset);
    if (index == -1) {
      if (blockManager.blocks.isEmpty) {
        return;
      }
      blockManager.layoutNextBlockWithHeight(
          viewContext, Size(visionWidth, visionHeight), 0, visionHeight);
      blockManager.layoutPreviousBlockWithHeight(
          viewContext,
          Size(visionWidth, visionHeight),
          blockManager.blocks.length - 1,
          visionHeight);
    } else {
      blockManager.layoutNextBlockWithHeight(
          viewContext, Size(visionWidth, visionHeight), index, visionHeight);
      blockManager.layoutPreviousBlockWithHeight(
          viewContext, Size(visionWidth, visionHeight), index, visionHeight);
    }
    var contentHeight = getContentHeight();
    double maxExtend = max(0, contentHeight - visionHeight);
    try {
      if (maxExtend > 0) {
        // scrollController?.position.applyContentDimensions(0, maxExtend);
      }
    } catch (e) {
      print(e);
    }
    double jumpToY = scrollOffset + dy;
    if (maxExtend > 0) {
      if (jumpToY < 0) {
        scrollController?.jumpTo(0);
      } else if (jumpToY > maxExtend) {
        scrollController?.jumpTo(maxExtend);
      } else {
        scrollController?.jumpTo(jumpToY);
      }
    }
  }

  double getContentHeight() {
    return padding.vertical + blockManager.height;
  }

  void setAlignment(String? alignment) {
    // 左对齐
    visitSelectBlock((block) {
      if (block is TableBlock) {
        block.setAlignment(alignment);
        return;
      }
      block.element.alignment = alignment;
      block.relayoutFlag = true;
    });
    updateWidgetState();
    refreshCursorPosition();
    record();
  }

  void onInputAction(TextInputAction action) {
    if (action == TextInputAction.newline || action == TextInputAction.done) {
      if (!kIsWeb && Platform.isAndroid || !kIsWeb && Platform.isIOS) {
        enter();
        record();
        WidgetsBinding.instance.scheduleFrameCallback((timeStamp) {
          refreshCursorPosition();
        });
      }
    }
  }

  void cut() {
    copySelect();
    if (selectState.hasSelect) {
      delete(false);
    }
    record();
  }

  /// 粘贴
  /// 难点：html富文本支持 解决方案：支持标题、正文、图片、代码、表格解析，其他特殊格式通过自有id熟悉解析
  /// 难点：html多层属性转换为2层属性
  /// 文档：https://pub.dev/packages/super_clipboard
  /// super_drag_and_drop
  Future<void> paste({
    bool pasteText = false,
    bool pasteHtml = false,
    bool pasteMarkdown = false,
  }) async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return;
    }
    String? text;
    String? html;
    var reader = await clipboard.read();
    if (reader.canProvide(Formats.htmlText)) {
      html = await reader.readValue(Formats.htmlText);
      // .. do something with the HTML text
    }

    if (reader.canProvide(Formats.plainText)) {
      try {
        text = await reader.readValue(Formats.plainText);
      } catch (e) {
        print(e);
        text = await Pasteboard.text;
      }
    }

    Uint8List? image;
    if (!isMobile) {
      image = await Pasteboard.image;
    }
    if (pasteText) {
      insertContent(null, text);
      record();
      return;
    }
    if (pasteMarkdown) {
      var elements = await parseMarkdown(fileManager, text ?? "");
      var blocks =
      elements.map((e) => createWenzBlock(viewContext, this, e)).toList();
      insertContent(blocks, null);
      record();
      return;
    }

    html = pasteHtml ? text : html;
    if (html != null) {
      List<WenzBlock>? blocks = await showDialog(
          context: viewContext,
          builder: (ctx) =>
              FutureProgressDialog(
                parseHtmlBlock(
                  editController: this,
                  copyService: copyService,
                  fileManager: fileManager,
                  context: viewContext,
                  html: html!,
                ),
              ));
      if (blocks != null) {
        // 移除前后换行符号
        while (blocks.isNotEmpty && blocks.first.isEmpty) {
          blocks.removeAt(0);
        }
        while (blocks.isNotEmpty && blocks.last.isEmpty) {
          blocks.removeLast();
        }
        insertContent(blocks, text);
        record();
        requestFocus();
      }
    } else if (text != null) {
      insertContent(null, text);
      record();
    } else if (image != null) {
      var fileId = await showMobileDialog(
          context: viewContext,
          builder: (context) =>
              FutureProgressDialog(
                fileManager.writeImage(image!),
              ));
      if (fileId != null) {
        var filepath = await fileManager.getImageFile(fileId.uuid);
        if (filepath == null) {
          return;
        }
        var size = await readImageFileSize(File(filepath));
        insertContent([
          ImageBlock(
              editController: this,
              context: viewContext,
              element: WenImageElement(
                id: fileId.uuid,
                file: filepath,
                width: size.width,
                height: size.height,
              ))
        ], text);
        record();
      }
    }
  }

  /// 粘贴图片
  Future<void> pasteImage(Uint8List image, {
    String suffix = ".png",
  }) async {
    var isImage = isValidImage(image_size.MemoryInput(image));
    if (!isImage) {
      return;
    }
    var fileItem = await fileManager.writeImage(
      image,
      suffix: suffix,
    );
    if (fileItem == null) {
      return;
    }
    var imageFile = await fileManager.getImageFile(fileItem.uuid);
    if (imageFile == null) {
      return;
    }
    var size = await readImageFileSize(File(imageFile));
    insertContent([
      ImageBlock(
          editController: this,
          context: viewContext,
          element: WenImageElement(
            id: fileItem.uuid!,
            file: imageFile,
            width: size.width,
            height: size.height,
          ))
    ], null);
    record();
  }

  Future<void> pasteImageFile(String path) async {
    var isImage = isValidImage(FileInput(File(path)));
    if (!isImage) {
      // return;
    }
    var fileItem = await fileManager.writeImageFile(path);
    if (fileItem == null) {
      return;
    }
    var imageFile = await fileManager.getImageFile(fileItem.uuid);
    if (imageFile == null) {
      return;
    }
    var size = await readImageFileSize(File(imageFile));
    insertContent([
      ImageBlock(
          editController: this,
          context: viewContext,
          element: WenImageElement(
            id: fileItem.uuid!,
            file: imageFile,
            width: size.width,
            height: size.height,
          ))
    ], null);
    record();
  }

  /// 缩进
  void addIndent() {
    if (currentStartBlockIndex != -1 &&
        currentStartBlockIndex == currentEndBlockIndex) {
      var block = blockManager.blocks[currentStartBlockIndex];
      if (block is CodeBlock) {
        block.addIndent();
        return;
      }
      if (block is TableBlock) {
        block.nextTable();
        return;
      }
    }
    var startIndex = cursorState.cursorPosition?.blockIndex;
    var endIndex = startIndex;
    if (selectState.hasSelect) {
      startIndex = selectState.realStart?.blockIndex;
      endIndex = selectState.realEnd?.blockIndex;
    }
    if (startIndex != null && endIndex != null) {
      for (var i = startIndex; i <= endIndex; i++) {
        var indent = blockManager.blocks[i].element.indent;
        indent ??= 0;
        indent++;
        if (indent > 6) {
          indent = 6;
        }
        blockManager.blocks[i].element.indent = indent;
        blockManager.blocks[i].relayoutFlag = true;
      }
      blockManager.layoutBlockRange(
          viewContext, startIndex, endIndex, Size(visionWidth, visionHeight));
      refreshCursorPosition();
    }
  }

  /// 缩退
  void removeIndent() {
    if (currentStartBlockIndex != -1 &&
        currentStartBlockIndex == currentEndBlockIndex) {
      var block = blockManager.blocks[currentStartBlockIndex];
      if (block is CodeBlock) {
        block.removeIndent();
        return;
      }
    }
    var startIndex = cursorState.cursorPosition?.blockIndex;
    var endIndex = startIndex;
    if (selectState.hasSelect) {
      startIndex = selectState.realStart?.blockIndex;
      endIndex = selectState.realEnd?.blockIndex;
    }
    if (startIndex != null && endIndex != null) {
      for (var i = startIndex; i <= endIndex; i++) {
        var indent = blockManager.blocks[i].element.indent;
        indent ??= 0;
        indent--;
        if (indent < 0) {
          indent = 0;
        }
        blockManager.blocks[i].relayoutFlag = true;
        blockManager.blocks[i].element.indent = indent;
      }
      blockManager.layoutBlockRange(
          viewContext, startIndex, endIndex, Size(visionWidth, visionHeight));
      refreshCursorPosition();
    }
  }

  ///回车
  void enter() {
    if (replaceWithCodeCheck()) {
      return;
    }
    if (popupTool.isShow) {
      popupTool.enter();
      return;
    }
    bool hasSelect = selectState.hasSelect;
    if (hasSelect) {
      deleteSelectRange();
    }
    var cursor = cursorState.cursorPosition;
    if (cursor == null) {
      return;
    }
    var cursorBlock = cursor.block;
    if (cursorBlock == null) {
      return;
    }
    var cursorTextPosition = cursor.textPosition;
    if (cursorTextPosition == null) {
      return;
    }
    if (cursorBlock.catchEnter) {
      onInputText(const TextEditingValue(text: "\n"));
      return;
    }
    var blockIndex = blockManager.indexOfBlockByBlock(cursorBlock);
    //0.如果没有选择，当前block内容为空，则清除block样式
    if (!hasSelect && blockManager.blocks[blockIndex].isEmpty) {
      var oldBlock = blockManager.blocks[blockIndex];
      var clearStyle = true;
      var oldElement = oldBlock.element;
      if (oldElement is WenTextElement) {
        if (oldElement.itemType == "text" || oldElement.itemType == null) {
          clearStyle = false;
        }
        if (oldElement.type == "quote" &&
            getBlockType(blockIndex + 1) != "quote") {
          clearStyle = true;
        }
      }
      if (clearStyle) {
        String newType = "text";
        if (getBlockType(blockIndex) == "quote" &&
            getBlockType(blockIndex + 1) == "quote") {
          newType = "quote";
        }
        blockManager.blocks[blockIndex] = TextBlock(
            editController: this,
            context: viewContext,
            textElement: WenTextElement(type: newType))
          ..top = oldBlock.top;
        layoutBlock(blockManager.blocks[blockIndex], blockIndex, blockIndex);
        var position = blockManager.blocks[blockIndex].startCursorPosition;
        toPosition(position, true);
        return;
      }
    }
    //1.如果光标在行首，则在前面插入一行text
    //2.如果光标在行尾，则在后面插入一行text
    //3.如果光标在中间，则分割block
    if (cursorTextPosition.offset == cursorBlock.endPosition.offset) {
      String? itemType;
      int? indent = cursorBlock.element.indent;
      String type = "text";
      if (getBlockType(blockIndex) == "quote" &&
          getBlockType(blockIndex + 1) == "quote") {
        type = "quote";
      } else if (cursorBlock is TextBlock) {
        if (!cursorBlock.isEmpty) {
          itemType = cursorBlock.textElement.itemType;
          type = cursorBlock.element.type;
        }
      }
      var textBlock = TextBlock(
          editController: this,
          context: viewContext,
          textElement: WenTextElement(
            type: type,
            itemType: itemType,
            indent: indent,
          ));
      blockManager.blocks.insert(
        blockIndex + 1,
        textBlock,
      );
      layoutBlock(cursorBlock, blockIndex, blockIndex + 1);
    } else if (cursorTextPosition == cursorBlock.startPosition) {
      String type = "text";
      if (cursorBlock is TextBlock) {
        type = cursorBlock.textElement.type;
      }
      var textBlock = TextBlock(
          editController: this,
          context: viewContext,
          textElement: WenTextElement(
            text: "",
            type: type,
          ));
      textBlock.top = cursorBlock.top;
      blockManager.blocks.insert(
        blockIndex,
        textBlock,
      );
      layoutBlock(textBlock, blockIndex, blockIndex + 1);
    } else {
      var textBlock = cursorBlock.splitBlock(cursorTextPosition);
      blockManager.blocks.insert(
        blockIndex + 1,
        textBlock,
      );
      layoutBlock(cursorBlock, blockIndex, blockIndex + 1);
    }
    var position = blockManager.blocks[blockIndex + 1].startCursorPosition;
    toPosition(position, true);
    refreshCursorPosition();
  }

  ///删除
  void delete(bool backspace) {
    if (selectState.hasSelectRange) {
      deleteSelectRange();
    } else {
      deleteCursor(backspace);
    }
    refreshCursorPosition();
    scrollToCursorPosition();
    updateWidgetState();
    showPopupTool();
  }

  ///输入拼音
  void onInputComposing(TextEditingValue composing) {
    deleteSelectRange();
    deleteComposing();
    var block = cursorState.cursorPosition?.block;
    block?.inputText(this, composing, isComposing: true);
    inputManager.composing = composing;
    selectState.clearSelect();
    updateInputMethodWindowPosition();
  }

  ///删除拼音
  void deleteComposing() {
    var composingLength = inputManager.composing?.text.length ?? 0;
    if (composingLength > 0) {
      var offset = cursorState.cursorPosition?.textPosition?.offset ?? 0;
      if (offset >= composingLength) {
        var block = cursorState.cursorPosition?.block;
        if (block != null) {
          block.deleteRange(TextPosition(offset: offset - composingLength),
              TextPosition(offset: offset));
          layoutCurrentBlock(block);
          updateCursor(
            block.getCursorPosition(
                TextPosition(offset: offset - composingLength)),
            applyUpdate: false,
          );
        }
      }
      inputManager.composing = null;
    }
  }

  ///输入法输入文字
  void onInputText(TextEditingValue text) {
    deleteComposing();
    deleteSelectRange();
    var block = cursorState.cursorPosition?.block;
    block?.inputText(this, text);
    record();
    showPopupTool(true);
    replaceWithTitleCheck();
    replaceWithLiCheck();
    replaceWithQuoteCheck();
  }

  void replaceWithTitleCheck() {
    var cursor = cursorState.cursorPosition;
    if (cursor == null) {
      return;
    }
    var block = cursor.block;
    if (block is! TextBlock) {
      return;
    }
    var cursorPos = cursor.textPosition?.offset;
    if (cursorPos == null) {
      return;
    }
    var text = block.textElement.getText();
    int level = 0;
    int levelIndex = -1;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == "#") {
        level++;
      } else if (text[i] == " ") {
        levelIndex = i;
        break;
      } else {
        return;
      }
    }
    if (level == 0 || levelIndex == -1) {
      return;
    }
    if (levelIndex + 1 != cursorPos) {
      return;
    }
    setSelection(
        block.getCursorPosition(const TextPosition(offset: 0))
          ..blockIndex = cursor.blockIndex,
        block.getCursorPosition(TextPosition(offset: levelIndex + 1))
          ..blockIndex = cursor.blockIndex);
    deleteSelectRange();
    setTextLevel(level);
  }

  // markdown 语法识别
  void replaceWithLiCheck() {
    var cursor = cursorState.cursorPosition;
    if (cursor == null) {
      return;
    }
    var block = cursor.block;
    if (block is! TextBlock) {
      return;
    }
    var cursorPos = cursor.textPosition?.offset;
    if (cursorPos == null) {
      return;
    }
    var text = block.textElement.getText();
    // check识别
    if (text.startsWith("-")) {
      if (text.length < 2) {
        return;
      }
      if (cursorPos != 2) {
        return;
      }

      if (text[0] != "-") {
        return;
      }
      if (text[1] != " ") {
        return;
      }
      setSelection(
          block.getCursorPosition(TextPosition(offset: 0))
            ..blockIndex = cursor.blockIndex,
          block.getCursorPosition(TextPosition(offset: 2))
            ..blockIndex = cursor.blockIndex);
      deleteSelectRange();
      setItemType(itemType: "li");
    }
    // 有序列表识别
    if (text.startsWith("1.")) {
      if (cursorPos != 3) {
        return;
      }
      if (text[2] != " ") {
        return;
      }
      setSelection(
          block.getCursorPosition(TextPosition(offset: 0))
            ..blockIndex = cursor.blockIndex,
          block.getCursorPosition(TextPosition(offset: 3))
            ..blockIndex = cursor.blockIndex);
      deleteSelectRange();
      setItemType(itemType: "oli");
    }
  }

  void replaceWithQuoteCheck() {
    var cursor = cursorState.cursorPosition;
    if (cursor == null) {
      return;
    }
    var block = cursor.block;
    if (block is! TextBlock) {
      return;
    }
    var cursorPos = cursor.textPosition?.offset;
    if (cursorPos == null) {
      return;
    }
    var text = block.textElement.getText();
    if (text.length < 2) {
      return;
    }
    if (cursorPos != 2) {
      return;
    }
    if (text[0] != ">") {
      return;
    }
    if (text[1] != " ") {
      return;
    }
    setSelection(
        block.getCursorPosition(TextPosition(offset: 0))
          ..blockIndex = cursor.blockIndex,
        block.getCursorPosition(TextPosition(offset: 2))
          ..blockIndex = cursor.blockIndex);
    deleteSelectRange();
    changeTextToQuote();
  }

  bool replaceWithCodeCheck() {
    var cursor = cursorState.cursorPosition;
    if (cursor == null) {
      return false;
    }
    var block = cursor.block;
    if (block is! TextBlock) {
      return false;
    }
    var cursorPos = cursor.textPosition?.offset;
    if (cursorPos == null) {
      return false;
    }
    var text = block.textElement.getText();
    if (text.length < 3) {
      return false;
    }
    if (cursorPos != text.length) {
      return false;
    }
    if (!(text.startsWith("```") || text.startsWith("···"))) {
      return false;
    }
    for (var i = 3; i < text.length; i++) {
      if (!text[i].contains(RegExp("[a-zA-Z0-9]"))) {
        return false;
      }
    }
    var lan = text.substring(3);
    setSelection(
        block.getCursorPosition(TextPosition(offset: 0))
          ..blockIndex = cursor.blockIndex,
        block.getCursorPosition(TextPosition(offset: text.length))
          ..blockIndex = cursor.blockIndex);
    deleteSelectRange();
    toggleCode(language: lan);
    return true;
  }

  void showPopupTool([bool input = false]) {
    popupTool.show(input);
  }

  ///光标删除
  void deleteCursor(bool backspace) {
    if (!backspace) {
      var cursor = cursorState.cursorPosition;
      toRight();
      if (cursor == cursorState.cursorPosition) {
        return;
      }
    }
    var cursorPosition = cursorState.cursorPosition;
    if (cursorPosition == null) {
      return;
    }
    var textPosition = cursorPosition.textPosition;
    var block = cursorPosition.block;
    if (textPosition == null || block == null) {
      return;
    }
    int blockIndex = blockManager.indexOfBlockByBlock(block);
    if (blockIndex == -1) {
      return;
    }
    //text position==0
    if (textPosition.offset == 0) {
      if (block.isEmpty) {
        if (block.needClearStyle) {
          String type = "text";
          if (block.element.type == "quote") {
            type = "quote";
          }
          blockManager.blocks[blockIndex] = TextBlock(
              editController: this,
              context: viewContext,
              textElement: WenTextElement(
                indent: block.element.indent,
                type: type,
              ))
            ..top = block.top;
          layoutCurrentBlock(blockManager.blocks[blockIndex]);
          refreshCursorPosition();
          return;
        }
      }
      if (blockIndex == 0) {
        //text position 和 index 都为 0，无法删除,闪烁一下光标即可
        if (block.isEmpty) {
          block = TextBlock(
              editController: this,
              context: viewContext,
              textElement: WenTextElement())
            ..top = block.top;
          blockManager.blocks[blockIndex] = block;
          blockManager.layoutBlockRange(viewContext, blockIndex, blockIndex,
              Size(blockMaxWidth, visionHeight));
          toPosition(blockManager.blocks[blockIndex].startCursorPosition, true);
          updateWidgetState();
        } else {
          updateCursor(cursorPosition, applyUpdate: true);
        }
      } else {
        if (block.isEmpty) {
          //空白block，直接删除即可
          blockManager.blocks.removeRange(blockIndex, blockIndex + 1);
          blockManager.layoutBlockRange(viewContext, blockIndex - 1,
              blockIndex - 1, Size(blockMaxWidth, visionHeight));
          toPosition(
              blockManager.blocks[blockIndex - 1].endCursorPosition, true);
        } else if (blockManager.blocks[blockIndex - 1].isEmpty) {
          //前面是空白block，直接删除前面即可
          var y = blockManager.blocks[blockIndex - 1].top;
          blockManager.blocks[blockIndex].top = y;
          blockManager.blocks.removeRange(blockIndex - 1, blockIndex);
          blockManager.layoutBlockRange(viewContext, blockIndex - 1,
              blockIndex - 1, Size(blockMaxWidth, visionHeight));
          toPosition(cursorPosition, true);
        } else {
          //合并后删除对应的block
          var preBlock = blockManager.blocks[blockIndex - 1];
          var newPosition = preBlock.endPosition;
          var merge = preBlock.mergeBlock(block);
          if (merge != null) {
            preBlock = merge;
            blockManager.blocks[blockIndex - 1] = preBlock;
            blockManager.blocks.removeRange(blockIndex, blockIndex + 1);
            blockManager.layoutBlockRange(viewContext, blockIndex - 1,
                blockIndex - 1, Size(blockMaxWidth, visionHeight));
          }
          toPosition(preBlock.getCursorPosition(newPosition), true);
        }
      }
    } else {
      //text position!=0
      int deleteLength = block.deletePosition(textPosition);
      if (block.isEmpty && !block.canEmpty) {
        block = TextBlock(
            editController: this,
            context: viewContext,
            textElement: WenTextElement())
          ..top = block.top;
        blockManager.blocks[blockIndex] = block;
      }
      blockManager.layoutBlockRange(viewContext, blockIndex, blockIndex,
          Size(blockMaxWidth, visionHeight));
      var cursor = block.getCursorPosition(
          TextPosition(offset: textPosition.offset - deleteLength));
      toPosition(cursor, true);
    }
  }

  void setSelection(CursorPosition? start, CursorPosition? end) {
    selectState.start = start;
    selectState.end = end;
    onSelectChanged();
    updateWidgetState();
  }

  ///删除选择的内容
  void deleteSelectRange() {
    if (!selectState.hasSelectRange) {
      return;
    }
    var start = selectState.realStart!;
    var end = selectState.realEnd!;
    var startBlock = start.block;
    var endBlock = end.block;
    var startPosition = start.textPosition;
    var endPosition = end.textPosition;
    if (startBlock == null ||
        endBlock == null ||
        startPosition == null ||
        endPosition == null) {
      return;
    }
    var startBlockIndex = blockManager.indexOfBlockByBlock(startBlock);
    var endBlockIndex = blockManager.indexOfBlockByBlock(endBlock);
    if (startBlockIndex == -1 || endBlockIndex == -1) {
      return;
    }
    var startBlockTextType = "text";
    if (startBlock is TextBlock) {
      startBlockTextType = startBlock.element.type;
    }
    if (startBlockIndex == endBlockIndex) {
      //删除选择内容即可
      startBlock.deleteRange(startPosition, endPosition);
      if (startBlock.isEmpty && !endBlock.canEmpty) {
        startBlock = TextBlock(
            editController: this,
            textElement: WenTextElement(),
            context: viewContext)
          ..top = startBlock.top;
        blockManager.blocks[startBlockIndex] = startBlock;
      }
    } else {
      //删除左block内容
      startBlock.deleteRange(startPosition, startBlock.endPosition);
      if (startBlock.isEmpty) {
        startBlock = TextBlock(
            editController: this,
            textElement: WenTextElement(type: startBlockTextType),
            context: viewContext)
          ..top = startBlock.top;
        blockManager.blocks[startBlockIndex] = startBlock;
      }
      //删除右block选择内容
      endBlock.deleteRange(endBlock.startPosition, endPosition);
      if (endBlock.isEmpty) {
        endBlock = TextBlock(
            editController: this,
            textElement: WenTextElement(type: startBlockTextType),
            context: viewContext)
          ..top = endBlock.top;
        blockManager.blocks[endBlockIndex] = endBlock;
      }
      //合并2个block
      int removeStart = startBlockIndex + 1;
      int removeEnd = endBlockIndex - 1;
      var merge = startBlock.mergeBlock(endBlock);
      if (merge != null) {
        //删除end block
        removeEnd = endBlockIndex;
        blockManager.blocks[startBlockIndex] = merge;
      }
      //删除需要删除的整个block
      if (removeStart <= removeEnd) {
        blockManager.blocks.removeRange(removeStart, removeEnd + 1);
      }
    }
    //重新布局
    blockManager.layoutBlockRange(viewContext, startBlockIndex,
        startBlockIndex + 1, Size(blockMaxWidth, visionHeight));
    //刷新光标位置
    var cursor = blockManager.blocks[startBlockIndex]
        .getCursorPosition(start.textPosition!);
    toPosition(cursor, true);
  }

  ///在光标位置插入blocks或者文字
  void insertContent(List<WenzBlock>? insertBlocks, String? insertText) {
    if (insertBlocks == null || insertBlocks.isEmpty) {
      if (insertText == null || insertText == "") {
        return;
      }
      insertBlocks = parseTextToBlock(insertText);
    }
    insertBlocks = TextUtils.dealInsertBlocks(this, insertBlocks);
    deleteSelectRange();
    var cursor = cursorState.cursorPosition;
    if (cursor == null) {
      return;
    }
    var cursorBlock = cursor.block;
    if (cursorBlock == null) {
      return;
    }
    var textPosition = cursor.textPosition;
    if (textPosition == null) {
      return;
    }
    var blockIndex = blockManager.indexOfBlockByBlock(cursorBlock);
    if (cursorBlock is TextBlock) {
      WenzBlock newCursorBlock = insertBlocks.last;
      TextPosition newCursorPosition = insertBlocks.last.endPosition;
      var splitBlock = cursorBlock.splitBlock(textPosition);
      if (!splitBlock.isEmpty) {
        var last = insertBlocks.removeLast();
        var merge = last.mergeBlock(splitBlock);
        if (merge != null) {
          insertBlocks.add(merge);
          newCursorBlock = merge;
        } else {
          insertBlocks.add(last);
          insertBlocks.add(splitBlock);
        }
      }
      var first = insertBlocks.removeAt(0);
      int len = cursorBlock.length;
      var merge = cursorBlock.mergeBlock(first);
      if (merge != null) {
        blockManager.blocks[blockIndex] = merge;
        cursorBlock = merge;
        if (insertBlocks.isNotEmpty) {
          blockManager.blocks.insertAll(blockIndex + 1, insertBlocks);
        } else {
          newCursorPosition =
              TextPosition(offset: newCursorPosition.offset + len);
          newCursorBlock = merge;
        }
        layoutBlock(
            cursorBlock, blockIndex, blockIndex + insertBlocks.length + 1);
        toPosition(newCursorBlock.getCursorPosition(newCursorPosition), true);
      } else {
        if (cursorBlock.isEmpty) {
          first.top = blockManager.blocks
              .removeAt(blockIndex)
              .top;
          blockManager.blocks.insert(blockIndex, first);
          if (insertBlocks.isNotEmpty) {
            blockManager.blocks.insertAll(blockIndex + 1, insertBlocks);
          }
        } else {
          blockManager.blocks.insert(blockIndex + 1, first);
          if (insertBlocks.isNotEmpty) {
            blockManager.blocks.insertAll(blockIndex + 2, insertBlocks);
          }
        }
        layoutBlock(
            cursorBlock, blockIndex, blockIndex + insertBlocks.length + 1);
        if (insertBlocks.isEmpty) {
          toPosition(first.endCursorPosition, true);
        } else {
          toPosition(newCursorBlock.getCursorPosition(newCursorPosition), true);
        }
      }
    } else if (cursorBlock is ImageBlock) {
      if (cursorBlock.isEmpty) {
        blockManager.blocks.removeAt(blockIndex);
      }
      if (textPosition.offset == 0) {
        //在前面插入
        blockManager.blocks.insertAll(blockIndex, insertBlocks);
        if (blockIndex == 0) {
          layoutBlock(
              cursorBlock, blockIndex, blockIndex + insertBlocks.length + 1);
        } else {
          layoutBlock(cursorBlock, blockIndex - 1,
              blockIndex + insertBlocks.length + 1);
        }
        toPosition(insertBlocks.last.endCursorPosition, true);
      } else {
        //在后面插入
        blockManager.blocks.insertAll(blockIndex + 1, insertBlocks);
        layoutBlock(
            cursorBlock, blockIndex, blockIndex + insertBlocks.length + 1);
        toPosition(insertBlocks.last.endCursorPosition, true);
      }
    } else if (cursorBlock is TableBlock) {
      cursorBlock.insertContent(insertBlocks);
    } else {
      cursorBlock.inputText(this, TextEditingValue(text: insertText ?? ""));
    }
  }

  List<WenzBlock> parseTextToBlock(String insertText) {
    var lines = insertText.replaceAll("\r", "").split("\n");
    return [
      for (var line in lines)
        TextBlock(
            editController: this,
            context: viewContext,
            textElement: WenTextElement(
              text: line,
            )),
    ];
  }

  ///改变textBlock的大纲级别
  void setTextLevel(int level) {
    var cursor = cursorState.cursorPosition;
    if (cursor == null || cursor.block == null) {
      return;
    }
    var cursorBlockIndex = blockManager.indexOfBlockByBlock(cursor.block!);
    var blocks = [];
    if (selectState.hasSelect) {
      var start = selectState.realStart?.block;
      var end = selectState.realEnd?.block;
      if (start != null && end != null) {
        var startIndex = blockManager.indexOfBlockByBlock(start);
        var endIndex = blockManager.indexOfBlockByBlock(end);
        for (var i = startIndex; i <= endIndex; i++) {
          blocks.add(blockManager.blocks[i]);
        }
      } else {
        blocks.add(cursor.block);
      }
    } else {
      blocks.add(cursor.block);
    }
    var changeToLevel0 = true;
    for (var block in blocks) {
      if (block is TextBlock) {
        if (block.textElement.level != level) {
          changeToLevel0 = false;
          break;
        }
      }
    }
    if (changeToLevel0) {
      level = 0;
    }
    for (var block in blocks) {
      if (block is TextBlock) {
        var blockIndex = blockManager.indexOfBlockByBlock(block);
        var element = block.textElement;
        if (level == 0) {
          if (element.type != "quote") {
            element.type = "text";
          }
          element.level = 0;
          element.fontSize = null;
          blockManager.blocks[blockIndex] = TextBlock(
              editController: this, textElement: element, context: viewContext)
            ..top = block.top
            ..height = block.height;
        } else {
          if (element.type != "quote") {
            element.type = "title";
          }
          element.fontSize = null;
          element.level = level;
          blockManager.blocks[blockIndex] = TitleBlock(
            editController: this,
            textElement: element,
            context: viewContext,
          )
            ..top = block.top
            ..height = block.height;
        }
        var newBlock = blockManager.blocks[blockIndex];
        layoutCurrentBlock(newBlock);
      }
    }
    updateSelectCursor();
    var textPosition = cursor.textPosition;
    if (textPosition != null) {
      updateCursor(
          blockManager.blocks[cursorBlockIndex].getCursorPosition(textPosition),
          scrollToShowCursor: false,
          applyUpdate: false);
    }
    updateWidgetState();
  }

  ///改变文字为引用型
  void changeTextToQuote() {
    var startBlockIndex = currentStartBlockIndex;
    var endBlockIndex = currentEndBlockIndex;
    if (startBlockIndex != -1 && endBlockIndex != -1) {
      bool allIsQuote = true;
      for (var i = startBlockIndex; i <= endBlockIndex; i++) {
        var block = blockManager.blocks[i];
        if (block is TextBlock) {
          if (block.element.type != "quote") {
            allIsQuote = false;
          }
        }
      }
      for (var i = startBlockIndex; i <= endBlockIndex; i++) {
        var block = blockManager.blocks[i];
        if (block is TextBlock) {
          if (allIsQuote) {
            block.element.type = "text";
            if (block.element.level > 0) {
              block.element.type = "title";
            }
          } else {
            block.element.type = "quote";
          }
          block.relayoutFlag = true;
        }
      }
      layoutBlock(
          blockManager.blocks[startBlockIndex], startBlockIndex, endBlockIndex);
      updateWidgetState();
      refreshCursorPosition();
    }
  }

  ///添加代码block
  ///如果当前block为空，则将当前block转为code bock
  ///如果当前block部位空，则在下方插入code block
  void addCodeBlock({String code = "", String language = ""}) {
    var cPos = cursorState.cursorPosition;
    var cBlock = cPos?.block;
    var ctPos = cPos?.textPosition;
    if (cBlock != null && ctPos != null) {
      var blockIndex = blockManager.indexOfBlock(cBlock.top);
      var codeBlock = CodeBlock(
          editController: this,
          element: WenCodeElement(
            code: code,
            language: language,
          ),
          context: viewContext);
      if (cBlock.isEmpty) {
        blockManager.blocks[blockIndex] = codeBlock;
        codeBlock.top = cBlock.top;
        layoutCurrentBlock(codeBlock);
        refreshCursorPosition();
      } else {
        blockManager.blocks.insert(blockIndex + 1, codeBlock);
        layoutCurrentBlock(cBlock);
        updateCursor(
          codeBlock.startCursorPosition,
          scrollToShowCursor: true,
          applyUpdate: true,
        );
      }
    }
  }

  void addBlock(WenzBlock block) {
    var cPos = cursorState.cursorPosition;
    var cBlock = cPos?.block;
    var ctPos = cPos?.textPosition;
    if (cBlock != null && ctPos != null) {
      var blockIndex = blockManager.indexOfBlock(cBlock.top);
      if (cBlock.isEmpty) {
        blockManager.blocks[blockIndex] = block;
        block.top = cBlock.top;
        layoutCurrentBlock(block);
        refreshCursorPosition();
      } else {
        blockManager.blocks.insert(blockIndex + 1, block);
        layoutCurrentBlock(cBlock);
        updateCursor(
          block.startCursorPosition,
          scrollToShowCursor: true,
          applyUpdate: true,
        );
      }
    }
  }

  ///添加文字block
  void addTextBlock() {
    var cPos = cursorState.cursorPosition;
    var cBlock = cPos?.block;
    var ctPos = cPos?.textPosition;
    selectState.clearSelect();
    if (cBlock != null && ctPos != null) {
      var blockIndex = blockManager.indexOfBlock(cBlock.top);
      var textBlock = TextBlock(
          editController: this,
          textElement: WenTextElement(),
          context: viewContext);
      textBlock.top = cBlock.top + cBlock.height;
      blockManager.blocks.insert(blockIndex + 1, textBlock);
      layoutCurrentBlock(textBlock);
      updateCursor(textBlock.startCursorPosition,
          scrollToShowCursor: true, applyUpdate: true);
      record();
    }
  }

  ///添加文字block
  void addTextBlockBefore() {
    var cPos = cursorState.cursorPosition;
    var cBlock = cPos?.block;
    var ctPos = cPos?.textPosition;
    selectState.clearSelect();
    if (cBlock != null && ctPos != null) {
      var blockIndex = blockManager.indexOfBlock(cBlock.top);
      var textBlock = TextBlock(
          editController: this,
          textElement: WenTextElement(),
          context: viewContext);
      textBlock.top = cBlock.top;
      blockManager.blocks.insert(blockIndex, textBlock);
      layoutCurrentBlock(textBlock);
      updateCursor(textBlock.startCursorPosition,
          scrollToShowCursor: true, applyUpdate: true);
      record();
    }
  }

  ///1.将选择文字创建链接
  ///2.弹出窗口添加链接
  void addLink() {
    var linkController = TextEditingController(text: "");
    var textController = TextEditingController(text: "");
    var ok = false;
    showMobileDialog(
        context: viewContext,
        builder: (context) {
          return Container(
            padding: MediaQuery
                .of(context)
                .viewInsets,
            child: AlertDialog(
              title: const Text("添加链接"),
              content: SizedBox(
                width: isMobile ? 300 : 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(
                        bottom: 10,
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "请输入链接文字",
                        ),
                        autofocus: true,
                        onSubmitted: (s) {
                          ok = true;
                          Navigator.pop(context, '取消');
                        },
                        controller: textController,
                      ),
                    ),
                    Container(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "http://",
                        ),
                        controller: linkController,
                        onSubmitted: (s) {
                          ok = true;
                          Navigator.pop(context, '取消');
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('取消'),
                  onPressed: () {
                    Navigator.pop(context, '取消');
                    // Delete file here
                  },
                ),
                FilledButton(
                    onPressed: () {
                      ok = true;
                      Navigator.pop(context, '确定');
                    },
                    child: const Text("确定")),
              ],
            ),
          );
        }).then((value) {
      if (ok && linkController.text.isNotEmpty) {
        var link = linkController.text;
        var text = textController.text;
        if (text.isEmpty) {
          text = link;
        }
        insertContent([
          TextBlock(
              editController: this,
              context: viewContext,
              textElement: WenTextElement(
                children: [
                  WenTextElement(
                    text: text,
                    url: link,
                  ),
                ],
              ))
        ], null);
        record();
      }
    });
  }

  /// 对文字设置链接
  void setLink() {
    var linkController = TextEditingController(text: "");
    var textController = TextEditingController(text: getSelectText());
    var ok = false;
    showMobileDialog(
        context: viewContext,
        builder: (context) {
          return Container(
            padding: MediaQuery
                .of(context)
                .viewInsets,
            child: AlertDialog(
              title: const Text("添加链接"),
              content: SizedBox(
                width: isMobile ? 300 : 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 10, top: 10),
                      child: TextField(
                        decoration: const InputDecoration(
                            hintText: "请输入链接文字"),
                        onSubmitted: (inputText) {
                          ok = true;
                          Navigator.pop(context, '取消');
                        },
                        controller: textController,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        autofocus: true,
                        decoration: const InputDecoration(hintText: "http://"),
                        controller: linkController,
                        onSubmitted: (s) {
                          ok = true;
                          Navigator.pop(context, '取消');
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  child: const Text('取消'),
                  onPressed: () {
                    Navigator.pop(context, '取消');
                    // Delete file here
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    ok = true;
                    Navigator.pop(context, '确定');
                  },
                  child: const Text("确定"),
                ),
              ],
            ),
          );
        }).then((value) {
      if (ok && linkController.text.isNotEmpty) {
        var selectElement = selectState.start?.block?.element;
        WenTextElement? textElement;
        if (selectElement is WenTextElement) {
          textElement = selectElement;
        } else if (selectElement is WenTableElement) {
          var tableBlock = selectState.start?.block as TableBlock;
          textElement =
              tableBlock.getTextElement(selectState.start!.textPosition!);
        } else {
          return;
        }
        if (textElement == null) {
          return;
        }
        var link = linkController.text;
        var text = textController.text;
        var linkElement = textElement.copyStyle(null, [
          WenTextElement(
            text: text,
            url: link,
          ),
        ]);
        delete(false);
        if (text.isEmpty) {
          text = link;
        }
        insertContent([
          textElement.level == 0
              ? TextBlock(
              editController: this,
              context: viewContext,
              textElement: linkElement)
              : TitleBlock(
              editController: this,
              context: viewContext,
              textElement: linkElement),
        ], null);
        record();
      }
    });
  }

  void setTableBlockItemType(TableBlock block, String itemType) {
    block.setItemType(itemType: itemType);
  }

  ///1.将选择行转为listitem
  ///2.将当前行转未listitem
  void setItemType({String itemType = "li"}) {
    int? startIndex = selectState.realStart?.blockIndex;
    int? endIndex = selectState.realEnd?.blockIndex;
    if (!selectState.hasSelect) {
      var block = cursorState.cursorPosition?.block;
      if (block == null) {
        return;
      }
      startIndex = endIndex = blockManager.indexOfBlockByBlock(block);
    }
    if (itemType == "check" && startIndex != null && startIndex == endIndex) {
      var block = blockManager.blocks[startIndex];
      if (block is TableBlock) {
        setTableBlockItemType(block, "check");
        return;
      }
    }
    if (startIndex != null && endIndex != null) {
      if (blockManager.blocks.getRange(startIndex, endIndex + 1).any((item) {
        if (item is TextBlock) {
          return false;
        }
        return true;
      })) {
        return;
      }
      setFunction() {
        blockManager.blocks
            .getRange(startIndex!, endIndex! + 1)
            .forEach((block) {
          if (block is TextBlock && block is! TitleBlock) {
            var text = block.textElement;
            text.itemType = itemType;
            block.relayoutFlag = true;
          }
        });
      }

      unSetFunction() {
        blockManager.blocks
            .getRange(startIndex!, endIndex! + 1)
            .forEach((block) {
          if (block is TextBlock && block is! TitleBlock) {
            var text = block.textElement;
            text.itemType = "text";
            block.relayoutFlag = true;
          }
        });
      }

      if (blockManager.blocks.getRange(startIndex, endIndex + 1).any((block) {
        if (block is TextBlock) {
          return block.textElement.itemType != itemType;
        }
        return false;
      })) {
        setFunction.call();
      } else {
        unSetFunction.call();
      }
      layoutBlock(blockManager.blocks[startIndex], startIndex, endIndex);
      refreshCursorPosition();
      record();
    }
  }

  Future<void> addFormula() async {
    var formula = await showDialog(
      context: viewContext,
      builder: (context) {
        return const FormulaWidget();
      },
    );

    if (formula is Map && formula["formula"] != null) {
      insertContent([
        TextBlock(
          editController: this,
          context: viewContext,
          textElement: WenTextElement(children: [
            WenTextElement(
              itemType: "formula",
              text: formula["formula"],
            ),
          ]),
        ),
      ], null);
      record();
    }
  }

  void addTable(int rowCount, int colCount) async {
    List<List<WenTextElement>> rows = [];
    for (int i = 0; i < rowCount; i++) {
      List<WenTextElement> row = [];
      rows.add(row);
      for (int j = 0; j < colCount; j++) {
        row.add(WenTextElement());
      }
    }
    addBlock(TableBlock(
      editController: this,
      context: viewContext,
      tableElement: WenTableElement(rows: rows),
    ));
    record();
  }

  void addLine() {
    addBlock(LineBlock(
        context: viewContext, element: LineElement(), editController: this));
    record();
  }

  void addTableRowOnPrevious() {
    var curBlock = cursorState.cursorPosition?.block;
    if (curBlock is TableBlock) {
      curBlock.addRowOnPrevious();
    }
  }

  void addTableRowOnNext() {
    var curBlock = cursorState.cursorPosition?.block;
    if (curBlock is TableBlock) {
      curBlock.addRowOnNext();
    }
  }

  void addTableColOnPrevious() {
    var curBlock = cursorState.cursorPosition?.block;
    if (curBlock is TableBlock) {
      curBlock.addColOnPrevious();
    }
  }

  void addTableColOnNext() {
    var curBlock = cursorState.cursorPosition?.block;
    if (curBlock is TableBlock) {
      curBlock.addColOnNext();
    }
  }

  void deleteTableRow() {
    var curBlock = cursorState.cursorPosition?.block;
    if (curBlock is TableBlock) {
      curBlock.deleteRow();
    }
  }

  void deleteTableCol() {
    var curBlock = cursorState.cursorPosition?.block;
    if (curBlock is TableBlock) {
      curBlock.deleteCol();
    }
  }

  void deleteTable() {
    var curBlock = cursorState.cursorPosition?.block;
    if (curBlock is TableBlock) {
      curBlock.deleteTable();
    }
  }

  void deleteCode() {
    var curBlock = cursorState.cursorPosition?.block;
    if (curBlock is CodeBlock) {
      curBlock.deleteCode();
    }
  }

  /// 如果选择了内容，则将选择内容删除，把选择内容text转为代码块
  /// 如果没选择内容，如果当前位置为代码块，则将代码块转为文字
  void toggleCode({String language = ""}) {
    if (cursorState.cursorPosition?.isValid != true) {
      return;
    }
    //如果是code，则转为text
    var isCodeBlock = cursorState.cursorPosition?.block is CodeBlock;
    var codeBlockIndex = 0;
    if (isCodeBlock) {
      codeBlockIndex = cursorState.cursorPosition!.block!.blockIndex;
    }
    if (selectState.hasSelect) {
      isCodeBlock = (selectState.start?.block is CodeBlock) &&
          (selectState.start?.blockIndex == selectState.end?.blockIndex);
      if (isCodeBlock) {
        codeBlockIndex = selectState.start!.blockIndex!;
      }
    }
    if (isCodeBlock) {
      replaceBlock(
          codeBlockIndex,
          1,
          parseTextToBlock(
              (cursorState.cursorPosition?.block as CodeBlock).element.code));
      toPosition(blockManager.blocks[codeBlockIndex].startCursorPosition, true);
      record();
      return;
    }
    //不是code，转为code
    var code = getSelectText();
    if (!cursorState.cursorPosition!.block!.isEmpty) {
      enter();
      toLeft();
    }
    var block = cursorState.cursorPosition!.block!;
    var pos = cursorState.cursorPosition!.textPosition!.offset;
    var len = block.length;
    var blockIndex = block.blockIndex;
    if (block.isEmpty || pos >= len - 1) {
      addCodeBlock(code: code, language: language);
      toPosition(
          blockManager.blocks[block.isEmpty ? blockIndex : blockIndex + 1]
              .startCursorPosition,
          true);
    } else {
      replaceBlock(blockIndex, 0, [
        CodeBlock(
          element: WenCodeElement(code: code, language: language),
          context: viewContext,
          editController: this,
        )
      ]);
      toPosition(blockManager.blocks[blockIndex].startCursorPosition, true);
    }
    record();
  }

  void replaceBlock(int startIndex, int replaceCount, List<WenzBlock> blocks) {
    blockManager.blocks
        .replaceRange(startIndex, startIndex + replaceCount, blocks);
    if (blockManager.blocks.isEmpty) {
      blockManager.blocks.add(TextBlock(
          context: viewContext,
          editController: this,
          textElement: WenTextElement()));
    }
    var layoutStartIndex = max(startIndex - 1, 0);
    layoutBlock(blockManager.blocks[max(startIndex - 1, 0)], layoutStartIndex,
        startIndex + replaceCount);
  }

  void clearStyle() {
    formatText((block, element) => element.clearStyle());
  }

  ///1.对齐方式修改
  ///2.字体颜色修改
  ///3.字体背景颜色修改
  ///4.链接修改
  ///5.粗体、斜体、下划线、删除线
  ///
  void formatText(WenzElementVisitor visitor, {bool splitUrl = false}) {
    var start = selectState.realStart;
    var end = selectState.realEnd;
    if (!selectState.hasSelect) {
      start = end = cursorState.cursorPosition;
    }
    if (start == null || end == null) {
      return;
    }
    var startBlock = start.block!;
    var endBlock = end.block!;
    var startTextPos = start.textPosition!;
    var startTextPosDownStream = TextPosition(
        offset: startTextPos.offset, affinity: TextAffinity.downstream);
    var endTextPos = end.textPosition!;
    var endTextPosUpStream = TextPosition(
        offset: endTextPos.offset, affinity: TextAffinity.upstream);
    WenTextElement? startElement;
    WenTextElement? endElement;
    //对text element进行拆分处理
    if (startBlock is TextBlock) {
      startBlock.textElement.splitElementInterior(startTextPosDownStream,
          splitUrlElement: splitUrl);
    } else if (startBlock is TableBlock) {
      startBlock.splitElementInterior(startTextPosDownStream,
          splitUrlElement: splitUrl);
    }
    if (endBlock is TextBlock) {
      endBlock.textElement
          .splitElementInterior(endTextPosUpStream, splitUrlElement: splitUrl);
    } else if (endBlock is TableBlock) {
      endBlock.splitElementInterior(endTextPosUpStream,
          splitUrlElement: splitUrl);
    }
    //获取拆分后的首个text element和最后一个text element
    if (startBlock is TextBlock) {
      startElement = startBlock.textElement.getElement(startTextPosDownStream);
    }
    if (endBlock is TextBlock) {
      endElement = endBlock.textElement.getElement(endTextPosUpStream);
    }
    //处理首个 text element
    if (startElement != null) {
      visitor.call(startBlock, startElement);
    }
    //处理中间的 text element
    visitSelectElement((block, element) {
      if (element is! WenTextElement) {
        return;
      }
      if (block is TableBaseCell) {
        var table = TableBaseCell
            .of(block)
            .tableBlock;
        visitor.call(table, element);
        block.relayoutFlag = true;
      } else {
        if (block == startBlock &&
            startElement != null &&
            element.offset < startElement.offset) {
          return;
        } else if (block == endBlock &&
            endElement != null &&
            element.offset > endElement.offset) {
          return;
        }
        visitor.call(block, element);
      }
    });
    //处理最后一个 text element
    if (endElement != null) {
      visitor.call(endBlock, endElement);
    }
    var startBlockIndex =
        start.blockIndex ?? blockManager.indexOfBlockByBlock(startBlock);
    var endBlockIndex =
        end.blockIndex ?? blockManager.indexOfBlockByBlock(endBlock);
    for (var i = startBlockIndex; i <= endBlockIndex; i++) {
      var curBlock = blockManager.blocks[i];
      curBlock.relayoutFlag = true;
    }
    updateWidgetState();
    record();
  }

  void setTableAlignment(TableBlock block, String alignment) {
    block.setAlignment(alignment);
    record();
  }

  void updateFormula(TextBlock block, WenTextElement element, String formula) {
    element.text = formula;
    record();
    refreshCursorPosition();
  }

  void adjustTable(TableBlock tableBlock, int newRowCount, int newColCount) {
    tableBlock.rows =
        tableBlock.addJustRows(newRowCount, newColCount, viewContext);
    tableBlock.calcLength();
    tableBlock.tableElement.rows = tableBlock.rows
        .map((e) => e.map((cell) => cell.element).toList())
        .toList();
    layoutCurrentBlock(tableBlock);
    updateWidgetState();
    record();
  }

  void changeBlockChecked(TextBlock textBlock, bool? checked) {
    record();
  }

  void onSelectChanged() {}

  void setBold(bool? bold) {
    formatText((block, element) {
      if (element is WenTextElement) {
        element.bold = bold;
      }
    });
  }

  void setLineThrough(bool? lineThrough) {
    formatText((block, element) {
      if (element is WenTextElement) {
        element.lineThrough = lineThrough;
      }
    });
  }

  void setUnderline(bool? underline) {
    formatText((block, element) {
      if (element is WenTextElement) {
        element.underline = underline;
      }
    });
  }

  void setItalic(bool? italic) {
    formatText((block, element) {
      if (element is WenTextElement) {
        element.italic = italic;
      }
    });
  }

  void setBackgroundColor(int index, [bool isColor = false]) {
    formatText((block, element) {
      if (element is WenTextElement) {
        element.background = isColor ? index : defaultColors[index]?.value;
      }
    });
  }

  void setTextColor(int index, [bool isColor = false]) {
    formatText((block, element) {
      if (element is WenTextElement) {
        element.color = isColor ? index : defaultColors[index]?.value;
      }
    });
  }

  void onSystemInputText(TextEditingValue value,
      TextRange? replaceRange) async {
    if (!value.text.contains("\n")) {
      if (replaceRange != null) {
        if (!selectState.hasSelect) {
          var cursor = cursorState.cursorPosition;
          if (cursor != null) {
            var block = cursor.block!;
            var startOffset = cursor.textPosition!.offset -
                replaceRange.end +
                replaceRange.start;
            var start =
            block.getCursorPosition(TextPosition(offset: startOffset));
            selectState.start = start;
            selectState.end = cursor;
          }
        }
      }
      onInputText(value);
      return;
    }
    String? text;
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return;
    }
    final reader = await clipboard.read();
    if (reader.canProvide(Formats.plainText)) {
      try {
        text = await reader.readValue(Formats.plainText);
      } catch (e) {
        text = await Pasteboard.text;
      }
    }

    if (text == value.text) {
      paste();
    } else {
      onInputText(value);
    }
  }

  void updateCodeLanguage(CodeBlock codeBlock, String language) {
    codeBlock.element.language = language;
    codeBlock.relayoutFlag = true;
    updateWidgetState();
  }

  bool insertCol(TableBlock tableBlock, int rowIndex, int colIndex) {
    return false;
  }

  bool insertRow(TableBlock tableBlock, int rowIndex, int colIndex) {
    return false;
  }

  void onUpdateImageSize(ImageBlock block, double imageWidth,
      double imageHeight) {
    record();
  }
}

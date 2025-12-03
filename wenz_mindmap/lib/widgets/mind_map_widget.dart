import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:wenz_mindmap/controller/mind_doc_controller.dart';
import 'package:wenz_ui/drag/index.dart';
import 'package:wenz_ui/scroll/two_direction_scrollable.dart';
import 'package:wenz_ui/utils/device_util.dart';
import 'package:wenz_ui/utils/mvc.dart';
import 'package:wenz_editor/commons/util/image.dart';
import 'package:wenz_editor/commons/widget/ignore_parent_pointer.dart';
import 'package:wenz_editor/editor/widget/drag_resize_container.dart';
import '../mindmap.dart';

Widget defaultBuilder(BuildContext context, NodeEditController controller) {
  return XMindNodeWidget(
    key: ValueKey(controller.node.uuid),
    controller: controller,
    docRootDir: controller.controller.docRootDir,
  );
}

typedef OnNodeClick = void Function(MindNode node);

class MindMap extends StatefulWidget {
  final MindMapController controller;
  final NodeContentBuilder? nodeContentBuilder;
  final Color selectBorderColor;
  final Color unSelectBorderColor;
  final MindStyle style;
  final OnNodeClick? onNodeClick;

  const MindMap({
    super.key,
    required this.controller,
    this.style = const XMindStyle(),
    this.selectBorderColor = Colors.red,
    this.unSelectBorderColor = Colors.transparent,
    this.nodeContentBuilder = defaultBuilder,
    this.onNodeClick,
  });

  @override
  State<MindMap> createState() => MindMapState();
}

class MindMapState extends State<MindMap> {
  late MindMapController controller;

  // 选择框拖动时的滚动定时器
  Timer? autoScrollTimer;

  // 选择框拖动开始位置
  Offset? selectPanStartPosition;
  Offset? selectPanStartScrollOffset;

  // 选择框拖动结束位置
  Offset? selectPanEndPosition;
  Offset? selectPanEndScrollOffset;

  // 拖拽移动地图位置
  Offset? dragMovePanStartPosition;
  Offset? dragMovePanEndScrollOffset;

  // 选择框是否开始拖动
  bool isSelectPanStartStatus = false;

  // 选择框是否开始更新
  bool isSelectPanUpdateStatus = false;

  // 拖拽的节点
  List<MindNode> dragNodes = [];

  // 拖拽节点时的鼠标位置
  Offset? dragMousePosition;

  void startAutoScrollTimer() {
    autoScrollTimer ??= Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      updateSelectScrollPosition();
    });
  }

  void stopAutoScrollTimer() {
    autoScrollTimer?.cancel();
    autoScrollTimer = null;
  }

  @override
  void initState() {
    super.initState();
    controller = widget.controller;
    controller.addListener(onChanged);
  }

  @override
  void dispose() {
    super.dispose();
    controller.removeListener(onChanged);
  }

  void onChanged() {
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant MindMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller = oldWidget.controller;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.initTextStyle(context);
    if (controller.document?.style != widget.style) {
      controller.document?.style = widget.style;
      controller.layout();
    }
  }

  // 是否正在编辑
  bool get isUserEditing => controller.isEditing;

  @override
  Widget build(BuildContext context) {
    var rendBox = context.findRenderObject();
    if (rendBox is RenderBox) {
      controller.layoutState.viewBoundRect =
          rendBox.localToGlobal(Offset.zero) & rendBox.size;
    }
    return IgnoreParentMousePointerContainer(
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.hardEdge,
        child: FocusScope(
          onKey: (node, event) {
            return KeyEventResult.ignored;
          },
          child: Focus(
            focusNode: controller.focusNode,
            onFocusChange: (focus) {
              controller.focusState.updateState(focus);
            },
            includeSemantics: true,
            onKeyEvent: onKeyEvent,
            child: NotificationListener(
              onNotification: (notification) {
                if (notification is ScrollEndNotification) {
                  controller.scrollState.onScrollEnd();
                }
                if (notification is InputNotification) {
                  var editingValue = notification.value;
                  controller.hasComposing = editingValue.composing.isValid;
                }
                return false;
              },
              child: buildMouseDragMove(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildMouseDragMove(BuildContext context) {
    return Listener(
      onPointerDown: (details) {
        if (details.buttons == 2 || details.buttons == 4) {
          dragMovePanStartPosition = details.localPosition;
          dragMovePanEndScrollOffset = controller.scrollState.getScrollOffset();
        }
        if (controller.focusNode?.hasFocus == true) {
          return;
        }
        controller.focusNode?.requestFocus();
      },
      onPointerMove: (details) {
        if (details.buttons == 2 || details.buttons == 4) {
          var offset = details.localPosition - dragMovePanStartPosition!;
          controller.scrollState.jumpTo(dragMovePanEndScrollOffset! - offset);
        }
      },
      child: GestureDetector(
        onTapDown: (event) {
          if (isMobile) {
            if (!controller.isEditing) {
              controller.clearSelects();
            }
          }
        },
        onPanStart: (details) {
          startAutoScrollTimer();
          requestFocus();
          isSelectPanStartStatus = true;
          selectPanStartPosition = details.localPosition;
          selectPanEndPosition = details.localPosition;
          selectPanEndScrollOffset = selectPanStartScrollOffset = controller
              .scrollState
              .getScrollOffset();
          clearSelectNodes();
          setState(() {});
        },
        onPanUpdate: (details) {
          if (isSelectPanStartStatus) {
            isSelectPanUpdateStatus = true;
            selectPanEndPosition = details.localPosition;
            selectPanEndScrollOffset = controller.scrollState.getScrollOffset();
            calcSelectNodes();
            setState(() {});
          }
        },
        onPanCancel: () {
          stopAutoScrollTimer();
        },
        onPanEnd: (details) {
          stopAutoScrollTimer();
          if (isSelectPanStartStatus) {
            calcSelectNodes(true);
            isSelectPanUpdateStatus = false;
            isSelectPanStartStatus = false;
            setState(() {});
          }
          selectPanStartPosition = selectPanStartPosition = null;
          selectPanEndScrollOffset = selectPanStartScrollOffset = null;
        },
        child: buildDragTarget(context),
      ),
    );
  }

  Widget buildDragTarget(BuildContext context) {
    return DragTarget(
      onMove: (details) {
        if (details.data is! MindNode) {
          return;
        }
        setState(() {
          calcDragPosition(
            details.offset.translate(
              controller.dragLeftTopOffset.dx,
              controller.dragLeftTopOffset.dy,
            ),
          );
        });
      },
      onWillAcceptWithDetails: (details) {
        return details.data is MindNode;
      },
      onAcceptWithDetails: (details) {
        if (details.data is MindNode) {
          doDragMove();
        }
      },
      builder: (context, _, b) {
        return buildResizeListener(context, buildScrollable(context));
      },
    );
  }

  Widget buildScrollable(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        var contentSize = Size(cons.maxWidth, cons.maxHeight);
        controller.layoutState.viewSize = contentSize;
        return Stack(
          children: [
            TwoDirectionScrollable(
              verticalController: controller.scrollState.verticalController,
              horizontalController: controller.scrollState.horizontalController,
              onScrollZoomChanged: (focal, zoomDelta) {
                var scale1 = controller.scale;
                var scroll1 = controller.scrollState.getScrollOffset();
                if (zoomDelta < 0) {
                  controller.scale += 0.1;
                  if (controller.scale > 4) {
                    controller.scale = 4;
                  }
                } else {
                  controller.scale -= 0.1;
                  if (controller.scale < 0.4) {
                    controller.scale = 0.4;
                  }
                }
                var size = controller.layoutState.viewSize;
                if (size == null) {
                  return;
                }
                var scale2 = controller.scale;
                var scroll2 = scroll1 + (focal * scale2) - (focal * scale1);
                controller.layout();
                var rect = controller.root.getScrollRect(size, scale2);
                var xOffset = controller.scrollState.xOffset;
                var yOffset = controller.scrollState.yOffset;
                xOffset?.applyContentDimensions(rect.left, rect.right);
                yOffset?.applyContentDimensions(rect.top, rect.bottom);
                controller.scrollState.jumpTo(scroll2);
              },
              onScrollUpdate: () {
                if (isSelectPanStartStatus) {
                  setState(() {
                    selectPanEndScrollOffset = controller.scrollState
                        .getScrollOffset();
                  });
                }
              },
              onLayout: (size, xPosition, yPosition) {
                if (controller.needCalcScrollStatus) {
                  xPosition.applyViewportDimension(size.width);
                  yPosition.applyViewportDimension(size.height);
                  var rect = controller.root.getScrollRect(
                    size,
                    controller.scale,
                  );
                  xPosition.applyContentDimensions(rect.left, rect.right);
                  yPosition.applyContentDimensions(rect.top, rect.bottom);
                  controller.needCalcScrollStatus = false;
                }
              },
              contentBuilder: (context, xPosition, yPosition) {
                var widgets = <Widget>[];
                var toolWidgets = <Widget>[];
                var linePaths = <LinePath>[];
                if (controller.isDragEnable) {
                  var previousLinePath = controller.previewPosition
                      ?.getLinePath(
                        viewSize: contentSize,
                        xOffset: xPosition,
                        yOffset: yPosition,
                        nodeBorderWidth:
                            widget.style.selectBorderWidth * controller.scale,
                        verticalSpacing: controller.verticalSpacing,
                        horizontalSpacing: controller.horizontalSpacing,
                      );
                  var previousWidget = controller.previewPosition?.getWidget(
                    viewSize: contentSize,
                    xOffset: xPosition,
                    yOffset: yPosition,
                    nodeBorderWidth:
                        widget.style.selectBorderWidth * controller.scale,
                    verticalSpacing: controller.verticalSpacing,
                    horizontalSpacing: controller.horizontalSpacing,
                    scale: controller.scale,
                  );
                  if (previousLinePath != null) {
                    linePaths.add(previousLinePath);
                  }
                  if (previousWidget != null) {
                    widgets.add(previousWidget);
                  }
                }
                controller.root.buildWidgets(
                  scale: controller.scale,
                  context: context,
                  size: contentSize,
                  xOffset: xPosition,
                  yOffset: yPosition,
                  widgets: widgets,
                  toolWidgets: toolWidgets,
                  linePaths: linePaths,
                  nodeBorderWidth: widget.style.selectBorderWidth,
                  nodeBuilder: buildNodeWidget,
                  style: controller.document?.style,
                  onExpandChanged: (node) {
                    clearSelectNodes();
                    controller.toggleExpand(node);
                  },
                );
                if (controller.isDragEnable &&
                    controller.isDragMoving &&
                    dragNodes.isNotEmpty) {
                  for (var linePath in linePaths) {
                    linePath.isDragging = dragNodes.contains(linePath.node);
                  }
                }
                return GestureDetector(
                  onTap: () {
                    controller.closeEdit();
                    controller.clearSelects();
                  },
                  child: CustomPaint(
                    painter: LinePathPainter(linePaths: linePaths),
                    child: Stack(
                      children: [
                        ...widgets,
                        if (controller.isShowFloatToolbar) ...toolWidgets,
                      ],
                    ),
                  ),
                );
              },
            ),
            Container(child: buildPanRectWidget(context)),
          ],
        );
      },
    );
  }

  Widget? buildPanRectWidget(BuildContext context) {
    if (!isSelectPanUpdateStatus) {
      return null;
    }
    var offset = selectPanStartScrollOffset! - selectPanEndScrollOffset!;
    var startOffset = selectPanStartPosition!.translate(offset.dx, offset.dy);
    var endOffset = selectPanEndPosition!;
    var left = min(startOffset.dx, endOffset.dx);
    var top = min(startOffset.dy, endOffset.dy);
    var right = max(startOffset.dx, endOffset.dx);
    var bottom = max(startOffset.dy, endOffset.dy);
    var panRect = Rect.fromLTRB(left, top, right, bottom);
    return Positioned(
      left: panRect.left,
      top: panRect.top,
      width: panRect.width,
      height: panRect.height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          border: Border.all(color: Colors.blue),
        ),
      ),
    );
  }

  KeyEventResult onKeyEvent(FocusNode node, KeyEvent event) {
    if (controller.hasComposing) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        controller.hasComposing = false;
        if (Platform.isWindows) {
          controller.focusNode?.requestFocus();
          controller.selectState.selectNode?.closeEdit();
        }
      }
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (!isUserEditing && event.logicalKey == LogicalKeyboardKey.space) {
      controller.selectState.selectNode?.showEdit();
      return KeyEventResult.handled;
    }
    if (!isUserEditing && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      toLeft();
      return KeyEventResult.handled;
    }
    if (!isUserEditing && event.logicalKey == LogicalKeyboardKey.arrowRight) {
      toRight();
      return KeyEventResult.handled;
    }
    if (!isUserEditing && event.logicalKey == LogicalKeyboardKey.keyT) {
      toggleTodo();
      return KeyEventResult.handled;
    }
    if (isUserEditing && event.logicalKey == LogicalKeyboardKey.escape) {
      escape();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      toUp();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      toDown();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (isUserEditing) {
        controller.selectState.selectNode?.closeEdit();
        requestFocus();
        return KeyEventResult.handled;
      }
      enter();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        toLeft();
      } else {
        tab();
      }
      return KeyEventResult.handled;
    }
    if (!isUserEditing &&
        (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace)) {
      delete();
      return KeyEventResult.handled;
    }
    // 防止focus切换
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      return KeyEventResult.handled;
    }
    if (!isUserEditing && event.logicalKey == LogicalKeyboardKey.keyC) {
      if (HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isControlPressed) {
        controller.copy();
        return KeyEventResult.handled;
      }
    }
    if (!isUserEditing && event.logicalKey == LogicalKeyboardKey.keyV) {
      if (HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isControlPressed) {
        controller.paste(context);
        return KeyEventResult.handled;
      }
    }
    if (!isUserEditing && event.logicalKey == LogicalKeyboardKey.keyY) {
      if (HardwareKeyboard.instance.isControlPressed) {
        controller.redo();
        return KeyEventResult.handled;
      }
    }
    if (!isUserEditing && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if ((Platform.isMacOS && HardwareKeyboard.instance.isMetaPressed) ||
          HardwareKeyboard.instance.isControlPressed) {
        if (Platform.isMacOS && HardwareKeyboard.instance.isShiftPressed) {
          controller.redo();
        } else {
          controller.undo();
        }
        return KeyEventResult.handled;
      }
    }
    if (Platform.isMacOS) {
      if (!isUserEditing) {
        if (event.character != null) {
          controller.selectState.selectNode?.showEdit();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // 清除选中的节点
  void clearSelectNodes() {
    controller.selectState.selectNodes = [];
    controller.selectState.selectNode = null;
  }

  // 根据图中坐标，计算实际位置
  Offset getRelativeOffset(Offset offset) {
    return controller.root.getRootAnchorOffset(
      viewSize: context.size,
      offset: offset,
      xOffset: controller.scrollState.xOffset,
      yOffset: controller.scrollState.yOffset,
    );
  }

  // 计算拖拽节点时的左上角位置
  Offset calcDragTopLeftPosition(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    final RenderBox renderObject =
        this.context.findRenderObject()! as RenderBox;
    var result = renderObject.globalToLocal(position);
    controller.dragLeftTopOffset = result;
    return result;
  }

  Widget buildResizeListener(BuildContext context, Widget child) {
    return NotificationListener<ResizeStateNotification>(
      onNotification: (no) {
        controller.setChildResizeState(no.resizing);
        return true;
      },
      child: child,
    );
  }

  // 构建节点
  Widget buildNodeWidget(BuildContext context, MindNode node) {
    bool isSelected =
        node == controller.selectState.selectNode ||
        controller.selectState.selectNodes.contains(node);
    bool isDragItem =
        controller.isDragEnable &&
        controller.isDragMoving &&
        dragNodes.contains(node);
    var child = MouseRegion(
      key: ValueKey(node.uuid),
      cursor: SystemMouseCursors.click,
      child: Container(
        width: node.widgetSize.width / controller.scale,
        height: node.widgetSize.height / controller.scale,
        decoration: BoxDecoration(
          border: Border.all(
            width: widget.style.selectBorderWidth,
            color: isSelected
                ? widget.style.selectBorderColor
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: MindTreeNodeWidget(
          controller: controller,
          nodeWidgetBuilder: widget.nodeContentBuilder,
          onEditChanged: (value) {
            if (value) {
              controller.selectState.selectNode = node;
            }
            node.updateEditing(value);
          },
          onTapDown: () {
            if (controller.selectState.selectNode != node &&
                !controller.selectState.selectNodes.contains(node)) {
              controller.selectState.selectNodes = [];
            }
            setState(() {
              controller.selectState.selectNode = node;
              calcDragNodes();
            });
            // scrollToNode(node);
          },
          onTapUp: () {
            controller.selectState.selectNodes = [];
            setState(() {
              controller.selectState.selectNode = node;
              calcDragNodes();
            });
            // scrollToNode(node);
            // 打开子笔记
            var noteList = node.getExistChildNoteList(context);
            if (noteList.isNotEmpty) {
              controller.openChildNote(context, noteList.first, node);
            }
            widget.onNodeClick?.call(node);
          },
          onChanged: (value) {
            controller.updateNodeLabel(node, value);
            controller.scrollToNode(node);
          },
          node: node,
        ),
      ),
    );

    return (node.editing || controller.layoutState.isChildResizing)
        ? child
        : Opacity(
            opacity: isDragItem ? 0.4 : 1,
            child: MultiPlatformDraggable(
              data: node,
              isLongDrag: isMobile,
              dragAnchorStrategy: calcDragTopLeftPosition,
              onDragStarted: () {
                startAutoScrollTimer();
                var isSelected =
                    controller.selectState.selectNode == node ||
                    controller.selectState.selectNodes.contains(node);
                if (!isSelected) {
                  setState(() {
                    controller.selectState.selectNode = node;
                    controller.selectState.selectNodes = [];
                    calcDragNodes();
                  });
                }
              },
              onDraggableCanceled: (v, o) {
                stopAutoScrollTimer();
                setState(() {
                  controller.isDragMoving = false;
                  controller.previewPosition = null;
                });
              },
              onDragCompleted: () {
                stopAutoScrollTimer();
                setState(() {
                  controller.isDragMoving = false;
                  controller.previewPosition = null;
                });
              },
              feedback: MvcControllerProvider(
                controller: findController<MindDocController>(context),
                child: buildDragFeedback(context, node),
              ),
              child: child,
            ),
          );
  }

  // 更新布局，在节点变化时调用
  void updateLayout() {
    controller.layout();
  }

  void requestFocus() {
    FocusScope.of(context).requestFocus(controller.focusNode);
  }

  void tab() {
    controller.addChild();
  }

  void enter() {
    controller.addNext();
  }

  void toLeft() {
    controller.toLeft();
  }

  void toRight() {
    controller.toRight();
  }

  void toUp() {
    controller.toUp();
  }

  void toDown() {
    controller.toDown();
  }

  // 滚动到指定节点
  void scrollToNode(MindNode node) {
    controller.scrollToNode(node);
  }

  // 删除节点
  void delete() {
    controller.delete();
  }

  // 退出编辑
  void escape() {
    controller.closeEdit();
  }

  // 计算范围内选择的节点
  void calcSelectNodes([bool isSelectEnd = false]) {
    if (selectPanStartPosition == null || selectPanEndPosition == null) {
      return;
    }
    controller.selectState.selectNodes = [];
    var startOffset = selectPanStartPosition!.translate(
      selectPanStartScrollOffset!.dx,
      selectPanStartScrollOffset!.dy,
    );
    var endOffset = selectPanEndPosition!.translate(
      selectPanEndScrollOffset!.dx,
      selectPanEndScrollOffset!.dy,
    );
    var panRect = Rect.fromLTRB(
      min(startOffset.dx, endOffset.dx),
      min(startOffset.dy, endOffset.dy),
      max(startOffset.dx, endOffset.dx),
      max(startOffset.dy, endOffset.dy),
    );
    controller.root.visitExpandChildren((node) {
      var rect = node.getRootAnchorRect(
        viewSize: context.size ?? Size.zero,
        scale: controller.scale,
      );
      if (rect.overlaps(panRect)) {
        controller.selectState.selectNodes.add(node);
      }
    });
    if (isSelectEnd) {
      calcDragNodes();
    }
  }

  // 计算拖拽的节点：包括拖拽节点的子节点
  void calcDragNodes() {
    var selectChildren = controller.selectState.selectNodes.toSet();
    if (controller.selectState.selectNode != null) {
      selectChildren.add(controller.selectState.selectNode!);
    }
    var dragNodes = <MindNode>[];
    for (var node in selectChildren) {
      if (dragNodes.contains(node)) {
        continue;
      }
      node.visitExpandChildren((element) {
        dragNodes.add(element);
      });
    }
    this.dragNodes = dragNodes;
  }

  // 构建拖拽的节点视图
  Widget buildDragFeedback(BuildContext context, MindNode current) {
    var nodes = controller.selectState.selectNodes.toSet();
    if (controller.selectState.selectNode != null) {
      nodes.add(controller.selectState.selectNode!);
    }
    if (nodes.isEmpty || !nodes.contains(current)) {
      return Container();
    }
    var children = <Widget>[];
    var size = Size.zero;
    var rend = this.context.findRenderObject();
    if (rend is RenderBox && rend.hasSize) {
      size = rend.size;
    }
    for (var node in nodes) {
      var rect = node.getStackRect(
        viewSize: size,
        scale: controller.scale,
        xOffset: controller.scrollState.xOffset,
        yOffset: controller.scrollState.yOffset,
      );
      children.add(
        node.buildPositionNodeWidget(rect, controller.scale, buildNodeWidget),
      );
    }
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Material(
        color: Colors.transparent,
        child: Stack(children: children),
      ),
    );
  }

  // 拖到节点计算预移动进入的位置
  void calcDragPosition(Offset global) {
    var rendBox = context.findRenderObject();
    if (rendBox is RenderBox) {
      var position = rendBox.globalToLocal(global);
      dragMousePosition = position;
      var relative = getRelativeOffset(position);
      setState(() {
        controller.isDragMoving = true;
        controller.calcPreviewPosition(relative);
        if ((controller.selectState.selectNode == null &&
                controller.selectState.selectNodes.isEmpty) ||
            dragNodes.contains(controller.previewPosition?.parentNode)) {
          controller.previewPosition = null;
        }
      });
    }
  }

  // 移动节点
  void doDragMove() {
    if (!controller.isDragEnable) {
      return;
    }
    // 计算选择节点中的根节点
    if (dragNodes.isEmpty || controller.previewPosition == null) {
      setState(() {
        controller.previewPosition = null;
      });
      return;
    }
    var selectNodeSet = controller.selectState.selectNodes.toSet();
    if (controller.selectState.selectNode != null) {
      selectNodeSet.add(controller.selectState.selectNode!);
    }
    var roots = <MindNode>[];
    for (var node in selectNodeSet) {
      var parent = node.parent;
      if (parent == null || !dragNodes.contains(parent)) {
        roots.add(node);
      }
    }
    controller.dragMove(roots);
  }

  Future<List<MindNode>> getClipboardImages() async {
    var result = <MindNode>[];
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return result;
    }
    var fileManager = controller.fileManager;
    var dpr = MediaQuery.of(context).devicePixelRatio;
    var image = await Pasteboard.image;
    if (image != null) {
      var imageFile = await fileManager?.writeImage(image);
      var path = imageFile?.path;
      if (path != null) {
        var imageId = imageFile?.uuid;
        var size = await readImageFileSize(File(path));
        var node = MindNode(
          info: MindNodeInfo(
            image: imageId,
            imageWidth: size.width,
            imageHeight: size.height,
            imageShowWidth: size.width / dpr,
            imageShowHeight: size.height / dpr,
          ),
        );
        result.add(node);
      }
    }
    var files = await Pasteboard.files();
    for (var file in files) {
      if (file.endsWith(".png") ||
          file.endsWith(".gif") ||
          file.endsWith(".jpg") ||
          file.endsWith(".jpeg") ||
          file.endsWith(".bmp") ||
          file.endsWith(".webp") ||
          file.endsWith(".tif")) {
        var imageFile = await fileManager?.parseFile(file);
        var path = imageFile?.path;
        if (path != null) {
          var imageId = imageFile?.uuid;
          var size = await readImageFileSize(File(path));
          var node = MindNode(
            info: MindNodeInfo(
              image: imageId,
              imageWidth: size.width,
              imageHeight: size.height,
              imageShowWidth: size.width / dpr,
              imageShowHeight: size.height / dpr,
            ),
          );
          result.add(node);
        }
      }
    }
    return result;
  }

  void updateSelectScrollPosition() {
    if (isSelectPanUpdateStatus) {
      // 判断鼠标位置是否在边界点
      if (selectPanEndPosition != null) {
        jumpToMousePosition(selectPanEndPosition!);
      }
    } else {
      if (dragMousePosition != null) {
        jumpToMousePosition(dragMousePosition!);
      }
    }
  }

  void jumpToMousePosition(Offset position) {
    var viewSize =
        min(
          controller.layoutState.viewSize?.width ?? 0,
          controller.layoutState.viewSize?.height ?? 0,
        ) *
        0.1;
    var borderWidth = min(80, viewSize);
    var offset = controller.scrollState.getScrollOffset();
    var maxJumpDistance = 300.0;
    double? jumpX;
    if (position.dx < borderWidth) {
      var jumpDistance = (borderWidth - position.dx) * 2;
      jumpDistance = min(maxJumpDistance, jumpDistance);
      jumpX = max(
        offset.dx - jumpDistance,
        controller.scrollState.xScrollExtent.dx,
      );
    }
    if (position.dx > controller.layoutState.viewSize!.width - borderWidth) {
      var jumpDistance =
          (position.dx -
              (controller.layoutState.viewSize!.width - borderWidth)) *
          2;
      jumpDistance = min(maxJumpDistance, jumpDistance);
      jumpX = min(
        offset.dx + jumpDistance,
        controller.scrollState.xScrollExtent.dy,
      );
    }
    double? jumpY;
    if (position.dy < borderWidth) {
      var jumpDistance = (borderWidth - position.dy) * 2;
      jumpDistance = min(maxJumpDistance, jumpDistance);
      jumpY = max(
        offset.dy - jumpDistance,
        controller.scrollState.yScrollExtent.dx,
      );
    }
    if (position.dy > controller.layoutState.viewSize!.height - borderWidth) {
      var jumpDistance =
          (position.dy -
              (controller.layoutState.viewSize!.height - borderWidth)) *
          2;
      jumpDistance = min(maxJumpDistance, jumpDistance);
      jumpY = min(
        offset.dy + jumpDistance,
        controller.scrollState.yScrollExtent.dy,
      );
    }
    if (jumpX != null) {
      controller.scrollState.xOffset!.animateTo(
        jumpX,
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );
    }
    if (jumpY != null) {
      controller.scrollState.yOffset!.animateTo(
        jumpY,
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );
    }
  }

  void toggleTodo() {
    controller.toggleTodo();
  }
}

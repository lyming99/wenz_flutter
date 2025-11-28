import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:wenz_ui/utils/mvc.dart';
import 'package:wenz_ui/utils/device_util.dart';
import 'package:wenz_ui/utils/platform_utils.dart';
import 'package:wenz_ui/utils/image/image.dart';
import '../controller/mind_doc_controller.dart';
import '../mindmap.dart';

class PreviewPosition {
  MindNode parentNode;
  int positionIndex;

  PreviewPosition({required this.parentNode, required this.positionIndex});

  LinePath getLinePath({
    required Size viewSize,
    ViewportOffset? xOffset,
    ViewportOffset? yOffset,
    double nodeBorderWidth = 2,
    double verticalSpacing = 20,
    double horizontalSpacing = 50,
    double scale = 1.0,
  }) {
    var rootNode = parentNode.root;
    var horizontalOffset =
        viewSize.width * scale / 2 -
        rootNode.widgetPosition.dx -
        (xOffset?.pixels ?? 0);
    var verticalOffset =
        viewSize.height * scale / 2 -
        rootNode.widgetPosition.dy -
        (yOffset?.pixels ?? 0);
    var offset = Offset(horizontalOffset, verticalOffset);
    var start = (parentNode.widgetPosition & parentNode.widgetSize).centerRight
        .translate(offset.dx - nodeBorderWidth, offset.dy);

    var end = getChildNodeRect(
      width: 40 * scale,
      verticalSpacing: verticalSpacing,
      horizontalSpacing: horizontalSpacing,
    ).centerLeft.translate(offset.dx, offset.dy);
    return LinePath(
      scale: scale,
      start: start,
      end: end,
      color: parentNode.info?.backgroundColor?.toColor() ?? Colors.blue,
    );
  }

  Rect getChildNodeRect({
    double width = 40,
    double verticalSpacing = 20,
    double horizontalSpacing = 50,
  }) {
    Rect getAbsoluteRect() {
      var height = verticalSpacing - 4;
      var children = parentNode.children;
      if (children == null || children.isEmpty) {
        return Rect.fromLTWH(
          0,
          (parentNode.widgetSize.height / 2 - height / 2),
          width,
          height,
        );
      }
      var zeroRect = Rect.fromLTWH(0, -verticalSpacing + 2, width, height);
      for (var i = 0; i < positionIndex; i++) {
        var child = children[i];
        zeroRect = zeroRect.translate(
          0,
          child.nodeContentSize.height + verticalSpacing,
        );
      }
      return zeroRect;
    }

    var rect = getAbsoluteRect();
    var parentRect = parentNode.widgetPosition & parentNode.nodeContentSize;
    var xOffset =
        parentRect.left + parentNode.widgetSize.width + horizontalSpacing;
    var yOffset = parentRect.top;
    if (parentNode.children != null && parentNode.children!.isNotEmpty) {
      var first = parentNode.children!.first;
      yOffset =
          first.widgetPosition.dy -
          first.nodeContentSize.height / 2 +
          first.widgetSize.height / 2;
    }
    return rect.translate(xOffset, yOffset);
  }

  Widget getWidget({
    required Size viewSize,
    ViewportOffset? xOffset,
    ViewportOffset? yOffset,
    double nodeBorderWidth = 2,
    double verticalSpacing = 20,
    double horizontalSpacing = 50,
    double scale = 1.0,
  }) {
    var rootNode = parentNode.root;
    var horizontalOffset =
        viewSize.width * scale / 2 -
        rootNode.widgetPosition.dx -
        (xOffset?.pixels ?? 0);
    var verticalOffset =
        viewSize.height * scale / 2 -
        rootNode.widgetPosition.dy -
        (yOffset?.pixels ?? 0);
    var rect = getChildNodeRect(
      width: 40 * scale,
      verticalSpacing: verticalSpacing,
      horizontalSpacing: horizontalSpacing,
    ).translate(horizontalOffset, verticalOffset);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Container(
        color: parentNode.info?.backgroundColor?.toColor() ?? Colors.blue,
      ),
    );
  }
}

class CountIncrement {
  double count = 0;

  void increment(double value) {
    count += value;
  }
}

typedef NodeWidgetBuilder =
    Widget Function(BuildContext context, MindNode node);

/// 思维导图节点
/// 1.计算节点和子节点总大小 size
/// 2.计算布局左上角位置 zero position
/// 3.计算 node position
///   节点在 size 的左侧居中位置
/// 3.绘制
///   节点内容
///     边框
///     文字
///   绘制子节点线条
///   绘制展开/折叠按钮
class MindNode with ChangeNotifier {
  MindNode({this.children, this.info, this.depth = 0});

  MindNode.placeHolder() : info = MindNodeInfo();

  MindNode? parent;
  int depth = 0;
  List<MindNode>? children;
  MindNodeInfo? info;

  String? get uuid => info?.uuid;

  /// 节点的组件尺寸
  Size widgetSize = Size.zero;
  Size? _widgetSize;
  double? _childrenHeight;

  /// 节点包含子节点的尺寸
  Size nodeContentSize = Size.zero;

  /// 通过父节点的位置计算节点的位置
  Offset widgetPosition = Offset.zero;
  bool editing = false;
  bool hover = false;

  /// 是否为点击选中的节点，需要显示图片按钮
  bool tapSelected = false;
  int nodeCount = 0;

  bool get expand => info?.expand ?? true;

  set expand(bool value) {
    info?.expand = value;
  }

  Map<String, dynamic> moreInfo = {};

  int get childCount => children?.length ?? 0;

  bool get needLayout => _widgetSize == null;

  void markNeedLayout() {
    _widgetSize = null;
    info?.width = null;
    info?.height = null;
  }

  T? getProperty<T>(String key) {
    return moreInfo[key] as T?;
  }

  void setProperty<T>(String key, T? value) {
    moreInfo[key] = value;
  }

  @override
  int get hashCode => uuid?.hashCode ?? 0;

  @override
  bool operator ==(Object other) {
    if (other is! MindNode) {
      return false;
    }
    return uuid == other.uuid;
  }

  void layout({
    required double scale,
    required double verticalSpacing,
    required double horizontalSpacing,
    MindStyle? style,
    TextStyle? defaultTextStyle,
  }) {
    _calcDepth();
    _initParent();
    _calcSize(
      scale: scale,
      verticalSpacing: verticalSpacing,
      horizontalSpacing: horizontalSpacing,
      style: style,
      defaultTextStyle: defaultTextStyle,
    );
    _calcPosition(
      scale: scale,
      yIncrement: CountIncrement(),
      verticalSpacing: verticalSpacing,
      horizontalSpacing: horizontalSpacing,
    );
  }

  int getNodeCount() {
    int ans = 0;
    visitChildren((e) {
      ans++;
    });
    return ans;
  }

  void _calcDepth([int depth = 0]) {
    this.depth = depth;
    if (children != null && children!.isNotEmpty) {
      for (var child in children!) {
        child._calcDepth(depth + 1);
      }
    }
  }

  void _initParent([MindNode? parent]) {
    this.parent = parent;
    var nodeCount = 0;
    if (children != null && children!.isNotEmpty) {
      for (var child in children!) {
        child._initParent(this);
        nodeCount += child.nodeCount + 1;
      }
    }
    this.nodeCount = nodeCount;
  }

  Size _calcSize({
    required double scale,
    required double verticalSpacing,
    required double horizontalSpacing,
    MindStyle? style,
    TextStyle? defaultTextStyle,
  }) {
    var oldStyle = getProperty<MindStyle>("mindStyle");
    if (oldStyle != style) {
      _widgetSize = style?.getNodeSize(
        this,
        defaultTextStyle: defaultTextStyle,
      );
      setProperty("mindStyle", style);
    }
    var widgetSize =
        (_widgetSize ??
            style?.getNodeSize(this, defaultTextStyle: defaultTextStyle) ??
            _calcWidgetSize(defaultTextStyle: defaultTextStyle)) *
        scale;
    this.widgetSize = widgetSize;
    Size calcNodeSize() {
      if (expand && children != null && children!.isNotEmpty) {
        var childrenHeight = 0.0;
        var childWidth = 0.0;
        for (var child in children!) {
          var childSize = child._calcSize(
            scale: scale,
            verticalSpacing: verticalSpacing,
            horizontalSpacing: horizontalSpacing,
            style: style,
            defaultTextStyle: defaultTextStyle,
          );
          childrenHeight += childSize.height;
          var calcWidth = childSize.width + horizontalSpacing;
          if (childWidth < calcWidth) {
            childWidth = calcWidth;
          }
        }
        var verticalSpacingSize = verticalSpacing * (children!.length - 1);
        _childrenHeight = childrenHeight + verticalSpacingSize;
        return Size(
          widgetSize.width + childWidth,
          max(widgetSize.height, verticalSpacingSize + childrenHeight),
        );
      }
      return widgetSize;
    }

    nodeContentSize = calcNodeSize();
    return nodeContentSize;
  }

  Size _calcWidgetSize({TextStyle? defaultTextStyle}) {
    if (_widgetSize == null) {
      var width = info?.width;
      var height = info?.height;
      if (width != null && height != null) {
        return _widgetSize = Size(width, height);
      }
      measureWidgetSize(defaultTextStyle: defaultTextStyle);
    }
    return _widgetSize!;
  }

  Size measureWidgetSize({TextStyle? defaultTextStyle}) {
    var textStyle = const TextStyle();
    if (defaultTextStyle != null) {
      textStyle = defaultTextStyle.merge(textStyle);
    }
    var painter = TextPainter(
      text: TextSpan(text: info?.content, style: textStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    _widgetSize = Size(painter.size.width + 32, 48);
    info?.width = _widgetSize!.width;
    info?.height = _widgetSize!.height;
    return _widgetSize!;
  }

  /// 计算节点的位置
  void _calcPosition({
    required CountIncrement yIncrement,
    required double scale,
    double xOffset = 0,
    required double verticalSpacing,
    required double horizontalSpacing,
  }) {
    if (isLeaf || !expand) {
      if (parent?.children?.first == this) {
        var parentChildrenHeight = (parent?._childrenHeight ?? 0);
        var parentNodeContentHeight = parent?.nodeContentSize.height ?? 0;
        if (parentChildrenHeight < parentNodeContentHeight) {
          yIncrement.increment(
            (parentNodeContentHeight - parentChildrenHeight) / 2,
          );
        }
      }
      var yOffset = yIncrement.count;
      widgetPosition = Offset(xOffset, yOffset);
      yIncrement.increment(widgetSize.height + verticalSpacing);
    } else {
      for (var i = 0; i < children!.length; i++) {
        var child = children![i];
        child._calcPosition(
          yIncrement: yIncrement,
          xOffset: xOffset + widgetSize.width + horizontalSpacing,
          verticalSpacing: verticalSpacing,
          horizontalSpacing: horizontalSpacing,
          scale: scale,
        );
      }
      var first = children!.first;
      var end = children!.last;
      widgetPosition = Offset(
        xOffset,
        (first.widgetPosition.dy +
                    end.widgetPosition.dy +
                    end.widgetSize.height) /
                2 -
            widgetSize.height / 2,
      );
    }
  }

  bool get isLeaf => children == null || children!.isEmpty;

  MindNode get root {
    if (parent == null) {
      return this;
    }
    return parent!.root;
  }

  bool get isRoot => parent == null;

  MindNode? get previous {
    if (parent == null) {
      return null;
    }
    var index = parent!.children!.indexWhere((item) => item == this);
    if (index == -1) {
      return null;
    }
    if (index == 0) {
      if (parent!.children!.length > 1) {
        return parent!.children![1];
      } else {
        return parent!;
      }
    }
    return parent!.children!.elementAt(index - 1);
  }

  bool get isTodo => info?.isTodo == true;

  bool get hasSuffix => hasLink || hasNote;

  bool get hasLink => info?.link != null;

  bool get hasNote => info?.note != null;

  bool get isSingleSuffix => (hasLink && !hasNote) || (hasNote && !hasLink);

  String get linkTitle => info?.linkTitle ?? "";

  bool get isImage => info?.image != null;

  bool get isFormula => info?.formula != null;

  List<String> get childNoteList => info?.note?.split(",") ?? [];

  List<String> getExistChildNoteList(BuildContext context) {
    var mindDocController = findController<MindDocController>(context);
    List<String> nodes = [];
    for (var node in childNoteList) {
      var docPage = mindDocController?.isChildNoteExist(node);
      if (docPage == true) {
        nodes.add(node);
      }
    }
    return childNoteList;
  }

  String getNoteTitle(BuildContext context, String uuid) {
    var docTabController = findController<MindDocController>(context);
    var childTitle = docTabController?.getChildNoteTitle(uuid);
    if (childTitle != null) {
      return childTitle ?? "未命名";
    }
    return "默认笔记";
  }

  Rect getStackRect({
    required Size viewSize,
    required double scale,
    ViewportOffset? xOffset,
    ViewportOffset? yOffset,
  }) {
    var horizontalOffset =
        viewSize.width * scale / 2 -
        root.widgetPosition.dx -
        (xOffset?.pixels ?? 0);
    var verticalOffset =
        viewSize.height * scale / 2 -
        root.widgetPosition.dy -
        (yOffset?.pixels ?? 0);
    return Rect.fromLTWH(
      widgetPosition.dx + horizontalOffset,
      widgetPosition.dy + verticalOffset,
      widgetSize.width,
      widgetSize.height,
    );
  }

  void buildWidgets({
    required BuildContext context,
    required Size size,
    double scale = 1.0,
    ViewportOffset? xOffset,
    ViewportOffset? yOffset,
    required List<Widget> widgets,
    required List<Widget> toolWidgets,
    required List<LinePath> linePaths,
    NodeWidgetBuilder? nodeBuilder,
    Function(MindNode node)? onExpandChanged,
    double nodeBorderWidth = 2,
    MindStyle? style,
    bool buildAll = false,
  }) {
    var horizontalOffset =
        size.width * scale / 2 - widgetPosition.dx - (xOffset?.pixels ?? 0);
    var verticalOffset =
        size.height * scale / 2 - widgetPosition.dy - (yOffset?.pixels ?? 0);
    if (buildAll) {
      horizontalOffset = verticalOffset = 0;
    }
    var stackRect = (Offset.zero & size);
    visitExpandChildren((element) {
      var path =
          style?.buildParentPath(
            element,
            Offset(horizontalOffset, verticalOffset),
            scale,
          ) ??
          element.buildParentPath(
            Offset(horizontalOffset, verticalOffset),
            nodeBorderWidth,
            scale,
          );
      if (path != null) {
        linePaths.add(path);
      }
      var widgetRect = Rect.fromLTWH(
        element.widgetPosition.dx + horizontalOffset,
        element.widgetPosition.dy + verticalOffset,
        element.widgetSize.width,
        element.widgetSize.height,
      );
      if (buildAll || stackRect.overlaps(widgetRect)) {
        widgets.add(
          element.buildPositionNodeWidget(widgetRect, scale, nodeBuilder),
        );
        var tool = style?.buildToolWidget(element, scale, widgetRect);
        if (tool != null) {
          toolWidgets.add(tool);
        }
      }
      // expand button
      buildExpandWidget(
        element,
        style,
        widgetRect,
        stackRect,
        widgets,
        onExpandChanged,
        buildAll: buildAll,
        scale: scale,
      );
    });
  }

  void buildExpandWidget(
    MindNode element,
    MindStyle? style,
    Rect widgetRect,
    Rect stackRect,
    List<Widget> widgets,
    Function(MindNode node)? onExpandChanged, {
    bool buildAll = false,
    double scale = 1.0,
  }) {
    if (!element.isLeaf) {
      final buttonSize = (PlatformUtils.isMobile ? 32.0 : 24.0) * scale;
      var borderWidth = (style?.getBorderWidth(element) ?? 1) * scale;
      var marginWidth = (style?.getMargin(element) ?? 1) * scale;
      var selectBorderWidth = (style?.selectBorderWidth ?? 1) * scale;
      var offsetWidth = borderWidth + selectBorderWidth + marginWidth;
      var expandButtonRect =
          widgetRect.centerRight.translate(-offsetWidth, -buttonSize / 2) &
          Size(buttonSize + offsetWidth, buttonSize);
      if (buildAll || stackRect.overlaps(expandButtonRect)) {
        var pathColor = style?.getPathColor(element);
        var expandButtonBackgroundColor = style?.getExpandButtonColor(element);
        widgets.add(
          Positioned(
            top: expandButtonRect.top,
            left: expandButtonRect.left,
            width: expandButtonRect.width,
            height: expandButtonRect.height,
            child: ListenableBuilder(
              listenable: element,
              builder: (context, child) {
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (e) {
                    element.hover = true;
                    element.notifyListeners();
                  },
                  onExit: (e) {
                    element.hover = false;
                    element.notifyListeners();
                  },
                  child: Stack(
                    children: [
                      if (element.depth > 0 && !element.expand)
                        Positioned(
                          left: 0,
                          width: offsetWidth + 4.0 * scale,
                          top: buttonSize / 2 - 1 * scale,
                          height: 2 * scale,
                          child: Container(color: pathColor),
                        ),
                      Opacity(
                        opacity: isMobile || element.hover || !element.expand
                            ? 1
                            : 0,
                        child: Container(
                          width: expandButtonRect.width,
                          height: expandButtonRect.height,
                          padding: EdgeInsets.only(
                            left: offsetWidth + 4.0 * scale,
                            top: 4.0 * scale,
                            bottom: 4.0 * scale,
                            right: 4.0 * scale,
                          ),
                          child: CircleButton(
                            radius: 16.0 * scale,
                            borderColor: pathColor ?? Colors.blue,
                            background:
                                expandButtonBackgroundColor ??
                                const Color(-16504525),
                            onTap: () {
                              onExpandChanged?.call(element);
                            },
                            child: !element.expand
                                ? (element.nodeCount < 100
                                      ? Center(
                                          child: Text(
                                            element.nodeCount.toString(),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: pathColor ?? Colors.blue,
                                              fontSize: 10 * scale,
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.more_horiz,
                                          size: 14 * scale,
                                          color: pathColor ?? Colors.blue,
                                        ))
                                : Icon(
                                    Icons.remove,
                                    size: 14 * scale,
                                    color: pathColor ?? Colors.blue,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Widget buildPositionNodeWidget(
    Rect rect,
    double scale,
    NodeWidgetBuilder? nodeBuilder,
  ) {
    var nodeWidget = Positioned(
      top: rect.top,
      left: rect.left,
      width: rect.width,
      height: rect.height,
      child: ListenableBuilder(
        listenable: this,
        builder: (context, child) {
          return MouseRegion(
            onHover: (e) {
              hover = true;
              notifyListeners();
            },
            onExit: (e) {
              hover = false;
              notifyListeners();
            },
            child: SizedBox(
              width: rect.width,
              height: rect.height,
              child: FittedBox(child: nodeBuilder?.call(context, this)),
            ),
          );
        },
      ),
    );
    return nodeWidget;
  }

  void visitChildren(Function(MindNode element) element) {
    element(this);
    if (children != null && children!.isNotEmpty) {
      for (var child in children!) {
        child.visitChildren(element);
      }
    }
  }

  void visitExpandChildren(Function(MindNode element) element) {
    element(this);
    if (expand && children != null && children!.isNotEmpty) {
      for (var child in children!) {
        child.visitExpandChildren(element);
      }
    }
  }

  Rect getScrollRect(Size size, double scale) {
    var horizontalOffset = size.width * scale / 2 - widgetPosition.dx;
    var verticalOffset = size.height * scale / 2 - widgetPosition.dy;
    var contentSize = nodeContentSize;
    var paddingX = size.width * scale / 2;
    var paddingY = size.height * scale / 2;

    return Rect.fromLTWH(
      -paddingX,
      -paddingY,
      contentSize.width - size.width + paddingX * 2,
      contentSize.height - size.height + paddingY * 2,
    ).translate(horizontalOffset, verticalOffset);
  }

  LinePath? buildParentPath(Offset offset, double borderWidth, double scale) {
    var parent = this.parent;
    if (parent == null) {
      return null;
    }

    var start = (parent.widgetPosition & parent.widgetSize).centerRight
        .translate(offset.dx, offset.dy);
    var end = (widgetPosition & widgetSize).centerLeft.translate(
      offset.dx,
      offset.dy,
    );
    return LinePath(
      scale: scale,
      start: start.translate(-borderWidth * scale, 0),
      end: end.translate(borderWidth * scale, 0),
      node: this,
    );
  }

  void addNodeToNext(MindNode node) {
    var pChildren = parent?.children;
    if (pChildren == null) {
      return;
    }
    var index = pChildren.indexOf(this);
    if (index == -1) {
      return;
    }
    parent?.insert(index + 1, node);
  }

  void addNodeToChildren(MindNode node) {
    children ??= [];
    children!.add(node);
    node.parent = this;
    node.depth = depth + 1;
  }

  List<MindNode> getDepthNode(int depth) {
    List<MindNode> list = [];
    visitChildren((element) {
      if (element.depth == depth) {
        list.add(element);
      }
    });
    return list;
  }

  MindNode? getUpNode(MindNode? selectNode) {
    if (selectNode == null) {
      return null;
    }
    var list = getDepthNode(selectNode.depth);
    var index = list.indexWhere((element) => element == selectNode);
    if (index <= 0) {
      return null;
    }
    return list[index - 1];
  }

  MindNode? getDownNode(MindNode? selectNode) {
    if (selectNode == null) {
      return null;
    }
    var list = getDepthNode(selectNode.depth);
    var index = list.indexWhere((element) => element == selectNode);
    if (index >= list.length - 1) {
      return null;
    }
    return list[index + 1];
  }

  MindNode? getLeftNode(MindNode? selectNode) {
    return selectNode?.parent;
  }

  MindNode? getRightNode(MindNode? selectNode) {
    return selectNode?.children?.firstOrNull;
  }

  void setContent(String value) {
    info ??= MindNodeInfo();
    info!.content = value;
    markNeedLayout();
    notifyListeners();
  }

  void delete() {
    if (parent == null) {
      return;
    }
    parent?.children?.remove(this);
  }

  void showEdit() {
    editing = true;
    notifyListeners();
  }

  void closeEdit() {
    editing = false;
    notifyListeners();
  }

  void toggleExpanded() {
    if (expand) {
      setExpand(false);
    } else {
      setExpand(true);
    }
  }

  void setExpand(bool expand) {
    this.expand = expand;
    notifyListeners();
  }

  // 获取相对于root节点的范围矩形
  Rect getRootAnchorRect({required Size viewSize, required double scale}) {
    var horizontalOffset = viewSize.width * scale / 2 - root.widgetPosition.dx;
    var verticalOffset = viewSize.height * scale / 2 - root.widgetPosition.dy;
    var rect = Rect.fromLTWH(
      widgetPosition.dx + horizontalOffset,
      widgetPosition.dy + verticalOffset,
      widgetSize.width,
      widgetSize.height,
    );
    return rect;
  }

  // 获取相对于root的位置
  Offset getRootAnchorOffset({
    Size? viewSize,
    required Offset offset,
    ViewportOffset? xOffset,
    ViewportOffset? yOffset,
  }) {
    var horizontalOffset =
        (viewSize?.width ?? 0) / 2 -
        root.widgetPosition.dx -
        (xOffset?.pixels ?? 0);
    var verticalOffset =
        (viewSize?.height ?? 0) / 2 -
        root.widgetPosition.dy -
        (yOffset?.pixels ?? 0);
    return Offset(-horizontalOffset + offset.dx, -verticalOffset + offset.dy);
  }

  // 获取拖拽预览位置
  PreviewPosition? getPreviewPosition(
    Offset offset, {
    required double verticalSpacing,
    required double horizontalSpacing,
  }) {
    if (expand && children != null && children!.isNotEmpty) {
      for (var child in children!) {
        var previous = child.getPreviewPosition(
          offset,
          verticalSpacing: verticalSpacing,
          horizontalSpacing: horizontalSpacing,
        );
        if (previous != null) {
          return previous;
        }
      }
    }
    var currentOffset = widgetPosition;
    var currentSize = nodeContentSize;
    if (!isRoot) {
      var topOffset = -nodeContentSize.height / 2 + widgetSize.height / 2;
      var topRect =
          currentOffset
              .translate(-horizontalSpacing, -verticalSpacing / 2)
              .translate(0, topOffset) &
          Size(
            widgetSize.width + horizontalSpacing,
            verticalSpacing / 2 + currentSize.height / 2,
          );
      if (topRect.contains(offset)) {
        return PreviewPosition(parentNode: parent!, positionIndex: getIndex());
      }
      var bottomRect =
          currentOffset
              .translate(-horizontalSpacing, currentSize.height / 2)
              .translate(0, topOffset) &
          Size(
            widgetSize.width + horizontalSpacing,
            verticalSpacing / 2 + currentSize.height / 2,
          );
      if (bottomRect.contains(offset)) {
        return PreviewPosition(
          parentNode: parent!,
          positionIndex: getIndex() + 1,
        );
      }
    }
    var leafRect =
        currentOffset.translate(widgetSize.width, 0) &
        Size(horizontalSpacing, widgetSize.height);
    if (leafRect.contains(offset)) {
      return PreviewPosition(parentNode: this, positionIndex: 0);
    }
    return null;
  }

  int getIndex() {
    var parent = this.parent;
    if (parent == null) {
      return 0;
    }
    return parent.children!.indexWhere((element) => element == this);
  }

  MindNode? replacePlaceHolder(MindNode replace) {
    if (parent == null) {
      return null;
    }
    var index = getIndex();
    var ret = parent?.removeAt(index);
    parent?.insert(index, replace);
    return ret;
  }

  MindNode? removeAt(int index) {
    if (children == null) {
      return null;
    }
    return children!.removeAt(index);
  }

  void insert(int index, MindNode node) {
    children ??= [];
    children!.insert(index, node);
    node.parent = this;
    node.depth = depth + 1;
  }

  void getText(StringBuffer buffer, [int tabCount = 0]) {
    var line = "${"\t" * tabCount}${info?.content ?? ""}";
    buffer.writeln(line);
    if (children != null && children!.isNotEmpty) {
      for (var child in children!) {
        child.getText(buffer, tabCount + 1);
      }
    }
  }

  MindNode? getNodeByUuid(String? uuid) {
    if (uuid == this.uuid) {
      return this;
    }
    if (children != null && children!.isNotEmpty) {
      for (var child in children!) {
        var node = child.getNodeByUuid(uuid);
        if (node != null) {
          return node;
        }
      }
    }
    return null;
  }

  List<MindNode> getNodeList() {
    var list = <MindNode>[];
    visitChildren((element) {
      list.add(element);
    });
    return list;
  }

  List<MindNode> getNodeListByDepth() {
    var list = <MindNode>[];
    var queue = Queue<MindNode>();
    queue.add(this);
    while (queue.isNotEmpty) {
      var first = queue.removeFirst();
      list.add(first);
      queue.addAll(first.children ?? []);
    }
    return list;
  }

  // 获取所有节点信息
  List<MindNodeInfo> getNodeInfoList() {
    var list = <MindNodeInfo>[];
    visitChildren((element) {
      list.add(element.createNodeInfo());
    });
    return list;
  }

  MindNodeInfo createNodeInfo() {
    return info!.copyWith(parentId: parent?.uuid, index: getIndex());
  }

  void updateEditing(bool value) {
    if (editing != value) {
      editing = value;
      notifyListeners();
    }
  }

  void setChecked(bool? value) {
    info?.isChecked = value;
    markNeedLayout();
    notifyListeners();
  }

  void setLink(String title, String url) {
    info?.link = url;
    info?.linkTitle = title;
    markNeedLayout();
    notifyListeners();
  }

  void removeLink() {
    info?.link = null;
    info?.linkTitle = null;
    markNeedLayout();
    notifyListeners();
  }

  String get childNote {
    return info?.note ?? "";
  }

  void addNote(String uuid, bool isFirst) {
    info?.note = uuid;
    markNeedLayout();
    notifyListeners();
  }

  void updateImageSize(double dx, double dy) {
    var imageShowWidth = dx + (info?.imageShowWidth ?? 0);
    var imageShowHeight = dy + (info?.imageShowHeight ?? 0);
    if (imageShowWidth < 10 || imageShowHeight < 10) {
      return;
    }
    info?.imageShowWidth = imageShowWidth;
    info?.imageShowHeight = imageShowHeight;
    markNeedLayout();
    notifyListeners();
  }

  void removeNote(String? uuid) {
    if (uuid == null) {
      info?.note = null;
    } else {
      List<String> list = info?.note?.split(",") ?? [];
      list.remove(uuid);
      if (list.isEmpty) {
        info?.note = null;
      } else {
        info?.note = list.join(",");
      }
    }
    markNeedLayout();
    notifyListeners();
  }

  void setTodo(bool? value) {
    info?.isTodo = value;
    markNeedLayout();
    notifyListeners();
  }

  void setImage(BuildContext context, String imageId, ImageSize size) {
    info?.image = imageId;
    info?.imageWidth = size.width;
    info?.imageHeight = size.height;
    var dpr = MediaQuery.of(context).devicePixelRatio;
    info?.imageShowWidth = size.width / dpr;
    info?.imageShowHeight = size.height / dpr;
    markNeedLayout();
    notifyListeners();
  }

  void setFormula(String formula, double width, double height) {
    info?.formula = formula;
    info?.formulaWidth = width;
    info?.formulaHeight = height;
    markNeedLayout();
    notifyListeners();
  }

  void setWenzLink(String linkId){
    info?.wenzLink = linkId;
    markNeedLayout();
    notifyListeners();
  }

  void updateTapSelected(bool selected) {
    tapSelected = selected;
    notifyListeners();
  }

  void visitParent(Function(MindNode element) visit) {
    var p = parent;
    while (p != null) {
      visit(p);
      p = p.parent;
    }
  }
}

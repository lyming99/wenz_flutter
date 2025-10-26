import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:wenz_editor/commons/service/file_manager.dart';
import 'package:wenz_ui/utils/index.dart';
import 'package:wenz_mindmap/controller/mind_doc_controller.dart';

import '../mindmap.dart';
import 'state/index.dart';

typedef FutureVoid = Future<void> Function();

abstract class MindMapStateHolder {
  Future writeState(MindDocument? document);

  Future readState(MindDocument? document);
}

class MindMapController with ChangeNotifier {
  MindMapController({
    this.document,
    this.onChanged,
    this.focusNode,
    this.copyFunction,
    this.pasteFunction,
    this.isShowFloatToolbar = true,
    this.docRootDir,
    this.isCaptureMode = false,
    this.fileManager,
  });

  late UndoManager undoManager = UndoManager(this);
  late MindFocusState focusState = MindFocusState(this);
  late MindDragState dragState = MindDragState(this);
  late MindEventState eventState = MindEventState(this);
  late MindInputState inputState = MindInputState(this);
  late MindLayoutState layoutState = MindLayoutState(this);
  late MindScrollState scrollState = MindScrollState(this);
  late MindSelectState selectState = MindSelectState(this);
  WenzAssetsFileManager? fileManager;
  MindMapStateHolder? stateHolder;
  MindDocument? document;
  CopyFunction? copyFunction;
  PasteFunction? pasteFunction;
  bool isShowFloatToolbar;
  double scale = 1.0;
  bool isCaptureMode = false;

  List<MindNode> get roots =>
      document?.roots ?? [MindNode(info: MindNodeInfo())];

  MindNode get root => roots.first;

  // 是否需要重新计算滚动位置，默认为true
  bool needCalcScrollStatus = true;

  // 焦点
  FocusNode? focusNode;

  // 预览位置
  PreviewPosition? previewPosition;

  // 是否在拖动节点过程中
  bool isDragMoving = false;

  // 拖动视图左上角与鼠标的偏移
  Offset dragLeftTopOffset = Offset.zero;

  // 是否可以拖动节点
  bool isDragEnable = true;

  VoidCallback? onChanged;

  TextStyle? defaultTextStyle;

  bool hasComposing = false;

  String? docRootDir;

  bool get isEditing => selectState.selectNode?.editing == true;

  double get verticalSpacing => (document?.verticalSpacing ?? 20) * scale;

  double get horizontalSpacing => (document?.horizontalSpacing ?? 50) * scale;

  bool setParentExpand(MindNode node, bool expand) {
    bool update = false;
    var parent = node.parent;
    while (parent != null) {
      if (parent.expand != true) {
        update = true;
      }
      parent.expand = expand;
      parent = parent.parent;
    }
    if (update) {
      layout();
      notifyListeners();
    }
    return update;
  }

  double getRootScrollYCenterOffset(Size viewSize) {
    var node = root;
    var stackRect = node.getStackRect(
      viewSize: viewSize,
      xOffset: null,
      yOffset: null,
      scale: scale,
    );
    var viewRect = Offset.zero & viewSize;
    var viewPadding = 50;
    return (stackRect.bottom + viewPadding / 2 - viewRect.bottom);
  }

  void scrollToNode(MindNode node, [bool needUpdateExpand = true]) {
    scrollState.scrollToNode(node, needUpdateExpand);
  }

  void scrollToNodeLeftCenter(MindNode node, [bool needUpdateExpand = true]) {
    scrollState.scrollToNodeLeftCenter(node, needUpdateExpand);
  }

  void addNext([MindNode? selectNode]) {
    selectNode ??= selectState.selectNode;
    var newNode = MindNode(
      info: MindNodeInfo(),
    )
      ..editing = true;
    if (selectNode?.isRoot == true) {
      selectNode?.addNodeToChildren(newNode);
    } else {
      selectNode?.addNodeToNext(newNode);
    }
    selectState.selectNode?.closeEdit();
    selectState.selectNode = newNode;
    undoManager.onAddNodes([newNode]);
    layout();
    fireOnChange();
    scrollToNode(newNode);
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((t) {
      newNode.showEdit();
    });
  }

  void addChild([MindNode? selectNode]) {
    selectNode ??= selectState.selectNode;
    var newNode = MindNode(
      info: MindNodeInfo(),
    )
      ..editing = true;
    selectNode?.addNodeToChildren(newNode);
    selectState.selectNode?.closeEdit();
    selectState.selectNode?.expand = true;
    selectState.selectNode = newNode;
    undoManager.onAddNodes([newNode]);
    layout();
    fireOnChange();
    scrollToNode(newNode);
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((t) {
      newNode.showEdit();
    });
  }

  void addNodes(List<MindNode> nodes) {
    if (nodes.isEmpty) {
      return;
    }
    for (var node in nodes) {
      selectState.selectNode?.addNodeToChildren(node);
    }
    undoManager.onAddNodes(nodes);
    selectState.selectNode?.expand = true;
    selectState.selectNode = nodes.first;
    selectState.selectNodes = nodes;
    layout();
    fireOnChange();
    scrollToNode(nodes.first);
    notifyListeners();
  }

  void delete() {
    var deleteNodes = <MindNode>[];
    var previous = selectState.selectNode?.previous;
    if (selectState.selectNode == null) {
      deleteNodes.addAll(selectState.selectNodes);
      previous = selectState.selectNodes.firstOrNull?.previous;
      undoManager.onDeleteNodes(deleteNodes);
      for (var value in selectState.selectNodes) {
        value.delete();
      }
    } else {
      if (selectState.selectNode!.isRoot) {
        updateSelectNodeInfo((node) {
          node.info?.formula = null;
          node.info?.image = null;
          node.info?.content = "";
        }, currentNode: selectState.selectNode);
      } else {
        deleteNodes.add(selectState.selectNode!);
        undoManager.onDeleteNodes(deleteNodes);
        selectState.selectNode!.delete();
      }
    }
    selectState.selectNodes = [];
    selectState.selectNode = previous;
    layout();
    notifyListeners();
    fireOnChange();
  }

  void dragMove(List<MindNode> selectRoots) {
    var index = previewPosition!.positionIndex;
    var parent = previewPosition!.parentNode;
    var deleteHolder = <MindNode>[];
    var oldNodeInfo = <List<MindNodeInfo>>[];
    for (var root in selectRoots) {
      oldNodeInfo.add(root.getNodeInfoList());
    }
    for (var root in selectRoots) {
      var holder = MindNode.placeHolder();
      root.replacePlaceHolder(holder);
      deleteHolder.add(holder);
      root.parent?.children?.remove(root);
      root.parent = parent;
      parent.children ??= [];
      parent.children!.insert(index, root);
      index++;
    }
    for (var holder in deleteHolder) {
      holder.delete();
    }
    var updateList = <UpdateInfo>[];
    for (var i = 0; i < selectRoots.length; i++) {
      var root = selectRoots[i];
      root.visitChildren((element) {
        element.markNeedLayout();
      });
      var oldInfoList = oldNodeInfo[i];
      updateList.add(
        UpdateInfo(
          oldInfo: oldInfoList,
          newInfo: root.getNodeInfoList(),
        ),
      );
    }
    undoManager.onDragMove(updateList);
    previewPosition = null;
    parent.expand = true;
    layout();

    fireOnChange();
  }

  void toggleExpand(MindNode node) {
    var oldInfo = node.createNodeInfo();
    node.toggleExpanded();
    var newInfo = node.createNodeInfo();
    undoManager.onUpdateNode(
      UpdateInfo(
        oldInfo: [oldInfo],
        newInfo: [newInfo],
      ),
    );
    layout();
    fireOnChange();
  }

  void updateNodeLabel(MindNode node, String label) {
    var oldInfo = node.createNodeInfo();
    node.info?.content = label;
    node.markNeedLayout();
    var newInfo = node.createNodeInfo();
    undoManager.onUpdateNode(
      UpdateInfo(
        oldInfo: [oldInfo],
        newInfo: [newInfo],
        hasComposing: hasComposing,
      ),
    );
    layout();
    fireOnChange();
  }

  void addLink(String title, String url, [MindNode? node]) {
    updateSelectNodeInfo(
          (node) {
        node.setLink(title, url);
      },
      currentNode: node,
    );
  }

  void updateImageShowSize(double dx, double dy, [MindNode? node]) {
    updateSelectNodeInfo(
          (node) {
        node.updateImageSize(dx, dy);
      },
      currentNode: node,
      isUndoAction: false,
    );
  }

  MindNode? getCurrentNode([MindNode? node]) {
    var nodes = node != null
        ? [node]
        : (selectState.selectNodes.isNotEmpty
        ? selectState.selectNodes
        : <MindNode>[
      if (selectState.selectNode != null) selectState.selectNode!
    ]);
    return nodes.firstOrNull;
  }

  bool isSelectAllTodo([MindNode? node]) {
    var nodes = node != null
        ? [node]
        : (selectState.selectNodes.isNotEmpty
        ? selectState.selectNodes
        : <MindNode>[
      if (selectState.selectNode != null) selectState.selectNode!
    ]);
    if (nodes.isEmpty) {
      return false;
    }
    return !nodes.any((item) => !item.isTodo);
  }

  void addTodo([MindNode? node]) {
    updateSelectNodeInfo(
          (node) {
        node.setTodo(true);
      },
      currentNode: node,
    );
  }

  void toggleTodo([MindNode? node]) {
    bool value = !isSelectAllTodo(node);
    updateSelectNodeInfo(
          (node) {
        node.setTodo(value);
      },
      currentNode: node,
    );
  }

  void addImage(BuildContext context, String imageId, ImageSize size,
      [MindNode? node]) {
    updateSelectNodeInfo(
          (node) {
        node.setImage(context, imageId, size);
      },
      currentNode: node,
    );
  }

  void addFormula(String formula, double width, double height,
      [MindNode? node]) {
    updateSelectNodeInfo(
          (node) {
        node.setFormula(formula, width, height);
      },
      currentNode: node,
    );
  }

  void removeTodo([MindNode? node]) {
    updateSelectNodeInfo(
          (node) {
        node.setTodo(null);
      },
      currentNode: node,
    );
  }

  void removeLink([MindNode? node]) {
    updateSelectNodeInfo(
          (node) {
        node.removeLink();
      },
      currentNode: node,
    );
  }

  void removeNote([MindNode? node, String? uuid]) {
    updateSelectNodeInfo(
          (node) {
        node.removeNote(uuid);
      },
      currentNode: node,
    );
  }

  void setChecked(MindNode node, bool? value) {
    updateSelectNodeInfo(
          (node) {
        node.setChecked(value);
      },
      currentNode: node,
    );
  }

  void updateSelectNodeInfo(Function(MindNode) update, {
    MindNode? currentNode,
    bool isUndoAction = true,
  }) {
    var oldInfo = <MindNodeInfo>[];
    var newInfo = <MindNodeInfo>[];
    var nodes = currentNode != null
        ? [currentNode]
        : (selectState.selectNodes.isNotEmpty
        ? selectState.selectNodes
        : <MindNode>[
      if (selectState.selectNode != null) selectState.selectNode!
    ]);
    for (var item in nodes) {
      oldInfo.add(item.createNodeInfo());
      update.call(item);
      newInfo.add(item.createNodeInfo());
      item.markNeedLayout();
    }
    if (isUndoAction) {
      undoManager.onUpdateNode(
        UpdateInfo(
          oldInfo: oldInfo,
          newInfo: newInfo,
          hasComposing: hasComposing,
        ),
        isUndoAction,
      );
    }
    layout();
    fireOnChange();
  }

  void layout() {
    root.layout(
      scale: scale,
      verticalSpacing: verticalSpacing,
      horizontalSpacing: horizontalSpacing,
      style: document?.style,
      defaultTextStyle: defaultTextStyle,
    );
    needCalcScrollStatus = true;
    notifyListeners();
  }

  void toLeft() {
    var left = root.getLeftNode(selectState.selectNode);
    if (left != null) {
      selectState.selectNode?.closeEdit();
      selectState.selectNode = left;
      scrollToNode(left);
      notifyListeners();
    }
  }

  void toRight() {
    var right = root.getRightNode(selectState.selectNode);
    if (right != null) {
      selectState.selectNode?.closeEdit();
      selectState.selectNode = right;
      scrollToNode(right);
      notifyListeners();
    }
  }

  void toUp() {
    var up = root.getUpNode(selectState.selectNode);
    if (up != null) {
      selectState.selectNode?.closeEdit();
      selectState.selectNode = up;
      scrollToNode(up);
      notifyListeners();
    }
  }

  void toDown() {
    var down = root.getDownNode(selectState.selectNode);
    if (down != null) {
      selectState.selectNode?.closeEdit();
      selectState.selectNode = down;
      scrollToNode(down);
      notifyListeners();
    }
  }

  void closeEdit() {
    selectState.selectNode?.closeEdit();
  }

  void setContent(MindDocument content, MindMapStateHolder? stateHolder,
      [bool init = false]) {
    if (stateHolder != null) {
      this.stateHolder = stateHolder;
    }
    undoManager.onUpdateContent(getContent(), content, init);
    content.loadRoots();
    document = content;
    root.layout(
      scale: scale,
      verticalSpacing: verticalSpacing,
      horizontalSpacing: horizontalSpacing,
      style: document?.style,
      defaultTextStyle: defaultTextStyle,
    );
    if (!init) {
      fireOnChange();
    }
    // 恢复滚动位置
    WidgetsBinding.instance.addPostFrameCallback((time) async {
      await stateHolder?.readState(content);
      if (content.xScrollOffset != null) {
        scrollState.xOffset?.jumpTo(content.xScrollOffset!);
      }
      if (content.yScrollOffset != null) {
        scrollState.yOffset?.jumpTo(content.yScrollOffset!);
      }
    });
    notifyListeners();
  }

  MindDocument getContent() {
    var res = MindDocument(
      docId: document?.docId,
      noteId: document?.noteId,
    );
    res.primaryRootId = root.uuid;
    res.nodes = [];
    res.xScrollOffset = scrollState.xOffset?.pixels;
    res.yScrollOffset = scrollState.yOffset?.pixels;
    for (var root in roots) {
      res.nodes.addAll(root.getNodeInfoList());
    }
    return res;
  }

  void calcPreviewPosition(Offset relative) {
    previewPosition = root.getPreviewPosition(
      relative,
      verticalSpacing: verticalSpacing,
      horizontalSpacing: horizontalSpacing,
    );
  }

  MindNode? getNodeByUuid(String? uuid) {
    return root.getNodeByUuid(uuid);
  }

  void undo() {
    undoManager.undo();
    layout();
    notifyListeners();
  }

  void redo() {
    undoManager.redo();
    layout();
    notifyListeners();
  }

  bool get canUndo {
    return undoManager.canUndo;
  }

  bool get canRedo {
    return undoManager.canRedo;
  }

  bool checkNodeSizeNeedUpdate(BuildContext context, MindNode node) {
    var style = document?.style;
    var newSize =
        style?.getNodeSize(node, defaultTextStyle: defaultTextStyle) ??
            node.measureWidgetSize();
    var oldWidth = node.info?.width;
    var oldHeight = node.info?.height;
    if (oldWidth != newSize.width || oldHeight != newSize.height) {
      node.info?.width = newSize.width;
      node.info?.height = newSize.height;
      return true;
    }
    return false;
  }

  void initTextStyle(BuildContext context) {
    var theme = Theme.of(context);
    // defaultTextStyle = theme.useMaterial3
    //     ? theme.textTheme.bodyLarge!
    //     : theme.textTheme.titleMedium!;
    defaultTextStyle = theme.textTheme.bodyMedium!;
  }

  void openChildNote(BuildContext context, String uuid, [MindNode? node]) {
    var controller = findController<MindDocController>(context);
    controller?.openChildNote(uuid);
  }

  void setChildResizeState(bool resizing) {
    layoutState.isChildResizing = resizing;
    notifyListeners();
  }

  void copy() async {
    var nodes = <MindNode>[];
    if (selectState.selectNode != null) {
      nodes.add(selectState.selectNode!);
    }
    for (var node in selectState.selectNodes) {
      nodes.add(node);
    }
    var dragNodes = <MindNode>[];
    for (var node in nodes) {
      if (nodes.contains(node.parent)) {
        continue;
      }
      dragNodes.add(node);
    }
    if (copyFunction != null) {
      copyFunction?.call(dragNodes);
    } else {
      writeTextClipboard(dragNodes);
    }
  }

  void paste(BuildContext context) async {
    var isImage = await pasteImage(context);
    if (isImage) {
      return;
    }
    var nodes = await pasteFunction?.call();
    nodes ??= await readTextClipboard();
    addNodes(nodes);
  }

  Future<bool> pasteImage(BuildContext cotext) async {
    var nodes = await getClipboardImages(cotext);
    if (nodes.isNotEmpty) {
      addNodes(nodes);
      return true;
    } else {
      return false;
    }
  }

  Future<List<MindNode>> getClipboardImages(BuildContext context) async {
    var result = <MindNode>[];
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return result;
    }
    var docController = findController<MindDocController>(context);
    if (docController == null) {
      return result;
    }

    var dpr = MediaQuery
        .of(context)
        .devicePixelRatio;
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

  static MindMapController? of(BuildContext context) {
    return context
        .findAncestorStateOfType<MindMapState>()
        ?.controller;
  }

  void clearSelects() {
    selectState.selectNodes.clear();
    selectState.selectNode = null;
    notifyListeners();
  }

  void fireOnChange() async {
    document?.xScrollOffset = scrollState.xOffset?.pixels;
    document?.yScrollOffset = scrollState.yOffset?.pixels;
    await stateHolder?.writeState(document);
    onChanged?.call();
  }
}

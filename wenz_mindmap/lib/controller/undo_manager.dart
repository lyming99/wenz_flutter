import '../mindmap.dart';

class UpdateInfo {
  int updateTime = DateTime.now().millisecondsSinceEpoch;
  bool hasComposing;
  List<MindNodeInfo> oldInfo;
  List<MindNodeInfo> newInfo;

  UpdateInfo({
    this.oldInfo = const [],
    this.newInfo = const [],
    this.hasComposing = false,
  });
}

class NodeDelta {
  /// 如果时move模式，那么就需要将update里面的节点全部删除，然后再进行插入
  bool? isMove;
  bool? isSetContent;
  List<MindNodeInfo>? insert;
  List<MindNodeInfo>? remove;
  List<UpdateInfo>? update;
  MindDocument? oldContent;
  MindDocument? newContent;

  NodeDelta({
    this.isMove,
    this.isSetContent,
    this.insert,
    this.remove,
    this.update,
    this.oldContent,
    this.newContent,
  });

  void undo(MindMapController controller) {
    // 移除插入的node
    if (insert != null) {
      for (var node in insert!) {
        deleteNode(controller, node);
      }
    }
    // 插入移除的节点
    if (remove != null) {
      for (var node in remove!) {
        insertNode(controller, node);
      }
    }
    // 撤销更新的节点
    if (update != null) {
      if (isMove == true) {
        // 如果是移动模式，先删除新的，再插入旧的
        for (var info in update!) {
          deleteNode(controller, info.newInfo.first);
        }
        for (var info in update!) {
          insertNodes(controller, info.oldInfo);
        }
      } else {
        // 回复旧信息
        for (var info in update!) {
          var node = controller.getNodeByUuid(info.oldInfo.first.uuid);
          if (node != null) {
            node.info = info.oldInfo.first;
          }
        }
      }
    }
  }

  void redo(MindMapController controller) {
    // 插入node
    if (insert != null) {
      for (var node in insert!) {
        insertNode(controller, node);
      }
    }
    // 移除节点
    if (remove != null) {
      for (var node in remove!) {
        deleteNode(controller, node);
      }
    }
    // 更新节点
    if (update != null) {
      if (isMove == true) {
        // 如果是移动模式，先删除新的，再插入旧的
        for (var info in update!) {
          deleteNode(controller, info.oldInfo.first);
        }
        for (var info in update!) {
          insertNodes(controller, info.newInfo);
        }
      } else {
        // 更新
        for (var info in update!) {
          var node = controller.getNodeByUuid(info.oldInfo.first.uuid);
          if (node != null) {
            node.info = info.newInfo.first;
          }
        }
      }
    }
  }

  void deleteNode(MindMapController controller, MindNodeInfo info) {
    var node = controller.getNodeByUuid(info.uuid);
    if (node != null) {
      node.delete();
    }
  }

  void insertNode(MindMapController controller, MindNodeInfo info) {
    var parent = controller.getNodeByUuid(info.parentId);
    if (parent != null) {
      parent.insert(info.index!, MindNode(info: info));
    }
  }

  void insertNodes(MindMapController controller, List<MindNodeInfo> infoList) {
    for (var info in infoList) {
      var parent = controller.getNodeByUuid(info.parentId);
      if (parent != null) {
        parent.insert(info.index!, MindNode(info: info));
      }
    }
  }
}

class UndoManager {
  MindMapController controller;

  UndoManager(this.controller);

  List<NodeDelta> deltaList = [];

  int index = -1;

  void add(NodeDelta delta) {
    if (index < deltaList.length - 1) {
      deltaList.removeRange(index + 1, deltaList.length);
    }
    deltaList.add(delta);
    index++;
  }

  void undo() {
    if (index >= 0) {
      deltaList[index].undo(controller);
      index--;
    }
  }

  void redo() {
    if (index < deltaList.length - 1) {
      index++;
      deltaList[index].redo(controller);
    }
  }

  bool get canUndo => index >= 0;

  bool get canRedo => index < deltaList.length - 1;

  void onAddNodes(List<MindNode> newNode) {
    add(
      NodeDelta(
        insert: newNode.map((e) => e.createNodeInfo()).toList(),
      ),
    );
  }

  void onDeleteNodes(List<MindNode> deleteNodes) {
    var nodes = <MindNodeInfo>[];
    for (var node in deleteNodes) {
      nodes.addAll(node.getNodeInfoList());
    }
    add(
      NodeDelta(
        remove: nodes,
      ),
    );
  }

  void onDragMove(List<UpdateInfo> updateList) {
    add(
      NodeDelta(
        isMove: true,
        update: updateList,
      ),
    );
  }

  bool mergeUpdateToCurrent(UpdateInfo updateInfo) {
    if (index < 0 || index >= deltaList.length) {
      return false;
    }
    if (updateInfo.newInfo.length != 1 || updateInfo.oldInfo.length != 1) {
      return false;
    }
    var current = deltaList[index].update;
    if (current == null || current.length != 1) {
      return false;
    }
    var currentUpdate = current.first;
    if (currentUpdate.oldInfo.length != 1 ||
        currentUpdate.newInfo.length != 1) {
      return false;
    }
    var currentOld = currentUpdate.oldInfo.first;
    var currentNew = currentUpdate.newInfo.first;
    var updateOld = updateInfo.oldInfo.first;
    var updateNew = updateInfo.newInfo.first;
    if (currentOld.uuid != updateOld.uuid ||
        currentNew.uuid != updateNew.uuid) {
      return false;
    }
    if (!currentUpdate.hasComposing &&
        updateInfo.updateTime - currentUpdate.updateTime > 500) {
      return false;
    }
    currentUpdate.newInfo = updateInfo.newInfo;
    return true;
  }

  void onUpdateNode(UpdateInfo updateInfo, [bool removeUndoStack = false]) {
    if (mergeUpdateToCurrent(updateInfo)) {
      // 移除后面的重做队列
      if (index < deltaList.length - 1) {
        deltaList.removeRange(index + 1, deltaList.length);
      }
      return;
    }
    add(
      NodeDelta(
        update: [updateInfo],
      ),
    );
  }

  void onUpdateContent(MindDocument oldContent, MindDocument newContent,
      [bool init = false]) {
    if (init) {
      clear();
      return;
    }
    add(
      NodeDelta(
        isSetContent: true,
        oldContent: oldContent,
        newContent: newContent,
      ),
    );
  }

  void clear() {
    deltaList.clear();
    index = -1;
  }
}

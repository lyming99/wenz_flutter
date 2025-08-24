import 'package:ydart/utils/queue_stack.dart';

import '../structs/item.dart';
import '../types/abstract_type.dart';
import '../types/y_array_base.dart';
import 'delete_set.dart';
import 'id.dart';
import 'transaction.dart';
import 'y_doc.dart';
import 'y_event.dart';

enum OperationType { undo, redo }

class StackEventArgs {
  final StackItem stackItem;
  final OperationType type;
  final Map<AbstractType, List<YEvent>> changedParentTypes;
  final Object? origin;

  StackEventArgs({
    required this.stackItem,
    required this.type,
    required this.changedParentTypes,
    required this.origin,
  });

  factory StackEventArgs.create(StackItem stackItem, OperationType type,
      Map<AbstractType, List<YEvent>> changedParentTypes, Object? origin) {
    return StackEventArgs(
        stackItem: stackItem,
        type: type,
        changedParentTypes: changedParentTypes,
        origin: origin);
  }
}

class StackItem {
  late Map<String, Object> meta;
  late DeleteSet deletions;
  late DeleteSet insertions;

  StackItem(this.deletions, this.insertions) {
    meta = {};
  }
}

class UndoManager {
  late List<AbstractType> _scope;
  late bool Function(Item) _deleteFilter;
  late Set<Object?> _trackedOrigins;
  late QueueStack<StackItem> _undoStack;
  late QueueStack<StackItem> _redoStack;
  late bool _undoing;
  late bool _redoing;
  late YDoc _doc;
  late DateTime _lastChange;
  late int _captureTimeout;
  var ignoreRemoteMapChanges = false;

  StackItem? currStackItem;

  List<Function(StackEventArgs)> stackItemAdded = [];

  List<Function(StackEventArgs)> stackItemUpdated = [];

  List<Function(StackEventArgs)> stackItemPopped = [];

  List<Function(bool undoStackCleared, bool redoStackCleared)> stackCleared =
      [];

  factory UndoManager.create(AbstractType typeScope) {
    return UndoManager([typeScope], 500, (Item it) => true, {null});
  }

  UndoManager(List<AbstractType> typeScopes, int captureTimeout,
      bool Function(Item)? deleteFilter, Set<Object?> trackedOrigins) {
    _scope = typeScopes;
    _deleteFilter = deleteFilter ?? ((Item it) => true);
    _trackedOrigins = trackedOrigins..add(this);
    _undoStack = QueueStack<StackItem>();
    _redoStack = QueueStack<StackItem>();
    _undoing = false;
    _redoing = false;
    _doc = typeScopes[0].doc!;
    _lastChange = DateTime.fromMillisecondsSinceEpoch(0);
    _captureTimeout = captureTimeout;
    _doc.afterTransaction[UndoManager] = (afterTransactionHandler);
  }

  bool captureTransaction(Transaction transaction) {
    // todo
    return true;
  }

  bool canUndo() {
    return _undoStack.isNotEmpty;
  }

  bool canRedo() {
    return _redoStack.isNotEmpty;
  }

  void clear([bool clearUndoStack = true, bool clearRedoStack = true]) {
    if (clearRedoStack && canRedo() || clearRedoStack && canRedo()) {
      _doc.transact((transaction) {
        if (clearUndoStack) {
          for (var item in _undoStack.queue) {
            clearUndoManagerStackItem(transaction, item);
          }
          _undoStack.clear();
        }
        if (clearRedoStack) {
          for (var item in _redoStack.queue) {
            clearUndoManagerStackItem(transaction, item);
          }
          _redoStack.clear();
        }
        for (var element in stackCleared) {
          element.call(clearUndoStack, clearRedoStack);
        }
      });
    }
  }

  void clearUndoManagerStackItem(Transaction transaction, StackItem stackItem) {
    stackItem.deletions.iterateDeletedStructs(transaction, (type) {
      if (type is Item) {
        if (_scope.any((element) => isParentOf(element, type))) {
          type.keep = false;
        }
      }
      return true;
    });
  }

  void destroy() {
    _trackedOrigins.remove(this);
    _doc.afterTransaction.remove(afterTransactionHandler);
  }

  void afterTransactionHandler(Transaction transaction) {
    if (!captureTransaction(transaction)) {
      return;
    }
    var isChangeParentType = _scope
        .any((element) => transaction.changedParentTypes.containsKey(element));
    if (!isChangeParentType) {
      return;
    }
    var isTrackOrigins = _trackedOrigins.contains(transaction.origin);
    if (!isTrackOrigins) {
      if (transaction.origin == null) {
        return;
      }
      var hasTrackedOrigin =
          _trackedOrigins.any((to) => transaction.origin.runtimeType == to);
      if (!hasTrackedOrigin) {
        return;
      }
    }

    var undoing = _undoing;
    var redoing = _redoing;
    QueueStack stack = undoing ? _redoStack : _undoStack;
    if (undoing) {
      stopCapturing();
    } else if (!redoing) {
      clear(false, true);
    }
    var insertions = DeleteSet(clients: {});
    transaction.afterState.forEach((client, endClock) {
      var startClock = transaction.beforeState[client] ?? 0;
      var len = endClock - startClock;
      if (len > 0) {
        insertions.add(client, startClock, len);
      }
    });
    var now = DateTime.now();
    var didAdd = false;
    if (now.difference(_lastChange).inMilliseconds < _captureTimeout &&
        stack.isNotEmpty &&
        !undoing &&
        !redoing) {
      var lastOp = stack.peek();
      lastOp.deletions =
          DeleteSet.merge([lastOp.deletions, transaction.deleteSet]);
      lastOp.insertions = DeleteSet.merge([lastOp.insertions, insertions]);
    } else {
      stack.push(StackItem(transaction.deleteSet, insertions));
      didAdd = true;
    }
    if (!undoing && !redoing) {
      _lastChange = DateTime.now();
    }
    transaction.deleteSet.iterateDeletedStructs(transaction, (item) {
      if (item is Item && _scope.any((element) => isParentOf(element, item))) {
        item.keep = true;
      }
      return true;
    });
    var changeEvent = StackEventArgs(
      stackItem: stack.peek(),
      type: undoing ? OperationType.redo : OperationType.undo,
      changedParentTypes: transaction.changedParentTypes,
      origin: transaction.origin,
    );
    if (didAdd) {
      for (var value in stackItemAdded) {
        value.call(changeEvent);
      }
    } else {
      for (var value in stackItemUpdated) {
        value.call(changeEvent);
      }
    }
  }

  void stopCapturing() {
    _lastChange = DateTime.fromMillisecondsSinceEpoch(0);
  }

  StackItem? undo() {
    _undoing = true;
    StackItem? res;
    try {
      res = popStackItem(_undoStack, OperationType.undo);
    } finally {
      _undoing = false;
    }
    return res;
  }

  StackItem? redo() {
    _redoing = true;
    StackItem? res;
    try {
      res = popStackItem(_redoStack, OperationType.redo);
    } finally {
      _redoing = false;
    }
    return res;
  }

  StackItem? popStackItem(
      QueueStack<StackItem> stack, OperationType eventType) {
    var doc = _doc;
    var scope = _scope;
    Transaction? tr;
    doc.transact((transaction) {
      while (stack.isNotEmpty && currStackItem == null) {
        var store = _doc.store;
        var stackItem = stack.pop();
        var itemsToRedo = <Item>[];
        var itemsToDelete = <Item>[];
        var performedChange = false;
        stackItem.insertions.iterateDeletedStructs(transaction, (struct) {
          if (struct is Item) {
            if (struct.redone != null) {
              var follow = store.followRedone(struct.id);
              var item = follow.item;
              if (follow.diff > 0) {
                item = store.getItemCleanStart(
                    transaction,
                    ID(
                        client: item!.id.client,
                        clock: item.id.clock + follow.diff));
              }
              struct = item!;
            }
            if (!struct.deleted &&
                scope.any((type) => isParentOf(type, struct as Item))) {
              itemsToDelete.add(struct as Item);
            }
          }
          return true;
        });
        stackItem.deletions.iterateDeletedStructs(transaction, (struct) {
          if (struct is Item &&
              scope.any((type) => isParentOf(type, struct)) &&
              !stackItem.insertions.isDeleted(struct.id)) {
            itemsToRedo.add(struct);
          }
          return true;
        });
        for (var struct in itemsToRedo) {
          performedChange =
              transaction.redoItem(struct, itemsToRedo, stackItem.insertions) !=
                      null ||
                  performedChange;
        }
        for (var i = itemsToDelete.length - 1; i >= 0; i--) {
          var item = itemsToDelete[i];
          if (_deleteFilter(item)) {
            item.delete(transaction);
            performedChange = true;
          }
        }
        currStackItem = performedChange ? stackItem : null;
      }
      transaction.changed.forEach((type, subProps) {
        if (subProps.contains(null) && type is YArrayBase) {
          type.clearSearchMarkers();
        }
      });
      tr = transaction;
    }, origin: this);
    if (currStackItem != null) {
      var changedParentTypes = tr!.changedParentTypes;
      for (var element in stackItemPopped) {
        element.call(StackEventArgs.create(
            currStackItem!, eventType, changedParentTypes, this));
      }
      currStackItem = null;
    }
    return currStackItem;
  }

  bool isParentOf(AbstractType parent, Item child) {
    Item? currentChild = child;
    while (currentChild != null) {
      if (currentChild.parent == parent) {
        return true;
      }
      currentChild = (currentChild.parent as AbstractType).item;
    }
    return false;
  }
}

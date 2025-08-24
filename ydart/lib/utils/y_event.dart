import 'package:ydart/structs/abstract_struct.dart';
import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/utils/transaction.dart';
import '../structs/item.dart';

enum ChangeAction { add, update, delete }

class ChangeKey {
  ChangeAction action;
  Object? oldValue;

  ChangeKey(this.action, this.oldValue);
}

class ChangesCollection {
  Set<Item>? added;
  Set<Item>? deleted;
  List<Delta>? delta;
  Map<String, ChangeKey>? keys;

  ChangesCollection({
    this.added,
    this.deleted,
    this.delta,
    this.keys,
  });
}

class Delta {
  Object? insert;
  int? delete;
  int? retain;
  Map<String, Object?>? attributes;

  Delta({
    this.insert,
    this.delete,
    this.retain,
    this.attributes,
  });
}

class YEvent {
  ChangesCollection? _changes;
  AbstractType target;
  late AbstractType currentTarget;
  Transaction transaction;

  YEvent(this.target, this.transaction) {
    currentTarget = target;
  }

  List<Object> get path => getPathTo(currentTarget, target);

  ChangesCollection get changes => collectChanges();

  bool deletes(AbstractStruct str) {
    return transaction.deleteSet.isDeleted(str.id);
  }

  bool adds(AbstractStruct str) {
    return !transaction.beforeState.containsKey(str.id.client) ||
        str.id.clock >= transaction.beforeState[str.id.client]!;
  }

  ChangesCollection collectChanges() {
    if (_changes == null) {
      var target = this.target;
      var added = <Item>{};
      var deleted = <Item>{};
      var delta = <Delta>[];
      var keys = <String, ChangeKey>{};

      _changes = ChangesCollection()
        ..added = added
        ..deleted = deleted
        ..delta = delta
        ..keys = keys;

      var changed = transaction.changed[target];
      if (changed == null) {
        changed = <String>{};
        transaction.changed[target] = changed;
      }

      if (changed.contains(null)) {
        Delta? lastOp;

        void packOp() {
          if (lastOp != null) {
            delta.add(lastOp);
          }
        }

        for (var item = target.start;
            item != null;
            item = item.right as Item?) {
          if (item.deleted) {
            if (deletes(item) && !adds(item)) {
              if (lastOp == null || lastOp.delete == null) {
                packOp();
                lastOp = Delta()..delete = 0;
              }

              lastOp.delete = lastOp.delete! + item.length;
              deleted.add(item);
            }
          } else {
            if (adds(item)) {
              if (lastOp == null || lastOp.insert == null) {
                packOp();
                lastOp = Delta()..insert = <Object?>[];
              }

              (lastOp.insert as List<Object?>)
                  .addAll(item.content.getContent());
              added.add(item);
            } else {
              if (lastOp == null || lastOp.retain == null) {
                packOp();
                lastOp = Delta()..retain = 0;
              }

              lastOp.retain = lastOp.retain! + item.length;
            }
          }
        }

        if (lastOp != null && lastOp.retain == null) {
          packOp();
        }
      }

      for (var key in changed) {
        ChangeAction action;
        dynamic oldValue;
        var item = target.map[key];

        if (adds(item as AbstractStruct)) {
          var prev = item?.left as Item?;
          while (prev != null && adds(prev)) {
            prev = prev.left as Item?;
          }

          if (deletes(item!)) {
            if (prev != null && deletes(prev)) {
              action = ChangeAction.delete;
              oldValue = (prev).content.getContent().last;
            } else {
              break;
            }
          } else {
            if (prev != null && deletes(prev)) {
              action = ChangeAction.update;
              oldValue = (prev).content.getContent().last;
            } else {
              action = ChangeAction.add;
              oldValue = null;
            }
          }
        } else {
          if (deletes(item as AbstractStruct)) {
            action = ChangeAction.delete;
            oldValue = item?.content.getContent().last;
          } else {
            break;
          }
        }

        keys[key] = ChangeKey(action,oldValue);
      }
    }

    return _changes!;
  }

  List<Object> getPathTo(AbstractType parent, AbstractType child) {
    var path = <Object>[];

    while (child.item != null && child != parent) {
      if (child.item?.parentSub != null && child.item!.parentSub!.isNotEmpty) {
        path.add(child.item!.parentSub!);
      } else {
        int i = 0;
        AbstractStruct? c = (child.item?.parent as AbstractType?)?.start;
        while (c != child.item && c != null) {
          if (!c.deleted) {
            i++;
          }

          c = (c as Item?)?.right;
        }

        path.add(i);
      }

      child = (child.item?.parent as AbstractType);
    }

    return path.reversed.toList();
  }
}

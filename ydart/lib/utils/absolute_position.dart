import 'dart:core';

import '../structs/content_type.dart';
import '../structs/item.dart';
import '../types/abstract_type.dart';
import 'relative_position.dart';
import 'y_doc.dart';

class AbsolutePosition {
  final AbstractType type;
  final int index;
  final int assoc;

  AbsolutePosition(this.type, this.index, {this.assoc = 0});

  static AbsolutePosition? tryCreateFromRelativePosition(
      RelativePosition rpos, YDoc doc) {
    var store = doc.store;
    var rightId = rpos.item;
    var typeId = rpos.typeId;
    var tName = rpos.tName;
    var assoc = rpos.assoc;
    int index = 0;
    AbstractType? type;
    if (rightId != null) {
      if (store.getState(rightId.client) <= rightId.clock) {
        return null;
      }
      var res = store.followRedone(rightId);
      var right = res.item as Item?;
      if (right == null) {
        return null;
      }
      type = right.parent as AbstractType?;
      assert(type != null);
      if (type!.item == null || !type.item!.deleted) {
        index = (right.deleted || !right.countable)
            ? 0
            : (res.diff + (assoc >= 0 ? 0 : 1));
        var tempItem = right.left as Item?;
        while (tempItem != null) {
          if (!tempItem.deleted && tempItem.countable) {
            index += tempItem.length;
          }
          tempItem = tempItem.left as Item?;
        }
      }
    } else {
      if (tName != null) {
        type = doc.get<AbstractType>(tName, () => AbstractType());
      } else if (typeId != null) {
        if (store.getState(typeId.client) <= typeId.clock) {
          return null;
        }
        var item = store.followRedone(typeId).item as Item?;
        if (item != null && item.content is ContentType) {
          type = (item.content as ContentType).type;
        } else {
          return null;
        }
      } else {
        throw Exception();
      }
      index = assoc >= 0 ? type!.length : 0;
    }

    return AbsolutePosition(type!, index, assoc: assoc);
  }
}

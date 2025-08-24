import 'package:ydart/structs/base_content.dart';
import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/types/y_array.dart';
import 'package:ydart/types/y_map.dart';
import 'package:ydart/types/y_text.dart';

import '../utils/encoding.dart';
import '../utils/struct_store.dart';
import '../utils/transaction.dart';
import '../utils/update_decoder.dart';
import '../utils/update_encoder.dart';
import 'item.dart';

class ContentType extends IContentEx {
  AbstractType type;

  ContentType(this.type);

  @override
  int get ref => 7;

  @override
  bool get isCountable => true;

  @override
  int get length => 1;

  @override
  List getContent() {
    return [type];
  }

  @override
  IContentEx copy() {
    return ContentType(type.internalCopy());
  }

  @override
  IContentEx splice(int offset) {
    throw UnimplementedError();
  }

  @override
  bool mergeWith(IContent right) {
    return false;
  }

  @override
  void integrate(Transaction transaction, Item item) {
    type.integrate(transaction.doc, item);
  }

  @override
  void delete(Transaction transaction) {
    var item = type.start;
    while (item != null) {
      if (!item.deleted) {
        item.delete(transaction);
      } else if (item.id.clock <
          (transaction.beforeState[item.id.client] ?? 0)) {
        transaction.mergeStructs.add(item);
      }
      item = item.right as Item?;
    }
    for (var valueItem in type.map.values) {
      if (!valueItem.deleted) {
        valueItem.delete(transaction);
      } else if (valueItem.id.clock <
          (transaction.beforeState[valueItem.id.client] ?? 0)) {
        transaction.mergeStructs.add(valueItem);
      }
    }
    transaction.changed.remove(type);
  }

  @override
  void gc(StructStore store) {
    var item = type.start;
    while (item != null) {
      item.gc(store, true);
      item = item.right as Item?;
    }
    type.start = null;
    for (var kvp in type.map.entries) {
      Item? valueItem = kvp.value;
      while (valueItem != null) {
        valueItem.gc(store, true);
        valueItem = valueItem.left as Item?;
      }
    }
    type.map.clear();
  }

  @override
  void write(IUpdateEncoder encoder, int offset) {
    type.write(encoder);
  }

  static ContentType read(IUpdateDecoder decoder) {
    var typeRef = decoder.readTypeRef();
    if (typeRef == yArrayRefId) {
      var arr = YArray.read(decoder);
      return ContentType(arr);
    } else if (typeRef == yMapRefId) {
      var map = YMap.read(decoder);
      return ContentType(map);
    } else if (typeRef == yTextRefId) {
      var text = YText.read(decoder);
      return ContentType(text);
    }
    throw Exception("read ydoc type error.");
  }
}

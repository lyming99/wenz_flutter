/// 完成1次review
import 'dart:math';

import 'package:ydart/types/y_array_base.dart';
import 'package:ydart/utils/update_decoder.dart';
import 'package:ydart/utils/y_event.dart';

import '../structs/item.dart';
import '../utils/transaction.dart';
import '../utils/update_encoder.dart';
import '../utils/y_doc.dart';
import 'abstract_type.dart';

const yArrayRefId = 0;

class YArrayEvent extends YEvent {
  YArrayEvent(super.target,
      super.transaction,);
}

class YArray extends YArrayBase {
  /// 记录没有整合的内容
  final List<Object> _prelimContent = [];

  @override
  void integrate(YDoc? doc, Item? item) {
    super.integrate(doc, item);
    insert(0, _prelimContent);
  }

  @override
  void write(IUpdateEncoder encoder) {
    encoder.writeTypeRef(yArrayRefId);
  }

  static YArray read(IUpdateDecoder decoder) {
    return YArray();
  }

  @override
  void callObserver(Transaction transaction, Set<String> parentSubs) {
    super.callObserver(transaction, parentSubs);
    callTypeObservers(transaction, YArrayEvent(this, transaction));
  }

  void insert(int index, List<Object> content) {
    var doc = this.doc;
    if (doc != null) {
      doc.transact((tr) {
        insertGenerics(tr, index, content);
      });
    } else {
      _prelimContent.insertAll(index, content);
    }
  }

  void add(List<Object> content) {
    insert(length, content);
  }

  void delete(int index, [int length = 1]) {
    var doc = this.doc;
    if (doc != null) {
      doc.transact((tr) {
        deleteImpl(tr, index, length);
      });
    } else {
      _prelimContent.removeRange(index, index + length);
    }
  }

  List<Object> slice([int start = 0, int end = 0]) {
    return internalSlice(start, end);
  }

  Object? get(int index) {
    var mark = findMarker(index);
    var item = start;
    if (mark != null) {
      item = mark.p;
      index -= mark.index;
    }
    // 按照逻辑，right 只会是 item 或者 null，而不应该是 gc
    for (; item != null; item = item.right as Item?) {
      if (!item.deleted && item.countable) {
        if (index < item.length) {
          return item.content.getContent()[index];
        }
        index -= item.length;
      }
    }
    return null;
  }

  @override
  AbstractType internalCopy() {
    return YArray();
  }

  List<Object?> enumerateList() {
    var result = <Object?>[];
    var n = start;
    while (n != null) {
      if (n.countable && !n.deleted) {
        var c = n.content.getContent();
        for (var item in c) {
          result.add(item);
        }
      }
      n = n.right as Item?;
    }
    return result;
  }

  List<Object?> toJsonList() {
    return enumerateList().map((e) => contentToJsonValue(e)).toList();
  }
}

/// 完成1次review
import 'dart:typed_data';

import 'package:ydart/structs/base_content.dart';
import 'package:ydart/structs/content_any.dart';
import 'package:ydart/structs/content_binary.dart';
import 'package:ydart/structs/content_doc.dart';
import 'package:ydart/structs/content_type.dart';
import 'package:ydart/types/y_array.dart';
import 'package:ydart/types/y_map.dart';
import 'package:ydart/types/y_text.dart';
import 'package:ydart/utils/id.dart';
import 'package:ydart/utils/snapshot.dart';
import 'package:ydart/utils/transaction.dart';
import 'package:ydart/utils/update_encoder.dart';
import 'package:ydart/utils/y_doc.dart';
import 'package:ydart/utils/y_event.dart';

import '../structs/item.dart';

typedef EventHandler<T> = Function(Object object, T callback);

class YEventArgs {
  YEvent event;
  Transaction transaction;

  YEventArgs({
    required this.event,
    required this.transaction,
  });
}

class YDeepEventArgs {
  List<YEvent> events;
  Transaction transaction;

  YDeepEventArgs({
    required this.events,
    required this.transaction,
  });
}

class AbstractType {
  Item? item;
  Item? start;
  Map<String, Item> map = {};
  Map<Object, Object> holder = {};
  EventHandler<YEventArgs>? eventHandler;
  EventHandler<YDeepEventArgs>? deepEventHandler;
  YDoc? doc;
  int length = 0;

  AbstractType? get parent {
    var parent = item?.parent;
    if (parent is AbstractType) {
      return parent;
    }
    return null;
  }

  void integrate(YDoc? doc, Item? item) {
    this.doc = doc;
    this.item = item;
  }

  AbstractType internalCopy() {
    throw UnimplementedError();
  }

  AbstractType internalClone() {
    throw UnimplementedError();
  }

  void write(IUpdateEncoder encoder) {
    throw UnimplementedError();
  }

  void callTypeObservers(Transaction transaction, YEvent evt) {
    var type = this;
    while (true) {
      var values = transaction.changedParentTypes.putIfAbsent(type, () => []);
      values.add(evt);
      if (type.item == null) {
        break;
      }
      type = type.item!.parent as AbstractType;
    }
    invokeEventHandlers(evt, transaction);
  }

  void callObserver(Transaction transaction, Set<String> parentSubs) {}

  Item? first() {
    var n = start;
    while (n != null && n.deleted) {
      n = n.right as Item?;
    }
    return n;
  }

  void invokeEventHandlers(YEvent event, Transaction transaction) {
    eventHandler?.call(
        this, YEventArgs(event: event, transaction: transaction));
  }

  void callDeepEventHandlerListeners(List<YEvent> events,
      Transaction transaction) {
    deepEventHandler?.call(
        this, YDeepEventArgs(events: events, transaction: transaction));
  }

  String findRootTypeKey() {
    return doc!.findRootTypeKey(this);
  }

  void typeMapDelete(Transaction transaction, String key) {
    var value = map[key];
    value?.delete(transaction);
  }

  void typeMapSet(Transaction transaction, String key, Object? value) {
    var left = map[key];
    var doc = transaction.doc;
    var ownClientId = doc.clientId;
    IContentEx content;
    if (value is YDoc) {
      content = ContentDoc(value);
    } else if (value is Uint8List) {
      content = ContentBinary(value);
    } else if (value is AbstractType) {
      value.doc ??= doc;
      content = ContentType(value);
    } else {
      content = ContentAny(content: [value]);
    }
    var newItem = Item(
      id: ID(
        client: ownClientId,
        clock: doc.store.getState(ownClientId),
      ),
      left: left,
      leftOrigin: left?.lastId,
      parent: this,
      parentSub: key,
      content: content,
    );
    newItem.integrate(transaction, 0);
  }

  Object? tryTypeMapGet(String key) {
    var val = map[key];
    if (val != null && !val.deleted) {
      var content = val.content;
      var list = content.getContent();
      return list.last;
    }
    return null;
  }

  Object? typeMapGetSnapshot(String key, Snapshot snapshot) {
    var item = map[key];
    while (item != null &&
        item.id.clock >= (snapshot.stateVector[item.id.client] ?? -1)) {
      item = item.left as Item?;
    }
    return item != null && item.isVisible(snapshot)
        ? item.content.getContent()[item.length - 1]
        : null;
  }

  Map<String, Object?> typeMapEnumerateValues() {
    var result = <String, Object?>{};
    for (var entry in map.entries) {
      var key = entry.key;
      var value = entry.value;
      if (entry.value.deleted) {
        continue;
      }
      var lastItem = value.content
          .getContent()
          .last;
      result[key] = lastItem;
    }
    return result;
  }

  Object? contentToJsonValue(Object? lastItem) {
    Object? child;
    if (lastItem is YMap) {
      child = lastItem.toJsonMap();
    } else if (lastItem is YArray) {
      child = lastItem.toJsonList();
    } else if (lastItem is YText) {
      child = lastItem.toString();
    } else {
      child = lastItem;
    }
    return child;
  }

  Object toJson() {
    return contentToJsonValue(this)!;
  }
}

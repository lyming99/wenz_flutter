/// 完成1次review
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:ydart/structs/content_any.dart';
import 'package:ydart/structs/content_type.dart';
import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/utils/snapshot.dart';
import 'package:ydart/utils/transaction.dart';

import '../structs/content_binary.dart';
import '../structs/content_doc.dart';
import '../structs/item.dart';
import '../utils/id.dart';
import '../utils/y_doc.dart';

const maxSearchMarkers = 80;

class ArraySearchMarker {
  static int _timeTick = -1;
  int timestamp = 0;
  Item p;
  int index;

  ArraySearchMarker({
    required this.p,
    required this.index,
  }) {
    p.marker = true;
    refreshTimestamp();
  }

  void update(Item item, int index) {
    p.marker = false;
    p = item;
    p.marker = true;
    this.index = index;
    refreshTimestamp();
  }

  void refreshTimestamp() {
    timestamp = ++_timeTick;
  }
}

class ArraySearchMarkerCollection {
  final List<ArraySearchMarker> searchMarkers = [];

  int get length => searchMarkers.length;

  bool get isNotEmpty => searchMarkers.isNotEmpty;

  void clear() {
    searchMarkers.clear();
  }

  ArraySearchMarker markPosition(Item p, int index) {
    if (length >= maxSearchMarkers) {
      var marker =
          searchMarkers.reduce((a, b) => a.timestamp < b.timestamp ? a : b);
      marker.update(p, index);
      return marker;
    }

    var pm = ArraySearchMarker(p: p, index: index);
    searchMarkers.add(pm);
    return pm;
  }

  void updateMarkerChanges(int index, int len) {
    for (int i = searchMarkers.length - 1; i >= 0; i--) {
      var m = searchMarkers[i];
      if (len > 0) {
        Item? p = m.p;
        p.marker = false;
        while (p != null && (p.deleted || !p.countable)) {
          p = p.left as Item?;
          if (p != null && !p.deleted && p.countable) {
            m.index -= p.length;
          }
        }
        if (p == null || p.marker) {
          searchMarkers.removeAt(i);
          continue;
        }
        m.p = p;
        p.marker = true;
      }
      // A simple index <= m.Index check would actually suffice.
      if (index < m.index || (len > 0 && index == m.index)) {
        m.index = math.max(index, m.index + len);
      }
    }
  }
}

/// 封装了一些数组通用操作
class YArrayBase extends AbstractType {
  final ArraySearchMarkerCollection searchMarkers =
      ArraySearchMarkerCollection();

  void clearSearchMarkers() {
    searchMarkers.clear();
  }

  @override
  void callObserver(Transaction transaction, Set<String> parentSubs) {
    if (!transaction.local) {
      searchMarkers.clear();
    }
  }

  /// 通用的 insert
  void insertGenerics(
      Transaction transaction, int index, List<Object> content) {
    if (index == 0) {
      if (searchMarkers.length > 0) {
        searchMarkers.updateMarkerChanges(index, content.length);
      }
      insertGenericsAfter(transaction, null, content);
      return;
    }
    int startIndex = index;
    ArraySearchMarker? marker = findMarker(index);
    var n = start;

    if (marker != null) {
      n = marker.p;
      index -= marker.index;

      // We need to iterate one to the left so that the algorithm works.
      if (index == 0) {
        n = n.prev as Item?;
        index += n != null && n.countable && !n.deleted ? n.length : 0;
      }
    }

    for (; n != null; n = n.right as Item?) {
      if (!n.deleted && n.countable) {
        if (index <= n.length) {
          if (index < n.length) {
            // insert in-between
            transaction.doc.store.getItemCleanStart(transaction,
                ID(client: n.id.client, clock: n.id.clock + index));
          }
          break;
        }
        index -= n.length;
      }
    }

    if (searchMarkers.length > 0) {
      searchMarkers.updateMarkerChanges(startIndex, content.length);
    }

    insertGenericsAfter(transaction, n, content);
  }

  /// 通用的 insert after
  /// 即字面意思，在 reference item 后面创建一个新的 item,新的 item 的内容为 content
  void insertGenericsAfter(
      Transaction transaction, Item? referenceItem, List<Object> content) {
    var left = referenceItem;
    var doc = transaction.doc;
    var ownClientId = doc.clientId;
    var store = doc.store;
    var right = referenceItem == null ? start : referenceItem.right as Item?;

    var jsonContent = <Object>[];

    void packJsonContent() {
      if (jsonContent.isNotEmpty) {
        left = Item(
            id: ID(client: ownClientId, clock: store.getState(ownClientId)),
            left: left,
            leftOrigin: left?.lastId,
            right: right,
            rightOrigin: right?.id,
            parent: this,
            parentSub: null,
            content: ContentAny(content: jsonContent));
        left!.integrate(transaction, 0);
        jsonContent.clear();
      }
    }

    for (var c in content) {
      switch (c) {
        case Uint8List arr:
          packJsonContent();
          left = Item(
            id: ID(
              client: ownClientId,
              clock: store.getState(ownClientId),
            ),
            left: left,
            leftOrigin: left?.lastId,
            right: right,
            rightOrigin: right?.id,
            parent: this,
            content: ContentBinary( arr),
          );
          left!.integrate(transaction, 0);
          break;
        case YDoc d:
          packJsonContent();
          left = Item(
              id: ID(client: ownClientId, clock: store.getState(ownClientId)),
              left: left,
              leftOrigin: left?.lastId,
              right: right,
              rightOrigin: right?.id,
              parent: this,
              content: ContentDoc(d));
          left!.integrate(transaction, 0);
          break;
        case AbstractType at:
          packJsonContent();
          left = Item(
              id: ID(client: ownClientId, clock: store.getState(ownClientId)),
              left: left,
              leftOrigin: left?.lastId,
              right: right,
              rightOrigin: right?.id,
              parent: this,
              content: ContentType(at));
          left!.integrate(transaction, 0);
          break;
        default:
          jsonContent.add(c);
          break;
      }
    }
    packJsonContent();
  }

  void deleteImpl(Transaction transaction, int index, int length) {
    if (length == 0) {
      return;
    }
    int startIndex = index;
    int startLength = length;
    var marker = findMarker(index);
    var n = start;
    if (marker != null) {
      n = marker.p;
      index -= marker.index;
    }
    // Compute the first item to be deleted.
    for (; n != null && index > 0; n = n.right as Item?) {
      if (!n.deleted && n.countable) {
        if (index < n.length) {
          transaction.doc.store.getItemCleanStart(
              transaction, ID(client: n.id.client, clock: n.id.clock + index));
        }
        index -= n.length;
      }
    }
    // Delete all items until done.
    while (length > 0 && n != null) {
      if (!n.deleted) {
        if (length < n.length) {
          transaction.doc.store.getItemCleanStart(
              transaction, ID(client: n.id.client, clock: n.id.clock + length));
        }
        n.delete(transaction);
        length -= n.length;
      }
      n = n.right as Item?;
    }
    if (length > 0) {
      throw Exception("Array length exceeded");
    }
    if (searchMarkers.length > 0) {
      searchMarkers.updateMarkerChanges(startIndex, -startLength + length);
    }
  }

  List<Object> internalSlice(int start, int end) {
    if (start < 0) {
      start += length;
    }
    if (end < 0) {
      end += length;
    }
    if (start < 0 || end < 0 || start < end) {
      throw RangeError("$start,$end");
    }
    int len = end - start;
    var cs = <Object>[];
    var item = this.start;
    while (item != null && len > 0) {
      if (item.countable && !item.deleted) {
        var content = item.content.getContent();
        if (content.length <= start) {
          start -= content.length;
        } else {
          for (int i = start; i < content.length && len > 0; i++) {
            cs.add(content[i]!);
            len--;
          }
          start = 0;
        }
      }
      item = item.right as Item?;
    }
    return cs;
  }

  void foreEach(Function(Object? item, int index) fun) {
    int index = 0;
    var n = start;
    while (n != null) {
      if (n.countable && !n.deleted) {
        var c = n.content.getContent();
        for (var cItem in c) {
          fun(cItem, index++);
        }
      }
      n = n.right as Item?;
    }
  }

  void forEachSnapshot(
      Function(Object? item, int index) fun, Snapshot snapshot) {
    int index = 0;
    var n = start;
    while (n != null) {
      if (n.countable && n.isVisible(snapshot)) {
        var c = n.content.getContent();
        for (var value in c) {
          fun(value, index++);
        }
      }
    }
  }

  ArraySearchMarker? findMarker(int index) {
    var p = start;
    if (p == null || index == 0 || searchMarkers.length == 0) {
      return null;
    }
    var marker = searchMarkers.length == 0
        ? null
        : searchMarkers.searchMarkers.reduce((a, b) =>
            ((index - a.index).abs() < (index - b.index).abs()) ? a : b);

    int pIndex = 0;
    if (marker != null) {
      p = marker.p;
      pIndex = marker.index;
      marker.refreshTimestamp();
    }
    while (p != null && p.right != null && pIndex < index) {
      if (!p.deleted && p.countable) {
        if (index < pIndex + p.length) {
          break;
        }
        pIndex += p.length;
      }
      p = p.right as Item;
    }
    while (p != null && p.left != null && pIndex > index) {
      p = p.left as Item;
      if (!p.deleted && p.countable) {
        pIndex -= p.length;
      }
    }
    while (p != null &&
        p.left != null &&
        p.left!.id.client == p.id.client &&
        p.left!.id.clock + p.left!.length == p.id.clock) {
      p = p.left as Item?;
      if (p == null) {
        break;
      }
      if (!p.deleted && p.countable) {
        pIndex -= p.length;
      }
    }
    if (p != null &&
        marker != null &&
        (marker.index - pIndex).abs() <
            ((p.parent as AbstractType).length / maxSearchMarkers)) {
      marker.update(p, pIndex);
      return marker;
    }
    return searchMarkers.markPosition(p!, pIndex);
  }
}

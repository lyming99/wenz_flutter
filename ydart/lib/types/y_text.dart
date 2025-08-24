import 'dart:io';

import 'package:ydart/structs/content_embed.dart';
import 'package:ydart/structs/content_format.dart';
import 'package:ydart/structs/content_string.dart';
import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/types/y_array_base.dart';
import 'package:ydart/utils/id.dart';
import 'package:ydart/utils/snapshot.dart';
import 'package:ydart/utils/transaction.dart';
import 'package:ydart/utils/update_encoder.dart';
import 'package:ydart/utils/y_doc.dart';
import 'package:ydart/utils/y_event.dart';

import '../structs/item.dart';
import '../utils/update_decoder.dart';

const yTextRefId = 2;
const changeKey = "ychange";

enum ChangeType { insert, delete, retain }

enum YTextChangeType { added, removed }

class YTextChangeAttributes {
  YTextChangeType? type;
  int? user;
  YTextChangeType? state;

  YTextChangeAttributes({
    this.type,
    this.user,
    this.state,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type?.index,
      'user': user,
      'state': state?.index,
    };
  }

  factory YTextChangeAttributes.fromMap(dynamic map) {
    var temp;
    return YTextChangeAttributes(
      type: null == (temp = map['type'])
          ? null
          : (temp is num
              ? YTextChangeType.values[temp.toInt()]
              : YTextChangeType.values[int.tryParse(temp) ?? 0]),
      user: null == (temp = map['user'])
          ? null
          : (temp is num ? temp.toInt() : int.tryParse(temp)),
      state: null == (temp = map['state'])
          ? null
          : (temp is num
              ? YTextChangeType.values[temp.toInt()]
              : YTextChangeType.values[int.tryParse(temp) ?? 0]),
    );
  }
}

class YTextEvent extends YEvent {
  Set<String>? subs;
  List<Delta>? _delta;
  Set<String>? keysChanged;
  bool childListChanged = false;

  YTextEvent(
    super.target,
    super.transaction,
    this.subs,
  );

  List<Delta> get delta {
    var delta = _delta;
    if (delta == null) {
      _delta = delta = <Delta>[];
      var doc = target.doc;
      if (doc != null) {
        doc.transact((tr) {
          _computeDelta(target, tr, delta!);
        });
      }
    }
    return delta;
  }

  void _computeDelta(AbstractType target, Transaction tr, List<Delta> delta) {
    var currentAttributes = <String, Object?>{};
    var oldAttributes = <String, Object?>{};
    var item = target.start;
    ChangeType? action;
    var attributes = <String, Object?>{};
    Object insert = "";
    int retain = 0;
    int deleteLen = 0;
    void addOp() {
      if (action == null) {
        return;
      }
      Delta op;
      if (action case ChangeType.delete) {
        op = Delta(delete: deleteLen);
        deleteLen = 0;
      } else if (action case ChangeType.insert) {
        op = Delta(insert: insert);
        if (currentAttributes.isNotEmpty) {
          var attr = op.attributes = <String, Object?>{};
          attr.addAll(currentAttributes);
        }
      } else if (action case ChangeType.retain) {
        op = Delta(retain: retain);
        if (attributes.isNotEmpty) {
          var attr = op.attributes = <String, Object?>{};
          attr.addAll(attributes);
        }
        retain = 0;
      } else {
        throw Exception("type error.");
      }
      delta.add(op);
      action = null;
    }

    while (item != null) {
      var content = item.content;
      if (content is ContentEmbed) {
        if (adds(item)) {
          if (!deletes(item)) {
            addOp();
            action = ChangeType.insert;
            insert = content.embed;
            addOp();
          }
        } else if (deletes(item)) {
          if (action != ChangeType.delete) {
            addOp();
            action = ChangeType.delete;
          }
          deleteLen++;
        } else if (!item.deleted) {
          if (action != ChangeType.retain) {
            addOp();
            action = ChangeType.retain;
          }
          retain++;
        }
      } else if (content is ContentString) {
        if (adds(item)) {
          if (!deletes(item)) {
            if (action != ChangeType.insert) {
              addOp();
              action = ChangeType.insert;
            }
            // 能否使用StringBuffer增加性能？
            insert = "$insert${content.content}";
          }
        } else if (deletes(item)) {
          if (action != ChangeType.delete) {
            addOp();
            action = ChangeType.delete;
          }
          deleteLen += item.length;
        } else if (!item.deleted) {
          if (action != ChangeType.retain) {
            addOp();
            action = ChangeType.retain;
          }
          retain += item.length;
        }
      } else if (content is ContentFormat) {
        if (adds(item)) {
          if (!deletes(item)) {
            var curVal = currentAttributes[content.key];
            if (!YText.equalAttrs(curVal, content.value)) {
              if (action == ChangeType.retain) {
                addOp();
              }
              var oldVal = oldAttributes[content.key];
              if (YText.equalAttrs(content.value, oldVal)) {
                attributes.remove(content.key);
              } else {
                attributes[content.key] = content.value;
              }
            } else {
              item.delete(tr);
            }
          }
        } else if (deletes(item)) {
          oldAttributes[content.key] = content.value;
          var curVal = currentAttributes[content.key];
          if (!YText.equalAttrs(curVal, content.value)) {
            if (action == ChangeType.retain) {
              addOp();
            }
            attributes[content.key] = curVal;
          }
        } else if (!item.deleted) {
          oldAttributes[content.key] = content.value;
          var attr = attributes[content.key];
          if (!YText.equalAttrs(attr, content.value)) {
            if (action == ChangeType.retain) {
              addOp();
            }
            if (content.value == null) {
              attributes[content.key] = null;
            } else {
              attributes.remove(content.key);
            }
          } else {
            item.delete(tr);
          }
        }
        if (!item.deleted) {
          if (action == ChangeType.insert) {
            addOp();
          }
          YText.updateCurrentAttributes(currentAttributes, content);
        }
      }
      item = item.right as Item?;
    }
    addOp();
    while (delta.isNotEmpty) {
      var lastOp = delta.last;
      if (lastOp.retain != null && lastOp.attributes != null) {
        delta.removeLast();
      } else {
        break;
      }
    }
  }
}

class ItemTextListPosition {
  Item? left;
  Item? right;
  int index;
  Map<String, Object?> currentAttributes;

  ItemTextListPosition({
    this.left,
    this.right,
    required this.index,
    required this.currentAttributes,
  });

  factory ItemTextListPosition.create(Item? left, Item? right, int index,
      Map<String, Object> currentAttributes) {
    return ItemTextListPosition(
      left: left,
      right: right,
      index: index,
      currentAttributes: currentAttributes,
    );
  }

  void forward() {
    var right = this.right;
    if (right == null) {
      throw Exception("unexpected");
    }
    if (right.content is ContentFormat) {
      if (!right.deleted) {
        YText.updateCurrentAttributes(
            currentAttributes, right.content as ContentFormat);
      }
    } else {
      if (!right.deleted) {
        index += right.length;
      }
    }
    left = right;
    this.right = right.right as Item?;
  }

  void findNextPosition(Transaction transaction, int count) {
    var right = this.right;
    while (right != null && count > 0) {
      var rContent = right.content;
      if (rContent is ContentFormat) {
        if (!right.deleted) {
          YText.updateCurrentAttributes(currentAttributes, rContent);
        }
      } else {
        if (!right.deleted) {
          if (count < right.length) {
            transaction.doc.store.getItemCleanStart(transaction,
                ID(client: right.id.client, clock: right.id.clock + count));
          }
          index+=right.length;
          count-=right.length;
        }
      }
      left = right;
      this.right = right = right.right as Item?;
    }
  }

  void insertNegatedAttributes(Transaction transaction, AbstractType parent,
      Map<String, Object?> negatedAttributes) {
    bool loopCheck() {
      var right = this.right;
      if (right == null) {
        return false;
      }
      if (right.deleted) {
        return true;
      }
      var content = right.content;
      if (content is ContentFormat) {
        if (negatedAttributes.containsKey(content.key)) {
          if (YText.equalAttrs(negatedAttributes[content.key], content.value)) {
            return true;
          }
        }
      }
      return false;
    }

    while (loopCheck()) {
      if (!this.right!.deleted) {
        negatedAttributes.remove((this.right!.content as ContentFormat).key);
      }
      forward();
    }
    var doc = transaction.doc;
    var ownClientId = doc.clientId;
    var left = this.left;
    var right = this.right;
    for (var kvp in negatedAttributes.entries) {
      left = Item.create(
        ID.create(ownClientId, doc.store.getState(ownClientId)),
        left,
        left?.lastId,
        right,
        right?.id,
        parent,
        null,
        ContentFormat.create(kvp.key, kvp.value),
        1,
      );
      left.integrate(transaction, 0);
      if (kvp.key == null) {
        print("null");
      }
      if (kvp.value == null) {
        currentAttributes.remove(kvp.key);
      } else {
        currentAttributes[kvp.key] = kvp.value;
      }
      YText.updateCurrentAttributes(
          currentAttributes, left.content as ContentFormat);
    }
  }

  void minimizeAttributeChanges(Map<String, Object?> attributes) {
    bool checkForward() {
      if (right!.deleted) {
        return true;
      }
      var content = right!.content;
      if (content is! ContentFormat) {
        return false;
      }
      var val = attributes[content.key];
      if (YText.equalAttrs(val, content.value)) {
        return true;
      }
      return false;
    }

    while (right != null) {
      if (!checkForward()) {
        break;
      }
      forward();
    }
  }
}

class YText extends YArrayBase {
  final List<Function> _pending = [];

  bool hasFormatting = false;

  YText([String text = ""]) {
    if (text.isNotEmpty) {
      _pending.add(() => insert(0, text));
    }
  }

  void applyDelta(List<Delta> delta, [bool sanitize = true]) {
    var doc = this.doc;
    if (doc == null) {
      _pending.add(() => applyDelta(delta, sanitize));
      return;
    }
    doc.transact((tr) {
      var curPos = ItemTextListPosition.create(null, start, 0, {});
      for (int i = 0; i < delta.length; i++) {
        var op = delta[i];
        if (op.insert != null) {
          var insertStr = op.insert as String;
          var ins = (!sanitize &&
                  i == delta.length - 1 &&
                  curPos.right == null &&
                  insertStr.endsWith("\n"))
              ? insertStr.substring(0, insertStr.length - 1)
              : op.insert;
          if (ins is! String || ins.isNotEmpty) {
            insertText(tr, curPos, ins!, op.attributes ?? {});
          }
        } else if (op.retain != null) {
          formatText(tr, curPos, op.retain!, op.attributes ?? {});
        } else if (op.delete != null) {
          deleteText(tr, curPos, op.delete!);
        }
      }
    });
  }

  List<Delta> toDelta({
    Snapshot? snapshot,
    Snapshot? prevSnapshot,
    YTextChangeAttributes Function(YTextChangeType type, ID id)? computeYChange,
  }) {
    var ops = <Delta>[];
    var currentAttributes = <String, Object>{};
    var doc = this.doc;
    var str = "";

    void packStr() {
      if (str.isNotEmpty) {
        // Pack str with attributes to ops.
        var attributes = <String, Object>{};
        var addAttributes = false;

        for (var kvp in currentAttributes.entries) {
          addAttributes = true;
          attributes[kvp.key] = kvp.value;
        }

        var op = Delta(insert: str);
        if (addAttributes) {
          op.attributes = attributes;
        }
        ops.add(op);
        str = "";
      }
    }

    void update(tr) {
      if (snapshot != null) {
        Transaction.splitSnapshotAffectedStructs(tr, snapshot);
      }

      if (prevSnapshot != null) {
        Transaction.splitSnapshotAffectedStructs(tr, prevSnapshot);
      }
      var n = start;
      while (n != null) {
        bool isSnapshotVisible = n.isVisible(snapshot);
        bool isPrevSnapshotVisible =
            prevSnapshot != null && n.isVisible(prevSnapshot);
        if (isSnapshotVisible || isPrevSnapshotVisible) {
          var content = n.content;
          if (content is ContentString) {
            var cur = currentAttributes[changeKey] as YTextChangeAttributes?;
            if (isSnapshotVisible) {
              if (cur == null ||
                  cur.user != n.id.client ||
                  cur.state != YTextChangeType.removed) {
                packStr();
                currentAttributes[changeKey] = computeYChange != null
                    ? computeYChange(YTextChangeType.removed, n.id)
                    : YTextChangeAttributes(
                        type: YTextChangeType.removed,
                      );
              }
            } else if (isPrevSnapshotVisible) {
              if (cur == null ||
                  cur.user != n.id.client ||
                  cur.state != YTextChangeType.added) {
                packStr();
                currentAttributes[changeKey] = computeYChange != null
                    ? computeYChange(YTextChangeType.added, n.id)
                    : YTextChangeAttributes(type: YTextChangeType.added);
              }
            } else if (cur != null) {
              packStr();
              currentAttributes.remove(changeKey);
            }
            str += content.content;
          }
          if (content is ContentEmbed) {
            packStr();
            var op = Delta(insert: content.embed);
            if (currentAttributes.isNotEmpty) {
              op.attributes = Map.from(currentAttributes);
            }
            ops.add(op);
          }
          if (content is ContentFormat) {
            if (isSnapshotVisible) {
              packStr();
              updateCurrentAttributes(currentAttributes, content);
            }
          }
        }

        n = n.right as Item?;
      }
      packStr();
    }

    doc?.transact(update, origin: "splitSnapshotAffectedStructs");
    return ops;
  }

  void insert(int index, String text, [Map<String, Object?>? attributes]) {
    if (text.isEmpty) {
      return;
    }
    var doc = this.doc;
    if (doc == null) {
      _pending.add(() => insert(index, text, attributes));
      return;
    }
    doc.transact(
      (tr) {
        var pos = findPosition(tr, index);
        attributes ??= Map.from(pos.currentAttributes);
        insertText(tr, pos, text, attributes);
      },
    );
  }

  void insertEmbed(int index, Object embed, [Map<String, Object>? attributes]) {
    attributes ??= {};
    var doc = this.doc;
    if (doc == null) {
      _pending.add(() => insertEmbed(index, embed, attributes));
      return;
    }
    doc.transact((tr) {
      var pos = findPosition(tr, index);
      insertText(tr, pos, embed, attributes);
    });
  }

  void delete(int index, int length) {
    if (length == 0) {
      return;
    }
    var doc = this.doc;
    if (doc == null) {
      _pending.add(() => delete(index, length));
      return;
    }
    doc.transact((tr) {
      deleteText(tr, findPosition(tr, index), length);
    });
  }

  void format(int index, int length, Map<String, Object?> attributes) {
    if (length == 0) {
      return;
    }
    var doc = this.doc;
    if (doc == null) {
      _pending.add(() => format(index, length, attributes));
      return;
    }
    doc.transact((tr) {
      var pos = findPosition(tr, index);
      if (pos.right == null) {
        return;
      }
      formatText(tr, pos, length, attributes);
    });
  }

  @override
  String toString() {
    var sb = StringBuffer();
    var n = start;
    while (n != null) {
      var content = n.content;
      if (!n.deleted && n.countable && content is ContentString) {
        sb.write(content.content);
      }
      n = n.right as Item?;
    }
    return sb.toString();
  }

  void removeAttribute(String name) {
    var doc = this.doc;
    if (doc == null) {
      _pending.add(() => removeAttribute(name));
      return;
    }
    doc.transact((tr) => typeMapDelete(tr, name));
  }

  void setAttribute(String name, Object value) {
    var doc = this.doc;
    if (doc == null) {
      _pending.add(() => setAttribute(name, value));
      return;
    }
    doc.transact((tr) {
      typeMapSet(tr, name, value);
    });
  }

  Object? getAttribute(String name) {
    return tryTypeMapGet(name);
  }

  Map<String, Object?>? getAttributes() {
    return typeMapEnumerateValues();
  }

  @override
  void integrate(YDoc? doc, Item? item) {
    super.integrate(doc, item);
    for (var c in _pending) {
      c.call();
    }
    _pending.clear();
  }

  @override
  void callObserver(Transaction transaction, Set<String> parentSubs) {
    super.callObserver(transaction, parentSubs);
    var evt = YTextEvent(this, transaction, parentSubs);
    var doc = transaction.doc;
    if (!transaction.local) {
      var foundFormattingItem = false;
      for (var kvp in transaction.afterState.entries) {
        var client = kvp.key;
        var afterClock = kvp.value;
        var clock = transaction.beforeState[kvp.key] ?? 0;
        if (afterClock == clock) {
          continue;
        }
        transaction.doc.store.iterateStructs(
          transaction,
          doc.store.clients[client]!,
          clock,
          afterClock,
          (item) {
            if (item is Item) {
              if (!item.deleted && item.content is ContentFormat) {
                foundFormattingItem = true;
                return false;
              }
            }
            return true;
          },
        );
        if (foundFormattingItem) {
          break;
        }
      }
      if (!foundFormattingItem) {
        transaction.deleteSet.iterateDeletedStructs(
          transaction,
          (item) {
            if (item is! Item) {
              return true;
            }
            if (item.parent == this && item.content is ContentFormat) {
              foundFormattingItem = true;
              return false;
            }
            return true;
          },
        );
      }
      doc.transact((transaction) {
        if (foundFormattingItem) {
          cleanupFormatting();
          return;
        }
        transaction.deleteSet.iterateDeletedStructs(
          transaction,
          (item) {
            if (item is Item && item.parent == this) {
              cleanupContextlessFormattingGap(transaction, item);
            }
            return true;
          },
        );
      });
    }
    callTypeObservers(transaction, evt);
  }

  ItemTextListPosition findPosition(Transaction transaction, int index) {
    var currentAttributes = <String, Object>{};
    var marker = findMarker(index);

    if (marker != null) {
      var pos = ItemTextListPosition.create(
          marker.p.left as Item?, marker.p, marker.index, currentAttributes);
      pos.findNextPosition(transaction, index - marker.index);
      return pos;
    } else {
      var pos = ItemTextListPosition.create(null, start, 0, currentAttributes);
      pos.findNextPosition(transaction, index);
      return pos;
    }
  }

  Map<String, Object?> insertAttributes(Transaction transaction,
      ItemTextListPosition currPos, Map<String, dynamic> attributes) {
    var doc = transaction.doc;
    var ownClientId = doc.clientId;
    var negatedAttributes = <String, Object?>{};

    for (var kvp in attributes.entries) {
      var key = kvp.key;
      var value = kvp.value;

      var currentVal = currPos.currentAttributes[key];

      if (!equalAttrs(currentVal, value)) {
        negatedAttributes[key] = currentVal;

        currPos.right = Item.create(
            ID.create(ownClientId, doc.store.getState(ownClientId)),
            currPos.left,
            currPos.left?.lastId,
            currPos.right,
            currPos.right?.id,
            this,
            null,
            ContentFormat.create(key, value),
            1);
        currPos.right?.integrate(transaction, 0);
        currPos.forward();
      }
    }

    return negatedAttributes;
  }

  void insertText(Transaction transaction, ItemTextListPosition currPos,
      Object text, Map<String, Object?>? attributes) {
    attributes = attributes ?? {};
    for (var kvp in currPos.currentAttributes.entries) {
      if (!attributes.containsKey(kvp.key)) {
        attributes[kvp.key] = null;
      }
    }

    var doc = transaction.doc;
    var ownClientId = doc.clientId;

    currPos.minimizeAttributeChanges(attributes);
    var negatedAttributes = insertAttributes(transaction, currPos, attributes);

    // Insert content.
    var content = text is String ? ContentString(text) : ContentEmbed(text);
    if (searchMarkers.length > 0) {
      searchMarkers.updateMarkerChanges(currPos.index, content.length);
    }

    currPos.right = Item.create(
      ID.create(ownClientId, doc.store.getState(ownClientId)),
      currPos.left,
      currPos.left?.lastId,
      currPos.right,
      currPos.right?.id,
      this,
      null,
      content,
    );
    currPos.right?.integrate(transaction, 0);
    currPos.forward();
    currPos.insertNegatedAttributes(transaction, this, negatedAttributes);
  }

  void formatText(Transaction transaction, ItemTextListPosition curPos,
      int length, Map<String, Object?> attributes) {
    var doc = transaction.doc;
    var ownClientId = doc.clientId;

    curPos.minimizeAttributeChanges(attributes);
    var negatedAttributes = insertAttributes(transaction, curPos, attributes);

    while (length > 0 && curPos.right != null) {
      if (!curPos.right!.deleted) {
        switch (curPos.right!.content.runtimeType) {
          case ContentFormat:
            var cf = curPos.right!.content as ContentFormat;
            if (attributes.containsKey(cf.key)) {
              var attr = attributes[cf.key];
              if (equalAttrs(attr, cf.value)) {
                negatedAttributes.remove(cf.key);
              } else {
                negatedAttributes[cf.key] = cf.value;
              }

              curPos.right!.delete(transaction);
            }
            break;
          case ContentEmbed:
          case ContentString:
            if (length < curPos.right!.length) {
              doc.store.getItemCleanStart(
                  transaction,
                  ID.create(curPos.right!.id.client,
                      curPos.right!.id.clock + length));
            }
            length -= curPos.right!.length;
            break;
        }
      }

      curPos.forward();
    }

    if (length > 0) {
      var newLines = '\n' * (length - 1);
      curPos.right = Item.create(
        ID.create(ownClientId, doc.store.getState(ownClientId)),
        curPos.left,
        curPos.left?.lastId,
        curPos.right,
        curPos.right?.id,
        this,
        null,
        ContentString(newLines),
      );
      curPos.right!.integrate(transaction, 0);
      curPos.forward();
    }

    curPos.insertNegatedAttributes(transaction, this, negatedAttributes);
  }

  int cleanupFormattingGap(Transaction transaction, Item? start, Item? end,
      Map<String, Object> startAttributes, Map<String, Object> endAttributes) {
    while (end != null &&
        end.content is! ContentString &&
        end.content is! ContentEmbed) {
      if (!end.deleted && end.content is ContentFormat) {
        updateCurrentAttributes(endAttributes, end.content as ContentFormat);
      }
      end = end.right as Item?;
    }
    int cleanups = 0;
    while (start != null && start != end) {
      if (!start.deleted) {
        var content = start.content;
        if (content is ContentFormat) {
          var cf = content;
          var endVal =
              endAttributes.containsKey(cf.key) ? endAttributes[cf.key] : null;
          var startVal = startAttributes.containsKey(cf.key)
              ? startAttributes[cf.key]
              : null;
          if (endVal != cf.value ||
              !(endVal == cf.value) ||
              startVal == cf.value ||
              (startVal == cf.value)) {
            start.delete(transaction);
            cleanups++;
          }
        }
      }
      start = start.right as Item?;
    }
    return cleanups;
  }

  void cleanupContextlessFormattingGap(Transaction transaction, Item? item) {
    while (item != null &&
        item.right != null &&
        (item.right!.deleted ||
            (item.right! as Item).content is! ContentString &&
                (item.right! as Item).content is! ContentEmbed)) {
      item = item.right as Item?;
    }

    var attrs = <Object>{};

    while (item != null &&
        (item.deleted ||
            item.content is! ContentString && item.content is! ContentEmbed)) {
      if (!item.deleted && item.content is ContentFormat) {
        var cf = item.content as ContentFormat;
        var key = cf.key;
        if (attrs.contains(key)) {
          item.delete(transaction);
        } else {
          attrs.add(key);
        }
      }

      item = item.left as Item?;
    }
  }

  int cleanupFormatting() {
    int res = 0;

    doc?.transact((transaction) {
      var start = this.start;
      var end = this.start;
      var startAttributes = <String, Object>{};
      var currentAttributes = <String, Object>{};

      while (end != null) {
        if (!end.deleted) {
          switch (end.content.runtimeType) {
            case ContentFormat:
              updateCurrentAttributes(
                  currentAttributes, end.content as ContentFormat);
              break;
            case ContentEmbed:
            case ContentString:
              res += cleanupFormattingGap(
                  transaction, start, end, startAttributes, currentAttributes);
              startAttributes = Map<String, Object>.from(currentAttributes);
              start = end;
              break;
          }
        }

        end = end.right as Item;
      }
    });

    return res;
  }

  ItemTextListPosition deleteText(
      Transaction transaction, ItemTextListPosition curPos, int length) {
    var startLength = length;
    var startAttrs = Map<String, Object>.from(curPos.currentAttributes);
    var start = curPos.right;

    while (length > 0 && curPos.right != null) {
      if (!curPos.right!.deleted) {
        switch (curPos.right!.content.runtimeType) {
          case ContentType:
          case ContentEmbed:
          case ContentString:
            if (length < curPos.right!.length) {
              transaction.doc.store.getItemCleanStart(
                  transaction,
                  ID.create(curPos.right!.id.client,
                      curPos.right!.id.clock + length));
            }
            length -= curPos.right!.length;
            curPos.right!.delete(transaction);
            break;
        }
      }
      curPos.forward();
    }
    if (start != null) {
      cleanupFormattingGap(transaction, start, curPos.right, startAttrs,
          Map<String, Object>.from(curPos.currentAttributes));
    }
    var parent = (curPos.left ?? curPos.right)!.parent as YText;
    if (parent.searchMarkers.isNotEmpty) {
      parent.searchMarkers
          .updateMarkerChanges(curPos.index, -startLength + length);
    }
    return curPos;
  }

  @override
  void write(IUpdateEncoder encoder) {
    encoder.writeTypeRef(yTextRefId);
  }

  static YText read(IUpdateDecoder decoder) {
    return YText("");
  }

  static void updateCurrentAttributes(
      Map<String, Object?> attributes, ContentFormat format) {
    if (format.value == null) {
      attributes.remove(format.key);
    } else {
      attributes[format.key] = format.value;
    }
  }

  @override
  AbstractType internalCopy() {
    return YText();
  }

  static bool equalAttrs(Object? curVal, Object? value) {
    return curVal == value;
  }
}

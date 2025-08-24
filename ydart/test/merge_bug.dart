import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ydart/types/y_array.dart';
import 'package:ydart/types/y_map.dart';
import 'package:ydart/types/y_text.dart';
import 'package:ydart/utils/delete_set.dart';
import 'package:ydart/utils/undo_manager.dart';
import 'package:ydart/utils/y_doc.dart';

var random = Random();
// 问题1：delete没有正常合并所有 item
// 问题2：apply时删除了多余的 item
void main() {
  var doc = YDoc();
  randomTest1(doc, doc.getArray("blocks"));
}
void testDelete(){
  var doc = YDoc();
  var text = doc.getText("blocks");
  text.insert(0, "hello");
  text.insert(1, "hello");
  text.insert(7, "hello");
  text.insert(3, "hello");
  text.insert(11, "hello");
  text.insert(17, "hello");
  var doc1 = doc.encodeStateAsUpdateV2();
  text.delete(11, 4);
  text.delete(3, 10);
  var doc2 = doc.encodeStateAsUpdateV2();
  mergeDocTest(doc1, doc2);
}

void printDs(Map<int, List<DeleteItem>> ds) {
  var text= ds.values.map((e) => e.map((e) => e.toString()).join(",")).join("|");
  print(text);
}

void randomTest1(YDoc doc, YArray array) {
  var um = UndoManager.create(array);
  // 随机模拟操作
  for (var i = 0; i < 10000; i++) {
    print("正在测试中:$i");
    var doc1 = doc.encodeStateAsUpdateV2();
    doRandomOp(um, array);
    var doc2 = doc.encodeStateAsUpdateV2();
    mergeDocTest(doc1, doc2);
    sleep(const Duration(milliseconds: 1));
  }
}
void randomTest2(YDoc doc, YText text) {
  var um = UndoManager.create(text);
  // 随机模拟操作
  for (var i = 0; i < 10000; i++) {
    print("正在测试中:$i");
    var doc1 = doc.encodeStateAsUpdateV2();
    doRandomOp2(um, text);
    var doc2 = doc.encodeStateAsUpdateV2();
    mergeDocTest(doc1, doc2);
    sleep(const Duration(milliseconds: 1));
  }
}

void doRandomOp(UndoManager um, YArray blocks) {
  void undo(UndoManager um, YArray blocks) {
    um.undo();
  }

  void redo(UndoManager um, YArray blocks) {
    um.undo();
  }

  void insertText(UndoManager um, YArray blocks) {
    var n = blocks.length;
    if (n == 0) {
      blocks.insert(0, [YMap()]);
      return;
    }
    var i = random.nextInt(n);
    // blocks.insert(i, [YMap()]);
    var map = blocks.get(i) as YMap;
    if (!map.containsKey("text")) {
      map.set("text", YText());
    }
    var text = map.get("text") as YText;
    var len = text.length;
    if (len == 0) {
      text.insert(0, "hello" * (random.nextInt(10) + 1));
    } else {
      text.insert(random.nextInt(len), "hello" * (random.nextInt(10) + 1));
    }
  }

  void deleteText(UndoManager um, YArray blocks) {
    var n = blocks.length;
    if (n == 0) {
      blocks.insert(0, [YMap()]);
      return;
    }
    var i = random.nextInt(n);
    var map = blocks.get(i) as YMap;
    if (!map.containsKey("text")) {
      map.set("text", YText());
    }
    var text = map.get("text") as YText;
    var len = text.length;
    if (len == 0) {
      return;
    }
    var deleteIndex = random.nextInt(len);
    if (deleteIndex == len - 1) {
      text.delete(deleteIndex, 1);
    } else {
      text.delete(deleteIndex, random.nextInt(len - deleteIndex - 1) + 1);
    }
  }

  var priority = [0, 0, 30, 3];
  var sum = priority.reduce((value, element) => value + element);
  var functions = [undo, redo, insertText, deleteText];
  var doCount = random.nextInt(1000);
  for (var i = 0; i < doCount; i++) {
    var n = random.nextInt(sum);
    var pos = 0;
    for (var j = 0; j < priority.length; j++) {
      if (n >= pos && n < pos + priority[j]) {
        functions[j].call(um, blocks);
        break;
      }
      pos += priority[j];
    }
  }
}

void doRandomOp2(UndoManager um, YText text) {
  void undo(UndoManager um, YText blocks) {
    um.undo();
  }

  void redo(UndoManager um, YText blocks) {
    um.undo();
  }

  void insertText(UndoManager um, YText text) {
    var len = text.length;
    if (len == 0) {
      text.insert(0, "hello");
    } else {
      text.insert(random.nextInt(len), "hello");
    }
  }

  void deleteText(UndoManager um, YText text) {
    var len = text.length;
    if (len == 0) {
      return;
    }
    var deleteIndex = random.nextInt(len);
    if (deleteIndex == len - 1) {
      text.delete(deleteIndex, 1);
    } else {
      text.delete(deleteIndex, random.nextInt(len - deleteIndex - 1) + 1);
    }
  }

  var priority = [0, 0, 3, 3];
  var sum = priority.reduce((value, element) => value + element);
  var functions = [undo, redo, insertText, deleteText];
  var doCount = 3;
  for (var i = 0; i < doCount; i++) {
    var n = random.nextInt(sum);
    var pos = 0;
    for (var j = 0; j < priority.length; j++) {
      if (n >= pos && n < pos + priority[j]) {
        functions[j].call(um, text);
        break;
      }
      pos += priority[j];
    }
  }
}

void mergeDocTest(Uint8List doc1, Uint8List doc2) {
  var v1 = mergeDoc(doc1, doc2);
  var v2 = mergeDoc(doc2, doc1);
  var d1 = YDoc();
  d1.applyUpdateV2(v1);
  var d2 = YDoc();
  d2.applyUpdateV2(v2);
  var text1 = d1.getText("blocks").toString();
  var text2 = d2.getText("blocks").toString();
  if (text1 != text2) {
    print(text1);
    print(text2);
    printDs(DeleteSet.store(d1.store).clients);
    printDs(DeleteSet.store(d2.store).clients);
    assert(text2 == text1);
  }
}

Uint8List mergeDoc(Uint8List doc1, Uint8List doc2) {
  print("merge start");
  YDoc doc = YDoc();
  doc.applyUpdateV2(doc1);
  doc.applyUpdateV2(doc2);
  print("merge end");
  printDs(DeleteSet.store(doc.store).clients);
  return doc.encodeStateAsUpdateV2();
}

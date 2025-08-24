import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ydart/types/y_map.dart';
import 'package:ydart/utils/undo_manager.dart';
import 'package:ydart/utils/y_doc.dart';

void main(){
  test("test undo text", () {
    var doc = YDoc();
    var text = doc.getText("hello");
    var undoManager = UndoManager.create(text);
    text.insert(0, 'test');
    print('first: ${text.toString()}');
    undoManager.stopCapturing();
    text.delete(0, 2);
    print('second: ${text.toString()}');
    undoManager.undo();
    print('result1: ${text.toString()}');
    undoManager.undo();
    print('result2: ${text.toString()}');
  });
  fixIssue367();
}
void fixIssue367(){
  var doc = YDoc();
  var root = doc.getMap();
  var undoManager = UndoManager.create(root);
  var point = YMap();
  point.set("x", 0);
  point.set("y", 0);
  root.set("a", point);
  undoManager.stopCapturing();
  point.set("x", 100);
  point.set("y", 100);
  undoManager.stopCapturing();
  point.set("x", 200);
  point.set("y", 200);
  undoManager.stopCapturing();
  point.set("x", 300);
  point.set("y", 300);
  undoManager.stopCapturing();
  print(jsonEncode(root.toJsonMap()));
  undoManager.undo();//200
  print(jsonEncode(root.toJsonMap()));
  undoManager.undo();//100
  print(jsonEncode(root.toJsonMap()));
  undoManager.undo();//0
  print(jsonEncode(root.toJsonMap()));
  undoManager.undo();//null
  print(jsonEncode(root.toJsonMap()));
  undoManager.redo();//0
  print(jsonEncode(root.toJsonMap()));
  undoManager.redo();//100
  print(jsonEncode(root.toJsonMap()));
  undoManager.redo();//200
  print(jsonEncode(root.toJsonMap()));
  undoManager.redo();//300,but actual is nil;
  print(jsonEncode(root.toJsonMap()));
}
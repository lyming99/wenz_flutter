import 'package:ydart/types/y_text.dart';
import 'package:ydart/utils/y_doc.dart';
import 'package:ydart/ydart.dart';

void main() {
  // deleteTest();
  undoTest();
}

void deleteTest(){
  var doc = YDoc();
  var blocks = doc.getArray("blocks");
  blocks.insert(0, [YText("hello")]);
  blocks.insert(1, [YText("world")]);
  blocks.delete(1);
  var bytes = doc.encodeStateAsUpdateV2();
  var doc2 = YDoc();
  doc2.applyUpdateV2(bytes);
  var blocks2 = doc2.getArray("blocks");
  assert(blocks2.length == 1);
  var text2 = blocks2.get(0) as YText;
  assert(text2.toString()=='hello');
}

void undoTest(){
  var doc = YDoc();
  var blocks = doc.getArray("blocks");
  var um = UndoManager.create(blocks);
  blocks.insert(0, [YText("hello")]);
  blocks.insert(1, [YText("world")]);
  um.stopCapturing();
  blocks.delete(1);
  um.undo();
  assert(blocks.length==2);
  assert(blocks.get(0).toString()=="hello");
  assert(blocks.get(1).toString()=="world");
}
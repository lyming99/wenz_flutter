import 'dart:math';

import 'package:ydart/utils/y_doc.dart';

const int n = 10000;
//经过测试，插入6万字符，编解码，总共耗时246ms
//插入600万字符，编解码，总共耗时
//得出结论，主要耗时在于编码
void main() {
  var startTime = DateTime.now().millisecondsSinceEpoch;
  var random = Random();
  var doc1 = YDoc();
  var doc2 = YDoc();

  // doc1.updateV2.add((data, origin, transaction) {
  //   // doc2.applyUpdateV2(data);
  // });

  for (int i = 0; i < n; i++) {
    var text = randomString(random,100);
    doc1.getText("text$i").insert(i, text);
  }
  var endTime = DateTime.now().millisecondsSinceEpoch;
  print('insert use time:${endTime - startTime}ms');
  var update = doc1.encodeStateAsUpdateV2();
  endTime = DateTime.now().millisecondsSinceEpoch;
  print('encode use time:${endTime - startTime}ms');
  doc1.encodeStateAsUpdateV2();
  endTime = DateTime.now().millisecondsSinceEpoch;
  print('encode2 use time:${endTime - startTime}ms');
  doc2.applyUpdateV2(update);
  var decodeText = doc2.getText("text").toString();
  endTime = DateTime.now().millisecondsSinceEpoch;
  print('decode use time:${endTime - startTime}ms');
  doc1.destroy();
  doc2.destroy();
  endTime = DateTime.now().millisecondsSinceEpoch;
  print('use time:${endTime - startTime}ms');
}
String randomString(Random rand,int n){
  String s = "";
  for(var i=0;i<n;i++) {
    s += getRandomChar(rand);
  }
  return s;
}
String getRandomChar(Random rand) {
  return String.fromCharCode(
      rand.nextInt('Z'.codeUnitAt(0) - 'A'.codeUnitAt(0) + 1) +
          'A'.codeUnitAt(0));
}

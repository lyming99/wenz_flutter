
import 'package:ydart/utils/fragment_utils.dart';

void main() async {
  var file = FragmentDocFile(path: "d:/doc.test");
  var startTime = DateTime.now();
  var doc = await file.readFragmentDoc();
  var endTime = DateTime.now();
  print(
      'read use time:${endTime.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch} ms');
  var hello = doc.getText("hello");
  print(hello.toString());
  for (var i = 0; i < 1000; i++) {
    var startTime = DateTime.now();
    hello.insert(0, "hello$i"+("*"*100));
    var endTime = DateTime.now();
    if (i == 999) {
      print(
          'write one use time:${endTime.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch} ms');
    }
  }
}


import 'dart:async';
import 'dart:io';

import 'y_doc.dart';

void main() async{
  var path = "D:/project/wen-note-app/local/user-1/notes/cb7fa6c0-e419-11ee-8c9c-6dd9f6d9736c.wnote";
  var file = File(path);
  var bytes = file.readAsBytesSync();
  var doc = YDoc();
  await file.withLog(() {
    doc.applyUpdateV2(bytes);
  }, logTitle: "decodeDoc");
  await file.withLog(() {
    doc.encodeStateAsUpdateV2();
  }, logTitle: "encodeDoc");
}



extension MethodTimeRecord on Object {

  Future<T> withLog<T>(
      FutureOr<T> Function() computation, {
        Duration? timeout,
        String? logTitle,
      }) async {
    print("[$logTitle] start.");
    var dateStart = DateTime.now();
    try {
      return await computation.call();
    } finally {
      var dateEnd = DateTime.now();
      print(
          "[$logTitle] use time: ${dateEnd.millisecondsSinceEpoch - dateStart.millisecondsSinceEpoch}ms");
    }
  }
}

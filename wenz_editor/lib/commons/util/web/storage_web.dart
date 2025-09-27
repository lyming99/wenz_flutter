// 声明全局 window 对象
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get window;

String? readLocalStorage(String key) {
  var localStorage = window['localStorage'];
  if (localStorage is JSObject) {
    return localStorage[key]?.toString();
  }
  return null;
}

void writeLocalStorage(String key, String value) {
  var localStorage = window['localStorage'];
  if (localStorage is JSObject) {
    localStorage[key] = value.toJS;
  }
}

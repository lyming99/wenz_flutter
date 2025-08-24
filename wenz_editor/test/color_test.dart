import 'package:flutter/material.dart';

String colorToHexWeb(Color color) {
  String hex = color.value.toRadixString(16).toUpperCase();
  return '#${('00000000'.substring(0, 8 - hex.length) + hex).substring(2)}';
}

void main() {
  Colors.blue;
  Color blue = Color.fromARGB(255, 0, 0, 255);
  String hexColor = colorToHexWeb(blue);
  print(hexColor); // 输出: #FF0000FF
}

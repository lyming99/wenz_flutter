String colorToHexWeb(int color) {
  String hex = color.toRadixString(16).toUpperCase();
  return '#${('00000000'.substring(0, 8 - hex.length) + hex).substring(2)}';
}

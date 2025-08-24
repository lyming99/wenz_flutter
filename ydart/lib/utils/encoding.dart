import 'dart:typed_data';

class AbstractEncoder {
  void writeVarInt(int client) {}

  void writeLength(int length) {}

  void writeAny(Object? content) {}

  void writeBuffer(Uint8List content) {}

  void writeString(String guid) {}

  void writeJson(Object? embed) {}

  void writeKey(String key) {}

  void writeInfo(int info) {}

  void writeTypeRef(int refId) {}
}

class AbstractDecoder {
  int readVarInt() {
    return 0;
  }

  int readLength() {
    return 0;
  }

  Object readAny() {
    return 1;
  }

  Uint8List readBuffer() {
    return Uint8List(0);
  }

  String readString() {
    return "";
  }

  Object readJson() {
    return 1;
  }

  String readKey() {
    return "";
  }
}

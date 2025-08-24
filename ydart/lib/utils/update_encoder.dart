import 'dart:typed_data';

import '../lib0/byte_output_stream.dart';
import 'id.dart';

abstract class IDSEncoder {
  ByteArrayOutputStream restWriter;

  IDSEncoder(this.restWriter);

  Uint8List toArray();

  void resetDsCurVal();

  void writeDsClock(int clock);

  void writeDsLength(int length);
}

abstract class IUpdateEncoder extends IDSEncoder {
  IUpdateEncoder(super.restWriter);

  void writeLeftId(ID id);

  void writeRightId(ID id);

  void writeClient(int client);

  void writeInfo(int info);

  void writeString(String s);

  void writeParentInfo(bool isYKey);

  void writeTypeRef(int info);

  void writeLength(int len);

  void writeAny(Object? any);

  void writeBuffer(Uint8List buf);

  void writeKey(String key);

  void writeJson<T>(T any);
}

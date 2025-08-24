import 'dart:io';
import 'dart:typed_data';

import 'package:ydart/lib0/byte_input_stream.dart';

import 'id.dart';

abstract class IDSDecoder {
  ByteArrayInputStream reader;

  IDSDecoder(this.reader);

  void resetDsCurVal();

  int readDsClock();

  int readDsLength();
}

abstract class IUpdateDecoder implements IDSDecoder {
  ID readLeftId();

  ID readRightId();

  int readClient();

  int readInfo();

  String readString();

  bool readParentInfo();

  int readTypeRef();

  int readLength();

  dynamic readAny();

   Uint8List readBuffer();

  String readKey();

  dynamic readJson();
}

import 'dart:io';

import 'package:ydart/lib0/byte_input_stream.dart';

import 'abstract_stream_decoder.dart';

class IntDiffDecoder extends AbstractStreamDecoder {
  late int _state;

  IntDiffDecoder(ByteArrayInputStream input, int start,
      {bool leaveOpen = false})
      : super(input, leaveOpen: leaveOpen) {
    _state = start;
  }

  @override
  int read() {
    checkDisposed();
    _state += stream.readVarInt();
    return _state;
  }
}

import 'dart:io';

import 'package:ydart/lib0/byte_input_stream.dart';

import 'abstract_stream_decoder.dart';

class UintOptRleDecoder extends AbstractStreamDecoder<int> {
  int _state = 0;
  int _count = 0;

  UintOptRleDecoder(super.input, {super.leaveOpen});

  @override
  int read() {
    checkDisposed();

    if (_count == 0) {
      var value = stream.readVarInt();
      bool isNegative = value < 0;
      if (isNegative) {
        _state = (-value).toUnsigned(32);
        _count = stream.readVarUint() + 2;
      } else {
        _state = value.toUnsigned(32);
        _count = 1;
      }
    }

    _count--;
    return _state;
  }
}

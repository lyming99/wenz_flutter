import 'dart:convert';
import 'dart:typed_data';

import 'package:ydart/lib0/byte_output_stream.dart';

import 'iencoder.dart';
import 'uint_opt_rle_encoder.dart';

class StringEncoder implements IEncoder<String> {
  late StringBuffer _sb;
  late UintOptRleEncoder _lengthEncoder;
  bool _disposed = false;

  StringEncoder() {
    _sb = StringBuffer();
    _lengthEncoder = UintOptRleEncoder();
  }

  void dispose() {
    _dispose(true);
    // System.GC.SuppressFinalize(this);
  }

  @override
  void write(String value) {
    _sb.write(value);
    _lengthEncoder.write(value.length);
  }

  @override
  Uint8List toArray() {
    var output = ByteArrayOutputStream();
    output.writeVarString(_sb.toString());
    var lengthData = _lengthEncoder.getBuffer();
    output.writeBuffer(lengthData, 0, lengthData.length);
    return output.toByteArray();
  }

  void _dispose(bool disposing) {
    if (!_disposed) {
      if (disposing) {
        _sb.clear();
        _lengthEncoder.dispose();
      }

      _sb = StringBuffer();
      _lengthEncoder = UintOptRleEncoder();
      _disposed = true;
    }
  }

  void checkDisposed() {
    if (_disposed) {
      throw Exception('${runtimeType.toString()} is disposed');
    }
  }

  @override
  Uint8List getBuffer() {
    return toArray();
  }
}

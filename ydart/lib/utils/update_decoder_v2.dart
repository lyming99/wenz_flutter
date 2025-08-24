import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:ydart/lib0/byte_input_stream.dart';

import '../lib0/decoding/int_diff_opt_rle_decoder.dart';
import '../lib0/decoding/rle_decoder.dart';
import '../lib0/decoding/string_decoder.dart';
import '../lib0/decoding/uint_opt_rle_decoder.dart';
import 'id.dart';
import 'update_decoder.dart';

class DSDecoderV2 extends IDSDecoder {
  bool leaveOpen;
  int _dsCurVal;
  bool _disposed;

  DSDecoderV2(super.reader, {this.leaveOpen = false})
      : _disposed = false,
        _dsCurVal = 0;

  @override
  void resetDsCurVal() {
    _dsCurVal = 0;
  }

  @override
  int readDsClock() {
    _dsCurVal += reader.readVarUint();
    assert(_dsCurVal >= 0);
    return _dsCurVal;
  }

  @override
  int readDsLength() {
    var diff = reader.readVarUint() + 1;
    assert(diff >= 0);
    _dsCurVal += diff;
    return diff;
  }

  void _dispose() {
    _disposed = true;
  }

  void checkDisposed() {
    if (_disposed) {
      throw Exception('DSDecoderV2');
    }
  }
}

class UpdateDecoderV2 extends DSDecoderV2 implements IUpdateDecoder {
  late List<String> _keys;
  late IntDiffOptRleDecoder _keyClockDecoder;
  late UintOptRleDecoder _clientDecoder;
  late IntDiffOptRleDecoder _leftClockDecoder;
  late IntDiffOptRleDecoder _rightClockDecoder;
  late RleDecoder _infoDecoder;
  late StringDecoder _stringDecoder;
  late RleDecoder _parentInfoDecoder;
  late UintOptRleDecoder _typeRefDecoder;
  late UintOptRleDecoder _lengthDecoder;

  UpdateDecoderV2(ByteArrayInputStream input, {bool leaveOpen = false})
      : super(input, leaveOpen: leaveOpen) {
    _keys = [];
    // Read feature flag - currently unused.
    input.readVarUint();
    _keyClockDecoder = IntDiffOptRleDecoder(input.readVarUint8ArrayAsStream());
    _clientDecoder = UintOptRleDecoder(input.readVarUint8ArrayAsStream());
    _leftClockDecoder = IntDiffOptRleDecoder(input.readVarUint8ArrayAsStream());
    _rightClockDecoder =
        IntDiffOptRleDecoder(input.readVarUint8ArrayAsStream());
    _infoDecoder = RleDecoder(input.readVarUint8ArrayAsStream());
    _stringDecoder = StringDecoder(input.readVarUint8ArrayAsStream());
    _parentInfoDecoder = RleDecoder(input.readVarUint8ArrayAsStream());
    _typeRefDecoder = UintOptRleDecoder(input.readVarUint8ArrayAsStream());
    _lengthDecoder = UintOptRleDecoder(input.readVarUint8ArrayAsStream());
  }

  @override
  ID readLeftId() {
    checkDisposed();
    return ID.create(_clientDecoder.read(), _leftClockDecoder.read());
  }

  @override
  ID readRightId() {
    checkDisposed();
    return ID.create(_clientDecoder.read(), _rightClockDecoder.read());
  }

  @override
  int readClient() {
    checkDisposed();
    return _clientDecoder.read();
  }

  @override
  int readInfo() {
    checkDisposed();
    return _infoDecoder.read();
  }

  @override
  String readString() {
    checkDisposed();
    return _stringDecoder.read();
  }

  @override
  bool readParentInfo() {
    checkDisposed();
    return _parentInfoDecoder.read() == 1;
  }

  @override
  int readTypeRef() {
    checkDisposed();
    return _typeRefDecoder.read();
  }

  @override
  int readLength() {
    checkDisposed();
    var value = _lengthDecoder.read();
    assert(value >= 0);
    return value;
  }

  @override
  dynamic readAny() {
    checkDisposed();
    var obj = reader.readAny();
    return obj;
  }

  @override
  Uint8List readBuffer() {
    checkDisposed();
    return reader.readVarUint8Array();
  }

  @override
  String readKey() {
    checkDisposed();
    var keyClock = _keyClockDecoder.read();
    if (keyClock < _keys.length) {
      return _keys[keyClock];
    } else {
      var key = _stringDecoder.read();
      _keys.add(key);
      return key;
    }
  }

  @override
  dynamic readJson() {
    checkDisposed();
    return reader.readAny();
  }
}

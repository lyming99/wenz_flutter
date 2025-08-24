import 'dart:convert';
import 'dart:typed_data';

import 'package:ydart/lib0/byte_output_stream.dart';

import '../lib0/encoding/int_diff_opt_rle_encoder.dart';
import '../lib0/encoding/rle_encoder.dart';
import '../lib0/encoding/string_encoder.dart';
import '../lib0/encoding/uint_opt_rle_encoder.dart';
import 'id.dart';
import 'update_encoder.dart';

class DSEncoderV2 extends IDSEncoder {
  late int _dsCurVal;
  bool disposed = false;

  DSEncoderV2(super.restWriter) {
    _dsCurVal = 0;
  }

  void dispose() {
    _dispose(disposing: true);
  }

  @override
  void resetDsCurVal() {
    _dsCurVal = 0;
  }

  @override
  void writeDsClock(int clock) {
    int diff = clock - _dsCurVal;
    assert(diff >= 0);
    _dsCurVal = clock;
    restWriter.writeVarUint(diff);
  }

  @override
  void writeDsLength(int length) {
    if (length <= 0) {
      throw ArgumentError();
    }

    restWriter.writeVarUint(length - 1);
    _dsCurVal += length;
  }

  @override
  Uint8List toArray() {
    return restWriter.toByteArray();
  }

  void _dispose({required bool disposing}) {}
}

class UpdateEncoderV2 extends DSEncoderV2 implements IUpdateEncoder {
  late int _keyclock;
  late Map<String, int> _keyMap;
  late IntDiffOptRleEncoder _keyclockEncoder;
  late UintOptRleEncoder _clientEncoder;
  late IntDiffOptRleEncoder _leftclockEncoder;
  late IntDiffOptRleEncoder _rightclockEncoder;
  late RleEncoder _infoEncoder;
  late StringEncoder _stringEncoder;
  late RleEncoder _parentInfoEncoder;
  late UintOptRleEncoder _typeRefEncoder;
  late UintOptRleEncoder _lengthEncoder;

  UpdateEncoderV2(super.restwriter) {
    _keyclock = 0;
    _keyMap = {};
    _keyclockEncoder = IntDiffOptRleEncoder();
    _clientEncoder = UintOptRleEncoder();
    _leftclockEncoder = IntDiffOptRleEncoder();
    _rightclockEncoder = IntDiffOptRleEncoder();
    _infoEncoder = RleEncoder();
    _stringEncoder = StringEncoder();
    _parentInfoEncoder = RleEncoder();
    _typeRefEncoder = UintOptRleEncoder();
    _lengthEncoder = UintOptRleEncoder();
  }

  @override
  Uint8List toArray() {
    var stream = ByteArrayOutputStream();
    stream.write(0);
    stream.writeVarUint8Array(_keyclockEncoder.toArray());
    stream.writeVarUint8Array(_clientEncoder.toArray());
    stream.writeVarUint8Array(_leftclockEncoder.toArray());
    stream.writeVarUint8Array(_rightclockEncoder.toArray());
    stream.writeVarUint8Array(_infoEncoder.toArray());
    stream.writeVarUint8Array(_stringEncoder.toArray());
    stream.writeVarUint8Array(_parentInfoEncoder.toArray());
    stream.writeVarUint8Array(_typeRefEncoder.toArray());
    stream.writeVarUint8Array(_lengthEncoder.toArray());
    var content = super.toArray();
    stream.writeBytes(content);
    return stream.toByteArray();
  }

  @override
  void writeLeftId(ID id) {
    _clientEncoder.write(id.client);
    _leftclockEncoder.write(id.clock);
  }

  @override
  void writeRightId(ID id) {
    _clientEncoder.write(id.client);
    _rightclockEncoder.write(id.clock);
  }

  @override
  void writeClient(int client) {
    _clientEncoder.write(client);
  }

  @override
  void writeInfo(int info) {
    _infoEncoder.write(info);
  }

  @override
  void writeString(String s) {
    _stringEncoder.write(s);
  }

  @override
  void writeParentInfo(bool isYKey) {
    _parentInfoEncoder.write(isYKey ? 1 : 0);
  }

  @override
  void writeTypeRef(int info) {
    _typeRefEncoder.write(info);
  }

  @override
  void writeLength(int len) {
    assert(len >= 0);
    _lengthEncoder.write(len);
  }

  @override
  void writeAny(Object? any) {
    restWriter.writeAny(any);
  }

  @override
  void writeBuffer(Uint8List data) {
    restWriter.writeVarUint8Array(data);
  }

  @override
  void writeKey(String key) {
    _keyclockEncoder.write(_keyclock++);
    if (!_keyMap.containsKey(key)) {
      _stringEncoder.write(key);
    }
  }

  @override
  void writeJson<T>(T any) {
    restWriter.writeAny(any);
  }

  @override
  void _dispose({required bool disposing}) {
    if (!disposed) {
      if (disposing) {
        _keyMap.clear();
        _keyclockEncoder.dispose();
        _clientEncoder.dispose();
        _leftclockEncoder.dispose();
        _rightclockEncoder.dispose();
        _infoEncoder.dispose();
        _stringEncoder.dispose();
        _parentInfoEncoder.dispose();
        _typeRefEncoder.dispose();
        _lengthEncoder.dispose();
      }

      _keyMap = {};
      _keyclockEncoder = IntDiffOptRleEncoder();
      _clientEncoder = UintOptRleEncoder();
      _leftclockEncoder = IntDiffOptRleEncoder();
      _rightclockEncoder = IntDiffOptRleEncoder();
      _infoEncoder = RleEncoder();
      _stringEncoder = StringEncoder();
      _parentInfoEncoder = RleEncoder();
      _typeRefEncoder = UintOptRleEncoder();
      _lengthEncoder = UintOptRleEncoder();
    }

    super._dispose(disposing: disposing);
  }
}

import 'dart:typed_data';

import 'package:ydart/lib0/constans.dart';

class ByteArrayInputStream {
  late Uint8List buf;
  late int pos;
  late int _mark;
  late int count;

  ByteArrayInputStream(this.buf) {
    pos = 0;
    count = buf.length;
  }

  ByteArrayInputStream.fromBuffer(this.buf, int offset, int length) {
    pos = offset;
    count = offset + length < buf.length ? offset + length : buf.length;
    _mark = offset;
  }

  int read() {
    return (pos < count) ? buf[pos++] & 0xff : -1;
  }

  Uint8List readNBytes(int len) {
    var result = Uint8List(len);
    readBytes(result, 0, len);
    return result;
  }

  int readBytes(Uint8List b, int off, int len) {
    if (pos >= count) {
      return -1;
    }

    int avail = count - pos;
    if (len > avail) {
      len = avail;
    }
    if (len <= 0) {
      return 0;
    }
    b.setRange(off, off + len, buf.sublist(pos, pos + len));
    pos += len;
    return len;
  }

  Uint8List readAllBytes() {
    Uint8List result = buf.sublist(pos, count);
    pos = count;
    return result;
  }

  int skip(int n) {
    int k = count - pos;
    if (n < k) {
      k = n < 0 ? 0 : n;
    }

    pos += k;
    return k;
  }

  int available() {
    return count - pos;
  }

  bool isClosed() {
    return false;
  }

  bool markSupported() {
    return true;
  }

  void mark(int readAheadLimit) {
    _mark = pos;
  }

  void reset() {
    pos = _mark;
  }

  void close() {}


  int readUint8() => buf[pos++];

  int readUint16() {
    return (readByte() + (readByte() << 8));
  }

  int readUint32() {
    return ((readByte() +
        (readByte() << 8) +
        (readByte() << 16) +
        (readByte() << 24)) >>
        0);
  }

  int readUint64() {
    return ((readByte() +
        (readByte() << 8) +
        (readByte() << 16) +
        (readByte() << 24) +
        (readByte() << 32) +
        (readByte() << 40) +
        (readByte() << 48) +
        (readByte() << 56)) >>
        0);
  }

  int readVarUint() {
    int num = 0;
    int len = 0;

    while (true) {
      int r = readByte();
      num |= (r & 0x7F) << len;
      len += 7;

      if (r < 0x80) {
        return num;
      }

      if (len > 35) {
        throw FormatException("Integer out of range.");
      }
    }
  }

  int readVarInt() {
    int r = readByte();
    int num = r & Bits.bits6;
    int len = 6;
    int sign = (r & Bit.bit7) > 0 ? -1 : 1;

    if ((r & Bit.bit8) == 0) {
      return sign * num;
    }

    while (true) {
      r = readByte();
      num |= (r & Bits.bits7) << len;
      len += 7;

      if (r < Bit.bit8) {
        return sign * num;
      }

      if (len > 41) {
        throw FormatException("Integer out of range");
      }
    }
  }

  String readVarString() {
    int remainingLen = readVarUint();
    if (remainingLen == 0) {
      return '';
    }
    Uint8List data = readNBytes(remainingLen);
    var str = String.fromCharCodes(data);
    try {
      return Uri.decodeComponent(str);
    } catch (e) {
      print(e);
      throw e;
    }
  }

  Uint8List readVarUint8Array() {
    int len = readVarUint();
    return readNBytes(len);
  }

  ByteArrayInputStream readVarUint8ArrayAsStream() {
    var data = readVarUint8Array();
    return ByteArrayInputStream(data);
  }

  dynamic readAny() {
    int type = readByte();
    switch (type) {
      case 119:
        return readVarString();
      case 120:
        return true;
      case 121:
        return false;
      case 123:
      // Float64
        var dBytes = readNBytes(8);
        ByteData byteData = ByteData.sublistView(dBytes);
        return byteData.getFloat64(0, Endian.host);
      case 124:
      // Float32
        var fBytes = readNBytes(4);
        ByteData byteData = ByteData.sublistView(fBytes);
        return byteData.getFloat32(0, Endian.host);
      case 125:
        return readVarInt();
      case 126:
      case 127:
        return null;
      case 116:
        return readVarUint8Array();
      case 117:
        int len = readVarUint();
        List<dynamic> arr = [];
        for (int i = 0; i < len; i++) {
          arr.add(readAny());
        }
        return arr;
      case 118:
        int len = readVarUint();
        Map<String, dynamic> obj = {};
        for (int i = 0; i < len; i++) {
          String key = readVarString();
          obj[key] = readAny();
        }
        return obj;
      default:
        throw FormatException("Unknown object type: $type");
    }
  }

  int readByte() {
    return read();
  }
}

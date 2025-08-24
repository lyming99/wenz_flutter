import 'dart:typed_data';

class ByteArrayOutputStream {
  late Uint8List _buf;
  int _count = 0;

  ByteArrayOutputStream([int size = 32]) {
    if (size < 0) {
      throw ArgumentError('Negative initial size: $size');
    }
    _buf = Uint8List(size);
  }

  void _ensureCapacity(int minCapacity) {
    int oldCapacity = _buf.length;
    int minGrowth = minCapacity - oldCapacity;
    if (minGrowth > 0) {
      var newBuf = Uint8List(minCapacity * 2);
      newBuf.setRange(0, oldCapacity, _buf);
      _buf = newBuf;
    }
  }

  void write(int b) {
    _ensureCapacity(_count + 1);
    _buf[_count] = b;
    _count += 1;
  }

  void writeBytes(Uint8List b) {
    writeBuffer(b, 0, b.length);
  }

  void writeBuffer(Uint8List b, int off, int len) {
    if (off < 0 || len < 0 || len > b.length - off) {
      throw RangeError('Invalid offset or length');
    }
    _ensureCapacity(_count + len);
    _buf.setRange(_count, _count + len, b.sublist(off, off + len));
    _count += len;
  }

  void reset() {
    _count = 0;
  }

  Uint8List toByteArray() {
    return Uint8List.fromList(_buf.sublist(0, _count));
  }

  int size() {
    return _count;
  }

  String toString() {
    return String.fromCharCodes(_buf.sublist(0, _count));
  }

  void close() {}

  void writeUint16(int num) {
    write(num & 0xFF);
    write((num >> 8) & 0xFF);
  }

  void writeUint32(int num) {
    for (int i = 0; i < 4; i++) {
      write(num & 0xFF);
      num >>= 8;
    }
  }

  void writeUint64(int num) {
    for (int i = 0; i < 8; i++) {
      write(num & 0xFF);
      num >>= 8;
    }
  }

  void writeVarUint(int num) {
    while (num > 0x7F) {
      write(0x80 | (num & 0x7F));
      num >>= 7;
    }
    write(num & 0x7F);
  }

  void writeVarInt(int num, {bool? treatZeroAsNegative}) {
    bool isNegative = num == 0 ? (treatZeroAsNegative ?? false) : num < 0;
    if (isNegative) {
      num = -num;
    }

    write((num > 0x3F ? 0x80 : 0) | (isNegative ? 0x40 : 0) | (num & 0x3F));
    num >>= 6;

    while (num > 0) {
      write((num > 0x7F ? 0x80 : 0) | (num & 0x7F));
      num >>= 7;
    }
  }

  void writeVarString(String str) {
    var value = Uri.encodeComponent(str);
    writeVarUint(value.length);
    for (var i = 0; i < value.length; i++) {
      write(value.codeUnitAt(i));
    }
  }

  void writeVarUint8Array(Uint8List array) {
    writeVarUint(array.length);
    writeBytes(array);
  }

  void writeAny(dynamic o) {
    if (o is String) {
      write(119);
      writeVarString(o);
    } else if (o is bool) {
      write(o ? 120 : 121);
    } else if (o is double) {
      write(123);
      var data = ByteData(8);
      data.setFloat64(0, o);
      writeBytes(data.buffer.asUint8List());
    } else if (o is int) {
      write(125);
      writeVarInt(o);
    } else if (o == null) {
      write(126);
    } else if (o is Iterable) {
      write(117);
      writeVarUint(o.length);
      for (var item in o) {
        writeAny(item);
      }
    } else if (o is Map) {
      write(118);
      writeVarUint(o.length);
      o.forEach((key, value) {
        writeVarString(key.toString());
        writeAny(value);
      });
    } else {
      throw UnimplementedError('Unsupported object type: ${o.runtimeType}');
    }
  }
}

import 'dart:typed_data';

abstract class IEncoder<T> {
    void write(T value);

    Uint8List toArray();

    Uint8List getBuffer();
}
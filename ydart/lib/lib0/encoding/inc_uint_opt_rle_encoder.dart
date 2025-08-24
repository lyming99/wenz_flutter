import 'abstract_stream_encoder.dart';

class IncUintOptRleEncoder extends AbstractStreamEncoder<int> {
  int _state = 0;
  int _count = 0;

  IncUintOptRleEncoder() {
    // Do nothing.
  }

  @override
  void write(int value) {
    if (_state + _count == value) {
      _count++;
    } else {
      writeEncodedValue();
      _count = 1;
      _state = value;
    }
  }

  void flush() {
    writeEncodedValue();
  }

  void writeEncodedValue() {
    if (_count > 0) {
      if (_count == 1) {
        stream.writeVarInt(_state);
      } else {
        stream.writeVarInt(-_state, treatZeroAsNegative: _state == 0);
        stream.writeVarUint(_count - 2);
      }
    }
  }
}
